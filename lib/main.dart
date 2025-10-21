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
