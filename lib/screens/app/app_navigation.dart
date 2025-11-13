import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:narra/supabase/supabase_config.dart';
import 'dashboard_page.dart';
import 'dashboard_walkthrough_controller.dart';
import 'stories_list_page.dart';
import 'subscribers_page.dart';
import 'settings_page.dart';
import 'story_editor_page.dart';
import 'top_navigation_bar.dart';

class AppNavigation extends StatefulWidget {
  const AppNavigation({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<AppNavigation> createState() => _AppNavigationState();
}

class _AppNavigationState extends State<AppNavigation> {
  late int _currentIndex;
  bool _isMenuOpen = false;
  bool _isScrolled = false;
  bool _isCheckingAuth = true;

  // Key para el showcase del menú
  final GlobalKey _menuKey = GlobalKey();

  late final List<_NavigationItem> _items;
  late final List<int> _pageVersions;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _items = [
      _NavigationItem(
        label: 'Inicio',
        icon: Icons.dashboard,
        builder: ({Key? key}) => DashboardPage(key: key, menuKey: _menuKey),
      ),
      const _NavigationItem(
        label: 'Historias',
        icon: Icons.library_books,
        builder: StoriesListPage.new,
      ),
      const _NavigationItem(
        label: 'Suscriptores',
        icon: Icons.email,
        builder: SubscribersPage.new,
      ),
      const _NavigationItem(
        label: 'Ajustes',
        icon: Icons.settings,
        builder: SettingsPage.new,
      ),
    ];
    _currentIndex = widget.initialIndex.clamp(0, _items.length - 1).toInt();
    _pageVersions = List<int>.filled(_items.length, 0);
    _pages = List<Widget>.generate(
      _items.length,
      (index) => _items[index].builder(
        key: ValueKey('app-page-$index-${_pageVersions[index]}'),
      ),
      growable: false,
    );
    _checkAuthentication();
  }

  void _checkAuthentication() async {
    // Estrategia mejorada: Escuchar eventos de autenticación de Supabase
    // en lugar de solo hacer polling de la sesión

    // Primero, verificar si hay un error en la URL (magic link inválido/expirado)
    final uri = Uri.base;
    final errorInFragment = uri.fragment.contains('error=');
    final errorDescription = uri.fragment.contains('error_description=')
        ? Uri.decodeComponent(uri.fragment
            .split('error_description=')[1]
            .split('&')[0]
            .replaceAll('+', ' '))
        : null;

    // Verificar si ya hay una sesión
    var session = SupabaseConfig.client.auth.currentSession;

    if (session != null) {
      // Ya hay sesión activa, continuar normalmente
      if (mounted) {
        setState(() {
          _isCheckingAuth = false;
        });
      }
      return;
    }

    // Si hay un error en el fragment, mostrar mensaje amigable
    if (errorInFragment && mounted) {
      setState(() {
        _isCheckingAuth = false;
      });

      // Mostrar mensaje amigable según el tipo de error
      String friendlyMessage =
          'El enlace de inicio de sesión no es válido o ya expiró. '
          'Por favor, solicita un nuevo correo de inicio de sesión.';

      if (errorDescription != null) {
        if (errorDescription.toLowerCase().contains('expired')) {
          friendlyMessage = 'El enlace de inicio de sesión ya expiró. '
              'Por favor, solicita un nuevo correo. Los enlaces duran 15 minutos.';
        } else if (errorDescription.toLowerCase().contains('invalid')) {
          friendlyMessage = 'El enlace de inicio de sesión no es válido. '
              'Asegúrate de copiar el enlace completo del correo o solicita uno nuevo.';
        }
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(friendlyMessage),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 8),
              action: SnackBarAction(
                label: 'Entendido',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );

          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
          );
        }
      });
      return;
    }

    // Si no hay sesión, suscribirse a cambios de auth por un tiempo limitado
    bool sessionDetected = false;
    var authSubscription =
        SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
      final authSession = data.session;
      if (authSession != null && mounted && !sessionDetected) {
        sessionDetected = true;
        setState(() {
          _isCheckingAuth = false;
        });
      }
    });

    // Esperar hasta 3 segundos máximo
    await Future.delayed(const Duration(milliseconds: 3000));

    // Cancelar suscripción
    await authSubscription.cancel();

    // Verificar resultado final
    session = SupabaseConfig.client.auth.currentSession;

    if (mounted) {
      setState(() {
        _isCheckingAuth = false;
      });

      if (session == null && !sessionDetected) {
        // No hay sesión después de esperar, redirigir a login
        // Usar ruta relativa (Flutter está montado con base-href=/app/)
        // Entonces '/login' = /app/login en la URL del navegador
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mostrar pantalla de carga mientras se verifica la autenticación
    if (_isCheckingAuth) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Verificando autenticación...',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 840;

        if (!isCompact && _isMenuOpen) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _isMenuOpen) {
              setState(() {
                _isMenuOpen = false;
              });
            }
          });
        }

        return ShowCaseWidget(
          blurValue: 4,
          disableBarrierInteraction: false,
          enableAutoScroll: false,
          onStart: (index, key) {
            DashboardWalkthroughController.notifyStepStarted(key);

            if (key != _menuKey || key.currentContext == null) {
              return;
            }

            Future.delayed(const Duration(milliseconds: 300), () {
              if (key.currentContext != null) {
                Scrollable.ensureVisible(
                  key.currentContext!,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  alignment: 0.5,
                );
              }
            });
          },
          onFinish: DashboardWalkthroughController.notifyFinished,
          builder: (context) => Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: SafeArea(
              child: Column(
                children: [
                  AppTopNavigationBar(
                    items: _items
                        .map((item) => item.asNavigationItem)
                        .toList(growable: false),
                    currentIndex: _currentIndex,
                    isCompact: isCompact,
                    isMenuOpen: _isMenuOpen,
                    isScrolled: _isScrolled,
                    menuKey: _menuKey,
                    onItemSelected: _handleNavigationTap,
                    onCreateStory: _startNewStory,
                    onToggleMenu: () {
                      setState(() {
                        _isMenuOpen = !_isMenuOpen;
                      });
                    },
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        final didScroll = notification.metrics.pixels > 12;

                        if (didScroll != _isScrolled) {
                          setState(() {
                            _isScrolled = didScroll;
                          });
                        }

                        if (_isMenuOpen && didScroll) {
                          setState(() {
                            _isMenuOpen = false;
                          });
                        }

                        return false;
                      },
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: _PageContainer(
                          key: ValueKey(
                            '$_currentIndex-${_pageVersions[_currentIndex]}',
                          ),
                          child: _pages[_currentIndex],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleNavigationTap(int index) {
    setState(() {
      if (index == _currentIndex) {
        _pageVersions[index]++;
        _pages[index] = _items[index].builder(
          key: ValueKey('app-page-$index-${_pageVersions[index]}'),
        );
      } else {
        _currentIndex = index;
      }
      _isMenuOpen = false;
    });
  }

  Future<void> _startNewStory() async {
    setState(() {
      _isMenuOpen = false;
    });

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const StoryEditorPage(),
      ),
    );
  }
}

class _NavigationItem {
  const _NavigationItem({
    required this.label,
    required this.icon,
    required this.builder,
  });

  final String label;
  final IconData icon;
  final Widget Function({Key? key}) builder;

  AppNavigationItem get asNavigationItem =>
      AppNavigationItem(label: label, icon: icon);
}

class _PageContainer extends StatelessWidget {
  const _PageContainer({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
      ),
      child: child,
    );
  }
}
