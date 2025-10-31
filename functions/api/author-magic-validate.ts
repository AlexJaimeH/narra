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
    // Validar configuración
    if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) {
      console.error('[author-magic-validate] Missing Supabase configuration');
      return json({ error: 'Server configuration error' }, 500);
    }

    // Parsear el body
    const payload = await request.json().catch(() => null);
    if (!payload || typeof payload !== 'object') {
      return json({ error: 'Invalid request body' }, 400);
    }

    const token = typeof (payload as any).token === 'string'
      ? (payload as any).token.trim()
      : '';

    if (!token) {
      return json({ error: 'Token is required' }, 400);
    }

    console.log('[author-magic-validate] Validating token');

    // Obtener información del request
    const clientIP = request.headers.get('cf-connecting-ip') || request.headers.get('x-forwarded-for') || null;
    const userAgent = request.headers.get('user-agent') || null;

    // Llamar a la función de validación de PostgreSQL
    const validateResponse = await fetch(
      `${env.SUPABASE_URL}/rest/v1/rpc/validate_author_magic_link`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          p_token: token,
          p_ip_address: clientIP,
          p_user_agent: userAgent,
        }),
      }
    );

    if (!validateResponse.ok) {
      const errorText = await validateResponse.text();
      console.error('[author-magic-validate] Validation failed:', errorText);
      return json({ error: 'Failed to validate magic link' }, 500);
    }

    const validationResult = await validateResponse.json();

    console.log('[author-magic-validate] Validation result:', validationResult);

    // Si el magic link es inválido
    if (validationResult.status === 'error') {
      return json({
        error: validationResult.message || 'Magic link inválido o expirado',
        expired: true,
      }, 400);
    }

    const email = validationResult.action === 'register'
      ? validationResult.email
      : validationResult.user?.email;

    if (!email) {
      return json({ error: 'No email found in validation result' }, 500);
    }

    // Generar link de magic link de Supabase para obtener el token_hash
    console.log('[author-magic-validate] Generating Supabase magic link for:', email);

    const generateLinkResponse = await fetch(
      `${env.SUPABASE_URL}/auth/v1/admin/generate_link`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          type: 'magiclink',
          email: email,
        }),
      }
    );

    if (!generateLinkResponse.ok) {
      const errorText = await generateLinkResponse.text();
      console.error('[author-magic-validate] Failed to generate Supabase link:', errorText);
      return json({ error: 'Failed to generate authentication link' }, 500);
    }

    const linkData = await generateLinkResponse.json();
    console.log('[author-magic-validate] Generated link data:', linkData);

    // Extraer access_token y refresh_token de la respuesta
    let accessToken = null;
    let refreshToken = null;
    let expiresIn = 3600;

    try {
      if (linkData.properties) {
        accessToken = linkData.properties.access_token;
        refreshToken = linkData.properties.refresh_token;
        expiresIn = linkData.properties.expires_in || 3600;
      }
    } catch (e) {
      console.error('[author-magic-validate] Error parsing link data:', e);
    }

    if (!accessToken || !refreshToken) {
      console.error('[author-magic-validate] No tokens found in response');
      return json({ error: 'Failed to generate authentication tokens' }, 500);
    }

    console.log('[author-magic-validate] Successfully generated session tokens');

    // Si es registro, crear el usuario primero
    if (validationResult.action === 'register') {
      console.log('[author-magic-validate] Creating new user account');

      const createUserResponse = await fetch(
        `${env.SUPABASE_URL}/auth/v1/admin/users`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
            'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            email: email,
            email_confirm: true,
            user_metadata: {
              name: email.split('@')[0],
            },
          }),
        }
      );

      if (!createUserResponse.ok) {
        const errorText = await createUserResponse.text();
        console.error('[author-magic-validate] Failed to create user:', errorText);
        // No fallar si el usuario ya existe
      }
    }

    // Devolver los tokens de sesión para que Flutter los use con setSession
    return json({
      success: true,
      action: validationResult.action,
      email: email,
      user: validationResult.user || {
        email: email,
        name: email.split('@')[0],
      },
      auth: {
        access_token: accessToken,
        refresh_token: refreshToken,
        expires_in: expiresIn,
        token_type: 'bearer',
      },
    });

  } catch (error) {
    console.error('[author-magic-validate] Unexpected error:', error);
    return json({ error: 'Internal server error', details: String(error) }, 500);
  }
};
