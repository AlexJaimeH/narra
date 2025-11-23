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

function generatePassword(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*';
  const array = new Uint8Array(32);
  crypto.getRandomValues(array);
  return Array.from(array, byte => chars[byte % chars.length]).join('');
}

export const onRequestPost: PagesFunction<Env> = async ({ request, env }) => {
  try {
    // Validate configuration
    if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) {
      console.error('[gift-later-activate] Missing Supabase configuration');
      return json({ error: 'Server configuration error' }, 500);
    }

    if (!env.RESEND_API_KEY || !env.RESEND_FROM_EMAIL) {
      console.error('[gift-later-activate] Missing email configuration');
      return json({ error: 'Email service not configured' }, 500);
    }

    // Parse request body
    const payload = await request.json().catch(() => null);
    if (!payload || typeof payload !== 'object') {
      return json({ error: 'Invalid request body' }, 400);
    }

    const token = ((payload as any).token as string || '').trim();
    const authorEmail = ((payload as any).authorEmail as string || '').toLowerCase().trim();
    const authorName = ((payload as any).authorName as string || '').trim();
    const buyerName = ((payload as any).buyerName as string || '').trim() || null;
    const giftMessage = ((payload as any).giftMessage as string || '').trim() || null;

    // Validate
    if (!token) {
      return json({ error: 'Token es requerido' }, 400);
    }

    if (!authorEmail || !authorEmail.includes('@')) {
      return json({ error: 'Email válido del destinatario es requerido' }, 400);
    }

    if (!authorName || authorName === '') {
      return json({ error: 'Nombre del destinatario es requerido' }, 400);
    }

    console.log(`[gift-later-activate] Activating gift for ${authorEmail} with token ${token.substring(0, 8)}...`);

    // Verify token is valid and not used
    const purchaseResponse = await fetch(
      `${env.SUPABASE_URL}/rest/v1/gift_purchases?activation_token=eq.${token}&select=*`,
      {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          'Content-Type': 'application/json',
        },
      }
    );

    if (!purchaseResponse.ok) {
      console.error('[gift-later-activate] Failed to query purchase');
      return json({ error: 'Error al verificar token' }, 500);
    }

    const purchases = await purchaseResponse.json();

    if (!purchases || purchases.length === 0) {
      return json({ error: 'Token no válido' }, 404);
    }

    const purchase = purchases[0];

    if (purchase.token_used) {
      return json({ error: 'Este regalo ya fue activado' }, 400);
    }

    if (purchase.purchase_type !== 'gift_later') {
      return json({ error: 'Token no válido para activación' }, 400);
    }

    const buyerEmail = purchase.buyer_email;

    // Check if email is already in use
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
      console.error('[gift-later-activate] Failed to check users');
      return json({ error: 'Error al verificar disponibilidad del email' }, 500);
    }

    const usersData = await usersResponse.json();
    const users = usersData.users || [];
    const emailExists = users.some((user: any) => user.email?.toLowerCase() === authorEmail);

    if (emailExists) {
      console.log('[gift-later-activate] Email already in use');
      return json({
        error: 'Este email ya está registrado. Si ya tienes una cuenta, inicia sesión en /app.'
      }, 400);
    }

    // Generate random password
    const randomPassword = generatePassword();

    // Create user in Supabase Auth
    console.log('[gift-later-activate] Creating user in auth.users...');
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
          email: authorEmail,
          password: randomPassword,
          email_confirm: false,
          user_metadata: {
            purchase_type: 'gift_later',
            purchase_date: new Date().toISOString(),
            activated_at: new Date().toISOString(),
          },
        }),
      }
    );

    if (!createUserResponse.ok) {
      const errorText = await createUserResponse.text();
      console.error('[gift-later-activate] Failed to create user:', errorText);
      return json({ error: 'Error al crear la cuenta' }, 500);
    }

    const newUser = await createUserResponse.json();
    const userId = newUser.id;

    console.log('[gift-later-activate] User created:', userId);

    // Create public.users record
    console.log('[gift-later-activate] Creating public.users record...');
    const createPublicUserResponse = await fetch(
      `${env.SUPABASE_URL}/rest/v1/users`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: JSON.stringify({
          id: userId,
          name: authorName,
          email: authorEmail,
          subscription_tier: 'premium',
          writing_tone: 'warm',
          stories_written: 0,
          words_written: 0,
          ai_queries_used: 0,
          ai_queries_limit: 999999,
        }),
      }
    );

    if (!createPublicUserResponse.ok) {
      const errorText = await createPublicUserResponse.text();
      console.error('[gift-later-activate] Failed to create public.users record:', errorText);
      return json({ error: 'Error al crear el perfil de usuario' }, 500);
    }

    console.log('[gift-later-activate] public.users record created');

    // Create user_settings record
    console.log('[gift-later-activate] Creating user_settings record...');
    const createSettingsResponse = await fetch(
      `${env.SUPABASE_URL}/rest/v1/user_settings`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          'Content-Type': 'application/json',
          'Prefer': 'resolution=ignore-duplicates',
        },
        body: JSON.stringify({
          user_id: userId,
          auto_save: true,
          notification_stories: true,
          notification_reminders: true,
          sharing_enabled: false,
          language: 'es',
          font_family: 'Montserrat',
          text_scale: 1.0,
          high_contrast: false,
          reduce_motion: false,
          ai_no_bad_words: true,
          ai_person: 'first',
          ai_fidelity: 'balanced',
          has_used_ghost_writer: false,
          has_configured_ghost_writer: false,
          has_dismissed_ghost_writer_intro: false,
          has_seen_home_walkthrough: false,
          has_seen_editor_walkthrough: false,
          public_author_name: authorName,
          has_confirmed_name: false,
        }),
      }
    );

    if (!createSettingsResponse.ok) {
      const errorText = await createSettingsResponse.text();
      console.error('[gift-later-activate] Failed to create user_settings record:', errorText);
    } else {
      console.log('[gift-later-activate] user_settings record created');
    }

    // Update gift_purchases record
    console.log('[gift-later-activate] Updating gift_purchases record...');
    const updatePurchaseResponse = await fetch(
      `${env.SUPABASE_URL}/rest/v1/gift_purchases?id=eq.${purchase.id}`,
      {
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: JSON.stringify({
          user_id: userId,
          author_name: authorName,
          author_email: authorEmail,
          buyer_name: buyerName,
          gift_message: giftMessage,
          token_used: true,
          activated_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        }),
      }
    );

    if (!updatePurchaseResponse.ok) {
      const errorText = await updatePurchaseResponse.text();
      console.error('[gift-later-activate] Failed to update gift_purchases:', errorText);
      // Don't fail the whole process
    }

    // Generate magic link for author
    console.log('[gift-later-activate] Generating magic link for author...');
    const appUrl = env.APP_URL || 'https://narra.mx';
    const redirectTo = `${appUrl}/app`;

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
          options: {
            redirect_to: redirectTo,
          },
        }),
      }
    );

    if (!magicLinkResponse.ok) {
      console.error('[gift-later-activate] Failed to generate magic link');
      return json({ error: 'Error al generar enlace de acceso' }, 500);
    }

    const magicLinkData = await magicLinkResponse.json();
    let magicLink = magicLinkData.properties?.action_link || magicLinkData.action_link || '';

    if (!magicLink) {
      console.error('[gift-later-activate] No magic link generated');
      return json({ error: 'Error al generar enlace de acceso' }, 500);
    }

    // Fix magic link redirect_to
    try {
      const urlObj = new URL(magicLink);
      let redirectParam = urlObj.searchParams.get('redirect_to');

      if (redirectParam && redirectParam.includes('localhost')) {
        redirectParam = redirectParam.replace(/http:\/\/localhost:\d+/g, appUrl);
        redirectParam = redirectParam.replace(/https:\/\/localhost:\d+/g, appUrl);
      }

      if (redirectParam) {
        const redirectUrl = new URL(redirectParam);
        if (redirectUrl.pathname.endsWith('/app/app')) {
          redirectUrl.pathname = redirectUrl.pathname.replace(/\/app\/app$/, '/app');
          redirectParam = redirectUrl.toString();
        } else if (!redirectUrl.pathname.endsWith('/app')) {
          redirectUrl.pathname = redirectUrl.pathname.replace(/\/$/, '') + '/app';
          redirectParam = redirectUrl.toString();
        }
        urlObj.searchParams.set('redirect_to', redirectParam);
        magicLink = urlObj.toString();
      }
    } catch (error) {
      console.error('[gift-later-activate] Error fixing magic link:', error);
    }

    // Send emails
    console.log('[gift-later-activate] Sending emails...');

    // Email to author (recipient)
    const authorEmailHtml = buildGiftAuthorEmail(authorEmail, magicLink, buyerName || 'Alguien especial', giftMessage, authorName);
    const authorEmailText = buildGiftAuthorEmailText(authorEmail, magicLink, buyerName || 'Alguien especial', giftMessage, authorName);

    const authorEmailResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${env.RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: env.RESEND_FROM_EMAIL,
        to: [authorEmail],
        subject: '🎁 ¡Te han regalado Narra!',
        html: authorEmailHtml,
        text: authorEmailText,
        tags: [{ name: 'type', value: 'gift-later-activated-author' }],
      }),
    });

    if (!authorEmailResponse.ok) {
      console.error('[gift-later-activate] Failed to send email to author');
    }

    // Email to buyer
    if (buyerEmail) {
      const buyerEmailHtml = buildGiftBuyerConfirmationEmail(buyerEmail, authorEmail, authorName);
      const buyerEmailText = buildGiftBuyerConfirmationEmailText(buyerEmail, authorEmail, authorName);

      const buyerEmailResponse = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${env.RESEND_API_KEY}`,
        },
        body: JSON.stringify({
          from: env.RESEND_FROM_EMAIL,
          to: [buyerEmail],
          subject: '✅ Tu regalo de Narra ha sido activado',
          html: buyerEmailHtml,
          text: buyerEmailText,
          tags: [{ name: 'type', value: 'gift-later-activated-buyer' }],
        }),
      });

      if (!buyerEmailResponse.ok) {
        console.error('[gift-later-activate] Failed to send email to buyer');
      }
    }

    console.log('[gift-later-activate] Gift activated successfully');

    return json({
      success: true,
      message: 'Regalo activado exitosamente',
      userId: userId,
    });

  } catch (error) {
    console.error('[gift-later-activate] Unexpected error:', error);
    return json({ error: 'Internal server error' }, 500);
  }
};

// Email templates
function buildGiftAuthorEmail(
  email: string,
  magicLink: string,
  buyerName: string,
  giftMessage: string | null,
  authorName: string,
): string {
  const hasMessage = giftMessage && giftMessage.trim() !== '';
  const normalizedAuthor = authorName.trim();
  const greetingLine = normalizedAuthor.length > 0 ? `Hola ${normalizedAuthor},` : 'Hola,';

  return `<!DOCTYPE html>
<html lang="es">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>¡Te han regalado Narra!</title>
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
                  <div style="text-align:center;margin-bottom:20px;font-size:80px;line-height:1;">🎁</div>
                  <h1 style="font-size:32px;line-height:1.2;margin:0;font-weight:800;color:#ffffff;text-shadow:0 2px 8px rgba(0,0,0,0.15);">¡${buyerName} te ha regalado Narra!</h1>
                </div>

                <div style="padding:40px 36px;">
                  <p style="margin:0 0 24px 0;font-size:18px;line-height:1.65;color:#374151;font-weight:500;">${greetingLine}</p>
                  <p style="margin:0 0 28px 0;font-size:17px;line-height:1.7;color:#4b5563;"><strong>${buyerName}</strong> te ha regalado acceso de por vida a <strong>Narra</strong>, una plataforma para preservar y compartir tus historias con tu familia.</p>

                  ${hasMessage ? `
                  <div style="background:linear-gradient(135deg, #FFF8F0 0%, #FFE8D6 100%);border-left:4px solid #F59E0B;border-radius:16px;padding:28px;margin:32px 0;position:relative;">
                    <div style="text-align:center;margin-bottom:16px;font-size:32px;line-height:1;">💌</div>
                    <p style="margin:0 0 12px 0;font-size:15px;line-height:1.6;color:#92400E;font-weight:700;text-align:center;">Mensaje especial de ${buyerName}</p>
                    <div style="background:#ffffff;border-radius:12px;padding:20px;margin-top:16px;">
                      <p style="margin:0;font-size:16px;line-height:1.7;color:#374151;font-style:italic;text-align:center;">"${giftMessage}"</p>
                    </div>
                  </div>
                  ` : ''}

                  <div style="background:#E8F5F4;border-left:4px solid #4DB3A8;border-radius:16px;padding:24px;margin:32px 0;">
                    <p style="margin:0 0 12px 0;font-size:15px;line-height:1.6;color:#38827A;font-weight:700;">✨ ¿Qué es Narra?</p>
                    <p style="margin:0 0 12px 0;font-size:14px;line-height:1.65;color:#4b5563;">Narra te permite escribir tus historias, agregar fotos y grabaciones de voz, y compartirlas de forma privada con las personas que amas.</p>
                    <ul style="margin:0;padding-left:20px;font-size:14px;line-height:1.65;color:#4b5563;">
                      <li>Historias ilimitadas</li>
                      <li>Fotos y grabaciones de voz</li>
                      <li>Asistente de IA para mejorar tu escritura</li>
                      <li>Comparte con tu familia de forma privada</li>
                    </ul>
                  </div>

                  <div style="text-align:center;margin:40px 0 32px;">
                    <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto;">
                      <tr>
                        <td style="border-radius:16px;background:linear-gradient(135deg, #4DB3A8 0%, #38827A 100%);box-shadow:0 8px 24px rgba(77,179,168,0.35),0 4px 12px rgba(0,0,0,0.1);">
                          <a href="${magicLink}" style="display:inline-block;color:#ffffff;text-decoration:none;font-weight:700;font-size:17px;padding:18px 42px;border-radius:16px;letter-spacing:0.01em;">🚀 Comenzar Ahora</a>
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

function buildGiftAuthorEmailText(
  email: string,
  magicLink: string,
  buyerName: string,
  giftMessage: string | null,
  authorName: string,
): string {
  const hasMessage = giftMessage && giftMessage.trim() !== '';
  const normalizedAuthor = authorName.trim();
  const greetingLine = normalizedAuthor.length > 0 ? `Hola ${normalizedAuthor},` : 'Hola,';

  let text = `¡${buyerName} te ha regalado Narra!

${greetingLine}

${buyerName} te ha regalado acceso de por vida a Narra, una plataforma para preservar y compartir tus historias con tu familia.`;

  if (hasMessage) {
    text += `

---
MENSAJE ESPECIAL DE ${buyerName.toUpperCase()}

"${giftMessage}"
---
`;
  }

  text += `

Para comenzar, haz clic en este enlace:
${magicLink}

¿Necesitas ayuda? Escríbenos a hola@narra.mx`;

  return text;
}

function buildGiftBuyerConfirmationEmail(
  buyerEmail: string,
  authorEmail: string,
  authorName: string,
): string {
  const normalizedAuthor = authorName.trim();
  const displayName = normalizedAuthor.length > 0 ? normalizedAuthor : authorEmail;
  return `<!DOCTYPE html>
<html lang="es">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Regalo activado exitosamente</title>
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
                    <p style="margin:0;font-size:14px;color:#ffffff;letter-spacing:0.08em;text-transform:uppercase;font-weight:600;">✅ REGALO ACTIVADO</p>
                  </div>
                  <h1 style="font-size:32px;line-height:1.2;margin:0;font-weight:800;color:#ffffff;text-shadow:0 2px 8px rgba(0,0,0,0.15);">¡Tu regalo fue activado!</h1>
                </div>

                <div style="padding:40px 36px;">
                  <p style="margin:0 0 24px 0;font-size:18px;line-height:1.65;color:#374151;font-weight:500;">Hola,</p>
                  <p style="margin:0 0 28px 0;font-size:17px;line-height:1.7;color:#4b5563;">Tu regalo de Narra ha sido activado exitosamente. <strong>${displayName}</strong> ya recibió su acceso y puede comenzar a preservar sus memorias.</p>

                  <div style="background:#E8F5F4;border-left:4px solid #4DB3A8;border-radius:16px;padding:24px;margin:32px 0;">
                    <p style="margin:0 0 8px 0;font-size:15px;line-height:1.6;color:#38827A;font-weight:700;">🎁 Detalles del Regalo</p>
                    <p style="margin:0;font-size:14px;line-height:1.65;color:#4b5563;">Destinatario: <strong>${displayName}</strong>${displayName !== authorEmail ? ` <span style="color:#6b7280;">(${authorEmail})</span>` : ''}</p>
                  </div>

                  <div
                    className="rounded-xl p-6"
                    style={{
                      background: 'linear-gradient(135deg, #FFF8F0 0%, #FFE8D6 100%)',
                      border: '2px solid #F59E0B',
                      borderRadius: '16px',
                      padding: '24px',
                      margin: '32px 0',
                    }}
                  >
                    <div style="text-align:center;margin-bottom:16px;font-size:32px;line-height:1;">🎁</div>
                    <p style="margin:0;font-size:14px;line-height:1.65;color:#92400e;text-align:center;"><strong>Has regalado memorias que durarán para siempre.</strong> Tu regalo ayudará a preservar historias familiares que se transmitirán de generación en generación.</p>
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

function buildGiftBuyerConfirmationEmailText(
  buyerEmail: string,
  authorEmail: string,
  authorName: string,
): string {
  const normalizedAuthor = authorName.trim();
  const displayName = normalizedAuthor.length > 0 ? normalizedAuthor : authorEmail;
  return `Regalo activado exitosamente

Tu regalo de Narra ha sido activado exitosamente.

${displayName}${displayName !== authorEmail ? ` (${authorEmail})` : ''} ya recibió su acceso y puede comenzar a preservar sus memorias.

Has regalado memorias que durarán para siempre.

¿Necesitas ayuda? Escríbenos a hola@narra.mx`;
}
