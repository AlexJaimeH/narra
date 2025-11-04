import React from 'react';
import { motion } from 'framer-motion';
import { NarraColors } from '../styles/colors';

export const Loading: React.FC = () => {
  return (
    <div className="flex items-center justify-center min-h-screen" style={{ background: `linear-gradient(to bottom, ${NarraColors.brand.primaryPale}, ${NarraColors.surface.white})` }}>
      <motion.div
        initial={{ opacity: 0, scale: 0.8 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ duration: 0.5 }}
        className="text-center"
      >
        {/* Animated book icon */}
        <div className="relative mb-6">
          {/* Outer circle with pulse */}
          <div className="absolute inset-0 flex items-center justify-center">
            <motion.div
              animate={{
                scale: [1, 1.2, 1],
                opacity: [0.5, 0.8, 0.5]
              }}
              transition={{
                duration: 2,
                repeat: Infinity,
                ease: "easeInOut"
              }}
              className="w-24 h-24 rounded-full"
              style={{ backgroundColor: `${NarraColors.brand.primaryLight}` }}
            />
          </div>

          {/* Inner spinning circle */}
          <div className="relative flex items-center justify-center">
            <motion.div
              animate={{ rotate: 360 }}
              transition={{
                duration: 3,
                repeat: Infinity,
                ease: "linear"
              }}
              className="w-20 h-20 rounded-full flex items-center justify-center"
              style={{
                background: `linear-gradient(135deg, ${NarraColors.brand.primary}, ${NarraColors.brand.accent})`,
                boxShadow: '0 10px 40px rgba(77, 179, 168, 0.3)'
              }}
            >
              {/* Narra Logo */}
              <motion.img
                animate={{
                  y: [0, -5, 0]
                }}
                transition={{
                  duration: 2,
                  repeat: Infinity,
                  ease: "easeInOut"
                }}
                src="/logo.png"
                alt="Narra"
                className="w-12 h-12 object-contain"
              />
            </motion.div>
          </div>
        </div>

        {/* Loading text with shimmer effect */}
        <div className="space-y-2">
          <motion.p
            animate={{
              opacity: [1, 0.7, 1]
            }}
            transition={{
              duration: 1.5,
              repeat: Infinity,
              ease: "easeInOut"
            }}
            className="text-xl font-semibold"
            style={{ color: NarraColors.text.primary }}
          >
            Cargando historias
          </motion.p>
          <div className="flex items-center justify-center gap-1">
            <motion.div
              animate={{ y: [0, -10, 0] }}
              transition={{
                duration: 0.6,
                repeat: Infinity,
                ease: "easeInOut",
                delay: 0
              }}
              className="w-2 h-2 rounded-full"
              style={{ backgroundColor: NarraColors.brand.primary }}
            />
            <motion.div
              animate={{ y: [0, -10, 0] }}
              transition={{
                duration: 0.6,
                repeat: Infinity,
                ease: "easeInOut",
                delay: 0.15
              }}
              className="w-2 h-2 rounded-full"
              style={{ backgroundColor: NarraColors.brand.primary }}
            />
            <motion.div
              animate={{ y: [0, -10, 0] }}
              transition={{
                duration: 0.6,
                repeat: Infinity,
                ease: "easeInOut",
                delay: 0.3
              }}
              className="w-2 h-2 rounded-full"
              style={{ backgroundColor: NarraColors.brand.primary }}
            />
          </div>
        </div>
      </motion.div>
    </div>
  );
};
