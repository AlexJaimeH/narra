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
              {/* Book icon */}
              <motion.svg
                animate={{
                  y: [0, -5, 0]
                }}
                transition={{
                  duration: 2,
                  repeat: Infinity,
                  ease: "easeInOut"
                }}
                className="w-10 h-10 text-white"
                fill="currentColor"
                viewBox="0 0 20 20"
              >
                <path d="M9 4.804A7.968 7.968 0 005.5 4c-1.255 0-2.443.29-3.5.804v10A7.969 7.969 0 015.5 14c1.669 0 3.218.51 4.5 1.385A7.962 7.962 0 0114.5 14c1.255 0 2.443.29 3.5.804v-10A7.968 7.968 0 0014.5 4c-1.255 0-2.443.29-3.5.804V12a1 1 0 11-2 0V4.804z" />
              </motion.svg>
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
