import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../providers/search_provider.dart';

/// The category (layer) and nikaya (pitaka) chips of search, as a small
/// bordered panel.
///
/// Used wherever the reader can narrow results — the full search screen and
/// sidebar (which build their own denser variant) and Gavesanā, where the
/// chips re-render the AI-found passages by book.
class SearchFilterPanel extends ConsumerWidget {
  final ColorScheme colors;

  /// Tighter padding and labels for the narrow sidebar panel.
  final bool dense;

  const SearchFilterPanel({
    super.key,
    required this.colors,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched purely for rebuilds: the notifier's getters stay live, and a
    // toggle emits a fresh state that carries the new selection.
    ref.watch(searchProvider);
    final notifier = ref.read(searchProvider.notifier);
    final loc = AppLocalizations.of(context);

    Widget row(
      String label,
      Set<String> all,
      Set<String> enabled,
      ValueChanged<String> onToggle,
    ) {
      return Row(
        children: [
          SizedBox(
            width: dense ? 40 : 44,
            child: Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: dense ? 9 : 10,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final key in all)
                  _SearchFilterChip(
                    label: key,
                    selected: enabled.contains(key),
                    colors: colors,
                    onTap: () => onToggle(key),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return Container(
      padding: EdgeInsets.all(dense ? 8 : 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(
            loc.layer,
            kAllCategories,
            notifier.enabledCategories,
            notifier.toggleCategory,
          ),
          const SizedBox(height: 6),
          row(
            loc.nikaya,
            kAllNikayas,
            notifier.enabledNikayas,
            notifier.toggleNikaya,
          ),
        ],
      ),
    );
  }
}

class _SearchFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ColorScheme colors;
  final VoidCallback onTap;

  const _SearchFilterChip({
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? colors.primaryContainer
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? colors.primary.withValues(alpha: 0.5)
                : colors.outlineVariant.withValues(alpha: 0.4),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? colors.onPrimaryContainer
                : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
