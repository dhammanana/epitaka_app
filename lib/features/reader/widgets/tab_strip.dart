import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/reader_tabs_provider.dart';

/// A horizontal tab strip for open reader books.
///
/// Renders as a scrollable row of rounded-top chips below the app bar.
/// Active tab uses a surface container with a primary-colour bottom border;
/// inactive tabs use a slightly darker surface.
///
/// Supports:
/// - Tap to switch tabs
/// - Long-press + drag on the **grip icon** (right side) to reorder tabs
/// - Natural horizontal scrolling by dragging anywhere else on the tab strip
/// - Visual overflow indicators (fade gradients) when tabs overflow the viewport
///
/// Uses local state for the tabs list to work correctly with
/// [ReorderableListView], which requires immediate [setState] in its
/// [onReorder] callback to prevent snap-back on release.
class TabStrip extends ConsumerStatefulWidget {
  const TabStrip({super.key});

  @override
  ConsumerState<TabStrip> createState() => _TabStripState();
}

class _TabStripState extends ConsumerState<TabStrip> {
  /// Local copy of the tabs list, kept in sync with the provider.
  List<ReaderTabInfo> _localTabs = [];
  int _localActiveIndex = 0;

  /// Scroll controller to detect overflow and track scroll position.
  final ScrollController _scrollController = ScrollController();

  /// Whether the content overflows the viewport (shows gradient indicators).
  bool _isOverflowing = false;

  /// Current scroll offset for fade gradient calculation.
  double _scrollOffset = 0;

  /// Max scroll extent for fade gradient calculation.
  double _maxScrollExtent = 0;

  @override
  void initState() {
    super.initState();
    final state = ref.read(readerTabsProvider);
    _localTabs = List.from(state.tabs);
    _localActiveIndex = state.activeIndex;
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    setState(() {
      _scrollOffset = _scrollController.offset;
      _maxScrollExtent = _scrollController.position.maxScrollExtent;
    });
  }

  /// Called when the provider state changes externally (tab opened/closed
  /// from search results, contents sheet, etc.). Syncs the local list.
  void _onTabsChanged(ReaderTabsState? _, ReaderTabsState next) {
    if (!mounted) return;
    setState(() {
      _localTabs = List.from(next.tabs);
      _localActiveIndex = next.activeIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(readerTabsProvider, _onTabsChanged);

    final colors = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.sizeOf(context).width > 768;

    if (_localTabs.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (!mounted) return false;
              if (notification is ScrollUpdateNotification ||
                  notification is OverscrollNotification) {
                // Check overflow after layout is done
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _scrollController.hasClients) {
                    final newOverflowing =
                        _scrollController.position.maxScrollExtent > 0;
                    if (newOverflowing != _isOverflowing) {
                      setState(() => _isOverflowing = newOverflowing);
                    }
                  }
                });
              }
              return false;
            },
            child: Stack(
              children: [
                // ── Scrollable tab list ─────────────────────────────
                SizedBox(
                  height: 44,
                  child: ReorderableListView.builder(
                    scrollDirection: Axis.horizontal,
                    buildDefaultDragHandles: false,
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop
                          ? AppDimensions.marginDesktop
                          : AppDimensions.marginMobile,
                    ),
                    itemCount: _localTabs.length,
                    onReorderItem: (oldIndex, newIndex) {
                      final adjustedIndex = oldIndex < newIndex
                          ? newIndex - 1
                          : newIndex;

                      setState(() {
                        final tab = _localTabs.removeAt(oldIndex);
                        _localTabs.insert(adjustedIndex, tab);

                        if (_localActiveIndex == oldIndex) {
                          _localActiveIndex = adjustedIndex;
                        } else if (oldIndex < _localActiveIndex &&
                            adjustedIndex >= _localActiveIndex) {
                          _localActiveIndex--;
                        } else if (oldIndex > _localActiveIndex &&
                            adjustedIndex <= _localActiveIndex) {
                          _localActiveIndex++;
                        }
                      });

                      ref
                          .read(readerTabsProvider.notifier)
                          .reorderTab(oldIndex, newIndex);
                    },
                    proxyDecorator: (child, index, animation) {
                      // Slight scale-down with shadow during drag
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) {
                          final scale = 1.0 - (0.05 * animation.value);
                          return Transform.scale(
                            scale: scale,
                            child: Material(
                              elevation: 4,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(AppDimensions.radiusMd),
                              ),
                              child: child,
                            ),
                          );
                        },
                        child: child,
                      );
                    },
                    itemBuilder: (context, index) {
                      final tab = _localTabs[index];
                      final isActive = index == _localActiveIndex;
                      return _TabChip(
                        key: ValueKey('tab-${tab.bookId}'),
                        index: index,
                        tab: tab,
                        isActive: isActive,
                        onTap: () => ref
                            .read(readerTabsProvider.notifier)
                            .switchTo(index),
                        onClose: () => ref
                            .read(readerTabsProvider.notifier)
                            .closeTab(index),
                      );
                    },
                  ),
                ),

                // ── Left fade gradient indicator ───────────────────
                if (_isOverflowing && _scrollOffset > 0)
                  IgnorePointer(
                    child: Container(
                      width: 24,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colors.surface.withValues(alpha: 0.9),
                            colors.surface.withValues(alpha: 0),
                          ],
                          stops: const [0.0, 1.0],
                        ),
                      ),
                    ),
                  ),

                // ── Right fade gradient indicator ──────────────────
                if (_isOverflowing &&
                    _scrollOffset < _maxScrollExtent)
                  Positioned(
                    right: 0,
                    child: IgnorePointer(
                      child: Container(
                        width: 24,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                            colors: [
                              colors.surface.withValues(alpha: 0.9),
                              colors.surface.withValues(alpha: 0),
                            ],
                            stops: const [0.0, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Single tab chip in the strip.
class _TabChip extends StatelessWidget {
  final int index;
  final ReaderTabInfo tab;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _TabChip({
    super.key,
    required this.index,
    required this.tab,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusMd),
          ),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: isActive
                  ? colors.surfaceContainerLowest
                  : colors.surfaceContainerHigh,
              border: Border(
                bottom: BorderSide(
                  color: isActive ? colors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppDimensions.radiusMd),
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Tab label ─────────────────────────────────────
                  Text(
                    tab.bookId,
                    style: AppTypography.labelMedium.copyWith(
                      color: isActive
                          ? colors.primary
                          : colors.onSurfaceVariant,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // ── Close button ──────────────────────────────────
                  _CloseButton(onClose: onClose, isActive: isActive),
                  const SizedBox(width: 2),
                  // ── Drag handle (grip) ────────────────────────────
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Icon(
                        Icons.drag_indicator,
                        size: 18,
                        color: isActive
                            ? colors.onSurfaceVariant
                            : colors.outline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onClose;
  final bool isActive;

  const _CloseButton({required this.onClose, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: 20,
      height: 20,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onClose,
          borderRadius: BorderRadius.circular(9999),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(
              Icons.close,
              size: 14,
              color: isActive ? colors.onSurfaceVariant : colors.outline,
            ),
          ),
        ),
      ),
    );
  }
}
