import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/reader_tabs_provider.dart';

/// A horizontal tab strip for open reader books, matching the design spec.
///
/// Renders as a scrollable row of rounded-top chips below the app bar.
/// Active tab uses a white surface with a primary-colour bottom border;
/// inactive tabs use a slightly darker surface.
///
/// Supports:
/// - Tap to switch tabs
/// - Long-press + drag to reorder tabs
///
/// Uses local state for the tabs list to work correctly with
/// [ReorderableListView], which requires immediate [setState] in its
/// [onReorder] callback to prevent snap-back on release.
///
/// [onSwitchTab] is called when a tab is tapped, so the parent can
/// animate the PageView directly (avoids conflicts with swipe).
class TabStrip extends ConsumerStatefulWidget {
  /// Called when a tab chip is tapped. Receives the tab index.
  /// When provided, used instead of directly calling switchTo on the
  /// provider — the parent should animate PageView and the
  /// onPageChanged handler will sync the provider.
  final void Function(int index)? onSwitchTab;

  const TabStrip({super.key, this.onSwitchTab});

  @override
  ConsumerState<TabStrip> createState() => _TabStripState();
}

class _TabStripState extends ConsumerState<TabStrip> {
  /// Local copy of the tabs list, kept in sync with the provider.
  /// We use this instead of watching the provider directly in the
  /// ReorderableListView builder so that onReorder can update it
  /// via immediate [setState] (preventing the item from snapping
  /// back after the drag ends).
  List<ReaderTabInfo> _localTabs = [];
  int _localActiveIndex = 0;

  @override
  void initState() {
    super.initState();
    final state = ref.read(readerTabsProvider);
    _localTabs = List.from(state.tabs);
    _localActiveIndex = state.activeIndex;
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
    // Keep local state in sync with the provider.
    // This fires synchronously when the provider state changes
    // (e.g. tab opened/closed from search results or other places).
    // Stable method reference avoids re-registering the listener on each build.
    ref.listen(readerTabsProvider, _onTabsChanged);

    final colors = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.sizeOf(context).width > 768;

    if (_localTabs.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
              onReorder: (oldIndex, newIndex) {
                // ReorderableListView reports newIndex in the list *before*
                // the dragged item is removed. Both the local update and the
                // provider apply the standard "decrement when moving down"
                // adjustment, so we must pass the RAW newIndex to the provider
                // and only adjust a local copy here. Mutating newIndex before
                // calling reorderTab caused a double-adjustment (the provider
                // adjusted it again), which produced wrong positions —
                // especially noticeable when the active tab was dragged.
                final adjustedIndex = oldIndex < newIndex
                    ? newIndex - 1
                    : newIndex;

                // ── 1. Update local state immediately (same frame) ──
                // This prevents ReorderableListView from snapping the
                // item back to its original position after release.
                setState(() {
                  final tab = _localTabs.removeAt(oldIndex);
                  _localTabs.insert(adjustedIndex, tab);

                  // Update local active index after the move
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

                // ── 2. Update provider for persistence ──────────────
                // Pass the RAW newIndex; reorderTab applies its own correct
                // adjustment. ref.listen above will sync _localTabs back,
                // which is a no-op since they already match.
                ref
                    .read(readerTabsProvider.notifier)
                    .reorderTab(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final tab = _localTabs[index];
                final isActive = index == _localActiveIndex;
                return _TabChip(
                  key: ValueKey('tab-${tab.bookId}'),
                  index: index,
                  tab: tab,
                  isActive: isActive,
                  onTap: () =>
                      ref.read(readerTabsProvider.notifier).switchTo(index),
                  onClose: () =>
                      ref.read(readerTabsProvider.notifier).closeTab(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

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
      padding: const EdgeInsets.only(right: 8),
      child: ReorderableDragStartListener(
        index: index,
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
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tab.bookId,
                      style: AppTypography.labelMedium.copyWith(
                        color: isActive
                            ? colors.primary
                            : colors.onSurfaceVariant,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w400,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _CloseButton(onClose: onClose, isActive: isActive),
                  ],
                ),
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
