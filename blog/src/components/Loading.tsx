import React from 'react';
import { motion } from 'framer-motion';
import { NarraColors } from '../styles/colors';

export const Loading: React.FC = () => {
  return (
    <div className="flex items-center justify-center min-h-screen" style={{ background: `linear-gradient(to bottom, ${NarraColors.brand.primaryPale}, ${NarraColors.surface.white})` }}>
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
        className="text-center"
      >
        {/* Logo con animación suave y brillo */}
        <div className="relative mb-8 flex items-center justify-center">
          {/* Glow effect detrás del logo */}
          <motion.div
            animate={{
              scale: [1, 1.15, 1],
              opacity: [0.2, 0.4, 0.2]
            }}
            transition={{
              duration: 2.5,
              repeat: Infinity,
              ease: "easeInOut"
            }}
            className="absolute w-32 h-32 rounded-full blur-2xl"
            style={{ backgroundColor: NarraColors.brand.primaryLight }}
          />

          {/* Logo con animación de respiración */}
          <motion.div
            animate={{
              scale: [1, 1.05, 1],
              opacity: [0.95, 1, 0.95]
            }}
            transition={{
              duration: 2,
              repeat: Infinity,
              ease: "easeInOut"
            }}
            className="relative z-10"
            style={{
              filter: `drop-shadow(0 10px 30px ${NarraColors.brand.primary}40)`
            }}
          >
            <img
              src="/logo.png"
              alt="Narra"
              className="w-20 h-20 object-contain"
            />
          </motion.div>
        </div>

        {/* Loading text */}
        <motion.p
          animate={{
            opacity: [0.7, 1, 0.7]
          }}
          transition={{
            duration: 2,
            repeat: Infinity,
            ease: "easeInOut"
          }}
          className="text-xl font-semibold mb-4"
          style={{ color: NarraColors.text.primary }}
        >
          Cargando historias
        </motion.p>

        {/* Puntos animados más elegantes */}
        <div className="flex items-center justify-center gap-2">
          {[0, 1, 2].map((index) => (
            <motion.div
              key={index}
              animate={{
                scale: [1, 1.3, 1],
                opacity: [0.5, 1, 0.5]
              }}
              transition={{
                duration: 1.2,
                repeat: Infinity,
                ease: "easeInOut",
                delay: index * 0.2
              }}
              className="w-2.5 h-2.5 rounded-full"
              style={{ backgroundColor: NarraColors.brand.primary }}
            />
          ))}
        </div>
      </motion.div>
    </div>
  );
};
