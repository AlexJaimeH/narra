import 'package:flutter/material.dart';
import 'package:narra/supabase/supabase_config.dart';
import 'dashboard_page.dart';
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

  final List<_NavigationItem> _items = const [
    _NavigationItem(
      label: 'Inicio',
      icon: Icons.dashboard,
      builder: DashboardPage.new,
    ),
    _NavigationItem(
      label: 'Historias',
      icon: Icons.library_books,
      builder: StoriesListPage.new,
    ),
    _NavigationItem(
      label: 'Suscriptores',
      icon: Icons.email,
      builder: SubscribersPage.new,
    ),
    _NavigationItem(
      label: 'Ajustes',
      icon: Icons.settings,
      builder: SettingsPage.new,
    ),
  ];

  late final List<int> _pageVersions;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
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
    // Dar tiempo a Supabase para procesar tokens del magic link en la URL
    // Cuando un usuario hace clic en el magic link, Supabase redirige con tokens
    // en el hash fragment que necesitan ser procesados

    // Intentar obtener la sesión múltiples veces con delays entre intentos
    var session = SupabaseConfig.client.auth.currentSession;

    // Si no hay sesión inmediata, esperar y reintentar
    if (session == null) {
      await Future.delayed(const Duration(milliseconds: 500));
      session = SupabaseConfig.client.auth.currentSession;
    }

    // Segundo intento si aún no hay sesión
    if (session == null) {
      await Future.delayed(const Duration(milliseconds: 500));
      session = SupabaseConfig.client.auth.currentSession;
    }

    if (mounted) {
      setState(() {
        _isCheckingAuth = false;
      });

      if (session == null) {
        // No hay sesión después de esperar, redirigir a login
        Navigator.pushReplacementNamed(context, '/app/login');
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

        return Scaffold(
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
