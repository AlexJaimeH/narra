import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:narra/screens/app/app_navigation.dart';
import 'package:narra/supabase/supabase_config.dart';
import 'package:narra/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    usePathUrlStrategy();

    // Flutter ONLY handles /app/* routes
    // All other routes (/, /blog/*) are handled by React
    final currentPath = Uri.base.path;
    if (!currentPath.startsWith('/app')) {
      // Not an app route - redirect to let React handle it
      runApp(const _ReactRedirectWidget());
      return;
    }
  }

  // Inicializar Supabase
  try {
    await SupabaseConfig.initialize();
  } catch (_) {
    // Evitar pantalla en blanco si faltan envs en preview; la app pública puede funcionar sin sesión
  }

  runApp(const NarraApp());
}

class NarraApp extends StatelessWidget {
  const NarraApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeController.instance..loadInitialFromSupabase();

    return AnimatedBuilder(
      animation: themeController,
      builder: (context, child) {
        // Aplicar escala de texto global
        final scaled = MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(themeController.textScale),
        );
        return MediaQuery(
          data: scaled,
          child: MaterialApp(
            title: 'Narra',
            debugShowCheckedModeBanner: false,
            theme: themeController.light,
            darkTheme: themeController.dark,
            themeMode: ThemeMode.system,
            initialRoute: _resolveInitialRoute(),
            onGenerateRoute: (settings) {
              final routeName = settings.name ?? '/app';

              // Flutter ONLY handles /app/* routes
              // All other routes are handled by React

              switch (routeName) {
                case '/app':
                  final initialIndex =
                      settings.arguments is int ? settings.arguments as int : 0;
                  return MaterialPageRoute(
                    builder: (_) => AppNavigation(initialIndex: initialIndex),
                    settings: settings,
                  );
              }

              // Default to app navigation
              return MaterialPageRoute(
                builder: (_) => AppNavigation(initialIndex: 0),
                settings: settings,
              );
            },
          ),
        );
      },
    );
  }
}

String _resolveInitialRoute() {
  // Flutter only handles /app/* routes
  // This function should always return '/app' since we've already
  // filtered out non-app routes in main()
  return '/app';
}

/// Lightweight widget shown when accessing non-/app routes (/, /blog/*)
/// This prevents Flutter from loading and allows Cloudflare Pages to serve the React app
class _ReactRedirectWidget extends StatelessWidget {
  const _ReactRedirectWidget();

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // Use a post-frame callback to reload the page
      // This ensures the widget tree is built before reloading
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Reload the page to let Cloudflare Pages serve the React blog
        // ignore: avoid_web_libraries_in_flutter
        if (kIsWeb) {
          // Force reload via JavaScript
          // This is safe because we're on web and specifically handling /blog/* routes
          final uri = Uri.base;
          final url = uri.toString();
          // Use replace to avoid adding to history
          // ignore: unsafe_html
          html.window.location.replace(url);
        }
      });
    }

    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4DB3A8)),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Cargando...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
