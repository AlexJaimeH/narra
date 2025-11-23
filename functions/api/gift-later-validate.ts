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
    // Validate configuration
    if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) {
      console.error('[gift-later-validate] Missing Supabase configuration');
      return json({ error: 'Server configuration error' }, 500);
    }

    // Get token from query params
    const url = new URL(request.url);
    const token = url.searchParams.get('token');

    if (!token) {
      return json({ valid: false, error: 'Token no proporcionado' }, 400);
    }

    console.log(`[gift-later-validate] Validating token: ${token.substring(0, 8)}...`);

    // Query gift_purchases table
    const response = await fetch(
      `${env.SUPABASE_URL}/rest/v1/gift_purchases?activation_token=eq.${token}&select=*`,
      {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          'Content-Type': 'application/json',
        },
      }
    );

    if (!response.ok) {
      console.error('[gift-later-validate] Failed to query gift_purchases');
      return json({ valid: false, error: 'Error al validar token' }, 500);
    }

    const purchases = await response.json();

    if (!purchases || purchases.length === 0) {
      console.log('[gift-later-validate] Token not found');
      return json({ valid: false, error: 'Token no válido' }, 404);
    }

    const purchase = purchases[0];

    // Check if token has already been used
    if (purchase.token_used) {
      console.log('[gift-later-validate] Token already used');
      return json({ valid: false, error: 'Este regalo ya fue activado' }, 400);
    }

    // Check if it's a gift_later type
    if (purchase.purchase_type !== 'gift_later') {
      console.log('[gift-later-validate] Invalid purchase type');
      return json({ valid: false, error: 'Token no válido para activación' }, 400);
    }

    console.log('[gift-later-validate] Token is valid');
    return json({
      valid: true,
      buyerEmail: purchase.buyer_email,
    });

  } catch (error) {
    console.error('[gift-later-validate] Unexpected error:', error);
    return json({ valid: false, error: 'Error interno del servidor' }, 500);
  }
};
