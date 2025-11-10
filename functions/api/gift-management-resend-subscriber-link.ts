interface Env {
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  RESEND_API_KEY: string;
  RESEND_FROM_EMAIL: string;
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
      console.error('[gift-management-resend-subscriber-link] Missing Supabase configuration');
      return json({ error: 'Server configuration error' }, 500);
    }

    if (!env.RESEND_API_KEY || !env.RESEND_FROM_EMAIL) {
      console.error('[gift-management-resend-subscriber-link] Missing email configuration');
      return json({ error: 'Email service not configured' }, 500);
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

    console.log('[gift-management-resend-subscriber-link] Validating token...');

    // Validate management token
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

    // Get subscriber and verify it belongs to this author
    console.log('[gift-management-resend-subscriber-link] Getting subscriber...');
    const subscriberResponse = await fetch(
      `${env.SUPABASE_URL}/rest/v1/subscribers?id=eq.${subscriberId}&author_id=eq.${authorUserId}&select=*`,
      {
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          'Content-Type': 'application/json',
        },
      }
    );

    if (!subscriberResponse.ok) {
      return json({ error: 'Error al obtener suscriptor' }, 500);
    }

    const subscribers = await subscriberResponse.json();

    if (!Array.isArray(subscribers) || subscribers.length === 0) {
      return json({ error: 'Suscriptor no encontrado' }, 404);
    }

    const subscriber = subscribers[0];

    // Get the subscriber's magic_link from the database
    const magicLink = subscriber.magic_link;

    if (!magicLink) {
      return json({ error: 'Magic link no encontrado para este suscriptor' }, 500);
    }

    // Construct the full magic link URL
    const appUrl = (env as any).APP_URL || 'https://narra.mx';
    const fullMagicLink = `${appUrl}/subscriber/${subscriber.author_id}?token=${magicLink}`;

    // Send email to subscriber
    console.log('[gift-management-resend-subscriber-link] Sending email to subscriber...');
    const emailHtml = buildSubscriberEmail(subscriber.name, subscriber.email, fullMagicLink);
    const emailText = buildSubscriberEmailText(subscriber.name, fullMagicLink);

    const emailResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${env.RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: env.RESEND_FROM_EMAIL,
        to: [subscriber.email],
        subject: '📖 Accede al blog de historias de Narra',
        html: emailHtml,
        text: emailText,
        tags: [{ name: 'type', value: 'subscriber-magic-link-resend' }],
      }),
    });

    if (!emailResponse.ok) {
      const errorText = await emailResponse.text();
      console.error('[gift-management-resend-subscriber-link] Failed to send email:', errorText);
      return json({ error: 'Error al enviar el email' }, 500);
    }

    console.log('[gift-management-resend-subscriber-link] Email sent successfully');

    return json({
      success: true,
      message: 'Enlace reenviado exitosamente',
    });

  } catch (error) {
    console.error('[gift-management-resend-subscriber-link] Unexpected error:', error);
    return json({ error: 'Internal server error' }, 500);
  }
};

function buildSubscriberEmail(name: string, email: string, magicLink: string): string {
  return `<!DOCTYPE html>
<html lang="es">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Accede al blog de Narra</title>
  </head>
  <body style="margin:0;padding:0;background:linear-gradient(135deg, #fdfbf7 0%, #f0ebe3 100%);font-family:-apple-system,BlinkMacSystemFont,'Segoe UI','Helvetica Neue',Arial,sans-serif;color:#1f2937;">
    <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="max-width:660px;margin:40px auto;padding:0 20px;">
      <tr>
        <td>
          <div style="text-align:center;margin-bottom:32px;">
            <img src="https://narra.mx/logo-horizontal.png" alt="Narra" style="height:36px;width:auto;" />
          </div>

          <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="background:#ffffff;border-radius:24px;box-shadow:0 20px 60px rgba(77,179,168,0.12);overflow:hidden;">
            <tr>
              <td style="padding:0;">
                <div style="background:linear-gradient(135deg, #4DB3A8 0%, #38827A 100%);padding:48px 36px;text-align:center;">
                  <h1 style="font-size:32px;margin:0;font-weight:800;color:#ffffff;">📖 Accede al Blog</h1>
                </div>

                <div style="padding:40px 36px;">
                  <p style="margin:0 0 24px 0;font-size:18px;line-height:1.65;color:#374151;">Hola ${name},</p>
                  <p style="margin:0 0 28px 0;font-size:16px;line-height:1.65;color:#374151;">
                    Haz clic en el botón de abajo para acceder al blog de historias en Narra.
                  </p>

                  <div style="text-align:center;margin:40px 0 32px;">
                    <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto;">
                      <tr>
                        <td style="border-radius:16px;background:linear-gradient(135deg, #4DB3A8 0%, #38827A 100%);box-shadow:0 8px 24px rgba(77,179,168,0.35);">
                          <a href="${magicLink}" style="display:inline-block;color:#ffffff;text-decoration:none;font-weight:700;font-size:17px;padding:18px 42px;border-radius:16px;">📖 Ver Historias</a>
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

function buildSubscriberEmailText(name: string, magicLink: string): string {
  return `Hola ${name},

Haz clic en el siguiente enlace para acceder al blog de historias en Narra:

${magicLink}

Correo automático de Narra`;
}
