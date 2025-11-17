import { fetchAuthorDisplayName } from './_author_display_name';

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

    if (!env.RESEND_API_KEY || !env.RESEND_FROM_EMAIL) {
      console.error('[gift-management-add-subscriber] Missing email configuration');
      return json({ error: 'Email service not configured' }, 500);
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

    let authorEmail: string | undefined;
    try {
      const userResponse = await fetch(
        `${env.SUPABASE_URL}/auth/v1/admin/users/${authorUserId}`,
        {
          headers: {
            'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
            'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
            'Content-Type': 'application/json',
          },
        },
      );
      if (userResponse.ok) {
        const userData = await userResponse.json();
        if (userData && typeof userData.email === 'string') {
          authorEmail = userData.email;
        }
      }
    } catch (error) {
      console.warn('[gift-management-add-subscriber] Failed to fetch author email', error);
    }

    const authorDisplayName = await fetchAuthorDisplayName(
      env.SUPABASE_URL,
      env.SUPABASE_SERVICE_ROLE_KEY,
      authorUserId,
      authorEmail,
    );

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
    const insertedSubscriber = newSubscriber[0];

    console.log('[gift-management-add-subscriber] Subscriber added successfully');

    // Send welcome email to subscriber
    console.log('[gift-management-add-subscriber] Sending welcome email to subscriber...');
    const appUrl = (env as any).APP_URL || 'https://narra.mx';
    const subscriberLink = `${appUrl}/blog/subscriber/${insertedSubscriber.id}?author=${authorUserId}&subscriber=${insertedSubscriber.id}&token=${accessToken}&name=${encodeURIComponent(name)}`;

    const emailHtml = buildSubscriberEmail(name, email, subscriberLink, authorDisplayName);
    const emailText = buildSubscriberEmailText(name, subscriberLink, authorDisplayName);

    const emailResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${env.RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: env.RESEND_FROM_EMAIL,
        to: [email],
        subject: '📖 Accede al blog de historias de Narra',
        html: emailHtml,
        text: emailText,
        tags: [{ name: 'type', value: 'subscriber-welcome' }],
      }),
    });

    if (!emailResponse.ok) {
      const errorText = await emailResponse.text();
      console.error('[gift-management-add-subscriber] Failed to send email:', errorText);
      // Don't fail the whole operation if email fails
    } else {
      console.log('[gift-management-add-subscriber] Welcome email sent successfully');
    }

    return json({
      success: true,
      message: 'Suscriptor agregado exitosamente',
      subscriber: insertedSubscriber,
    });

  } catch (error) {
    console.error('[gift-management-add-subscriber] Unexpected error:', error);
    return json({ error: 'Internal server error' }, 500);
  }
};

function buildSubscriberEmail(
  name: string,
  email: string,
  magicLink: string,
  authorName: string,
): string {
  const normalizedAuthor = authorName.trim();
  const resolvedAuthor = normalizedAuthor.length > 0 ? normalizedAuthor : 'tu autor/a en Narra';
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
                  <p style="margin:0 0 18px 0;font-size:16px;line-height:1.65;color:#374151;">
                    ${resolvedAuthor} acaba de compartir contigo su blog privado de historias en Narra.
                  </p>
                  <p style="margin:0 0 28px 0;font-size:16px;line-height:1.65;color:#374151;">
                    Haz clic en el botón de abajo para abrir tus historias personalizadas.
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
                  <p style="margin:0 0 8px 0;font-size:14px;color:#78716c;line-height:1.6;text-align:center;">
                    Formas parte del círculo privado de <strong>${resolvedAuthor}</strong> en Narra
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

function buildSubscriberEmailText(
  name: string,
  magicLink: string,
  authorName: string,
): string {
  const normalizedAuthor = authorName.trim();
  const resolvedAuthor = normalizedAuthor.length > 0 ? normalizedAuthor : 'tu autor/a en Narra';
  return `Hola ${name},

${resolvedAuthor} te acaba de invitar a su blog privado en Narra. Usa este enlace personal para acceder:

${magicLink}

Este enlace es único para ti. Si necesitas ayuda, responde directamente a ${resolvedAuthor}.`;
}
