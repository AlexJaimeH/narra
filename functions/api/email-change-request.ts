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
    // Validar configuración
    if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) {
      console.error('[email-change-request] Missing Supabase configuration');
      return json({ error: 'Server configuration error' }, 500);
    }

    if (!env.RESEND_API_KEY || !env.RESEND_FROM_EMAIL) {
      console.error('[email-change-request] Missing email configuration');
      return json({ error: 'Email service not configured' }, 500);
    }

    // Parsear el body
    const payload = await request.json().catch(() => null);
    if (!payload || typeof payload !== 'object') {
      return json({ error: 'Invalid request body' }, 400);
    }

    const newEmail = typeof (payload as any).newEmail === 'string'
      ? (payload as any).newEmail.trim().toLowerCase()
      : '';

    if (!newEmail || !newEmail.includes('@')) {
      return json({ error: 'Email válido es requerido' }, 400);
    }

    // Obtener el token de autorización
    const authHeader = request.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return json({ error: 'No autorizado' }, 401);
    }

    const token = authHeader.substring(7);

    // Verificar el usuario actual usando el token
    console.log('[email-change-request] Verifying user token...');
    const userResponse = await fetch(`${env.SUPABASE_URL}/auth/v1/user`, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
      },
    });

    if (!userResponse.ok) {
      console.error('[email-change-request] Invalid token');
      return json({ error: 'No autorizado' }, 401);
    }

    const currentUser = await userResponse.json();
    const userId = currentUser.id;
    const oldEmail = currentUser.email;

    console.log('[email-change-request] User:', userId, 'Old email:', oldEmail);

    // Validar que el email no sea el mismo
    if (newEmail === oldEmail.toLowerCase()) {
      return json({ error: 'El nuevo email es igual al actual' }, 400);
    }

    // Verificar que el nuevo email no esté registrado
    console.log('[email-change-request] Checking if new email is available...');
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
      console.error('[email-change-request] Failed to check users');
      return json({ error: 'Error al verificar disponibilidad del email' }, 500);
    }

    const usersData = await usersResponse.json();
    const users = usersData.users || [];
    const emailExists = users.some((user: any) =>
      user.email?.toLowerCase() === newEmail && user.id !== userId
    );

    if (emailExists) {
      console.log('[email-change-request] Email already in use');
      return json({
        error: 'Este email ya está registrado con otra cuenta. Por favor usa un email diferente.'
      }, 400);
    }

    // Cancelar solicitudes pendientes anteriores para este usuario
    console.log('[email-change-request] Cancelling previous pending requests...');
    const cancelResponse = await fetch(
      `${env.SUPABASE_URL}/rest/v1/email_change_requests?user_id=eq.${userId}&status=eq.pending`,
      {
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: JSON.stringify({
          status: 'cancelled',
          cancelled_at: new Date().toISOString(),
        }),
      }
    );

    // Generar tokens únicos
    const confirmationToken = generateToken();
    const revertToken = generateToken();

    // Crear la solicitud de cambio de email
    console.log('[email-change-request] Creating email change request...');
    const createResponse = await fetch(
      `${env.SUPABASE_URL}/rest/v1/email_change_requests`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          'Content-Type': 'application/json',
          'Prefer': 'return=representation',
        },
        body: JSON.stringify({
          user_id: userId,
          old_email: oldEmail,
          new_email: newEmail,
          confirmation_token: confirmationToken,
          revert_token: revertToken,
          status: 'pending',
        }),
      }
    );

    if (!createResponse.ok) {
      const errorText = await createResponse.text();
      console.error('[email-change-request] Failed to create request:', errorText);
      return json({ error: 'Error al crear solicitud de cambio' }, 500);
    }

    // Determinar la URL base
    const appUrl = env.APP_URL || 'https://narra.mx';

    // Construir los links
    const confirmLink = `${appUrl}/app/email-change-confirm?token=${confirmationToken}`;
    const revertLink = `${appUrl}/app/email-change-revert?token=${revertToken}`;

    // Enviar email al correo viejo
    console.log('[email-change-request] Sending email to old address...');
    const oldEmailHtml = buildOldEmailHtml(oldEmail, newEmail, revertLink);
    const oldEmailText = buildOldEmailText(oldEmail, newEmail, revertLink);

    const oldEmailResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${env.RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: env.RESEND_FROM_EMAIL,
        to: [oldEmail],
        subject: 'Solicitud de cambio de email en Narra',
        html: oldEmailHtml,
        text: oldEmailText,
        tags: [{ name: 'type', value: 'email-change-old' }],
      }),
    });

    if (!oldEmailResponse.ok) {
      const errorText = await oldEmailResponse.text();
      console.error('[email-change-request] Failed to send old email:', errorText);
    }

    // Enviar email al correo nuevo
    console.log('[email-change-request] Sending email to new address...');
    const newEmailHtml = buildNewEmailHtml(newEmail, confirmLink);
    const newEmailText = buildNewEmailText(newEmail, confirmLink);

    const newEmailResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${env.RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: env.RESEND_FROM_EMAIL,
        to: [newEmail],
        subject: 'Confirma tu nuevo email en Narra',
        html: newEmailHtml,
        text: newEmailText,
        tags: [{ name: 'type', value: 'email-change-new' }],
      }),
    });

    if (!newEmailResponse.ok) {
      const errorText = await newEmailResponse.text();
      console.error('[email-change-request] Failed to send new email:', errorText);
      return json({ error: 'Error al enviar email de confirmación' }, 500);
    }

    console.log('[email-change-request] Email change request created successfully');

    return json({
      success: true,
      message: 'Se han enviado correos de confirmación. Revisa ambas bandejas de entrada.',
    });

  } catch (error) {
    console.error('[email-change-request] Unexpected error:', error);
    return json({ error: 'Internal server error' }, 500);
  }
};

function buildOldEmailHtml(oldEmail: string, newEmail: string, revertLink: string): string {
  return `<!DOCTYPE html>
<html lang="es">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="color-scheme" content="light only" />
    <meta name="supported-color-schemes" content="light" />
    <title>Solicitud de cambio de email en Narra</title>
    <style>
      :root { color-scheme: light only; }
      @media (prefers-color-scheme: dark) {
        body { background: #fdfbf7 !important; color: #1f2937 !important; }
        .email-card { background: #ffffff !important; }
        .email-header { background: linear-gradient(135deg, #4DB3A8 0%, #38827A 100%) !important; }
      }
    </style>
  </head>
  <body style="margin:0;padding:0;background:#fdfbf7;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI','Helvetica Neue',Arial,sans-serif;color:#1f2937;">
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
                    <p style="margin:0;font-size:14px;color:#ffffff;letter-spacing:0.08em;text-transform:uppercase;font-weight:600;">🔄 Cambio de Email</p>
                  </div>
                  <h1 style="font-size:32px;line-height:1.2;margin:0;font-weight:800;color:#ffffff;text-shadow:0 2px 8px rgba(0,0,0,0.15);">Solicitud de Cambio</h1>
                </div>

                <div style="padding:40px 36px;">
                  <p style="margin:0 0 24px 0;font-size:18px;line-height:1.65;color:#374151;font-weight:500;">Hola,</p>
                  <p style="margin:0 0 28px 0;font-size:17px;line-height:1.7;color:#4b5563;">Se ha solicitado cambiar el email de tu cuenta de Narra.</p>

                  <div style="background:#E8F5F4;border-left:4px solid #4DB3A8;border-radius:16px;padding:24px;margin:32px 0;">
                    <p style="margin:0 0 8px 0;font-size:15px;line-height:1.6;color:#38827A;font-weight:700;">📧 Cambio solicitado</p>
                    <p style="margin:0 0 12px 0;font-size:14px;line-height:1.65;color:#4b5563;">
                      <strong>Email actual:</strong> ${oldEmail}
                    </p>
                    <p style="margin:0;font-size:14px;line-height:1.65;color:#4b5563;">
                      <strong>Nuevo email:</strong> ${newEmail}
                    </p>
                  </div>

                  <div style="background:#fffbeb;border:2px solid #fde047;border-radius:16px;padding:24px;margin:32px 0;">
                    <p style="margin:0 0 12px 0;font-size:15px;line-height:1.6;color:#78350f;font-weight:600;">⚡ Importante</p>
                    <p style="margin:0;font-size:14px;line-height:1.65;color:#92400e;">
                      El cambio NO se realizará hasta que se confirme desde el nuevo email. Si no reconoces esta solicitud,
                      puedes ignorar este mensaje o usar el botón de abajo para cancelarla inmediatamente.
                    </p>
                  </div>

                  <div style="text-align:center;margin:40px 0 32px;">
                    <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto;">
                      <tr>
                        <td style="border-radius:16px;background:linear-gradient(135deg, #EF4444 0%, #DC2626 100%);box-shadow:0 8px 24px rgba(239,68,68,0.35),0 4px 12px rgba(0,0,0,0.1);">
                          <a href="${revertLink}" style="display:inline-block;color:#ffffff;text-decoration:none;font-weight:700;font-size:17px;padding:18px 42px;border-radius:16px;letter-spacing:0.01em;">🚫 Cancelar Cambio</a>
                        </td>
                      </tr>
                    </table>
                  </div>

                  <div style="background:#fafaf9;border-radius:16px;padding:24px;margin:32px 0;">
                    <p style="margin:0 0 12px 0;font-size:15px;line-height:1.6;color:#374151;font-weight:600;">🔒 Protección permanente</p>
                    <p style="margin:0;font-size:14px;line-height:1.65;color:#78716c;">
                      Este enlace de cancelación <strong>nunca expira</strong>. Puedes revertir el cambio en cualquier momento,
                      incluso después de que se haya confirmado. Guarda este correo en un lugar seguro.
                    </p>
                  </div>

                  <div style="background:#f9fafb;border:2px dashed #e5e7eb;border-radius:12px;padding:20px;margin:24px 0 0 0;">
                    <p style="margin:0 0 8px 0;font-size:13px;color:#6b7280;font-weight:600;">Si el botón no funciona, usa este enlace:</p>
                    <p style="margin:0;font-size:13px;word-break:break-all;"><a href="${revertLink}" style="color:#38827A;text-decoration:none;">${revertLink}</a></p>
                  </div>
                </div>

                <div style="background:#fafaf9;padding:32px 36px;border-top:1px solid #e7e5e4;">
                  <p style="margin:0 0 16px 0;font-size:14px;line-height:1.6;color:#78716c;text-align:center;">
                    Si no solicitaste este cambio, te recomendamos cancelarlo de inmediato.
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

function buildOldEmailText(oldEmail: string, newEmail: string, revertLink: string): string {
  return `Solicitud de cambio de email en Narra

Hola,

Se ha solicitado cambiar el email de tu cuenta de Narra.

Email actual: ${oldEmail}
Nuevo email: ${newEmail}

IMPORTANTE: El cambio NO se realizará hasta que se confirme desde el nuevo email.

Si no reconoces esta solicitud, puedes cancelarla en cualquier momento usando este enlace:
${revertLink}

Este enlace NUNCA expira. Puedes revertir el cambio en cualquier momento, incluso después de que se confirme.

---
Correo automático de Narra`;
}

function buildNewEmailHtml(newEmail: string, confirmLink: string): string {
  return `<!DOCTYPE html>
<html lang="es">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="color-scheme" content="light only" />
    <meta name="supported-color-schemes" content="light" />
    <title>Confirma tu nuevo email en Narra</title>
    <style>
      :root { color-scheme: light only; }
      @media (prefers-color-scheme: dark) {
        body { background: #fdfbf7 !important; color: #1f2937 !important; }
        .email-card { background: #ffffff !important; }
        .email-header { background: linear-gradient(135deg, #4DB3A8 0%, #38827A 100%) !important; }
      }
    </style>
  </head>
  <body style="margin:0;padding:0;background:#fdfbf7;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI','Helvetica Neue',Arial,sans-serif;color:#1f2937;">
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
                    <p style="margin:0;font-size:14px;color:#ffffff;letter-spacing:0.08em;text-transform:uppercase;font-weight:600;">✅ Confirmación Requerida</p>
                  </div>
                  <h1 style="font-size:32px;line-height:1.2;margin:0;font-weight:800;color:#ffffff;text-shadow:0 2px 8px rgba(0,0,0,0.15);">Confirma tu Email</h1>
                </div>

                <div style="padding:40px 36px;">
                  <p style="margin:0 0 24px 0;font-size:18px;line-height:1.65;color:#374151;font-weight:500;">Hola,</p>
                  <p style="margin:0 0 28px 0;font-size:17px;line-height:1.7;color:#4b5563;">
                    Se ha solicitado usar este email (<strong>${newEmail}</strong>) como el nuevo email de registro en Narra.
                  </p>

                  <div style="background:#E8F5F4;border-left:4px solid #4DB3A8;border-radius:16px;padding:24px;margin:32px 0;">
                    <p style="margin:0 0 8px 0;font-size:15px;line-height:1.6;color:#38827A;font-weight:700;">🔒 Confirmación necesaria</p>
                    <p style="margin:0;font-size:14px;line-height:1.65;color:#4b5563;">
                      Para completar el cambio de email, debes confirmar que tienes acceso a esta dirección de correo.
                      Haz clic en el botón de abajo para confirmar.
                    </p>
                  </div>

                  <div style="text-align:center;margin:40px 0 32px;">
                    <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto;">
                      <tr>
                        <td style="border-radius:16px;background:linear-gradient(135deg, #4DB3A8 0%, #38827A 100%);box-shadow:0 8px 24px rgba(77,179,168,0.35),0 4px 12px rgba(0,0,0,0.1);">
                          <a href="${confirmLink}" style="display:inline-block;color:#ffffff;text-decoration:none;font-weight:700;font-size:17px;padding:18px 42px;border-radius:16px;letter-spacing:0.01em;">✅ Confirmar Nuevo Email</a>
                        </td>
                      </tr>
                    </table>
                  </div>

                  <div style="background:#fffbeb;border:2px solid #fde047;border-radius:16px;padding:24px;margin:32px 0;">
                    <p style="margin:0 0 12px 0;font-size:15px;line-height:1.6;color:#78350f;font-weight:600;">⚡ Importante</p>
                    <p style="margin:0;font-size:14px;line-height:1.65;color:#92400e;">
                      El cambio se completará <strong>inmediatamente</strong> al hacer clic en el botón.
                      Después de esto, usarás este email para iniciar sesión en Narra.
                    </p>
                  </div>

                  <div style="background:#f9fafb;border:2px dashed #e5e7eb;border-radius:12px;padding:20px;margin:24px 0 0 0;">
                    <p style="margin:0 0 8px 0;font-size:13px;color:#6b7280;font-weight:600;">Si el botón no funciona, usa este enlace:</p>
                    <p style="margin:0;font-size:13px;word-break:break-all;"><a href="${confirmLink}" style="color:#38827A;text-decoration:none;">${confirmLink}</a></p>
                  </div>
                </div>

                <div style="background:#fafaf9;padding:32px 36px;border-top:1px solid #e7e5e4;">
                  <p style="margin:0 0 16px 0;font-size:14px;line-height:1.6;color:#78716c;text-align:center;">
                    Si no solicitaste este cambio, puedes ignorar este correo de forma segura.
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

function buildNewEmailText(newEmail: string, confirmLink: string): string {
  return `Confirma tu nuevo email en Narra

Hola,

Se ha solicitado usar este email (${newEmail}) como el nuevo email de registro en Narra.

Para completar el cambio, confirma que tienes acceso a esta dirección:
${confirmLink}

El cambio se completará inmediatamente al hacer clic en el enlace.

Si no solicitaste este cambio, puedes ignorar este correo de forma segura.

---
Correo automático de Narra`;
}
