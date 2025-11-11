import React, { useState, useEffect } from 'react';
import { useSearchParams } from 'react-router-dom';
import { motion } from 'framer-motion';
import { NarraColors } from '../styles/colors';

interface AuthorData {
  email: string;
  created_at: string;
}

interface Subscriber {
  id: string;
  name: string;
  email: string;
  status: string;
  added_at: string;
}

export const GiftManagementPage: React.FC = () => {
  const [searchParams] = useSearchParams();
  const [token, setToken] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const [authorData, setAuthorData] = useState<AuthorData | null>(null);
  const [subscribers, setSubscribers] = useState<Subscriber[]>([]);

  const [activeSection, setActiveSection] = useState<'email' | 'subscribers' | 'download' | 'login'>('email');

  // Email change states
  const [newEmail, setNewEmail] = useState('');
  const [newEmailConfirm, setNewEmailConfirm] = useState('');
  const [emailChanging, setEmailChanging] = useState(false);

  // Subscriber states
  const [newSubName, setNewSubName] = useState('');
  const [newSubEmail, setNewSubEmail] = useState('');
  const [addingSubscriber, setAddingSubscriber] = useState(false);

  // Other states
  const [downloading, setDownloading] = useState(false);
  const [sendingLink, setSendingLink] = useState(false);
  const [resendingSubLink, setResendingSubLink] = useState<string | null>(null);

  useEffect(() => {
    const tokenParam = searchParams.get('token');
    if (!tokenParam) {
      setError('Token no encontrado en la URL');
      setLoading(false);
      return;
    }
    setToken(tokenParam);
    loadAuthorData(tokenParam);
  }, [searchParams]);

  const loadAuthorData = async (token: string) => {
    try {
      setLoading(true);
      const response = await fetch(`/api/gift-management-get-author?token=${token}`);
      const data = await response.json();

      if (response.ok && data.success) {
        setAuthorData(data.author);
        setSubscribers(data.subscribers || []);
      } else {
        setError(data.error || 'Error al cargar datos');
      }
    } catch (err) {
      setError('Error de conexión');
    } finally {
      setLoading(false);
    }
  };

  const handleChangeEmail = async (e: React.FormEvent) => {
    e.preventDefault();

    if (newEmail !== newEmailConfirm) {
      alert('Los emails no coinciden');
      return;
    }

    if (newEmail === authorData?.email) {
      alert('El nuevo email es igual al actual');
      return;
    }

    setEmailChanging(true);
    try {
      const response = await fetch('/api/gift-management-change-email', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ token, newEmail }),
      });

      const data = await response.json();

      if (response.ok && data.success) {
        alert('✅ Email cambiado exitosamente');
        setAuthorData({ ...authorData!, email: newEmail });
        setNewEmail('');
        setNewEmailConfirm('');
      } else {
        alert(data.error || 'Error al cambiar email');
      }
    } catch (err) {
      alert('Error de conexión');
    } finally {
      setEmailChanging(false);
    }
  };

  const handleAddSubscriber = async (e: React.FormEvent) => {
    e.preventDefault();

    setAddingSubscriber(true);
    try {
      const response = await fetch('/api/gift-management-add-subscriber', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ token, name: newSubName, email: newSubEmail }),
      });

      const data = await response.json();

      if (response.ok && data.success) {
        alert('✅ Suscriptor agregado exitosamente');
        // Reload subscribers
        await loadAuthorData(token);
        setNewSubName('');
        setNewSubEmail('');
      } else {
        alert(data.error || 'Error al agregar suscriptor');
      }
    } catch (err) {
      alert('Error de conexión');
    } finally {
      setAddingSubscriber(false);
    }
  };

  const handleRemoveSubscriber = async (subscriberId: string) => {
    if (!confirm('¿Estás seguro de eliminar este suscriptor?')) {
      return;
    }

    try {
      const response = await fetch('/api/gift-management-remove-subscriber', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ token, subscriberId }),
      });

      const data = await response.json();

      if (response.ok && data.success) {
        alert('✅ Suscriptor eliminado');
        // Reload subscribers
        await loadAuthorData(token);
      } else {
        alert(data.error || 'Error al eliminar suscriptor');
      }
    } catch (err) {
      alert('Error de conexión');
    }
  };

  const handleDownloadData = async () => {
    setDownloading(true);
    try {
      const response = await fetch(`/api/gift-management-download-data?token=${token}`);

      if (response.ok) {
        const blob = await response.blob();
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `narra-historias-${new Date().toISOString().split('T')[0]}.zip`;
        document.body.appendChild(a);
        a.click();
        a.remove();
        window.URL.revokeObjectURL(url);
      } else {
        const data = await response.json();
        alert(data.error || 'Error al descargar datos');
      }
    } catch (err) {
      alert('Error de conexión');
    } finally {
      setDownloading(false);
    }
  };

  const handleSendMagicLink = async () => {
    if (!confirm(`¿Enviar enlace de inicio de sesión a ${authorData?.email}?`)) {
      return;
    }

    setSendingLink(true);
    try {
      const response = await fetch('/api/gift-management-send-magic-link', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ token }),
      });

      const data = await response.json();

      if (response.ok && data.success) {
        alert('✅ Enlace enviado exitosamente');
      } else {
        alert(data.error || 'Error al enviar enlace');
      }
    } catch (err) {
      alert('Error de conexión');
    } finally {
      setSendingLink(false);
    }
  };

  const handleResendSubscriberLink = async (subscriberId: string, subscriberName: string) => {
    if (!confirm(`¿Reenviar enlace de acceso a ${subscriberName}?`)) {
      return;
    }

    setResendingSubLink(subscriberId);
    try {
      const response = await fetch('/api/gift-management-resend-subscriber-link', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ token, subscriberId }),
      });

      const data = await response.json();

      if (response.ok && data.success) {
        alert('✅ Enlace reenviado exitosamente');
      } else {
        alert(data.error || 'Error al reenviar enlace');
      }
    } catch (err) {
      alert('Error de conexión');
    } finally {
      setResendingSubLink(null);
    }
  };

  if (loading) {
    return (
      <div
        className="flex items-center justify-center min-h-screen"
        style={{ background: 'linear-gradient(135deg, #fdfbf7 0%, #f0ebe3 100%)' }}
      >
        <div className="text-center">
          <div className="w-12 h-12 border-4 border-t-transparent rounded-full animate-spin mx-auto mb-4"
            style={{ borderColor: NarraColors.brand.primary, borderTopColor: 'transparent' }}
          />
          <p style={{ color: NarraColors.text.secondary }}>Cargando panel de gestión...</p>
        </div>
      </div>
    );
  }

  if (error || !authorData) {
    return (
      <div
        className="flex items-center justify-center min-h-screen p-4"
        style={{ background: 'linear-gradient(135deg, #fdfbf7 0%, #f0ebe3 100%)' }}
      >
        <div
          className="max-w-md w-full p-8 rounded-3xl text-center"
          style={{
            background: NarraColors.surface.white,
            boxShadow: '0 10px 30px rgba(0,0,0,0.1)',
          }}
        >
          <div className="text-6xl mb-4">❌</div>
          <h1 className="text-2xl font-bold mb-2" style={{ color: NarraColors.text.primary }}>
            Error
          </h1>
          <p style={{ color: NarraColors.text.secondary }}>
            {error || 'No se pudieron cargar los datos'}
          </p>
          <a
            href="/"
            className="inline-block mt-6 px-6 py-3 rounded-xl font-bold text-white"
            style={{ background: 'linear-gradient(135deg, #4DB3A8 0%, #38827A 100%)' }}
          >
            Volver al Inicio
          </a>
        </div>
      </div>
    );
  }

  return (
    <div
      className="min-h-screen"
      style={{ background: 'linear-gradient(135deg, #fdfbf7 0%, #f0ebe3 100%)' }}
    >
      {/* Header */}
      <header className="bg-white/95 backdrop-blur-sm shadow-sm border-b" style={{ borderColor: '#e5e7eb' }}>
        <div className="max-w-7xl mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            <img src="/logo-horizontal.png" alt="Narra" className="h-10 w-auto object-contain" />
            <div className="text-right">
              <p className="text-sm" style={{ color: NarraColors.text.light }}>Panel de Gestión</p>
              <p className="text-sm font-semibold" style={{ color: NarraColors.text.primary }}>
                {authorData.email}
              </p>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <div className="max-w-6xl mx-auto px-6 py-12">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
        >
          <h1 className="text-4xl font-bold mb-2" style={{ color: NarraColors.text.primary }}>
            Panel de Gestión del Regalo
          </h1>
          <p className="text-lg mb-8" style={{ color: NarraColors.text.secondary }}>
            Administra la cuenta regalada de forma segura
          </p>

          <div className="grid md:grid-cols-4 gap-4 mb-8">
            {[
              { key: 'email', icon: '📧', label: 'Cambiar Email' },
              { key: 'subscribers', icon: '👥', label: 'Suscriptores' },
              { key: 'download', icon: '📥', label: 'Descargar Datos' },
              { key: 'login', icon: '🔗', label: 'Enviar Acceso' },
            ].map(({ key, icon, label }) => (
              <motion.button
                key={key}
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.98 }}
                onClick={() => setActiveSection(key as any)}
                className={`p-4 rounded-xl font-semibold transition-all ${
                  activeSection === key ? 'shadow-lg' : ''
                }`}
                style={{
                  background: activeSection === key
                    ? 'linear-gradient(135deg, #4DB3A8 0%, #38827A 100%)'
                    : NarraColors.surface.white,
                  color: activeSection === key ? '#fff' : NarraColors.text.primary,
                  boxShadow: activeSection === key
                    ? '0 8px 24px rgba(77,179,168,0.35)'
                    : '0 4px 12px rgba(0,0,0,0.08)',
                }}
              >
                <div className="text-2xl mb-1">{icon}</div>
                <div className="text-sm">{label}</div>
              </motion.button>
            ))}
          </div>

          {/* Section Content */}
          <motion.div
            key={activeSection}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.4 }}
            className="p-8 rounded-3xl"
            style={{
              background: NarraColors.surface.white,
              boxShadow: '0 10px 30px rgba(0,0,0,0.1)',
            }}
          >
            {/* Change Email Section */}
            {activeSection === 'email' && (
              <div>
                <h2 className="text-2xl font-bold mb-4" style={{ color: NarraColors.text.primary }}>
                  Cambiar Email del Autor
                </h2>
                <p className="mb-6" style={{ color: NarraColors.text.secondary }}>
                  Email actual: <strong>{authorData.email}</strong>
                </p>

                <form onSubmit={handleChangeEmail} className="space-y-4">
                  <div>
                    <label className="block text-sm font-semibold mb-2">Nuevo Email</label>
                    <input
                      type="email"
                      value={newEmail}
                      onChange={(e) => setNewEmail(e.target.value)}
                      className="w-full px-4 py-3 rounded-xl border-2"
                      style={{ borderColor: NarraColors.border.light }}
                      required
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-semibold mb-2">Confirmar Nuevo Email</label>
                    <input
                      type="email"
                      value={newEmailConfirm}
                      onChange={(e) => setNewEmailConfirm(e.target.value)}
                      className="w-full px-4 py-3 rounded-xl border-2"
                      style={{ borderColor: NarraColors.border.light }}
                      required
                    />
                  </div>

                  <div
                    className="p-4 rounded-xl"
                    style={{ background: '#E8F5F4', border: `1px solid ${NarraColors.brand.primary}` }}
                  >
                    <p className="text-sm" style={{ color: NarraColors.text.secondary }}>
                      ⚠️ El autor recibirá un email notificándole del cambio de email
                    </p>
                  </div>

                  <button
                    type="submit"
                    disabled={emailChanging}
                    className="w-full py-3 rounded-xl font-bold text-white disabled:opacity-50"
                    style={{ background: 'linear-gradient(135deg, #4DB3A8 0%, #38827A 100%)' }}
                  >
                    {emailChanging ? 'Cambiando...' : '✓ Cambiar Email'}
                  </button>
                </form>
              </div>
            )}

            {/* Subscribers Section */}
            {activeSection === 'subscribers' && (
              <div>
                <h2 className="text-2xl font-bold mb-4" style={{ color: NarraColors.text.primary }}>
                  Gestionar Suscriptores
                </h2>

                {/* Add Subscriber Form */}
                <div className="mb-8 p-6 rounded-2xl" style={{ background: '#E8F5F4' }}>
                  <h3 className="font-bold mb-4">Agregar Suscriptor</h3>
                  <form onSubmit={handleAddSubscriber} className="space-y-3">
                    <div className="grid md:grid-cols-2 gap-3">
                      <input
                        type="text"
                        value={newSubName}
                        onChange={(e) => setNewSubName(e.target.value)}
                        placeholder="Nombre"
                        className="px-4 py-2 rounded-xl border-2"
                        style={{ borderColor: NarraColors.border.light, background: '#fff' }}
                        required
                      />
                      <input
                        type="email"
                        value={newSubEmail}
                        onChange={(e) => setNewSubEmail(e.target.value)}
                        placeholder="Email"
                        className="px-4 py-2 rounded-xl border-2"
                        style={{ borderColor: NarraColors.border.light, background: '#fff' }}
                        required
                      />
                    </div>
                    <button
                      type="submit"
                      disabled={addingSubscriber}
                      className="w-full py-2 rounded-xl font-bold text-white disabled:opacity-50"
                      style={{ background: 'linear-gradient(135deg, #4DB3A8 0%, #38827A 100%)' }}
                    >
                      {addingSubscriber ? 'Agregando...' : '+ Agregar'}
                    </button>
                  </form>
                </div>

                {/* Subscribers List */}
                <div>
                  <h3 className="font-bold mb-4">Suscriptores Actuales ({subscribers.length})</h3>
                  {subscribers.length === 0 ? (
                    <p style={{ color: NarraColors.text.light }}>No hay suscriptores aún</p>
                  ) : (
                    <div className="space-y-3">
                      {subscribers.map((sub) => (
                        <div
                          key={sub.id}
                          className="p-4 rounded-xl"
                          style={{ background: '#f9fafb', border: `1px solid ${NarraColors.border.light}` }}
                        >
                          <div className="flex items-start justify-between mb-3">
                            <div className="flex-1">
                              <p className="font-semibold text-lg">{sub.name}</p>
                              <p className="text-sm mb-2" style={{ color: NarraColors.text.light }}>{sub.email}</p>
                              <div className="flex items-center gap-2">
                                <span
                                  className="inline-block px-2 py-1 rounded-md text-xs font-semibold"
                                  style={{
                                    background: sub.status === 'confirmed' ? '#D1FAE5' : sub.status === 'pending' ? '#FEF3C7' : '#FEE2E2',
                                    color: sub.status === 'confirmed' ? '#065F46' : sub.status === 'pending' ? '#92400E' : '#991B1B',
                                  }}
                                >
                                  {sub.status === 'confirmed' ? '✓ Confirmado' : sub.status === 'pending' ? '⏳ Pendiente' : '✗ Dado de baja'}
                                </span>
                                <span className="text-xs" style={{ color: NarraColors.text.light }}>
                                  Agregado: {new Date(sub.added_at).toLocaleDateString()}
                                </span>
                              </div>
                            </div>
                          </div>
                          <div className="flex gap-2">
                            <button
                              onClick={() => handleResendSubscriberLink(sub.id, sub.name)}
                              disabled={resendingSubLink === sub.id}
                              className="flex-1 px-4 py-2 rounded-lg font-semibold text-sm disabled:opacity-50"
                              style={{ background: '#E8F5F4', color: NarraColors.brand.primary }}
                            >
                              {resendingSubLink === sub.id ? 'Enviando...' : '📧 Reenviar Enlace'}
                            </button>
                            <button
                              onClick={() => handleRemoveSubscriber(sub.id)}
                              className="px-4 py-2 rounded-lg font-semibold text-sm"
                              style={{ background: '#FEE2E2', color: NarraColors.status.error }}
                            >
                              🗑️ Eliminar
                            </button>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              </div>
            )}

            {/* Download Section */}
            {activeSection === 'download' && (
              <div>
                <h2 className="text-2xl font-bold mb-4" style={{ color: NarraColors.text.primary }}>
                  Descargar Datos
                </h2>
                <p className="mb-6" style={{ color: NarraColors.text.secondary }}>
                  Descarga las historias publicadas del autor en formato texto
                </p>

                <div
                  className="p-6 rounded-xl mb-6"
                  style={{ background: '#FFFBEB', border: `2px solid ${NarraColors.status.warning}` }}
                >
                  <h3 className="font-bold mb-2">⚠️ Limitaciones</h3>
                  <ul className="space-y-1 text-sm" style={{ color: NarraColors.text.secondary }}>
                    <li>• Solo historias publicadas (no borradores)</li>
                    <li>• Solo contenido de texto (sin fotos ni grabaciones)</li>
                    <li>• Sin historial de versiones</li>
                    <li>• Para descarga completa, el autor debe hacerlo desde su cuenta</li>
                  </ul>
                </div>

                <button
                  onClick={handleDownloadData}
                  disabled={downloading}
                  className="w-full py-4 rounded-xl font-bold text-white disabled:opacity-50"
                  style={{ background: 'linear-gradient(135deg, #4DB3A8 0%, #38827A 100%)' }}
                >
                  {downloading ? 'Descargando...' : '📥 Descargar Historias'}
                </button>
              </div>
            )}

            {/* Send Login Link Section */}
            {activeSection === 'login' && (
              <div>
                <h2 className="text-2xl font-bold mb-4" style={{ color: NarraColors.text.primary }}>
                  Enviar Enlace de Acceso
                </h2>
                <p className="mb-6" style={{ color: NarraColors.text.secondary }}>
                  Envía un enlace mágico al autor para que pueda iniciar sesión
                </p>

                <div
                  className="p-6 rounded-xl mb-6"
                  style={{ background: '#E8F5F4', borderLeft: `4px solid ${NarraColors.brand.primary}` }}
                >
                  <p className="text-sm mb-2">📧 Se enviará a: <strong>{authorData.email}</strong></p>
                  <p className="text-sm" style={{ color: NarraColors.text.light }}>
                    El enlace será válido por 15 minutos
                  </p>
                </div>

                <button
                  onClick={handleSendMagicLink}
                  disabled={sendingLink}
                  className="w-full py-4 rounded-xl font-bold text-white disabled:opacity-50"
                  style={{ background: 'linear-gradient(135deg, #4DB3A8 0%, #38827A 100%)' }}
                >
                  {sendingLink ? 'Enviando...' : '🔗 Enviar Enlace de Acceso'}
                </button>
              </div>
            )}
          </motion.div>

          {/* Footer */}
          <div className="mt-8 text-center">
            <p className="text-sm mb-2" style={{ color: NarraColors.text.light }}>
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
        </motion.div>
      </div>
    </div>
  );
};
