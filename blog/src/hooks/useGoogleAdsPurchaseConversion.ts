import { useEffect } from 'react';

declare global {
  interface Window {
    gtag?: (...args: unknown[]) => void;
  }
}

export const useGoogleAdsPurchaseConversion = () => {
  useEffect(() => {
    // Wait for gtag to be available
    const sendConversionEvent = () => {
      if (window.gtag) {
        window.gtag('event', 'conversion', {
          'send_to': 'AW-17774980441/QmIwCOKtxssbENna4ptC',
          'transaction_id': ''
        });
      }
    };

    // If gtag is already available, send immediately
    if (window.gtag) {
      sendConversionEvent();
    } else {
      // Otherwise, wait for it to load
      const checkGtag = setInterval(() => {
        if (window.gtag) {
          sendConversionEvent();
          clearInterval(checkGtag);
        }
      }, 100);

      // Cleanup interval after 5 seconds max
      setTimeout(() => clearInterval(checkGtag), 5000);

      return () => clearInterval(checkGtag);
    }
  }, []);
};
