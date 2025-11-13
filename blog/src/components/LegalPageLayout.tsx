import React, { useState } from 'react';
import { motion } from 'framer-motion';

interface LegalPageLayoutProps {
  children: React.ReactNode;
  title: string;
}

export const LegalPageLayout: React.FC<LegalPageLayoutProps> = ({ children, title }) => {
  const [isMenuOpen, setIsMenuOpen] = useState(false);

  const scrollToTop = () => {
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  return (
    <div className="min-h-screen" style={{ background: 'linear-gradient(135deg, #fdfbf7 0%, #f0ebe3 100%)' }}>
      {/* Header */}
      <motion.header
        initial={{ y: -100 }}
        animate={{ y: 0 }}
        transition={{ duration: 0.6 }}
        className="fixed top-0 left-0 right-0 bg-white/95 backdrop-blur-sm shadow-sm z-50 border-b"
        style={{ borderColor: '#e5e7eb' }}
      >
        <div className="max-w-7xl mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            {/* Logo */}
            <a href="/" className="flex items-center cursor-pointer" onClick={scrollToTop}>
              <img
                src="/logo-horizontal.png"
                alt="Narra - Todos tienen una historia"
                className="h-10 w-auto object-contain"
              />
            </a>

            {/* Desktop Navigation */}
            <nav className="hidden md:flex items-center gap-6">
              <a href="/#como-funciona" className="text-gray-700 hover:text-[#4DB3A8] font-medium transition">
                Cómo funciona
              </a>
              <a href="/#caracteristicas" className="text-gray-700 hover:text-[#4DB3A8] font-medium transition">
                Características
              </a>
              <a href="/#precio" className="text-gray-700 hover:text-[#4DB3A8] font-medium transition">
                Precio
              </a>
              <a href="/app" className="text-gray-700 hover:text-[#4DB3A8] font-medium transition">
                Iniciar sesión
              </a>
              <motion.a
                href="/purchase?type=gift"
                className="px-6 py-2.5 text-white rounded-xl font-semibold shadow-lg"
                style={{ background: 'linear-gradient(135deg, #4DB3A8 0%, #38827A 100%)' }}
                whileHover={{ scale: 1.05, boxShadow: '0 20px 40px rgba(77, 179, 168, 0.3)' }}
                whileTap={{ scale: 0.95 }}
              >
                Comprar
              </motion.a>
            </nav>

            {/* Mobile Menu Button */}
            <button
              onClick={() => setIsMenuOpen(!isMenuOpen)}
              className="md:hidden p-2 text-gray-700"
            >
              <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                {isMenuOpen ? (
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                ) : (
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
                )}
              </svg>
            </button>
          </div>

          {/* Mobile Menu */}
          {isMenuOpen && (
            <motion.nav
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: 'auto' }}
              exit={{ opacity: 0, height: 0 }}
              className="md:hidden mt-4 pb-4 flex flex-col gap-3"
            >
              <a href="/#como-funciona" className="text-left py-2 text-gray-700 hover:text-[#4DB3A8]">
                Cómo funciona
              </a>
              <a href="/#caracteristicas" className="text-left py-2 text-gray-700 hover:text-[#4DB3A8]">
                Características
              </a>
              <a href="/#precio" className="text-left py-2 text-gray-700 hover:text-[#4DB3A8]">
                Precio
              </a>
              <a href="/app" className="text-left py-2 text-gray-700 hover:text-[#4DB3A8]">
                Iniciar sesión
              </a>
              <a
                href="/purchase?type=gift"
                className="px-6 py-3 text-white rounded-xl text-center font-semibold"
                style={{ background: 'linear-gradient(135deg, #4DB3A8 0%, #38827A 100%)' }}
              >
                Comprar
              </a>
            </motion.nav>
          )}
        </div>
      </motion.header>

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
