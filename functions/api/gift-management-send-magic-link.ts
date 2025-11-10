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
      console.error('[gift-management-send-magic-link] Missing Supabase configuration');
      return json({ error: 'Server configuration error' }, 500);
    }

    if (!env.RESEND_API_KEY || !env.RESEND_FROM_EMAIL) {
      console.error('[gift-management-send-magic-link] Missing email configuration');
      return json({ error: 'Email service not configured' }, 500);
    }

    const payload = await request.json().catch(() => null);
    if (!payload || typeof payload !== 'object') {
      return json({ error: 'Invalid request body' }, 400);
    }

    const token = (payload as any).token as string;

    if (!token) {
      return json({ error: 'Token es requerido' }, 400);
    }

    console.log('[gift-management-send-magic-link] Validating token...');

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

    // Get author email
    console.log('[gift-management-send-magic-link] Getting author email...');
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
      return json({ error: 'Error al obtener datos del autor' }, 500);
    }

    const userData = await userResponse.json();
    const authorEmail = userData.email;

    // Generate magic link
    console.log('[gift-management-send-magic-link] Generating magic link...');
    const magicLinkResponse = await fetch(
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
          email: authorEmail,
        }),
      }
    );

    if (!magicLinkResponse.ok) {
      const errorText = await magicLinkResponse.text();
      console.error('[gift-management-send-magic-link] Failed to generate magic link:', errorText);
      return json({ error: 'Error al generar enlace de acceso' }, 500);
    }

    const magicLinkData = await magicLinkResponse.json();
    let magicLink = magicLinkData.action_link || '';

    if (!magicLink) {
      return json({ error: 'Error al generar enlace de acceso' }, 500);
    }

    // Ensure magic link redirects to /app
    // Transform: https://narra.mx/#access_token=... → https://narra.mx/app#access_token=...
    const appUrl = (env as any).APP_URL || 'https://narra.mx';
    magicLink = magicLink.replace(appUrl + '/#', appUrl + '/app#');

    // Send email
    console.log('[gift-management-send-magic-link] Sending magic link email...');
    const emailHtml = buildMagicLinkEmail(authorEmail, magicLink);
    const emailText = buildMagicLinkEmailText(authorEmail, magicLink);

    const emailResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${env.RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: env.RESEND_FROM_EMAIL,
        to: [authorEmail],
        subject: 'Accede a tu cuenta de Narra',
        html: emailHtml,
        text: emailText,
        tags: [{ name: 'type', value: 'magic-link-from-manager' }],
      }),
    });

    if (!emailResponse.ok) {
      const errorText = await emailResponse.text();
      console.error('[gift-management-send-magic-link] Failed to send email:', errorText);
      return json({ error: 'Error al enviar el email' }, 500);
    }

    console.log('[gift-management-send-magic-link] Magic link sent successfully');

    return json({
      success: true,
      message: 'Enlace de acceso enviado exitosamente',
    });

  } catch (error) {
    console.error('[gift-management-send-magic-link] Unexpected error:', error);
    return json({ error: 'Internal server error' }, 500);
  }
};

function buildMagicLinkEmail(email: string, magicLink: string): string {
  return `<!DOCTYPE html>
<html lang="es">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Accede a Narra</title>
  </head>
  <body style="margin:0;padding:0;background:linear-gradient(135deg, #fdfbf7 0%, #f0ebe3 100%);font-family:-apple-system,BlinkMacSystemFont,'Segoe UI','Helvetica Neue',Arial,sans-serif;color:#1f2937;">
    <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="max-width:660px;margin:40px auto;padding:0 20px;">
      <tr>
        <td>
          <div style="text-align:center;margin-bottom:32px;">
            <img src="https://narra.mx/logo-horizontal.png" alt="Narra" style="height:36px;width:auto;" />
          </div>

          <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="background:#ffffff;border-radius:24px;box-shadow:0 20px 60px rgba(77,179,168,0.12),0 8px 20px rgba(0,0,0,0.06);overflow:hidden;">
            <tr>
              <td style="padding:0;">
                <div style="background:linear-gradient(135deg, #4DB3A8 0%, #38827A 100%);padding:48px 36px;text-align:center;">
                  <div style="display:inline-block;background:rgba(255,255,255,0.25);backdrop-filter:blur(10px);border-radius:16px;padding:12px 24px;margin-bottom:20px;">
                    <p style="margin:0;font-size:14px;color:#ffffff;letter-spacing:0.08em;text-transform:uppercase;font-weight:600;">🔑 ACCESO SEGURO</p>
                  </div>
                  <h1 style="font-size:32px;line-height:1.2;margin:0;font-weight:800;color:#ffffff;text-shadow:0 2px 8px rgba(0,0,0,0.15);">Inicia Sesión</h1>
                </div>

                <div style="padding:40px 36px;">
                  <p style="margin:0 0 24px 0;font-size:18px;line-height:1.65;color:#374151;font-weight:500;">Hola,</p>
                  <p style="margin:0 0 28px 0;font-size:17px;line-height:1.7;color:#4b5563;">Haz clic en el botón de abajo para acceder a tu cuenta de Narra.</p>

                  <div style="background:#E8F5F4;border-left:4px solid #4DB3A8;border-radius:16px;padding:24px;margin:32px 0;">
                    <p style="margin:0 0 8px 0;font-size:15px;line-height:1.6;color:#38827A;font-weight:700;">⏰ Válido por 15 minutos</p>
                    <p style="margin:0;font-size:14px;line-height:1.65;color:#4b5563;">Este enlace expira en 15 minutos por seguridad. Si necesitas otro, puedes solicitarlo nuevamente.</p>
                  </div>

                  <div style="text-align:center;margin:40px 0 32px;">
                    <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto;">
                      <tr>
                        <td style="border-radius:16px;background:linear-gradient(135deg, #4DB3A8 0%, #38827A 100%);box-shadow:0 8px 24px rgba(77,179,168,0.35),0 4px 12px rgba(0,0,0,0.1);">
                          <a href="${magicLink}" style="display:inline-block;color:#ffffff;text-decoration:none;font-weight:700;font-size:17px;padding:18px 42px;border-radius:16px;letter-spacing:0.01em;">🚀 Acceder a Narra</a>
                        </td>
                      </tr>
                    </table>
                  </div>

                  <div style="background:#f9fafb;border:2px dashed #e5e7eb;border-radius:12px;padding:20px;margin:24px 0 0 0;">
                    <p style="margin:0 0 8px 0;font-size:13px;color:#6b7280;font-weight:600;">Si el botón no funciona, usa este enlace:</p>
                    <p style="margin:0;font-size:13px;word-break:break-all;"><a href="${magicLink}" style="color:#38827A;text-decoration:none;">${magicLink}</a></p>
                  </div>
                </div>

                <div style="background:#fafaf9;padding:32px 36px;border-top:1px solid #e7e5e4;">
                  <p style="margin:0 0 16px 0;font-size:14px;line-height:1.6;color:#78716c;text-align:center;">Si no solicitaste este enlace, puedes ignorar este correo de forma segura.</p>
                  <p style="margin:0;font-size:12px;color:#a8a29e;line-height:1.6;text-align:center;">Correo automático de Narra • Por favor no respondas</p>
                </div>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;
}

function buildMagicLinkEmailText(email: string, magicLink: string): string {
  return `Accede a tu cuenta de Narra

Hola,

Haz clic en el siguiente enlace para acceder a tu cuenta:

${magicLink}

Este enlace es válido por 15 minutos.

Si no solicitaste este enlace, puedes ignorar este correo de forma segura.

---
Correo automático de Narra`;
}
