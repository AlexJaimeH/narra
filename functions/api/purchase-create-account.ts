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

function generatePassword(): string {
  // Generate a strong random password (32 characters)
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*';
  const array = new Uint8Array(32);
  crypto.getRandomValues(array);
  return Array.from(array, byte => chars[byte % chars.length]).join('');
}

export const onRequestPost: PagesFunction<Env> = async ({ request, env }) => {
  try {
    // Validate configuration
    if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) {
      console.error('[purchase-create-account] Missing Supabase configuration');
      return json({ error: 'Server configuration error' }, 500);
    }

    if (!env.RESEND_API_KEY || !env.RESEND_FROM_EMAIL) {
      console.error('[purchase-create-account] Missing email configuration');
      return json({ error: 'Email service not configured' }, 500);
    }

    // Parse request body
    const payload = await request.json().catch(() => null);
    if (!payload || typeof payload !== 'object') {
      return json({ error: 'Invalid request body' }, 400);
    }

    const purchaseType = (payload as any).purchaseType as string;
    const authorEmail = ((payload as any).authorEmail as string || '').toLowerCase().trim();
    const buyerEmail = purchaseType === 'gift' ? ((payload as any).buyerEmail as string || '').toLowerCase().trim() : null;
    const buyerName = purchaseType === 'gift' ? ((payload as any).buyerName as string || '').trim() : null;
    const giftMessage = purchaseType === 'gift' && (payload as any).giftMessage ? ((payload as any).giftMessage as string).trim() : null;

    // Validate
    if (purchaseType !== 'self' && purchaseType !== 'gift') {
      return json({ error: 'Invalid purchase type' }, 400);
    }

    if (!authorEmail || !authorEmail.includes('@')) {
      return json({ error: 'Email válido del autor es requerido' }, 400);
    }

    if (purchaseType === 'gift' && (!buyerEmail || !buyerEmail.includes('@'))) {
      return json({ error: 'Email válido del comprador es requerido' }, 400);
    }

    if (purchaseType === 'gift' && (!buyerName || buyerName === '')) {
      return json({ error: 'Nombre del comprador es requerido' }, 400);
    }

    console.log(`[purchase-create-account] Creating account for ${authorEmail}, type: ${purchaseType}`);

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
      console.error('[purchase-create-account] Failed to check users');
      return json({ error: 'Error al verificar disponibilidad del email' }, 500);
    }

    const usersData = await usersResponse.json();
    const users = usersData.users || [];
    const emailExists = users.some((user: any) => user.email?.toLowerCase() === authorEmail);

    if (emailExists) {
      console.log('[purchase-create-account] Email already in use');
      return json({
        error: 'Este email ya está registrado. Si ya tienes una cuenta, inicia sesión en /app.'
      }, 400);
    }

    // Generate random password
    const randomPassword = generatePassword();

    // Create user in Supabase Auth
    console.log('[purchase-create-account] Creating user in auth.users...');
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
          email_confirm: false, // User needs to confirm via magic link
          user_metadata: {
            purchase_type: purchaseType,
            purchase_date: new Date().toISOString(),
          },
        }),
      }
    );

    if (!createUserResponse.ok) {
      const errorText = await createUserResponse.text();
      console.error('[purchase-create-account] Failed to create user:', errorText);
      return json({ error: 'Error al crear la cuenta' }, 500);
    }

    const newUser = await createUserResponse.json();
    const userId = newUser.id;

    console.log('[purchase-create-account] User created:', userId);

    const authorDisplayName = await fetchAuthorDisplayName(
      env.SUPABASE_URL,
      env.SUPABASE_SERVICE_ROLE_KEY,
      userId,
      authorEmail,
    );

    // Create management token for both gift AND self purchases (for account recovery)
    let managementToken: string | null = null;
    const tokenBuyerEmail = purchaseType === 'gift' ? buyerEmail : authorEmail; // For self, use author email

    managementToken = generateToken();

    console.log('[purchase-create-account] Creating management token...');
    const tokenResponse = await fetch(
      `${env.SUPABASE_URL}/rest/v1/gift_management_tokens`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: JSON.stringify({
          author_user_id: userId,
          buyer_email: tokenBuyerEmail,
          management_token: managementToken,
        }),
      }
    );

    if (!tokenResponse.ok) {
      console.error('[purchase-create-account] Failed to create management token');
      // Don't fail the whole process, but log it
    }

    // Generate magic link for author
    console.log('[purchase-create-account] Generating magic link for author...');
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
      console.error('[purchase-create-account] Failed to generate magic link');
      return json({ error: 'Error al generar enlace de acceso' }, 500);
    }

    const magicLinkData = await magicLinkResponse.json();
    let magicLink = magicLinkData.properties?.action_link || magicLinkData.action_link || '';

    if (!magicLink) {
      console.error('[purchase-create-account] No magic link generated');
      return json({ error: 'Error al generar enlace de acceso' }, 500);
    }

    console.log('[purchase-create-account] Original magic link:', magicLink);

    // IMPORTANT: Fix common issues with redirect_to (same logic as author-magic-link.ts)
    try {
      const urlObj = new URL(magicLink);
      let redirectParam = urlObj.searchParams.get('redirect_to');

      console.log('[purchase-create-account] Original redirect_to param:', redirectParam);

      // 1. Replace localhost if it appears
      if (redirectParam && redirectParam.includes('localhost')) {
        console.log('[purchase-create-account] Detected localhost in redirect_to');
        redirectParam = redirectParam.replace(/http:\/\/localhost:\d+/g, appUrl);
        redirectParam = redirectParam.replace(/https:\/\/localhost:\d+/g, appUrl);
      }

      // 2. Make sure it ends in /app
      if (redirectParam) {
        const redirectUrl = new URL(redirectParam);

        // If it ends in /app/app, remove one
        if (redirectUrl.pathname.endsWith('/app/app')) {
          console.log('[purchase-create-account] Detected /app/app, fixing to /app');
          redirectUrl.pathname = redirectUrl.pathname.replace(/\/app\/app$/, '/app');
          redirectParam = redirectUrl.toString();
        }
        // If it does NOT end in /app, add /app
        else if (!redirectUrl.pathname.endsWith('/app')) {
          console.log('[purchase-create-account] redirect_to missing /app, adding it');
          redirectUrl.pathname = redirectUrl.pathname.replace(/\/$/, '') + '/app';
          redirectParam = redirectUrl.toString();
        }

        // Update the magic link with the corrected redirect_to
        urlObj.searchParams.set('redirect_to', redirectParam);
        magicLink = urlObj.toString();
      }

      console.log('[purchase-create-account] Fixed redirect_to param:', redirectParam);
      console.log('[purchase-create-account] Final magic link:', magicLink);
    } catch (error) {
      console.error('[purchase-create-account] Error fixing magic link:', error);
      // Continue with original magic link if fixing fails
    }

    // Send emails
    console.log('[purchase-create-account] Sending emails...');

    if (purchaseType === 'self') {
      // Send welcome + magic link email to author
      const emailHtml = buildSelfPurchaseEmail(authorEmail, magicLink, appUrl, managementToken);
      const emailText = buildSelfPurchaseEmailText(authorEmail, magicLink, appUrl, managementToken);

      const emailResponse = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${env.RESEND_API_KEY}`,
        },
        body: JSON.stringify({
          from: env.RESEND_FROM_EMAIL,
          to: [authorEmail],
          subject: '¡Bienvenido a Narra! Confirma tu cuenta',
          html: emailHtml,
          text: emailText,
          tags: [{ name: 'type', value: 'purchase-self' }],
        }),
      });

      if (!emailResponse.ok) {
        console.error('[purchase-create-account] Failed to send email to author');
        // Don't fail, user can request magic link later
      }
    } else {
      // Gift: Send two emails
      // 1. To author
      const authorEmailHtml = buildGiftAuthorEmail(authorEmail, magicLink, buyerName || '', giftMessage);
      const authorEmailText = buildGiftAuthorEmailText(authorEmail, magicLink, buyerName || '', giftMessage);

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
          tags: [{ name: 'type', value: 'purchase-gift-author' }],
        }),
      });

      if (!authorEmailResponse.ok) {
        console.error('[purchase-create-account] Failed to send email to author');
      }

      // 2. To buyer
      if (buyerEmail && managementToken) {
        const managementUrl = `${appUrl}/gift-management?token=${managementToken}`;
        const buyerEmailHtml = buildGiftBuyerEmail(buyerEmail, authorEmail, managementUrl);
        const buyerEmailText = buildGiftBuyerEmailText(buyerEmail, authorEmail, managementUrl);

        const buyerEmailResponse = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${env.RESEND_API_KEY}`,
          },
          body: JSON.stringify({
            from: env.RESEND_FROM_EMAIL,
            to: [buyerEmail],
            subject: '✅ Regalo enviado - Panel de gestión de Narra',
            html: buyerEmailHtml,
            text: buyerEmailText,
            tags: [{ name: 'type', value: 'purchase-gift-buyer' }],
          }),
        });

        if (!buyerEmailResponse.ok) {
          console.error('[purchase-create-account] Failed to send email to buyer');
        }
      }
    }

    console.log('[purchase-create-account] Account created successfully');

    return json({
      success: true,
      message: 'Cuenta creada exitosamente',
      userId: userId,
    });

  } catch (error) {
    console.error('[purchase-create-account] Unexpected error:', error);
    return json({ error: 'Internal server error' }, 500);
  }
};

// Email templates (simplified, will be expanded)
function buildSelfPurchaseEmail(
  email: string,
  magicLink: string,
  appUrl: string,
  managementToken: string | null,
  authorName: string,
): string {
  const recoveryPortalUrl = managementToken ? `${appUrl}/gift-management?token=${managementToken}` : null;
  const normalizedAuthor = authorName.trim();
  const greetingLine = normalizedAuthor.length > 0 ? `Hola ${normalizedAuthor},` : 'Hola,';
  return `<!DOCTYPE html>
<html lang="es">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>¡Bienvenido a Narra!</title>
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
                    <p style="margin:0;font-size:14px;color:#ffffff;letter-spacing:0.08em;text-transform:uppercase;font-weight:600;">🎉 ¡BIENVENIDO!</p>
                  </div>
                  <h1 style="font-size:32px;line-height:1.2;margin:0;font-weight:800;color:#ffffff;text-shadow:0 2px 8px rgba(0,0,0,0.15);">Tu cuenta está lista</h1>
                </div>

                <div style="padding:40px 36px;">
                  <p style="margin:0 0 24px 0;font-size:18px;line-height:1.65;color:#374151;font-weight:500;">${greetingLine}</p>
                  <p style="margin:0 0 28px 0;font-size:17px;line-height:1.7;color:#4b5563;">¡Gracias por unirte a Narra! Tu cuenta ha sido creada y estás listo para comenzar a preservar tus memorias.</p>

                  <div style="background:#E8F5F4;border-left:4px solid #4DB3A8;border-radius:16px;padding:24px;margin:32px 0;">
                    <p style="margin:0 0 8px 0;font-size:15px;line-height:1.6;color:#38827A;font-weight:700;">📧 Tu email</p>
                    <p style="margin:0;font-size:14px;line-height:1.65;color:#4b5563;"><strong>${email}</strong></p>
                  </div>

                  <div style="text-align:center;margin:40px 0 32px;">
                    <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto;">
                      <tr>
                        <td style="border-radius:16px;background:linear-gradient(135deg, #4DB3A8 0%, #38827A 100%);box-shadow:0 8px 24px rgba(77,179,168,0.35),0 4px 12px rgba(0,0,0,0.1);">
                          <a href="${magicLink}" style="display:inline-block;color:#ffffff;text-decoration:none;font-weight:700;font-size:17px;padding:18px 42px;border-radius:16px;letter-spacing:0.01em;">🚀 Confirmar y Comenzar</a>
                        </td>
                      </tr>
                    </table>
                  </div>

                  <div style="background:#f9fafb;border:2px dashed #e5e7eb;border-radius:12px;padding:20px;margin:24px 0 0 0;">
                    <p style="margin:0 0 8px 0;font-size:13px;color:#6b7280;font-weight:600;">Si el botón no funciona, usa este enlace:</p>
                    <p style="margin:0;font-size:13px;word-break:break-all;"><a href="${magicLink}" style="color:#38827A;text-decoration:none;">${magicLink}</a></p>
                  </div>
                </div>
                ${recoveryPortalUrl ? `
                <!-- Recovery Portal Section -->
                <div style="background:#FFFBEB;padding:24px 36px;border-top:1px solid #FDE68A;">
                  <div style="text-align:center;margin-bottom:16px;">
                    <span style="font-size:24px;">🔐</span>
                  </div>
                  <h3 style="margin:0 0 12px 0;font-size:16px;color:#92400E;text-align:center;font-weight:700;">Portal de Recuperación y Gestión</h3>
                  <p style="margin:0 0 16px 0;font-size:14px;line-height:1.65;color:#78350F;text-align:center;">
                    Por seguridad, también puedes acceder a tu información desde este portal. Úsalo si necesitas cambiar tu email, recuperar acceso o gestionar tu cuenta.
                  </p>
                  <div style="text-align:center;margin:20px 0 0;">
                    <a href="${recoveryPortalUrl}" style="display:inline-block;background:#92400E;color:#ffffff;text-decoration:none;font-weight:600;font-size:14px;padding:12px 24px;border-radius:8px;">Acceder al Portal de Gestión</a>
                  </div>
                  <p style="margin:16px 0 0 0;font-size:12px;line-height:1.5;color:#92400E;text-align:center;">
                    💡 Guarda este enlace en un lugar seguro. Te permitirá gestionar tu cuenta incluso si pierdes acceso a tu email.
                  </p>
                </div>
                ` : ''}

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

function buildSelfPurchaseEmailText(
  email: string,
  magicLink: string,
  appUrl: string,
  managementToken: string | null,
  authorName: string,
): string {
  const recoveryPortalUrl = managementToken ? `${appUrl}/gift-management?token=${managementToken}` : null;
  const normalizedAuthor = authorName.trim();
  const greetingLine = normalizedAuthor.length > 0 ? `Hola ${normalizedAuthor},` : 'Hola,';

  let text = `${greetingLine}

Tu cuenta ha sido creada exitosamente.

Email: ${email}

Para confirmar tu cuenta y comenzar, usa este enlace:
${magicLink}`;

  if (recoveryPortalUrl) {
    text += `

---

PORTAL DE RECUPERACIÓN Y GESTIÓN
Por seguridad, también puedes acceder a tu información desde este portal. Úsalo si necesitas cambiar tu email, recuperar acceso o gestionar tu cuenta:

${recoveryPortalUrl}

💡 Guarda este enlace en un lugar seguro. Te permitirá gestionar tu cuenta incluso si pierdes acceso a tu email.

---`;
  }

  text += `

¿Necesitas ayuda? Escríbenos a hola@narra.mx`;

  return text;
}

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

function buildGiftBuyerEmail(
  buyerEmail: string,
  authorEmail: string,
  managementUrl: string,
  authorName: string,
): string {
  const normalizedAuthor = authorName.trim();
  const displayName = normalizedAuthor.length > 0 ? normalizedAuthor : authorEmail;
  return `<!DOCTYPE html>
<html lang="es">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Regalo enviado - Panel de gestión</title>
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
                    <p style="margin:0;font-size:14px;color:#ffffff;letter-spacing:0.08em;text-transform:uppercase;font-weight:600;">✅ REGALO ENVIADO</p>
                  </div>
                  <h1 style="font-size:32px;line-height:1.2;margin:0;font-weight:800;color:#ffffff;text-shadow:0 2px 8px rgba(0,0,0,0.15);">¡Tu regalo fue enviado!</h1>
                </div>

                <div style="padding:40px 36px;">
                  <p style="margin:0 0 24px 0;font-size:18px;line-height:1.65;color:#374151;font-weight:500;">Hola,</p>
                  <p style="margin:0 0 28px 0;font-size:17px;line-height:1.7;color:#4b5563;">Tu regalo de Narra ha sido enviado exitosamente a <strong>${displayName}</strong>${displayName !== authorEmail ? ` <span style="color:#6b7280;">(${authorEmail})</span>` : ''}.</p>

                  <div style="background:#E8F5F4;border-left:4px solid #4DB3A8;border-radius:16px;padding:24px;margin:32px 0;">
                    <p style="margin:0 0 12px 0;font-size:15px;line-height:1.6;color:#38827A;font-weight:700;">🎁 Panel de Gestión</p>
                    <p style="margin:0 0 12px 0;font-size:14px;line-height:1.65;color:#4b5563;">Hemos creado un panel especial donde puedes:</p>
                    <ul style="margin:0;padding-left:20px;font-size:14px;line-height:1.65;color:#4b5563;">
                      <li>Cambiar el email del destinatario</li>
                      <li>Ver y gestionar suscriptores</li>
                      <li>Descargar historias publicadas</li>
                      <li>Enviar enlaces de inicio de sesión</li>
                    </ul>
                  </div>

                  <div style="text-align:center;margin:40px 0 32px;">
                    <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto;">
                      <tr>
                        <td style="border-radius:16px;background:linear-gradient(135deg, #4DB3A8 0%, #38827A 100%);box-shadow:0 8px 24px rgba(77,179,168,0.35),0 4px 12px rgba(0,0,0,0.1);">
                          <a href="${managementUrl}" style="display:inline-block;color:#ffffff;text-decoration:none;font-weight:700;font-size:17px;padding:18px 42px;border-radius:16px;letter-spacing:0.01em;">🎯 Acceder al Panel</a>
                        </td>
                      </tr>
                    </table>
                  </div>

                  <div style="background:#FFFBEB;border:2px solid #fde047;border-radius:16px;padding:24px;margin:32px 0;">
                    <p style="margin:0 0 12px 0;font-size:15px;line-height:1.6;color:#78350f;font-weight:600;">⚡ Importante</p>
                    <p style="margin:0;font-size:14px;line-height:1.65;color:#92400e;">Guarda este email en un lugar seguro. El enlace del panel de gestión no expira y te permite administrar el regalo en cualquier momento.</p>
                  </div>

                  <div style="background:#f9fafb;border:2px dashed #e5e7eb;border-radius:12px;padding:20px;margin:24px 0 0 0;">
                    <p style="margin:0 0 8px 0;font-size:13px;color:#6b7280;font-weight:600;">Enlace al panel de gestión:</p>
                    <p style="margin:0;font-size:13px;word-break:break-all;"><a href="${managementUrl}" style="color:#38827A;text-decoration:none;">${managementUrl}</a></p>
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

function buildGiftBuyerEmailText(
  buyerEmail: string,
  authorEmail: string,
  managementUrl: string,
  authorName: string,
): string {
  const normalizedAuthor = authorName.trim();
  const displayName = normalizedAuthor.length > 0 ? normalizedAuthor : authorEmail;
  return `Regalo enviado - Panel de gestión

Tu regalo de Narra ha sido enviado exitosamente a ${displayName}${displayName !== authorEmail ? ` (${authorEmail})` : ''}.

Panel de Gestión:
Desde este panel puedes administrar el regalo:
- Cambiar el email del destinatario
- Ver y gestionar suscriptores
- Descargar historias publicadas
- Enviar enlaces de inicio de sesión

Accede al panel aquí:
${managementUrl}

IMPORTANTE: Guarda este email en un lugar seguro. El enlace no expira.

¿Necesitas ayuda? Escríbenos a hola@narra.mx`;
}
