import { useState, useEffect } from 'react';

export interface StripePriceData {
  originalPrice: number;
  discountedPrice: number;
  discountAmount: number;
  discountPercentage: number;
  currency: string;
  hasCoupon: boolean;
  couponName: string | null;
  priceId: string;
  productId: string;
}

interface UseStripePriceResult {
  priceData: StripePriceData | null;
  loading: boolean;
  error: string | null;
  refetch: () => void;
}

// Default fallback prices (in case API fails)
const FALLBACK_PRICE: StripePriceData = {
  originalPrice: 300,
  discountedPrice: 300,
  discountAmount: 0,
  discountPercentage: 0,
  currency: 'MXN',
  hasCoupon: false,
  couponName: null,
  priceId: '',
  productId: '',
};

// Cache for the price data (avoid multiple fetches)
let cachedPriceData: StripePriceData | null = null;
let cacheTimestamp: number = 0;
const CACHE_DURATION = 5 * 60 * 1000; // 5 minutes

export function useStripePrice(): UseStripePriceResult {
  const [priceData, setPriceData] = useState<StripePriceData | null>(cachedPriceData);
  const [loading, setLoading] = useState(!cachedPriceData);
  const [error, setError] = useState<string | null>(null);

  const fetchPrice = async () => {
    // Check cache first
    const now = Date.now();
    if (cachedPriceData && now - cacheTimestamp < CACHE_DURATION) {
      setPriceData(cachedPriceData);
      setLoading(false);
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const response = await fetch('/api/stripe-price');

      if (!response.ok) {
        throw new Error('Failed to fetch price');
      }

      const data = await response.json();

      if (data.success) {
        const newPriceData: StripePriceData = {
          originalPrice: data.originalPrice,
          discountedPrice: data.discountedPrice,
          discountAmount: data.discountAmount,
          discountPercentage: data.discountPercentage,
          currency: data.currency,
          hasCoupon: data.hasCoupon,
          couponName: data.couponName,
          priceId: data.priceId,
          productId: data.productId,
        };

        // Update cache
        cachedPriceData = newPriceData;
        cacheTimestamp = now;

        setPriceData(newPriceData);
      } else {
        throw new Error(data.error || 'Unknown error');
      }
    } catch (err) {
      console.error('Error fetching Stripe price:', err);
      setError(err instanceof Error ? err.message : 'Failed to load price');
      // Use fallback price on error
      setPriceData(FALLBACK_PRICE);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchPrice();
  }, []);

  return {
    priceData,
    loading,
    error,
    refetch: fetchPrice,
  };
}

// Utility function to format price in MXN
export function formatPrice(amount: number, currency: string = 'MXN'): string {
  return new Intl.NumberFormat('es-MX', {
    style: 'currency',
    currency,
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(amount);
}

// Component to display price with discount
export function PriceDisplay({
  priceData,
  showDiscount = true,
  size = 'normal',
}: {
  priceData: StripePriceData | null;
  showDiscount?: boolean;
  size?: 'small' | 'normal' | 'large';
}) {
  if (!priceData) {
    return <span className="animate-pulse">Cargando...</span>;
  }

  const sizeClasses = {
    small: { price: 'text-2xl', currency: 'text-lg', original: 'text-sm' },
    normal: { price: 'text-4xl', currency: 'text-xl', original: 'text-lg' },
    large: { price: 'text-5xl', currency: 'text-2xl', original: 'text-xl' },
  };

  const classes = sizeClasses[size];

  if (!showDiscount || !priceData.hasCoupon) {
    return (
      <div className="flex items-baseline gap-2">
        <span className={`${classes.price} font-bold`} style={{ color: '#4DB3A8' }}>
          {formatPrice(priceData.originalPrice, priceData.currency)}
        </span>
        <span className={`${classes.currency}`} style={{ color: '#4B5563' }}>
          {priceData.currency}
        </span>
      </div>
    );
  }

  return (
    <div className="flex flex-col items-center gap-1">
      {/* Original price - strikethrough */}
      <div className="flex items-center gap-2">
        <span
          className={`${classes.original} line-through`}
          style={{ color: '#9CA3AF' }}
        >
          {formatPrice(priceData.originalPrice, priceData.currency)}
        </span>
        <span
          className="px-2 py-1 rounded-full text-xs font-bold"
          style={{ background: '#FEF3C7', color: '#92400E' }}
        >
          -{priceData.discountPercentage}%
        </span>
      </div>
      {/* Discounted price */}
      <div className="flex items-baseline gap-2">
        <span className={`${classes.price} font-bold`} style={{ color: '#4DB3A8' }}>
          {formatPrice(priceData.discountedPrice, priceData.currency)}
        </span>
        <span className={`${classes.currency}`} style={{ color: '#4B5563' }}>
          {priceData.currency}
        </span>
      </div>
    </div>
  );
}
