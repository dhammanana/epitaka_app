import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/settings_provider.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/app_localizations.dart';
import '../../core/utils/responsive_breakpoint.dart';
import '../../features/contents/widgets/contents_panel.dart';
import '../../features/dictionary/widgets/dictionary_panel.dart';
import '../../features/library/widgets/library_panel.dart';
import '../../features/search/widgets/search_panel.dart';
import '../../features/gavesana/widgets/gavesana_panel.dart';
import '../providers/side_panel_provider.dart';
import 'app_shell.dart';

/// A responsive scaffold that adapts between mobile and desktop layouts.
///
/// **Mobile/Phone** — delegates to [AppShell] with a bottom navigation bar.
/// **Desktop** — renders a three-column layout:
/// ```
/// ┌──────────┬──────────────────────┬──────────┐
/// │  Left    │   Main Content       │  Right   │
/// │  Panel   │   (Reader/Screen)    │  Panel   │
/// │ (TOC,    │         │            │ (Dict,   │
/// │  Search, │    divider           │  AI)     │
/// │  Library)│                      │          │
/// └──────────┴──────────────────────┴──────────┘
/// ```
/// Side panels are collapsible (animated) and can be pinned open. Each open
/// panel is separated from the main content by a draggable divider, so the
/// panel width is user-adjustable; the chosen widths persist via
/// [settingsProvider].
class ResponsiveScaffold extends ConsumerStatefulWidget {
  /// The main content widget (e.g. [ReaderScreen] or [LibraryScreen]).
  final Widget child;

  /// Optional app bar for the main content area (desktop uses thin header
  /// instead of full app bar).
  final PreferredSizeWidget? appBar;

  /// Optional drawer for mobile.
  final Widget? drawer;

  const ResponsiveScaffold({
    super.key,
    required this.child,
    this.appBar,
    this.drawer,
  });

  @override
  ConsumerState<ResponsiveScaffold> createState() => _ResponsiveScaffoldState();
}

class _ResponsiveScaffoldState extends ConsumerState<ResponsiveScaffold>
    with TickerProviderStateMixin {
  /// Smallest width a side panel can be dragged to.
  static const double _minPanelWidth = 260;

  /// Hard cap for a single side panel width.
  static const double _maxPanelWidth = 640;

  late AnimationController _leftAnimController;
  late AnimationController _rightAnimController;

  // User-resizable panel widths. 0 = not initialized yet; the first build
  // seeds them from persisted settings (or the screen-size-aware default).
  double _leftWidth = 0;
  double _rightWidth = 0;

  /// Becomes true once the user drags a divider, so persisted settings that
  /// arrive later (async prefs init) never overwrite the in-session choice.
  bool _userResized = false;

  @override
  void initState() {
    super.initState();
    _leftAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _rightAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _leftAnimController.dispose();
    _rightAnimController.dispose();
    super.dispose();
  }

  /// Seeds the panel widths from persisted settings, falling back to the
  /// screen-size-aware default when the user never resized a panel. Once the
  /// user drags a divider, the local widths win and are no longer re-synced.
  void _initWidths() {
    if (_userResized) return;
    final settings = ref.read(settingsProvider);
    final defaultWidth = ResponsiveBreakpoint.panelWidth(context);
    _leftWidth = settings.leftPanelWidth > 0
        ? settings.leftPanelWidth
        : defaultWidth;
    _rightWidth = settings.rightPanelWidth > 0
        ? settings.rightPanelWidth
        : defaultWidth;
  }

  /// Largest width a panel may have so the main content keeps at least
  /// [minContentWidth] and the opposite panel (when open) still fits.
  double _maxPanelWidthFor(
    double availableWidth,
    double minContentWidth,
    double otherPanelWidth,
  ) {
    final cap = math.min(
      _maxPanelWidth,
      availableWidth - minContentWidth - otherPanelWidth,
    );
    return math.max(_minPanelWidth, cap);
  }

  @override
  Widget build(BuildContext context) {
    final panels = ref.watch(sidePanelProvider);
    final isDesktop = ResponsiveBreakpoint.isDesktop(context);

    // Listen for panel state changes to animate sidebars
    // Must be in build() — Riverpod requires ref.listen during build phase
    ref.listen(sidePanelProvider, (
      SidePanelsState? prev,
      SidePanelsState next,
    ) {
      if (!mounted) return;
      if (next.isLeftExpanded) {
        _leftAnimController.forward();
      } else {
        _leftAnimController.reverse();
      }
      if (next.isRightExpanded) {
        _rightAnimController.forward();
      } else {
        _rightAnimController.reverse();
      }
    });

    // On mobile/tablet, fall back to traditional AppShell
    if (!isDesktop) {
      return AppShell(
        appBar: widget.appBar,
        drawer: widget.drawer,
        child: widget.child,
      );
    }

    // ── Desktop layout ─────────────────────────────────────────────────
    // Sync persisted widths when SharedPreferences init completes (async),
    // without rebuilding this whole subtree on every settings change.
    ref.listen(settingsProvider, (AppSettings? prev, AppSettings next) {
      if (!mounted || _userResized) return;
      final defaultWidth = ResponsiveBreakpoint.panelWidth(context);
      final newLeft = next.leftPanelWidth > 0
          ? next.leftPanelWidth
          : defaultWidth;
      final newRight = next.rightPanelWidth > 0
          ? next.rightPanelWidth
          : defaultWidth;
      if (newLeft != _leftWidth || newRight != _rightWidth) {
        setState(() {
          _leftWidth = newLeft;
          _rightWidth = newRight;
        });
      }
    });
    _initWidths();
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: widget.drawer,
      backgroundColor: colors.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            final leftExpanded = panels.isLeftExpanded;
            final rightExpanded = panels.isRightExpanded;
            final minContentWidth =
                ResponsiveBreakpoint.minContentWidth(context);

            // Two passes so each panel's max accounts for the other panel's
            // *effective* (clamped) width, not its raw preference. Stored
            // preferences are left untouched — these are layout-only values.
            var leftWidth = _leftWidth.clamp(_minPanelWidth, _maxPanelWidth);
            var rightWidth = _rightWidth.clamp(_minPanelWidth, _maxPanelWidth);
            double leftMax = leftWidth;
            double rightMax = rightWidth;
            for (var pass = 0; pass < 2; pass++) {
              leftMax = leftExpanded
                  ? _maxPanelWidthFor(
                      availableWidth,
                      minContentWidth,
                      rightExpanded ? rightWidth : 0,
                    )
                  : leftWidth;
              rightMax = rightExpanded
                  ? _maxPanelWidthFor(
                      availableWidth,
                      minContentWidth,
                      leftExpanded ? leftWidth : 0,
                    )
                  : rightWidth;
              leftWidth = leftWidth.clamp(_minPanelWidth, leftMax);
              rightWidth = rightWidth.clamp(_minPanelWidth, rightMax);
            }

            return Row(
              children: [
                // ── Left sidebar (resizable) ───────────────────────────
                _buildResizablePanel(
                  colors: colors,
                  slot: PanelSlot.left,
                  animController: _leftAnimController,
                  width: leftWidth,
                  maxWidth: leftMax,
                  onResize: (w) {
                    _userResized = true;
                    setState(() => _leftWidth = w);
                  },
                  onResizeEnd: () {
                    ref
                        .read(settingsProvider.notifier)
                        .setLeftPanelWidth(_leftWidth.roundToDouble());
                  },
                  panel: panels.left.openPanel != null
                      ? _SidebarPanel(
                          slot: PanelSlot.left,
                          width: leftWidth,
                          panelType: panels.left.openPanel!,
                          panelData: panels.left.panelData,
                        )
                      : const SizedBox.shrink(),
                ),

                // ── Main content ──────────────────────────────────────
                Expanded(
                  child: Column(
                    children: [
                      // Thin header bar on desktop
                      if (widget.appBar != null)
                        SizedBox(
                          height: AppDimensions.appBarHeight,
                          child: widget.appBar,
                        ),
                      Expanded(child: widget.child),
                    ],
                  ),
                ),

                // ── Right sidebar (resizable) ──────────────────────────
                _buildResizablePanel(
                  colors: colors,
                  slot: PanelSlot.right,
                  animController: _rightAnimController,
                  width: rightWidth,
                  maxWidth: rightMax,
                  onResize: (w) {
                    _userResized = true;
                    setState(() => _rightWidth = w);
                  },
                  onResizeEnd: () {
                    ref
                        .read(settingsProvider.notifier)
                        .setRightPanelWidth(_rightWidth.roundToDouble());
                  },
                  panel: panels.right.openPanel != null
                      ? _SidebarPanel(
                          slot: PanelSlot.right,
                          width: rightWidth,
                          panelType: panels.right.openPanel!,
                          panelData: panels.right.panelData,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Builds a hideable + resizable side panel.
  ///
  /// Visibility is animated via [animController] (sizeFactor). The drag
  /// divider sits between the panel and the main content: on the panel's
  /// right edge for the left slot, on its left edge for the right slot.
  /// Dragging the divider reports the new width through [onResize], and
  /// [onResizeEnd] fires once the drag is released (used to persist).
  Widget _buildResizablePanel({
    required ColorScheme colors,
    required PanelSlot slot,
    required AnimationController animController,
    required double width,
    required double maxWidth,
    required ValueChanged<double> onResize,
    required VoidCallback onResizeEnd,
    required Widget panel,
  }) {
    final isLeft = slot == PanelSlot.left;
    return SizeTransition(
      sizeFactor: CurvedAnimation(
        parent: animController,
        curve: Curves.easeInOut,
      ),
      axis: Axis.horizontal,
      alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLeft) ...[
            SizedBox(width: width, child: panel),
            _PanelDivider(
              key: const Key('left-panel-divider'),
              colors: colors,
              growsRightward: true,
              width: width,
              minWidth: _minPanelWidth,
              maxWidth: maxWidth,
              onResize: onResize,
              onResizeEnd: onResizeEnd,
            ),
          ] else ...[
            _PanelDivider(
              key: const Key('right-panel-divider'),
              colors: colors,
              growsRightward: false,
              width: width,
              minWidth: _minPanelWidth,
              maxWidth: maxWidth,
              onResize: onResize,
              onResizeEnd: onResizeEnd,
            ),
            SizedBox(width: width, child: panel),
          ],
        ],
      ),
    );
  }
}

/// A draggable vertical divider separating a side panel from the main
/// content. Shows a hairline that highlights on hover / while dragging, and
/// resizes the adjacent panel via horizontal drags.
class _PanelDivider extends StatefulWidget {
  final ColorScheme colors;

  /// True for the left slot (divider on the panel's right edge, so dragging
  /// rightward grows the panel); false for the right slot (opposite).
  final bool growsRightward;

  /// Current panel width — used as the drag baseline on drag start.
  final double width;

  final double minWidth;
  final double maxWidth;

  /// Called with the new panel width while dragging.
  final ValueChanged<double> onResize;

  /// Called once when the drag gesture ends.
  final VoidCallback onResizeEnd;

  const _PanelDivider({
    super.key,
    required this.colors,
    required this.growsRightward,
    required this.width,
    required this.minWidth,
    required this.maxWidth,
    required this.onResize,
    required this.onResizeEnd,
  });

  @override
  State<_PanelDivider> createState() => _PanelDividerState();
}

class _PanelDividerState extends State<_PanelDivider> {
  /// Panel width captured when the drag started, so width changes are
  /// computed from a stable baseline instead of accumulated deltas.
  double? _dragStartWidth;
  bool _hovered = false;

  void _onDragStart(DragStartDetails _) {
    _dragStartWidth = widget.width;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final start = _dragStartWidth ?? widget.width;
    final target = widget.growsRightward
        ? start + details.delta.dx
        : start - details.delta.dx;
    widget.onResize(target.clamp(widget.minWidth, widget.maxWidth));
  }

  void _onDragEnd(DragEndDetails _) {
    _dragStartWidth = null;
    widget.onResizeEnd();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final lineColor = _hovered
        ? colors.primary.withValues(alpha: 0.8)
        : colors.outlineVariant;

    return Semantics(
      label: 'Resize panel',
      container: true,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Container(
            width: 12,
            color: _hovered
                ? colors.surfaceContainerHighest.withValues(alpha: 0.6)
                : Colors.transparent,
            // Anchor the hairline to the panel edge so it reads as the pane
            // boundary; the grab area extends toward the main content.
            alignment: widget.growsRightward
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: Container(
              width: _hovered ? 2.5 : 1,
              color: lineColor,
              // Full height: bounded by the panel row's height.
              height: double.infinity,
            ),
          ),
        ),
      ),
    );
  }
}

/// A single sidebar panel with header (title, pin, close) and content.
class _SidebarPanel extends ConsumerWidget {
  final PanelSlot slot;
  final double width;
  final SidePanelType panelType;
  final String? panelData;

  const _SidebarPanel({
    required this.slot,
    required this.width,
    required this.panelType,
    this.panelData,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    return SizedBox(
      width: width,
      child: Column(
        children: [
          // Header
          Container(
            height: AppDimensions.appBarHeight,
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(bottom: BorderSide(color: colors.outlineVariant)),
            ),
            child: Row(
              children: [
                // Panel icon + title
                Icon(_iconFor(panelType), size: 18, color: colors.primary),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: Text(
                    _titleFor(context, panelType),
                    style: AppTypography.labelMedium.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Close
                IconButton(
                  icon: Icon(Icons.close, size: 18),
                  color: colors.onSurfaceVariant,
                  tooltip: loc.closePanel,
                  onPressed: () {
                    ref.read(sidePanelProvider.notifier).close(panelType);
                  },
                ),
              ],
            ),
          ),
          // Panel content
          Expanded(child: _buildPanelContent(ref, colors)),
        ],
      ),
    );
  }

  Widget _buildPanelContent(WidgetRef ref, ColorScheme colors) {
    // Read the autoFocus flag from the current panel state so keyboard
    // shortcuts (Cmd+D / Cmd+Shift+F) can focus the search field on open.
    final autoFocus = slot == PanelSlot.left
        ? ref.watch(sidePanelProvider).left.autoFocus
        : ref.watch(sidePanelProvider).right.autoFocus;
    switch (panelType) {
      case SidePanelType.contents:
        return const ContentsPanel();
      case SidePanelType.dictionary:
        return DictionaryPanel(
          initialWord: panelData ?? '',
          autoFocus: autoFocus,
        );
      case SidePanelType.search:
        return SearchPanel(autoFocus: autoFocus);
      case SidePanelType.library:
        return const LibraryPanel();
      case SidePanelType.gavesana:
        return const GavesanaPanel();
    }
  }

  IconData _iconFor(SidePanelType type) {
    switch (type) {
      case SidePanelType.contents:
        return Icons.format_list_bulleted;
      case SidePanelType.dictionary:
        return Icons.menu_book;
      case SidePanelType.search:
        return Icons.search;
      case SidePanelType.library:
        return Icons.library_books;
      case SidePanelType.gavesana:
        return Icons.auto_awesome;
    }
  }

  String _titleFor(BuildContext context, SidePanelType type) {
    final loc = AppLocalizations.of(context);
    switch (type) {
      case SidePanelType.contents:
        return loc.contents;
      case SidePanelType.dictionary:
        return loc.dictionary;
      case SidePanelType.search:
        return loc.search;
      case SidePanelType.library:
        return loc.libraryLabel;
      case SidePanelType.gavesana:
        return loc.gavesana;
    }
  }
}
