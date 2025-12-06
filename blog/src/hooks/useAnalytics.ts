import { useEffect, useCallback } from 'react';
import { useLocation } from 'react-router-dom';

// ============================================================
// CONFIGURACION
// ============================================================
const GA4_MEASUREMENT_ID = 'G-4GQ0HNZG0Y';
const GOOGLE_ADS_ID = 'AW-17774980441';

// ============================================================
// Tipos
// ============================================================
declare global {
  interface Window {
    dataLayer: unknown[];
    gtag: (...args: unknown[]) => void;
    gtagInitialized?: boolean;
  }
}

type EventParams = Record<string, string | number | boolean | undefined>;

// ============================================================
// Inicializacion de gtag
// ============================================================
const initializeGtag = () => {
  if (typeof window === 'undefined') return;

  // Solo inicializar una vez
  if (window.gtagInitialized) return;

  // Crear dataLayer si no existe
  window.dataLayer = window.dataLayer || [];

  // Crear funcion gtag
  window.gtag = function gtag(...args: unknown[]) {
    window.dataLayer.push(args);
  };

  // Cargar script de gtag.js (usa GA4 como ID principal)
  const script = document.createElement('script');
  script.async = true;
  script.src = `https://www.googletagmanager.com/gtag/js?id=${GA4_MEASUREMENT_ID}`;
  document.head.appendChild(script);

  // Inicializar
  window.gtag('js', new Date());

  // Configurar GA4
  window.gtag('config', GA4_MEASUREMENT_ID, {
    send_page_view: false, // Lo manejamos manualmente para SPA
    cookie_flags: 'SameSite=None;Secure',
  });

  // Configurar Google Ads
  window.gtag('config', GOOGLE_ADS_ID);

  window.gtagInitialized = true;
};

// ============================================================
// Hook principal de Analytics
// ============================================================
export const useAnalytics = () => {
  const location = useLocation();

  // Inicializar al montar
  useEffect(() => {
    initializeGtag();
  }, []);

  // Rastrear pageviews automaticamente
  useEffect(() => {
    if (!window.gtag) return;

    // Pequeno delay para asegurar que el titulo de la pagina este actualizado
    const timeout = setTimeout(() => {
      window.gtag('event', 'page_view', {
        page_path: location.pathname + location.search,
        page_title: document.title,
        page_location: window.location.href,
      });
    }, 100);

    return () => clearTimeout(timeout);
  }, [location.pathname, location.search]);
};

// ============================================================
// Funciones de tracking de eventos
// ============================================================

/**
 * Evento generico
 */
export const trackEvent = (eventName: string, params?: EventParams) => {
  if (typeof window === 'undefined' || !window.gtag) return;
  window.gtag('event', eventName, params);
};

/**
 * Clic en CTA principal (botones de comprar)
 */
export const trackCTAClick = (
  ctaName: string,
  location: string,
  destination?: string
) => {
  trackEvent('cta_click', {
    cta_name: ctaName,
    cta_location: location,
    destination: destination,
  });
};

/**
 * Inicio del funnel de compra
 */
export const trackBeginCheckout = (
  purchaseType: 'self' | 'gift',
  value?: number,
  currency?: string
) => {
  trackEvent('begin_checkout', {
    purchase_type: purchaseType,
    value: value,
    currency: currency || 'MXN',
  });
};

/**
 * Seleccion de tipo de compra
 */
export const trackSelectPurchaseType = (purchaseType: 'self' | 'gift') => {
  trackEvent('select_purchase_type', {
    purchase_type: purchaseType,
  });
};

/**
 * Seleccion de timing de regalo
 */
export const trackSelectGiftTiming = (timing: 'now' | 'later') => {
  trackEvent('select_gift_timing', {
    gift_timing: timing,
  });
};

/**
 * Envio del formulario de checkout
 */
export const trackCheckoutSubmit = (
  purchaseType: 'self' | 'gift',
  giftTiming?: 'now' | 'later'
) => {
  trackEvent('checkout_submit', {
    purchase_type: purchaseType,
    gift_timing: giftTiming,
  });
};

/**
 * Compra completada (conversion)
 */
export const trackPurchase = (
  transactionId: string,
  value: number,
  purchaseType: 'self' | 'gift',
  currency: string = 'MXN'
) => {
  // Evento de GA4
  trackEvent('purchase', {
    transaction_id: transactionId,
    value: value,
    currency: currency,
    purchase_type: purchaseType,
  });

  // Conversion de Google Ads (mantener compatibilidad)
  if (window.gtag) {
    window.gtag('event', 'conversion', {
      send_to: 'AW-17774980441/Szt7CNSb28obENna4ptC',
      transaction_id: transactionId,
      value: value,
      currency: currency,
    });
  }
};

/**
 * Visualizacion de seccion importante
 */
export const trackSectionView = (sectionName: string) => {
  trackEvent('section_view', {
    section_name: sectionName,
  });
};

/**
 * Scroll depth (porcentaje de scroll)
 */
export const trackScrollDepth = (percentage: number, pagePath: string) => {
  trackEvent('scroll_depth', {
    percent_scrolled: percentage,
    page_path: pagePath,
  });
};

/**
 * Clic en enlace externo
 */
export const trackOutboundLink = (url: string, linkText?: string) => {
  trackEvent('click', {
    event_category: 'outbound',
    event_label: url,
    link_text: linkText,
  });
};

/**
 * Interaccion con el banner de navidad
 */
export const trackBannerInteraction = (
  action: 'view' | 'click' | 'dismiss',
  bannerName: string
) => {
  trackEvent('banner_interaction', {
    action: action,
    banner_name: bannerName,
  });
};

/**
 * Error en el flujo
 */
export const trackError = (errorType: string, errorMessage: string, page: string) => {
  trackEvent('error', {
    error_type: errorType,
    error_message: errorMessage,
    page: page,
  });
};

/**
 * Engagement con formulario
 */
export const trackFormEngagement = (
  formName: string,
  action: 'start' | 'field_focus' | 'field_complete' | 'submit' | 'error'
) => {
  trackEvent('form_engagement', {
    form_name: formName,
    action: action,
  });
};

// ============================================================
// Hook para scroll tracking
// ============================================================
export const useScrollTracking = () => {
  const location = useLocation();

  useEffect(() => {
    const thresholds = [25, 50, 75, 90];
    const tracked = new Set<number>();

    const handleScroll = () => {
      const scrollTop = window.scrollY;
      const docHeight = document.documentElement.scrollHeight - window.innerHeight;
      const scrollPercent = Math.round((scrollTop / docHeight) * 100);

      thresholds.forEach((threshold) => {
        if (scrollPercent >= threshold && !tracked.has(threshold)) {
          tracked.add(threshold);
          trackScrollDepth(threshold, location.pathname);
        }
      });
    };

    // Debounce scroll handler
    let timeout: NodeJS.Timeout;
    const debouncedScroll = () => {
      clearTimeout(timeout);
      timeout = setTimeout(handleScroll, 100);
    };

    window.addEventListener('scroll', debouncedScroll, { passive: true });

    return () => {
      window.removeEventListener('scroll', debouncedScroll);
      clearTimeout(timeout);
    };
  }, [location.pathname]);
};

export default useAnalytics;
