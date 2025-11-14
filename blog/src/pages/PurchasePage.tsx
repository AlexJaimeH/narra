import React, { useState, useEffect } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { motion } from 'framer-motion';
import { NarraColors } from '../styles/colors';
import { NavigationHeader } from '../components/NavigationHeader';

type PurchaseType = 'self' | 'gift';

export const PurchasePage: React.FC = () => {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const [selectedType, setSelectedType] = useState<PurchaseType>(
    (searchParams.get('type') as PurchaseType) || 'self'
  );

  useEffect(() => {
    const type = searchParams.get('type');
    if (type === 'self' || type === 'gift') {
      setSelectedType(type);
    }
  }, [searchParams]);

  const features = [
    {
      icon: '✍️',
      title: 'Editor Intuitivo',
      description: 'Escribe tus historias con un editor simple y poderoso, diseñado para personas de todas las edades',
    },
    {
      icon: '📸',
      title: 'Fotos y Audios',
      description: 'Agrega hasta 8 fotos por historia y grabaciones de voz para darle vida a tus recuerdos',
    },
    {
      icon: '🤖',
      title: 'Asistente de IA',
      description: 'Ghost Writer te ayuda a mejorar la redacción mientras mantiene tu voz única',
    },
    {
      icon: '👥',
      title: 'Comparte con Familia',
      description: 'Invita a tus seres queridos para que lean, comenten y reaccionen a tus historias',
    },
    {
      icon: '🔒',
      title: 'Totalmente Privado',
      description: 'Tus historias son privadas. Solo las personas que invites podrán leerlas',
    },
    {
      icon: '📚',
      title: 'Sin Límites',
      description: 'Escribe todas las historias que quieras, sin restricciones de cantidad o longitud',
    },
  ];

  const price = 300; // MXN

  return (
    <div
      className="min-h-screen"
      style={{ background: 'linear-gradient(135deg, #fdfbf7 0%, #f0ebe3 100%)' }}
    >
      {/* Header */}
      <NavigationHeader />

      {/* Main Content */}
      <div className="max-w-5xl mx-auto px-6 pt-28 pb-12">
        {/* Hero Section */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
          className="text-center mb-12"
        >
          <h1 className="text-5xl font-bold mb-4" style={{ color: NarraColors.text.primary }}>
            {selectedType === 'self' ? 'Comienza tu Legado' : 'Regala Memorias Eternas'}
          </h1>
          <p className="text-xl" style={{ color: NarraColors.text.secondary }}>
            {selectedType === 'self'
              ? 'Crea y comparte tus historias con las personas que amas'
              : 'El regalo perfecto para que alguien especial preserve sus recuerdos'}
          </p>
        </motion.div>

        {/* Selection Cards */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.2 }}
          className="grid md:grid-cols-2 gap-6 mb-12"
        >
          {/* For Me Card */}
          <motion.div
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            onClick={() => setSelectedType('self')}
            className={`relative p-8 rounded-3xl cursor-pointer transition-all ${
              selectedType === 'self' ? 'ring-4 ring-offset-4' : 'hover:shadow-xl'
            }`}
            style={{
              background: NarraColors.surface.white,
              boxShadow: selectedType === 'self'
                ? `0 20px 60px rgba(77,179,168,0.3)`
                : '0 10px 30px rgba(0,0,0,0.1)',
              ['--tw-ring-color' as any]: NarraColors.brand.primary,
            }}
          >
            {selectedType === 'self' && (
              <div
                className="absolute top-4 right-4 w-8 h-8 rounded-full flex items-center justify-center"
                style={{ background: NarraColors.brand.primary }}
              >
                <span className="text-white text-lg">✓</span>
              </div>
            )}
            <div className="text-6xl mb-4">✍️</div>
            <h3 className="text-2xl font-bold mb-2" style={{ color: NarraColors.text.primary }}>
              Para Mí
            </h3>
            <p className="text-gray-600">
              Quiero preservar mis propias memorias y compartirlas con mi familia
            </p>
          </motion.div>

          {/* Gift Card */}
          <motion.div
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            onClick={() => setSelectedType('gift')}
            className={`relative p-8 rounded-3xl cursor-pointer transition-all ${
              selectedType === 'gift' ? 'ring-4 ring-offset-4' : 'hover:shadow-xl'
            }`}
            style={{
              background: NarraColors.surface.white,
              boxShadow: selectedType === 'gift'
                ? `0 20px 60px rgba(77,179,168,0.3)`
                : '0 10px 30px rgba(0,0,0,0.1)',
              ['--tw-ring-color' as any]: NarraColors.brand.primary,
            }}
          >
            {selectedType === 'gift' && (
              <div
                className="absolute top-4 right-4 w-8 h-8 rounded-full flex items-center justify-center"
                style={{ background: NarraColors.brand.primary }}
              >
                <span className="text-white text-lg">✓</span>
              </div>
            )}
            <div className="text-6xl mb-4">🎁</div>
            <h3 className="text-2xl font-bold mb-2" style={{ color: NarraColors.text.primary }}>
              Regalo
            </h3>
            <p className="text-gray-600">
              Quiero regalárselo a alguien especial para que preserve sus memorias
            </p>
          </motion.div>
        </motion.div>

        {/* Buy Button after Selection */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.3 }}
          className="text-center mb-12"
        >
          <motion.button
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            onClick={() => navigate(`/purchase/checkout?type=${selectedType}`)}
            className="px-12 py-4 rounded-xl font-bold text-white text-lg shadow-lg"
            style={{
              background: 'linear-gradient(135deg, #4DB3A8 0%, #38827A 100%)',
            }}
          >
            {selectedType === 'self' ? '🚀 Continuar con mi Compra' : '🎁 Continuar con el Regalo'}
          </motion.button>
          <p className="text-sm mt-4" style={{ color: NarraColors.text.light }}>
            Solo $300 MXN • Pago único • Sin suscripciones
          </p>
        </motion.div>

        {/* Features Grid */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.4 }}
          className="mb-12"
        >
          <h2 className="text-3xl font-bold text-center mb-8" style={{ color: NarraColors.text.primary }}>
            Todo lo que incluye
          </h2>
          <div className="grid md:grid-cols-3 gap-6">
            {features.map((feature, index) => (
              <motion.div
                key={index}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.4, delay: 0.5 + index * 0.1 }}
                className="p-6 rounded-2xl"
                style={{
                  background: NarraColors.surface.white,
                  boxShadow: '0 4px 20px rgba(0,0,0,0.08)',
                }}
              >
                <div className="text-4xl mb-3">{feature.icon}</div>
                <h3 className="text-lg font-bold mb-2" style={{ color: NarraColors.text.primary }}>
                  {feature.title}
                </h3>
                <p className="text-sm" style={{ color: NarraColors.text.secondary }}>
                  {feature.description}
                </p>
              </motion.div>
            ))}
          </div>
        </motion.div>

        {/* Price and CTA Section */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.6 }}
          className="p-8 rounded-3xl max-w-2xl mx-auto"
          style={{
            background: NarraColors.surface.white,
            boxShadow: '0 20px 60px rgba(77,179,168,0.12), 0 8px 20px rgba(0,0,0,0.06)',
          }}
        >
          <div className="text-center mb-8">
            <div className="flex items-baseline justify-center gap-2 mb-2">
              <span className="text-5xl font-bold" style={{ color: NarraColors.brand.primary }}>
                ${price}
              </span>
              <span className="text-2xl" style={{ color: NarraColors.text.secondary }}>
                MXN
              </span>
            </div>
            <p className="text-lg" style={{ color: NarraColors.text.secondary }}>
              Pago único • Sin suscripciones • Uso de por vida
            </p>
          </div>

          <div
            className="rounded-2xl p-6 mb-8"
            style={{
              background: '#E8F5F4',
              borderLeft: `4px solid ${NarraColors.brand.primary}`,
            }}
          >
            <h4 className="font-bold mb-3" style={{ color: NarraColors.brand.primarySolid }}>
              ✨ Incluye:
            </h4>
            <ul className="space-y-2 text-sm" style={{ color: NarraColors.text.secondary }}>
              <li className="flex items-start gap-2">
                <span style={{ color: NarraColors.brand.primary }}>✓</span>
                <span>Historias ilimitadas sin restricciones</span>
              </li>
              <li className="flex items-start gap-2">
                <span style={{ color: NarraColors.brand.primary }}>✓</span>
                <span>Fotos y grabaciones de voz incluidas</span>
              </li>
              <li className="flex items-start gap-2">
                <span style={{ color: NarraColors.brand.primary }}>✓</span>
                <span>Asistente de IA Ghost Writer</span>
              </li>
              <li className="flex items-start gap-2">
                <span style={{ color: NarraColors.brand.primary }}>✓</span>
                <span>Suscriptores ilimitados para compartir</span>
              </li>
              <li className="flex items-start gap-2">
                <span style={{ color: NarraColors.brand.primary }}>✓</span>
                <span>Soporte prioritario por email</span>
              </li>
              <li className="flex items-start gap-2">
                <span style={{ color: NarraColors.brand.primary }}>✓</span>
                <span>Todas las actualizaciones futuras</span>
              </li>
            </ul>
          </div>

          <motion.button
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            onClick={() => navigate(`/purchase/checkout?type=${selectedType}`)}
            className="w-full py-4 rounded-xl font-bold text-white text-lg shadow-lg"
            style={{
              background: 'linear-gradient(135deg, #4DB3A8 0%, #38827A 100%)',
            }}
          >
            {selectedType === 'self' ? '🚀 Comenzar Ahora' : '🎁 Continuar con el Regalo'}
          </motion.button>

          <p className="text-center text-sm mt-4" style={{ color: NarraColors.text.light }}>
            🔒 Pago seguro • 🎯 Sin compromisos • ⚡ Acceso inmediato
          </p>
        </motion.div>

        {/* Trust Badges */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.6, delay: 0.8 }}
          className="text-center mt-12"
        >
          <p className="text-sm mb-4" style={{ color: NarraColors.text.light }}>
            Confiado por familias en todo México 🇲🇽
          </p>
          <div className="flex items-center justify-center gap-8 flex-wrap">
            <div className="flex items-center gap-2">
              <span className="text-2xl">⭐</span>
              <span className="font-semibold" style={{ color: NarraColors.text.secondary }}>
                100% Seguro
              </span>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-2xl">🔒</span>
              <span className="font-semibold" style={{ color: NarraColors.text.secondary }}>
                Privacidad Garantizada
              </span>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-2xl">💚</span>
              <span className="font-semibold" style={{ color: NarraColors.text.secondary }}>
                Hecho con Amor
              </span>
            </div>
          </div>
        </motion.div>
      </div>
    </div>
  );
};
