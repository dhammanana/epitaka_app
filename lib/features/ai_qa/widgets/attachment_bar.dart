/// Chips bar showing attached headings above the chat input field.
///
/// Displays a horizontal scrolling row of chips, each representing a
/// [HeadingAttachment] the user has selected via the @ mention system.
/// Each chip shows the book name and heading title, with a remove button.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../models/heading_attachment.dart';
import '../providers/mention_provider.dart';

/// A bar showing attached heading chips above the chat input field.
class AttachmentBar extends ConsumerWidget {
  const AttachmentBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachments = ref.watch(attachmentsProvider);
    if (attachments.isEmpty) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.marginMobile,
        AppDimensions.xs,
        AppDimensions.marginMobile,
        AppDimensions.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.outlineVariant, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Row(
              children: [
                Icon(
                  Icons.link,
                  size: 12,
                  color: colors.primary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 4),
                Text(
                  'Attached headings',
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.primary.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${attachments.length}',
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                ),
                const Spacer(),
                // Clear all button
                GestureDetector(
                  onTap: () => ref.read(attachmentsProvider.notifier).clear(),
                  child: Text(
                    'Clear all',
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.error.withValues(alpha: 0.7),
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Chips row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: attachments.map((attachment) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _AttachmentChip(
                    attachment: attachment,
                    colors: colors,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single chip showing an attached heading.
class _AttachmentChip extends ConsumerWidget {
  final HeadingAttachment attachment;
  final ColorScheme colors;

  const _AttachmentChip({
    required this.attachment,
    required this.colors,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mūla indicator
          Icon(
            Icons.auto_stories,
            size: 12,
            color: colors.primary,
          ),
          const SizedBox(width: 4),

          // Chip text
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  attachment.title,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  attachment.bookName.isNotEmpty
                      ? '${attachment.bookName} (${attachment.bookId})'
                      : attachment.bookId,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                    fontSize: 9,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 4),

          // Remove button
          GestureDetector(
            onTap: () => ref.read(attachmentsProvider.notifier).remove(attachment.id),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: colors.onSurfaceVariant.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                Icons.close,
                size: 10,
                color: colors.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
