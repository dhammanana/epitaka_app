import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../providers/search_history_provider.dart';

/// Horizontal history chips for previous Tipitaka searches.
///
/// Tapping a chip calls [onSelected] — the caller fills its search bar with
/// that text and re-runs the search.
class SearchHistoryChips extends ConsumerWidget {
  final void Function(String query) onSelected;

  /// Smaller paddings for the sidebar panel.
  final bool compact;

  /// Max chips shown; the rest stay in history but are hidden.
  final int maxVisible;

  const SearchHistoryChips({
    super.key,
    required this.onSelected,
    this.compact = false,
    this.maxVisible = 10,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(searchHistoryProvider);
    if (history.isEmpty) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final visible = history.length > maxVisible
        ? history.sublist(0, maxVisible)
        : history;
    final hPad = compact ? AppDimensions.sm : AppDimensions.marginMobile;
    final fontSize = compact ? 11.0 : 12.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, compact ? 6 : 8, hPad, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.history,
                size: compact ? 13 : 14,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                loc.recentSearches,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: compact ? 10 : 11,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => ref.read(searchHistoryProvider.notifier).clear(),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Text(
                    loc.clearHistory,
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.primary,
                      fontSize: compact ? 10 : 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final q in visible)
                InputChip(
                  label: Text(
                    q,
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: fontSize,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  avatar: Icon(
                    Icons.search,
                    size: compact ? 13 : 14,
                    color: colors.onSurfaceVariant,
                  ),
                  deleteIcon: Icon(
                    Icons.close,
                    size: compact ? 13 : 14,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  onDeleted: () =>
                      ref.read(searchHistoryProvider.notifier).remove(q),
                  onPressed: () => onSelected(q),
                  backgroundColor: colors.surfaceContainerHighest,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  visualDensity: compact
                      ? VisualDensity.compact
                      : VisualDensity.standard,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
