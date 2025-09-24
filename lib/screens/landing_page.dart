import 'package:flutter/material.dart';
import 'package:narra/screens/auth/login_page.dart';
import 'package:narra/screens/auth/register_page.dart';
import 'package:narra/supabase/supabase_config.dart';
const String kHeroSubtitle =
    'Comparte tus historias de vida con tu familia y amigos';

class LandingPage extends StatefulWidget {
LandingPage({super.key});
  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
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
        builder: (context) => isLogin ? const LoginPage() : const RegisterPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero Section
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  // Logo and Title
                  Text(
                    'Narra',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Comparte tus historias de vida con tu familia',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // Hero Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      'https://pixabay.com/get/gad86189039735b8b0f93e0900e5585200a5b1d97f08f25d52cad4e8842488a528a8ec4d3ef56857739c83f8c236e1ee67e299745e75def46ecd82d4fdcb7a43e_1280.jpg',
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 200,
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: const Icon(Icons.image, size: 64),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // CTA Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _navigateToAuth(false),
                          icon: const Icon(Icons.edit, color: Colors.white),
                          label: const Text('Empezar Gratis'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _navigateToAuth(true),
                          icon: const Icon(Icons.login),
                          label: const Text('Iniciar Sesión'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.visibility),
                    label: const Text('Ver historias de ejemplo'),
                  ),
                ],
              ),
            ),
            // How it Works Section
            const HowItWorksSection(),
            // Features Section
            const FeaturesSection(),
            // Pricing Section
            PricingSection(onStartPressed: () => _navigateToAuth(false)),
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
                  Text(
                    '© 2024 Narra. Todos los derechos reservados.',
                    style: Theme.of(context).textTheme.bodySmall,
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
              Expanded(child: StepCard(
                number: '1',
                icon: Icons.edit,
                title: 'Escribe o dicta',
                description: 'Cuenta tus historias escribiendo o usando tu voz',
              )),
              SizedBox(width: 16),
              Expanded(child: StepCard(
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
              Expanded(child: StepCard(
                number: '3',
                icon: Icons.auto_awesome,
                title: 'IA te ayuda',
                description: 'Sugerencias y mejoras automáticas del texto',
              )),
              SizedBox(width: 16),
              Expanded(child: StepCard(
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
            description: 'Letra grande, dictado por voz, y diseño pensado para personas mayores',
          ),
          const SizedBox(height: 16),
          const FeatureCard(
            icon: Icons.auto_awesome,
            title: 'Asistente IA',
            description: 'Te ayuda con preguntas, mejora tu texto y verifica que tu historia esté completa',
          ),
          const SizedBox(height: 16),
          const FeatureCard(
            icon: Icons.lock,
            title: 'Privacidad',
            description: 'Tus historias son privadas. Solo las personas que invites pueden leerlas',
          ),
          const SizedBox(height: 16),
          const FeatureCard(
            icon: Icons.book,
            title: 'Libro personalizado',
            description: 'Con 8 o más historias, creamos automáticamente tu libro de memorias',
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
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
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
                      _buildPricingFeature(context, '✓', 'Historias ilimitadas'),
                      _buildPricingFeature(context, '✓', 'Fotos en cada historia'),
                      _buildPricingFeature(context, '✓', 'Asistente de IA'),
                      _buildPricingFeature(context, '✓', 'Dictado por voz'),
                      _buildPricingFeature(context, '✓', 'Libro automático'),
                      _buildPricingFeature(context, '✓', 'Suscriptores ilimitados'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onStartPressed,
                      child: const Text('Empezar ahora'),
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

  Widget _buildPricingFeature(BuildContext context, String checkmark, String feature) {
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
