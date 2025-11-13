import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { LegalPageLayout } from '../components/LegalPageLayout';

interface FormData {
  name: string;
  email: string;
  message: string;
  isCurrentClient: boolean;
}

interface FormErrors {
  name?: string;
  email?: string;
  message?: string;
}

export const ContactPage: React.FC = () => {
  const [formData, setFormData] = useState<FormData>({
    name: '',
    email: '',
    message: '',
    isCurrentClient: false,
  });

  const [errors, setErrors] = useState<FormErrors>({});
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitStatus, setSubmitStatus] = useState<'idle' | 'success' | 'error'>('idle');

  const validateForm = (): boolean => {
    const newErrors: FormErrors = {};

    if (!formData.name.trim()) {
      newErrors.name = 'Por favor ingresa tu nombre';
    }

    if (!formData.email.trim()) {
      newErrors.email = 'Por favor ingresa tu correo electrónico';
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.email)) {
      newErrors.email = 'Por favor ingresa un correo válido';
    }

    if (!formData.message.trim()) {
      newErrors.message = 'Por favor escribe tu mensaje';
    } else if (formData.message.trim().length < 10) {
      newErrors.message = 'El mensaje debe tener al menos 10 caracteres';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!validateForm()) {
      return;
    }

    setIsSubmitting(true);
    setSubmitStatus('idle');

    try {
      // Llamar al API para enviar el mensaje
      const response = await fetch('/api/contact', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          name: formData.name.trim(),
          email: formData.email.trim(),
          message: formData.message.trim(),
          is_current_client: formData.isCurrentClient,
        }),
      });

      if (response.ok) {
        setSubmitStatus('success');
        setFormData({
          name: '',
          email: '',
          message: '',
          isCurrentClient: false,
        });
      } else {
        setSubmitStatus('error');
      }
    } catch (error) {
      console.error('Error al enviar mensaje:', error);
      setSubmitStatus('error');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleChange = (field: keyof FormData, value: string | boolean) => {
    setFormData(prev => ({ ...prev, [field]: value }));
    if (errors[field as keyof FormErrors]) {
      setErrors(prev => ({ ...prev, [field]: undefined }));
    }
  };

  return (
    <LegalPageLayout title="Contacto">
      <div className="max-w-2xl mx-auto">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2, duration: 0.6 }}
          className="text-center mb-12"
        >
          <div className="w-20 h-20 rounded-full flex items-center justify-center text-4xl mx-auto mb-6" style={{ background: '#E8F5F4' }}>
            💬
          </div>
          <h2 className="text-2xl font-bold mb-4" style={{ color: '#1F2937' }}>
            Nos encantaría escucharte
          </h2>
          <p className="text-lg" style={{ color: '#4B5563' }}>
            ¿Tienes una pregunta, sugerencia o necesitas ayuda? Envíanos un mensaje y te responderemos lo antes posible.
          </p>
        </motion.div>

        {submitStatus === 'success' ? (
          <motion.div
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ duration: 0.5 }}
            className="text-center py-12"
          >
            <div className="w-24 h-24 rounded-full flex items-center justify-center text-5xl mx-auto mb-6" style={{ background: '#E8F5F4' }}>
              ✅
            </div>
            <h3 className="text-3xl font-bold mb-4" style={{ color: '#4DB3A8' }}>
              ¡Mensaje enviado!
            </h3>
            <p className="text-xl mb-8" style={{ color: '#4B5563' }}>
              Gracias por contactarnos. Hemos recibido tu mensaje y te responderemos pronto a <strong>{formData.email || 'tu correo'}</strong>.
            </p>
            <motion.button
              onClick={() => setSubmitStatus('idle')}
              className="px-8 py-3 text-white rounded-xl font-semibold shadow-lg"
              style={{ background: 'linear-gradient(135deg, #4DB3A8 0%, #38827A 100%)' }}
              whileHover={{ scale: 1.05, boxShadow: '0 20px 40px rgba(77, 179, 168, 0.3)' }}
              whileTap={{ scale: 0.95 }}
            >
              Enviar otro mensaje
            </motion.button>
          </motion.div>
        ) : (
          <form onSubmit={handleSubmit} className="space-y-6">
            {/* Nombre */}
            <div>
              <label htmlFor="name" className="block text-sm font-semibold mb-2" style={{ color: '#1F2937' }}>
                Tu nombre <span style={{ color: '#EF4444' }}>*</span>
              </label>
              <input
                type="text"
                id="name"
                value={formData.name}
                onChange={(e) => handleChange('name', e.target.value)}
                placeholder="¿Cómo te llamas?"
                className="w-full px-4 py-3 rounded-xl border-2 transition-all focus:outline-none"
                style={{
                  borderColor: errors.name ? '#EF4444' : '#E8F5F4',
                  background: '#FDFBF7',
                }}
                onFocus={(e) => e.target.style.borderColor = '#4DB3A8'}
                onBlur={(e) => e.target.style.borderColor = errors.name ? '#EF4444' : '#E8F5F4'}
              />
              {errors.name && (
                <p className="mt-2 text-sm" style={{ color: '#EF4444' }}>
                  {errors.name}
                </p>
              )}
            </div>

            {/* Email */}
            <div>
              <label htmlFor="email" className="block text-sm font-semibold mb-2" style={{ color: '#1F2937' }}>
                Tu correo electrónico <span style={{ color: '#EF4444' }}>*</span>
              </label>
              <input
                type="email"
                id="email"
                value={formData.email}
                onChange={(e) => handleChange('email', e.target.value)}
                placeholder="tu@correo.com"
                className="w-full px-4 py-3 rounded-xl border-2 transition-all focus:outline-none"
                style={{
                  borderColor: errors.email ? '#EF4444' : '#E8F5F4',
                  background: '#FDFBF7',
                }}
                onFocus={(e) => e.target.style.borderColor = '#4DB3A8'}
                onBlur={(e) => e.target.style.borderColor = errors.email ? '#EF4444' : '#E8F5F4'}
              />
              {errors.email && (
                <p className="mt-2 text-sm" style={{ color: '#EF4444' }}>
                  {errors.email}
                </p>
              )}
              <p className="mt-2 text-sm" style={{ color: '#6B7280' }}>
                Te responderemos a este correo
              </p>
            </div>

            {/* ¿Eres cliente actual? */}
            <div>
              <label className="flex items-center gap-3 cursor-pointer p-4 rounded-xl border-2 transition-all hover:bg-opacity-50" style={{ borderColor: '#E8F5F4', background: formData.isCurrentClient ? '#E8F5F4' : 'transparent' }}>
                <input
                  type="checkbox"
                  checked={formData.isCurrentClient}
                  onChange={(e) => handleChange('isCurrentClient', e.target.checked)}
                  className="w-5 h-5 rounded cursor-pointer"
                  style={{ accentColor: '#4DB3A8' }}
                />
                <span className="text-base font-medium" style={{ color: '#1F2937' }}>
                  Soy cliente actual de Narra
                </span>
              </label>
            </div>

            {/* Mensaje */}
            <div>
              <label htmlFor="message" className="block text-sm font-semibold mb-2" style={{ color: '#1F2937' }}>
                Tu mensaje <span style={{ color: '#EF4444' }}>*</span>
              </label>
              <textarea
                id="message"
                value={formData.message}
                onChange={(e) => handleChange('message', e.target.value)}
                placeholder="Cuéntanos qué necesitas... ¿Tienes una pregunta? ¿Una sugerencia? ¿Necesitas ayuda?"
                rows={6}
                className="w-full px-4 py-3 rounded-xl border-2 transition-all focus:outline-none resize-none"
                style={{
                  borderColor: errors.message ? '#EF4444' : '#E8F5F4',
                  background: '#FDFBF7',
                }}
                onFocus={(e) => e.target.style.borderColor = '#4DB3A8'}
                onBlur={(e) => e.target.style.borderColor = errors.message ? '#EF4444' : '#E8F5F4'}
              />
              {errors.message && (
                <p className="mt-2 text-sm" style={{ color: '#EF4444' }}>
                  {errors.message}
                </p>
              )}
              <p className="mt-2 text-sm" style={{ color: '#6B7280' }}>
                {formData.message.length} caracteres
              </p>
            </div>

            {/* Error general */}
            {submitStatus === 'error' && (
              <motion.div
                initial={{ opacity: 0, y: -10 }}
                animate={{ opacity: 1, y: 0 }}
                className="p-4 rounded-xl border-2"
                style={{ borderColor: '#EF4444', background: '#FEE2E2' }}
              >
                <p className="text-sm font-medium" style={{ color: '#991B1B' }}>
                  Hubo un error al enviar tu mensaje. Por favor intenta de nuevo o escríbenos directamente a <a href="mailto:contacto@narra.mx" className="underline font-bold">contacto@narra.mx</a>
                </p>
              </motion.div>
            )}

            {/* Botón de envío */}
            <motion.button
              type="submit"
              disabled={isSubmitting}
              className="w-full py-4 text-white rounded-xl font-bold text-lg shadow-xl transition-all"
              style={{
                background: isSubmitting ? '#9CA3AF' : 'linear-gradient(135deg, #4DB3A8 0%, #38827A 100%)',
                cursor: isSubmitting ? 'not-allowed' : 'pointer',
              }}
              whileHover={!isSubmitting ? { scale: 1.02, boxShadow: '0 25px 50px rgba(77, 179, 168, 0.4)' } : {}}
              whileTap={!isSubmitting ? { scale: 0.98 } : {}}
            >
              {isSubmitting ? (
                <span className="flex items-center justify-center gap-3">
                  <svg className="animate-spin h-5 w-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                  Enviando...
                </span>
              ) : (
                '📨 Enviar mensaje'
              )}
            </motion.button>

            <p className="text-center text-sm" style={{ color: '#6B7280' }}>
              Al enviar este formulario, aceptas nuestra <a href="/privacidad" className="font-semibold" style={{ color: '#4DB3A8' }}>Política de Privacidad</a>
            </p>
          </form>
        )}

        {/* Información adicional */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.4, duration: 0.6 }}
          className="mt-16 pt-8 border-t"
          style={{ borderColor: '#E8F5F4' }}
        >
          <h3 className="text-xl font-bold mb-6 text-center" style={{ color: '#1F2937' }}>
            Otras formas de contactarnos
          </h3>
          <div className="grid md:grid-cols-2 gap-6">
            <div className="p-6 rounded-2xl text-center" style={{ background: '#E8F5F4' }}>
              <div className="text-3xl mb-3">📧</div>
              <p className="font-semibold mb-2" style={{ color: '#1F2937' }}>Correo directo</p>
              <a href="mailto:contacto@narra.mx" className="text-lg font-bold" style={{ color: '#4DB3A8' }}>
                contacto@narra.mx
              </a>
            </div>
            <div className="p-6 rounded-2xl text-center" style={{ background: '#E8F5F4' }}>
              <div className="text-3xl mb-3">🔒</div>
              <p className="font-semibold mb-2" style={{ color: '#1F2937' }}>Privacidad</p>
              <a href="mailto:privacidad@narra.mx" className="text-lg font-bold" style={{ color: '#4DB3A8' }}>
                privacidad@narra.mx
              </a>
            </div>
          </div>
        </motion.div>
      </div>
    </LegalPageLayout>
  );
};
