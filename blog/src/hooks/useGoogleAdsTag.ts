import { useEffect } from 'react';

const GOOGLE_ADS_ID = 'AW-17774980441';
const SCRIPT_ID = 'google-ads-gtag';

declare global {
  interface Window {
    dataLayer?: unknown[];
    gtag?: (...args: unknown[]) => void;
    gtagInitialized?: boolean;
  }
}

export const useGoogleAdsTag = () => {
  useEffect(() => {
    const existingScript = document.getElementById(SCRIPT_ID);
    if (!existingScript) {
      const script = document.createElement('script');
      script.id = SCRIPT_ID;
      script.async = true;
      script.src = `https://www.googletagmanager.com/gtag/js?id=${GOOGLE_ADS_ID}`;
      document.head.appendChild(script);
    }

    if (!window.dataLayer) {
      window.dataLayer = [];
    }

    if (!window.gtag) {
      window.gtag = (...args: unknown[]) => {
        window.dataLayer?.push(args);
      };
    }

    if (!window.gtagInitialized) {
      window.gtag('js', new Date());
      window.gtag('config', GOOGLE_ADS_ID);
      window.gtagInitialized = true;
    }
  }, []);
};
