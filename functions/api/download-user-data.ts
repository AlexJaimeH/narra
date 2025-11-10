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

    // Fetch user profile
    const userProfile = await fetchFromSupabase(supabaseUrl, serviceKey, 'users', `id=eq.${userId}`);
    const userName = (userProfile[0]?.name || 'Usuario').trim();
    console.log('[download-user-data] User name:', userName);

    // Fetch stories
    const stories = await fetchFromSupabase(
      supabaseUrl,
      serviceKey,
      'stories',
      `author_id=eq.${userId}&order=created_at.desc`
    );

    // Build complete data structure
    const completeData: any = {
      metadata: {
        exportado: new Date().toISOString(),
        usuario: user.email,
        nombre: userName,
        total_historias: stories.length,
      },
      borradores: [],
      publicadas: []
    };

    // Process each story
    for (let i = 0; i < stories.length; i++) {
      const story = stories[i];

      // Fetch related data
      const [photos, recordings, versions] = await Promise.all([
        fetchFromSupabase(supabaseUrl, serviceKey, 'story_photos', `story_id=eq.${story.id}&order=position.asc`),
        fetchFromSupabase(supabaseUrl, serviceKey, 'voice_recordings', `story_id=eq.${story.id}&order=created_at.asc`),
        fetchFromSupabase(supabaseUrl, serviceKey, 'story_versions', `story_id=eq.${story.id}&order=version_number.asc`),
      ]);

      const storyData = {
        titulo: story.title || 'Sin título',
        contenido: stripHtml(story.content || ''),
        extracto: story.excerpt || '',
        transcripcion_voz: story.voice_transcript ? stripHtml(story.voice_transcript) : '',
        fecha_historia: story.story_date || '',
        fecha_creacion: story.created_at,
        fecha_actualizacion: story.updated_at,
        fecha_publicacion: story.published_at || '',
        numero_palabras: story.word_count || 0,
        imagenes: photos.map((p: any) => ({
          url: p.photo_url,
          posicion: p.position
        })),
        grabaciones: recordings.map((r: any) => ({
          url: r.audio_url,
          fecha: r.created_at
        })),
        versiones: versions.map((v: any) => ({
          numero: v.version_number,
          contenido: stripHtml(v.content || ''),
          fecha: v.created_at
        }))
      };

      if (story.is_published) {
        completeData.publicadas.push(storyData);
      } else {
        completeData.borradores.push(storyData);
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

    // Generate filename
    const now = new Date();
    const yy = String(now.getFullYear()).slice(-2);
    const mm = now.getMonth() + 1;
    const dd = now.getDate();
    const mmStr = mm < 10 ? '0' + mm : String(mm);
    const ddStr = dd < 10 ? '0' + dd : String(dd);
    const sanitizedName = sanitizeFileName(userName);
    const filename = `${yy}${mmStr}${ddStr} Narra - ${sanitizedName}.json`;

    // Return as JSON download
    return new Response(JSON.stringify(completeData, null, 2), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
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
