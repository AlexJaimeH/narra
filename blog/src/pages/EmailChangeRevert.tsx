import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { NarraColors } from '../styles/colors';

export const EmailChangeRevert: React.FC = () => {
  const [state, setState] = useState<'loading' | 'success' | 'error'>('loading');
  const [message, setMessage] = useState('');
  const [oldEmail, setOldEmail] = useState('');
  const [wasConfirmed, setWasConfirmed] = useState(false);

  useEffect(() => {
    const revertEmailChange = async () => {
      try {
        // Obtener el token desde la URL
        const url = new URL(window.location.href);
        const token = url.searchParams.get('token');

        if (!token) {
          setState('error');
          setMessage('Token no encontrado. El enlace puede estar incompleto.');
          return;
        }

        // Llamar a la API de reversión
        const response = await fetch(`/api/email-change-revert?token=${token}`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
        });

        const data = await response.json();

        if (response.ok && data.success) {
          setState('success');
          setMessage(data.message || 'Cambio revertido exitosamente');
          setOldEmail(data.oldEmail || '');
          setWasConfirmed(data.wasConfirmed || false);
        } else {
          setState('error');
          setMessage(data.error || 'Error al revertir el cambio de email');
        }
      } catch (error) {
        setState('error');
        setMessage('Error de conexión. Por favor intenta nuevamente.');
      }
    };

    revertEmailChange();
  }, []);

  return (
    <div
      className="flex items-center justify-center min-h-screen p-4"
      style={{ background: 'linear-gradient(135deg, #fdfbf7 0%, #f0ebe3 100%)' }}
    >
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
        className="w-full max-w-md"
      >
        {/* Card */}
        <div
          className="rounded-3xl shadow-2xl overflow-hidden"
          style={{
            background: NarraColors.surface.white,
            boxShadow: '0 20px 60px rgba(77,179,168,0.12), 0 8px 20px rgba(0,0,0,0.06)',
          }}
        >
          {/* Header */}
          <div
            className="p-8 text-center"
            style={{
              background: state === 'success'
                ? 'linear-gradient(135deg, #4DB3A8 0%, #38827A 100%)'
                : 'linear-gradient(135deg, #EF4444 0%, #DC2626 100%)',
            }}
          >
            <div className="mb-6">
              <img
                src="/logo.png"
                alt="Narra"
                className="w-20 h-20 mx-auto object-contain"
                style={{ filter: 'brightness(0) invert(1)' }}
              />
            </div>
            <h1 className="text-3xl font-bold text-white">
              {state === 'loading' && 'Procesando...'}
              {state === 'success' && (wasConfirmed ? '🔄 Cambio Revertido' : '🚫 Cambio Cancelado')}
              {state === 'error' && '❌ Error'}
            </h1>
          </div>

          {/* Content */}
          <div className="p-8">
            {state === 'loading' && (
              <div className="text-center">
                <div className="flex items-center justify-center gap-2 mb-4">
                  {[0, 1, 2].map((index) => (
                    <motion.div
                      key={index}
                      animate={{
                        scale: [1, 1.3, 1],
                        opacity: [0.5, 1, 0.5],
                      }}
                      transition={{
                        duration: 1.2,
                        repeat: Infinity,
                        ease: 'easeInOut',
                        delay: index * 0.2,
                      }}
                      className="w-3 h-3 rounded-full"
                      style={{ backgroundColor: NarraColors.brand.primary }}
                    />
                  ))}
                </div>
                <p className="text-gray-600">Procesando tu solicitud...</p>
              </div>
            )}

            {state === 'success' && (
              <div>
                <div
                  className="rounded-2xl p-6 mb-6"
                  style={{
                    background: '#E8F5F4',
                    borderLeft: `4px solid ${NarraColors.brand.primary}`,
                  }}
                >
                  <p className="text-gray-700 leading-relaxed mb-2">{message}</p>
                  {oldEmail && (
                    <p className="text-sm text-gray-600 mt-2">
                      <strong>Email actual:</strong> {oldEmail}
                    </p>
                  )}
                </div>

                {wasConfirmed ? (
                  <div
                    className="rounded-2xl p-6 mb-6"
                    style={{
                      background: '#FFFBEB',
                      border: `2px solid ${NarraColors.status.warning}`,
                    }}
                  >
                    <p className="text-sm text-gray-700">
                      <strong>ℹ️ Nota:</strong> El cambio de email había sido confirmado,
                      pero hemos revertido tu email al anterior. Puedes seguir usando
                      tu cuenta normalmente.
                    </p>
                  </div>
                ) : (
                  <div
                    className="rounded-2xl p-6 mb-6"
                    style={{
                      background: '#E8F5F4',
                      border: `2px solid ${NarraColors.brand.primary}`,
                    }}
                  >
                    <p className="text-sm text-gray-700">
                      <strong>✅ Todo está bien:</strong> El cambio de email fue cancelado
                      antes de confirmarse. Tu cuenta sigue usando el email original.
                    </p>
                  </div>
                )}

                <div className="space-y-4">
                  <motion.a
                    href="/app"
                    whileHover={{ scale: 1.02 }}
                    whileTap={{ scale: 0.98 }}
                    className="block w-full text-center px-6 py-4 rounded-xl font-bold text-white shadow-lg"
                    style={{
                      background: 'linear-gradient(135deg, #4DB3A8 0%, #38827A 100%)',
                    }}
                  >
                    Ir a la aplicación
                  </motion.a>

                  <p className="text-center text-sm text-gray-500">
                    Tu cuenta está segura y lista para usar
                  </p>
                </div>
              </div>
            )}

            {state === 'error' && (
              <div>
                <div
                  className="rounded-2xl p-6 mb-6"
                  style={{
                    background: '#FEF2F2',
                    borderLeft: `4px solid ${NarraColors.status.error}`,
                  }}
                >
                  <p className="text-gray-700 leading-relaxed">{message}</p>
                </div>

                <div className="space-y-3">
                  <motion.a
                    href="/app"
                    whileHover={{ scale: 1.02 }}
                    whileTap={{ scale: 0.98 }}
                    className="block w-full text-center px-6 py-4 rounded-xl font-bold text-white shadow-lg"
                    style={{
                      background: 'linear-gradient(135deg, #4DB3A8 0%, #38827A 100%)',
                    }}
                  >
                    Ir a la aplicación
                  </motion.a>

                  <p className="text-center text-sm text-gray-500">
                    Si necesitas ayuda, contacta a soporte
                  </p>
                </div>
              </div>
            )}
          </div>

          {/* Footer */}
          <div
            className="px-8 py-6 text-center border-t"
            style={{
              background: '#fafaf9',
              borderColor: '#e7e5e4',
            }}
          >
            <p className="text-sm text-gray-500">
              🔒 Tu cuenta está protegida
            </p>
          </div>
        </div>

        {/* Logo Narra */}
        <div className="text-center mt-8">
          <img
            src="/logo-horizontal.png"
            alt="Narra"
            className="h-8 mx-auto opacity-50"
          />
        </div>
      </motion.div>
    </div>
  );
};
