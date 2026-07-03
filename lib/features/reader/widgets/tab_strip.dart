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
class TabStrip extends ConsumerWidget {
  const TabStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabsState = ref.watch(readerTabsProvider);
    final colors = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.sizeOf(context).width > 768;

    if (tabsState.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.outlineVariant),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(
                horizontal:
                    isDesktop ? AppDimensions.marginDesktop : AppDimensions.marginMobile,
              ),
              itemCount: tabsState.tabs.length,
              itemBuilder: (context, index) {
                final tab = tabsState.tabs[index];
                final isActive = index == tabsState.activeIndex;
                return _TabChip(
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
  final ReaderTabInfo tab;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _TabChip({
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
                      color: isActive ? colors.primary : colors.onSurfaceVariant,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
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
              color: isActive
                  ? colors.onSurfaceVariant
                  : colors.outline,
            ),
          ),
        ),
      ),
    );
  }
}
