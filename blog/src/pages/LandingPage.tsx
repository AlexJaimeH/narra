import React, { useState, useRef } from 'react';

export const LandingPage: React.FC = () => {
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const howRef = useRef<HTMLDivElement>(null);
  const featuresRef = useRef<HTMLDivElement>(null);
  const testimonialsRef = useRef<HTMLDivElement>(null);
  const pricingRef = useRef<HTMLDivElement>(null);

  const scrollToSection = (ref: React.RefObject<HTMLDivElement>) => {
    ref.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    setIsMenuOpen(false);
  };

  return (
    <div className="min-h-screen" style={{ background: 'linear-gradient(135deg, #fdfbf7 0%, #f0ebe3 100%)' }}>
      {/* Header */}
      <header className="fixed top-0 left-0 right-0 bg-white/95 backdrop-blur-sm shadow-sm z-50 border-b" style={{ borderColor: '#e5e7eb' }}>
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
              <button onClick={() => scrollToSection(howRef)} className="text-gray-700 hover:text-[#4DB3A8] font-medium transition">
                Cómo funciona
              </button>
              <button onClick={() => scrollToSection(featuresRef)} className="text-gray-700 hover:text-[#4DB3A8] font-medium transition">
                Características
              </button>
              <button onClick={() => scrollToSection(pricingRef)} className="text-gray-700 hover:text-[#4DB3A8] font-medium transition">
                Precio
              </button>
              <button onClick={() => scrollToSection(testimonialsRef)} className="text-gray-700 hover:text-[#4DB3A8] font-medium transition">
                Testimonios
              </button>
              <a href="/app" className="text-gray-700 hover:text-[#4DB3A8] font-medium transition">
                Iniciar sesión
              </a>
              <a
                href="#comprar"
                className="px-6 py-2.5 text-white rounded-xl font-semibold shadow-lg hover:shadow-xl transition-all"
                style={{ background: 'linear-gradient(135deg, #4DB3A8 0%, #38827A 100%)' }}
                onClick={(e) => {
                  e.preventDefault();
                  scrollToSection(pricingRef);
                }}
              >
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
              <button onClick={() => scrollToSection(howRef)} className="text-left py-2 text-gray-700 hover:text-[#4DB3A8]">
                Cómo funciona
              </button>
              <button onClick={() => scrollToSection(featuresRef)} className="text-left py-2 text-gray-700 hover:text-[#4DB3A8]">
                Características
              </button>
              <button onClick={() => scrollToSection(pricingRef)} className="text-left py-2 text-gray-700 hover:text-[#4DB3A8]">
                Precio
              </button>
              <button onClick={() => scrollToSection(testimonialsRef)} className="text-left py-2 text-gray-700 hover:text-[#4DB3A8]">
                Testimonios
              </button>
              <a href="/app" className="text-left py-2 text-gray-700 hover:text-[#4DB3A8]">
                Iniciar sesión
              </a>
              <a
                href="#comprar"
                className="px-6 py-3 text-white rounded-xl text-center font-semibold"
                style={{ background: 'linear-gradient(135deg, #4DB3A8 0%, #38827A 100%)' }}
                onClick={(e) => {
                  e.preventDefault();
                  scrollToSection(pricingRef);
                }}
              >
                Comprar
              </a>
            </nav>
          )}
        </div>
      </header>

      {/* Hero Section */}
      <section className="pt-32 pb-20 px-6">
        <div className="max-w-7xl mx-auto">
          <div className="grid lg:grid-cols-2 gap-12 items-center">
            {/* Left: Text Content */}
            <div className="text-center lg:text-left">
              <div className="inline-block mb-6 px-4 py-2 rounded-full" style={{ background: '#E8F5F4' }}>
                <p className="text-sm font-semibold" style={{ color: '#38827A' }}>Todos tienen una historia</p>
              </div>
              <h1 className="text-5xl md:text-6xl lg:text-7xl font-bold mb-6 leading-tight" style={{ color: '#1F2937' }}>
                Todos tienen una historia.<br />
                <span style={{ color: '#4DB3A8' }}>Narra la tuya.</span>
              </h1>
              <p className="text-xl md:text-2xl mb-8 leading-relaxed" style={{ color: '#4B5563' }}>
                Convierte tus recuerdos en un legado. Narra te acompaña paso a paso para escribir, guardar y transformar tu vida en un libro que quedará para siempre.
              </p>

              <div className="flex flex-col sm:flex-row gap-4 justify-center lg:justify-start mb-8">
                <a
                  href="#comprar"
                  className="px-8 py-4 text-white rounded-xl font-bold text-lg shadow-xl hover:shadow-2xl transition-all transform hover:scale-105"
                  style={{ background: 'linear-gradient(135deg, #4DB3A8 0%, #38827A 100%)' }}
                  onClick={(e) => {
                    e.preventDefault();
                    scrollToSection(pricingRef);
                  }}
                >
                  Regala una historia
                </a>
                <a
                  href="/app"
                  className="px-8 py-4 bg-white rounded-xl font-bold text-lg shadow-lg hover:shadow-xl transition-all border-2"
                  style={{ color: '#4DB3A8', borderColor: '#4DB3A8' }}
                >
                  Iniciar sesión
                </a>
              </div>

              <p className="text-sm" style={{ color: '#9CA3AF' }}>
                Sin suscripción • Pago único de $300 MXN • Para toda la vida
              </p>
            </div>

            {/* Right: Hero Image */}
            <div className="relative">
              <div className="rounded-3xl overflow-hidden shadow-2xl">
                <img
                  src="https://images.unsplash.com/photo-1521791136064-7986c2920216?q=80&w=1600&auto=format&fit=crop"
                  alt="Adulto mayor escribiendo sus memorias"
                  className="w-full h-[500px] object-cover"
                />
              </div>
              {/* Floating card */}
              <div className="absolute -bottom-6 -left-6 bg-white rounded-2xl p-6 shadow-xl max-w-xs hidden lg:block">
                <div className="flex items-center gap-4">
                  <div className="w-12 h-12 rounded-full flex items-center justify-center text-2xl" style={{ background: '#E8F5F4' }}>
                    📖
                  </div>
                  <div>
                    <p className="font-bold" style={{ color: '#1F2937' }}>Tu legado familiar</p>
                    <p className="text-sm" style={{ color: '#6B7280' }}>Historias para siempre</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Para Quién Section - Dual Audience */}
      <section className="py-16 px-6 bg-white/60">
        <div className="max-w-7xl mx-auto">
          <h2 className="text-4xl md:text-5xl font-bold text-center mb-4" style={{ color: '#1F2937' }}>
            Para quien quiere dejar huella
          </h2>
          <p className="text-xl text-center mb-16 max-w-3xl mx-auto" style={{ color: '#4B5563' }}>
            Ya sea que quieras escribir tu propia historia o regalarle esta experiencia a alguien que amas
          </p>

          <div className="grid md:grid-cols-2 gap-8">
            {/* Para el Narrador */}
            <div className="bg-white rounded-3xl p-8 shadow-xl border-2" style={{ borderColor: '#E8F5F4' }}>
              <div className="w-16 h-16 rounded-2xl flex items-center justify-center text-3xl mb-6" style={{ background: '#E8F5F4' }}>
                ✍️
              </div>
              <h3 className="text-2xl font-bold mb-4" style={{ color: '#1F2937' }}>Para ti, que tienes historias que contar</h3>
              <p className="text-lg mb-6" style={{ color: '#4B5563' }}>
                Has vivido mucho. Tienes anécdotas, lecciones y momentos que merecen ser recordados. Narra te ayuda a plasmarlos de forma sencilla y hermosa.
              </p>
              <ul className="space-y-3">
                <BenefitItem text="Sencillo de usar, diseñado para ti" />
                <BenefitItem text="Escribe o dicta con tu voz" />
                <BenefitItem text="Asistente inteligente que te guía" />
                <BenefitItem text="Tu libro impreso cuando termines" />
              </ul>
            </div>

            {/* Para el Comprador */}
            <div className="bg-white rounded-3xl p-8 shadow-xl border-2" style={{ borderColor: '#E8F5F4' }}>
              <div className="w-16 h-16 rounded-2xl flex items-center justify-center text-3xl mb-6" style={{ background: '#E8F5F4' }}>
                💝
              </div>
              <h3 className="text-2xl font-bold mb-4" style={{ color: '#1F2937' }}>Para ti, que quieres preservar su legado</h3>
              <p className="text-lg mb-6" style={{ color: '#4B5563' }}>
                Las historias de tus padres o abuelos son un tesoro. Regálales Narra para que sus vivencias perduren y sean un regalo para toda la familia.
              </p>
              <ul className="space-y-3">
                <BenefitItem text="El regalo más significativo" />
                <BenefitItem text="Preserva historias familiares" />
                <BenefitItem text="Toda la familia puede leerlas" />
                <BenefitItem text="Un legado para generaciones" />
              </ul>
            </div>
          </div>
        </div>
      </section>

      {/* How It Works */}
      <section ref={howRef} className="py-20 px-6">
        <div className="max-w-7xl mx-auto">
          <h2 className="text-4xl md:text-5xl font-bold text-center mb-4" style={{ color: '#1F2937' }}>
            Cómo funciona
          </h2>
          <p className="text-xl text-center mb-16 max-w-3xl mx-auto" style={{ color: '#4B5563' }}>
            Narra te acompaña en cada paso para que escribir tus memorias sea fácil, natural y hermoso
          </p>

          <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-6">
            <HowStepCard
              number="1"
              icon="🎤"
              title="Habla o escribe"
              description="Cuenta tus recuerdos como prefieras: escribiendo o usando tu voz con transcripción automática"
              image="https://images.unsplash.com/photo-1516979187457-637abb4f9353?q=80&w=800&auto=format&fit=crop"
            />
            <HowStepCard
              number="2"
              icon="✨"
              title="La IA te ayuda"
              description="El Ghost Writer sugiere mejoras, organiza tus ideas y te hace preguntas para enriquecer tu historia"
              image="https://images.unsplash.com/photo-1485827404703-89b55fcc595e?q=80&w=800&auto=format&fit=crop"
            />
            <HowStepCard
              number="3"
              icon="📷"
              title="Añade recuerdos visuales"
              description="Sube fotos antiguas o recientes. Cada historia puede tener múltiples imágenes"
              image="https://images.unsplash.com/photo-1542601098-3adb3b1c255b?q=80&w=800&auto=format&fit=crop"
            />
            <HowStepCard
              number="4"
              icon="📖"
              title="Comparte y publica"
              description="Tus suscriptores reciben cada historia. Al completar 20, recibes tu libro impreso"
              image="https://images.unsplash.com/photo-1512820790803-83ca734da794?q=80&w=800&auto=format&fit=crop"
            />
          </div>
        </div>
      </section>

      {/* Emotional Legacy Section */}
      <section className="py-20 px-6 relative overflow-hidden" style={{ background: 'linear-gradient(135deg, #E8F5F4 0%, #ffffff 100%)' }}>
        <div className="max-w-7xl mx-auto">
          <div className="grid lg:grid-cols-2 gap-12 items-center">
            <div>
              <h2 className="text-4xl md:text-5xl font-bold mb-6 leading-tight" style={{ color: '#1F2937' }}>
                Tu historia es un regalo para quienes amas
              </h2>
              <p className="text-xl mb-6 leading-relaxed" style={{ color: '#4B5563' }}>
                No se trata solo de escribir. Se trata de dejar un pedacito de ti para quienes vengan después.
              </p>
              <p className="text-xl mb-8 leading-relaxed" style={{ color: '#4B5563' }}>
                Narra convierte tus memorias en algo tangible, hermoso y eterno. Un puente entre el pasado y el futuro. Entre tu vida y las generaciones que vienen.
              </p>

              <div className="space-y-4">
                <EmotionalBenefit
                  icon="💛"
                  text="Tus nietos conocerán tu historia, aunque no te hayan conocido"
                />
                <EmotionalBenefit
                  icon="🌳"
                  text="Tus valores y lecciones perdurarán en tu familia"
                />
                <EmotionalBenefit
                  icon="📚"
                  text="Tu libro será un tesoro familiar para siempre"
                />
                <EmotionalBenefit
                  icon="🕊️"
                  text="Tu voz permanecerá viva en cada palabra"
                />
              </div>
            </div>

            <div className="relative">
              <div className="rounded-3xl overflow-hidden shadow-2xl">
                <img
                  src="https://images.unsplash.com/photo-1516627145497-ae6968895b74?q=80&w=1600&auto=format&fit=crop"
                  alt="Familia compartiendo historias juntos"
                  className="w-full h-[600px] object-cover"
                />
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section ref={featuresRef} className="py-20 px-6 bg-white">
        <div className="max-w-7xl mx-auto">
          <h2 className="text-4xl md:text-5xl font-bold text-center mb-4" style={{ color: '#1F2937' }}>
            Todo lo que necesitas para crear tu legado
          </h2>
          <p className="text-xl text-center mb-16 max-w-3xl mx-auto" style={{ color: '#4B5563' }}>
            Narra incluye herramientas profesionales diseñadas con amor para preservar tus historias
          </p>

          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
            <FeatureCard
              icon="🎙️"
              title="Transcripción automática"
              description="Habla y Narra transcribe automáticamente. Perfecto para quienes prefieren contar sus historias en voz alta."
            />
            <FeatureCard
              icon="🤖"
              title="Ghost Writer con IA"
              description="Un asistente inteligente que mejora tu redacción, sugiere ideas y te hace preguntas para enriquecer cada historia."
            />
            <FeatureCard
              icon="💬"
              title="Sugerencias personalizadas"
              description="Recibe ideas y preguntas adaptadas a tu historia para que no te quedes sin saber qué escribir."
            />
            <FeatureCard
              icon="📝"
              title="Blog privado"
              description="Cada historia se publica en tu blog personal donde tus suscriptores pueden leer, comentar y reaccionar."
            />
            <FeatureCard
              icon="👥"
              title="Suscriptores ilimitados"
              description="Invita a toda tu familia. Cada suscriptor recibe notificaciones cuando publicas nuevas historias."
            />
            <FeatureCard
              icon="📖"
              title="Tu libro impreso"
              description="Al completar 20 historias, recibe automáticamente tu libro de memorias impreso y encuadernado."
            />
            <FeatureCard
              icon="📷"
              title="Galería de fotos"
              description="Añade múltiples fotos a cada historia. Tus recuerdos visuales dan vida a tus palabras."
            />
            <FeatureCard
              icon="🔒"
              title="Privado y seguro"
              description="Tus historias son 100% privadas. Solo las personas que invites pueden acceder a ellas."
            />
            <FeatureCard
              icon="♿"
              title="Accesible para todos"
              description="Diseño con letra grande, controles sencillos y pensado especialmente para personas mayores."
            />
          </div>
        </div>
      </section>

      {/* Testimonials */}
      <section ref={testimonialsRef} className="py-20 px-6" style={{ background: 'linear-gradient(135deg, #fdfbf7 0%, #f0ebe3 100%)' }}>
        <div className="max-w-7xl mx-auto">
          <h2 className="text-4xl md:text-5xl font-bold text-center mb-4" style={{ color: '#1F2937' }}>
            Cada vida guarda un libro dentro
          </h2>
          <p className="text-xl text-center mb-16 max-w-3xl mx-auto" style={{ color: '#4B5563' }}>
            Historias reales de familias que decidieron preservar su legado
          </p>

          <div className="grid md:grid-cols-3 gap-8">
            <TestimonialCard
              quote="Nunca pensé que escribir mi historia sería tan fácil. Ahora mis nietos leen cosas que ni mis hijos sabían. Es como si les estuviera hablando directamente."
              name="Carmen González"
              role="76 años, Abuela de 5 nietos"
              image="https://images.unsplash.com/photo-1574084497077-f72fdc385f0d?q=80&w=400&auto=format&fit=crop"
            />
            <TestimonialCard
              quote="Le regalé Narra a mi mamá por su cumpleaños. Cuando llegó su libro impreso, lloramos juntas. Es el regalo más valioso que le he dado."
              name="Patricia Ramírez"
              role="Hija y madre de familia"
              image="https://images.unsplash.com/photo-1544005313-94ddf0286df2?q=80&w=400&auto=format&fit=crop"
            />
            <TestimonialCard
              quote="Grabar mis recuerdos fue como volver a vivirlos. La IA me ayudó a recordar detalles que creí olvidados. Mis hijos ahora conocen mi historia completa."
              name="Roberto Silva"
              role="82 años, Veterano"
              image="https://images.unsplash.com/photo-1544723795-3fb6469f5b39?q=80&w=400&auto=format&fit=crop"
            />
          </div>
        </div>
      </section>

      {/* Pricing Section */}
      <section ref={pricingRef} className="py-20 px-6 bg-white">
        <div className="max-w-4xl mx-auto">
          <h2 className="text-4xl md:text-5xl font-bold text-center mb-4" style={{ color: '#1F2937' }}>
            Inversión única en tu legado
          </h2>
          <p className="text-xl text-center mb-12 max-w-2xl mx-auto" style={{ color: '#4B5563' }}>
            Sin mensualidades. Sin sorpresas. Un solo pago para toda la vida.
          </p>

          <div className="bg-white rounded-3xl p-10 shadow-2xl border-2 relative overflow-hidden" style={{ borderColor: '#4DB3A8' }}>
            {/* Badge "Mejor valor" */}
            <div className="absolute top-6 right-6 px-4 py-2 rounded-full text-white font-bold text-sm" style={{ background: '#38827A' }}>
              Mejor inversión para tu familia
            </div>

            <div className="text-center mb-8 mt-8">
              <p className="text-lg font-semibold mb-2" style={{ color: '#4DB3A8' }}>Pago único • Sin suscripciones</p>
              <div className="flex items-center justify-center gap-2 mb-2">
                <span className="text-7xl font-bold" style={{ color: '#4DB3A8' }}>$300</span>
                <span className="text-3xl font-bold" style={{ color: '#4B5563' }}>MXN</span>
              </div>
              <p className="text-lg" style={{ color: '#6B7280' }}>Pago único para siempre</p>
            </div>

            <div className="grid md:grid-cols-2 gap-4 mb-10">
              <PricingFeature text="Historias ilimitadas para toda la vida" />
              <PricingFeature text="Transcripción automática por voz" />
              <PricingFeature text="Ghost Writer con inteligencia artificial" />
              <PricingFeature text="Sugerencias personalizadas" />
              <PricingFeature text="Blog privado para tu familia" />
              <PricingFeature text="Suscriptores ilimitados" />
              <PricingFeature text="Galería de fotos en cada historia" />
              <PricingFeature text="Tu libro impreso al completar 20 historias" />
              <PricingFeature text="Notificaciones por email" />
              <PricingFeature text="100% privado y seguro" />
              <PricingFeature text="Actualizaciones y mejoras gratis" />
              <PricingFeature text="Soporte dedicado" />
            </div>

            <div className="space-y-4">
              <button
                className="w-full py-5 text-white rounded-2xl font-bold text-xl shadow-xl hover:shadow-2xl transition-all transform hover:scale-105"
                style={{ background: 'linear-gradient(135deg, #4DB3A8 0%, #38827A 100%)' }}
              >
                🎁 Comprar para regalar
              </button>
              <button
                className="w-full py-5 bg-white rounded-2xl font-bold text-xl shadow-lg hover:shadow-xl transition-all border-2"
                style={{ color: '#4DB3A8', borderColor: '#4DB3A8' }}
              >
                ✍️ Comprar para mí
              </button>
            </div>

            <p className="text-center mt-6 text-sm" style={{ color: '#9CA3AF' }}>
              Pago 100% seguro • Garantía de satisfacción
            </p>
          </div>

          {/* Trust indicators */}
          <div className="mt-12 flex flex-wrap justify-center gap-8 items-center opacity-70">
            <div className="flex items-center gap-2">
              <svg className="w-6 h-6" style={{ color: '#4DB3A8' }} fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M2.166 4.999A11.954 11.954 0 0010 1.944 11.954 11.954 0 0017.834 5c.11.65.166 1.32.166 2.001 0 5.225-3.34 9.67-8 11.317C5.34 16.67 2 12.225 2 7c0-.682.057-1.35.166-2.001zm11.541 3.708a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
              </svg>
              <span className="text-sm font-medium" style={{ color: '#4B5563' }}>Pago seguro</span>
            </div>
            <div className="flex items-center gap-2">
              <svg className="w-6 h-6" style={{ color: '#4DB3A8' }} fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
              </svg>
              <span className="text-sm font-medium" style={{ color: '#4B5563' }}>Sin cargos ocultos</span>
            </div>
            <div className="flex items-center gap-2">
              <svg className="w-6 h-6" style={{ color: '#4DB3A8' }} fill="currentColor" viewBox="0 0 20 20">
                <path d="M2.003 5.884L10 9.882l7.997-3.998A2 2 0 0016 4H4a2 2 0 00-1.997 1.884z" />
                <path d="M18 8.118l-8 4-8-4V14a2 2 0 002 2h12a2 2 0 002-2V8.118z" />
              </svg>
              <span className="text-sm font-medium" style={{ color: '#4B5563' }}>Soporte por email</span>
            </div>
          </div>
        </div>
      </section>

      {/* FAQ Section */}
      <section className="py-20 px-6" style={{ background: 'linear-gradient(135deg, #fdfbf7 0%, #f0ebe3 100%)' }}>
        <div className="max-w-4xl mx-auto">
          <h2 className="text-4xl md:text-5xl font-bold text-center mb-4" style={{ color: '#1F2937' }}>
            Preguntas frecuentes
          </h2>
          <p className="text-xl text-center mb-12" style={{ color: '#4B5563' }}>
            Todo lo que necesitas saber sobre Narra
          </p>

          <div className="space-y-4">
            <FaqItem
              question="¿Es realmente fácil de usar para personas mayores?"
              answer="Sí. Narra está diseñado específicamente pensando en personas mayores. Tiene letra grande, instrucciones claras paso a paso, y la opción de dictar por voz si no quieren escribir. Además, el Ghost Writer les ayuda con sugerencias."
            />
            <FaqItem
              question="¿Cómo funciona el libro impreso?"
              answer="Al completar 20 historias, automáticamente generamos tu libro de memorias personalizado, impreso y encuadernado profesionalmente. Lo enviamos directamente a tu domicilio sin costo adicional."
            />
            <FaqItem
              question="¿Qué es el Ghost Writer?"
              answer="Es un asistente de inteligencia artificial que te ayuda a mejorar tu redacción, te hace preguntas para enriquecer tus historias, y sugiere ideas. Es como tener un editor personal que respeta tu voz y estilo."
            />
            <FaqItem
              question="¿Quiénes pueden leer mis historias?"
              answer="Solo las personas que tú invites. Tú tienes control total sobre quién puede acceder a tu blog privado. Puedes agregar o quitar suscriptores cuando quieras."
            />
            <FaqItem
              question="¿Puedo usar fotos antiguas?"
              answer="Por supuesto. Puedes subir fotos antiguas escaneadas o tomar fotos de fotografías físicas con tu celular. Cada historia puede incluir múltiples imágenes."
            />
            <FaqItem
              question="¿Realmente no hay mensualidades?"
              answer="Correcto. Pagas $300 MXN una sola vez y tienes acceso de por vida a todas las funciones, sin límites. No hay cargos recurrentes ni sorpresas."
            />
            <FaqItem
              question="¿Cómo funciona si lo regalo?"
              answer="Al comprar, puedes elegir la opción 'Comprar para regalar'. Te ayudamos a configurar la cuenta para la persona que recibirá el regalo. Es el regalo más significativo que puedes dar."
            />
            <FaqItem
              question="¿Qué pasa con mis historias si algo me sucede?"
              answer="Tus historias y tu blog permanecen accesibles para tus suscriptores indefinidamente. Tu legado perdura para que las futuras generaciones siempre puedan conocer tu historia."
            />
          </div>
        </div>
      </section>

      {/* Final CTA Section */}
      <section className="py-24 px-6 bg-white relative overflow-hidden">
        <div className="absolute inset-0 opacity-5" style={{
          backgroundImage: 'url("https://images.unsplash.com/photo-1509909756405-ac7aa7e4a6b2?q=80&w=1600&auto=format&fit=crop")',
          backgroundSize: 'cover',
          backgroundPosition: 'center'
        }}></div>

        <div className="max-w-4xl mx-auto text-center relative z-10">
          <h2 className="text-5xl md:text-6xl font-bold mb-6 leading-tight" style={{ color: '#1F2937' }}>
            No dejes que tu historia se pierda
          </h2>
          <p className="text-2xl mb-4" style={{ color: '#4B5563' }}>
            Cada día que pasa, hay recuerdos que se desvanecen.
          </p>
          <p className="text-2xl mb-12" style={{ color: '#4B5563' }}>
            Empieza hoy. Narra te acompaña a convertir tus recuerdos en un legado.
          </p>

          <div className="flex flex-col sm:flex-row gap-6 justify-center mb-8">
            <button
              className="px-12 py-5 text-white rounded-2xl font-bold text-xl shadow-2xl hover:shadow-3xl transition-all transform hover:scale-105"
              style={{ background: 'linear-gradient(135deg, #4DB3A8 0%, #38827A 100%)' }}
            >
              Comienza tu historia ahora
            </button>
            <a
              href="/app"
              className="px-12 py-5 bg-white rounded-2xl font-bold text-xl shadow-xl hover:shadow-2xl transition-all border-2"
              style={{ color: '#4DB3A8', borderColor: '#4DB3A8' }}
            >
              Ya tengo cuenta
            </a>
          </div>

          <p className="text-sm" style={{ color: '#9CA3AF' }}>
            Solo $300 MXN • Pago único • Para toda la vida
          </p>
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
              <button className="text-gray-400 hover:text-white transition">
                Privacidad
              </button>
              <button className="text-gray-400 hover:text-white transition">
                Términos
              </button>
              <button className="text-gray-400 hover:text-white transition">
                Contacto
              </button>
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

// Helper Components

const HowStepCard: React.FC<{ number: string; icon: string; title: string; description: string; image: string }> =
  ({ number, icon, title, description, image }) => (
  <div className="bg-white rounded-2xl overflow-hidden shadow-xl hover:shadow-2xl transition-all">
    <div className="h-48 overflow-hidden">
      <img src={image} alt={title} className="w-full h-full object-cover" />
    </div>
    <div className="p-6">
      <div className="flex items-center gap-3 mb-4">
        <div className="w-10 h-10 rounded-full flex items-center justify-center font-bold text-white text-lg" style={{ background: '#4DB3A8' }}>
          {number}
        </div>
        <span className="text-3xl">{icon}</span>
      </div>
      <h3 className="text-xl font-bold mb-3" style={{ color: '#1F2937' }}>{title}</h3>
      <p style={{ color: '#4B5563' }}>{description}</p>
    </div>
  </div>
);

const BenefitItem: React.FC<{ text: string }> = ({ text }) => (
  <div className="flex items-center gap-3">
    <svg className="w-6 h-6 flex-shrink-0" style={{ color: '#4DB3A8' }} fill="currentColor" viewBox="0 0 20 20">
      <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
    </svg>
    <span className="text-lg" style={{ color: '#4B5563' }}>{text}</span>
  </div>
);

const EmotionalBenefit: React.FC<{ icon: string; text: string }> = ({ icon, text }) => (
  <div className="flex items-start gap-4 p-4 rounded-xl" style={{ background: '#ffffff' }}>
    <span className="text-3xl flex-shrink-0">{icon}</span>
    <p className="text-lg font-medium" style={{ color: '#1F2937' }}>{text}</p>
  </div>
);

const FeatureCard: React.FC<{ icon: string; title: string; description: string }> = ({ icon, title, description }) => (
  <div className="bg-white rounded-2xl p-6 shadow-lg hover:shadow-xl transition-all border" style={{ borderColor: '#E8F5F4' }}>
    <div className="w-14 h-14 rounded-xl flex items-center justify-center text-3xl mb-4" style={{ background: '#E8F5F4' }}>
      {icon}
    </div>
    <h3 className="text-xl font-bold mb-3" style={{ color: '#1F2937' }}>{title}</h3>
    <p style={{ color: '#4B5563' }}>{description}</p>
  </div>
);

const TestimonialCard: React.FC<{ quote: string; name: string; role: string; image: string }> =
  ({ quote, name, role, image }) => (
  <div className="bg-white rounded-2xl p-8 shadow-xl">
    <div className="flex items-center gap-4 mb-6">
      <img src={image} alt={name} className="w-16 h-16 rounded-full object-cover" />
      <div>
        <p className="font-bold text-lg" style={{ color: '#1F2937' }}>{name}</p>
        <p className="text-sm" style={{ color: '#6B7280' }}>{role}</p>
      </div>
    </div>
    <p className="text-lg italic leading-relaxed" style={{ color: '#4B5563' }}>
      "{quote}"
    </p>
  </div>
);

const PricingFeature: React.FC<{ text: string }> = ({ text }) => (
  <div className="flex items-start gap-3">
    <svg className="w-6 h-6 flex-shrink-0 mt-0.5" style={{ color: '#4DB3A8' }} fill="currentColor" viewBox="0 0 20 20">
      <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
    </svg>
    <span style={{ color: '#4B5563' }}>{text}</span>
  </div>
);

const FaqItem: React.FC<{ question: string; answer: string }> = ({ question, answer }) => (
  <div className="bg-white rounded-2xl p-8 shadow-lg hover:shadow-xl transition-all">
    <h3 className="font-bold text-xl mb-3" style={{ color: '#1F2937' }}>{question}</h3>
    <p className="text-lg leading-relaxed" style={{ color: '#4B5563' }}>{answer}</p>
  </div>
);
