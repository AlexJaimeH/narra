import React, { useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { motion } from 'framer-motion';
import { NarraColors } from '../styles/colors';
import { useGoogleAdsTag } from '../hooks/useGoogleAdsTag';
import { useGoogleAdsPurchaseConversion } from '../hooks/useGoogleAdsPurchaseConversion';

export const PurchaseSuccessPage: React.FC = () => {
  const [searchParams] = useSearchParams();
  const sessionId = searchParams.get('session_id');
  const initialType = searchParams.get('type') || 'self';
  const timing = searchParams.get('timing');

  const [purchaseType, setPurchaseType] = useState(initialType);
  const [email, setEmail] = useState('');
  const [isLoading, setIsLoading] = useState(!!sessionId);
  const [error, setError] = useState<string | null>(null);
  const [, setAlreadyProcessed] = useState(false);

  useGoogleAdsTag();
  useGoogleAdsPurchaseConversion();

  // Verify Stripe session and create account if needed
  useEffect(() => {
    const verifyPayment = async () => {
      if (!sessionId) {
        setIsLoading(false);
        return;
      }

      try {
        const response = await fetch('/api/stripe-verify-session', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ sessionId }),
        });

        const data = await response.json();

        if (response.ok && data.success) {
          // Payment verified and account created (or was already created)
          if (data.alreadyProcessed) {
            setAlreadyProcessed(true);
          }

          // Update type based on response
          if (data.type === 'gift_later' || timing === 'later') {
            setPurchaseType('gift_later');
          } else if (data.type === 'gift') {
            setPurchaseType('gift');
          }

          // Email might come from metadata
          if (data.email) {
            setEmail(data.email);
          }
        } else {
          // Handle specific errors
          if (data.alreadyExists) {
            setError('Este email ya está registrado. El pago fue procesado. Por favor revisa tu email o contacta a soporte.');
          } else {
            setError(data.error || 'Hubo un error al procesar tu pago. Por favor contacta a soporte.');
          }
        }
      } catch (err) {
        console.error('Error verifying payment:', err);
        setError('Error de conexión. Por favor recarga la página o contacta a soporte.');
      } finally {
        setIsLoading(false);
      }
    };

    verifyPayment();
  }, [sessionId, timing]);

  // Determinar el título y descripción según el tipo
  const getHeaderInfo = () => {
    switch (purchaseType) {
      case 'self':
        return {
          emoji: '✅',
          title: '¡Bienvenido a Narra!',
          subtitle: 'Tu cuenta ha sido creada exitosamente'
        };
      case 'gift':
      case 'gift_now':
        return {
          emoji: '🎁',
          title: '¡Regalo Enviado!',
          subtitle: 'Tu regalo ha sido enviado exitosamente'
        };
      case 'gift_later':
        return {
          emoji: '📅',
          title: '¡Regalo Guardado!',
          subtitle: 'Tu regalo está listo para activar cuando quieras'
        };
      case 'gift_activated':
        return {
          emoji: '🎉',
          title: '¡Regalo Activado!',
          subtitle: 'El regalo ha sido activado exitosamente'
        };
      default:
        return {
          emoji: '✅',
          title: '¡Éxito!',
          subtitle: 'Operación completada'
        };
    }
  };

  const headerInfo = getHeaderInfo();

  useEffect(() => {
    // Scroll to top on mount
    window.scrollTo(0, 0);
  }, []);

  // Loading state
  if (isLoading) {
    return (
      <div
        className="min-h-screen flex items-center justify-center p-4"
        style={{ background: 'linear-gradient(135deg, #fdfbf7 0%, #f0ebe3 100%)' }}
      >
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          className="text-center"
        >
          <div className="w-16 h-16 mx-auto mb-4 border-4 border-t-transparent rounded-full animate-spin" style={{ borderColor: NarraColors.brand.primary, borderTopColor: 'transparent' }} />
          <h2 className="text-xl font-bold mb-2" style={{ color: NarraColors.text.primary }}>
            Verificando tu pago...
          </h2>
          <p style={{ color: NarraColors.text.secondary }}>
            Por favor espera un momento
          </p>
        </motion.div>
      </div>
    );
  }

  // Error state
  if (error) {
    return (
      <div
        className="min-h-screen flex items-center justify-center p-4"
        style={{ background: 'linear-gradient(135deg, #fdfbf7 0%, #f0ebe3 100%)' }}
      >
        <motion.div
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1 }}
          className="w-full max-w-md"
        >
          <div
            className="rounded-3xl p-8 text-center"
            style={{
              background: NarraColors.surface.white,
              boxShadow: '0 20px 60px rgba(0,0,0,0.1)',
            }}
          >
            <div className="w-16 h-16 mx-auto mb-4 rounded-full flex items-center justify-center" style={{ background: '#FEE2E2' }}>
              <span className="text-3xl">⚠️</span>
            </div>
            <h2 className="text-xl font-bold mb-4" style={{ color: NarraColors.text.primary }}>
              Hubo un problema
            </h2>
            <p className="mb-6" style={{ color: NarraColors.text.secondary }}>
              {error}
            </p>
            <div className="space-y-3">
              <motion.a
                href="mailto:hola@narra.mx"
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.98 }}
                className="block w-full py-3 rounded-xl font-bold text-white"
                style={{ background: 'linear-gradient(135deg, #4DB3A8 0%, #38827A 100%)' }}
              >
                Contactar Soporte
              </motion.a>
              <motion.a
                href="/"
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.98 }}
                className="block w-full py-3 rounded-xl font-bold border-2"
                style={{ borderColor: NarraColors.brand.primary, color: NarraColors.brand.primary }}
              >
                Volver al Inicio
              </motion.a>
            </div>
          </div>
        </motion.div>
      </div>
    );
  }

  return (
    <div
      className="min-h-screen flex items-center justify-center p-4"
      style={{ background: 'linear-gradient(135deg, #fdfbf7 0%, #f0ebe3 100%)' }}
    >
      <motion.div
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ duration: 0.5 }}
        className="w-full max-w-2xl"
      >
        <div
          className="rounded-3xl overflow-hidden"
          style={{
            background: NarraColors.surface.white,
            boxShadow: '0 20px 60px rgba(77,179,168,0.12), 0 8px 20px rgba(0,0,0,0.06)',
          }}
        >
          {/* Header */}
          <div
            className="p-8 text-center"
            style={{
              background: 'linear-gradient(135deg, #4DB3A8 0%, #38827A 100%)',
            }}
          >
            <motion.div
              initial={{ scale: 0 }}
              animate={{ scale: 1 }}
              transition={{ duration: 0.5, delay: 0.2 }}
              className="w-20 h-20 mx-auto mb-4 rounded-full flex items-center justify-center"
              style={{ background: 'rgba(255,255,255,0.2)' }}
            >
              <span className="text-5xl">{headerInfo.emoji}</span>
            </motion.div>
            <h1 className="text-3xl font-bold text-white mb-2">
              {headerInfo.title}
            </h1>
            <p className="text-white/90">
              {headerInfo.subtitle}
            </p>
          </div>

          {/* Content */}
          <div className="p-8">
            {purchaseType === 'gift_later' ? (
              // Gift Later success
              <>
                <div
                  className="rounded-2xl p-6 mb-6"
                  style={{
                    background: '#E8F5F4',
                    borderLeft: `4px solid ${NarraColors.brand.primary}`,
                  }}
                >
                  <h2 className="font-bold mb-2" style={{ color: NarraColors.brand.primarySolid }}>
                    📧 Revisa tu email
                  </h2>
                  <p className="text-sm mb-3" style={{ color: NarraColors.text.secondary }}>
                    Hemos enviado un correo a <strong>{email}</strong> con:
                  </p>
                  <ul className="space-y-2 text-sm" style={{ color: NarraColors.text.secondary }}>
                    <li className="flex items-start gap-2">
                      <span style={{ color: NarraColors.brand.primary }}>✓</span>
                      <span>Un enlace especial para activar el regalo cuando quieras</span>
                    </li>
                    <li className="flex items-start gap-2">
                      <span style={{ color: NarraColors.brand.primary }}>✓</span>
                      <span>Instrucciones de cómo completar los datos del destinatario</span>
                    </li>
                    <li className="flex items-start gap-2">
                      <span style={{ color: NarraColors.brand.primary }}>✓</span>
                      <span>El enlace no expira - actívalo en el momento perfecto</span>
                    </li>
                  </ul>
                </div>

                <div
                  className="rounded-2xl p-6 mb-6"
                  style={{
                    background: '#FFFBEB',
                    border: `2px solid ${NarraColors.status.warning}`,
                  }}
                >
                  <h3 className="font-bold mb-2 flex items-center gap-2" style={{ color: NarraColors.text.primary }}>
                    <span>📅</span>
                    <span>¿Cómo funciona?</span>
                  </h3>
                  <ol className="space-y-2 text-sm" style={{ color: NarraColors.text.secondary }}>
                    <li>1. Abre el email que te enviamos</li>
                    <li>2. Cuando quieras activar el regalo, haz clic en el enlace</li>
                    <li>3. Completa los datos del destinatario</li>
                    <li>4. ¡El destinatario recibirá su acceso a Narra de inmediato!</li>
                  </ol>
                </div>

                <motion.a
                  href="/"
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                  className="block w-full text-center py-4 rounded-xl font-bold text-white shadow-lg"
                  style={{
                    background: 'linear-gradient(135deg, #4DB3A8 0%, #38827A 100%)',
                  }}
                >
                  Volver al Inicio
                </motion.a>
              </>
            ) : purchaseType === 'gift_activated' ? (
              // Gift Activated success
              <>
                <div
                  className="rounded-2xl p-6 mb-6"
                  style={{
                    background: '#E8F5F4',
                    borderLeft: `4px solid ${NarraColors.brand.primary}`,
                  }}
                >
                  <h2 className="font-bold mb-2" style={{ color: NarraColors.brand.primarySolid }}>
                    📧 Emails Enviados
                  </h2>
                  <div className="space-y-4 text-sm" style={{ color: NarraColors.text.secondary }}>
                    <div>
                      <p className="font-semibold mb-1">Al destinatario ({email}):</p>
                      <ul className="space-y-1 ml-4">
                        <li>• Notificación del regalo</li>
                        <li>• Enlace para iniciar sesión</li>
                        <li>• Introducción a Narra</li>
                      </ul>
                    </div>
                    <div>
                      <p className="font-semibold mb-1">A ti:</p>
                      <ul className="space-y-1 ml-4">
                        <li>• Confirmación de activación</li>
                        <li>• Detalles del regalo activado</li>
                      </ul>
                    </div>
                  </div>
                </div>

                <div
                  className="rounded-2xl p-6 mb-6"
                  style={{
                    background: 'linear-gradient(135deg, #FFF8F0 0%, #FFE8D6 100%)',
                    border: '2px solid #F59E0B',
                  }}
                >
                  <div className="text-center mb-3">
                    <span className="text-4xl">🎁</span>
                  </div>
                  <p className="text-sm text-center" style={{ color: NarraColors.text.secondary }}>
                    <strong>Has regalado memorias que durarán para siempre.</strong><br/>
                    Tu regalo ayudará a preservar historias familiares que se transmitirán de generación en generación.
                  </p>
                </div>

                <motion.a
                  href="/"
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                  className="block w-full text-center py-4 rounded-xl font-bold text-white shadow-lg"
                  style={{
                    background: 'linear-gradient(135deg, #4DB3A8 0%, #38827A 100%)',
                  }}
                >
                  Volver al Inicio
                </motion.a>
              </>
            ) : purchaseType === 'self' ? (
              // Self purchase success
              <>
                <div
                  className="rounded-2xl p-6 mb-6"
                  style={{
                    background: '#E8F5F4',
                    borderLeft: `4px solid ${NarraColors.brand.primary}`,
                  }}
                >
                  <h2 className="font-bold mb-2" style={{ color: NarraColors.brand.primarySolid }}>
                    📧 Revisa tu email
                  </h2>
                  <p className="text-sm mb-3" style={{ color: NarraColors.text.secondary }}>
                    Hemos enviado un correo a <strong>{email}</strong> con:
                  </p>
                  <ul className="space-y-2 text-sm" style={{ color: NarraColors.text.secondary }}>
                    <li className="flex items-start gap-2">
                      <span style={{ color: NarraColors.brand.primary }}>✓</span>
                      <span>Un enlace para confirmar tu email e iniciar sesión</span>
                    </li>
                    <li className="flex items-start gap-2">
                      <span style={{ color: NarraColors.brand.primary }}>✓</span>
                      <span>Un enlace para cambiar tu email en cualquier momento</span>
                    </li>
                    <li className="flex items-start gap-2">
                      <span style={{ color: NarraColors.brand.primary }}>✓</span>
                      <span>Instrucciones para comenzar a usar Narra</span>
                    </li>
                  </ul>
                </div>

                <div
                  className="rounded-2xl p-6 mb-6"
                  style={{
                    background: '#FFFBEB',
                    border: `2px solid ${NarraColors.status.warning}`,
                  }}
                >
                  <h3 className="font-bold mb-2 flex items-center gap-2" style={{ color: NarraColors.text.primary }}>
                    <span>⚡</span>
                    <span>Próximos Pasos</span>
                  </h3>
                  <ol className="space-y-2 text-sm" style={{ color: NarraColors.text.secondary }}>
                    <li>1. Revisa tu bandeja de entrada (y spam)</li>
                    <li>2. Haz clic en el enlace para confirmar tu email</li>
                    <li>3. ¡Comienza a escribir tus primeras historias!</li>
                  </ol>
                </div>

                <motion.a
                  href="/"
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                  className="block w-full text-center py-4 rounded-xl font-bold text-white shadow-lg"
                  style={{
                    background: 'linear-gradient(135deg, #4DB3A8 0%, #38827A 100%)',
                  }}
                >
                  Volver al Inicio
                </motion.a>
              </>
            ) : (
              // Gift purchase success
              <>
                <div
                  className="rounded-2xl p-6 mb-6"
                  style={{
                    background: '#E8F5F4',
                    borderLeft: `4px solid ${NarraColors.brand.primary}`,
                  }}
                >
                  <h2 className="font-bold mb-2" style={{ color: NarraColors.brand.primarySolid }}>
                    📧 Emails Enviados
                  </h2>
                  <div className="space-y-4 text-sm" style={{ color: NarraColors.text.secondary }}>
                    <div>
                      <p className="font-semibold mb-1">Al destinatario ({email}):</p>
                      <ul className="space-y-1 ml-4">
                        <li>• Notificación del regalo</li>
                        <li>• Enlace para iniciar sesión</li>
                        <li>• Introducción a Narra</li>
                      </ul>
                    </div>
                    <div>
                      <p className="font-semibold mb-1">A ti:</p>
                      <ul className="space-y-1 ml-4">
                        <li>• Confirmación de tu compra</li>
                        <li>• Enlace para gestionar el regalo</li>
                        <li>• Instrucciones de administración</li>
                      </ul>
                    </div>
                  </div>
                </div>

                <div
                  className="rounded-2xl p-6 mb-6"
                  style={{
                    background: '#FEF3C7',
                    borderLeft: `4px solid ${NarraColors.status.warning}`,
                  }}
                >
                  <h3 className="font-bold mb-2" style={{ color: NarraColors.text.primary }}>
                    🎁 Panel de Gestión
                  </h3>
                  <p className="text-sm mb-3" style={{ color: NarraColors.text.secondary }}>
                    Desde tu email podrás acceder a un panel especial donde podrás:
                  </p>
                  <ul className="space-y-2 text-sm" style={{ color: NarraColors.text.secondary }}>
                    <li className="flex items-start gap-2">
                      <span>✓</span>
                      <span>Cambiar el email del destinatario</span>
                    </li>
                    <li className="flex items-start gap-2">
                      <span>✓</span>
                      <span>Ver y gestionar suscriptores</span>
                    </li>
                    <li className="flex items-start gap-2">
                      <span>✓</span>
                      <span>Descargar historias publicadas</span>
                    </li>
                    <li className="flex items-start gap-2">
                      <span>✓</span>
                      <span>Enviar enlaces de inicio de sesión</span>
                    </li>
                  </ul>
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <motion.a
                    href="/"
                    whileHover={{ scale: 1.02 }}
                    whileTap={{ scale: 0.98 }}
                    className="text-center py-3 rounded-xl font-bold border-2"
                    style={{
                      borderColor: NarraColors.brand.primary,
                      color: NarraColors.brand.primary,
                    }}
                  >
                    Volver al Inicio
                  </motion.a>
                  <motion.button
                    whileHover={{ scale: 1.02 }}
                    whileTap={{ scale: 0.98 }}
                    onClick={() => window.open('mailto:' + email, '_blank')}
                    className="py-3 rounded-xl font-bold text-white"
                    style={{
                      background: 'linear-gradient(135deg, #4DB3A8 0%, #38827A 100%)',
                    }}
                  >
                    Abrir Email
                  </motion.button>
                </div>
              </>
            )}

            {/* Support */}
            <div className="mt-8 pt-6 border-t text-center" style={{ borderColor: NarraColors.border.light }}>
              <p className="text-sm mb-2" style={{ color: NarraColors.text.secondary }}>
                ¿Necesitas ayuda?
              </p>
              <a
                href="mailto:hola@narra.mx"
                className="text-sm font-semibold"
                style={{ color: NarraColors.brand.primary }}
              >
                Contáctanos: hola@narra.mx
              </a>
            </div>
          </div>
        </div>
      </motion.div>
    </div>
  );
};
