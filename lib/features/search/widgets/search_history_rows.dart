import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_localizations.dart';
import '../../../shared/widgets/history_list.dart';
import '../providers/search_history_provider.dart';

/// The Search history as full-width rows. All three Search surfaces (screen,
/// sidebar, sheet) share one history, so Clear here clears it for all.
/// Put it in an `Expanded` or `Flexible`.
class SearchHistoryRows extends ConsumerWidget {
  const SearchHistoryRows({
    super.key,
    required this.onSelected,
    this.selectedIndex = -1,
    this.controller,
  });

  final void Function(String query) onSelected;
  final int selectedIndex;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(searchHistoryProvider);
    final notifier = ref.read(searchHistoryProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    return HistoryList(
      title: AppLocalizations.of(context).recentSearches,
      onClear: notifier.clear,
      selectedIndex: selectedIndex < 0 ? null : selectedIndex,
      controller: controller,
      items: [
        for (final q in history)
          HistoryItem(
            key: q,
            title: Text(
              q,
              style: historyTitleStyle(colors),
            ),
            onTap: () => onSelected(q),
            onDelete: () => notifier.remove(q),
          ),
      ],
    );
  }
}
