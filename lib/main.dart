import 'package:flutter/material.dart';
import 'package:narra/theme_controller.dart';
import 'package:narra/screens/landing_page.dart';
import 'package:narra/screens/app/app_navigation.dart';
import 'package:narra/repositories/story_repository.dart';
import 'package:narra/screens/public/story_blog_page.dart';
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
        final routeName = settings.name;

        if (routeName != null) {
          final uri = Uri.tryParse(routeName);
          if (uri != null && uri.pathSegments.isNotEmpty) {
            final firstSegment = uri.pathSegments.first;
            if (firstSegment == 'story' && uri.pathSegments.length >= 2) {
              final storyId = uri.pathSegments[1];
              Story? initialStory;
              StorySharePayload? sharePayload;

              if (settings.arguments is StoryBlogPageArguments) {
                final args = settings.arguments as StoryBlogPageArguments;
                initialStory = args.story;
                sharePayload = args.share;
              }

              sharePayload ??= StorySharePayload.fromUri(uri);

              return MaterialPageRoute(
                builder: (_) => StoryBlogPage(
                  storyId: storyId,
                  initialStory: initialStory,
                  initialShare: sharePayload,
                ),
                settings: settings,
              );
            }
          }

          switch (routeName) {
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
          }
        }
        return null;
      },
          ),
        );
      },
    );
  }
}
