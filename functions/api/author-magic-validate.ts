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

    // Si necesitamos crear un nuevo usuario (registro)
    if (validationResult.action === 'register') {
      console.log('[author-magic-validate] Creating new user:', validationResult.email);

      // Crear usuario con Supabase Auth
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
            email: validationResult.email,
            email_confirm: true,
            user_metadata: {
              name: validationResult.email.split('@')[0],
            },
          }),
        }
      );

      if (!createUserResponse.ok) {
        const errorText = await createUserResponse.text();
        console.error('[author-magic-validate] Failed to create user:', errorText);
        return json({ error: 'Failed to create user account' }, 500);
      }

      const newUser = await createUserResponse.json();

      // Generar sesión para el nuevo usuario
      const sessionResponse = await fetch(
        `${env.SUPABASE_URL}/auth/v1/token?grant_type=password`,
        {
          method: 'POST',
          headers: {
            'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            email: validationResult.email,
            password: token, // Usar el token temporalmente, luego lo cambiaremos
          }),
        }
      );

      // En caso de que falle la generación de sesión automática,
      // generar un link de sesión manual
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
            email: validationResult.email,
          }),
        }
      );

      if (!generateLinkResponse.ok) {
        console.error('[author-magic-validate] Failed to generate session link');
        return json({ error: 'Failed to generate session' }, 500);
      }

      const linkData = await generateLinkResponse.json();

      return json({
        success: true,
        action: 'register',
        user: {
          id: newUser.id,
          email: newUser.email,
          name: newUser.user_metadata?.name || newUser.email.split('@')[0],
        },
        session: linkData,
      });
    }

    // Si es un usuario existente (login)
    if (validationResult.action === 'login' && validationResult.user) {
      console.log('[author-magic-validate] Logging in user:', validationResult.user.email);

      // Generar un link de sesión para el usuario existente
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
            email: validationResult.user.email,
          }),
        }
      );

      if (!generateLinkResponse.ok) {
        const errorText = await generateLinkResponse.text();
        console.error('[author-magic-validate] Failed to generate session link:', errorText);
        return json({ error: 'Failed to generate session' }, 500);
      }

      const linkData = await generateLinkResponse.json();

      return json({
        success: true,
        action: 'login',
        user: validationResult.user,
        session: linkData,
      });
    }

    // Caso inesperado
    console.error('[author-magic-validate] Unexpected validation result:', validationResult);
    return json({ error: 'Unexpected validation result' }, 500);

  } catch (error) {
    console.error('[author-magic-validate] Unexpected error:', error);
    return json({ error: 'Internal server error' }, 500);
  }
};
