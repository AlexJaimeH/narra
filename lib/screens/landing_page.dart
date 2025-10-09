import 'package:flutter/material.dart';
import 'package:narra/screens/auth/login_page.dart';
import 'package:narra/screens/auth/register_page.dart';
import 'package:narra/supabase/supabase_config.dart';

const String kHeroSubtitle =
    'Escribe tu historia. Regálala para siempre a quienes amas.';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key}); // ← vuelve a const
  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _scrollController = ScrollController();

  final GlobalKey _howKey = GlobalKey();
  final GlobalKey _featuresKey = GlobalKey();
  final GlobalKey _testimonialsKey = GlobalKey();
  final GlobalKey _pricingKey = GlobalKey();
  final GlobalKey _faqKey = GlobalKey();

  bool _isScrolled = false;
  bool _isMenuOpen = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _checkAuthState();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final hasScrolled = _scrollController.positions.isNotEmpty
        ? _scrollController.offset > 12
        : false;
    if (hasScrolled != _isScrolled) {
      setState(() {
        _isScrolled = hasScrolled;
      });
    }
    if (_isMenuOpen && hasScrolled) {
      setState(() {
        _isMenuOpen = false;
      });
    }
  }

  void _checkAuthState() {
    // Si ya está autenticado, redirigir a la app
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

  void _scrollTo(GlobalKey key) {
    final contextForKey = key.currentContext;
    if (contextForKey != null) {
      Scrollable.ensureVisible(
        contextForKey,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
    }
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
    });
  }

  void _closeMenu() {
    if (_isMenuOpen) {
      setState(() {
        _isMenuOpen = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 120),

                // Hero
                _HeroSection(
                  onBuy: () {
                    _closeMenu();
                    _navigateToAuth(false);
                  },
                  onExplore: () {
                    _closeMenu();
                    _scrollTo(_howKey);
                  },
                  onLogin: () {
                    _closeMenu();
                    _navigateToAuth(true);
                  },
                ),

                // Social proof
                const _SocialProofBar(),

                // How it Works Section
                KeyedSubtree(key: _howKey, child: const HowItWorksSection()),

                // Emotional statement section
                const _EmotionalSection(),

                // Features Section
                KeyedSubtree(key: _featuresKey, child: const FeaturesSection()),

                // Testimonials
                KeyedSubtree(
                    key: _testimonialsKey, child: const _TestimonialsSection()),

                // Pricing Section
                KeyedSubtree(
                  key: _pricingKey,
                  child: PricingSection(onStartPressed: () {
                    _closeMenu();
                    _navigateToAuth(false);
                  }),
                ),

                // FAQ
                KeyedSubtree(key: _faqKey, child: const _FaqSection()),

                // Footer
                Container(
                  padding: const EdgeInsets.all(24),
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  child: Column(
                    children: [
                      Text(
                        'Narra',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Historias que perduran para siempre',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 16,
                        runSpacing: 8,
                        children: const [
                          Text('Privacidad'),
                          Text('Términos'),
                          Text('Cookies'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '© 2025 Narra. Todos los derechos reservados.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _LandingHeader(
            isScrolled: _isScrolled,
            isMenuOpen: _isMenuOpen,
            onMenuToggle: _toggleMenu,
            onHow: () {
              _closeMenu();
              _scrollTo(_howKey);
            },
            onFeatures: () {
              _closeMenu();
              _scrollTo(_featuresKey);
            },
            onTestimonials: () {
              _closeMenu();
              _scrollTo(_testimonialsKey);
            },
            onPricing: () {
              _closeMenu();
              _scrollTo(_pricingKey);
            },
            onFaq: () {
              _closeMenu();
              _scrollTo(_faqKey);
            },
            onLogin: () {
              _closeMenu();
              _navigateToAuth(true);
            },
            onRegister: () {
              _closeMenu();
              _navigateToAuth(false);
            },
            onBuy: () {
              _closeMenu();
              _navigateToAuth(false);
            },
          ),
        ],
      ),
    );
  }
}

class _LandingHeader extends StatelessWidget {
  final bool isScrolled;
  final bool isMenuOpen;
  final VoidCallback onMenuToggle;
  final VoidCallback onHow;
  final VoidCallback onFeatures;
  final VoidCallback onTestimonials;
  final VoidCallback onPricing;
  final VoidCallback onFaq;
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final VoidCallback onBuy;

  const _LandingHeader({
    required this.isScrolled,
    required this.isMenuOpen,
    required this.onMenuToggle,
    required this.onHow,
    required this.onFeatures,
    required this.onTestimonials,
    required this.onPricing,
    required this.onFaq,
    required this.onLogin,
    required this.onRegister,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final menuItems = [
      _NavItemData(label: 'Cómo funciona', onTap: onHow),
      _NavItemData(label: 'Características', onTap: onFeatures),
      _NavItemData(label: 'Testimonios', onTap: onTestimonials),
      _NavItemData(label: 'Precio', onTap: onPricing),
      _NavItemData(label: 'FAQ', onTap: onFaq),
    ];

    return SafeArea(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isScrolled || isMenuOpen
              ? theme.colorScheme.surface.withValues(alpha: 0.98)
              : theme.colorScheme.surface.withValues(alpha: 0.88),
          boxShadow: (isScrolled || isMenuOpen)
              ? [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ]
              : null,
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outlineVariant
                  .withValues(alpha: isScrolled ? 1 : 0.3),
              width: 1,
            ),
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 920;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _BrandMark(theme: theme),
                        const Spacer(),
                        if (!isCompact)
                          Row(
                            children: [
                              for (final item in menuItems)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: _AnimatedNavLink(
                                      label: item.label, onTap: item.onTap),
                                ),
                            ],
                          ),
                        const SizedBox(width: 12),
                        if (!isCompact)
                          Row(
                            children: [
                              TextButton(
                                onPressed: onLogin,
                                child: const Text('Iniciar sesión'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: onRegister,
                                child: const Text('Registrarse'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: onBuy,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.favorite,
                                        size: 18, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text('Comprar'),
                                  ],
                                ),
                              ),
                            ],
                          )
                        else
                          _AnimatedMenuButton(
                            isOpen: isMenuOpen,
                            onPressed: onMenuToggle,
                          ),
                      ],
                    ),
                    if (isCompact)
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: 0,
                          end: isMenuOpen ? 1 : 0,
                        ),
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeInOut,
                        builder: (context, value, child) {
                          return ClipRect(
                            child: Align(
                              heightFactor: value,
                              alignment: Alignment.topCenter,
                              child: Opacity(
                                opacity: value.clamp(0, 1).toDouble(),
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final item in menuItems)
                                  _MobileMenuItem(
                                    label: item.label,
                                    onTap: item.onTap,
                                  ),
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      OutlinedButton(
                                        onPressed: onLogin,
                                        child: const Text('Iniciar sesión'),
                                      ),
                                      const SizedBox(height: 12),
                                      FilledButton(
                                        onPressed: onRegister,
                                        child:
                                            const Text('Crear cuenta gratuita'),
                                      ),
                                      const SizedBox(height: 12),
                                      ElevatedButton.icon(
                                        onPressed: onBuy,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              theme.colorScheme.primary,
                                          foregroundColor:
                                              theme.colorScheme.onPrimary,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 16),
                                        ),
                                        icon: const Icon(Icons.card_giftcard,
                                            size: 18),
                                        label: const Text('Regalar Narra'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final String label;
  final VoidCallback onTap;

  const _NavItemData({required this.label, required this.onTap});
}

class _BrandMark extends StatelessWidget {
  final ThemeData theme;

  const _BrandMark({required this.theme});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primaryContainer,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.auto_stories, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Text(
            'Narra',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedNavLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _AnimatedNavLink({required this.label, required this.onTap});

  @override
  State<_AnimatedNavLink> createState() => _AnimatedNavLinkState();
}

class _AnimatedNavLinkState extends State<_AnimatedNavLink> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _hovering
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(top: 6),
                height: 2,
                width: _hovering ? 24 : 0,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedMenuButton extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onPressed;

  const _AnimatedMenuButton({
    required this.isOpen,
    required this.onPressed,
  });

  @override
  State<_AnimatedMenuButton> createState() => _AnimatedMenuButtonState();
}

class _AnimatedMenuButtonState extends State<_AnimatedMenuButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    if (widget.isOpen) {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedMenuButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen != oldWidget.isOpen) {
      if (widget.isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: widget.onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: AnimatedIcon(
            icon: AnimatedIcons.menu_close,
            progress: _controller,
            size: 26,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _MobileMenuItem extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _MobileMenuItem({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final VoidCallback onBuy;
  final VoidCallback onExplore;
  final VoidCallback onLogin;

  const _HeroSection({
    super.key,
    required this.onBuy,
    required this.onExplore,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            Theme.of(context).colorScheme.surface,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isNarrow = constraints.maxWidth < 900;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Title
              Text(
                'Tu vida es un legado',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                kHeroSubtitle,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: onBuy,
                    icon: const Icon(Icons.card_giftcard, color: Colors.white),
                    label: const Text('Comprar para un ser querido'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onExplore,
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Cómo funciona'),
                  ),
                  TextButton(
                    onPressed: onLogin,
                    child: const Text('Ya tengo cuenta'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Visual
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  'https://images.unsplash.com/photo-1543269865-cbf427effbad?q=80&w=1600&auto=format&fit=crop',
                  height: isNarrow ? 220 : 360,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: isNarrow ? 220 : 360,
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: const Icon(Icons.image, size: 64),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SocialProofBar extends StatelessWidget {
  const _SocialProofBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 24,
        runSpacing: 12,
        children: [
          _ProofItem(icon: Icons.star, text: 'Calificación 4.9/5'),
          _ProofItem(icon: Icons.groups, text: '1000+ familias inspiradas'),
          _ProofItem(icon: Icons.lock, text: 'Privado y seguro'),
          _ProofItem(icon: Icons.schedule, text: 'En 10 minutos por semana'),
        ],
      ),
    );
  }
}

class _ProofItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ProofItem({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _EmotionalSection extends StatelessWidget {
  const _EmotionalSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Column(
        children: [
          Text(
            'Porque tu voz importa',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Narra te acompaña para guardar anécdotas, fotos y aprendizajes. Un regalo de amor para tus hijos y nietos — una biblioteca hecha de recuerdos auténticos.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TestimonialsSection extends StatelessWidget {
  const _TestimonialsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Testimonios',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 900;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: const [
                  _TestimonialCard(
                    quote:
                        '“Mi madre escribió su infancia. Hoy mis hijos la leen con una sonrisa.”',
                    name: 'Lucía, 38',
                    relation: 'Hija',
                    avatarUrl:
                        'https://images.unsplash.com/photo-1517841905240-472988babdf9?q=80&w=300&auto=format&fit=crop',
                  ),
                  _TestimonialCard(
                    quote:
                        '“Nunca pensé que escribiría. Con Narra fue fácil y hermoso.”',
                    name: 'Jorge, 72',
                    relation: 'Abuelo',
                    avatarUrl:
                        'https://images.unsplash.com/photo-1544006659-f0b21884ce1d?q=80&w=300&auto=format&fit=crop',
                  ),
                  _TestimonialCard(
                    quote: '“Es el mejor regalo que nos hicimos como familia.”',
                    name: 'María, 45',
                    relation: 'Madre',
                    avatarUrl:
                        'https://images.unsplash.com/photo-1556157382-97eda2d62296?q=80&w=300&auto=format&fit=crop',
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

class _TestimonialCard extends StatelessWidget {
  final String quote;
  final String name;
  final String relation;
  final String avatarUrl;

  const _TestimonialCard({
    super.key,
    required this.quote,
    required this.name,
    required this.relation,
    required this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: NetworkImage(avatarUrl),
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(relation,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                quote,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqSection extends StatelessWidget {
  const _FaqSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('Preguntas frecuentes',
              style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 16),
          const _FaqItem(
            q: '¿Es difícil escribir mis historias?',
            a: 'No. Te guiamos con preguntas sencillas y puedes dictar por voz.',
          ),
          const _FaqItem(
            q: '¿Quién puede leer mis historias?',
            a: 'Tú decides. Las historias son privadas y solo accede quien invites.',
          ),
          const _FaqItem(
            q: '¿Cuánto cuesta?',
            a: 'Un pago único de 25€ para desbloquear todas las funciones.',
          ),
          const _FaqItem(
            q: '¿Puedo regalar Narra?',
            a: 'Sí. Usa “Comprar para un ser querido” y te guiamos en el proceso.',
          ),
        ],
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  final String q;
  final String a;

  const _FaqItem({super.key, required this.q, required this.a});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(q,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(a, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class HowItWorksSection extends StatelessWidget {
  const HowItWorksSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            '¿Cómo funciona?',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 32),
          const Row(
            children: [
              Expanded(
                  child: StepCard(
                number: '1',
                icon: Icons.edit,
                title: 'Escribe o dicta',
                description: 'Cuenta tus historias escribiendo o usando tu voz',
              )),
              SizedBox(width: 16),
              Expanded(
                  child: StepCard(
                number: '2',
                icon: Icons.photo_library,
                title: 'Añade fotos',
                description: 'Incluye hasta 8 fotos en cada historia',
              )),
            ],
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(
                  child: StepCard(
                number: '3',
                icon: Icons.auto_awesome,
                title: 'IA te ayuda',
                description: 'Sugerencias y mejoras automáticas del texto',
              )),
              SizedBox(width: 16),
              Expanded(
                  child: StepCard(
                number: '4',
                icon: Icons.share,
                title: 'Comparte',
                description: 'Tu familia recibe las historias por email',
              )),
            ],
          ),
        ],
      ),
    );
  }
}

class StepCard extends StatelessWidget {
  final String number;
  final IconData icon;
  final String title;
  final String description;

  const StepCard({
    super.key,
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  number,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Icon(
              icon,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class FeaturesSection extends StatelessWidget {
  const FeaturesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Column(
        children: [
          Text(
            'Características',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 24),
          const FeatureCard(
            icon: Icons.accessibility,
            title: 'Accesible',
            description:
                'Letra grande, dictado por voz, y diseño pensado para personas mayores',
          ),
          const SizedBox(height: 16),
          const FeatureCard(
            icon: Icons.auto_awesome,
            title: 'Asistente IA',
            description:
                'Te ayuda con preguntas, mejora tu texto y verifica que tu historia esté completa',
          ),
          const SizedBox(height: 16),
          const FeatureCard(
            icon: Icons.lock,
            title: 'Privacidad',
            description:
                'Tus historias son privadas. Solo las personas que invites pueden leerlas',
          ),
          const SizedBox(height: 16),
          const FeatureCard(
            icon: Icons.book,
            title: 'Libro personalizado',
            description:
                'Con 8 o más historias, creamos automáticamente tu libro de memorias',
          ),
        ],
      ),
    );
  }
}

class FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 28,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PricingSection extends StatelessWidget {
  final VoidCallback onStartPressed;

  const PricingSection({super.key, required this.onStartPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            'Precio',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'Pago único',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      style:
                          Theme.of(context).textTheme.displayMedium?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                      children: const [
                        TextSpan(text: '25'),
                        TextSpan(
                          text: '€',
                          style: TextStyle(fontSize: 24),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    children: [
                      _buildPricingFeature(
                          context, '✓', 'Historias ilimitadas'),
                      _buildPricingFeature(
                          context, '✓', 'Fotos en cada historia'),
                      _buildPricingFeature(context, '✓', 'Asistente de IA'),
                      _buildPricingFeature(context, '✓', 'Dictado por voz'),
                      _buildPricingFeature(context, '✓', 'Libro automático'),
                      _buildPricingFeature(
                          context, '✓', 'Suscriptores ilimitados'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onStartPressed,
                      child: const Text('Comprar ahora'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingFeature(
      BuildContext context, String checkmark, String feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            checkmark,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              feature,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
