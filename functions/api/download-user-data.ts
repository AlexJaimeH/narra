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
      console.error('[download-user-data] Missing Supabase credentials');
      return json({
        error: 'Configuración de servidor incorrecta',
      }, 500);
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

    // Import JSZip dynamically
    const JSZip = (await import('https://esm.sh/jszip@3.10.1')).default;
    const zip = new JSZip();

    // Fetch user data
    const [userProfile, userSettings, stories] = await Promise.all([
      fetchFromSupabase(supabaseUrl, serviceKey, 'users', `id=eq.${userId}`),
      fetchFromSupabase(supabaseUrl, serviceKey, 'user_settings', `user_id=eq.${userId}`),
      fetchFromSupabase(supabaseUrl, serviceKey, 'stories', `author_id=eq.${userId}&order=created_at.desc`),
    ]);

    // Create root folders
    const draftFolder = zip.folder('borradores');
    const publishedFolder = zip.folder('publicadas');

    // Process each story
    for (const story of stories) {
      const isPublished = story.is_published;
      const parentFolder = isPublished ? publishedFolder : draftFolder;

      // Sanitize story title for folder name
      const storyTitle = sanitizeFileName(story.title || 'Sin título');
      const storyFolder = parentFolder?.folder(storyTitle);

      if (!storyFolder) continue;

      // Fetch related data for this story
      const [photos, recordings, versions] = await Promise.all([
        fetchFromSupabase(supabaseUrl, serviceKey, 'story_photos', `story_id=eq.${story.id}&order=position.asc`),
        fetchFromSupabase(supabaseUrl, serviceKey, 'voice_recordings', `story_id=eq.${story.id}&order=created_at.asc`),
        fetchFromSupabase(supabaseUrl, serviceKey, 'story_versions', `story_id=eq.${story.id}&order=version_number.asc`),
      ]);

      // Create main story text file
      const storyText = createStoryText(story);
      storyFolder.file('historia.txt', storyText);

      // Download and add images if they exist
      if (photos.length > 0) {
        const imagesFolder = storyFolder.folder('imagenes');
        for (let i = 0; i < photos.length; i++) {
          const photo = photos[i];
          try {
            const imageData = await downloadFile(photo.photo_url);
            if (imageData) {
              const extension = getFileExtension(photo.photo_url) || 'jpg';
              imagesFolder?.file(`imagen-${i + 1}.${extension}`, imageData, { binary: true });
            }
          } catch (error) {
            console.error(`[download-user-data] Error downloading image: ${error}`);
            // Add a text file indicating the image URL if download fails
            imagesFolder?.file(`imagen-${i + 1}-url.txt`, photo.photo_url);
          }
        }
      }

      // Download and add recordings if they exist
      if (recordings.length > 0) {
        const recordingsFolder = storyFolder.folder('grabaciones');
        for (let i = 0; i < recordings.length; i++) {
          const recording = recordings[i];
          if (recording.audio_url) {
            try {
              const audioData = await downloadFile(recording.audio_url);
              if (audioData) {
                const extension = getFileExtension(recording.audio_url) || 'mp3';
                recordingsFolder?.file(`grabacion-${i + 1}.${extension}`, audioData, { binary: true });
              }
            } catch (error) {
              console.error(`[download-user-data] Error downloading recording: ${error}`);
              // Add a text file indicating the recording URL if download fails
              recordingsFolder?.file(`grabacion-${i + 1}-url.txt`, recording.audio_url);
            }
          }
        }
      }

      // Add version history if it exists
      if (versions.length > 0) {
        const versionsFolder = storyFolder.folder('versiones');
        for (let i = 0; i < versions.length; i++) {
          const version = versions[i];
          const versionText = createVersionText(version, i + 1);
          versionsFolder?.file(`version-${version.version_number || (i + 1)}.txt`, versionText);
        }
      }
    }

    // Add metadata file in root
    const metadata = {
      exportado: new Date().toISOString(),
      usuario: user.email,
      total_historias: stories.length,
      borradores: stories.filter((s: any) => !s.is_published).length,
      publicadas: stories.filter((s: any) => s.is_published).length,
    };
    zip.file('info.txt', JSON.stringify(metadata, null, 2));

    // Generate ZIP
    const zipBlob = await zip.generateAsync({
      type: 'uint8array',
      compression: 'DEFLATE',
      compressionOptions: { level: 6 }
    });

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
    console.error('[download-user-data] Error:', error);
    return json({ error: 'Error al generar descarga de datos', detail: String(error) }, 500);
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
