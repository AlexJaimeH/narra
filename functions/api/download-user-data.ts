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

    // Fetch user profile from user_settings
    const userSettingsUrl = `${supabaseUrl}/rest/v1/user_settings?user_id=eq.${userId}`;
    const userSettingsRes = await fetch(userSettingsUrl, {
      headers: {
        'Content-Type': 'application/json',
        'apikey': serviceKey,
        'Authorization': `Bearer ${serviceKey}`,
      },
    });

    let userName = 'Usuario';
    if (userSettingsRes.ok) {
      const settings = await userSettingsRes.json();
      if (settings && settings.length > 0) {
        userName = settings[0].public_author_name || user.user_metadata?.full_name || user.email || 'Usuario';
      }
    } else {
      // Fallback to user metadata
      userName = user.user_metadata?.full_name || user.email || 'Usuario';
    }

    // Fetch stories with all related data
    const storiesUrl = `${supabaseUrl}/rest/v1/stories?user_id=eq.${userId}&order=created_at.desc`;
    const storiesRes = await fetch(storiesUrl, {
      headers: {
        'Content-Type': 'application/json',
        'apikey': serviceKey,
        'Authorization': `Bearer ${serviceKey}`,
      },
    });

    let stories = [];
    if (storiesRes.ok) {
      stories = await storiesRes.json();
    }

    // Fetch all related data for stories
    const storyIds = stories.map((s: any) => s.id);

    // Fetch photos
    const photosUrl = `${supabaseUrl}/rest/v1/story_photos?story_id=in.(${storyIds.join(',')})&order=position.asc`;
    const photosRes = await fetch(photosUrl, {
      headers: {
        'Content-Type': 'application/json',
        'apikey': serviceKey,
        'Authorization': `Bearer ${serviceKey}`,
      },
    });
    const allPhotos = photosRes.ok ? await photosRes.json() : [];

    // Fetch recordings
    const recordingsUrl = `${supabaseUrl}/rest/v1/voice_recordings?story_id=in.(${storyIds.join(',')})&order=created_at.asc`;
    const recordingsRes = await fetch(recordingsUrl, {
      headers: {
        'Content-Type': 'application/json',
        'apikey': serviceKey,
        'Authorization': `Bearer ${serviceKey}`,
      },
    });
    const allRecordings = recordingsRes.ok ? await recordingsRes.json() : [];

    // Fetch versions
    const versionsUrl = `${supabaseUrl}/rest/v1/story_versions?story_id=in.(${storyIds.join(',')})&order=saved_at.asc`;
    const versionsRes = await fetch(versionsUrl, {
      headers: {
        'Content-Type': 'application/json',
        'apikey': serviceKey,
        'Authorization': `Bearer ${serviceKey}`,
      },
    });
    const allVersions = versionsRes.ok ? await versionsRes.json() : [];

    // Build complete data structure
    const completeData: any = {
      metadata: {
        exportado: new Date().toISOString(),
        usuario: user.email,
        nombre: userName,
        total_historias: stories.length,
        borradores: stories.filter((s: any) => s.status !== 'published').length,
        publicadas: stories.filter((s: any) => s.status === 'published').length,
      },
      historias: stories.map((story: any) => {
        const photos = allPhotos.filter((p: any) => p.story_id === story.id);
        const recordings = allRecordings.filter((r: any) => r.story_id === story.id);
        const versions = allVersions.filter((v: any) => v.story_id === story.id);

        return {
          titulo: story.title || 'Sin título',
          contenido: story.content || '',
          extracto: story.excerpt || '',
          fecha_creacion: story.created_at,
          fecha_actualizacion: story.updated_at,
          fecha_publicacion: story.published_at,
          is_published: story.status === 'published',
          status: story.status || 'draft',
          fotos: photos.map((p: any) => ({
            url: p.photo_url || p.url || null,
            caption: p.caption || '',
            position: p.position,
          })),
          grabaciones: recordings.map((r: any) => ({
            url: r.audio_url || r.url || null,
            titulo: r.story_title || '',
            transcripcion: r.transcript || '',
            duracion: r.duration_seconds,
            fecha: r.created_at,
          })),
          versiones: versions.map((v: any) => ({
            titulo: v.title || '',
            contenido: v.content || '',
            razon: v.reason || '',
            fecha: v.saved_at,
          })),
        };
      })
    };

    // Return as JSON
    return new Response(JSON.stringify(completeData), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        ...CORS_HEADERS,
      },
    });

  } catch (error: any) {
    return json({
      error: 'Error al generar descarga de datos',
      detail: error?.message || String(error),
      stack: error?.stack || ''
    }, 500);
  }
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}
