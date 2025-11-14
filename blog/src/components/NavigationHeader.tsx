import React, { useState } from 'react';
import { motion } from 'framer-motion';

export const NavigationHeader: React.FC = () => {
  const [isMenuOpen, setIsMenuOpen] = useState(false);

  return (
    <motion.header
      initial={{ opacity: 0, y: -20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3 }}
      className="fixed top-0 left-0 right-0 bg-white/95 backdrop-blur-sm shadow-sm z-50 border-b"
      style={{ borderColor: '#e5e7eb' }}
    >
      <div className="max-w-7xl mx-auto px-6 py-4">
        <div className="flex items-center justify-between">
          {/* Logo */}
          <a href="/" className="flex items-center">
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
            <a href="/#testimonios" className="text-gray-700 hover:text-[#4DB3A8] font-medium transition">
              Testimonios
            </a>
            <a href="/app" className="text-gray-700 hover:text-[#4DB3A8] font-medium transition">
              Iniciar sesión
            </a>
            <motion.a
              href="/purchase?type=gift"
              className="px-6 py-2.5 text-white rounded-xl font-semibold shadow-lg"
              style={{ background: 'linear-gradient(135deg, #4DB3A8 0%, #38827A 100%)' }}
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
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
            <a href="/#testimonios" className="text-left py-2 text-gray-700 hover:text-[#4DB3A8]">
              Testimonios
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
  );
};
