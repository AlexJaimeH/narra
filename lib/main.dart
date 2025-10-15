import 'package:flutter/material.dart';
import 'package:narra/theme.dart';
import 'package:narra/theme_controller.dart';
import 'package:narra/screens/landing_page.dart';
import 'package:narra/screens/app/app_navigation.dart';
import 'package:narra/supabase/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
      home: const LandingPage(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/app':
            final initialIndex = settings.arguments is int
                ? settings.arguments as int
                : 0;
            return MaterialPageRoute(
              builder: (_) => AppNavigation(initialIndex: initialIndex),
              settings: settings,
            );
          case '/landing':
            return MaterialPageRoute(
              builder: (_) => const LandingPage(),
              settings: settings,
            );
          default:
            return null;
        }
      },
          ),
        );
      },
    );
  }
}
