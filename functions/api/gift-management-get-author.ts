interface Env {
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
}

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Max-Age': '86400',
};

export const onRequestOptions: PagesFunction<Env> = async () => {
  return new Response(null, { status: 204, headers: CORS_HEADERS });
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}

export const onRequestGet: PagesFunction<Env> = async ({ request, env }) => {
  try {
    if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) {
      console.error('[gift-management-get-author] Missing Supabase configuration');
      return json({ error: 'Server configuration error' }, 500);
    }

    const url = new URL(request.url);
    const token = url.searchParams.get('token');

    if (!token) {
      return json({ error: 'Token es requerido' }, 400);
    }

    console.log('[gift-management-get-author] Validating token...');

    // Validate token and get author_user_id
    const tokenResponse = await fetch(
      `${env.SUPABASE_URL}/rest/v1/gift_management_tokens?management_token=eq.${token}&select=*`,
      {
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          'Content-Type': 'application/json',
        },
      }
    );

    if (!tokenResponse.ok) {
      console.error('[gift-management-get-author] Failed to validate token');
      return json({ error: 'Error al validar token' }, 500);
    }

    const tokens = await tokenResponse.json();

    if (!Array.isArray(tokens) || tokens.length === 0) {
      console.log('[gift-management-get-author] Invalid token');
      return json({ error: 'Token inválido o expirado' }, 401);
    }

    const tokenData = tokens[0];
    const authorUserId = tokenData.author_user_id;

    // Update last_used_at
    await fetch(
      `${env.SUPABASE_URL}/rest/v1/gift_management_tokens?id=eq.${tokenData.id}`,
      {
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: JSON.stringify({
          last_used_at: new Date().toISOString(),
        }),
      }
    );

    // Get author data from auth.users
    console.log('[gift-management-get-author] Getting author data...');
    const userResponse = await fetch(
      `${env.SUPABASE_URL}/auth/v1/admin/users/${authorUserId}`,
      {
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          'Content-Type': 'application/json',
        },
      }
    );

    if (!userResponse.ok) {
      console.error('[gift-management-get-author] Failed to get author');
      return json({ error: 'Error al obtener datos del autor' }, 500);
    }

    const userData = await userResponse.json();

    // Get subscribers
    console.log('[gift-management-get-author] Getting subscribers...');
    const subscribersResponse = await fetch(
      `${env.SUPABASE_URL}/rest/v1/subscribers?author_id=eq.${authorUserId}&select=id,name,email,status,created_at`,
      {
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          'Content-Type': 'application/json',
        },
      }
    );

    const subscribers = subscribersResponse.ok ? await subscribersResponse.json() : [];

    console.log('[gift-management-get-author] Data retrieved successfully');

    return json({
      success: true,
      author: {
        email: userData.email,
        created_at: userData.created_at,
      },
      subscribers: subscribers.map((sub: any) => ({
        id: sub.id,
        name: sub.name,
        email: sub.email,
        status: sub.status,
        added_at: sub.created_at,
      })),
    });

  } catch (error) {
    console.error('[gift-management-get-author] Unexpected error:', error);
    return json({ error: 'Internal server error' }, 500);
  }
};
