import React, { useState, useEffect } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { motion } from 'framer-motion';
import { NarraColors } from '../styles/colors';

export const GiftActivationPage: React.FC = () => {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const [token, setToken] = useState('');
  const [isValidating, setIsValidating] = useState(true);
  const [tokenValid, setTokenValid] = useState(false);
  const [tokenError, setTokenError] = useState('');

  // Form states
  const [authorName, setAuthorName] = useState('');
  const [authorEmail, setAuthorEmail] = useState('');
  const [buyerName, setBuyerName] = useState('');
  const [giftMessage, setGiftMessage] = useState('');

  const [isProcessing, setIsProcessing] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    const tokenParam = searchParams.get('token');
    if (!tokenParam) {
      setTokenError('Token no encontrado en la URL');
      setIsValidating(false);
      return;
    }
    setToken(tokenParam);
    validateToken(tokenParam);
  }, [searchParams]);

  const validateToken = async (token: string) => {
    try {
      const response = await fetch(`/api/gift-later-validate?token=${token}`);
      const data = await response.json();

      if (response.ok && data.valid) {
        setTokenValid(true);
        // Si tiene datos del comprador, prellenar el nombre
        if (data.buyerEmail) {
          // Podríamos mostrar el email del comprador o alguna info
        }
      } else {
        setTokenError(data.error || 'Token inválido o expirado');
        setTokenValid(false);
      }
    } catch (err) {
      setTokenError('Error al validar el token');
      setTokenValid(false);
    } finally {
      setIsValidating(false);
    }
  };

  const validateForm = (): boolean => {
    setError('');

    if (!authorName || authorName.trim() === '') {
      setError('Por favor ingresa el nombre del destinatario');
      return false;
    }

    if (!authorEmail || !authorEmail.includes('@')) {
      setError('Por favor ingresa un email válido del destinatario');
      return false;
    }

    const emailRegex = /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/;
    if (!emailRegex.test(authorEmail)) {
      setError('Por favor ingresa un email válido');
      return false;
    }

    return true;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!validateForm()) {
      return;
    }

    setIsProcessing(true);
    setError('');

    try {
      // TODO: Aquí va la integración con Stripe para el pago
      // Por ahora simulamos que el pago fue exitoso

      await new Promise(resolve => setTimeout(resolve, 1500));

      const response = await fetch('/api/gift-later-activate', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          token,
          authorName: authorName.trim(),
          authorEmail: authorEmail.toLowerCase().trim(),
          buyerName: buyerName.trim() || null,
          giftMessage: giftMessage.trim() || null,
        }),
      });

      const data = await response.json();

      if (response.ok && data.success) {
        // Redirigir a página de éxito
        navigate(`/purchase/success?type=gift_activated&email=${encodeURIComponent(authorEmail)}`);
      } else {
        setError(data.error || 'Error al activar el regalo. Por favor intenta nuevamente.');
      }
    } catch (error) {
      setError('Error de conexión. Por favor intenta nuevamente.');
    } finally {
      setIsProcessing(false);
    }
  };

  if (isValidating) {
    return (
      <div
        className="min-h-screen flex items-center justify-center"
        style={{ background: 'linear-gradient(135deg, #fdfbf7 0%, #f0ebe3 100%)' }}
      >
        <div className="text-center">
          <div
            className="w-12 h-12 border-4 border-t-transparent rounded-full animate-spin mx-auto mb-4"
            style={{ borderColor: NarraColors.brand.primary, borderTopColor: 'transparent' }}
          />
          <p style={{ color: NarraColors.text.secondary }}>Validando enlace...</p>
        </div>
      </div>
    );
  }

  if (!tokenValid || tokenError) {
    return (
      <div
        className="min-h-screen"
        style={{ background: 'linear-gradient(135deg, #fdfbf7 0%, #f0ebe3 100%)' }}
      >
        <header className="bg-white/95 backdrop-blur-sm shadow-sm border-b" style={{ borderColor: '#e5e7eb' }}>
          <div className="max-w-7xl mx-auto px-6 py-4">
            <a href="/" className="flex items-center">
              <img
                src="/logo-horizontal.png"
                alt="Narra"
                className="h-10 w-auto object-contain"
              />
            </a>
          </div>
        </header>

        <div className="max-w-2xl mx-auto px-6 py-12">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6 }}
            className="p-8 rounded-3xl text-center"
            style={{
              background: NarraColors.surface.white,
              boxShadow: '0 10px 30px rgba(0,0,0,0.1)',
            }}
          >
            <div className="text-6xl mb-4">❌</div>
            <h1 className="text-2xl font-bold mb-2" style={{ color: NarraColors.text.primary }}>
              Enlace Inválido
            </h1>
            <p className="mb-6" style={{ color: NarraColors.text.secondary }}>
              {tokenError || 'Este enlace no es válido o ya fue utilizado.'}
            </p>
            <a
              href="/"
              className="inline-block px-6 py-3 rounded-xl font-bold text-white"
              style={{ background: 'linear-gradient(135deg, #4DB3A8 0%, #38827A 100%)' }}
            >
              Volver al Inicio
            </a>
          </motion.div>
        </div>
      </div>
    );
  }

  return (
    <div
      className="min-h-screen"
      style={{ background: 'linear-gradient(135deg, #fdfbf7 0%, #f0ebe3 100%)' }}
    >
      <header className="bg-white/95 backdrop-blur-sm shadow-sm border-b" style={{ borderColor: '#e5e7eb' }}>
        <div className="max-w-7xl mx-auto px-6 py-4">
          <a href="/" className="flex items-center">
            <img
              src="/logo-horizontal.png"
              alt="Narra"
              className="h-10 w-auto object-contain"
            />
          </a>
        </div>
      </header>

      <div className="max-w-4xl mx-auto px-6 py-12">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
        >
          <h1 className="text-4xl font-bold mb-2" style={{ color: NarraColors.text.primary }}>
            🎁 Activa tu Regalo de Narra
          </h1>
          <p className="text-lg mb-8" style={{ color: NarraColors.text.secondary }}>
            Completa los datos del destinatario para activar este regalo
          </p>

          <div className="grid md:grid-cols-2 gap-8">
            {/* Left Column - Form */}
            <div>
              <div
                className="p-8 rounded-3xl mb-6"
                style={{
                  background: NarraColors.surface.white,
                  boxShadow: '0 10px 30px rgba(0,0,0,0.1)',
                }}
              >
                <h2 className="text-2xl font-bold mb-6" style={{ color: NarraColors.text.primary }}>
                  Información del Regalo
                </h2>

                <form onSubmit={handleSubmit} className="space-y-6">
                  <div>
                    <label className="block text-sm font-semibold mb-2" style={{ color: NarraColors.text.primary }}>
                      Nombre del Destinatario
                    </label>
                    <input
                      type="text"
                      value={authorName}
                      onChange={(e) => setAuthorName(e.target.value)}
                      placeholder="¿Cómo se llama?"
                      className="w-full px-4 py-3 rounded-xl border-2 focus:outline-none focus:border-opacity-100"
                      style={{
                        borderColor: NarraColors.border.light,
                        background: NarraColors.surface.white,
                      }}
                      required
                    />
                    <p className="text-xs mt-2" style={{ color: NarraColors.text.light }}>
                      Este nombre aparecerá en su perfil de autor
                    </p>
                  </div>

                  <div>
                    <label className="block text-sm font-semibold mb-2" style={{ color: NarraColors.text.primary }}>
                      Email del Destinatario
                    </label>
                    <input
                      type="email"
                      value={authorEmail}
                      onChange={(e) => setAuthorEmail(e.target.value)}
                      placeholder="destinatario@email.com"
                      className="w-full px-4 py-3 rounded-xl border-2 focus:outline-none focus:border-opacity-100"
                      style={{
                        borderColor: NarraColors.border.light,
                        background: NarraColors.surface.white,
                      }}
                      required
                    />
                    <p className="text-xs mt-2" style={{ color: NarraColors.text.light }}>
                      La persona que recibirá el acceso a Narra
                    </p>
                  </div>

                  <div className="border-t pt-6" style={{ borderColor: NarraColors.border.light }}>
                    <h3 className="text-lg font-bold mb-4" style={{ color: NarraColors.text.primary }}>
                      Personaliza tu Regalo
                    </h3>

                    <div className="space-y-4">
                      <div>
                        <label className="block text-sm font-semibold mb-2" style={{ color: NarraColors.text.primary }}>
                          Tu Nombre (opcional)
                        </label>
                        <input
                          type="text"
                          value={buyerName}
                          onChange={(e) => setBuyerName(e.target.value)}
                          placeholder="¿Cómo te llamas?"
                          className="w-full px-4 py-3 rounded-xl border-2 focus:outline-none focus:border-opacity-100"
                          style={{
                            borderColor: NarraColors.border.light,
                            background: NarraColors.surface.white,
                          }}
                        />
                        <p className="text-xs mt-2" style={{ color: NarraColors.text.light }}>
                          Este nombre aparecerá en el email de regalo
                        </p>
                      </div>

                      <div>
                        <label className="block text-sm font-semibold mb-2" style={{ color: NarraColors.text.primary }}>
                          Mensaje de Regalo (opcional)
                        </label>
                        <textarea
                          value={giftMessage}
                          onChange={(e) => setGiftMessage(e.target.value)}
                          placeholder="Escribe un mensaje especial para acompañar tu regalo..."
                          rows={4}
                          className="w-full px-4 py-3 rounded-xl border-2 focus:outline-none focus:border-opacity-100 resize-none"
                          style={{
                            borderColor: NarraColors.border.light,
                            background: NarraColors.surface.white,
                          }}
                        />
                        <p className="text-xs mt-2" style={{ color: NarraColors.text.light }}>
                          Este mensaje aparecerá en el email que reciba el destinatario
                        </p>
                      </div>
                    </div>
                  </div>

                  {error && (
                    <div
                      className="p-4 rounded-xl"
                      style={{
                        background: '#FEF2F2',
                        borderLeft: `4px solid ${NarraColors.status.error}`,
                      }}
                    >
                      <p className="text-sm" style={{ color: NarraColors.status.error }}>
                        {error}
                      </p>
                    </div>
                  )}

                  <div
                    className="p-4 rounded-xl"
                    style={{
                      background: '#E8F5F4',
                      border: `1px solid ${NarraColors.brand.primary}`,
                    }}
                  >
                    <p className="text-sm" style={{ color: NarraColors.text.secondary }}>
                      📧 El destinatario recibirá un email con su acceso a Narra de inmediato
                    </p>
                  </div>

                  <motion.button
                    type="submit"
                    disabled={isProcessing}
                    whileHover={{ scale: isProcessing ? 1 : 1.02 }}
                    whileTap={{ scale: isProcessing ? 1 : 0.98 }}
                    className="w-full py-4 rounded-xl font-bold text-white text-lg shadow-lg disabled:opacity-50 disabled:cursor-not-allowed"
                    style={{
                      background: isProcessing
                        ? NarraColors.text.light
                        : 'linear-gradient(135deg, #4DB3A8 0%, #38827A 100%)',
                    }}
                  >
                    {isProcessing ? (
                      <span className="flex items-center justify-center gap-2">
                        <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                        <span>Activando...</span>
                      </span>
                    ) : (
                      '🎁 Activar Regalo'
                    )}
                  </motion.button>
                </form>
              </div>
            </div>

            {/* Right Column - Info */}
            <div>
              <div
                className="p-8 rounded-3xl sticky top-24"
                style={{
                  background: NarraColors.surface.white,
                  boxShadow: '0 10px 30px rgba(0,0,0,0.1)',
                }}
              >
                <h2 className="text-2xl font-bold mb-6" style={{ color: NarraColors.text.primary }}>
                  ¿Qué Incluye?
                </h2>

                <div
                  className="rounded-xl p-4 mb-6"
                  style={{ background: '#E8F5F4' }}
                >
                  <h3 className="font-bold mb-2" style={{ color: NarraColors.brand.primarySolid }}>
                    ✨ Acceso Completo de por Vida:
                  </h3>
                  <ul className="space-y-1 text-sm" style={{ color: NarraColors.text.secondary }}>
                    <li>✓ Historias ilimitadas</li>
                    <li>✓ Fotos y grabaciones de voz</li>
                    <li>✓ Ghost Writer IA</li>
                    <li>✓ Suscriptores ilimitados</li>
                    <li>✓ Sin mensualidades</li>
                    <li>✓ Actualizaciones futuras</li>
                  </ul>
                </div>

                <div
                  className="rounded-xl p-4"
                  style={{
                    background: 'linear-gradient(135deg, #FFF8F0 0%, #FFE8D6 100%)',
                    border: '2px solid #F59E0B',
                  }}
                >
                  <div className="text-3xl mb-2 text-center">🎁</div>
                  <p className="text-sm text-center" style={{ color: NarraColors.text.secondary }}>
                    <strong>El regalo perfecto</strong><br />
                    para preservar memorias familiares que durarán para siempre
                  </p>
                </div>
              </div>
            </div>
          </div>
        </motion.div>
      </div>
    </div>
  );
};
