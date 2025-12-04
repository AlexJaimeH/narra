import { useEffect } from 'react';

declare global {
  interface Window {
    gtag?: (...args: unknown[]) => void;
    dataLayer?: unknown[];
  }
}

export const useGoogleAdsPurchaseConversion = () => {
  useEffect(() => {
    console.log('[Google Ads] Starting conversion tracking setup');

    // Wait for gtag to be available
    const sendConversionEvent = () => {
      if (window.gtag) {
        console.log('[Google Ads] Sending conversion event with ID: AW-17774980441/Szt7CNSb28obENna4ptC');

        // Send conversion with the correct ID and label
        window.gtag('event', 'conversion', {
          'send_to': 'AW-17774980441/Szt7CNSb28obENna4ptC',
          'transaction_id': ''
        });

        console.log('[Google Ads] Conversion event sent successfully');
      } else {
        console.warn('[Google Ads] gtag not available');
      }
    };

    // Try sending immediately if gtag is ready
    if (window.gtag && window.dataLayer) {
      console.log('[Google Ads] gtag and dataLayer already available, sending immediately');
      sendConversionEvent();
    } else {
      // Wait for gtag to load
      console.log('[Google Ads] Waiting for gtag to load...');
      let attempts = 0;
      const maxAttempts = 50; // 5 seconds with 100ms intervals

      const checkGtag = setInterval(() => {
        attempts++;

        if (window.gtag && window.dataLayer) {
          console.log(`[Google Ads] gtag loaded after ${attempts * 100}ms`);
          sendConversionEvent();
          clearInterval(checkGtag);
        } else if (attempts >= maxAttempts) {
          console.error('[Google Ads] gtag failed to load after 5 seconds');
          clearInterval(checkGtag);
        }
      }, 100);

      return () => {
        clearInterval(checkGtag);
      };
    }
  }, []);
};
