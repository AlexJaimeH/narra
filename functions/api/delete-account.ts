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
      console.error('[delete-account] Missing Supabase credentials');
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
    const userEmail = user.email;

    if (!userId) {
      return json({ error: 'Usuario no encontrado' }, 404);
    }

    // Get email confirmation from request body
    const body = await request.json().catch(() => ({}));
    const confirmEmail = (body as any).email?.trim().toLowerCase();

    if (!confirmEmail || confirmEmail !== userEmail.toLowerCase()) {
      return json({ error: 'El correo electrónico no coincide' }, 400);
    }

    console.log(`[delete-account] Starting account deletion for user ${userId} (${userEmail})`);

    // Delete all user data in order (respecting foreign key constraints)
    const deletionSteps = [
      // 1. Delete story-related data first
      { table: 'story_comments', filter: `story_id.in.(select id from stories where author_id=eq.${userId})` },
      { table: 'story_reactions', filter: `story_id.in.(select id from stories where author_id=eq.${userId})` },
      { table: 'story_tags', filter: `story_id.in.(select id from stories where author_id=eq.${userId})` },
      { table: 'story_versions', filter: `story_id.in.(select id from stories where author_id=eq.${userId})` },
      { table: 'story_photos', filter: `story_id.in.(select id from stories where author_id=eq.${userId})` },
      { table: 'voice_recordings', filter: `story_id.in.(select id from stories where author_id=eq.${userId})` },

      // 2. Delete stories
      { table: 'stories', filter: `author_id=eq.${userId}` },

      // 3. Delete user-related data
      { table: 'tags', filter: `author_id=eq.${userId}` },
      { table: 'subscribers', filter: `author_id=eq.${userId}` },
      { table: 'subscriber_access_logs', filter: `author_id=eq.${userId}` },
      { table: 'user_feedback', filter: `user_id=eq.${userId}` },
      { table: 'user_settings', filter: `user_id=eq.${userId}` },

      // 4. Delete user profile
      { table: 'users', filter: `id=eq.${userId}` },
    ];

    let deletedCounts: Record<string, number> = {};

    for (const step of deletionSteps) {
      try {
        const deleteUrl = `${supabaseUrl}/rest/v1/${step.table}?${step.filter}`;
        const response = await fetch(deleteUrl, {
          method: 'DELETE',
          headers: {
            'Content-Type': 'application/json',
            'apikey': serviceKey,
            'Authorization': `Bearer ${serviceKey}`,
            'Prefer': 'return=representation',
          },
        });

        if (response.ok) {
          const deleted = await response.json();
          deletedCounts[step.table] = Array.isArray(deleted) ? deleted.length : 0;
          console.log(`[delete-account] Deleted ${deletedCounts[step.table]} records from ${step.table}`);
        } else {
          console.error(`[delete-account] Failed to delete from ${step.table}: ${response.status}`);
        }
      } catch (error) {
        console.error(`[delete-account] Error deleting from ${step.table}:`, error);
      }
    }

    // Delete user from Supabase Auth (this will cascade to auth-related tables)
    try {
      const deleteAuthUrl = `${supabaseUrl}/auth/v1/admin/users/${userId}`;
      const authResponse = await fetch(deleteAuthUrl, {
        method: 'DELETE',
        headers: {
          'apikey': serviceKey,
          'Authorization': `Bearer ${serviceKey}`,
        },
      });

      if (authResponse.ok) {
        console.log(`[delete-account] Deleted auth user ${userId}`);
      } else {
        console.error(`[delete-account] Failed to delete auth user: ${authResponse.status}`);
      }
    } catch (error) {
      console.error('[delete-account] Error deleting auth user:', error);
    }

    console.log(`[delete-account] Account deletion completed for ${userEmail}`, deletedCounts);

    return json({
      success: true,
      message: 'Cuenta eliminada exitosamente',
      deletedCounts,
    });

  } catch (error) {
    console.error('[delete-account] Error:', error);
    return json({
      error: 'Error al eliminar cuenta',
      detail: String(error)
    }, 500);
  }
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}
