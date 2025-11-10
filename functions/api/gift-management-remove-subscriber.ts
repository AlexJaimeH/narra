interface Env {
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
}

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
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

export const onRequestPost: PagesFunction<Env> = async ({ request, env }) => {
  try {
    if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) {
      console.error('[gift-management-remove-subscriber] Missing Supabase configuration');
      return json({ error: 'Server configuration error' }, 500);
    }

    const payload = await request.json().catch(() => null);
    if (!payload || typeof payload !== 'object') {
      return json({ error: 'Invalid request body' }, 400);
    }

    const token = (payload as any).token as string;
    const subscriberId = (payload as any).subscriberId as string;

    if (!token || !subscriberId) {
      return json({ error: 'Token y subscriberId son requeridos' }, 400);
    }

    console.log('[gift-management-remove-subscriber] Validating token...');

    // Validate token
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
      return json({ error: 'Error al validar token' }, 500);
    }

    const tokens = await tokenResponse.json();

    if (!Array.isArray(tokens) || tokens.length === 0) {
      return json({ error: 'Token inválido' }, 401);
    }

    const tokenData = tokens[0];
    const authorUserId = tokenData.author_user_id;

    // Verify subscriber belongs to this author
    console.log('[gift-management-remove-subscriber] Verifying subscriber ownership...');
    const subscriberResponse = await fetch(
      `${env.SUPABASE_URL}/rest/v1/subscribers?id=eq.${subscriberId}&user_id=eq.${authorUserId}&select=id`,
      {
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          'Content-Type': 'application/json',
        },
      }
    );

    if (!subscriberResponse.ok) {
      return json({ error: 'Error al verificar suscriptor' }, 500);
    }

    const subscribers = await subscriberResponse.json();

    if (!Array.isArray(subscribers) || subscribers.length === 0) {
      return json({ error: 'Suscriptor no encontrado o no pertenece a este autor' }, 404);
    }

    // Delete subscriber
    console.log('[gift-management-remove-subscriber] Deleting subscriber...');
    const deleteResponse = await fetch(
      `${env.SUPABASE_URL}/rest/v1/subscribers?id=eq.${subscriberId}`,
      {
        method: 'DELETE',
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
      }
    );

    if (!deleteResponse.ok) {
      const errorText = await deleteResponse.text();
      console.error('[gift-management-remove-subscriber] Failed to delete subscriber:', errorText);
      return json({ error: 'Error al eliminar suscriptor' }, 500);
    }

    console.log('[gift-management-remove-subscriber] Subscriber removed successfully');

    return json({
      success: true,
      message: 'Suscriptor eliminado exitosamente',
    });

  } catch (error) {
    console.error('[gift-management-remove-subscriber] Unexpected error:', error);
    return json({ error: 'Internal server error' }, 500);
  }
};
