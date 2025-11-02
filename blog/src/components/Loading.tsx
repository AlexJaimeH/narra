import React from 'react';
import { NarraColors } from '../styles/colors';

export const Loading: React.FC = () => {
  return (
    <div className="flex items-center justify-center min-h-screen" style={{ background: `linear-gradient(to bottom, ${NarraColors.brand.primaryPale}, ${NarraColors.surface.white})` }}>
      <div className="text-center animate-fade-in">
        {/* Animated book icon */}
        <div className="relative mb-6">
          {/* Outer circle with pulse */}
          <div className="absolute inset-0 flex items-center justify-center">
            <div
              className="w-24 h-24 rounded-full animate-pulse-soft"
              style={{ backgroundColor: `${NarraColors.brand.primaryLight}` }}
            ></div>
          </div>

          {/* Inner spinning circle */}
          <div className="relative flex items-center justify-center">
            <div
              className="w-20 h-20 rounded-full flex items-center justify-center animate-spin-slow"
              style={{
                background: `linear-gradient(135deg, ${NarraColors.brand.primary}, ${NarraColors.brand.accent})`,
                boxShadow: '0 10px 40px rgba(77, 179, 168, 0.3)'
              }}
            >
              {/* Book icon */}
              <svg
                className="w-10 h-10 text-white animate-float"
                fill="currentColor"
                viewBox="0 0 20 20"
              >
                <path d="M9 4.804A7.968 7.968 0 005.5 4c-1.255 0-2.443.29-3.5.804v10A7.969 7.969 0 015.5 14c1.669 0 3.218.51 4.5 1.385A7.962 7.962 0 0114.5 14c1.255 0 2.443.29 3.5.804v-10A7.968 7.968 0 0014.5 4c-1.255 0-2.443.29-3.5.804V12a1 1 0 11-2 0V4.804z" />
              </svg>
            </div>
          </div>
        </div>

        {/* Loading text with shimmer effect */}
        <div className="space-y-2">
          <p
            className="text-xl font-semibold animate-pulse-soft"
            style={{ color: NarraColors.text.primary }}
          >
            Cargando historias
          </p>
          <div className="flex items-center justify-center gap-1">
            <div
              className="w-2 h-2 rounded-full animate-bounce"
              style={{
                backgroundColor: NarraColors.brand.primary,
                animationDelay: '0ms'
              }}
            ></div>
            <div
              className="w-2 h-2 rounded-full animate-bounce"
              style={{
                backgroundColor: NarraColors.brand.primary,
                animationDelay: '150ms'
              }}
            ></div>
            <div
              className="w-2 h-2 rounded-full animate-bounce"
              style={{
                backgroundColor: NarraColors.brand.primary,
                animationDelay: '300ms'
              }}
            ></div>
          </div>
        </div>
      </div>
    </div>
  );
};
