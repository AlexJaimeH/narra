import React from 'react';
import { motion } from 'framer-motion';
import { NavigationHeader } from './NavigationHeader';

interface LegalPageLayoutProps {
  children: React.ReactNode;
  title: string;
}

export const LegalPageLayout: React.FC<LegalPageLayoutProps> = ({ children, title }) => {
  return (
    <div className="min-h-screen" style={{ background: 'linear-gradient(135deg, #fdfbf7 0%, #f0ebe3 100%)' }}>
      {/* Header */}
      <NavigationHeader />

      {/* Page Title */}
      <section className="pt-32 pb-12 px-6">
        <div className="max-w-4xl mx-auto text-center">
          <motion.h1
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.2, duration: 0.6 }}
            className="text-4xl md:text-5xl font-bold mb-4"
            style={{ color: '#1F2937' }}
          >
            {title}
          </motion.h1>
        </div>
      </section>

      {/* Content */}
      <section className="pb-20 px-6">
        <div className="max-w-4xl mx-auto">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.3, duration: 0.6 }}
            className="bg-white rounded-3xl shadow-xl p-8 md:p-12"
          >
            {children}
          </motion.div>
        </div>
      </section>

      {/* Footer */}
      <footer className="py-12 px-6" style={{ background: '#1F2937' }}>
        <div className="max-w-7xl mx-auto">
          <div className="flex flex-col md:flex-row justify-between items-center gap-8 mb-8">
            <div className="text-center md:text-left">
              <img
                src="/logo-horizontal.png"
                alt="Narra"
                className="h-10 w-auto object-contain opacity-90 mb-4 mx-auto md:mx-0"
              />
              <p className="text-gray-400 text-lg italic">
                Todos tienen una historia. Narra la tuya.
              </p>
            </div>

            <div className="flex flex-wrap justify-center gap-8 text-sm">
              <a href="/app" className="text-gray-400 hover:text-white transition">
                Iniciar sesión
              </a>
              <a href="/privacidad" className="text-gray-400 hover:text-white transition">
                Privacidad
              </a>
              <a href="/terminos" className="text-gray-400 hover:text-white transition">
                Términos
              </a>
              <a href="/contacto" className="text-gray-400 hover:text-white transition">
                Contacto
              </a>
            </div>
          </div>

          <div className="border-t border-gray-700 pt-8 text-center">
            <p className="text-sm text-gray-400">
              © 2025 Narra. Todos los derechos reservados. Hecho con ❤️ para preservar historias familiares.
            </p>
          </div>
        </div>
      </footer>
    </div>
  );
};
