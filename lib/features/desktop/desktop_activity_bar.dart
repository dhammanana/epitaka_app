import 'package:flutter/material.dart';

import '../../core/utils/app_localizations.dart';
import '../../shared/providers/side_panel_provider.dart';

/// A VS Code-style vertical icon rail on the far left of the desktop shell.
///
/// Each top button toggles a sidebar panel (one at a time — clicking an
/// item opens the sidebar showing it and closes the others). The dictionary
/// button toggles the dictionary dock, Vimaṃsa opens the center chat tab,
/// and the bottom section holds layout-wide actions (reset, settings).
class DesktopActivityBar extends StatelessWidget {
  /// The sidebar panel currently open in the left slot (highlights its
  /// button), or null when the sidebar is closed.
  final SidePanelType? activeSidebar;

  /// Whether the dictionary is currently visible (docked or on the right).
  final bool dictionaryVisible;

  /// Whether the Vimaṃsa center tab is selected.
  final bool vimamsaActive;

  final ValueChanged<SidePanelType> onToggleSidebar;
  final VoidCallback onToggleDictionary;
  final VoidCallback onToggleVimamsa;
  final VoidCallback onResetLayout;
  final VoidCallback onOpenSettings;

  const DesktopActivityBar({
    super.key,
    required this.activeSidebar,
    required this.dictionaryVisible,
    required this.vimamsaActive,
    required this.onToggleSidebar,
    required this.onToggleDictionary,
    required this.onToggleVimamsa,
    required this.onResetLayout,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    final items = <_ActivityItem>[
      _ActivityItem(
        SidePanelType.library,
        Icons.library_books_outlined,
        Icons.library_books,
        loc.libraryLabel,
      ),
      _ActivityItem(
        SidePanelType.search,
        Icons.search,
        Icons.search,
        loc.search,
      ),
      _ActivityItem(
        SidePanelType.history,
        Icons.history,
        Icons.history,
        loc.history,
      ),
      _ActivityItem(
        SidePanelType.bookmarks,
        Icons.bookmark_outline,
        Icons.bookmark,
        loc.bookmarks,
      ),
      _ActivityItem(
        SidePanelType.contents,
        Icons.format_list_bulleted,
        Icons.format_list_bulleted,
        loc.contents,
      ),
      _ActivityItem(
        SidePanelType.gavesana,
        Icons.travel_explore,
        Icons.travel_explore,
        loc.gavesana,
      ),
      _ActivityItem(
        null, // dictionary is not a plain sidebar toggle
        Icons.menu_book_outlined,
        Icons.menu_book,
        loc.dictionary,
        activeOverride: dictionaryVisible,
        onTapOverride: onToggleDictionary,
      ),
    ];

    return Container(
      width: 52,
      color: colors.surfaceContainerLowest,
      child: Column(
        children: [
          const SizedBox(height: 6),
          for (final item in items)
            _ActivityBarButton(
              icon: item.isActive(activeSidebar) ? item.activeIcon : item.icon,
              tooltip: item.label,
              active: item.isActive(activeSidebar),
              onTap: () {
                if (item.onTapOverride != null) {
                  item.onTapOverride!();
                } else if (item.toggleSidebar != null) {
                  onToggleSidebar(item.toggleSidebar!);
                }
              },
            ),
          // Vimaṃsa center tab (separate group)
          _ActivityBarButton(
            icon: vimamsaActive
                ? Icons.auto_awesome
                : Icons.auto_awesome_outlined,
            tooltip: loc.vimamsa,
            active: vimamsaActive,
            onTap: onToggleVimamsa,
          ),
          const Spacer(),
          _ActivityBarButton(
            icon: Icons.restart_alt,
            tooltip: loc.resetLayout,
            active: false,
            onTap: onResetLayout,
          ),
          _ActivityBarButton(
            icon: Icons.settings_outlined,
            tooltip: loc.settings,
            active: false,
            onTap: onOpenSettings,
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _ActivityItem {
  final SidePanelType? toggleSidebar;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// For items that aren't plain sidebar toggles (e.g. dictionary).
  final bool? activeOverride;
  final VoidCallback? onTapOverride;

  const _ActivityItem(
    this.toggleSidebar,
    this.icon,
    this.activeIcon,
    this.label, {
    this.activeOverride,
    this.onTapOverride,
  });

  bool isActive(SidePanelType? activeSidebar) {
    if (activeOverride != null) return activeOverride!;
    return activeSidebar == toggleSidebar;
  }
}

/// A single 52×52 icon button with hover feedback and active highlight.
class _ActivityBarButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  const _ActivityBarButton({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  @override
  State<_ActivityBarButton> createState() => _ActivityBarButtonState();
}

class _ActivityBarButtonState extends State<_ActivityBarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = widget.active
        ? colors.primary
        : _hovered
            ? colors.onSurface
            : colors.onSurfaceVariant;

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: widget.active
                ? BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.25),
                    border: Border(
                      left: BorderSide(color: colors.primary, width: 3),
                    ),
                  )
                : null,
            child: Icon(widget.icon, size: 22, color: color),
          ),
        ),
      ),
    );
  }
}
