import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_localizations.dart';
import '../../../shared/widgets/history_list.dart';
import '../providers/dictionary_font_scale_provider.dart';

/// The whole lookup history as a list over the results, newest first, drawn
/// with the shared history rows. A tap on a word looks it up. [words] come
/// oldest first, as the history keeps them.
///
/// The text box keeps the cursor. The host moves [selectedIndex] with the
/// arrow keys (row `i` is word `words.length - 1 - i`) and closes the list
/// on Escape.
class LookupHistoryList extends ConsumerWidget {
  const LookupHistoryList({
    super.key,
    required this.words,
    required this.colors,
    required this.onTap,
    this.onClose,
    this.onDelete,
    this.onClear,
    this.selectedIndex = -1,
    this.controller,
  });

  final List<String> words;
  final ColorScheme colors;
  final void Function(String word) onTap;
  /// Null when the list shows because the box is empty: nothing to close.
  final VoidCallback? onClose;
  final void Function(String word)? onDelete;
  final VoidCallback? onClear;
  final int selectedIndex;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final pali = ref.watch(dictionaryPaliProvider);
    final style = historyTitleStyle(
      colors,
    ).copyWith(fontFamily: pali.fontFamily.fontFamily);
    return Material(
      color: colors.surface,
      child: HistoryList(
        title: loc.dictionaryHeaderHistoryTitle,
        onClear: onClear,
        onClose: onClose,
        controller: controller,
        selectedIndex: selectedIndex < 0 ? null : selectedIndex,
        items: [
          for (final word in words.reversed)
            HistoryItem(
              key: word,
              title: Text(word, style: style),
              onTap: () => onTap(word),
              onDelete: onDelete == null ? null : () => onDelete!(word),
            ),
        ],
      ),
    );
  }
}
