/**
 * API endpoint to verify a Stripe Checkout session and create the account
 * POST /api/stripe-verify-session
 *
 * Called after successful payment to verify and provision the account
 */

import { fetchAuthorDisplayName } from './_author_display_name';

interface Env {
  STRIPE_SECRET_KEY: string;
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
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*';
  const array = new Uint8Array(32);
  crypto.getRandomValues(array);
  return Array.from(array, byte => chars[byte % chars.length]).join('');
}

export const onRequestPost: PagesFunction<Env> = async ({ request, env }) => {
  try {
    if (!env.STRIPE_SECRET_KEY) {
      console.error('[stripe-verify-session] Missing STRIPE_SECRET_KEY');
      return json({ error: 'Stripe not configured' }, 500);
    }

    if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) {
      console.error('[stripe-verify-session] Missing Supabase configuration');
      return json({ error: 'Server configuration error' }, 500);
    }

    const payload = await request.json().catch(() => null);
    if (!payload || typeof payload !== 'object') {
      return json({ error: 'Invalid request body' }, 400);
    }

    const sessionId = (payload as any).sessionId as string;
    if (!sessionId) {
      return json({ error: 'Session ID is required' }, 400);
    }

    console.log('[stripe-verify-session] Verifying session:', sessionId);

    // Retrieve the checkout session from Stripe
    const sessionResponse = await fetch(
      `https://api.stripe.com/v1/checkout/sessions/${sessionId}`,
      {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${env.STRIPE_SECRET_KEY}`,
        },
      }
    );

    if (!sessionResponse.ok) {
      const errorText = await sessionResponse.text();
      console.error('[stripe-verify-session] Failed to retrieve session:', errorText);
      return json({ error: 'Invalid session' }, 400);
    }

    const session = await sessionResponse.json() as any;

    // Check payment status
    if (session.payment_status !== 'paid') {
      console.log('[stripe-verify-session] Payment not completed:', session.payment_status);
      return json({ error: 'Payment not completed', status: session.payment_status }, 400);
    }

    // Check if session was already processed (idempotency)
    const sessionToken = session.metadata?.session_token;
    if (sessionToken) {
      // Check if we already created an account for this session
      const existingCheckResponse = await fetch(
        `${env.SUPABASE_URL}/rest/v1/gift_purchases?stripe_session_id=eq.${sessionId}`,
        {
          method: 'GET',
          headers: {
            'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
            'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          },
        }
      );

      if (existingCheckResponse.ok) {
        const existingRecords = await existingCheckResponse.json() as any[];
        if (existingRecords && existingRecords.length > 0) {
          console.log('[stripe-verify-session] Session already processed');
          return json({
            success: true,
            alreadyProcessed: true,
            message: 'Payment was already processed',
          });
        }
      }
    }

    // Extract metadata
    const purchaseType = session.metadata?.purchase_type || 'self';
    const authorEmail = session.metadata?.author_email || '';
    const authorName = session.metadata?.author_name || '';
    const giftTiming = session.metadata?.gift_timing || 'now';
    const buyerEmail = session.metadata?.buyer_email || '';
    const buyerName = session.metadata?.buyer_name || '';
    const giftMessage = session.metadata?.gift_message || '';

    console.log('[stripe-verify-session] Processing purchase:', {
      purchaseType,
      authorEmail,
      giftTiming,
    });

    const appUrl = env.APP_URL || 'https://narra.mx';

    // Handle gift_later flow differently
    if (purchaseType === 'gift' && giftTiming === 'later') {
      // Create a gift_later_requests record
      const activationToken = generateToken();

      const giftLaterResponse = await fetch(
        `${env.SUPABASE_URL}/rest/v1/gift_later_requests`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
            'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
            'Content-Type': 'application/json',
            'Prefer': 'return=representation',
          },
          body: JSON.stringify({
            buyer_email: buyerEmail,
            activation_token: activationToken,
            stripe_session_id: sessionId,
            stripe_payment_intent: session.payment_intent,
            status: 'pending',
          }),
        }
      );

      if (!giftLaterResponse.ok) {
        const errorText = await giftLaterResponse.text();
        console.error('[stripe-verify-session] Failed to create gift_later_request:', errorText);
        return json({ error: 'Failed to create gift request' }, 500);
      }

      // Send email to buyer with activation link
      const activationUrl = `${appUrl}/gift-activation?token=${activationToken}`;

      const emailHtml = buildGiftLaterEmail(buyerEmail, activationUrl);
      const emailText = buildGiftLaterEmailText(buyerEmail, activationUrl);

      await fetch('https://api.resend.com/emails', {
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
          tags: [{ name: 'type', value: 'gift-later-paid' }],
        }),
      });

      return json({
        success: true,
        type: 'gift_later',
        message: 'Gift ready for activation',
      });
    }

    // Regular flow: create account now (self or gift_now)
    // Check if email is already in use
    const usersResponse = await fetch(
      `${env.SUPABASE_URL}/auth/v1/admin/users`,
      {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
        },
      }
    );

    if (!usersResponse.ok) {
      console.error('[stripe-verify-session] Failed to check users');
      return json({ error: 'Error checking email availability' }, 500);
    }

    const usersData = await usersResponse.json() as any;
    const users = usersData.users || [];
    const emailExists = users.some((user: any) => user.email?.toLowerCase() === authorEmail.toLowerCase());

    if (emailExists) {
      console.log('[stripe-verify-session] Email already in use');
      return json({
        error: 'Este email ya está registrado. El pago fue procesado pero la cuenta ya existe. Por favor contacta a soporte.',
        alreadyExists: true,
      }, 400);
    }

    // Create user in Supabase Auth
    const randomPassword = generatePassword();

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
            purchase_type: purchaseType,
            purchase_date: new Date().toISOString(),
            stripe_session_id: sessionId,
          },
        }),
      }
    );

    if (!createUserResponse.ok) {
      const errorText = await createUserResponse.text();
      console.error('[stripe-verify-session] Failed to create user:', errorText);
      return json({ error: 'Failed to create account' }, 500);
    }

    const newUser = await createUserResponse.json() as any;
    const userId = newUser.id;

    console.log('[stripe-verify-session] User created:', userId);

    // Create public.users record
    await fetch(
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

    // Create user_settings record
    await fetch(
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

    // Create management token
    const managementToken = generateToken();
    const tokenBuyerEmail = purchaseType === 'gift' ? buyerEmail : authorEmail;

    await fetch(
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

    // Create gift_purchases record with stripe info
    await fetch(
      `${env.SUPABASE_URL}/rest/v1/gift_purchases`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: JSON.stringify({
          user_id: userId,
          purchase_type: purchaseType === 'self' ? 'self' : 'gift_now',
          author_name: authorName,
          author_email: authorEmail,
          buyer_name: buyerName || null,
          buyer_email: buyerEmail || null,
          gift_message: giftMessage || null,
          stripe_session_id: sessionId,
          stripe_payment_intent: session.payment_intent,
        }),
      }
    );

    // Generate magic link
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
          options: { redirect_to: redirectTo },
        }),
      }
    );

    let magicLink = '';
    if (magicLinkResponse.ok) {
      const magicLinkData = await magicLinkResponse.json() as any;
      magicLink = magicLinkData.properties?.action_link || magicLinkData.action_link || '';

      // Fix redirect URL
      if (magicLink) {
        try {
          const urlObj = new URL(magicLink);
          let redirectParam = urlObj.searchParams.get('redirect_to');
          if (redirectParam && redirectParam.includes('localhost')) {
            redirectParam = redirectParam.replace(/http:\/\/localhost:\d+/g, appUrl);
            urlObj.searchParams.set('redirect_to', redirectParam);
            magicLink = urlObj.toString();
          }
        } catch {}
      }
    }

    // Send emails
    if (purchaseType === 'self') {
      const emailHtml = buildSelfPurchaseEmail(authorEmail, magicLink, appUrl, managementToken, authorName);
      const emailText = buildSelfPurchaseEmailText(authorEmail, magicLink, appUrl, managementToken, authorName);

      await fetch('https://api.resend.com/emails', {
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
    } else {
      // Gift: send to both author and buyer
      const authorEmailHtml = buildGiftAuthorEmail(authorEmail, magicLink, buyerName, giftMessage, authorName);
      const authorEmailText = buildGiftAuthorEmailText(authorEmail, magicLink, buyerName, giftMessage, authorName);

      await fetch('https://api.resend.com/emails', {
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

      if (buyerEmail) {
        const managementUrl = `${appUrl}/gift-management?token=${managementToken}`;
        const buyerEmailHtml = buildGiftBuyerEmail(buyerEmail, authorEmail, managementUrl, authorName);
        const buyerEmailText = buildGiftBuyerEmailText(buyerEmail, authorEmail, managementUrl, authorName);

        await fetch('https://api.resend.com/emails', {
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
      }
    }

    console.log('[stripe-verify-session] Account created successfully');

    return json({
      success: true,
      type: purchaseType,
      message: 'Account created successfully',
      userId,
    });

  } catch (error) {
    console.error('[stripe-verify-session] Unexpected error:', error);
    return json({ error: 'Internal server error' }, 500);
  }
};

// Email templates
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
                  <div style="text-align:center;margin-bottom:20px;font-size:80px;line-height:1;">🎁</div>
                  <h1 style="font-size:32px;line-height:1.2;margin:0;font-weight:800;color:#ffffff;">Tu regalo está listo</h1>
                </div>
                <div style="padding:40px 36px;">
                  <p style="margin:0 0 24px 0;font-size:18px;line-height:1.65;color:#374151;font-weight:500;">Hola,</p>
                  <p style="margin:0 0 28px 0;font-size:17px;line-height:1.7;color:#4b5563;">¡Gracias por tu compra! Tu regalo de Narra está listo para activar cuando quieras.</p>
                  <div style="background:#E8F5F4;border-left:4px solid #4DB3A8;border-radius:16px;padding:24px;margin:32px 0;">
                    <p style="margin:0 0 12px 0;font-size:15px;line-height:1.6;color:#38827A;font-weight:700;">🎯 ¿Qué sigue?</p>
                    <p style="margin:0;font-size:14px;line-height:1.65;color:#4b5563;">Cuando estés listo para regalar, haz clic en el botón de abajo. Podrás ingresar los datos de la persona que recibirá el regalo.</p>
                  </div>
                  <div style="text-align:center;margin:40px 0 32px;">
                    <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto;">
                      <tr>
                        <td style="border-radius:16px;background:linear-gradient(135deg, #4DB3A8 0%, #38827A 100%);box-shadow:0 8px 24px rgba(77,179,168,0.35),0 4px 12px rgba(0,0,0,0.1);">
                          <a href="${activationUrl}" style="display:inline-block;color:#ffffff;text-decoration:none;font-weight:700;font-size:17px;padding:18px 42px;border-radius:16px;">🎁 Activar Regalo</a>
                        </td>
                      </tr>
                    </table>
                  </div>
                  <div style="background:#f9fafb;border:2px dashed #e5e7eb;border-radius:12px;padding:20px;margin:24px 0 0 0;">
                    <p style="margin:0 0 8px 0;font-size:13px;color:#6b7280;font-weight:600;">Enlace de activacion:</p>
                    <p style="margin:0;font-size:13px;word-break:break-all;"><a href="${activationUrl}" style="color:#38827A;text-decoration:none;">${activationUrl}</a></p>
                  </div>
                </div>
                <div style="background:#fafaf9;padding:32px 36px;border-top:1px solid #e7e5e4;">
                  <p style="margin:0;font-size:14px;line-height:1.6;color:#78716c;text-align:center;">¿Preguntas? Escríbenos a <a href="mailto:hola@narra.mx" style="color:#38827A">hola@narra.mx</a></p>
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
  return `Tu regalo de Narra está listo

Hola,

¡Gracias por tu compra! Tu regalo de Narra está listo para activar cuando quieras.

Cuando estés listo para regalar, visita este enlace:
${activationUrl}

Podrás ingresar los datos de la persona que recibirá el regalo.

¿Preguntas? Escríbenos a hola@narra.mx`;
}

function buildSelfPurchaseEmail(email: string, magicLink: string, appUrl: string, managementToken: string, authorName: string): string {
  const recoveryPortalUrl = `${appUrl}/gift-management?token=${managementToken}`;
  const greetingLine = authorName ? `Hola ${authorName},` : 'Hola,';
  return `<!DOCTYPE html>
<html lang="es">
  <head><meta charset="utf-8" /><meta name="viewport" content="width=device-width, initial-scale=1.0" /><title>¡Bienvenido a Narra!</title></head>
  <body style="margin:0;padding:0;background:linear-gradient(135deg, #fdfbf7 0%, #f0ebe3 100%);font-family:-apple-system,BlinkMacSystemFont,'Segoe UI','Helvetica Neue',Arial,sans-serif;color:#1f2937;">
    <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="max-width:660px;margin:40px auto;padding:0 20px;">
      <tr><td>
        <div style="text-align:center;margin-bottom:32px;"><img src="https://narra.mx/logo-horizontal.png" alt="Narra" style="height:36px;width:auto;" /></div>
        <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="background:#ffffff;border-radius:24px;box-shadow:0 20px 60px rgba(77,179,168,0.12),0 8px 20px rgba(0,0,0,0.06);overflow:hidden;">
          <tr><td style="padding:0;">
            <div style="background:linear-gradient(135deg, #4DB3A8 0%, #38827A 100%);padding:48px 36px;text-align:center;">
              <div style="display:inline-block;background:rgba(255,255,255,0.25);border-radius:16px;padding:12px 24px;margin-bottom:20px;"><p style="margin:0;font-size:14px;color:#ffffff;letter-spacing:0.08em;text-transform:uppercase;font-weight:600;">🎉 ¡BIENVENIDO!</p></div>
              <h1 style="font-size:32px;line-height:1.2;margin:0;font-weight:800;color:#ffffff;">Tu cuenta está lista</h1>
            </div>
            <div style="padding:40px 36px;">
              <p style="margin:0 0 24px 0;font-size:18px;line-height:1.65;color:#374151;font-weight:500;">${greetingLine}</p>
              <p style="margin:0 0 28px 0;font-size:17px;line-height:1.7;color:#4b5563;">¡Gracias por unirte a Narra! Tu cuenta ha sido creada.</p>
              <div style="text-align:center;margin:40px 0 32px;">
                <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto;">
                  <tr><td style="border-radius:16px;background:linear-gradient(135deg, #4DB3A8 0%, #38827A 100%);box-shadow:0 8px 24px rgba(77,179,168,0.35);">
                    <a href="${magicLink}" style="display:inline-block;color:#ffffff;text-decoration:none;font-weight:700;font-size:17px;padding:18px 42px;border-radius:16px;">🚀 Confirmar y Comenzar</a>
                  </td></tr>
                </table>
              </div>
              <div style="background:#f9fafb;border:2px dashed #e5e7eb;border-radius:12px;padding:20px;margin:24px 0 0 0;">
                <p style="margin:0 0 8px 0;font-size:13px;color:#6b7280;font-weight:600;">Si el botón no funciona:</p>
                <p style="margin:0;font-size:13px;word-break:break-all;"><a href="${magicLink}" style="color:#38827A;">${magicLink}</a></p>
              </div>
            </div>
            <div style="background:#FFFBEB;padding:24px 36px;border-top:1px solid #FDE68A;">
              <h3 style="margin:0 0 12px 0;font-size:16px;color:#92400E;text-align:center;font-weight:700;">🔐 Portal de Recuperación</h3>
              <p style="margin:0 0 16px 0;font-size:14px;color:#78350F;text-align:center;">Guarda este enlace para gestionar tu cuenta:</p>
              <div style="text-align:center;"><a href="${recoveryPortalUrl}" style="display:inline-block;background:#92400E;color:#ffffff;font-weight:600;font-size:14px;padding:12px 24px;border-radius:8px;text-decoration:none;">Acceder al Portal</a></div>
            </div>
            <div style="background:#fafaf9;padding:32px 36px;border-top:1px solid #e7e5e4;">
              <p style="margin:0;font-size:14px;color:#78716c;text-align:center;">¿Preguntas? <a href="mailto:hola@narra.mx" style="color:#38827A">hola@narra.mx</a></p>
            </div>
          </td></tr>
        </table>
      </td></tr>
    </table>
  </body>
</html>`;
}

function buildSelfPurchaseEmailText(email: string, magicLink: string, appUrl: string, managementToken: string, authorName: string): string {
  const greetingLine = authorName ? `Hola ${authorName},` : 'Hola,';
  return `${greetingLine}

Tu cuenta ha sido creada exitosamente.

Para confirmar tu cuenta y comenzar: ${magicLink}

Portal de recuperación (guarda este enlace): ${appUrl}/gift-management?token=${managementToken}

¿Preguntas? hola@narra.mx`;
}

function buildGiftAuthorEmail(email: string, magicLink: string, buyerName: string, giftMessage: string, authorName: string): string {
  const greetingLine = authorName ? `Hola ${authorName},` : 'Hola,';
  const hasMessage = giftMessage && giftMessage.trim() !== '';
  return `<!DOCTYPE html>
<html lang="es">
  <head><meta charset="utf-8" /><meta name="viewport" content="width=device-width, initial-scale=1.0" /></head>
  <body style="margin:0;padding:0;background:linear-gradient(135deg, #fdfbf7 0%, #f0ebe3 100%);font-family:-apple-system,BlinkMacSystemFont,'Segoe UI','Helvetica Neue',Arial,sans-serif;color:#1f2937;">
    <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="max-width:660px;margin:40px auto;padding:0 20px;">
      <tr><td>
        <div style="text-align:center;margin-bottom:32px;"><img src="https://narra.mx/logo-horizontal.png" alt="Narra" style="height:36px;width:auto;" /></div>
        <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="background:#ffffff;border-radius:24px;box-shadow:0 20px 60px rgba(77,179,168,0.12);overflow:hidden;">
          <tr><td style="padding:0;">
            <div style="background:linear-gradient(135deg, #4DB3A8 0%, #38827A 100%);padding:48px 36px;text-align:center;">
              <div style="font-size:80px;line-height:1;margin-bottom:20px;">🎁</div>
              <h1 style="font-size:32px;margin:0;font-weight:800;color:#ffffff;">¡${buyerName} te ha regalado Narra!</h1>
            </div>
            <div style="padding:40px 36px;">
              <p style="margin:0 0 24px 0;font-size:18px;color:#374151;font-weight:500;">${greetingLine}</p>
              <p style="margin:0 0 28px 0;font-size:17px;line-height:1.7;color:#4b5563;"><strong>${buyerName}</strong> te ha regalado acceso de por vida a Narra.</p>
              ${hasMessage ? `<div style="background:#FFF8F0;border-left:4px solid #F59E0B;border-radius:16px;padding:28px;margin:32px 0;"><div style="text-align:center;font-size:32px;margin-bottom:16px;">💌</div><p style="margin:0 0 12px 0;font-size:15px;color:#92400E;font-weight:700;text-align:center;">Mensaje de ${buyerName}</p><div style="background:#ffffff;border-radius:12px;padding:20px;"><p style="margin:0;font-size:16px;color:#374151;font-style:italic;text-align:center;">"${giftMessage}"</p></div></div>` : ''}
              <div style="text-align:center;margin:40px 0 32px;">
                <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto;">
                  <tr><td style="border-radius:16px;background:linear-gradient(135deg, #4DB3A8 0%, #38827A 100%);box-shadow:0 8px 24px rgba(77,179,168,0.35);">
                    <a href="${magicLink}" style="display:inline-block;color:#ffffff;text-decoration:none;font-weight:700;font-size:17px;padding:18px 42px;border-radius:16px;">🚀 Comenzar Ahora</a>
                  </td></tr>
                </table>
              </div>
            </div>
            <div style="background:#fafaf9;padding:32px 36px;border-top:1px solid #e7e5e4;">
              <p style="margin:0;font-size:14px;color:#78716c;text-align:center;">¿Preguntas? <a href="mailto:hola@narra.mx" style="color:#38827A">hola@narra.mx</a></p>
            </div>
          </td></tr>
        </table>
      </td></tr>
    </table>
  </body>
</html>`;
}

function buildGiftAuthorEmailText(email: string, magicLink: string, buyerName: string, giftMessage: string, authorName: string): string {
  const greetingLine = authorName ? `Hola ${authorName},` : 'Hola,';
  let text = `¡${buyerName} te ha regalado Narra!\n\n${greetingLine}\n\n${buyerName} te ha regalado acceso de por vida a Narra.`;
  if (giftMessage) text += `\n\nMensaje de ${buyerName}:\n"${giftMessage}"`;
  text += `\n\nPara comenzar: ${magicLink}\n\n¿Preguntas? hola@narra.mx`;
  return text;
}

function buildGiftBuyerEmail(buyerEmail: string, authorEmail: string, managementUrl: string, authorName: string): string {
  const displayName = authorName || authorEmail;
  return `<!DOCTYPE html>
<html lang="es">
  <head><meta charset="utf-8" /><meta name="viewport" content="width=device-width, initial-scale=1.0" /></head>
  <body style="margin:0;padding:0;background:linear-gradient(135deg, #fdfbf7 0%, #f0ebe3 100%);font-family:-apple-system,BlinkMacSystemFont,'Segoe UI','Helvetica Neue',Arial,sans-serif;color:#1f2937;">
    <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="max-width:660px;margin:40px auto;padding:0 20px;">
      <tr><td>
        <div style="text-align:center;margin-bottom:32px;"><img src="https://narra.mx/logo-horizontal.png" alt="Narra" style="height:36px;width:auto;" /></div>
        <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="background:#ffffff;border-radius:24px;box-shadow:0 20px 60px rgba(77,179,168,0.12);overflow:hidden;">
          <tr><td style="padding:0;">
            <div style="background:linear-gradient(135deg, #4DB3A8 0%, #38827A 100%);padding:48px 36px;text-align:center;">
              <div style="display:inline-block;background:rgba(255,255,255,0.25);border-radius:16px;padding:12px 24px;margin-bottom:20px;"><p style="margin:0;font-size:14px;color:#ffffff;letter-spacing:0.08em;text-transform:uppercase;font-weight:600;">✅ REGALO ENVIADO</p></div>
              <h1 style="font-size:32px;margin:0;font-weight:800;color:#ffffff;">¡Tu regalo fue enviado!</h1>
            </div>
            <div style="padding:40px 36px;">
              <p style="margin:0 0 24px 0;font-size:18px;color:#374151;font-weight:500;">Hola,</p>
              <p style="margin:0 0 28px 0;font-size:17px;line-height:1.7;color:#4b5563;">Tu regalo de Narra ha sido enviado a <strong>${displayName}</strong>.</p>
              <div style="background:#E8F5F4;border-left:4px solid #4DB3A8;border-radius:16px;padding:24px;margin:32px 0;">
                <p style="margin:0 0 12px 0;font-size:15px;color:#38827A;font-weight:700;">🎁 Panel de Gestión</p>
                <p style="margin:0;font-size:14px;color:#4b5563;">Desde este panel puedes gestionar el regalo, cambiar el email del destinatario y más.</p>
              </div>
              <div style="text-align:center;margin:40px 0 32px;">
                <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto;">
                  <tr><td style="border-radius:16px;background:linear-gradient(135deg, #4DB3A8 0%, #38827A 100%);box-shadow:0 8px 24px rgba(77,179,168,0.35);">
                    <a href="${managementUrl}" style="display:inline-block;color:#ffffff;text-decoration:none;font-weight:700;font-size:17px;padding:18px 42px;border-radius:16px;">🎯 Acceder al Panel</a>
                  </td></tr>
                </table>
              </div>
              <div style="background:#FFFBEB;border:2px solid #fde047;border-radius:16px;padding:24px;margin:32px 0;">
                <p style="margin:0;font-size:14px;color:#92400e;"><strong>⚡ Importante:</strong> Guarda este email. El enlace del panel no expira.</p>
              </div>
            </div>
            <div style="background:#fafaf9;padding:32px 36px;border-top:1px solid #e7e5e4;">
              <p style="margin:0;font-size:14px;color:#78716c;text-align:center;">¿Preguntas? <a href="mailto:hola@narra.mx" style="color:#38827A">hola@narra.mx</a></p>
            </div>
          </td></tr>
        </table>
      </td></tr>
    </table>
  </body>
</html>`;
}

function buildGiftBuyerEmailText(buyerEmail: string, authorEmail: string, managementUrl: string, authorName: string): string {
  const displayName = authorName || authorEmail;
  return `¡Tu regalo fue enviado!

Tu regalo de Narra ha sido enviado a ${displayName}.

Panel de Gestión: ${managementUrl}

Guarda este email. El enlace no expira.

¿Preguntas? hola@narra.mx`;
}
