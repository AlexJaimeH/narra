import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

import 'dashboard_walkthrough_controller.dart';

class AppNavigationItem {
  const AppNavigationItem({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;
}

class AppTopNavigationBar extends StatelessWidget {
  const AppTopNavigationBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onItemSelected,
    required this.isCompact,
    required this.isMenuOpen,
    required this.onToggleMenu,
    required this.onCreateStory,
    required this.isScrolled,
    this.menuKey,
  });

  final List<AppNavigationItem> items;
  final int currentIndex;
  final ValueChanged<int> onItemSelected;
  final bool isCompact;
  final bool isMenuOpen;
  final VoidCallback onToggleMenu;
  final VoidCallback onCreateStory;
  final bool isScrolled;
  final GlobalKey? menuKey;

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
                  menuKey: menuKey,
                )
              : _DesktopNav(
                  items: items,
                  currentIndex: currentIndex,
                  onItemSelected: onItemSelected,
                  onCreateStory: onCreateStory,
                  menuKey: menuKey,
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
    this.menuKey,
  });

  final List<AppNavigationItem> items;
  final int currentIndex;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onCreateStory;
  final GlobalKey? menuKey;

  @override
  Widget build(BuildContext context) {
    final navRow = Row(
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
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const _Brand(),
        menuKey != null
            ? Showcase(
                key: menuKey!,
                description: '🗂️ Menú de navegación:\n\n'
                    '• Inicio - Vista general y crear historias\n'
                    '• Historias - Ver y organizar tus relatos\n'
                    '• Suscriptores - Gestionar tu audiencia\n'
                    '• Ajustes - Personalizar tu cuenta',
                descTextStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                  color: Colors.white,
                ),
                tooltipBackgroundColor: const Color(0xFF4DB3A8),
                textColor: Colors.white,
                tooltipPadding: const EdgeInsets.all(20),
                tooltipBorderRadius: BorderRadius.circular(16),
                overlayColor: Colors.black,
                overlayOpacity: 0.60,
                disableDefaultTargetGestures: true,
                onTargetClick: DashboardWalkthroughController.triggerAdvance,
                onToolTipClick: DashboardWalkthroughController.triggerAdvance,
                onBarrierClick: DashboardWalkthroughController.triggerAdvance,
                child: navRow,
              )
            : navRow,
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
    this.menuKey,
  });

  final List<AppNavigationItem> items;
  final int currentIndex;
  final ValueChanged<int> onItemSelected;
  final bool isMenuOpen;
  final VoidCallback onToggleMenu;
  final VoidCallback onCreateStory;
  final GlobalKey? menuKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final menuButton = _AnimatedMenuButton(
      isOpen: isMenuOpen,
      onPressed: onToggleMenu,
      color: colorScheme.primary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _Brand(),
            const Spacer(),
            menuKey != null
                ? Showcase(
                    key: menuKey!,
                    description: '🗂️ Menú de navegación:\n\n'
                        '• Inicio - Vista general y crear historias\n'
                        '• Historias - Ver y organizar tus relatos\n'
                        '• Suscriptores - Gestionar tu audiencia\n'
                        '• Ajustes - Personalizar tu cuenta',
                    descTextStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                      color: Colors.white,
                    ),
                    tooltipBackgroundColor: const Color(0xFF4DB3A8),
                    textColor: Colors.white,
                    tooltipPadding: const EdgeInsets.all(20),
                    tooltipBorderRadius: BorderRadius.circular(16),
                    overlayColor: Colors.black,
                    overlayOpacity: 0.60,
                    disableDefaultTargetGestures: true,
                    onTargetClick: DashboardWalkthroughController.triggerAdvance,
                    onToolTipClick: DashboardWalkthroughController.triggerAdvance,
                    onBarrierClick: DashboardWalkthroughController.triggerAdvance,
                    child: menuButton,
                  )
                : menuButton,
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
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
    final double size = compact ? 42 : 48;

    return Tooltip(
      message: 'Nueva historia',
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
          minimumSize: Size.square(size),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 3,
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
    return Image.network(
      '/app/logo-horizontal.png',
      height: 32,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // Fallback si la imagen no carga
        return const Text(
          'Narra',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        );
      },
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
  void didUpdateWidget(covariant _MobileNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      if (widget.selected) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
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
