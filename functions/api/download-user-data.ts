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
    const userProfileUrl = `${supabaseUrl}/rest/v1/users?id=eq.${userId}`;
    const userProfileRes = await fetch(userProfileUrl, {
      headers: {
        'Content-Type': 'application/json',
        'apikey': serviceKey,
        'Authorization': `Bearer ${serviceKey}`,
      },
    });

    let userName = 'Usuario';
    if (userProfileRes.ok) {
      const profiles = await userProfileRes.json();
      if (profiles && profiles.length > 0) {
        userName = profiles[0].name || 'Usuario';
      }
    }

    // Fetch stories - SIMPLE, no relacionados
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

    // Build MINIMAL data structure
    const completeData: any = {
      metadata: {
        exportado: new Date().toISOString(),
        usuario: user.email,
        nombre: userName,
        total_historias: stories.length,
        borradores: stories.filter((s: any) => !s.is_published).length,
        publicadas: stories.filter((s: any) => s.is_published).length,
      },
      historias: stories.map((story: any) => ({
        titulo: story.title || 'Sin título',
        contenido: story.content || '',
        extracto: story.excerpt || '',
        fecha_creacion: story.created_at,
        fecha_actualizacion: story.updated_at,
        is_published: story.is_published || false,
      }))
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
