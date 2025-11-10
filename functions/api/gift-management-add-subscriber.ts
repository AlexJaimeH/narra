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

function generateToken(): string {
  const array = new Uint8Array(32);
  crypto.getRandomValues(array);
  return Array.from(array, byte => byte.toString(16).padStart(2, '0')).join('');
}

export const onRequestPost: PagesFunction<Env> = async ({ request, env }) => {
  try {
    if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) {
      console.error('[gift-management-add-subscriber] Missing Supabase configuration');
      return json({ error: 'Server configuration error' }, 500);
    }

    const payload = await request.json().catch(() => null);
    if (!payload || typeof payload !== 'object') {
      return json({ error: 'Invalid request body' }, 400);
    }

    const token = (payload as any).token as string;
    const name = ((payload as any).name as string || '').trim();
    const email = ((payload as any).email as string || '').toLowerCase().trim();

    if (!token || !name || !email) {
      return json({ error: 'Token, nombre y email son requeridos' }, 400);
    }

    if (!email.includes('@')) {
      return json({ error: 'Email válido es requerido' }, 400);
    }

    console.log('[gift-management-add-subscriber] Validating token...');

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

    // Check if subscriber already exists for this author
    console.log('[gift-management-add-subscriber] Checking for duplicate subscriber...');
    const existingSubResponse = await fetch(
      `${env.SUPABASE_URL}/rest/v1/subscribers?user_id=eq.${authorUserId}&email=eq.${email}&select=id`,
      {
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          'Content-Type': 'application/json',
        },
      }
    );

    if (existingSubResponse.ok) {
      const existing = await existingSubResponse.json();
      if (existing && existing.length > 0) {
        return json({ error: 'Este suscriptor ya existe para este autor' }, 400);
      }
    }

    // Generate access_token for the subscriber
    const accessToken = generateToken();

    // Add subscriber
    console.log('[gift-management-add-subscriber] Adding subscriber...');
    const subscriberData = {
      user_id: authorUserId,
      name: name,
      email: email,
      status: 'confirmed',
      access_token: accessToken,
      access_token_created_at: new Date().toISOString(),
      created_at: new Date().toISOString(),
    };

    const insertResponse = await fetch(
      `${env.SUPABASE_URL}/rest/v1/subscribers`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          'Content-Type': 'application/json',
          'Prefer': 'return=representation',
        },
        body: JSON.stringify(subscriberData),
      }
    );

    if (!insertResponse.ok) {
      const errorText = await insertResponse.text();
      console.error('[gift-management-add-subscriber] Failed to add subscriber:', errorText);
      return json({ error: 'Error al agregar suscriptor' }, 500);
    }

    const newSubscriber = await insertResponse.json();

    console.log('[gift-management-add-subscriber] Subscriber added successfully');

    return json({
      success: true,
      message: 'Suscriptor agregado exitosamente',
      subscriber: newSubscriber[0],
    });

  } catch (error) {
    console.error('[gift-management-add-subscriber] Unexpected error:', error);
    return json({ error: 'Internal server error' }, 500);
  }
};
