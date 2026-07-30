/// Overlay widget that appears when the user types @ in the chat input.
///
/// Shows a scrollable list of matching headings and books from the
/// pre-built mention index.  Each item displays:
///   - Line 1: The last heading title (2 lines max, wrapping)
///   - Line 2: The full path (wrapping, not ellipsised)
///   - Leading icon indicating Mūla, Aṭṭhakathā, or Ṭīkā
///
/// Supports keyboard navigation (up/down arrows + enter to select).
/// Disappears when the user taps outside, presses Escape, or selects an item.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../models/heading_attachment.dart';
import '../providers/mention_provider.dart';
import 'mention_index_build_dialog.dart';

/// Overlay that shows @ mention search results anchored near the text field.
///
/// Positioned by the parent's CompositedTransformFollower — this widget
/// returns just the visual content (no LayerLink needed).
class MentionOverlay extends ConsumerWidget {
  const MentionOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mentionSearchProvider);
    if (!state.isActive || (state.results.isEmpty && !state.isLoading)) {
      return const SizedBox.shrink();
    }

    final colors = Theme.of(context).colorScheme;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      color: colors.surface,
      surfaceTintColor: colors.surfaceTint,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 420,
          maxHeight: 360,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context, colors, state),
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (state.results.isEmpty)
              _buildEmptyState(context, colors, state.query)
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: state.results.length,
                  itemBuilder: (context, index) {
                    return _ResultItem(
                      result: state.results[index],
                      isSelected: index == state.selectedIndex,
                    );
                  },
                ),
              ),
            if (state.results.isNotEmpty)
              _buildFooter(context, colors),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme colors, MentionSearchState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusMd)),
      ),
      child: Row(
        children: [
          Icon(Icons.bookmark_outline, size: 14, color: colors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              state.query.isNotEmpty
                  ? 'Attach: "${state.query}"'
                  : 'Type a sutta or heading name',
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurfaceVariant,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (state.results.isNotEmpty)
            Text(
              '${state.results.length}',
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme colors, String query) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 28,
            color: colors.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 8),
          Text(
            query.isNotEmpty
                ? 'No results for "$query"'
                : 'Start typing a sutta or heading name',
            style: AppTypography.labelMedium.copyWith(
              color: colors.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Tip: Try @cankisutta, @dn1, or a heading title',
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant.withValues(alpha: 0.4),
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // ── Rebuild index button ────────────────────────────────
          _RebuildIndexButton(colors: colors),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.15),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppDimensions.radiusMd),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.keyboard_return, size: 12, color: colors.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(width: 4),
          Text('Select', style: AppTypography.labelSmall.copyWith(color: colors.onSurfaceVariant.withValues(alpha: 0.4), fontSize: 9)),
          const SizedBox(width: 10),
          Icon(Icons.keyboard_arrow_up, size: 12, color: colors.onSurfaceVariant.withValues(alpha: 0.4)),
          Icon(Icons.keyboard_arrow_down, size: 12, color: colors.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(width: 4),
          Text('Navigate', style: AppTypography.labelSmall.copyWith(color: colors.onSurfaceVariant.withValues(alpha: 0.4), fontSize: 9)),
          const Spacer(),
          Icon(Icons.close, size: 12, color: colors.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(width: 4),
          Text('Esc', style: AppTypography.labelSmall.copyWith(color: colors.onSurfaceVariant.withValues(alpha: 0.4), fontSize: 9)),
        ],
      ),
    );
  }
}

/// A single result item in the mention dropdown.
///
/// Displays 2 lines:
///   1. The last/current heading title (wraps, max 2 lines)
///   2. The full path (wraps, not stripped)
/// With a leading icon indicating Mūla, Aṭṭhakathā, or Ṭīkā.
class _ResultItem extends ConsumerWidget {
  final MentionSearchResult result;
  final bool isSelected;

  const _ResultItem({
    required this.result,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final isBook = result.entryType == AttachmentEntryType.book;

    // Determine the text type icon configuration
    final (IconData icon, Color iconColor) = switch (result.textType) {
      TextType.mula => (Icons.auto_stories, colors.primary),
      TextType.attha => (Icons.forum_outlined, colors.tertiary),
      TextType.tika => (Icons.layers_outlined, colors.secondary),
    };

    return InkWell(
      onTap: () => _select(ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? colors.primaryContainer.withValues(alpha: 0.15) : null,
          border: Border(
            bottom: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text type indicator icon
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                icon,
                size: 14,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 10),

            // Text content: 2 lines only
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Line 1: Last heading title (max 2 lines, wrapping)
                  Text(
                    result.lastHeading,
                    style: AppTypography.labelMedium.copyWith(
                      color: colors.onSurface,
                      fontWeight: isBook ? FontWeight.w700 : FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 1),

                  // Line 2: Full path (wrapping, not ellipsised)
                  Text(
                    result.path,
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                    // Allow wrapping — no maxLines, no overflow ellipsis.
                    // The overlay container's maxHeight constraint will
                    // naturally clip if needed.
                  ),
                ],
              ),
            ),

            // Chapter length badge for book entries
            if (isBook && result.chapterLen > 0)
              Container(
                margin: const EdgeInsets.only(left: 6, top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  result.chapterLenLabel,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                    fontSize: 8,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _select(WidgetRef ref) {
    final notifier = ref.read(mentionSearchProvider.notifier);
    final attachmentsNotifier = ref.read(attachmentsProvider.notifier);

    attachmentsNotifier.add(result.toAttachment());
    notifier.deactivate();
  }
}

/// A small button shown in the empty state that lets the user rebuild
/// the suggestion index if no results are found.
class _RebuildIndexButton extends ConsumerStatefulWidget {
  final ColorScheme colors;

  const _RebuildIndexButton({required this.colors});

  @override
  ConsumerState<_RebuildIndexButton> createState() => _RebuildIndexButtonState();
}

class _RebuildIndexButtonState extends ConsumerState<_RebuildIndexButton> {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: _rebuildIndex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: widget.colors.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: widget.colors.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.refresh,
              size: 13,
              color: widget.colors.primary,
            ),
            const SizedBox(width: 5),
            Text(
              'Rebuild suggestion index',
              style: AppTypography.labelSmall.copyWith(
                color: widget.colors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rebuildIndex() async {
    if (!mounted) return;
    final count = await showMentionIndexBuildDialog(context);
    debugPrint('[MENTION] Rebuild complete: $count entries');
    // Refresh the search results after rebuild
    if (mounted) {
      final notifier = ref.read(mentionSearchProvider.notifier);
      notifier.deactivate();
      notifier.activate();
    }
  }
}
