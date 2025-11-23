import React, { useState, useEffect } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { motion } from 'framer-motion';
import { NarraColors } from '../styles/colors';

type PurchaseType = 'self' | 'gift';
type GiftTiming = 'now' | 'later';

export const PurchaseCheckoutPage: React.FC = () => {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const [purchaseType, setPurchaseType] = useState<PurchaseType>('self');
  const [giftTiming, setGiftTiming] = useState<GiftTiming>('now');

  // Form states
  const [authorEmail, setAuthorEmail] = useState('');
  const [authorEmailConfirm, setAuthorEmailConfirm] = useState('');
  const [authorName, setAuthorName] = useState('');
  const [buyerEmail, setBuyerEmail] = useState('');
  const [buyerEmailConfirm, setBuyerEmailConfirm] = useState('');
  const [buyerName, setBuyerName] = useState('');
  const [giftMessage, setGiftMessage] = useState('');

  const [isProcessing, setIsProcessing] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    const type = searchParams.get('type');
    if (type === 'self' || type === 'gift') {
      setPurchaseType(type);
    } else {
      navigate('/purchase');
    }
  }, [searchParams, navigate]);

  const validateEmails = (): boolean => {
    setError('');

    if (purchaseType === 'self') {
      if (!authorEmail || !authorEmailConfirm) {
        setError('Por favor ingresa tu email en ambos campos');
        return false;
      }
      if (authorEmail !== authorEmailConfirm) {
        setError('Los emails no coinciden');
        return false;
      }
      if (!authorName || authorName.trim() === '') {
        setError('Por favor ingresa tu nombre');
        return false;
      }
      const emailRegex = /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/;
      if (!emailRegex.test(authorEmail)) {
        setError('Por favor ingresa un email válido');
        return false;
      }
    } else if (purchaseType === 'gift' && giftTiming === 'later') {
      // Gift later flow - solo necesita email del comprador
      if (!buyerEmail || !buyerEmailConfirm) {
        setError('Por favor ingresa tu email en ambos campos');
        return false;
      }
      if (buyerEmail !== buyerEmailConfirm) {
        setError('Los emails no coinciden');
        return false;
      }
      const emailRegex = /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/;
      if (!emailRegex.test(buyerEmail)) {
        setError('Por favor ingresa un email válido');
        return false;
      }
    } else {
      // Gift now flow
      if (!authorEmail) {
        setError('Por favor ingresa el email del destinatario');
        return false;
      }
      if (!authorName || authorName.trim() === '') {
        setError('Por favor ingresa el nombre del destinatario');
        return false;
      }
      if (!buyerEmail || !buyerEmailConfirm) {
        setError('Por favor ingresa tu email en ambos campos');
        return false;
      }
      if (buyerEmail !== buyerEmailConfirm) {
        setError('Tus emails no coinciden');
        return false;
      }
      if (!buyerName || buyerName.trim() === '') {
        setError('Por favor ingresa tu nombre');
        return false;
      }
      const emailRegex = /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/;
      if (!emailRegex.test(authorEmail) || !emailRegex.test(buyerEmail)) {
        setError('Por favor ingresa emails válidos');
        return false;
      }
      if (authorEmail.toLowerCase() === buyerEmail.toLowerCase()) {
        setError('El email del destinatario debe ser diferente al tuyo');
        return false;
      }
    }

    return true;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!validateEmails()) {
      return;
    }

    setIsProcessing(true);
    setError('');

    try {
      // TODO: Aquí va la integración con Stripe
      // Por ahora simulamos que el pago fue exitoso

      await new Promise(resolve => setTimeout(resolve, 1500));

      // Si es regalo para más tarde, usar API diferente
      if (purchaseType === 'gift' && giftTiming === 'later') {
        const response = await fetch('/api/gift-later-request', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            buyerEmail: buyerEmail.toLowerCase().trim(),
          }),
        });

        const data = await response.json();

        if (response.ok && data.success) {
          // Redirigir a página de éxito con tipo especial
          navigate(`/purchase/success?type=gift_later&email=${encodeURIComponent(buyerEmail)}`);
        } else {
          setError(data.error || 'Error al procesar la compra. Por favor intenta nuevamente.');
        }
      } else {
        // Flujo normal: self o gift_now
        const finalPurchaseType = purchaseType === 'self' ? 'self' : 'gift_now';

        const response = await fetch('/api/purchase-create-account', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            purchaseType: finalPurchaseType,
            authorEmail: authorEmail.toLowerCase().trim(),
            authorName: authorName.trim(),
            buyerEmail: purchaseType === 'gift' ? buyerEmail.toLowerCase().trim() : null,
            buyerName: purchaseType === 'gift' ? buyerName.trim() : null,
            giftMessage: purchaseType === 'gift' && giftMessage.trim() !== '' ? giftMessage.trim() : null,
          }),
        });

        const data = await response.json();

        if (response.ok && data.success) {
          // Redirigir a página de éxito
          navigate(`/purchase/success?type=${purchaseType}&email=${encodeURIComponent(authorEmail)}`);
        } else {
          setError(data.error || 'Error al procesar la compra. Por favor intenta nuevamente.');
        }
      }
    } catch (error) {
      setError('Error de conexión. Por favor intenta nuevamente.');
    } finally {
      setIsProcessing(false);
    }
  };

  const price = 300;

  return (
    <div
      className="min-h-screen"
      style={{ background: 'linear-gradient(135deg, #fdfbf7 0%, #f0ebe3 100%)' }}
    >
      {/* Header */}
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

      {/* Main Content */}
      <div className="max-w-4xl mx-auto px-6 py-12">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
        >
          <button
            onClick={() => navigate('/purchase')}
            className="flex items-center gap-2 mb-8 text-gray-600 hover:text-gray-800 transition"
          >
            <span>←</span>
            <span>Volver</span>
          </button>

          <h1 className="text-4xl font-bold mb-2" style={{ color: NarraColors.text.primary }}>
            {purchaseType === 'self' ? 'Completa tu Compra' : 'Completa tu Regalo'}
          </h1>
          <p className="text-lg mb-8" style={{ color: NarraColors.text.secondary }}>
            {purchaseType === 'self'
              ? 'Estás a un paso de comenzar a preservar tus memorias'
              : 'Estás a un paso de regalar algo inolvidable'}
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
                  Información de {purchaseType === 'self' ? 'Contacto' : 'Regalo'}
                </h2>

                <form onSubmit={handleSubmit} className="space-y-6">
                  {purchaseType === 'self' ? (
                    // Self flow
                    <>
                      <div>
                        <label className="block text-sm font-semibold mb-2" style={{ color: NarraColors.text.primary }}>
                          Tu Nombre
                        </label>
                        <input
                          type="text"
                          value={authorName}
                          onChange={(e) => setAuthorName(e.target.value)}
                          placeholder="¿Cómo te llamas?"
                          className="w-full px-4 py-3 rounded-xl border-2 focus:outline-none focus:border-opacity-100"
                          style={{
                            borderColor: NarraColors.border.light,
                            background: NarraColors.surface.white,
                          }}
                          required
                        />
                        <p className="text-xs mt-2" style={{ color: NarraColors.text.light }}>
                          Este nombre aparecerá en tu perfil de autor
                        </p>
                      </div>

                      <div>
                        <label className="block text-sm font-semibold mb-2" style={{ color: NarraColors.text.primary }}>
                          Tu Email
                        </label>
                        <input
                          type="email"
                          value={authorEmail}
                          onChange={(e) => setAuthorEmail(e.target.value)}
                          placeholder="tu@email.com"
                          className="w-full px-4 py-3 rounded-xl border-2 focus:outline-none focus:border-opacity-100"
                          style={{
                            borderColor: NarraColors.border.light,
                            background: NarraColors.surface.white,
                          }}
                          required
                        />
                      </div>

                      <div>
                        <label className="block text-sm font-semibold mb-2" style={{ color: NarraColors.text.primary }}>
                          Confirma tu Email
                        </label>
                        <input
                          type="email"
                          value={authorEmailConfirm}
                          onChange={(e) => setAuthorEmailConfirm(e.target.value)}
                          placeholder="tu@email.com"
                          className="w-full px-4 py-3 rounded-xl border-2 focus:outline-none focus:border-opacity-100"
                          style={{
                            borderColor: NarraColors.border.light,
                            background: NarraColors.surface.white,
                          }}
                          required
                        />
                      </div>
                    </>
                  ) : (
                    // Gift flow
                    <>
                      {/* Gift Timing Selection */}
                      <div className="mb-6">
                        <label className="block text-sm font-semibold mb-3" style={{ color: NarraColors.text.primary }}>
                          ¿Cuándo quieres regalar Narra?
                        </label>
                        <div className="grid grid-cols-2 gap-4">
                          <motion.div
                            whileHover={{ scale: 1.02 }}
                            whileTap={{ scale: 0.98 }}
                            onClick={() => setGiftTiming('now')}
                            className={`p-4 rounded-xl cursor-pointer transition-all ${
                              giftTiming === 'now' ? 'ring-2 ring-offset-2' : ''
                            }`}
                            style={{
                              background: giftTiming === 'now'
                                ? 'linear-gradient(135deg, #E8F5F4 0%, #D1F0ED 100%)'
                                : NarraColors.surface.white,
                              border: `2px solid ${giftTiming === 'now' ? NarraColors.brand.primary : NarraColors.border.light}`,
                              ['--tw-ring-color' as any]: NarraColors.brand.primary,
                            }}
                          >
                            <div className="text-3xl mb-2">🎁</div>
                            <h4 className="font-bold text-sm mb-1" style={{ color: NarraColors.text.primary }}>
                              Regalar Ahora
                            </h4>
                            <p className="text-xs" style={{ color: NarraColors.text.secondary }}>
                              Envío inmediato al destinatario
                            </p>
                          </motion.div>

                          <motion.div
                            whileHover={{ scale: 1.02 }}
                            whileTap={{ scale: 0.98 }}
                            onClick={() => setGiftTiming('later')}
                            className={`p-4 rounded-xl cursor-pointer transition-all ${
                              giftTiming === 'later' ? 'ring-2 ring-offset-2' : ''
                            }`}
                            style={{
                              background: giftTiming === 'later'
                                ? 'linear-gradient(135deg, #E8F5F4 0%, #D1F0ED 100%)'
                                : NarraColors.surface.white,
                              border: `2px solid ${giftTiming === 'later' ? NarraColors.brand.primary : NarraColors.border.light}`,
                              ['--tw-ring-color' as any]: NarraColors.brand.primary,
                            }}
                          >
                            <div className="text-3xl mb-2">📅</div>
                            <h4 className="font-bold text-sm mb-1" style={{ color: NarraColors.text.primary }}>
                              Regalar Más Tarde
                            </h4>
                            <p className="text-xs" style={{ color: NarraColors.text.secondary }}>
                              Tú decides cuándo activarlo
                            </p>
                          </motion.div>
                        </div>
                      </div>

                      {giftTiming === 'later' ? (
                        // Gift Later flow - Solo email del comprador
                        <>
                          <div
                            className="p-4 rounded-xl mb-6"
                            style={{
                              background: '#E8F5F4',
                              borderLeft: `4px solid ${NarraColors.brand.primary}`,
                            }}
                          >
                            <p className="text-sm leading-relaxed" style={{ color: NarraColors.text.secondary }}>
                              <strong>📧 ¿Cómo funciona?</strong><br/>
                              Te enviaremos un email con un enlace especial. Cuando quieras activar el regalo, solo haz clic en el enlace y completa los datos del destinatario. Así podrás elegir el momento perfecto para dar la sorpresa.
                            </p>
                          </div>

                          <div>
                            <label className="block text-sm font-semibold mb-2" style={{ color: NarraColors.text.primary }}>
                              Tu Email
                            </label>
                            <input
                              type="email"
                              value={buyerEmail}
                              onChange={(e) => setBuyerEmail(e.target.value)}
                              placeholder="tu@email.com"
                              className="w-full px-4 py-3 rounded-xl border-2 focus:outline-none focus:border-opacity-100"
                              style={{
                                borderColor: NarraColors.border.light,
                                background: NarraColors.surface.white,
                              }}
                              required
                            />
                            <p className="text-xs mt-2" style={{ color: NarraColors.text.light }}>
                              Te enviaremos el enlace de activación a este email
                            </p>
                          </div>

                          <div>
                            <label className="block text-sm font-semibold mb-2" style={{ color: NarraColors.text.primary }}>
                              Confirma tu Email
                            </label>
                            <input
                              type="email"
                              value={buyerEmailConfirm}
                              onChange={(e) => setBuyerEmailConfirm(e.target.value)}
                              placeholder="tu@email.com"
                              className="w-full px-4 py-3 rounded-xl border-2 focus:outline-none focus:border-opacity-100"
                              style={{
                                borderColor: NarraColors.border.light,
                                background: NarraColors.surface.white,
                              }}
                              required
                            />
                          </div>
                        </>
                      ) : (
                        // Gift Now flow - Formulario completo
                        <>
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
                              Tu Información
                            </h3>

                            <div className="space-y-4">
                          <div>
                            <label className="block text-sm font-semibold mb-2" style={{ color: NarraColors.text.primary }}>
                              Tu Nombre
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
                              required
                            />
                            <p className="text-xs mt-2" style={{ color: NarraColors.text.light }}>
                              Este nombre aparecerá en el email de regalo
                            </p>
                          </div>

                          <div>
                            <label className="block text-sm font-semibold mb-2" style={{ color: NarraColors.text.primary }}>
                              Tu Email
                            </label>
                            <input
                              type="email"
                              value={buyerEmail}
                              onChange={(e) => setBuyerEmail(e.target.value)}
                              placeholder="tu@email.com"
                              className="w-full px-4 py-3 rounded-xl border-2 focus:outline-none focus:border-opacity-100"
                              style={{
                                borderColor: NarraColors.border.light,
                                background: NarraColors.surface.white,
                              }}
                              required
                            />
                          </div>

                          <div>
                            <label className="block text-sm font-semibold mb-2" style={{ color: NarraColors.text.primary }}>
                              Confirma tu Email
                            </label>
                            <input
                              type="email"
                              value={buyerEmailConfirm}
                              onChange={(e) => setBuyerEmailConfirm(e.target.value)}
                              placeholder="tu@email.com"
                              className="w-full px-4 py-3 rounded-xl border-2 focus:outline-none focus:border-opacity-100"
                              style={{
                                borderColor: NarraColors.border.light,
                                background: NarraColors.surface.white,
                              }}
                              required
                            />
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
                        </>
                      )}
                    </>
                  )}

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
                      {purchaseType === 'self'
                        ? '📧 Recibirás un email para confirmar tu cuenta e iniciar sesión'
                        : purchaseType === 'gift' && giftTiming === 'later'
                        ? '📧 Te enviaremos un email con el enlace para activar el regalo cuando quieras'
                        : '📧 Enviaremos emails tanto a ti como al destinatario con toda la información'}
                    </p>
                  </div>

                  {/* TODO: AQUÍ VA LA INTEGRACIÓN DE STRIPE */}
                  {/* <StripePaymentForm amount={price} /> */}

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
                        <span>Procesando...</span>
                      </span>
                    ) : (
                      `💳 Pagar $${price} MXN`
                    )}
                  </motion.button>
                </form>
              </div>
            </div>

            {/* Right Column - Summary */}
            <div>
              <div
                className="p-8 rounded-3xl sticky top-24"
                style={{
                  background: NarraColors.surface.white,
                  boxShadow: '0 10px 30px rgba(0,0,0,0.1)',
                }}
              >
                <h2 className="text-2xl font-bold mb-6" style={{ color: NarraColors.text.primary }}>
                  Resumen
                </h2>

                <div className="space-y-4 mb-6">
                  <div className="flex items-center justify-between">
                    <span style={{ color: NarraColors.text.secondary }}>
                      {purchaseType === 'self' ? 'Narra - Para Mí' : 'Narra - Regalo'}
                    </span>
                    <span className="font-bold" style={{ color: NarraColors.text.primary }}>
                      ${price} MXN
                    </span>
                  </div>

                  <div className="border-t pt-4" style={{ borderColor: NarraColors.border.light }}>
                    <div className="flex items-center justify-between text-lg font-bold">
                      <span style={{ color: NarraColors.text.primary }}>Total</span>
                      <span style={{ color: NarraColors.brand.primary }}>
                        ${price} MXN
                      </span>
                    </div>
                  </div>
                </div>

                <div
                  className="rounded-xl p-4 mb-6"
                  style={{ background: '#E8F5F4' }}
                >
                  <h3 className="font-bold mb-2" style={{ color: NarraColors.brand.primarySolid }}>
                    ✨ Incluye:
                  </h3>
                  <ul className="space-y-1 text-sm" style={{ color: NarraColors.text.secondary }}>
                    <li>✓ Acceso de por vida</li>
                    <li>✓ Historias ilimitadas</li>
                    <li>✓ Fotos y audios</li>
                    <li>✓ Ghost Writer IA</li>
                    <li>✓ Suscriptores ilimitados</li>
                    <li>✓ Sin mensualidades</li>
                  </ul>
                </div>

                <div className="flex items-center gap-3 text-sm" style={{ color: NarraColors.text.light }}>
                  <span>🔒</span>
                  <span>Pago seguro y encriptado</span>
                </div>
              </div>
            </div>
          </div>
        </motion.div>
      </div>
    </div>
  );
};
