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
  console.log('[download-user-data] ===== START REQUEST =====');

  try {
    console.log('[download-user-data] Step 1: Checking authorization');
    const authHeader = request.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      console.log('[download-user-data] ERROR: No authorization header');
      return json({ error: 'No autorizado' }, 401);
    }

    const token = authHeader.substring(7);
    console.log('[download-user-data] Step 2: Getting Supabase config');

    const { credentials } = resolveSupabaseConfig(env);
    const supabaseUrl = credentials?.url;
    const serviceKey = credentials?.serviceKey;

    if (!supabaseUrl || !serviceKey) {
      console.log('[download-user-data] ERROR: Missing Supabase credentials');
      return json({ error: 'Configuración de servidor incorrecta' }, 500);
    }
    console.log('[download-user-data] Supabase URL:', supabaseUrl);

    console.log('[download-user-data] Step 3: Verifying user token');
    const userResponse = await fetch(`${supabaseUrl}/auth/v1/user`, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'apikey': serviceKey,
      },
    });

    if (!userResponse.ok) {
      console.log('[download-user-data] ERROR: Invalid token, status:', userResponse.status);
      return json({ error: 'Token inválido o expirado' }, 401);
    }

    const user = await userResponse.json() as any;
    const userId = user.id;

    if (!userId) {
      console.log('[download-user-data] ERROR: User ID not found in response');
      return json({ error: 'Usuario no encontrado' }, 404);
    }
    console.log('[download-user-data] User verified:', userId);

    console.log('[download-user-data] Step 4: Fetching user profile');
    const userProfile = await fetchFromSupabase(supabaseUrl, serviceKey, 'users', `id=eq.${userId}`);
    const userName = (userProfile[0]?.name || 'Usuario').trim();
    console.log('[download-user-data] User name:', userName);

    console.log('[download-user-data] Step 5: Importing JSZip');
    let JSZip: any;
    try {
      JSZip = (await import('https://esm.sh/jszip@3.10.1')).default;
      console.log('[download-user-data] JSZip imported successfully, type:', typeof JSZip);
    } catch (importError: any) {
      console.error('[download-user-data] ERROR importing JSZip:', importError);
      console.error('[download-user-data] Import error details:', {
        message: importError?.message,
        stack: importError?.stack,
        name: importError?.name
      });
      return json({ error: 'Error al cargar biblioteca de compresión', detail: String(importError) }, 500);
    }

    console.log('[download-user-data] Step 6: Creating JSZip instance');
    let zip: any;
    try {
      zip = new JSZip();
      console.log('[download-user-data] JSZip instance created successfully');
    } catch (zipError: any) {
      console.error('[download-user-data] ERROR creating JSZip instance:', zipError);
      return json({ error: 'Error al crear instancia de ZIP', detail: String(zipError) }, 500);
    }

    console.log('[download-user-data] Step 7: Fetching stories');
    let stories: any[] = [];
    try {
      stories = await fetchFromSupabase(
        supabaseUrl,
        serviceKey,
        'stories',
        `author_id=eq.${userId}&order=created_at.desc`
      );
      console.log('[download-user-data] Fetched', stories.length, 'stories');
    } catch (storiesError: any) {
      console.error('[download-user-data] ERROR fetching stories:', storiesError);
      return json({ error: 'Error al obtener historias', detail: String(storiesError) }, 500);
    }

    console.log('[download-user-data] Step 8: Creating root folders');
    try {
      const draftFolder = zip.folder('borradores');
      const publishedFolder = zip.folder('publicadas');
      console.log('[download-user-data] Root folders created');

      console.log('[download-user-data] Step 9: Processing stories');
      for (let i = 0; i < stories.length; i++) {
        const story = stories[i];
        console.log(`[download-user-data] Processing story ${i + 1}/${stories.length}: "${story.title || 'Sin título'}"`);

        try {
          const isPublished = story.is_published;
          const parentFolder = isPublished ? publishedFolder : draftFolder;
          const storyTitle = sanitizeFileName(story.title || 'Sin título');
          const storyFolder = parentFolder?.folder(storyTitle);

          if (!storyFolder) {
            console.log(`[download-user-data] WARNING: Could not create folder for story: ${storyTitle}`);
            continue;
          }

          console.log(`[download-user-data] Story ${i + 1}: Fetching related data`);
          const [photos, recordings, versions] = await Promise.all([
            fetchFromSupabase(supabaseUrl, serviceKey, 'story_photos', `story_id=eq.${story.id}&order=position.asc`),
            fetchFromSupabase(supabaseUrl, serviceKey, 'voice_recordings', `story_id=eq.${story.id}&order=created_at.asc`),
            fetchFromSupabase(supabaseUrl, serviceKey, 'story_versions', `story_id=eq.${story.id}&order=version_number.asc`),
          ]);
          console.log(`[download-user-data] Story ${i + 1}: photos=${photos.length}, recordings=${recordings.length}, versions=${versions.length}`);

          console.log(`[download-user-data] Story ${i + 1}: Creating historia.txt`);
          const storyText = createStoryText(story);
          storyFolder.file('historia.txt', storyText);

          if (photos.length > 0) {
            console.log(`[download-user-data] Story ${i + 1}: Adding ${photos.length} image references`);
            const imagesFolder = storyFolder.folder('imagenes');
            for (let j = 0; j < photos.length; j++) {
              const photo = photos[j];
              const extension = getFileExtension(photo.photo_url) || 'jpg';
              imagesFolder?.file(`imagen-${j + 1}-${extension}.txt`, `URL de la imagen:\n${photo.photo_url}\n\nPuedes descargar este archivo manualmente desde esta URL.`);
            }
          }

          if (recordings.length > 0) {
            console.log(`[download-user-data] Story ${i + 1}: Adding ${recordings.length} recording references`);
            const recordingsFolder = storyFolder.folder('grabaciones');
            for (let j = 0; j < recordings.length; j++) {
              const recording = recordings[j];
              if (recording.audio_url) {
                const extension = getFileExtension(recording.audio_url) || 'mp3';
                recordingsFolder?.file(`grabacion-${j + 1}-${extension}.txt`, `URL de la grabación:\n${recording.audio_url}\n\nPuedes descargar este archivo manualmente desde esta URL.`);
              }
            }
          }

          if (versions.length > 0) {
            console.log(`[download-user-data] Story ${i + 1}: Adding ${versions.length} versions`);
            const versionsFolder = storyFolder.folder('versiones');
            for (let j = 0; j < versions.length; j++) {
              const version = versions[j];
              const versionText = createVersionText(version, j + 1);
              versionsFolder?.file(`version-${version.version_number || (j + 1)}.txt`, versionText);
            }
          }

          console.log(`[download-user-data] Story ${i + 1}: Completed successfully`);

        } catch (storyError: any) {
          console.error(`[download-user-data] ERROR processing story ${i + 1}:`, storyError);
          console.error(`[download-user-data] Story error details:`, {
            message: storyError?.message,
            stack: storyError?.stack
          });
          continue;
        }
      }

      console.log('[download-user-data] Step 10: Adding metadata file');
      const metadata = {
        exportado: new Date().toISOString(),
        usuario: user.email,
        nombre: userName,
        total_historias: stories.length,
        borradores: stories.filter((s: any) => !s.is_published).length,
        publicadas: stories.filter((s: any) => s.is_published).length,
      };
      zip.file('info.txt', JSON.stringify(metadata, null, 2));
      console.log('[download-user-data] Metadata file added');

    } catch (processingError: any) {
      console.error('[download-user-data] ERROR during processing:', processingError);
      console.error('[download-user-data] Processing error details:', {
        message: processingError?.message,
        stack: processingError?.stack,
        name: processingError?.name
      });
      return json({ error: 'Error al procesar datos', detail: String(processingError) }, 500);
    }

    console.log('[download-user-data] Step 11: Generating ZIP file');
    let zipBlob: Uint8Array;
    try {
      zipBlob = await zip.generateAsync({
        type: 'uint8array',
        compression: 'DEFLATE',
        compressionOptions: { level: 6 }
      });
      console.log('[download-user-data] ZIP generated successfully, size:', zipBlob.byteLength, 'bytes');
    } catch (zipError: any) {
      console.error('[download-user-data] ERROR generating ZIP:', zipError);
      console.error('[download-user-data] ZIP generation error details:', {
        message: zipError?.message,
        stack: zipError?.stack,
        name: zipError?.name
      });
      return json({ error: 'Error al generar archivo ZIP', detail: String(zipError) }, 500);
    }

    console.log('[download-user-data] Step 12: Preparing response');
    const now = new Date();
    const yy = String(now.getFullYear()).slice(-2);
    const mm = String(now.getMonth() + 1).padStart(2, '0');
    const dd = String(now.getDate()).padStart(2, '0');
    const sanitizedName = sanitizeFileName(userName);
    const filename = `${yy}${mm}${dd} Narra - ${sanitizedName}.zip`;
    console.log('[download-user-data] Filename:', filename);

    console.log('[download-user-data] Step 13: Sending response');
    const response = new Response(zipBlob, {
      status: 200,
      headers: {
        'Content-Type': 'application/zip',
        'Content-Disposition': `attachment; filename="${filename}"`,
        ...CORS_HEADERS,
      },
    });
    console.log('[download-user-data] ===== REQUEST COMPLETED SUCCESSFULLY =====');
    return response;

  } catch (error: any) {
    console.error('[download-user-data] ===== UNEXPECTED ERROR =====');
    console.error('[download-user-data] Error type:', typeof error);
    console.error('[download-user-data] Error:', error);
    console.error('[download-user-data] Error details:', {
      message: error?.message,
      stack: error?.stack,
      name: error?.name,
      cause: error?.cause
    });

    const errorDetail = error instanceof Error ? `${error.message}\n${error.stack}` : String(error);
    return json({
      error: 'Error al generar descarga de datos',
      detail: errorDetail,
      type: typeof error,
      name: error?.name
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

  if (story.excerpt) {
    lines.push('EXTRACTO:');
    lines.push(story.excerpt);
    lines.push('');
    lines.push('─'.repeat(80));
    lines.push('');
  }

  lines.push('CONTENIDO:');
  lines.push('');
  const content = stripHtml(story.content || '');
  lines.push(content);

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
      console.log(`[download-user-data] fetchFromSupabase: ${table} returned status ${response.status}`);
      return [];
    }

    const data = await response.json();
    console.log(`[download-user-data] fetchFromSupabase: ${table} returned ${Array.isArray(data) ? data.length : 'non-array'} results`);
    return data;
  } catch (error) {
    console.error(`[download-user-data] fetchFromSupabase ERROR for ${table}:`, error);
    return [];
  }
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}
