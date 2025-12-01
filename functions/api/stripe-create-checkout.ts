/**
 * API endpoint to create a Stripe Checkout session
 * POST /api/stripe-create-checkout
 *
 * Creates a checkout session with the coupon automatically applied
 */

interface Env {
  STRIPE_SECRET_KEY: string;
  STRIPE_PRICE_ID: string;
  STRIPE_COUPON_ID: string;
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
    if (!env.STRIPE_SECRET_KEY) {
      console.error('[stripe-create-checkout] Missing STRIPE_SECRET_KEY');
      return json({ error: 'Stripe not configured' }, 500);
    }

    const payload = await request.json().catch(() => null);
    if (!payload || typeof payload !== 'object') {
      return json({ error: 'Invalid request body' }, 400);
    }

    const purchaseType = (payload as any).purchaseType as string;
    const authorEmail = ((payload as any).authorEmail as string || '').toLowerCase().trim();
    const authorName = ((payload as any).authorName as string || '').trim();
    const buyerEmail = ((payload as any).buyerEmail as string || '').toLowerCase().trim();
    const buyerName = ((payload as any).buyerName as string || '').trim();
    const giftMessage = ((payload as any).giftMessage as string || '').trim();
    const giftTiming = (payload as any).giftTiming as string; // 'now' or 'later'

    // Validate
    if (!purchaseType || !['self', 'gift'].includes(purchaseType)) {
      return json({ error: 'Invalid purchase type' }, 400);
    }

    const priceId = env.STRIPE_PRICE_ID || 'price_1SZfF1CA2DgWjmuROEZkHE1G';
    const couponId = env.STRIPE_COUPON_ID || 'egeS4YL0';
    const appUrl = env.APP_URL || 'https://narra.mx';

    // Generate a unique session token to track this purchase
    const sessionToken = generateToken();

    // Determine customer email for Stripe
    const customerEmail = purchaseType === 'gift' && giftTiming === 'later'
      ? buyerEmail
      : purchaseType === 'gift'
        ? buyerEmail || authorEmail
        : authorEmail;

    // Build metadata to pass through checkout
    const metadata: Record<string, string> = {
      session_token: sessionToken,
      purchase_type: purchaseType,
      author_email: authorEmail,
      author_name: authorName,
    };

    if (purchaseType === 'gift') {
      metadata.gift_timing = giftTiming || 'now';
      metadata.buyer_email = buyerEmail;
      metadata.buyer_name = buyerName;
      if (giftMessage) {
        metadata.gift_message = giftMessage.substring(0, 500); // Stripe metadata limit
      }
    }

    // Build the request body for Stripe API
    const params = new URLSearchParams();
    params.append('mode', 'payment');
    params.append('line_items[0][price]', priceId);
    params.append('line_items[0][quantity]', '1');
    params.append('success_url', `${appUrl}/purchase/success?session_id={CHECKOUT_SESSION_ID}&type=${purchaseType}${giftTiming === 'later' ? '&timing=later' : ''}`);
    params.append('cancel_url', `${appUrl}/purchase/checkout?type=${purchaseType}&cancelled=true`);
    params.append('customer_email', customerEmail);

    // Apply coupon automatically
    if (couponId) {
      params.append('discounts[0][coupon]', couponId);
    }

    // Add metadata
    Object.entries(metadata).forEach(([key, value]) => {
      params.append(`metadata[${key}]`, value);
    });

    // Payment method types
    params.append('payment_method_types[0]', 'card');

    // Locale for Mexican users
    params.append('locale', 'es');

    // Create Stripe Checkout Session
    const checkoutResponse = await fetch('https://api.stripe.com/v1/checkout/sessions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${env.STRIPE_SECRET_KEY}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: params.toString(),
    });

    if (!checkoutResponse.ok) {
      const errorText = await checkoutResponse.text();
      console.error('[stripe-create-checkout] Stripe error:', errorText);
      return json({ error: 'Failed to create checkout session' }, 500);
    }

    const session = await checkoutResponse.json() as any;

    console.log('[stripe-create-checkout] Session created:', session.id);

    return json({
      success: true,
      sessionId: session.id,
      url: session.url,
      sessionToken,
    });

  } catch (error) {
    console.error('[stripe-create-checkout] Unexpected error:', error);
    return json({ error: 'Internal server error' }, 500);
  }
};
