interface Env {
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  RESEND_API_KEY: string;
  RESEND_FROM_EMAIL: string;
  APP_URL?: string;
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

function generateSecureToken(): string {
  const array = new Uint8Array(32);
  crypto.getRandomValues(array);
  return Array.from(array, byte => byte.toString(16).padStart(2, '0')).join('');
}

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
      console.error('[author-magic-link] Missing Supabase configuration');
      return json({ error: 'Server configuration error' }, 500);
    }

    if (!env.RESEND_API_KEY || !env.RESEND_FROM_EMAIL) {
      console.error('[author-magic-link] Missing email configuration');
      return json({ error: 'Email service not configured' }, 500);
    }

    // Parsear el body
    const payload = await request.json().catch(() => null);
    if (!payload || typeof payload !== 'object') {
      return json({ error: 'Invalid request body' }, 400);
    }

    const email = typeof (payload as any).email === 'string'
      ? (payload as any).email.trim().toLowerCase()
      : '';

    if (!email || !email.includes('@')) {
      return json({ error: 'Email válido es requerido' }, 400);
    }

    console.log('[author-magic-link] Generating magic link for:', email);

    // Buscar si el usuario ya existe
    const userCheckResponse = await fetch(
      `${env.SUPABASE_URL}/auth/v1/admin/users`,
      {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          'Content-Type': 'application/json',
        },
      }
    );

    let existingUser: any = null;
    if (userCheckResponse.ok) {
      const usersData = await userCheckResponse.json();
      const users = usersData.users || [];
      existingUser = users.find((u: any) => u.email?.toLowerCase() === email);
    }

    // Generar token único
    const token = generateSecureToken();
    const now = new Date().toISOString();
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000).toISOString(); // 15 minutos

    // Insertar magic link en la base de datos
    const insertResponse = await fetch(
      `${env.SUPABASE_URL}/rest/v1/author_magic_links`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          'Content-Type': 'application/json',
          'Prefer': 'return=representation',
        },
        body: JSON.stringify({
          email: email,
          token: token,
          user_id: existingUser?.id || null,
          created_at: now,
          expires_at: expiresAt,
        }),
      }
    );

    if (!insertResponse.ok) {
      const errorText = await insertResponse.text();
      console.error('[author-magic-link] Failed to insert magic link:', errorText);
      return json({ error: 'Failed to generate magic link' }, 500);
    }

    // Construir el link de magic login
    const appUrl = env.APP_URL || 'https://narra-8m1.pages.dev';
    const magicLink = `${appUrl}/app/auth/magic?token=${token}`;

    // Enviar email
    const emailHtml = buildMagicLinkEmail(email, magicLink, !!existingUser);
    const emailText = buildMagicLinkPlainText(email, magicLink, !!existingUser);

    const emailResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${env.RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: env.RESEND_FROM_EMAIL,
        to: [email],
        subject: existingUser
          ? 'Tu enlace para iniciar sesión en Narra'
          : 'Bienvenido a Narra - Tu enlace para comenzar',
        html: emailHtml,
        text: emailText,
        tags: [{ name: 'type', value: 'author-magic-link' }],
      }),
    });

    if (!emailResponse.ok) {
      const errorText = await emailResponse.text();
      console.error('[author-magic-link] Failed to send email:', errorText);
      return json({ error: 'Failed to send email' }, 500);
    }

    console.log('[author-magic-link] Magic link sent successfully to:', email);

    return json({
      success: true,
      message: 'Te hemos enviado un correo con un enlace para iniciar sesión',
      isNewUser: !existingUser,
    });

  } catch (error) {
    console.error('[author-magic-link] Unexpected error:', error);
    return json({ error: 'Internal server error' }, 500);
  }
};

function buildMagicLinkEmail(email: string, magicLink: string, isExistingUser: boolean): string {
  const greeting = isExistingUser
    ? '¡Hola de nuevo!'
    : '¡Bienvenido a Narra!';

  const mainMessage = isExistingUser
    ? 'Recibimos tu solicitud para iniciar sesión. Haz clic en el botón de abajo para acceder a tu cuenta de Narra.'
    : 'Estamos emocionados de que comiences a compartir tus historias. Haz clic en el botón de abajo para comenzar.';

  return `<!DOCTYPE html>
<html lang="es">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Tu enlace para ${isExistingUser ? 'iniciar sesión' : 'comenzar'} en Narra</title>
  </head>
  <body style="margin:0;padding:0;background:linear-gradient(135deg, #fdfbf7 0%, #f0ebe3 100%);font-family:-apple-system,BlinkMacSystemFont,'Segoe UI','Helvetica Neue',Arial,sans-serif;color:#2d2a26;">
    <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="max-width:660px;margin:40px auto;padding:0 20px;">
      <tr>
        <td>
          <!-- Logo/Brand -->
          <div style="text-align:center;margin-bottom:32px;">
            <div style="display:inline-block;background:linear-gradient(135deg, #4DB3A8 0%, #38827A 100%);color:#ffffff;font-weight:800;font-size:24px;padding:14px 28px;border-radius:16px;letter-spacing:-0.02em;box-shadow:0 8px 24px rgba(77,179,168,0.25);">
              📖 Narra
            </div>
          </div>

          <!-- Main Card -->
          <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="background:#ffffff;border-radius:28px;box-shadow:0 20px 60px rgba(0,0,0,0.08);overflow:hidden;">
            <tr>
              <td style="padding:0;">
                <!-- Header Section -->
                <div style="background:linear-gradient(135deg, #4DB3A8 0%, #38827A 100%);padding:48px 36px;text-align:center;">
                  <h1 style="font-size:36px;line-height:1.2;margin:0;font-weight:800;color:#ffffff;text-shadow:0 2px 8px rgba(0,0,0,0.15);">${greeting}</h1>
                </div>

                <!-- Content Section -->
                <div style="padding:48px 36px;">
                  <p style="margin:0 0 28px 0;font-size:19px;line-height:1.6;color:#374151;font-weight:400;">${mainMessage}</p>

                  <!-- Info Box -->
                  <div style="background:linear-gradient(135deg, #fef3c7 0%, #fde68a 100%);border-left:6px solid #f59e0b;border-radius:20px;padding:28px;margin:32px 0;">
                    <p style="margin:0 0 12px 0;font-size:17px;line-height:1.6;color:#78350f;font-weight:700;">
                      🔒 Tu enlace es seguro y personal
                    </p>
                    <p style="margin:0;font-size:16px;line-height:1.65;color:#92400e;">
                      Este enlace es único para <strong>${email}</strong> y expira en <strong>15 minutos</strong> por tu seguridad.
                    </p>
                  </div>

                  <!-- CTA Button -->
                  <div style="text-align:center;margin:48px 0;">
                    <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto;">
                      <tr>
                        <td style="border-radius:20px;background:linear-gradient(135deg, #4DB3A8 0%, #38827A 100%);box-shadow:0 12px 32px rgba(77,179,168,0.4);">
                          <a href="${magicLink}" style="display:inline-block;color:#ffffff;text-decoration:none;font-weight:700;font-size:19px;padding:22px 48px;border-radius:20px;letter-spacing:0.01em;">
                            ${isExistingUser ? '🔑 Iniciar Sesión' : '🎉 Comenzar Mi Viaje'}
                          </a>
                        </td>
                      </tr>
                    </table>
                  </div>

                  <!-- Explanation -->
                  <div style="background:#f9fafb;border-radius:20px;padding:28px;margin:32px 0;">
                    <p style="margin:0 0 16px 0;font-size:16px;line-height:1.6;color:#374151;font-weight:600;">
                      ¿Cómo funciona?
                    </p>
                    <ol style="margin:0;padding-left:24px;font-size:15px;line-height:1.8;color:#4b5563;">
                      <li style="margin-bottom:10px;">Haz clic en el botón de arriba</li>
                      <li style="margin-bottom:10px;">Serás llevado directamente a tu cuenta de Narra</li>
                      <li style="margin-bottom:0;">${isExistingUser ? 'Comienza a gestionar tus historias' : 'Completa tu perfil y crea tu primera historia'}</li>
                    </ol>
                  </div>

                  <!-- Alternative Link -->
                  <div style="background:#fef2f2;border:2px solid #fee2e2;border-radius:16px;padding:24px;margin:32px 0 0 0;">
                    <p style="margin:0 0 12px 0;font-size:14px;color:#991b1b;font-weight:600;">¿El botón no funciona?</p>
                    <p style="margin:0 0 8px 0;font-size:13px;color:#7f1d1d;">Copia y pega este enlace en tu navegador:</p>
                    <p style="margin:0;font-size:13px;word-break:break-all;"><a href="${magicLink}" style="color:#dc2626;text-decoration:none;">${magicLink}</a></p>
                  </div>
                </div>

                <!-- Footer -->
                <div style="background:#fafaf9;padding:36px;border-top:2px solid #e7e5e4;text-align:center;">
                  <p style="margin:0 0 16px 0;font-size:15px;line-height:1.6;color:#78716c;">
                    ${isExistingUser
                      ? '¿No solicitaste este enlace? Puedes ignorar este correo de forma segura.'
                      : '¿Recibiste este correo por error? Puedes ignorarlo de forma segura.'}
                  </p>
                  <p style="margin:0;font-size:13px;color:#a8a29e;line-height:1.6;">
                    Este es un correo automático de Narra. Por favor no respondas a este mensaje.
                  </p>
                </div>
              </td>
            </tr>
          </table>

          <!-- Bottom Spacing -->
          <div style="height:40px;"></div>
        </td>
      </tr>
    </table>
  </body>
</html>`;
}

function buildMagicLinkPlainText(email: string, magicLink: string, isExistingUser: boolean): string {
  const greeting = isExistingUser ? '¡Hola de nuevo!' : '¡Bienvenido a Narra!';

  const lines = [
    greeting,
    '',
    isExistingUser
      ? 'Recibimos tu solicitud para iniciar sesión en Narra.'
      : 'Estamos emocionados de que comiences a compartir tus historias en Narra.',
    '',
    'Haz clic en el siguiente enlace para continuar:',
    magicLink,
    '',
    `Este enlace es único para ${email} y expira en 15 minutos por tu seguridad.`,
    '',
    isExistingUser
      ? '¿No solicitaste este enlace? Puedes ignorar este correo de forma segura.'
      : '¿Recibiste este correo por error? Puedes ignorarlo de forma segura.',
  ];

  return lines.join('\n');
}
