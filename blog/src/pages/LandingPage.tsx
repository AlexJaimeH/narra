import React, { useState, useRef } from 'react';

export const LandingPage: React.FC = () => {
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const howRef = useRef<HTMLDivElement>(null);
  const featuresRef = useRef<HTMLDivElement>(null);
  const testimonialsRef = useRef<HTMLDivElement>(null);
  const pricingRef = useRef<HTMLDivElement>(null);
  const faqRef = useRef<HTMLDivElement>(null);

  const scrollToSection = (ref: React.RefObject<HTMLDivElement>) => {
    ref.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    setIsMenuOpen(false);
  };

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="fixed top-0 left-0 right-0 bg-white/95 backdrop-blur-sm shadow-sm z-50 border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            {/* Logo */}
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 bg-gradient-to-br from-brand-primary to-brand-accent rounded-xl flex items-center justify-center shadow-lg">
                <svg className="w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                </svg>
              </div>
              <span className="text-2xl font-bold text-gray-900">Narra</span>
            </div>

            {/* Desktop Navigation */}
            <nav className="hidden md:flex items-center gap-8">
              <button onClick={() => scrollToSection(howRef)} className="text-gray-700 hover:text-brand-primary font-medium transition">
                Cómo funciona
              </button>
              <button onClick={() => scrollToSection(featuresRef)} className="text-gray-700 hover:text-brand-primary font-medium transition">
                Características
              </button>
              <button onClick={() => scrollToSection(testimonialsRef)} className="text-gray-700 hover:text-brand-primary font-medium transition">
                Testimonios
              </button>
              <button onClick={() => scrollToSection(pricingRef)} className="text-gray-700 hover:text-brand-primary font-medium transition">
                Precio
              </button>
              <button onClick={() => scrollToSection(faqRef)} className="text-gray-700 hover:text-brand-primary font-medium transition">
                FAQ
              </button>
              <a href="/app" className="text-gray-700 hover:text-brand-primary font-medium transition">
                Iniciar sesión
              </a>
              <a href="/app" className="px-6 py-2 bg-brand-primary text-white rounded-lg hover:bg-brand-primary-solid transition font-medium">
                Comprar
              </a>
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
            <nav className="md:hidden mt-4 pb-4 flex flex-col gap-3">
              <button onClick={() => scrollToSection(howRef)} className="text-left py-2 text-gray-700 hover:text-brand-primary">
                Cómo funciona
              </button>
              <button onClick={() => scrollToSection(featuresRef)} className="text-left py-2 text-gray-700 hover:text-brand-primary">
                Características
              </button>
              <button onClick={() => scrollToSection(testimonialsRef)} className="text-left py-2 text-gray-700 hover:text-brand-primary">
                Testimonios
              </button>
              <button onClick={() => scrollToSection(pricingRef)} className="text-left py-2 text-gray-700 hover:text-brand-primary">
                Precio
              </button>
              <button onClick={() => scrollToSection(faqRef)} className="text-left py-2 text-gray-700 hover:text-brand-primary">
                FAQ
              </button>
              <a href="/app" className="text-left py-2 text-gray-700 hover:text-brand-primary">
                Iniciar sesión
              </a>
              <a href="/app" className="px-6 py-3 bg-brand-primary text-white rounded-lg hover:bg-brand-primary-solid transition text-center">
                Comprar
              </a>
            </nav>
          )}
        </div>
      </header>

      {/* Hero Section */}
      <section className="pt-32 pb-16 px-6 bg-gradient-to-b from-brand-primary/10 to-white">
        <div className="max-w-5xl mx-auto text-center">
          <h1 className="text-5xl md:text-6xl font-bold text-gray-900 mb-4">
            Tu vida es un legado
          </h1>
          <p className="text-2xl md:text-3xl text-gray-700 mb-8">
            Escribe tu historia. Regálala para siempre a quienes amas.
          </p>
          <div className="flex flex-wrap justify-center gap-4 mb-12">
            <a href="/app" className="px-8 py-4 bg-brand-primary text-white rounded-lg hover:bg-brand-primary-solid transition font-semibold shadow-lg">
              Comprar para un ser querido
            </a>
            <button onClick={() => scrollToSection(howRef)} className="px-8 py-4 bg-white text-brand-primary border-2 border-brand-primary rounded-lg hover:bg-brand-primary/5 transition font-semibold">
              Cómo funciona
            </button>
            <a href="/app" className="px-8 py-4 text-brand-primary hover:underline font-medium">
              Ya tengo cuenta
            </a>
          </div>
          <div className="rounded-2xl overflow-hidden shadow-2xl">
            <img
              src="https://images.unsplash.com/photo-1543269865-cbf427effbad?q=80&w=1600&auto=format&fit=crop"
              alt="Familia compartiendo historias"
              className="w-full h-[400px] object-cover"
            />
          </div>
        </div>
      </section>

      {/* Social Proof */}
      <section className="py-12 px-6 bg-white">
        <div className="max-w-5xl mx-auto flex flex-wrap justify-center gap-8 text-center">
          <div className="flex items-center gap-2">
            <svg className="w-6 h-6 text-brand-primary" fill="currentColor" viewBox="0 0 20 20">
              <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
            </svg>
            <span className="text-gray-700 font-medium">Calificación 4.9/5</span>
          </div>
          <div className="flex items-center gap-2">
            <svg className="w-6 h-6 text-brand-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
            </svg>
            <span className="text-gray-700 font-medium">1000+ familias inspiradas</span>
          </div>
          <div className="flex items-center gap-2">
            <svg className="w-6 h-6 text-brand-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
            </svg>
            <span className="text-gray-700 font-medium">Privado y seguro</span>
          </div>
          <div className="flex items-center gap-2">
            <svg className="w-6 h-6 text-brand-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <span className="text-gray-700 font-medium">En 10 minutos por semana</span>
          </div>
        </div>
      </section>

      {/* How It Works */}
      <section ref={howRef} className="py-20 px-6 bg-gray-50">
        <div className="max-w-5xl mx-auto">
          <h2 className="text-4xl font-bold text-center text-gray-900 mb-12">¿Cómo funciona?</h2>
          <div className="grid md:grid-cols-2 gap-8">
            <StepCard number="1" icon="✍️" title="Escribe o dicta" description="Cuenta tus historias escribiendo o usando tu voz" />
            <StepCard number="2" icon="📷" title="Añade fotos" description="Incluye hasta 8 fotos en cada historia" />
            <StepCard number="3" icon="✨" title="IA te ayuda" description="Sugerencias y mejoras automáticas del texto" />
            <StepCard number="4" icon="📤" title="Comparte" description="Tu familia recibe las historias por email" />
          </div>
        </div>
      </section>

      {/* Emotional Section */}
      <section className="py-16 px-6 bg-brand-primary/5">
        <div className="max-w-4xl mx-auto text-center">
          <h2 className="text-4xl font-bold text-gray-900 mb-4">Porque tu voz importa</h2>
          <p className="text-xl text-gray-700">
            Narra te acompaña para guardar anécdotas, fotos y aprendizajes. Un regalo de amor para tus hijos y nietos — una biblioteca hecha de recuerdos auténticos.
          </p>
        </div>
      </section>

      {/* Features */}
      <section ref={featuresRef} className="py-20 px-6 bg-white">
        <div className="max-w-5xl mx-auto">
          <h2 className="text-4xl font-bold text-center text-gray-900 mb-12">Características</h2>
          <div className="space-y-6">
            <FeatureCard
              icon="♿"
              title="Accesible"
              description="Letra grande, dictado por voz, y diseño pensado para personas mayores"
            />
            <FeatureCard
              icon="🤖"
              title="Asistente IA"
              description="Te ayuda con preguntas, mejora tu texto y verifica que tu historia esté completa"
            />
            <FeatureCard
              icon="🔒"
              title="Privacidad"
              description="Tus historias son privadas. Solo las personas que invites pueden leerlas"
            />
            <FeatureCard
              icon="📖"
              title="Libro personalizado"
              description="Con 8 o más historias, creamos automáticamente tu libro de memorias"
            />
          </div>
        </div>
      </section>

      {/* Testimonials */}
      <section ref={testimonialsRef} className="py-20 px-6 bg-gray-50">
        <div className="max-w-5xl mx-auto">
          <h2 className="text-4xl font-bold text-center text-gray-900 mb-12">Testimonios</h2>
          <div className="grid md:grid-cols-3 gap-8">
            <TestimonialCard
              quote="Mi madre escribió su infancia. Hoy mis hijos la leen con una sonrisa."
              name="Lucía, 38"
              role="Hija"
            />
            <TestimonialCard
              quote="Nunca pensé que escribiría. Con Narra fue fácil y hermoso."
              name="Jorge, 72"
              role="Abuelo"
            />
            <TestimonialCard
              quote="Es el mejor regalo que nos hicimos como familia."
              name="María, 45"
              role="Madre"
            />
          </div>
        </div>
      </section>

      {/* Pricing */}
      <section ref={pricingRef} className="py-20 px-6 bg-white">
        <div className="max-w-2xl mx-auto">
          <h2 className="text-4xl font-bold text-center text-gray-900 mb-12">Precio</h2>
          <div className="bg-white border-2 border-brand-primary rounded-2xl p-8 shadow-xl">
            <div className="text-center mb-6">
              <p className="text-brand-primary font-bold text-xl mb-2">Pago único</p>
              <p className="text-6xl font-bold text-brand-primary">25<span className="text-2xl">€</span></p>
            </div>
            <div className="space-y-3 mb-8">
              <PricingFeature text="Historias ilimitadas" />
              <PricingFeature text="Fotos en cada historia" />
              <PricingFeature text="Asistente de IA" />
              <PricingFeature text="Dictado por voz" />
              <PricingFeature text="Libro automático" />
              <PricingFeature text="Suscriptores ilimitados" />
            </div>
            <a href="/app" className="block w-full py-4 bg-brand-primary text-white text-center rounded-lg hover:bg-brand-primary-solid transition font-semibold text-lg">
              Comprar ahora
            </a>
          </div>
        </div>
      </section>

      {/* FAQ */}
      <section ref={faqRef} className="py-20 px-6 bg-gray-50">
        <div className="max-w-3xl mx-auto">
          <h2 className="text-4xl font-bold text-center text-gray-900 mb-12">Preguntas frecuentes</h2>
          <div className="space-y-4">
            <FaqItem
              question="¿Es difícil escribir mis historias?"
              answer="No. Te guiamos con preguntas sencillas y puedes dictar por voz."
            />
            <FaqItem
              question="¿Quién puede leer mis historias?"
              answer="Tú decides. Las historias son privadas y solo accede quien invites."
            />
            <FaqItem
              question="¿Cuánto cuesta?"
              answer="Un pago único de 25€ para desbloquear todas las funciones."
            />
            <FaqItem
              question="¿Puedo regalar Narra?"
              answer="Sí. Usa 'Comprar para un ser querido' y te guiamos en el proceso."
            />
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="py-12 px-6 bg-gray-800 text-white">
        <div className="max-w-5xl mx-auto text-center">
          <p className="text-2xl font-bold mb-2 text-brand-primary">Narra</p>
          <p className="text-gray-300 mb-6">Historias que perduran para siempre</p>
          <div className="flex justify-center gap-6 mb-6 text-sm text-gray-400">
            <button className="hover:text-white">Privacidad</button>
            <button className="hover:text-white">Términos</button>
            <button className="hover:text-white">Cookies</button>
          </div>
          <p className="text-sm text-gray-400">© 2025 Narra. Todos los derechos reservados.</p>
        </div>
      </footer>
    </div>
  );
};

// Helper Components
const StepCard: React.FC<{ number: string; icon: string; title: string; description: string }> = ({ number, icon, title, description }) => (
  <div className="bg-white rounded-xl p-6 shadow-lg">
    <div className="flex items-center gap-4 mb-4">
      <div className="w-12 h-12 bg-brand-primary text-white rounded-full flex items-center justify-center font-bold text-xl">
        {number}
      </div>
      <span className="text-4xl">{icon}</span>
    </div>
    <h3 className="text-xl font-bold text-gray-900 mb-2">{title}</h3>
    <p className="text-gray-600">{description}</p>
  </div>
);

const FeatureCard: React.FC<{ icon: string; title: string; description: string }> = ({ icon, title, description }) => (
  <div className="bg-white rounded-xl p-6 shadow-md flex items-start gap-4">
    <div className="w-14 h-14 bg-brand-primary/10 rounded-xl flex items-center justify-center text-3xl flex-shrink-0">
      {icon}
    </div>
    <div>
      <h3 className="text-xl font-bold text-gray-900 mb-2">{title}</h3>
      <p className="text-gray-600">{description}</p>
    </div>
  </div>
);

const TestimonialCard: React.FC<{ quote: string; name: string; role: string }> = ({ quote, name, role }) => (
  <div className="bg-white rounded-xl p-6 shadow-lg">
    <p className="text-gray-700 mb-4 italic text-lg">"{quote}"</p>
    <p className="font-bold text-gray-900">{name}</p>
    <p className="text-sm text-gray-600">{role}</p>
  </div>
);

const PricingFeature: React.FC<{ text: string }> = ({ text }) => (
  <div className="flex items-center gap-3">
    <svg className="w-6 h-6 text-brand-primary flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
      <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
    </svg>
    <span className="text-gray-700">{text}</span>
  </div>
);

const FaqItem: React.FC<{ question: string; answer: string }> = ({ question, answer }) => (
  <div className="bg-white rounded-xl p-6 shadow-md">
    <h3 className="font-bold text-lg text-gray-900 mb-2">{question}</h3>
    <p className="text-gray-600">{answer}</p>
  </div>
);
