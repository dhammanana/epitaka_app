import 'package:flutter/material.dart';

import '../../core/utils/app_localizations.dart';
import '../../shared/providers/side_panel_provider.dart';
import '../../shared/utils/app_shortcuts.dart';
import '../sutta_jump/widgets/go_to_sutta_dialog.dart';

/// A VS Code-style vertical icon rail on the far left of the desktop shell.
///
/// Each top button toggles a sidebar panel (one at a time — clicking an
/// item opens the sidebar showing it and closes the others). The dictionary
/// button toggles the dictionary dock, Vīmaṃsā opens the center chat tab,
/// and the bottom section holds layout-wide actions (reset, settings).
class DesktopActivityBar extends StatelessWidget {
  /// The sidebar panel currently open in the left slot (highlights its
  /// button), or null when the sidebar is closed.
  final SidePanelType? activeSidebar;

  /// Whether the Vīmaṃsā center tab is selected.
  final bool vimamsaActive;

  final ValueChanged<SidePanelType> onToggleSidebar;
  final VoidCallback onToggleVimamsa;
  final VoidCallback onResetLayout;
  final VoidCallback onOpenSettings;

  const DesktopActivityBar({
    super.key,
    required this.activeSidebar,
    required this.vimamsaActive,
    required this.onToggleSidebar,
    required this.onToggleVimamsa,
    required this.onResetLayout,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    final items = <_ActivityItem>[
      // Order: Tipiṭaka, Vīmaṃsā (center tab, rendered second),
      // Contents, Annotations, History, Search, Gavesanā,
      // Dictionary, Script Converter, Translation Builder
      _ActivityItem(
        SidePanelType.library,
        Icons.library_books_outlined,
        Icons.library_books,
        loc.tipitaka,
        shortcutId: 'library-sidebar',
      ),
      _ActivityItem(
        SidePanelType.contents,
        Icons.format_list_bulleted,
        Icons.format_list_bulleted,
        loc.contents,
        shortcutId: 'contents',
      ),
      _ActivityItem(
        SidePanelType.outline,
        Icons.account_tree_outlined,
        Icons.account_tree_outlined,
        loc.outline,
        shortcutId: 'outline',
      ),
      _ActivityItem(
        SidePanelType.annotations,
        Icons.edit_note,
        Icons.edit_note,
        loc.annotations,
        shortcutId: 'annotations',
      ),
      _ActivityItem(
        SidePanelType.history,
        Icons.history,
        Icons.history,
        loc.history,
        shortcutId: 'history',
      ),
      _ActivityItem(
        SidePanelType.search,
        Icons.search,
        Icons.search,
        loc.search,
        shortcutId: 'find-everywhere',
      ),
      _ActivityItem(
        null,
        Icons.near_me_outlined,
        Icons.near_me_outlined,
        loc.goToSutta,
        shortcutId: 'go-to-sutta',
        onTap: () => showGoToSuttaDialog(context),
      ),
      _ActivityItem(
        SidePanelType.gavesana,
        Icons.travel_explore,
        Icons.travel_explore,
        loc.gavesana,
      ),
      _ActivityItem(
        SidePanelType.dictionary,
        Icons.menu_book_outlined,
        Icons.menu_book,
        loc.dictionary,
        shortcutId: 'dictionary',
      ),
      _ActivityItem(
        SidePanelType.scriptConverter,
        Icons.swap_horiz,
        Icons.swap_horiz,
        loc.scriptConverter,
      ),
      _ActivityItem(
        SidePanelType.translator,
        Icons.translate,
        Icons.translate,
        loc.t('Translation Builder'),
      ),
    ];

    return Container(
      width: 52,
      color: colors.surfaceContainerLowest,
      child: Column(
        children: [
          const SizedBox(height: 6),
          // The top group scrolls vertically so the rail never overflows on
          // short windows — there are many sidebar panels now.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _ActivityBarButton(
                    icon: items.first.isActive(activeSidebar)
                        ? items.first.activeIcon
                        : items.first.icon,
                    tooltip: AppShortcuts.tooltip(
                      items.first.label,
                      items.first.shortcutId!,
                    ),
                    active: items.first.isActive(activeSidebar),
                    onTap: () => onToggleSidebar(items.first.toggleSidebar!),
                  ),
                  // Vīmaṃsā center tab, second after Tipiṭaka
                  _ActivityBarButton(
                    icon: vimamsaActive
                        ? Icons.auto_awesome
                        : Icons.auto_awesome_outlined,
                    tooltip: AppShortcuts.tooltip(loc.vimamsa, 'vimamsa'),
                    active: vimamsaActive,
                    onTap: onToggleVimamsa,
                  ),
                  for (final item in items.skip(1))
                    _ActivityBarButton(
                      icon: item.isActive(activeSidebar)
                          ? item.activeIcon
                          : item.icon,
                      tooltip: item.shortcutId == null
                          ? item.label
                          : AppShortcuts.tooltip(item.label, item.shortcutId!),
                      active: item.isActive(activeSidebar),
                      onTap: () {
                        if (item.toggleSidebar != null) {
                          onToggleSidebar(item.toggleSidebar!);
                        }
                        item.onTap?.call();
                      },
                    ),
                ],
              ),
            ),
          ),
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

  /// Id of the global shortcut for this action (see
  /// [AppShortcuts.shortcutCatalog]) whose hint is appended to the
  /// tooltip. Null when the action has no keyboard shortcut.
  final String? shortcutId;

  /// For an item that opens something other than a sidebar panel.
  final VoidCallback? onTap;

  const _ActivityItem(
    this.toggleSidebar,
    this.icon,
    this.activeIcon,
    this.label, {
    this.shortcutId,
    this.onTap,
  });

  bool isActive(SidePanelType? activeSidebar) {
    // Without this guard an item with no panel would light up whenever the
    // sidebar is closed (null == null).
    return toggleSidebar != null && activeSidebar == toggleSidebar;
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
