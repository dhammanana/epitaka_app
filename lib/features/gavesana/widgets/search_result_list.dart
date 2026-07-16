import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../reader/providers/reader_tabs_provider.dart';
import '../providers/gavesana_provider.dart';

/// A single search result card in the Gavesana sidebar.
class GavesanaResultTile extends ConsumerWidget {
  final GavesanaSearchHit hit;
  final int index;

  const GavesanaResultTile({
    super.key,
    required this.hit,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        side: BorderSide(
          color: colors.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        onTap: () => _navigateToResult(context, ref),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Book + para info
              Row(
                children: [
                  Icon(
                    Icons.import_contacts,
                    size: 12,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      hit.bookId,
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Similarity badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: hit.similarity > 0.7
                          ? colors.tertiaryContainer
                          : (hit.similarity > 0.5
                              ? colors.secondaryContainer
                              : colors.surfaceContainerHighest),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${(hit.similarity * 100).toStringAsFixed(0)}%',
                      style: AppTypography.labelSmall.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Location info
              Text(
                'Para ${hit.startPara} – ${hit.endPara} · '
                'Line ${hit.startLine} – ${hit.endLine}',
                style: AppTypography.labelSmall.copyWith(
                  fontSize: 10,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToResult(BuildContext context, WidgetRef ref) {
    ref.read(readerTabsProvider.notifier).openTab(
      ReaderTabInfo(
        bookId: hit.bookId,
        bookName: hit.bookId,
        initialParaId: hit.startPara,
        initialLineId: hit.startLine,
      ),
    );
    // Close the drawer
    Navigator.of(context).pop();
    // Navigate to reader
    context.push('/reader');
  }
}

/// List of Gavesana search results.
class GavesanaResultList extends StatelessWidget {
  final List<GavesanaSearchHit> results;

  const GavesanaResultList({
    super.key,
    required this.results,
  });

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            'Results (${results.length})',
            style: AppTypography.labelSmall.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 4),
        ...results.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GavesanaResultTile(
              hit: entry.value,
              index: entry.key,
            ),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Placeholder for when no search has been performed yet.
class GavesanaIdleState extends StatelessWidget {
  const GavesanaIdleState({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.psychology,
            size: 36,
            color: colors.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'Ask a question about the Tipitaka',
            textAlign: TextAlign.center,
            style: AppTypography.bodyTranslation.copyWith(
              color: colors.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Gavesana will search semantically\nsimilar passages using AI.',
            textAlign: TextAlign.center,
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant.withValues(alpha: 0.6),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
