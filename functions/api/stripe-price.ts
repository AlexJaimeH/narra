/**
 * API endpoint to get dynamic pricing from Stripe
 * GET /api/stripe-price
 *
 * Returns the product price with coupon applied (if any)
 */

interface Env {
  STRIPE_SECRET_KEY: string;
  STRIPE_PRICE_ID: string;
  STRIPE_COUPON_ID: string;
}

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
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

export const onRequestGet: PagesFunction<Env> = async ({ env }) => {
  try {
    if (!env.STRIPE_SECRET_KEY) {
      console.error('[stripe-price] Missing STRIPE_SECRET_KEY');
      return json({ error: 'Stripe not configured' }, 500);
    }

    const priceId = env.STRIPE_PRICE_ID || 'price_1SZfF1CA2DgWjmuROEZkHE1G';
    const couponId = env.STRIPE_COUPON_ID || 'egeS4YL0';

    // Fetch price from Stripe
    const priceResponse = await fetch(`https://api.stripe.com/v1/prices/${priceId}`, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${env.STRIPE_SECRET_KEY}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    });

    if (!priceResponse.ok) {
      const errorText = await priceResponse.text();
      console.error('[stripe-price] Failed to fetch price:', errorText);
      return json({ error: 'Failed to fetch price from Stripe' }, 500);
    }

    const priceData = await priceResponse.json() as any;

    // Get the original price in cents
    const originalPriceCents = priceData.unit_amount;
    const currency = priceData.currency;

    // Fetch coupon from Stripe
    let discountedPriceCents = originalPriceCents;
    let couponData: any = null;
    let discountPercentage = 0;
    let discountAmountCents = 0;

    if (couponId) {
      const couponResponse = await fetch(`https://api.stripe.com/v1/coupons/${couponId}`, {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${env.STRIPE_SECRET_KEY}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      });

      if (couponResponse.ok) {
        couponData = await couponResponse.json() as any;

        if (couponData.valid) {
          if (couponData.percent_off) {
            discountPercentage = couponData.percent_off;
            discountAmountCents = Math.round(originalPriceCents * (discountPercentage / 100));
            discountedPriceCents = originalPriceCents - discountAmountCents;
          } else if (couponData.amount_off) {
            discountAmountCents = couponData.amount_off;
            discountedPriceCents = originalPriceCents - discountAmountCents;
            discountPercentage = Math.round((discountAmountCents / originalPriceCents) * 100);
          }
        }
      } else {
        console.warn('[stripe-price] Coupon not found or invalid:', couponId);
      }
    }

    // Convert to display amounts (from cents to currency units)
    const originalPrice = originalPriceCents / 100;
    const discountedPrice = discountedPriceCents / 100;
    const discountAmount = discountAmountCents / 100;

    return json({
      success: true,
      originalPrice,
      discountedPrice,
      discountAmount,
      discountPercentage,
      currency: currency.toUpperCase(),
      hasCoupon: couponData?.valid || false,
      couponName: couponData?.name || null,
      priceId,
      productId: priceData.product,
    });

  } catch (error) {
    console.error('[stripe-price] Unexpected error:', error);
    return json({ error: 'Internal server error' }, 500);
  }
};
