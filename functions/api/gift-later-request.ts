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
    // Validate configuration
    if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) {
      console.error('[gift-later-request] Missing Supabase configuration');
      return json({ error: 'Server configuration error' }, 500);
    }

    if (!env.RESEND_API_KEY || !env.RESEND_FROM_EMAIL) {
      console.error('[gift-later-request] Missing email configuration');
      return json({ error: 'Email service not configured' }, 500);
    }

    // Parse request body
    const payload = await request.json().catch(() => null);
    if (!payload || typeof payload !== 'object') {
      return json({ error: 'Invalid request body' }, 400);
    }

    const buyerEmail = ((payload as any).buyerEmail as string || '').toLowerCase().trim();

    // Validate
    if (!buyerEmail || !buyerEmail.includes('@')) {
      return json({ error: 'Email válido del comprador es requerido' }, 400);
    }

    console.log(`[gift-later-request] Creating gift later purchase for ${buyerEmail}`);

    // Generate activation token
    const activationToken = generateToken();

    // Create record in gift_purchases table
    console.log('[gift-later-request] Creating gift_purchases record...');
    const createPurchaseResponse = await fetch(
      `${env.SUPABASE_URL}/rest/v1/gift_purchases`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          'Content-Type': 'application/json',
          'Prefer': 'return=representation',
        },
        body: JSON.stringify({
          purchase_type: 'gift_later',
          author_name: '', // Will be filled when activated
          author_email: '', // Will be filled when activated
          buyer_email: buyerEmail,
          activation_token: activationToken,
          token_used: false,
        }),
      }
    );

    if (!createPurchaseResponse.ok) {
      const errorText = await createPurchaseResponse.text();
      console.error('[gift-later-request] Failed to create gift_purchases record:', errorText);
      return json({ error: 'Error al crear el registro de compra' }, 500);
    }

    const purchaseData = await createPurchaseResponse.json();
    console.log('[gift-later-request] Purchase record created:', purchaseData);

    // Send email with activation link
    console.log('[gift-later-request] Sending activation email...');
    const appUrl = env.APP_URL || 'https://narra.mx';
    const activationUrl = `${appUrl}/gift-activation?token=${activationToken}`;

    const emailHtml = buildGiftLaterEmail(buyerEmail, activationUrl);
    const emailText = buildGiftLaterEmailText(buyerEmail, activationUrl);

    const emailResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${env.RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: env.RESEND_FROM_EMAIL,
        to: [buyerEmail],
        subject: '🎁 Tu regalo de Narra está listo para activar',
        html: emailHtml,
        text: emailText,
        tags: [{ name: 'type', value: 'gift-later-request' }],
      }),
    });

    if (!emailResponse.ok) {
      console.error('[gift-later-request] Failed to send email');
      // Don't fail the whole process
    } else {
      console.log('[gift-later-request] Email sent successfully');
    }

    return json({
      success: true,
      message: 'Regalo creado exitosamente. Revisa tu email para activarlo cuando quieras.',
    });

  } catch (error) {
    console.error('[gift-later-request] Unexpected error:', error);
    return json({ error: 'Internal server error' }, 500);
  }
};

// Email template for gift later activation
function buildGiftLaterEmail(buyerEmail: string, activationUrl: string): string {
  return `<!DOCTYPE html>
<html lang="es">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Tu regalo de Narra está listo</title>
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
                    <p style="margin:0;font-size:14px;color:#ffffff;letter-spacing:0.08em;text-transform:uppercase;font-weight:600;">🎁 REGALO GUARDADO</p>
                  </div>
                  <h1 style="font-size:32px;line-height:1.2;margin:0;font-weight:800;color:#ffffff;text-shadow:0 2px 8px rgba(0,0,0,0.15);">Tu regalo está listo</h1>
                </div>

                <div style="padding:40px 36px;">
                  <p style="margin:0 0 24px 0;font-size:18px;line-height:1.65;color:#374151;font-weight:500;">Hola,</p>
                  <p style="margin:0 0 28px 0;font-size:17px;line-height:1.7;color:#4b5563;">Tu compra de Narra ha sido guardada y está lista para ser activada cuando quieras. Podrás completar los datos del destinatario y enviárselo en el momento perfecto.</p>

                  <div style="background:#E8F5F4;border-left:4px solid #4DB3A8;border-radius:16px;padding:24px;margin:32px 0;">
                    <p style="margin:0 0 12px 0;font-size:15px;line-height:1.6;color:#38827A;font-weight:700;">📧 ¿Cómo activar el regalo?</p>
                    <p style="margin:0 0 12px 0;font-size:14px;line-height:1.65;color:#4b5563;">Cuando estés listo para regalar Narra, simplemente haz clic en el botón de abajo. Te pediremos:</p>
                    <ul style="margin:0;padding-left:20px;font-size:14px;line-height:1.65;color:#4b5563;">
                      <li>Nombre del destinatario</li>
                      <li>Email del destinatario</li>
                      <li>Un mensaje especial (opcional)</li>
                    </ul>
                    <p style="margin:12px 0 0 0;font-size:14px;line-height:1.65;color:#4b5563;">Una vez completado, la persona recibirá su acceso a Narra de inmediato.</p>
                  </div>

                  <div style="text-align:center;margin:40px 0 32px;">
                    <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto;">
                      <tr>
                        <td style="border-radius:16px;background:linear-gradient(135deg, #4DB3A8 0%, #38827A 100%);box-shadow:0 8px 24px rgba(77,179,168,0.35),0 4px 12px rgba(0,0,0,0.1);">
                          <a href="${activationUrl}" style="display:inline-block;color:#ffffff;text-decoration:none;font-weight:700;font-size:17px;padding:18px 42px;border-radius:16px;letter-spacing:0.01em;">🎁 Activar Regalo Ahora</a>
                        </td>
                      </tr>
                    </table>
                  </div>

                  <div style="background:#FFFBEB;border:2px solid #fde047;border-radius:16px;padding:24px;margin:32px 0;">
                    <p style="margin:0 0 12px 0;font-size:15px;line-height:1.6;color:#78350f;font-weight:600;">⚡ Importante</p>
                    <p style="margin:0;font-size:14px;line-height:1.65;color:#92400e;">Este enlace no expira. Puedes activar el regalo en cualquier momento - hoy, mañana, o el día que prefieras. Guarda este email en un lugar seguro.</p>
                  </div>

                  <div style="background:#f9fafb;border:2px dashed #e5e7eb;border-radius:12px;padding:20px;margin:24px 0 0 0;">
                    <p style="margin:0 0 8px 0;font-size:13px;color:#6b7280;font-weight:600;">Si el botón no funciona, usa este enlace:</p>
                    <p style="margin:0;font-size:13px;word-break:break-all;"><a href="${activationUrl}" style="color:#38827A;text-decoration:none;">${activationUrl}</a></p>
                  </div>
                </div>

                <div style="background:#fafaf9;padding:32px 36px;border-top:1px solid #e7e5e4;">
                  <p style="margin:0 0 16px 0;font-size:14px;line-height:1.6;color:#78716c;text-align:center;">¿Tienes preguntas? Estamos aquí para ayudarte en <a href="mailto:hola@narra.mx" style="color:#38827A">hola@narra.mx</a></p>
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

function buildGiftLaterEmailText(buyerEmail: string, activationUrl: string): string {
  return `Tu regalo de Narra está listo para activar

Hola,

Tu compra de Narra ha sido guardada y está lista para ser activada cuando quieras.

Cuando estés listo para regalar Narra, simplemente haz clic en este enlace:
${activationUrl}

Te pediremos:
- Nombre del destinatario
- Email del destinatario
- Un mensaje especial (opcional)

Una vez completado, la persona recibirá su acceso a Narra de inmediato.

IMPORTANTE: Este enlace no expira. Puedes activar el regalo en cualquier momento.

¿Necesitas ayuda? Escríbenos a hola@narra.mx`;
}
