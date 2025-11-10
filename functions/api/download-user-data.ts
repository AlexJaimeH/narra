import {
  resolveSupabaseConfig,
  type SupabaseEnv,
} from "./_supabase";

interface Env extends SupabaseEnv {}

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Max-Age': '86400',
};

export const onRequestOptions: PagesFunction<Env> = async () => {
  return new Response(null, { status: 204, headers: CORS_HEADERS });
};

export const onRequestPost: PagesFunction<Env> = async ({ request, env }) => {
  try {
    // Get authorization header
    const authHeader = request.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return json({ error: 'No autorizado' }, 401);
    }

    const token = authHeader.substring(7);

    const { credentials } = resolveSupabaseConfig(env);
    const supabaseUrl = credentials?.url;
    const serviceKey = credentials?.serviceKey;

    if (!supabaseUrl || !serviceKey) {
      return json({ error: 'Configuración de servidor incorrecta' }, 500);
    }

    // Verify token and get user
    const userResponse = await fetch(`${supabaseUrl}/auth/v1/user`, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'apikey': serviceKey,
      },
    });

    if (!userResponse.ok) {
      return json({ error: 'Token inválido o expirado' }, 401);
    }

    const user = await userResponse.json() as any;
    const userId = user.id;

    if (!userId) {
      return json({ error: 'Usuario no encontrado' }, 404);
    }

    // Fetch user profile
    const userProfile = await fetchFromSupabase(supabaseUrl, serviceKey, 'users', `id=eq.${userId}`);
    const userName = (userProfile[0]?.name || 'Usuario').trim();

    // CORREGIDO: usar user_id en lugar de author_id
    const stories = await fetchFromSupabase(
      supabaseUrl,
      serviceKey,
      'stories',
      `user_id=eq.${userId}&order=created_at.desc`
    );

    // Import fflate (más ligero que JSZip)
    const { strToU8, zipSync } = await import('https://esm.sh/fflate@0.8.2');

    // Create files structure for ZIP
    const files: Record<string, Uint8Array> = {};

    // Add metadata
    const metadata = {
      exportado: new Date().toISOString(),
      usuario: user.email,
      nombre: userName,
      total_historias: stories.length,
      borradores: stories.filter((s: any) => !s.is_published).length,
      publicadas: stories.filter((s: any) => s.is_published).length,
    };
    files['info.txt'] = strToU8(JSON.stringify(metadata, null, 2));

    // Process each story
    for (let i = 0; i < stories.length; i++) {
      const story = stories[i];
      const isPublished = story.is_published;
      const folderPrefix = isPublished ? 'publicadas/' : 'borradores/';

      const storyTitle = sanitizeFileName(story.title || 'Sin título');
      const storyPath = folderPrefix + storyTitle + '/';

      // Fetch related data
      const [photos, recordings, versions] = await Promise.all([
        fetchFromSupabase(supabaseUrl, serviceKey, 'story_photos', `story_id=eq.${story.id}&order=position.asc`),
        fetchFromSupabase(supabaseUrl, serviceKey, 'voice_recordings', `story_id=eq.${story.id}&order=created_at.asc`),
        fetchFromSupabase(supabaseUrl, serviceKey, 'story_versions', `story_id=eq.${story.id}&order=version_number.asc`),
      ]);

      // Add main story file
      const storyText = createStoryText(story);
      files[storyPath + 'historia.txt'] = strToU8(storyText);

      // Add image references
      if (photos.length > 0) {
        for (let j = 0; j < photos.length; j++) {
          const photo = photos[j];
          const extension = getFileExtension(photo.photo_url) || 'jpg';
          const imageText = `URL de la imagen:\n${photo.photo_url}\n\nDescarga este archivo manualmente desde la URL.`;
          files[storyPath + `imagenes/imagen-${j + 1}-${extension}.txt`] = strToU8(imageText);
        }
      }

      // Add recording references
      if (recordings.length > 0) {
        for (let j = 0; j < recordings.length; j++) {
          const recording = recordings[j];
          if (recording.audio_url) {
            const extension = getFileExtension(recording.audio_url) || 'mp3';
            const audioText = `URL de la grabación:\n${recording.audio_url}\n\nDescarga este archivo manualmente desde la URL.`;
            files[storyPath + `grabaciones/grabacion-${j + 1}-${extension}.txt`] = strToU8(audioText);
          }
        }
      }

      // Add versions
      if (versions.length > 0) {
        for (let j = 0; j < versions.length; j++) {
          const version = versions[j];
          const versionText = createVersionText(version, j + 1);
          files[storyPath + `versiones/version-${version.version_number || (j + 1)}.txt`] = strToU8(versionText);
        }
      }
    }

    // Generate ZIP
    const zipData = zipSync(files, { level: 6 });

    // Generate filename
    const now = new Date();
    const yy = String(now.getFullYear()).slice(-2);
    const mm = now.getMonth() + 1;
    const dd = now.getDate();
    const mmStr = mm < 10 ? '0' + mm : String(mm);
    const ddStr = dd < 10 ? '0' + dd : String(dd);
    const sanitizedName = sanitizeFileName(userName);
    const filename = `${yy}${mmStr}${ddStr} Narra - ${sanitizedName}.zip`;

    // Return as ZIP download
    return new Response(zipData, {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Content-Disposition': `attachment; filename="${filename}"`,
        ...CORS_HEADERS,
      },
    });

  } catch (error: any) {
    return json({
      error: 'Error al generar descarga de datos',
      detail: error?.message || String(error)
    }, 500);
  }
};

function sanitizeFileName(name: string): string {
  return name
    .replace(/[<>:"/\\|?*]/g, '-')
    .replace(/\s+/g, ' ')
    .trim()
    .substring(0, 200);
}

function stripHtml(html: string): string {
  return html
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p>/gi, '\n\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .trim();
}

async function fetchFromSupabase(
  supabaseUrl: string,
  serviceKey: string,
  table: string,
  query: string
): Promise<any[]> {
  try {
    const url = `${supabaseUrl}/rest/v1/${table}?${query}`;
    const response = await fetch(url, {
      headers: {
        'Content-Type': 'application/json',
        'apikey': serviceKey,
        'Authorization': `Bearer ${serviceKey}`,
      },
    });

    if (!response.ok) {
      return [];
    }

    return await response.json();
  } catch (error) {
    return [];
  }
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}
