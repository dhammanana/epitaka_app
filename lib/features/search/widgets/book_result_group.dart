import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/pali_text.dart';
import '../providers/search_provider.dart';
import 'search_result_item_tile.dart';

/// A collapsible group of search results for a single book.
class BookResultGroup extends ConsumerStatefulWidget {
  final String bookId;
  final String? bookName;
  final List<SearchResultItem> results;
  final String? searchQuery;
  final ValueChanged<SearchResultItem> onResultTap;

  const BookResultGroup({
    super.key,
    required this.bookId,
    this.bookName,
    required this.results,
    this.searchQuery,
    required this.onResultTap,
  });

  @override
  ConsumerState<BookResultGroup> createState() => _BookResultGroupState();
}

class _BookResultGroupState extends ConsumerState<BookResultGroup> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final script = ref.watch(settingsProvider).paliScript;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group header
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: AppDimensions.sm,
            ),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  // Book names are Pāli — render in the user's script
                  // with the script font, like the library.
                  child: PaliTextStatic(
                    widget.bookName ?? widget.bookId,
                    script,
                    style: AppTypography.labelMedium.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    '${widget.results.length}',
                    style: AppTypography.labelSmall.copyWith(
                      fontSize: 11,
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Results
        if (_expanded)
          ...widget.results.map((result) => Padding(
                padding: const EdgeInsets.only(left: 12),
                child: SearchResultItemTile(
                  result: result,
                  searchQuery: widget.searchQuery,
                  onTap: () => widget.onResultTap(result),
                ),
              )),
        Divider(
          height: 1,
          color: colors.outlineVariant.withValues(alpha: 0.5),
          indent: AppDimensions.marginMobile,
          endIndent: AppDimensions.marginMobile,
        ),
      ],
    );
  }
}
