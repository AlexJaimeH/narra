import 'package:flutter/material.dart';
import 'package:narra/supabase/supabase_config.dart';
import 'dashboard_page.dart';
import 'stories_list_page.dart';
import 'people_page.dart';
import 'subscribers_page.dart';
import 'settings_page.dart';
import 'story_editor_page.dart';

class AppNavigation extends StatefulWidget {
  const AppNavigation({super.key});

  @override
  State<AppNavigation> createState() => _AppNavigationState();
}

class _AppNavigationState extends State<AppNavigation> {
  int _currentIndex = 0;
  bool _isMenuOpen = false;
  bool _isScrolled = false;

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
      label: 'Personas',
      icon: Icons.people,
      builder: PeoplePage.new,
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

  late final List<Widget> _pages =
      _items.map((item) => item.builder()).toList(growable: false);

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  void _checkAuthentication() {
    if (!SupabaseAuth.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/landing');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                _TopNavigationBar(
                  items: _items,
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
                        key: ValueKey(_currentIndex),
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
    if (index == _currentIndex) {
      setState(() {
        _isMenuOpen = false;
      });
      return;
    }

    setState(() {
      _currentIndex = index;
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
  final Widget Function() builder;
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

class _TopNavigationBar extends StatelessWidget {
  const _TopNavigationBar({
    required this.items,
    required this.currentIndex,
    required this.onItemSelected,
    required this.isCompact,
    required this.isMenuOpen,
    required this.onToggleMenu,
    required this.isScrolled,
    required this.onCreateStory,
  });

  final List<_NavigationItem> items;
  final int currentIndex;
  final ValueChanged<int> onItemSelected;
  final bool isCompact;
  final bool isMenuOpen;
  final VoidCallback onToggleMenu;
  final bool isScrolled;
  final VoidCallback onCreateStory;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final double elevation = isScrolled ? 10 : 0;

    return Material(
      color: colorScheme.surface,
      elevation: elevation,
      shadowColor: Colors.black.withValues(alpha: isScrolled ? 0.12 : 0.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: isCompact
              ? _MobileNav(
                  items: items,
                  currentIndex: currentIndex,
                  onItemSelected: onItemSelected,
                  isMenuOpen: isMenuOpen,
                  onToggleMenu: onToggleMenu,
                  onCreateStory: onCreateStory,
                )
              : _DesktopNav(
                  items: items,
                  currentIndex: currentIndex,
                  onItemSelected: onItemSelected,
                  onCreateStory: onCreateStory,
                ),
        ),
      ),
    );
  }
}

class _DesktopNav extends StatelessWidget {
  const _DesktopNav({
    required this.items,
    required this.currentIndex,
    required this.onItemSelected,
    required this.onCreateStory,
  });

  final List<_NavigationItem> items;
  final int currentIndex;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onCreateStory;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _Brand(),
        Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Tooltip(
                  message: items[i].label,
                  waitDuration: const Duration(milliseconds: 300),
                  child: _NavItemButton(
                    label: items[i].label,
                    icon: items[i].icon,
                    selected: currentIndex == i,
                    onTap: () => onItemSelected(i),
                  ),
                ),
              ),
          ],
        ),
        _CreateStoryButton(onPressed: onCreateStory),
      ],
    );
  }
}

class _MobileNav extends StatelessWidget {
  const _MobileNav({
    required this.items,
    required this.currentIndex,
    required this.onItemSelected,
    required this.isMenuOpen,
    required this.onToggleMenu,
    required this.onCreateStory,
  });

  final List<_NavigationItem> items;
  final int currentIndex;
  final ValueChanged<int> onItemSelected;
  final bool isMenuOpen;
  final VoidCallback onToggleMenu;
  final VoidCallback onCreateStory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _Brand(),
            const Spacer(),
            _AnimatedMenuButton(
              isOpen: isMenuOpen,
              onPressed: onToggleMenu,
              color: colorScheme.primary,
            ),
          ],
        ),
        AnimatedCrossFade(
          crossFadeState:
              isMenuOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
          sizeCurve: Curves.easeInOut,
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++)
                    _MobileNavItem(
                      label: items[i].label,
                      icon: items[i].icon,
                      selected: currentIndex == i,
                      onTap: () => onItemSelected(i),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _CreateStoryButton(
                        onPressed: onCreateStory,
                        compact: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CreateStoryButton extends StatelessWidget {
  const _CreateStoryButton({
    required this.onPressed,
    this.compact = false,
  });

  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: 'Nueva historia',
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: compact
              ? const EdgeInsets.all(12)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 2,
        ),
        child: const Icon(Icons.add, size: 20),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            'N',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Narra',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _NavItemButton extends StatefulWidget {
  const _NavItemButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavItemButton> createState() => _NavItemButtonState();
}

class _NavItemButtonState extends State<_NavItemButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isActive = widget.selected;
    final background = isActive
        ? colorScheme.primary.withValues(alpha: 0.14)
        : _isHovering
            ? colorScheme.primary.withValues(alpha: 0.08)
            : Colors.transparent;
    final foreground =
        isActive ? colorScheme.primary : colorScheme.onSurfaceVariant;

    Widget navButton = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: foreground),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight:
                      widget.selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: navButton,
    );
  }
}

class _MobileNavItem extends StatefulWidget {
  const _MobileNavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_MobileNavItem> createState() => _MobileNavItemState();
}

class _MobileNavItemState extends State<_MobileNavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 200),
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    if (widget.selected) {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant _MobileNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasActive = oldWidget.selected;
    final isActive = widget.selected;
    if (wasActive != isActive) {
      if (isActive) {
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
    final colorScheme = theme.colorScheme;

    final isActive = widget.selected;

    Widget navItem = InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Container(
                  height: 32,
                  width: 32,
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      colorScheme.primary.withValues(alpha: 0.08),
                      colorScheme.primary.withValues(alpha: 0.18),
                      isActive ? 1 : _controller.value,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: child,
                );
              },
              child: Icon(
                widget.icon,
                color: isActive
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isActive ? 1 : 0,
              child: Icon(
                Icons.chevron_right,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: navItem,
    );
  }
}

class _AnimatedMenuButton extends StatefulWidget {
  const _AnimatedMenuButton({
    required this.isOpen,
    required this.onPressed,
    required this.color,
  });

  final bool isOpen;
  final VoidCallback onPressed;
  final Color color;

  @override
  State<_AnimatedMenuButton> createState() => _AnimatedMenuButtonState();
}

class _AnimatedMenuButtonState extends State<_AnimatedMenuButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 250),
    vsync: this,
    value: widget.isOpen ? 1 : 0,
  );

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
    return IconButton(
      onPressed: widget.onPressed,
      icon: AnimatedIcon(
        icon: AnimatedIcons.menu_close,
        progress: _controller,
        color: widget.color,
      ),
      tooltip: widget.isOpen ? 'Cerrar menú' : 'Abrir menú',
    );
  }
}
