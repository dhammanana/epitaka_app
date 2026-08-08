import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/settings_provider.dart';
import '../../core/utils/app_localizations.dart';
import '../../features/reader/providers/reader_tabs_provider.dart';
import '../../shared/providers/side_panel_provider.dart';
import '../../shared/widgets/reader_toolbar_controller.dart';
import '../ai_qa/screens/ai_qa_screen.dart';
import '../contents/widgets/contents_panel.dart';
import '../dictionary/widgets/dictionary_panel.dart';
import '../gavesana/widgets/gavesana_panel.dart';
import '../library/widgets/bookmarks_panel.dart';
import '../library/widgets/history_panel.dart';
import '../library/widgets/library_panel.dart';
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

/// Horizontal drag distance (px) that commits a "move to the other side".
const double _kDragCommitDx = 80;

/// The desktop shell shown instead of the mobile layout on desktop platforms.
///
/// ```
/// ┌────┬──────────────┬───────────────────────┬──────────────┐
/// │    │ Sidebar      │ Reader │ Vimaṃsa      │ Right panel  │
/// │ Act│ (one panel   │ (center tabs)         │ (dictionary  │
/// │ Bar│  at a time)  │                       │  or sidebar) │
/// │    │ ┌──────────┐ │                       │              │
/// │    │ │ Library /│ │                       │              │
/// │    │ │ Search / │ │                       │              │
/// │    │ │ History /│ │                       │              │
/// │    │ │ Bookmarks│ │                       │              │
/// │    │ ├──────────┤ │                       │              │
/// │    │ │ Dict dock│ │                       │              │
/// │    │ └──────────┘ │                       │              │
/// ├────┴──────────────┴───────────────────────┴──────────────┤
/// │ Status bar (reader toolbar)                               │
/// └───────────────────────────────────────────────────────────┘
/// ```
///
/// * **Sidebar** — the activity-bar items (library, search, history,
///   bookmarks, contents, gavesana) open the sidebar next to the rail one
///   at a time (clicking another item replaces the previous one; clicking
///   the active item closes the sidebar). It starts closed.
/// * **Dictionary dock** — by default the dictionary is docked at the
///   bottom of the sidebar, so it collapses with it. It can be dragged
///   (via its grip) to the right side, where it becomes an independent
///   panel that is not affected by the sidebar collapse. Dragging it back
///   returns it to the dock.
/// * **Sidebar drag** — the sidebar can be dragged to the right side of
///   the window (grip in its header), where it stays open independently.
/// * **Center** — only the reader (books) and Vimaṃsa live here, as two
///   tabs.
/// * Panels are resizable via the draggable dividers; widths persist via
///   [settingsProvider] (`leftPanelWidth` / `rightPanelWidth`).
/// * The layout state (open panel, dictionary/sidebar placement, Vimaṃsa
///   tab) is derived from / synced with [sidePanelProvider], so keyboard
///   shortcuts (Cmd/Ctrl+D, Cmd/Ctrl+Shift+F) and the reader toolbar keep
///   working.
class DesktopShell extends ConsumerStatefulWidget {
  /// The main content (the reader). Shown in the center "Reading" tab.
  final Widget child;

  const DesktopShell({super.key, required this.child});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  /// Bridges the reader's toolbar actions to the attached status bar.
  final ReaderToolbarController _toolbarController =
      ReaderToolbarController();

  /// Whether the center tab shows Vimaṃsa instead of the reader.
  bool _vimamsaOpen = false;

  /// Whether the sidebar is docked on the right side of the window.
  bool _sidebarOnRight = false;

  /// Whether the dictionary lives as an independent right-side panel
  /// (vs. docked at the bottom of the sidebar).
  bool _dictOnRight = false;

  /// Set right before the activity-bar opens the dictionary docked in the
  /// sidebar, so the [sidePanelProvider] listener doesn't re-place it on
  /// the right.
  bool _pendingDockPlacement = false;

  double _leftWidth = _kDefaultLeftWidth;
  double _rightWidth = _kDefaultRightWidth;

  @override
  void initState() {
    super.initState();
    // Load persisted widths once settings are available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = ref.read(settingsProvider);
      setState(() {
        _leftWidth =
            s.leftPanelWidth > 0 ? s.leftPanelWidth : _kDefaultLeftWidth;
        _rightWidth =
            s.rightPanelWidth > 0 ? s.rightPanelWidth : _kDefaultRightWidth;
      });
    });
  }

  @override
  void dispose() {
    _toolbarController.dispose();
    super.dispose();
  }

  // ── Sidebar / dictionary toggling ─────────────────────────────────

  void _toggleSidebar(SidePanelType panel) {
    ref.read(sidePanelProvider.notifier).toggle(panel);
  }

  /// Activity-bar dictionary button: toggles the dictionary docked at the
  /// bottom of the sidebar (opening the sidebar first if it's closed).
  void _toggleDictionary() {
    final notifier = ref.read(sidePanelProvider.notifier);
    final panels = ref.read(sidePanelProvider);
    final dictVisible = panels.right.openPanel == SidePanelType.dictionary;
    if (dictVisible) {
      notifier.close(SidePanelType.dictionary);
      return;
    }
    _pendingDockPlacement = true;
    setState(() => _dictOnRight = false);
    notifier.open(SidePanelType.dictionary, pin: true);
    // The dock lives inside the sidebar — make sure it's visible.
    if (ref.read(sidePanelProvider).left.openPanel == null) {
      notifier.open(SidePanelType.library);
    }
  }

  void _moveDictToRight() {
    if (_sidebarOnRight) return; // the dict rides inside the sidebar
    setState(() => _dictOnRight = true);
  }

  void _moveDictToLeft() {
    setState(() => _dictOnRight = false);
    // The dock lives inside the sidebar — make sure it's visible.
    if (ref.read(sidePanelProvider).left.openPanel == null) {
      ref.read(sidePanelProvider.notifier).open(SidePanelType.library);
    }
  }

  void _moveSidebarToRight() {
    setState(() {
      _sidebarOnRight = true;
      _dictOnRight = false; // the dictionary travels with the sidebar
    });
  }

  void _moveSidebarToLeft() {
    setState(() => _sidebarOnRight = false);
  }

  void resetLayout() {
    setState(() {
      _sidebarOnRight = false;
      _dictOnRight = false;
      _vimamsaOpen = false;
      _leftWidth = _kDefaultLeftWidth;
      _rightWidth = _kDefaultRightWidth;
    });
    ref.read(sidePanelProvider.notifier).closeAll();
    ref.read(settingsProvider.notifier).setLeftPanelWidth(0);
    ref.read(settingsProvider.notifier).setRightPanelWidth(0);
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

  /// Builds a [DesktopSidebar] (used for both the left and the right slot).
  Widget _buildSidebar({
    required SidePanelType panel,
    required String title,
    required bool onRight,
    required bool autoFocus,
    required bool showDictionaryDock,
  }) {
    return DesktopSidebar(
      panel: panel,
      title: title,
      onRight: onRight,
      autoFocus: autoFocus,
      showDictionaryDock: showDictionaryDock,
      onClose: () => _toggleSidebar(panel),
      onMoveSidebarRight: _moveSidebarToRight,
      onMoveSidebarLeft: _moveSidebarToLeft,
      onCloseDictionary: () => ref
          .read(sidePanelProvider.notifier)
          .close(SidePanelType.dictionary),
      onMoveDictionaryToRight: _moveDictToRight,
      onMoveDictionaryToLeft: _moveDictToLeft,
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
      case SidePanelType.bookmarks:
        return loc.bookmarks;
      case SidePanelType.contents:
        return loc.contents;
      case SidePanelType.gavesana:
        return loc.gavesana;
      case SidePanelType.dictionary:
        return loc.dictionary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final panels = ref.watch(sidePanelProvider);
    final left = panels.left.openPanel;
    final dictVisible = panels.right.openPanel == SidePanelType.dictionary;
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    final showLeftSidebar = left != null && !_sidebarOnRight;
    final showRightPanel =
        (_sidebarOnRight && left != null) || (_dictOnRight && dictVisible);
    final rightIsSidebar = _sidebarOnRight && left != null;
    final showDictDock = dictVisible && !_dictOnRight && left != null;

    // Provider-driven panel changes (shortcuts, reader toolbar, dialogs).
    ref.listen(sidePanelProvider, (prev, next) {
      if (!mounted) return;
      final prevRight = prev?.right.openPanel;
      final nextRight = next.right.openPanel;
      final prevLeft = prev?.left.openPanel;
      final nextLeft = next.left.openPanel;

      // A dictionary opened through the provider (Cmd/Ctrl+D, toolbar,
      // word lookup) becomes an independent right-side panel — unless the
      // activity bar just opened it docked in the sidebar.
      if (nextRight == SidePanelType.dictionary &&
          prevRight != SidePanelType.dictionary) {
        if (_pendingDockPlacement) {
          _pendingDockPlacement = false;
        } else {
          // Provider-driven open (word lookup, Cmd/Ctrl+D, toolbar):
          // dock in the sidebar when it's open, otherwise show as the
          // independent right column.
          setState(() => _dictOnRight = nextLeft == null);
        }
        // Keep the dictionary pinned wherever it is placed (docked or
        // right panel) so the reader's word-lookup routes into it instead
        // of the bottom sheet. `setPinned` only flips the flag, leaving
        // any pending word (panelData) untouched.
        if (!next.right.isPinned) {
          ref
              .read(sidePanelProvider.notifier)
              .setPinned(SidePanelType.dictionary, true);
        }
      }
      // The dictionary dock collapses together with the sidebar: if the
      // sidebar closes while the dictionary is still docked in it, close
      // the dictionary too.
      if (nextLeft == null &&
          prevLeft != null &&
          !_dictOnRight &&
          nextRight == SidePanelType.dictionary) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref
                .read(sidePanelProvider.notifier)
                .close(SidePanelType.dictionary);
          }
        });
      }
    });

    // Opening a book while Vimaṃsa is showing returns to the reader.
    ref.listen(readerTabsProvider, (prev, next) {
      if (!mounted) return;
      if (_vimamsaOpen && next.tabs.length > (prev?.tabs.length ?? 0)) {
        setState(() => _vimamsaOpen = false);
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
                    dictionaryVisible: dictVisible,
                    vimamsaActive: _vimamsaOpen,
                    onToggleSidebar: _toggleSidebar,
                    onToggleDictionary: _toggleDictionary,
                    onToggleVimamsa: () =>
                        setState(() => _vimamsaOpen = !_vimamsaOpen),
                    onResetLayout: resetLayout,
                    onOpenSettings: () => showSettingsDialog(context),
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
                            showDictionaryDock: showDictDock,
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
                  // Center: reader + Vimaṃsa tabs
                  Expanded(child: _buildCenter(context, colors, loc)),
                  // Right divider + panel
                  _PanelDivider(
                    key: const Key('right-panel-divider'),
                    visible: showRightPanel,
                    sign: -1,
                    currentWidth: () => _rightWidth,
                    onWidthChanged: (w) =>
                        setState(() => _rightWidth = _clampRight(w)),
                    onDragEnd: _persistWidths,
                  ),
                  Container(
                    width: showRightPanel ? _rightWidth : 0,
                    child: showRightPanel
                        ? rightIsSidebar
                              ? _buildSidebar(
                                  panel: left,
                                  title: _panelTitle(left, loc),
                                  onRight: true,
                                  autoFocus: panels.left.autoFocus,
                                  showDictionaryDock: showDictDock,
                                )
                              : _RightDictionaryPanel(
                                  autoFocus: panels.right.autoFocus,
                                  onClose: () => ref
                                      .read(sidePanelProvider.notifier)
                                      .close(SidePanelType.dictionary),
                                  onMoveToLeft: _moveDictToLeft,
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
    return ReaderToolbarScope(
      controller: _toolbarController,
      child: Column(
        children: [
          _CenterTabs(
            colors: colors,
            vimamsaSelected: _vimamsaOpen,
            readingLabel: loc.reading,
            vimamsaLabel: loc.vimamsa,
            onReadingTap: () => setState(() => _vimamsaOpen = false),
            onVimamsaTap: () => setState(() => _vimamsaOpen = true),
          ),
          Divider(height: 1, color: colors.outlineVariant),
          Expanded(
            child: IndexedStack(
              index: _vimamsaOpen ? 1 : 0,
              children: [
                widget.child,
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

/// The single sidebar panel: a header (title + drag grip + close), the
/// active panel content on top, and the dictionary dock at the bottom.
class DesktopSidebar extends StatelessWidget {
  final SidePanelType panel;
  final String title;
  final bool onRight;
  final bool autoFocus;
  final bool showDictionaryDock;
  final VoidCallback onClose;
  final VoidCallback onMoveSidebarRight;
  final VoidCallback onMoveSidebarLeft;
  final VoidCallback onCloseDictionary;
  final VoidCallback onMoveDictionaryToRight;
  final VoidCallback onMoveDictionaryToLeft;

  const DesktopSidebar({
    super.key,
    required this.panel,
    required this.title,
    required this.onRight,
    required this.autoFocus,
    required this.showDictionaryDock,
    required this.onClose,
    required this.onMoveSidebarRight,
    required this.onMoveSidebarLeft,
    required this.onCloseDictionary,
    required this.onMoveDictionaryToRight,
    required this.onMoveDictionaryToLeft,
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
          // Top zone: the active sidebar item (one at a time).
          Expanded(flex: 5, child: _panelContent(context)),
          if (showDictionaryDock) ...[
            Divider(height: 1, color: colors.outlineVariant),
            // Dictionary docked at the bottom (collapses with the sidebar).
            Expanded(
              flex: 4,
              child: _DictionaryDock(
                onClose: onCloseDictionary,
                onMoveToRight: onMoveDictionaryToRight,
                onMoveToLeft: onMoveDictionaryToLeft,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _panelContent(BuildContext context) {
    switch (panel) {
      case SidePanelType.library:
        return const LibraryPanel();
      case SidePanelType.search:
        return SearchPanel(autoFocus: autoFocus);
      case SidePanelType.history:
        return const HistoryPanel();
      case SidePanelType.bookmarks:
        return const BookmarksPanel();
      case SidePanelType.contents:
        return const ContentsPanel();
      case SidePanelType.gavesana:
        return const GavesanaPanel();
      case SidePanelType.dictionary:
        return const SizedBox.shrink();
    }
  }
}

/// The dictionary dock shown at the bottom of the sidebar (or as the
/// independent right-side panel). Drag its grip to move it to the other
/// side of the window.
class _DictionaryDock extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onMoveToRight;
  final VoidCallback onMoveToLeft;

  const _DictionaryDock({
    required this.onClose,
    required this.onMoveToRight,
    required this.onMoveToLeft,
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
            title: loc.dictionary,
            colors: colors,
            onClose: onClose,
            grip: _Grip(
              onDragRight: onMoveToRight,
              onDragLeft: onMoveToLeft,
              tooltip: loc.t('Move dictionary to the right'),
            ),
          ),
          Divider(height: 1, color: colors.outlineVariant),
          Expanded(child: const DictionaryPanel()),
        ],
      ),
    );
  }
}

/// The dictionary as an independent right-side panel (dragged there from
/// the sidebar dock). Dragging its grip left returns it to the dock.
class _RightDictionaryPanel extends StatelessWidget {
  final bool autoFocus;
  final VoidCallback onClose;
  final VoidCallback onMoveToLeft;

  const _RightDictionaryPanel({
    required this.autoFocus,
    required this.onClose,
    required this.onMoveToLeft,
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
            title: loc.dictionary,
            colors: colors,
            onClose: onClose,
            grip: _Grip(
              onDragLeft: onMoveToLeft,
              tooltip: loc.t('Dock dictionary in the sidebar'),
            ),
          ),
          Divider(height: 1, color: colors.outlineVariant),
          Expanded(child: DictionaryPanel(autoFocus: autoFocus)),
        ],
      ),
    );
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

/// A small horizontal-drag grip. A committed drag to the right calls
/// [onDragRight], to the left [onDragLeft] (based on distance/velocity).
class _Grip extends StatefulWidget {
  final VoidCallback? onDragRight;
  final VoidCallback? onDragLeft;
  final String tooltip;

  const _Grip({
    this.onDragRight,
    this.onDragLeft,
    required this.tooltip,
  });

  @override
  State<_Grip> createState() => _GripState();
}

class _GripState extends State<_Grip> {
  double _accumDx = 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => _accumDx = 0,
          onHorizontalDragUpdate: (d) => _accumDx += d.delta.dx,
          onHorizontalDragEnd: (d) {
            final velocity = d.primaryVelocity ?? 0;
            if ((_accumDx > _kDragCommitDx || velocity > 300) &&
                widget.onDragRight != null) {
              widget.onDragRight!();
            } else if ((_accumDx < -_kDragCommitDx || velocity < -300) &&
                widget.onDragLeft != null) {
              widget.onDragLeft!();
            }
          },
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            child: Icon(
              Icons.drag_indicator,
              size: 16,
              color: colors.outline,
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
///
/// [sign] controls the resize direction: +1 means dragging left shrinks
/// the panel (panel on the left), -1 means dragging left grows it (panel
/// on the right). The divider is 12px wide when [visible] and collapses to
/// zero (not hit-testable) otherwise.
class _PanelDivider extends StatefulWidget {
  final bool visible;

  /// +1: width = start + dx · -1: width = start − dx.
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

/// The center-area tab strip: Reading (the books) and Vimaṃsa.
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
