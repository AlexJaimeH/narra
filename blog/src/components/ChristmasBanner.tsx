import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';

const BANNER_DISMISSED_KEY = 'narra_christmas_banner_dismissed_2024';

interface ChristmasBannerProps {
  onVisibilityChange?: (visible: boolean) => void;
}

export const ChristmasBanner: React.FC<ChristmasBannerProps> = ({ onVisibilityChange }) => {
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    // Check if banner was previously dismissed
    const wasDismissed = localStorage.getItem(BANNER_DISMISSED_KEY);
    const shouldShow = !wasDismissed;
    setIsVisible(shouldShow);
    onVisibilityChange?.(shouldShow);
  }, [onVisibilityChange]);

  const handleDismiss = () => {
    setIsVisible(false);
    onVisibilityChange?.(false);
    localStorage.setItem(BANNER_DISMISSED_KEY, 'true');
  };

  return (
    <AnimatePresence>
      {isVisible && (
        <motion.div
          initial={{ height: 0, opacity: 0 }}
          animate={{ height: 'auto', opacity: 1 }}
          exit={{ height: 0, opacity: 0 }}
          transition={{ duration: 0.3, ease: 'easeInOut' }}
          className="fixed top-0 left-0 right-0 w-full overflow-hidden z-[60]"
          style={{
            background: 'linear-gradient(135deg, #1a472a 0%, #2d5a3d 50%, #1a472a 100%)',
          }}
        >
          <div className="relative px-4 py-3 sm:py-4">
            {/* Decorative snowflakes */}
            <div className="absolute inset-0 overflow-hidden pointer-events-none">
              <div className="absolute top-1 left-[5%] text-white/20 text-lg animate-pulse">*</div>
              <div className="absolute top-2 left-[15%] text-white/15 text-sm">*</div>
              <div className="absolute bottom-1 left-[25%] text-white/20 text-base animate-pulse">*</div>
              <div className="absolute top-1 right-[20%] text-white/15 text-lg">*</div>
              <div className="absolute bottom-2 right-[10%] text-white/20 text-sm animate-pulse">*</div>
              <div className="absolute top-3 right-[35%] text-white/10 text-base">*</div>
            </div>

            <div className="max-w-7xl mx-auto flex flex-col sm:flex-row items-center justify-center gap-3 sm:gap-6 relative">
              {/* Christmas icon and promo text */}
              <div className="flex items-center gap-2 sm:gap-3 text-center sm:text-left">
                <span className="text-2xl sm:text-3xl" role="img" aria-label="Christmas tree">
                  🎄
                </span>
                <div className="flex flex-col sm:flex-row sm:items-center sm:gap-2">
                  <span className="text-white font-bold text-sm sm:text-base">
                    Promocion Navidad
                  </span>
                  <span className="hidden sm:inline text-white/60">|</span>
                  <span className="text-white/90 text-sm sm:text-base">
                    Narra de{' '}
                    <span className="line-through text-white/60">$500</span>
                    {' '}a{' '}
                    <span className="text-yellow-300 font-bold text-base sm:text-lg">$300 MXN</span>
                  </span>
                </div>
              </div>

              {/* Benefits badge */}
              <div className="hidden md:flex items-center gap-2 px-3 py-1 rounded-full bg-white/10 backdrop-blur-sm">
                <span className="text-white/90 text-xs">
                  Pago unico • Todas las funciones • Actualizaciones gratis
                </span>
              </div>

              {/* CTA Button */}
              <motion.a
                href="/purchase?type=gift"
                className="flex items-center gap-2 px-5 py-2 rounded-full font-bold text-sm shadow-lg"
                style={{
                  background: 'linear-gradient(135deg, #c41e3a 0%, #a01830 100%)',
                  color: 'white',
                }}
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
              >
                <span className="text-lg" role="img" aria-label="Gift">🎁</span>
                <span>Comprar ahora</span>
              </motion.a>

              {/* Close button */}
              <button
                onClick={handleDismiss}
                className="absolute right-2 top-1/2 -translate-y-1/2 sm:relative sm:right-auto sm:top-auto sm:translate-y-0 p-2 text-white/60 hover:text-white transition-colors rounded-full hover:bg-white/10"
                aria-label="Cerrar banner"
              >
                <svg
                  className="w-5 h-5"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  strokeWidth={2}
                >
                  <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            {/* Mobile benefits text */}
            <div className="md:hidden text-center mt-2">
              <span className="text-white/70 text-xs">
                Pago unico • Todas las funciones • Actualizaciones gratis
              </span>
            </div>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
};

export default ChristmasBanner;
