import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
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
/// │ (TOC,    │                      │ (Dict,   │
/// │  Search, │                      │  AI)     │
/// │  Library)│                      │          │
/// └──────────┴──────────────────────┴──────────┘
/// ```
/// Side panels are collapsible (animated) and can be pinned open.
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
  late AnimationController _leftAnimController;
  late AnimationController _rightAnimController;

  // User-resizable panel widths (persisted only for the session).
  double _leftWidth = 0;
  double _rightWidth = 0;

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

  void _initWidths(double defaultWidth) {
    _leftWidth = _leftWidth == 0 ? defaultWidth : _leftWidth;
    _rightWidth = _rightWidth == 0 ? defaultWidth : _rightWidth;
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
    final defaultWidth = ResponsiveBreakpoint.panelWidth(context);
    _initWidths(defaultWidth);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: widget.drawer,
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Row(
          children: [
            // ── Left sidebar (resizable) ───────────────────────────
            _buildResizablePanel(
              context: context,
              colors: colors,
              slot: PanelSlot.left,
              isExpanded: panels.isLeftExpanded,
              animController: _leftAnimController,
              width: _leftWidth,
              onWidthChanged: (w) => setState(() => _leftWidth = w),
              panel: panels.left.openPanel != null
                  ? _SidebarPanel(
                      slot: PanelSlot.left,
                      width: _leftWidth,
                      panelType: panels.left.openPanel!,
                      panelData: panels.left.panelData,
                    )
                  : const SizedBox.shrink(),
            ),

            // ── Main content ──────────────────────────────────────────
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

            // ── Right sidebar (resizable) ────────────────────────────
            _buildResizablePanel(
              context: context,
              colors: colors,
              slot: PanelSlot.right,
              isExpanded: panels.isRightExpanded,
              animController: _rightAnimController,
              width: _rightWidth,
              onWidthChanged: (w) => setState(() => _rightWidth = w),
              panel: panels.right.openPanel != null
                  ? _SidebarPanel(
                      slot: PanelSlot.right,
                      width: _rightWidth,
                      panelType: panels.right.openPanel!,
                      panelData: panels.right.panelData,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a hideable + resizable side panel.
  ///
  /// Visibility is animated via [animController] (sizeFactor). Width is
  /// user-adjustable by dragging the [VerticalDivider] handle; [onWidthChanged]
  /// reports the new width back to the parent for state persistence.
  Widget _buildResizablePanel({
    required BuildContext context,
    required ColorScheme colors,
    required PanelSlot slot,
    required bool isExpanded,
    required AnimationController animController,
    required double width,
    required ValueChanged<double> onWidthChanged,
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
          if (isLeft)
            _ResizeHandle(
              colors: colors,
              onDrag: (delta) =>
                  onWidthChanged((width + delta).clamp(240.0, 560.0)),
            ),
          SizedBox(width: width, child: panel),
          if (!isLeft)
            _ResizeHandle(
              colors: colors,
              onDrag: (delta) =>
                  onWidthChanged((width - delta).clamp(240.0, 560.0)),
            ),
        ],
      ),
    );
  }
}

/// A thin vertical drag handle used to resize a side panel.
class _ResizeHandle extends StatelessWidget {
  final ColorScheme colors;
  final ValueChanged<double> onDrag;

  const _ResizeHandle({required this.colors, required this.onDrag});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: Container(
          width: 6,
          color: colors.outlineVariant.withValues(alpha: 0.4),
          child: Center(
            child: Container(
              width: 2,
              height: 32,
              decoration: BoxDecoration(
                color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(1),
              ),
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
                    _titleFor(panelType),
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
                  tooltip: 'Close panel',
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

  String _titleFor(SidePanelType type) {
    switch (type) {
      case SidePanelType.contents:
        return 'Contents';
      case SidePanelType.dictionary:
        return 'Dictionary';
      case SidePanelType.search:
        return 'Search';
      case SidePanelType.library:
        return 'Library';
      case SidePanelType.gavesana:
        return 'Gavesana';
    }
  }
}
