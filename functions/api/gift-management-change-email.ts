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
      console.error('[gift-management-change-email] Missing Supabase configuration');
      return json({ error: 'Server configuration error' }, 500);
    }

    const payload = await request.json().catch(() => null);
    if (!payload || typeof payload !== 'object') {
      return json({ error: 'Invalid request body' }, 400);
    }

    const token = (payload as any).token as string;
    const newEmail = ((payload as any).newEmail as string || '').toLowerCase().trim();

    if (!token || !newEmail) {
      return json({ error: 'Token y email son requeridos' }, 400);
    }

    if (!newEmail.includes('@')) {
      return json({ error: 'Email válido es requerido' }, 400);
    }

    console.log('[gift-management-change-email] Validating token...');

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

    // Check if new email is available
    console.log('[gift-management-change-email] Checking email availability...');
    const usersResponse = await fetch(
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

    if (!usersResponse.ok) {
      return json({ error: 'Error al verificar disponibilidad del email' }, 500);
    }

    const usersData = await usersResponse.json();
    const users = usersData.users || [];
    const emailExists = users.some((user: any) =>
      user.email?.toLowerCase() === newEmail && user.id !== authorUserId
    );

    if (emailExists) {
      return json({
        error: 'Este email ya está registrado con otra cuenta. Por favor usa un email diferente.'
      }, 400);
    }

    // Update email in auth.users
    console.log('[gift-management-change-email] Updating email...');
    const updateResponse = await fetch(
      `${env.SUPABASE_URL}/auth/v1/admin/users/${authorUserId}`,
      {
        method: 'PUT',
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          email: newEmail,
          email_confirm: true,
        }),
      }
    );

    if (!updateResponse.ok) {
      const errorText = await updateResponse.text();
      console.error('[gift-management-change-email] Failed to update email:', errorText);
      return json({ error: 'Error al actualizar el email' }, 500);
    }

    // Optional: Send notification email to author
    if (env.RESEND_API_KEY && env.RESEND_FROM_EMAIL) {
      console.log('[gift-management-change-email] Sending notification email...');
      const emailHtml = buildNotificationEmail(newEmail);
      const emailText = `Tu email en Narra ha sido actualizado a ${newEmail}. Si no reconoces este cambio, contacta a soporte en hola@narra.mx`;

      await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${env.RESEND_API_KEY}`,
        },
        body: JSON.stringify({
          from: env.RESEND_FROM_EMAIL,
          to: [newEmail],
          subject: 'Tu email en Narra ha sido actualizado',
          html: emailHtml,
          text: emailText,
          tags: [{ name: 'type', value: 'email-changed-by-manager' }],
        }),
      });
    }

    console.log('[gift-management-change-email] Email changed successfully');

    return json({
      success: true,
      message: 'Email actualizado exitosamente',
    });

  } catch (error) {
    console.error('[gift-management-change-email] Unexpected error:', error);
    return json({ error: 'Internal server error' }, 500);
  }
};

function buildNotificationEmail(newEmail: string): string {
  return `<!DOCTYPE html>
<html lang="es">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Email actualizado</title>
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
                  <h1 style="font-size:32px;line-height:1.2;margin:0;font-weight:800;color:#ffffff;text-shadow:0 2px 8px rgba(0,0,0,0.15);">Email Actualizado</h1>
                </div>

                <div style="padding:40px 36px;">
                  <p style="margin:0 0 24px 0;font-size:18px;line-height:1.65;color:#374151;font-weight:500;">Hola,</p>
                  <p style="margin:0 0 28px 0;font-size:17px;line-height:1.7;color:#4b5563;">Tu email en Narra ha sido actualizado exitosamente.</p>

                  <div style="background:#E8F5F4;border-left:4px solid #4DB3A8;border-radius:16px;padding:24px;margin:32px 0;">
                    <p style="margin:0 0 8px 0;font-size:15px;line-height:1.6;color:#38827A;font-weight:700;">📧 Nuevo email</p>
                    <p style="margin:0;font-size:14px;line-height:1.65;color:#4b5563;"><strong>${newEmail}</strong></p>
                  </div>

                  <p style="margin:0 0 24px 0;font-size:15px;line-height:1.7;color:#4b5563;">A partir de ahora, usa este email para iniciar sesión en Narra.</p>

                  <div style="background:#FFFBEB;border:2px solid #fde047;border-radius:16px;padding:24px;margin:32px 0;">
                    <p style="margin:0 0 12px 0;font-size:15px;line-height:1.6;color:#78350f;font-weight:600;">⚠️ ¿No reconoces este cambio?</p>
                    <p style="margin:0;font-size:14px;line-height:1.65;color:#92400e;">Si no solicitaste este cambio, contacta inmediatamente a nuestro equipo de soporte en <a href="mailto:hola@narra.mx" style="color:#38827A">hola@narra.mx</a></p>
                  </div>
                </div>

                <div style="background:#fafaf9;padding:32px 36px;border-top:1px solid #e7e5e4;">
                  <p style="margin:0;font-size:14px;line-height:1.6;color:#78716c;text-align:center;">Correo automático de Narra • Por favor no respondas</p>
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
