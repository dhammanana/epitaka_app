import 'package:flutter/material.dart';

import '../../core/theme/app_dimensions.dart';

/// The primary app shell wrapper with a floating bottom toolbar.
class AppShell extends StatelessWidget {
  final Widget child;
  final PreferredSizeWidget? appBar;
  final List<Widget>? bottomToolbarActions;
  final bool showBottomToolbar;

  const AppShell({
    super.key,
    required this.child,
    this.appBar,
    this.bottomToolbarActions,
    this.showBottomToolbar = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: appBar,
      body: Stack(
        children: [
          child,
          if (showBottomToolbar)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: _FloatingBottomToolbar(
                  actions: bottomToolbarActions,
                  colors: colors,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Floating pill-shaped bottom toolbar matching the design spec.
class _FloatingBottomToolbar extends StatelessWidget {
  final List<Widget>? actions;
  final ColorScheme colors;

  const _FloatingBottomToolbar({this.actions, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppDimensions.bottomToolbarHeight,
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: actions ??
            [
              _ToolbarIcon(icon: Icons.format_list_bulleted, label: 'Contents'),
              _ToolbarIcon(icon: Icons.search, label: 'Search'),
              _ToolbarIcon(icon: Icons.menu_book, label: 'Dictionary'),
              _ToolbarIcon(icon: Icons.volume_up, label: 'Listen'),
              _ToolbarIcon(icon: Icons.bookmark, label: 'Save'),
            ],
      ),
    );
  }
}

class _ToolbarIcon extends StatefulWidget {
  final IconData icon;
  final String label;

  const _ToolbarIcon({required this.icon, required this.label});

  @override
  State<_ToolbarIcon> createState() => _ToolbarIconState();
}

class _ToolbarIconState extends State<_ToolbarIcon> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.label,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: AnimatedScale(
            scale: _hovered ? 1.15 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: IconButton(
              icon: Icon(widget.icon),
              color: _hovered ? colors.primary : colors.onSurfaceVariant,
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
  }
}
