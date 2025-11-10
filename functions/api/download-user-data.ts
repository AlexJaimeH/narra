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
    console.log('[download-user-data] Starting download request');

    // Get authorization header
    const authHeader = request.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      console.error('[download-user-data] Missing authorization header');
      return json({ error: 'No autorizado' }, 401);
    }

    const token = authHeader.substring(7);

    const { credentials } = resolveSupabaseConfig(env);
    const supabaseUrl = credentials?.url;
    const serviceKey = credentials?.serviceKey;

    if (!supabaseUrl || !serviceKey) {
      console.error('[download-user-data] Missing Supabase credentials');
      return json({
        error: 'Configuración de servidor incorrecta',
      }, 500);
    }

    console.log('[download-user-data] Verifying user token');

    // Verify token and get user
    const userResponse = await fetch(`${supabaseUrl}/auth/v1/user`, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'apikey': serviceKey,
      },
    });

    if (!userResponse.ok) {
      console.error('[download-user-data] Invalid token', userResponse.status);
      return json({ error: 'Token inválido o expirado' }, 401);
    }

    const user = await userResponse.json() as any;
    const userId = user.id;

    if (!userId) {
      console.error('[download-user-data] User ID not found');
      return json({ error: 'Usuario no encontrado' }, 404);
    }

    console.log('[download-user-data] User verified:', userId);

    // Import JSZip dynamically
    console.log('[download-user-data] Importing JSZip');
    let JSZip: any;
    try {
      JSZip = (await import('https://esm.sh/jszip@3.10.1')).default;
      console.log('[download-user-data] JSZip imported successfully');
    } catch (importError) {
      console.error('[download-user-data] Failed to import JSZip:', importError);
      return json({ error: 'Error al cargar biblioteca de compresión', detail: String(importError) }, 500);
    }

    const zip = new JSZip();

    console.log('[download-user-data] Fetching user data');

    // Fetch user data
    let stories: any[] = [];
    try {
      const [userProfile, userSettings, storiesData] = await Promise.all([
        fetchFromSupabase(supabaseUrl, serviceKey, 'users', `id=eq.${userId}`),
        fetchFromSupabase(supabaseUrl, serviceKey, 'user_settings', `user_id=eq.${userId}`),
        fetchFromSupabase(supabaseUrl, serviceKey, 'stories', `author_id=eq.${userId}&order=created_at.desc`),
      ]);
      stories = storiesData;
      console.log('[download-user-data] Fetched data - stories count:', stories.length);
    } catch (fetchError) {
      console.error('[download-user-data] Error fetching user data:', fetchError);
      return json({ error: 'Error al obtener datos del usuario', detail: String(fetchError) }, 500);
    }

    // Create root folders
    const draftFolder = zip.folder('borradores');
    const publishedFolder = zip.folder('publicadas');

    console.log('[download-user-data] Processing', stories.length, 'stories');

    // Process each story
    for (let i = 0; i < stories.length; i++) {
      const story = stories[i];
      try {
        console.log(`[download-user-data] Processing story ${i + 1}/${stories.length}: ${story.title || 'Sin título'}`);

        const isPublished = story.is_published;
        const parentFolder = isPublished ? publishedFolder : draftFolder;

        // Sanitize story title for folder name
        const storyTitle = sanitizeFileName(story.title || 'Sin título');
        const storyFolder = parentFolder?.folder(storyTitle);

        if (!storyFolder) {
          console.warn(`[download-user-data] Could not create folder for story: ${storyTitle}`);
          continue;
        }

        // Fetch related data for this story
        const [photos, recordings, versions] = await Promise.all([
          fetchFromSupabase(supabaseUrl, serviceKey, 'story_photos', `story_id=eq.${story.id}&order=position.asc`),
          fetchFromSupabase(supabaseUrl, serviceKey, 'voice_recordings', `story_id=eq.${story.id}&order=created_at.asc`),
          fetchFromSupabase(supabaseUrl, serviceKey, 'story_versions', `story_id=eq.${story.id}&order=version_number.asc`),
        ]);

        console.log(`[download-user-data] Story data - photos: ${photos.length}, recordings: ${recordings.length}, versions: ${versions.length}`);

        // Create main story text file
        const storyText = createStoryText(story);
        storyFolder.file('historia.txt', storyText);

        // Add images as text references if they exist
        // TEMPORARY: Not downloading actual files to debug 500 error
        if (photos.length > 0) {
          const imagesFolder = storyFolder.folder('imagenes');
          for (let j = 0; j < photos.length; j++) {
            const photo = photos[j];
            imagesFolder?.file(`imagen-${j + 1}-url.txt`, `URL: ${photo.photo_url}\n\nNota: La descarga de archivos multimedia se habilitará una vez resuelto el error inicial.`);
          }
          console.log(`[download-user-data] Added ${photos.length} image references`);
        }

        // Add recordings as text references if they exist
        // TEMPORARY: Not downloading actual files to debug 500 error
        if (recordings.length > 0) {
          const recordingsFolder = storyFolder.folder('grabaciones');
          for (let j = 0; j < recordings.length; j++) {
            const recording = recordings[j];
            if (recording.audio_url) {
              recordingsFolder?.file(`grabacion-${j + 1}-url.txt`, `URL: ${recording.audio_url}\n\nNota: La descarga de archivos multimedia se habilitará una vez resuelto el error inicial.`);
            }
          }
          console.log(`[download-user-data] Added ${recordings.length} recording references`);
        }

        // Add version history if it exists
        if (versions.length > 0) {
          const versionsFolder = storyFolder.folder('versiones');
          for (let j = 0; j < versions.length; j++) {
            const version = versions[j];
            const versionText = createVersionText(version, j + 1);
            versionsFolder?.file(`version-${version.version_number || (j + 1)}.txt`, versionText);
          }
        }

      } catch (storyError) {
        console.error(`[download-user-data] Error processing story ${i + 1}:`, storyError);
        // Continue with next story even if this one fails
        continue;
      }
    }

    console.log('[download-user-data] Creating metadata file');

    // Add metadata file in root
    const metadata = {
      exportado: new Date().toISOString(),
      usuario: user.email,
      total_historias: stories.length,
      borradores: stories.filter((s: any) => !s.is_published).length,
      publicadas: stories.filter((s: any) => s.is_published).length,
    };
    zip.file('info.txt', JSON.stringify(metadata, null, 2));

    console.log('[download-user-data] Generating ZIP file');

    // Generate ZIP
    let zipBlob: Uint8Array;
    try {
      zipBlob = await zip.generateAsync({
        type: 'uint8array',
        compression: 'DEFLATE',
        compressionOptions: { level: 6 }
      });
      console.log('[download-user-data] ZIP generated successfully, size:', zipBlob.byteLength, 'bytes');
    } catch (zipError) {
      console.error('[download-user-data] Error generating ZIP:', zipError);
      return json({ error: 'Error al generar archivo ZIP', detail: String(zipError) }, 500);
    }

    console.log('[download-user-data] Sending ZIP response');

    // Return as ZIP download
    return new Response(zipBlob, {
      status: 200,
      headers: {
        'Content-Type': 'application/zip',
        'Content-Disposition': `attachment; filename="narra-datos-${Date.now()}.zip"`,
        ...CORS_HEADERS,
      },
    });

  } catch (error) {
    console.error('[download-user-data] Unexpected error:', error);
    // Include stack trace in error detail
    const errorDetail = error instanceof Error ? `${error.message}\n${error.stack}` : String(error);
    return json({
      error: 'Error al generar descarga de datos',
      detail: errorDetail
    }, 500);
  }
};

function sanitizeFileName(name: string): string {
  // Remove or replace invalid characters for file/folder names
  return name
    .replace(/[<>:"/\\|?*]/g, '-')
    .replace(/\s+/g, ' ')
    .trim()
    .substring(0, 200); // Limit length
}

function createStoryText(story: any): string {
  const lines = [];

  lines.push('═'.repeat(80));
  lines.push(`  ${story.title || 'Sin título'}`);
  lines.push('═'.repeat(80));
  lines.push('');

  if (story.story_date) {
    lines.push(`📅 Fecha de la historia: ${formatDate(story.story_date)}`);
  }

  lines.push(`📝 Creada: ${formatDate(story.created_at)}`);
  lines.push(`✏️  Última edición: ${formatDate(story.updated_at)}`);

  if (story.is_published && story.published_at) {
    lines.push(`🌐 Publicada: ${formatDate(story.published_at)}`);
  }

  if (story.word_count) {
    lines.push(`📊 Palabras: ${story.word_count}`);
  }

  lines.push('');
  lines.push('─'.repeat(80));
  lines.push('');

  // Add excerpt if exists
  if (story.excerpt) {
    lines.push('EXTRACTO:');
    lines.push(story.excerpt);
    lines.push('');
    lines.push('─'.repeat(80));
    lines.push('');
  }

  // Add main content
  lines.push('CONTENIDO:');
  lines.push('');
  const content = stripHtml(story.content || '');
  lines.push(content);

  // Add voice transcript if exists
  if (story.voice_transcript) {
    lines.push('');
    lines.push('');
    lines.push('─'.repeat(80));
    lines.push('TRANSCRIPCIÓN DE VOZ:');
    lines.push('');
    lines.push(stripHtml(story.voice_transcript));
  }

  lines.push('');
  lines.push('');
  lines.push('═'.repeat(80));

  return lines.join('\n');
}

function createVersionText(version: any, versionNum: number): string {
  const lines = [];

  lines.push(`VERSIÓN ${versionNum}`);
  lines.push('─'.repeat(60));
  lines.push(`Fecha: ${formatDate(version.created_at)}`);
  if (version.version_number) {
    lines.push(`Número de versión: ${version.version_number}`);
  }
  lines.push('');
  lines.push('CONTENIDO:');
  lines.push('');
  lines.push(stripHtml(version.content || ''));

  return lines.join('\n');
}

function formatDate(dateString: string): string {
  const date = new Date(dateString);
  return date.toLocaleString('es-ES', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  });
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

function getFileExtension(url: string): string | null {
  try {
    const urlObj = new URL(url);
    const pathname = urlObj.pathname;
    const match = pathname.match(/\.([a-zA-Z0-9]+)$/);
    return match ? match[1] : null;
  } catch {
    return null;
  }
}

async function downloadFile(url: string): Promise<ArrayBuffer | null> {
  try {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    return await response.arrayBuffer();
  } catch (error) {
    console.error(`[download-user-data] Failed to download file from ${url}:`, error);
    return null;
  }
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
      console.error(`[download-user-data] Failed to fetch ${table}:`, response.status);
      return [];
    }

    return await response.json();
  } catch (error) {
    console.error(`[download-user-data] Error fetching ${table}:`, error);
    return [];
  }
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}
