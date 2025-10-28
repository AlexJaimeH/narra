import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:narra/repositories/story_repository.dart';
import 'package:narra/screens/app/app_navigation.dart';
import 'package:narra/screens/landing_page.dart';
import 'package:narra/screens/public/story_blog_page.dart';
import 'package:narra/screens/public/subscriber_welcome_page.dart';
import 'package:narra/supabase/supabase_config.dart';
import 'package:narra/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    usePathUrlStrategy();

    // Check if we're on a /blog/* route - these should be handled by React, not Flutter
    final currentPath = Uri.base.path;
    if (currentPath.startsWith('/blog/')) {
      // Force reload so Cloudflare Pages can serve the React blog
      runApp(const _BlogRedirectWidget());
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
              final routeName = settings.name ?? '/';

              // Ignore /blog/* routes - these are handled by React app
              if (routeName.startsWith('/blog/')) {
                return null;
              }

              Uri? uri = Uri.tryParse(routeName);
              final baseUri = Uri.base;
              final isDefaultRoute = routeName == '/' || routeName.isEmpty;

              if ((uri == null || uri.pathSegments.isEmpty) && isDefaultRoute) {
                if (baseUri.pathSegments.isNotEmpty) {
                  final first = baseUri.pathSegments.first;
                  if (first == 'story' || first == 'subscriber') {
                    uri = Uri(
                      pathSegments: baseUri.pathSegments,
                      queryParameters: baseUri.queryParameters.isEmpty
                          ? null
                          : baseUri.queryParameters,
                    );
                  }
                }

                if ((uri == null || uri.pathSegments.isEmpty) &&
                    baseUri.hasFragment &&
                    baseUri.fragment.isNotEmpty) {
                  final fragment = baseUri.fragment.startsWith('/')
                      ? baseUri.fragment
                      : '/${baseUri.fragment}';
                  uri = Uri.tryParse(fragment);
                }
              }

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
                } else if (firstSegment == 'subscriber' &&
                    uri.pathSegments.length >= 2) {
                  final subscriberId = uri.pathSegments[1];

                  return MaterialPageRoute(
                    builder: (_) => SubscriberWelcomePage(
                      subscriberId: subscriberId,
                    ),
                    settings: settings,
                  );
                }
              }

              switch (routeName) {
                case '/':
                case '/landing':
                  return MaterialPageRoute(
                    builder: (_) => const LandingPage(),
                    settings: settings,
                  );
                case '/app':
                  final initialIndex =
                      settings.arguments is int ? settings.arguments as int : 0;
                  return MaterialPageRoute(
                    builder: (_) => AppNavigation(initialIndex: initialIndex),
                    settings: settings,
                  );
              }

              return MaterialPageRoute(
                builder: (_) => const LandingPage(),
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
  final baseUri = Uri.base;
  final fromPath = _extractDeepLinkRoute(baseUri);
  if (fromPath != null) {
    return fromPath;
  }

  final fragment = baseUri.hasFragment ? baseUri.fragment : '';
  if (fragment.isNotEmpty) {
    final normalizedFragment =
        fragment.startsWith('/') ? fragment : '/$fragment';
    final fragmentUri = Uri.tryParse(normalizedFragment);
    final fromFragment =
        fragmentUri != null ? _extractDeepLinkRoute(fragmentUri) : null;
    if (fromFragment != null) {
      return fromFragment;
    }
  }

  final defaultRouteName =
      WidgetsBinding.instance.platformDispatcher.defaultRouteName;
  if (defaultRouteName.isNotEmpty && defaultRouteName != '/') {
    final normalized = defaultRouteName.startsWith('/')
        ? defaultRouteName
        : '/$defaultRouteName';
    final defaultUri = Uri.tryParse(normalized);
    final fromDefault =
        defaultUri != null ? _extractDeepLinkRoute(defaultUri) : null;
    if (fromDefault != null) {
      return fromDefault;
    }

    if (normalized == '/app' || normalized == '/landing') {
      return normalized;
    }
  }

  return '/';
}

String? _extractDeepLinkRoute(Uri uri) {
  if (uri.pathSegments.isEmpty) {
    return null;
  }

  final first = uri.pathSegments.first;
  if (first == 'story' && uri.pathSegments.length >= 2) {
    final storyId = uri.pathSegments[1];
    if (storyId.isNotEmpty) {
      return '/story/$storyId';
    }
  }

  if (first == 'subscriber' && uri.pathSegments.length >= 2) {
    final subscriberId = uri.pathSegments[1];
    if (subscriberId.isNotEmpty) {
      return '/subscriber/$subscriberId';
    }
  }

  return null;
}

/// Lightweight widget shown when accessing /blog/* routes
/// This prevents Flutter from loading and allows Cloudflare Pages to serve the React blog
class _BlogRedirectWidget extends StatelessWidget {
  const _BlogRedirectWidget();

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
                'Cargando blog...',
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
