import 'dart:math' as math;

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

/// Fraction of the sidebar height the docked dictionary takes by default
/// (before the user resizes it). Sized so the dictionary clearly dominates
/// the sidebar ("show it in the sidebar", not a small bottom strip).
const double _kDefaultDockFraction = 0.7;

/// The docked dictionary's height can be dragged between these fractions
/// of the sidebar height.
const double _kMinDockFraction = 0.25;
const double _kMaxDockFraction = 0.85;

/// Horizontal drag distance (px) that commits a "move to the other side".
const double _kDragCommitDx = 80;

/// Duration of the dictionary panel's fly-out / slide-in / spring-back
/// animations when it moves between the sidebar dock and the right column.
const Duration _kDictMoveDuration = Duration(milliseconds: 240);

/// Grace period after the fly-out before the layout swap runs. Kept longer
/// than [_kDictMoveDuration] so the exit animation visually finishes before
/// the panel is re-placed on the other side.
const Duration _kDictSwapDelay = Duration(milliseconds: 280);

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
///   bottom of the sidebar, so it collapses with it. Its height can be
///   resized by dragging the divider above it, and it can be dragged (via
///   its grip) to the right side, where it becomes an independent panel
///   that is not affected by the sidebar collapse. Dragging it back
///   returns it to the dock.
/// * **Saved placement** — where the user last put the dictionary (dock
///   vs. right column), the dock's height, and whether the sidebar sits on
///   the right are all persisted, so word lookups reopen the dictionary
///   where the user left it instead of forcing one position.
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

  /// Fraction (0..1) of the sidebar height the docked dictionary occupies.
  double _dictDockFraction = _kDefaultDockFraction;

  /// Live horizontal slide (fraction of the visible dictionary panel's
  /// width) applied while its grip is dragged, plus the fly-out / slide-in
  /// offsets used when a committed move lands on the other side.
  double _dictSlideX = 0;

  /// Whether a dictionary grip drag is in progress — while true the
  /// [AnimatedSlide] previews follow the pointer instantly (zero duration);
  /// when false, settle animations run.
  bool _dictDragging = false;

  /// Invalidates pending fly-out / swap callbacks when a new drag starts or
  /// the placement changes, so a stale animation can't clobber a newer one.
  int _dictSettleToken = 0;

  /// Set right before the activity-bar opens the dictionary docked in the
  /// sidebar, so the [sidePanelProvider] listener doesn't re-place it on
  /// the right.
  bool _pendingDockPlacement = false;

  double _leftWidth = _kDefaultLeftWidth;
  double _rightWidth = _kDefaultRightWidth;

  @override
  void initState() {
    super.initState();
    // Load persisted widths / placements once settings are available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = ref.read(settingsProvider);
      setState(() {
        _leftWidth =
            s.leftPanelWidth > 0 ? s.leftPanelWidth : _kDefaultLeftWidth;
        _rightWidth =
            s.rightPanelWidth > 0 ? s.rightPanelWidth : _kDefaultRightWidth;
        _dictOnRight = s.dictOnRight;
        _sidebarOnRight = s.sidebarOnRight;
        _dictDockFraction = s.dictionaryDockFraction > 0
            ? s.dictionaryDockFraction
            : _kDefaultDockFraction;
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

  /// Activity-bar dictionary button: toggles the dictionary, honoring where
  /// the user last placed it (docked in the sidebar, or the right column)
  /// instead of always forcing one position.
  void _toggleDictionary() {
    final notifier = ref.read(sidePanelProvider.notifier);
    final panels = ref.read(sidePanelProvider);
    final dictVisible = panels.right.openPanel == SidePanelType.dictionary;
    if (dictVisible) {
      notifier.close(SidePanelType.dictionary);
      return;
    }
    // Set the placement ourselves so the [sidePanelProvider] listener
    // doesn't re-place it based on the current sidebar state. When the
    // sidebar sits on the right, the dictionary rides inside it;
    // otherwise honor the saved placement (dock or right column).
    _pendingDockPlacement = true;
    _dictSettleToken++;
    if (_dictSlideX != 0 || _dictDragging) {
      setState(() {
        _dictSlideX = 0;
        _dictDragging = false;
      });
    }
    if (_sidebarOnRight) {
      setState(() => _dictOnRight = false);
    }
    // When docked, the dock lives inside the sidebar — make sure it's open.
    if (!_dictOnRight && panels.left.openPanel == null) {
      notifier.open(SidePanelType.library);
    }
    notifier.open(SidePanelType.dictionary, pin: true);
  }

  /// Place the dictionary after a provider-driven open (word lookup,
  /// Cmd/Ctrl+D, reader toolbar), honoring where the user last put it
  /// ([_dictOnRight] / [_sidebarOnRight], persisted) rather than forcing
  /// one position.
  void _placeDictionary({required bool sidebarOpen}) {
    _dictSettleToken++; // cancel any in-flight grip animation
    setState(() {
      if (_sidebarOnRight) {
        // The dictionary rides inside the sidebar. If the sidebar (which
        // sits on the right) is closed, fall back to the right column.
        _dictOnRight = !sidebarOpen;
      } else if (!_dictOnRight && !sidebarOpen) {
        // Saved dock placement, but the sidebar is closed — the dock only
        // exists inside the sidebar, so show the right column for now.
        // Deliberately NOT persisted: the user's saved dock preference
        // survives restarts; this fallback only applies for the current
        // session until they drag the dictionary again.
        _dictOnRight = true;
      }
      // _dictOnRight == true → keep the dictionary as the right column.
      // _dictOnRight == false && sidebar open → docked in the sidebar.
      // Provider-driven opens are not animated.
      _dictSlideX = 0;
      _dictDragging = false;
    });
  }

  /// Persist the dictionary/sidebar placement ("save where it was").
  void _persistPlacement() {
    final notifier = ref.read(settingsProvider.notifier);
    notifier.setDictOnRight(_dictOnRight);
    notifier.setSidebarOnRight(_sidebarOnRight);
  }

  /// Live dictionary-panel preview while its grip is dragged: the visible
  /// panel (dock or right column) follows the pointer's horizontal offset.
  void _onDictDragUpdate(double dx) {
    _dictSettleToken++; // a new drag supersedes any pending fly-out/swap
    final width = _dictOnRight ? _rightWidth : _leftWidth;
    setState(() {
      _dictDragging = true;
      _dictSlideX = dx / width;
    });
  }

  /// Spring the dictionary panel back into place when a grip drag is
  /// cancelled (or doesn't reach the commit threshold).
  void _onDictDragCancel() {
    setState(() {
      _dictDragging = false;
      _dictSlideX = 0;
    });
  }

  void _moveDictToRight() {
    if (_sidebarOnRight) {
      // The dict rides inside the sidebar — spring the preview back.
      _onDictDragCancel();
      return;
    }
    final token = ++_dictSettleToken;
    // Fly the dock out to the right, then land it as the right column.
    setState(() {
      _dictDragging = false;
      _dictSlideX = 2.0;
    });
    Future.delayed(_kDictSwapDelay, () {
      if (!mounted || _dictSettleToken != token) return;
      setState(() {
        _dictOnRight = true;
        // The right panel starts off-screen to the left and slides in.
        _dictSlideX = -1.0;
      });
      _persistPlacement();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _dictSlideX = 0.0); // slide into place
      });
    });
  }

  void _moveDictToLeft() {
    final token = ++_dictSettleToken;
    // Fly the right panel out to the left, then land it back in the dock.
    setState(() {
      _dictDragging = false;
      _dictSlideX = -2.0;
    });
    Future.delayed(_kDictSwapDelay, () {
      if (!mounted || _dictSettleToken != token) return;
      setState(() {
        _dictOnRight = false;
        // The dock starts off-screen to the right and slides in.
        _dictSlideX = 1.0;
      });
      // The dock lives inside the sidebar — make sure it's visible.
      if (ref.read(sidePanelProvider).left.openPanel == null) {
        ref.read(sidePanelProvider.notifier).open(SidePanelType.library);
      }
      _persistPlacement();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _dictSlideX = 0.0); // slide into place
      });
    });
  }

  void _moveSidebarToRight() {
    setState(() {
      _sidebarOnRight = true;
      _dictOnRight = false; // the dictionary travels with the sidebar
    });
    _persistPlacement();
  }

  void _moveSidebarToLeft() {
    setState(() => _sidebarOnRight = false);
    _persistPlacement();
  }

  void resetLayout() {
    _dictSettleToken++;
    setState(() {
      _sidebarOnRight = false;
      _dictOnRight = false;
      _vimamsaOpen = false;
      _leftWidth = _kDefaultLeftWidth;
      _rightWidth = _kDefaultRightWidth;
      _dictDockFraction = _kDefaultDockFraction;
      _dictSlideX = 0;
      _dictDragging = false;
    });
    ref.read(sidePanelProvider.notifier).closeAll();
    ref.read(settingsProvider.notifier).setLeftPanelWidth(0);
    ref.read(settingsProvider.notifier).setRightPanelWidth(0);
    ref.read(settingsProvider.notifier).setDictOnRight(false);
    ref.read(settingsProvider.notifier).setSidebarOnRight(false);
    ref
        .read(settingsProvider.notifier)
        .setDictionaryDockFraction(_kDefaultDockFraction);
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
      dictDockFraction: _dictDockFraction,
      onDictDockResize: (fraction) =>
          setState(() => _dictDockFraction = fraction),
      onDictDockResizeEnd: () => ref
          .read(settingsProvider.notifier)
          .setDictionaryDockFraction(_dictDockFraction),
      dictSlideX: _dictSlideX,
      dictDragging: _dictDragging,
      onDictDragUpdate: _onDictDragUpdate,
      onDictDragCancel: _onDictDragCancel,
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

      // A dictionary opened through the provider (word lookup, Cmd/Ctrl+D,
      // toolbar, activity bar) is placed where the user last had it — the
      // activity bar pre-sets the placement and marks it pending; every
      // other path goes through [_placeDictionary].
      if (nextRight == SidePanelType.dictionary &&
          prevRight != SidePanelType.dictionary) {
        if (_pendingDockPlacement) {
          _pendingDockPlacement = false;
        } else {
          _placeDictionary(sidebarOpen: nextLeft != null);
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
      // When the dictionary closes, reset any in-flight slide animation so
      // a later reopen doesn't show the panel offset.
      if (prevRight == SidePanelType.dictionary &&
          nextRight != SidePanelType.dictionary) {
        _dictSettleToken++;
        if (_dictSlideX != 0 || _dictDragging) {
          setState(() {
            _dictSlideX = 0;
            _dictDragging = false;
          });
        }
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
                                  dictSlideX: _dictSlideX,
                                  dictDragging: _dictDragging,
                                  onDragUpdate: _onDictDragUpdate,
                                  onDragCancel: _onDictDragCancel,
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
/// The dock's height is resizable by dragging the divider above it; the
/// chosen height (as a fraction of the sidebar) is reported back to the
/// shell so it can be persisted.
class DesktopSidebar extends StatelessWidget {
  final SidePanelType panel;
  final String title;
  final bool onRight;
  final bool autoFocus;
  final bool showDictionaryDock;

  /// Fraction (0..1) of the sidebar height the docked dictionary occupies.
  final double dictDockFraction;

  /// Called while the dock divider is dragged, with the new height fraction.
  final ValueChanged<double> onDictDockResize;

  /// Called when the dock divider drag ends (persist the height).
  final VoidCallback onDictDockResizeEnd;

  /// Horizontal slide fraction applied to the docked dictionary while its
  /// grip is dragged or while it flies out / slides in on a committed move.
  final double dictSlideX;

  /// Whether the dictionary grip is currently being dragged (previews the
  /// move instantly instead of animating).
  final bool dictDragging;

  final ValueChanged<double> onDictDragUpdate;
  final VoidCallback onDictDragCancel;

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
    required this.dictDockFraction,
    required this.onDictDockResize,
    required this.onDictDockResizeEnd,
    required this.dictSlideX,
    required this.dictDragging,
    required this.onDictDragUpdate,
    required this.onDictDragCancel,
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxHeight = math.max(1.0, constraints.maxHeight);
          // The dock can be resized between ~a quarter and ~80% of the
          // sidebar height (with a floor so it never collapses entirely).
          final minPx = math.min(140.0, maxHeight * _kMinDockFraction);
          final maxPx = maxHeight * _kMaxDockFraction;
          final dockPx = (dictDockFraction * maxHeight)
              .clamp(minPx, maxPx)
              .toDouble();

          return Column(
            children: [
              _PanelHeader(
                title: title,
                colors: colors,
                onClose: onClose,
                grip: _Grip(
                  onDragRight: onMoveSidebarRight,
                  onDragLeft: onMoveSidebarLeft,
                  tooltip: loc.t(
                    onRight
                        ? 'Move panel to the left'
                        : 'Move panel to the right',
                  ),
                ),
              ),
              Divider(height: 1, color: colors.outlineVariant),
              // Top zone: the active sidebar item (one at a time).
              Expanded(child: _panelContent(context)),
              if (showDictionaryDock) ...[
                // The whole dock section (resize divider + dictionary)
                // slides horizontally with the grip drag / move animation.
                AnimatedSlide(
                  offset: Offset(dictSlideX, 0),
                  duration: dictDragging
                      ? Duration.zero
                      : _kDictMoveDuration,
                  curve: Curves.easeOutCubic,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Draggable divider — resizes the docked dictionary's
                      // height. Dragging up grows the dictionary.
                      _DockResizeDivider(
                        key: const Key('dict-dock-divider'),
                        currentHeight: () => dockPx,
                        onHeightChanged: (px) => onDictDockResize(
                          (px / maxHeight).clamp(0.0, 1.0),
                        ),
                        onDragEnd: onDictDockResizeEnd,
                      ),
                      // Dictionary docked at the bottom (collapses with
                      // the sidebar).
                      SizedBox(
                        height: dockPx,
                        child: _DictionaryDock(
                          onClose: onCloseDictionary,
                          onMoveToRight: onMoveDictionaryToRight,
                          onMoveToLeft: onMoveDictionaryToLeft,
                          onDragUpdate: onDictDragUpdate,
                          onDragCancel: onDictDragCancel,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
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
  final ValueChanged<double> onDragUpdate;
  final VoidCallback onDragCancel;

  const _DictionaryDock({
    required this.onClose,
    required this.onMoveToRight,
    required this.onMoveToLeft,
    required this.onDragUpdate,
    required this.onDragCancel,
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
              onDragUpdate: onDragUpdate,
              onDragCancel: onDragCancel,
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
  final double dictSlideX;
  final bool dictDragging;
  final ValueChanged<double> onDragUpdate;
  final VoidCallback onDragCancel;

  const _RightDictionaryPanel({
    required this.autoFocus,
    required this.onClose,
    required this.onMoveToLeft,
    required this.dictSlideX,
    required this.dictDragging,
    required this.onDragUpdate,
    required this.onDragCancel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    return AnimatedSlide(
      offset: Offset(dictSlideX, 0),
      duration: dictDragging ? Duration.zero : _kDictMoveDuration,
      curve: Curves.easeOutCubic,
      child: Container(
        color: colors.surfaceContainerLowest,
        child: Column(
          children: [
            _PanelHeader(
              title: loc.dictionary,
              colors: colors,
              onClose: onClose,
              grip: _Grip(
                onDragLeft: onMoveToLeft,
                onDragUpdate: onDragUpdate,
                onDragCancel: onDragCancel,
                tooltip: loc.t('Dock dictionary in the sidebar'),
              ),
            ),
            Divider(height: 1, color: colors.outlineVariant),
            Expanded(child: DictionaryPanel(autoFocus: autoFocus)),
          ],
        ),
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

/// A small horizontal-drag grip used to move a panel to the other side of
/// the window. Hovering highlights it and shows a grab cursor; while
/// dragging the live horizontal offset is reported via [onDragUpdate] so
/// the shell can preview the move (and the cursor becomes a closed grab).
/// A committed drag to the right calls [onDragRight], to the left
/// [onDragLeft] (based on distance/velocity); otherwise [onDragCancel] is
/// called so the preview can spring back.
class _Grip extends StatefulWidget {
  final VoidCallback? onDragRight;
  final VoidCallback? onDragLeft;
  final ValueChanged<double>? onDragUpdate;
  final VoidCallback? onDragCancel;
  final String tooltip;

  const _Grip({
    this.onDragRight,
    this.onDragLeft,
    this.onDragUpdate,
    this.onDragCancel,
    required this.tooltip,
  });

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
            widget.onDragUpdate?.call(0);
          },
          onHorizontalDragUpdate: (d) {
            _accumDx += d.delta.dx;
            widget.onDragUpdate?.call(_accumDx);
          },
          onHorizontalDragEnd: (d) {
            setState(() => _dragging = false);
            final velocity = d.primaryVelocity ?? 0;
            if ((_accumDx > _kDragCommitDx || velocity > 300) &&
                widget.onDragRight != null) {
              widget.onDragRight!();
            } else if ((_accumDx < -_kDragCommitDx || velocity < -300) &&
                widget.onDragLeft != null) {
              widget.onDragLeft!();
            } else {
              widget.onDragCancel?.call();
            }
          },
          onHorizontalDragCancel: () {
            setState(() => _dragging = false);
            widget.onDragCancel?.call();
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

/// A draggable horizontal divider between the sidebar's top panel and the
/// docked dictionary. Dragging it up/down resizes the dictionary's height.
class _DockResizeDivider extends StatefulWidget {
  /// Returns the dictionary dock's current pixel height (clamped) so the
  /// drag can accumulate deltas against a stable start value.
  final double Function() currentHeight;

  /// Called while dragging, with the new desired dock height in pixels.
  final ValueChanged<double> onHeightChanged;

  /// Called when the drag ends (persist the height).
  final VoidCallback onDragEnd;

  const _DockResizeDivider({
    super.key,
    required this.currentHeight,
    required this.onHeightChanged,
    required this.onDragEnd,
  });

  @override
  State<_DockResizeDivider> createState() => _DockResizeDividerState();
}

class _DockResizeDividerState extends State<_DockResizeDivider> {
  double _startHeight = 0;
  double _accumDy = 0;

  void _onDragStart(DragStartDetails details) {
    _startHeight = widget.currentHeight();
    _accumDy = 0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _accumDy += details.delta.dy;
    widget.onHeightChanged(_startHeight - _accumDy);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: _onDragStart,
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: (_) => widget.onDragEnd(),
        child: SizedBox(
          height: 12,
          child: Center(
            child: Container(
              width: 28,
              height: 3,
              decoration: BoxDecoration(
                color: colors.outlineVariant.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(1.5),
              ),
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
