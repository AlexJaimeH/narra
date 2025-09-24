import 'package:flutter/material.dart';
import 'package:narra/screens/auth/login_page.dart';
import 'package:narra/screens/auth/register_page.dart';
import 'package:narra/supabase/supabase_config.dart';
import 'package:narra/theme.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _promiseSectionKey = GlobalKey();
  final _howItWorksKey = GlobalKey();
  final _pricingKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  void _checkAuthState() {
    if (SupabaseAuth.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/app');
      });
    }
  }

  void _navigateToAuth(bool isLogin) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            isLogin ? const LoginPage() : const RegisterPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 900;
          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LandingNavigationBar(
                    onLogin: () => _navigateToAuth(true),
                    onRegister: () => _navigateToAuth(false),
                    onBuy: () => _navigateToAuth(false),
                    isMobile: isMobile,
                    onGoToPromise: () => _scrollToKey(_promiseSectionKey),
                    onGoToHowItWorks: () => _scrollToKey(_howItWorksKey),
                    onGoToPricing: () => _scrollToKey(_pricingKey),
                  ),
                  _HeroSection(
                    isMobile: isMobile,
                    onRegister: () => _navigateToAuth(false),
                    onGift: () => _navigateToAuth(false),
                    onLogin: () => _navigateToAuth(true),
                  ),
                  const _TrustSignalsSection(),
                  _PromiseSection(key: _promiseSectionKey),
                  const _LegacyExperienceSection(),
                  _HowItWorksSection(key: _howItWorksKey),
                  const _TestimonialSection(),
                  _GiftSection(onRegister: () => _navigateToAuth(false)),
                  PricingSection(
                    key: _pricingKey,
                    onStartPressed: () => _navigateToAuth(false),
                  ),
                  _FinalCallToAction(
                    onRegister: () => _navigateToAuth(false),
                    onLogin: () => _navigateToAuth(true),
                  ),
                  _Footer(theme: theme),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _scrollToKey(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
    }
  }
}

class _LandingNavigationBar extends StatelessWidget {
  const _LandingNavigationBar({
    Key? key,
    required this.onLogin,
    required this.onRegister,
    required this.onBuy,
    required this.isMobile,
    required this.onGoToPromise,
    required this.onGoToHowItWorks,
    required this.onGoToPricing,
  }) : super(key: key);

  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final VoidCallback onBuy;
  final bool isMobile;
  final VoidCallback onGoToPromise;
  final VoidCallback onGoToHowItWorks;
  final VoidCallback onGoToPricing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 48,
        vertical: 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Row(
        children: [
          const _BrandMark(),
          const Spacer(),
          if (!isMobile) ...[
            TextButton(
              onPressed: onGoToPromise,
              child: const Text('Producto'),
            ),
            TextButton(
              onPressed: onGoToHowItWorks,
              child: const Text('Cómo funciona'),
            ),
            TextButton(
              onPressed: onGoToPricing,
              child: const Text('Planes'),
            ),
            const SizedBox(width: 16),
          ],
          TextButton(
            onPressed: onLogin,
            child: const Text('Iniciar sesión'),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: onRegister,
            style: FilledButton.styleFrom(
              backgroundColor: NarraColors.brandPrimarySolid,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999)),
            ),
            child: const Text('Crear cuenta'),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: onBuy,
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.secondary,
              side: BorderSide(color: theme.colorScheme.secondary),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999)),
            ),
            child: const Text('Regalar Narra'),
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Narra, memorias familiares preservadas',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  NarraColors.brandPrimarySolid,
                  NarraColors.brandSecondarySolid
                ],
              ),
            ),
            child: const Icon(Icons.auto_stories, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Text(
            'Narra',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.isMobile,
    required this.onRegister,
    required this.onGift,
    required this.onLogin,
  });

  final bool isMobile;
  final VoidCallback onRegister;
  final VoidCallback onGift;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin:
          EdgeInsets.symmetric(horizontal: isMobile ? 20 : 48, vertical: 24),
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 24 : 56, vertical: isMobile ? 48 : 72),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF103A3D), Color(0xFF1B4F52)],
        ),
        image: const DecorationImage(
          image: NetworkImage(
            'https://images.unsplash.com/photo-1492725764893-90b379c2b6e7?auto=format&fit=crop&w=1600&q=80',
          ),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Color(0xCC0B1E21), BlendMode.darken),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
            ),
            child: const Text(
              'Todo legado merece ser escuchado',
              style:
                  TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Cuenta tu historia con Narra',
            style: theme.textTheme.displayMedium?.copyWith(
              color: Colors.white,
              height: 1.2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: isMobile ? double.infinity : 480),
            child: Text(
              'Transforma vivencias en capítulos que tu familia podrá atesorar por generaciones. '
              'Narra combina IA cuidadosa con herramientas sencillas para escribir, grabar y regalar recuerdos.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.86),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: onRegister,
                icon: const Icon(Icons.favorite, color: Colors.white),
                label: const Text('Crear mi legado'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NarraColors.brandAccent,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                ),
              ),
              FilledButton.icon(
                onPressed: onGift,
                icon: const Icon(Icons.card_giftcard),
                label: const Text('Regalar Narra a mis padres'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                ),
              ),
              TextButton(
                onPressed: onLogin,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Ya tengo cuenta'),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 32,
            runSpacing: 16,
            children: const [
              _HeroStat(label: 'Familias conectadas', value: '12 400+'),
              _HeroStat(label: 'Historias narradas', value: '89 000'),
              _HeroStat(label: 'Idiomas disponibles', value: '5'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
          ),
        ],
      ),
    );
  }
}

class _TrustSignalsSection extends StatelessWidget {
  const _TrustSignalsSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 24,
        runSpacing: 16,
        children: [
          _TrustChip(
            icon: Icons.shield_moon_outlined,
            title: 'Privacidad ante todo',
            description: 'Tus historias solo se comparten con quienes elijas.',
          ),
          _TrustChip(
            icon: Icons.auto_awesome,
            title: 'IA con cuidado humano',
            description: 'Te acompañamos con sugerencias empáticas y seguras.',
          ),
          _TrustChip(
            icon: Icons.public,
            title: 'Listo en múltiples idiomas',
            description:
                'Inglés, español y más en camino para narrar sin límites.',
          ),
        ],
      ),
    );
  }
}

class _TrustChip extends StatelessWidget {
  const _TrustChip({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _PromiseSection extends StatelessWidget {
  const _PromiseSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Porque cada recuerdo merece un lugar seguro',
            style: theme.textTheme.headlineLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: const [
              _PromiseCard(
                icon: Icons.mic,
                title: 'Escribe o habla, Narra te escucha',
                description:
                    'Graba tu voz o escribe a tu ritmo. Nuestro asistente convierte tus palabras en capítulos listos para compartir.',
              ),
              _PromiseCard(
                icon: Icons.people_alt,
                title: 'Invita a tu círculo cercano',
                description:
                    'Comparte con hijos, nietos y amistades. Ellos reciben notificaciones cuando publiques nuevas memorias.',
              ),
              _PromiseCard(
                icon: Icons.emoji_emotions,
                title: 'Celebra momentos significativos',
                description:
                    'Añade fotos, dedicatorias y aprendizajes. Crea colecciones para cumpleaños, aniversarios o despedidas.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PromiseCard extends StatelessWidget {
  const _PromiseCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _LegacyExperienceSection extends StatelessWidget {
  const _LegacyExperienceSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 900;
          final textColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Un ritual semanal para reconectar',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF4D3626),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Narra propone pequeños recordatorios cada semana. Elige una pregunta, revive un momento, agrega fotos y deja un mensaje para quienes más quieres. '
                'Ellos recibirán una cápsula de memoria con tu voz y tus palabras.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF5F4635),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(Icons.check_circle, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Disponible en web, tableta y móvil sin instalar nada.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.check_circle, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Recordatorios automáticos y libros imprimibles listos en PDF.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
          );

          final image = ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
              aspectRatio: 4 / 5,
              child: Image.network(
                'https://images.unsplash.com/photo-1517849845537-4d257902454a?auto=format&fit=crop&w=900&q=80',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.black.withValues(alpha: 0.05),
                  alignment: Alignment.center,
                  child: const Icon(Icons.photo_library_outlined,
                      size: 48, color: Colors.black45),
                ),
              ),
            ),
          );

          return Container(
            padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 24 : 48, vertical: 40),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: const LinearGradient(
                colors: [Color(0xFFFAF4EB), Color(0xFFF0E6DC)],
              ),
            ),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      textColumn,
                      const SizedBox(height: 32),
                      image,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: textColumn),
                      const SizedBox(width: 40),
                      Expanded(flex: 4, child: image),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cómo Narra acompaña tus memorias',
            style: theme.textTheme.headlineLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 700;
              return Column(
                children: [
                  _ProcessStep(
                    step: '01',
                    title: 'Elige una pregunta significativa',
                    description:
                        'Te sugerimos temas y disparadores emocionales para que comenzar sea fácil. También puedes escribir tus propios capítulos.',
                    icon: Icons.menu_book,
                    isMobile: isMobile,
                  ),
                  _ProcessStep(
                    step: '02',
                    title: 'Escribe, dicta o sube tu voz',
                    description:
                        'La IA de Narra limpia tus audios, corrige errores y mantiene tu estilo. Añade fotos, videos cortos y ubicaciones.',
                    icon: Icons.mic_external_on,
                    isMobile: isMobile,
                  ),
                  _ProcessStep(
                    step: '03',
                    title: 'Comparte con quienes amas',
                    description:
                        'Invita por email o enlace privado. Tu familia recibe notificaciones y puede dejar reacciones o mensajes cariñosos.',
                    icon: Icons.family_restroom,
                    isMobile: isMobile,
                  ),
                  _ProcessStep(
                    step: '04',
                    title: 'Imprime o regala un libro digital',
                    description:
                        'Genera automáticamente un libro con diseño editorial listo para imprimir o proyectar en celebraciones.',
                    icon: Icons.auto_awesome_motion,
                    isMobile: isMobile,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProcessStep extends StatelessWidget {
  const _ProcessStep({
    required this.step,
    required this.title,
    required this.description,
    required this.icon,
    required this.isMobile,
  });

  final String step;
  final String title;
  final String description;
  final IconData icon;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Flex(
        direction: isMobile ? Axis.vertical : Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                step,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: isMobile ? 0 : 24, height: isMobile ? 16 : 0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TestimonialSection extends StatelessWidget {
  const _TestimonialSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Historias que ya están emocionando familias',
            style: theme.textTheme.headlineLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: const [
              _TestimonialCard(
                quote:
                    '“Narra me ayudó a conversar con mi abuelo sobre momentos que nunca había escuchado. Ahora tenemos un libro digital que comparte cada domingo con sus nietos.”',
                author: 'María, nieta orgullosa',
              ),
              _TestimonialCard(
                quote:
                    '“Escribir era difícil para mi mamá, pero pudo grabar sus relatos y la IA los dejó listos para leer. Fue el mejor regalo del Día de las Madres.”',
                author: 'Andrés, hijo mayor',
              ),
              _TestimonialCard(
                quote:
                    '“Guardar las recetas de la abuela con su voz es un tesoro. Narra nos dio un espacio seguro para reunir fotos, audios y dedicatorias.”',
                author: 'Familia Rojas',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  const _TestimonialCard({required this.quote, required this.author});

  final String quote;
  final String author;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote, color: theme.colorScheme.primary, size: 32),
          const SizedBox(height: 12),
          Text(
            quote,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
          ),
          const SizedBox(height: 16),
          Text(
            author,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _GiftSection extends StatelessWidget {
  const _GiftSection({required this.onRegister});

  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF0E2A30),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Regala Narra a quienes te regalaron sus historias',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Un obsequio que inspira conversaciones profundas. Incluye acceso para dos narradores, plantillas guiadas y un libro digital al completar 8 capítulos.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: onRegister,
                  icon: const Icon(Icons.card_giftcard, color: Colors.white),
                  label: const Text('Comprar tarjeta regalo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NarraColors.brandSecondarySolid,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                  ),
                ),
                TextButton(
                  onPressed: onRegister,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('Ver qué incluye el regalo'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PricingSection extends StatelessWidget {
  const PricingSection({Key? key, required this.onStartPressed})
      : super(key: key);

  final VoidCallback onStartPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Planes claros para comenzar hoy',
            style: theme.textTheme.headlineLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            'Paga una vez o suscríbete para acompañamiento continuo. Cada plan incluye soporte humano y IA responsable.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
          const SizedBox(height: 32),
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 900;
              return Wrap(
                spacing: 24,
                runSpacing: 24,
                children: [
                  _PlanCard(
                    title: 'Legado Personal',
                    price: '25€',
                    cadence: 'Pago único',
                    description:
                        'Ideal para comenzar tu propio archivo de memorias.',
                    features: const [
                      'Historias y fotos ilimitadas',
                      'Asistente de escritura y dictado',
                      'Libro digital descargable',
                    ],
                    highlight: false,
                    onSelect: onStartPressed,
                    isMobile: isMobile,
                  ),
                  _PlanCard(
                    title: 'Familia Cercana',
                    price: '12€',
                    cadence: 'al mes',
                    description:
                        'Para familias que desean co-crear un legado vivo.',
                    features: const [
                      'Hasta 4 narradores y 12 oyentes',
                      'Eventos privados y comentarios',
                      'Impresión anual incluida',
                      'Soporte prioritario',
                    ],
                    highlight: true,
                    onSelect: onStartPressed,
                    isMobile: isMobile,
                  ),
                  _PlanCard(
                    title: 'Regalo Premium',
                    price: '79€',
                    cadence: 'Kit completo',
                    description:
                        'Incluye tarjeta física, onboarding asistido y diseño editorial.',
                    features: const [
                      'Sesión de bienvenida guiada',
                      'Digitalización de álbumes (30 fotos)',
                      'Entrega de libro impreso en tapa dura',
                    ],
                    highlight: false,
                    onSelect: onStartPressed,
                    isMobile: isMobile,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.cadence,
    required this.description,
    required this.features,
    required this.highlight,
    required this.onSelect,
    required this.isMobile,
  });

  final String title;
  final String price;
  final String cadence;
  final String description;
  final List<String> features;
  final bool highlight;
  final VoidCallback onSelect;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: isMobile ? double.infinity : 280,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: highlight
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: highlight
              ? theme.colorScheme.primary
              : theme.colorScheme.outline.withValues(alpha: 0.2),
          width: highlight ? 2 : 1,
        ),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  blurRadius: 28,
                  offset: const Offset(0, 18),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 12),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: highlight
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
              if (highlight) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Más elegido',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: theme.textTheme.displaySmall?.copyWith(
                color: highlight
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
              children: [
                TextSpan(text: price),
                TextSpan(
                  text: ' · $cadence',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: highlight
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 20),
          Column(
            children: features
                .map(
                  (feature) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle,
                            color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            feature,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSelect,
              style: ElevatedButton.styleFrom(
                backgroundColor: highlight
                    ? theme.colorScheme.primary
                    : NarraColors.brandPrimarySolid,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Comenzar'),
            ),
          ),
          TextButton(
            onPressed: onSelect,
            child: const Text('Hablar con nuestro equipo'),
          ),
        ],
      ),
    );
  }
}

class _FinalCallToAction extends StatelessWidget {
  const _FinalCallToAction({required this.onRegister, required this.onLogin});

  final VoidCallback onRegister;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            colors: [Color(0xFF1B3637), Color(0xFF122224)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tu voz merece trascender',
              style: theme.textTheme.headlineLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Comienza hoy mismo a escribir, grabar y compartir los momentos que te definieron. '
              'Narra te acompaña paso a paso para que tu historia nunca se pierda.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: onRegister,
                  icon: const Icon(Icons.edit_rounded, color: Colors.white),
                  label: const Text('Crear cuenta gratuita'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NarraColors.brandAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 18),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: onLogin,
                  style: FilledButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 18),
                  ),
                  child: const Text('Acceder a mis capítulos'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.colorScheme.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BrandMark(),
          const SizedBox(height: 16),
          Text(
            'Narra es la forma más humana de preservar tus historias y compartirlas con quienes más amas.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 40,
            runSpacing: 12,
            children: [
              _FooterColumn(
                title: 'Producto',
                links: const ['Características', 'Cómo funciona', 'Planes'],
              ),
              _FooterColumn(
                title: 'Recursos',
                links: const [
                  'Preguntas frecuentes',
                  'Historias de clientes',
                  'Centro de ayuda'
                ],
              ),
              _FooterColumn(
                title: 'Legal',
                links: const ['Privacidad', 'Términos', 'Cookies'],
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            '© ${DateTime.now().year} Narra. Historias para siempre.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _FooterColumn extends StatelessWidget {
  const _FooterColumn({required this.title, required this.links});

  final String title;
  final List<String> links;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style:
              theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...links.map(
          (link) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
              child: Text(link),
            ),
          ),
        ),
      ],
    );
  }
}
