import 'package:flutter/material.dart';
import 'package:narra/theme.dart';
import 'package:narra/screens/landing_page.dart';
import 'package:narra/screens/app/app_navigation.dart';
import 'package:narra/supabase/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar Supabase
  await SupabaseConfig.initialize();
  
  runApp(const NarraApp());
}

class NarraApp extends StatelessWidget {
  const NarraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Narra - (preview test)',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: const LandingPage(),
      routes: {
        '/app': (context) => const AppNavigation(),
        '/landing': (context) => const LandingPage(),
      },
    );
  }
}
