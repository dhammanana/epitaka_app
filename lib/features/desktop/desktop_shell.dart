import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/settings_provider.dart';
import '../../core/utils/app_localizations.dart';
import '../../features/reader/providers/reader_tabs_provider.dart';
import '../../shared/providers/side_panel_provider.dart';
import '../../shared/providers/vimamsa_panel_provider.dart';
import '../../shared/widgets/reader_toolbar_controller.dart';
import '../ai_qa/screens/ai_qa_screen.dart';
import '../contents/widgets/contents_panel.dart';
import '../dictionary/widgets/dictionary_panel.dart';
import '../gavesana/widgets/gavesana_panel.dart';
import '../translator/widgets/translator_panel.dart';
import '../annotations/widgets/global_annotations_view.dart';
import '../script_converter/widgets/script_converter_panel.dart';
import '../library/widgets/history_panel.dart';
import '../library/widgets/library_panel.dart';
import '../outline/widgets/outline_panel.dart';
import '../reader/widgets/reader_keyboard_navigation.dart';
import '../search/widgets/search_panel.dart';
import '../settings/widgets/settings_dialog.dart';
import 'desktop_activity_bar.dart';
import 'desktop_status_bar.dart';

/// Width of the draggable divider between a side panel and the main area.
const double _kDividerWidth = 12;

/// Minimum width a side panel can be resized to.
const double _kMinPanelWidth = 260;

/// Maximum width the right side panel can be resized to.
const double _kMaxRightPanelWidth = 640;

/// Default side-panel widths (used until the user resizes them).
const double _kDefaultLeftWidth = 340;
const double _kDefaultRightWidth = 360;

/// The desktop shell shown instead of the mobile layout on desktop platforms.
///
/// The sidebar shows one panel at a time (library, search, dictionary, etc.)
/// as a regular panel — dictionary is no longer a special docked/right-panel.
class DesktopShell extends ConsumerStatefulWidget {
  /// The main content (the reader). Shown in the center "Reading" tab.
  final Widget child;

  const DesktopShell({super.key, required this.child});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  final ReaderToolbarController _toolbarController = ReaderToolbarController();

  /// Whether the sidebar is docked on the right side of the window.
  bool _sidebarOnRight = false;

  double _leftWidth = _kDefaultLeftWidth;
  double _rightWidth = _kDefaultRightWidth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = ref.read(settingsProvider);
      setState(() {
        _leftWidth = s.leftPanelWidth > 0
            ? s.leftPanelWidth
            : _kDefaultLeftWidth;
        _rightWidth = s.rightPanelWidth > 0
            ? s.rightPanelWidth
            : _kDefaultRightWidth;
        _sidebarOnRight = s.sidebarOnRight;
      });
    });
  }

  @override
  void dispose() {
    _toolbarController.dispose();
    super.dispose();
  }

  // ── Sidebar toggling ──────────────────────────────────────────────

  void _toggleSidebar(SidePanelType panel) {
    ref.read(sidePanelProvider.notifier).toggle(panel);
  }

  void _moveSidebarToRight() {
    setState(() => _sidebarOnRight = true);
    ref.read(settingsProvider.notifier).setSidebarOnRight(true);
  }

  void _moveSidebarToLeft() {
    setState(() => _sidebarOnRight = false);
    ref.read(settingsProvider.notifier).setSidebarOnRight(false);
  }

  void resetLayout() {
    ref.read(vimamsaOpenProvider.notifier).close();
    setState(() {
      _sidebarOnRight = false;
      _leftWidth = _kDefaultLeftWidth;
      _rightWidth = _kDefaultRightWidth;
    });
    ref.read(sidePanelProvider.notifier).closeAll();
    ref.read(settingsProvider.notifier).setLeftPanelWidth(0);
    ref.read(settingsProvider.notifier).setRightPanelWidth(0);
    ref.read(settingsProvider.notifier).setSidebarOnRight(false);
  }

  // ── Panel resizing ────────────────────────────────────────────────

  double _clampLeft(double w) => w.clamp(_kMinPanelWidth, 700).toDouble();
  double _clampRight(double w) =>
      w.clamp(_kMinPanelWidth, _kMaxRightPanelWidth).toDouble();

  void _persistWidths() {
    ref
        .read(settingsProvider.notifier)
        .setLeftPanelWidth(_leftWidth.roundToDouble());
    ref
        .read(settingsProvider.notifier)
        .setRightPanelWidth(_rightWidth.roundToDouble());
  }

  // ── Panel content ─────────────────────────────────────────────────

  Widget _buildSidebar({
    required SidePanelType panel,
    required String title,
    required bool onRight,
    required bool autoFocus,
  }) {
    return DesktopSidebar(
      panel: panel,
      title: title,
      onRight: onRight,
      autoFocus: autoFocus,
      onClose: () => _toggleSidebar(panel),
      onMoveSidebarRight: _moveSidebarToRight,
      onMoveSidebarLeft: _moveSidebarToLeft,
    );
  }

  String _panelTitle(SidePanelType panel, AppLocalizations loc) {
    switch (panel) {
      case SidePanelType.library:
        return loc.libraryLabel;
      case SidePanelType.search:
        return loc.search;
      case SidePanelType.history:
        return loc.history;
      case SidePanelType.annotations:
        return loc.annotations;
      case SidePanelType.scriptConverter:
        return loc.scriptConverter;
      case SidePanelType.contents:
        return loc.contents;
      case SidePanelType.outline:
        return loc.outline;
      case SidePanelType.gavesana:
        return loc.gavesana;
      case SidePanelType.translator:
        return loc.t('Translation Builder');
      case SidePanelType.dictionary:
        return loc.dictionary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final panels = ref.watch(sidePanelProvider);
    final vimamsaOpen = ref.watch(vimamsaOpenProvider);
    // Rebuilds the activity bar's tooltips when the user changes a shortcut.
    ref.watch(settingsProvider.select((s) => s.shortcutOverrides));
    final left = panels.left.openPanel;
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    final showLeftSidebar = left != null && !_sidebarOnRight;
    final showRightSidebar = _sidebarOnRight && left != null;

    // Opening a book while Vīmaṃsā is showing returns to the reader.
    ref.listen(readerTabsProvider, (prev, next) {
      if (!mounted) return;
      if (ref.read(vimamsaOpenProvider) &&
          next.tabs.length > (prev?.tabs.length ?? 0)) {
        ref.read(vimamsaOpenProvider.notifier).close();
      }
    });

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // VS Code-style icon rail
                  DesktopActivityBar(
                    activeSidebar: left,
                    vimamsaActive: vimamsaOpen,
                    onToggleSidebar: _toggleSidebar,
                    onToggleVimamsa: () =>
                        ref.read(vimamsaOpenProvider.notifier).toggle(),
                    onResetLayout: resetLayout,
                    onOpenSettings: () => showSettingsDialog(context),
                  ),
                  _ActivityRailDivider(
                    visible: showLeftSidebar || showRightSidebar,
                  ),
                  // Left sidebar
                  Container(
                    width: showLeftSidebar ? _leftWidth : 0,
                    child: showLeftSidebar
                        ? _buildSidebar(
                            panel: left,
                            title: _panelTitle(left, loc),
                            onRight: false,
                            autoFocus: panels.left.autoFocus,
                          )
                        : const SizedBox.shrink(),
                  ),
                  _PanelDivider(
                    key: const Key('left-panel-divider'),
                    visible: showLeftSidebar,
                    sign: 1,
                    currentWidth: () => _leftWidth,
                    onWidthChanged: (w) =>
                        setState(() => _leftWidth = _clampLeft(w)),
                    onDragEnd: _persistWidths,
                  ),
                  // Center: reader + Vīmaṃsā tabs
                  Expanded(child: _buildCenter(context, colors, loc)),
                  // Right divider + panel
                  _PanelDivider(
                    key: const Key('right-panel-divider'),
                    visible: showRightSidebar,
                    sign: -1,
                    currentWidth: () => _rightWidth,
                    onWidthChanged: (w) =>
                        setState(() => _rightWidth = _clampRight(w)),
                    onDragEnd: _persistWidths,
                  ),
                  Container(
                    width: showRightSidebar ? _rightWidth : 0,
                    child: showRightSidebar
                        ? _buildSidebar(
                            panel: left,
                            title: _panelTitle(left, loc),
                            onRight: true,
                            autoFocus: panels.left.autoFocus,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            // Attached status bar (not floating)
            DesktopStatusBar(
              controller: _toolbarController,
              onResetLayout: resetLayout,
              onOpenSettings: () => showSettingsDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenter(
    BuildContext context,
    ColorScheme colors,
    AppLocalizations loc,
  ) {
    final vimamsaOpen = ref.watch(vimamsaOpenProvider);
    final tabsState = ref.watch(readerTabsProvider);
    final bookName = tabsState.activeTab?.bookName;
    return ReaderToolbarScope(
      controller: _toolbarController,
      child: Column(
        children: [
          _CenterTabs(
            colors: colors,
            vimamsaSelected: vimamsaOpen,
            readingLabel: bookName ?? loc.reading,
            vimamsaLabel: loc.vimamsa,
            onReadingTap: () => ref.read(vimamsaOpenProvider.notifier).close(),
            onVimamsaTap: () => ref.read(vimamsaOpenProvider.notifier).open(),
          ),
          Divider(height: 1, color: colors.outlineVariant),
          Expanded(
            child: IndexedStack(
              index: vimamsaOpen ? 1 : 0,
              children: [
                ReaderKeyboardNavigation(child: widget.child),
                const VimamsaScreen(panelMode: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SIDEBAR
// ═══════════════════════════════════════════════════════════════════════════

/// The single sidebar panel: a header (title + drag grip + close), then the
/// active panel content filling the rest of the space.
class DesktopSidebar extends StatelessWidget {
  final SidePanelType panel;
  final String title;
  final bool onRight;
  final bool autoFocus;
  final VoidCallback onClose;
  final VoidCallback onMoveSidebarRight;
  final VoidCallback onMoveSidebarLeft;

  const DesktopSidebar({
    super.key,
    required this.panel,
    required this.title,
    required this.onRight,
    required this.autoFocus,
    required this.onClose,
    required this.onMoveSidebarRight,
    required this.onMoveSidebarLeft,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    return Container(
      color: colors.surfaceContainerLowest,
      child: Column(
        children: [
          _PanelHeader(
            title: title,
            colors: colors,
            onClose: onClose,
            grip: _Grip(
              onDragRight: onMoveSidebarRight,
              onDragLeft: onMoveSidebarLeft,
              tooltip: loc.t(
                onRight ? 'Move panel to the left' : 'Move panel to the right',
              ),
            ),
          ),
          Divider(height: 1, color: colors.outlineVariant),
          Expanded(child: _panelContent(context)),
        ],
      ),
    );
  }

  Widget _panelContent(BuildContext context) {
    switch (panel) {
      case SidePanelType.library:
        return LibraryPanel(autoFocus: autoFocus);
      case SidePanelType.search:
        return SearchPanel(autoFocus: autoFocus);
      case SidePanelType.history:
        return const HistoryPanel();
      case SidePanelType.annotations:
        return const GlobalAnnotationsView();
      case SidePanelType.scriptConverter:
        return const ScriptConverterPanel();
      case SidePanelType.contents:
        return const ContentsPanel();
      case SidePanelType.outline:
        return const OutlinePanel();
      case SidePanelType.gavesana:
        return GavesanaPanel(autoFocus: autoFocus);
      case SidePanelType.translator:
        return const TranslatorPanel();
      case SidePanelType.dictionary:
        return DictionaryPanel(autoFocus: autoFocus);
    }
  }
}

/// A slim panel header: title on the left, drag grip and close button on
/// the right.
class _PanelHeader extends StatelessWidget {
  final String title;
  final ColorScheme colors;
  final VoidCallback onClose;
  final Widget grip;

  const _PanelHeader({
    required this.title,
    required this.colors,
    required this.onClose,
    required this.grip,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          grip,
          Tooltip(
            message: loc.closePanel,
            child: InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 30,
                height: 30,
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// A small horizontal-drag grip used to move a panel to the other side.
class _Grip extends StatefulWidget {
  final VoidCallback? onDragRight;
  final VoidCallback? onDragLeft;
  final String tooltip;

  const _Grip({this.onDragRight, this.onDragLeft, required this.tooltip});

  @override
  State<_Grip> createState() => _GripState();
}

class _GripState extends State<_Grip> {
  double _accumDx = 0;
  bool _hovered = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = _hovered || _dragging;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: _dragging
            ? SystemMouseCursors.grabbing
            : (_hovered ? SystemMouseCursors.grab : SystemMouseCursors.basic),
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) {
            _accumDx = 0;
            setState(() => _dragging = true);
          },
          onHorizontalDragUpdate: (d) {
            _accumDx += d.delta.dx;
          },
          onHorizontalDragEnd: (d) {
            setState(() => _dragging = false);
            final velocity = d.primaryVelocity ?? 0;
            if ((_accumDx > 80 || velocity > 300) &&
                widget.onDragRight != null) {
              widget.onDragRight!();
            } else if ((_accumDx < -80 || velocity < -300) &&
                widget.onDragLeft != null) {
              widget.onDragLeft!();
            }
          },
          onHorizontalDragCancel: () {
            setState(() => _dragging = false);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active
                  ? colors.primaryContainer.withValues(alpha: 0.35)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.drag_indicator,
              size: 16,
              color: active ? colors.primary : colors.outline,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  DIVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// A draggable vertical divider between a side panel and the main area.
class _PanelDivider extends StatefulWidget {
  final bool visible;
  final int sign;
  final double Function() currentWidth;
  final ValueChanged<double> onWidthChanged;
  final VoidCallback onDragEnd;

  const _PanelDivider({
    super.key,
    required this.visible,
    required this.sign,
    required this.currentWidth,
    required this.onWidthChanged,
    required this.onDragEnd,
  });

  @override
  State<_PanelDivider> createState() => _PanelDividerState();
}

class _ActivityRailDivider extends StatelessWidget {
  final bool visible;

  const _ActivityRailDivider({required this.visible});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 1,
      color: visible
          ? colors.outlineVariant.withValues(alpha: 0.7)
          : Colors.transparent,
    );
  }
}

class _PanelDividerState extends State<_PanelDivider> {
  double _startWidth = 0;
  double _accumDx = 0;

  void _onDragStart(DragStartDetails details) {
    _startWidth = widget.currentWidth();
    _accumDx = 0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _accumDx += details.delta.dx;
    widget.onWidthChanged(_startWidth + widget.sign * _accumDx);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: widget.visible ? _kDividerWidth : 0,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: (_) => widget.onDragEnd(),
          child: Container(
            color: Colors.transparent,
            alignment: Alignment.center,
            child: widget.visible
                ? Container(
                    width: 2,
                    height: 28,
                    decoration: BoxDecoration(
                      color: colors.outlineVariant.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CENTER TABS
// ═══════════════════════════════════════════════════════════════════════════

/// The center-area tab strip: Reading (the books) and Vīmaṃsā.
class _CenterTabs extends StatelessWidget {
  final ColorScheme colors;
  final bool vimamsaSelected;
  final String readingLabel;
  final String vimamsaLabel;
  final VoidCallback onReadingTap;
  final VoidCallback onVimamsaTap;

  const _CenterTabs({
    required this.colors,
    required this.vimamsaSelected,
    required this.readingLabel,
    required this.vimamsaLabel,
    required this.onReadingTap,
    required this.onVimamsaTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget tab({
      required String label,
      required IconData icon,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 36,
            alignment: Alignment.center,
            decoration: selected
                ? BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.15),
                    border: Border(
                      bottom: BorderSide(color: colors.primary, width: 2),
                    ),
                  )
                : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? colors.primary : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: colors.surface,
      child: Row(
        children: [
          tab(
            label: readingLabel,
            icon: Icons.menu_book_outlined,
            selected: !vimamsaSelected,
            onTap: onReadingTap,
          ),
          tab(
            label: vimamsaLabel,
            icon: Icons.auto_awesome_outlined,
            selected: vimamsaSelected,
            onTap: onVimamsaTap,
          ),
        ],
      ),
    );
  }
}
