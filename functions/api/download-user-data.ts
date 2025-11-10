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

    // Fetch stories with user_id
    const stories = await fetchFromSupabase(
      supabaseUrl,
      serviceKey,
      'stories',
      `user_id=eq.${userId}&order=created_at.desc`
    );

    // Build complete data structure for client-side ZIP generation
    const completeData: any = {
      metadata: {
        exportado: new Date().toISOString(),
        usuario: user.email,
        nombre: userName,
        total_historias: stories.length,
        borradores: stories.filter((s: any) => !s.is_published).length,
        publicadas: stories.filter((s: any) => s.is_published).length,
      },
      historias: []
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

      completeData.historias.push({
        titulo: story.title || 'Sin título',
        contenido: story.content || '',
        extracto: story.excerpt || '',
        transcripcion_voz: story.voice_transcript || '',
        fecha_historia: story.story_date || '',
        fecha_creacion: story.created_at,
        fecha_actualizacion: story.updated_at,
        fecha_publicacion: story.published_at || '',
        numero_palabras: story.word_count || 0,
        is_published: story.is_published || false,
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
          contenido: v.content || '',
          fecha: v.created_at
        }))
      });
    }

    // Return as JSON (client will generate ZIP)
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
      detail: error?.message || String(error)
    }, 500);
  }
};

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
