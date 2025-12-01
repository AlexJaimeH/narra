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

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}

export const onRequestPost: PagesFunction<Env> = async ({ request, env }) => {
  try {
    if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) {
      console.error('[author-login-pin] Missing Supabase configuration');
      return json({ error: 'Server configuration error' }, 500);
    }

    if (!env.RESEND_API_KEY || !env.RESEND_FROM_EMAIL) {
      console.error('[author-login-pin] Missing email configuration');
      return json({ error: 'Email service not configured' }, 500);
    }

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

    console.log('[author-login-pin] Generating OTP for:', email);

    const usersResponse = await fetch(
      `${env.SUPABASE_URL}/auth/v1/admin/users?email=${encodeURIComponent(email)}`,
      {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          'Content-Type': 'application/json',
        },
      }
    );

    if (!usersResponse.ok) {
      console.error('[author-login-pin] Failed to check users');
      return json({ error: 'Error al verificar usuario' }, 500);
    }

    const usersData = await usersResponse.json();
    const users = usersData.users || [];
    const userExists = users.some((user: any) => user.email?.toLowerCase() === email);

    if (!userExists) {
      console.log('[author-login-pin] User does not exist:', email);
      return json({
        error: 'Este correo no está registrado. Por favor, contacta al administrador para crear tu cuenta.'
      }, 404);
    }

    const appUrl = env.APP_URL || 'https://narra.mx';
    const redirectTo = `${appUrl}/app`;

    const requestBody = {
      type: 'magiclink',
      email: email,
      options: {
        redirect_to: redirectTo,
      },
    };

    console.log('[author-login-pin] Request body:', JSON.stringify(requestBody, null, 2));

    const generateLinkResponse = await fetch(
      `${env.SUPABASE_URL}/auth/v1/admin/generate_link`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(requestBody),
      }
    );

    if (!generateLinkResponse.ok) {
      const errorText = await generateLinkResponse.text();
      console.error('[author-login-pin] Failed to generate OTP:', errorText);
      return json({ error: 'Failed to generate OTP' }, 500);
    }

    const linkData = await generateLinkResponse.json();
    const emailOtp = linkData.properties?.email_otp || linkData.email_otp;

    if (!emailOtp || typeof emailOtp !== 'string') {
      console.error('[author-login-pin] No email_otp returned');
      return json({ error: 'No se pudo generar el PIN de acceso' }, 500);
    }

    console.log('[author-login-pin] OTP generated successfully for:', email);

    const emailHtml = buildPinEmail(email, emailOtp);
    const emailText = buildPinPlainText(email, emailOtp);

    const emailResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${env.RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: env.RESEND_FROM_EMAIL,
        to: [email],
        subject: 'Tu PIN de acceso a Narra',
        html: emailHtml,
        text: emailText,
        tags: [{ name: 'type', value: 'author-login-pin' }],
      }),
    });

    if (!emailResponse.ok) {
      const errorText = await emailResponse.text();
      console.error('[author-login-pin] Failed to send email:', errorText);
      return json({ error: 'Failed to send email' }, 500);
    }

    console.log('[author-login-pin] Email sent successfully to:', email);

    return json({
      success: true,
      message: 'Te enviamos un PIN de 6 dígitos para iniciar sesión',
    });
  } catch (error) {
    console.error('[author-login-pin] Unexpected error:', error);
    return json({ error: 'Internal server error' }, 500);
  }
};

function buildPinEmail(email: string, pin: string): string {
  const greeting = '¡Hola!';
  const mainMessage = 'Usa este PIN de 6 dígitos para entrar a Narra. Escríbelo en la pantalla de inicio de sesión.';

  return `<!DOCTYPE html>
<html lang="es">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="color-scheme" content="light only" />
    <meta name="supported-color-schemes" content="light" />
    <title>Tu PIN para entrar a Narra</title>
    <style>
      :root { color-scheme: light only; }
      @media (prefers-color-scheme: dark) {
        body { background: #fdfbf7 !important; color: #1f2937 !important; }
        .email-card { background: #ffffff !important; }
        .email-header { background: linear-gradient(135deg, #4DB3A8 0%, #38827A 100%) !important; }
      }
    </style>
  </head>
  <body style="margin:0;padding:0;background:linear-gradient(135deg, #fdfbf7 0%, #f0ebe3 100%);font-family:-apple-system,BlinkMacSystemFont,'Segoe UI','Helvetica Neue',Arial,sans-serif;color:#1f2937;">
    <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="max-width:660px;margin:40px auto;padding:0 20px;">
      <tr>
        <td>
          <div style="text-align:center;margin-bottom:32px;">
            <img src="https://narra.mx/logo-horizontal.png" alt="Narra" style="height:36px;width:auto;" />
          </div>

          <table role="presentation" cellpadding="0" cellspacing="0" width="100%" class="email-card" style="background:#ffffff;border-radius:24px;box-shadow:0 20px 60px rgba(77,179,168,0.12),0 8px 20px rgba(0,0,0,0.06);overflow:hidden;">
            <tr>
              <td style="padding:0;">
                <div class="email-header" style="background:linear-gradient(135deg, #4DB3A8 0%, #38827A 100%);padding:48px 36px;text-align:center;">
                  <div style="display:inline-block;background:rgba(255,255,255,0.25);backdrop-filter:blur(10px);border-radius:16px;padding:12px 24px;margin-bottom:20px;">
                    <p style="margin:0;font-size:14px;color:#ffffff;letter-spacing:0.08em;text-transform:uppercase;font-weight:600;">🔐 PIN de acceso</p>
                  </div>
                  <h1 style="font-size:32px;line-height:1.2;margin:0;font-weight:800;color:#ffffff;text-shadow:0 2px 8px rgba(0,0,0,0.15);">${greeting}</h1>
                </div>

                <div style="padding:40px 36px;">
                  <p style="margin:0 0 24px 0;font-size:18px;line-height:1.65;color:#374151;font-weight:500;">${mainMessage}</p>

                  <div style="text-align:center;margin:24px 0 12px;">
                    <div style="display:inline-block;border-radius:20px;background:#0f172a;color:#ffffff;padding:18px 28px;letter-spacing:0.45em;font-size:28px;font-weight:800;box-shadow:0 18px 40px rgba(15,23,42,0.25),0 6px 12px rgba(0,0,0,0.08);">
                      ${pin}
                    </div>
                    <p style="margin:12px 0 0 0;font-size:14px;color:#475569;font-weight:700;text-transform:uppercase;letter-spacing:0.08em;">PIN válido por 15 minutos</p>
                  </div>

                  <div style="background:#E8F5F4;border-left:4px solid #4DB3A8;border-radius:16px;padding:20px;margin:28px 0;">
                    <p style="margin:0 0 10px 0;font-size:15px;line-height:1.6;color:#0f172a;font-weight:700;">Instrucciones rápidas:</p>
                    <ol style="margin:0;padding-left:20px;font-size:14px;line-height:1.8;color:#4b5563;">
                      <li style="margin-bottom:8px;">Escribe el PIN exactamente como aparece.</li>
                      <li style="margin-bottom:8px;">Tienes 5 intentos. Después de 3 intentos fallidos pide un nuevo PIN.</li>
                      <li style="margin-bottom:0;">Si el tiempo vence, solicita un PIN nuevo en la página.</li>
                    </ol>
                  </div>

                  <div style="background:#f9fafb;border:2px dashed #e5e7eb;border-radius:12px;padding:18px;margin:12px 0 0 0;">
                    <p style="margin:0;font-size:13px;color:#6b7280;line-height:1.6;">Este PIN es solo para <strong style="color:#1f2937;">${email}</strong> y se invalida al generar uno nuevo.</p>
                  </div>
                </div>

                <div style="background:#fafaf9;padding:32px 36px;border-top:1px solid #e7e5e4;">
                  <p style="margin:0 0 16px 0;font-size:14px;line-height:1.6;color:#78716c;text-align:center;">
                    ¿No solicitaste este PIN? Ignora este correo y se desactivará solo.
                  </p>
                  <p style="margin:0;font-size:12px;color:#a8a29e;line-height:1.6;text-align:center;">
                    Correo automático de Narra • Por favor no respondas
                  </p>
                </div>
              </td>
            </tr>
          </table>

          <div style="height:40px;"></div>
        </td>
      </tr>
    </table>
  </body>
</html>`;
}

function buildPinPlainText(email: string, pin: string): string {
  const lines = [
    '¡Hola!',
    '',
    'Usa este PIN de 6 dígitos para entrar a Narra:',
    pin,
    '',
    'Tienes hasta 5 intentos y el PIN vence en 15 minutos.',
    'Después de 3 intentos fallidos, solicita uno nuevo en la página de inicio de sesión.',
    '',
    `Este PIN es solo para ${email} y se invalida al generar uno nuevo.`,
  ];

  return lines.join('\n');
}
