import 'package:flutter/material.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/utils/app_localizations.dart';
import 'dictionary_search_shared.dart';

/// The whole lookup history as a list over the results, newest first, drawn
/// like the suggestion box. A tap on a word looks it up. [words] come oldest
/// first, as the history keeps them.
class LookupHistoryList extends StatelessWidget {
  const LookupHistoryList({
    super.key,
    required this.words,
    required this.colors,
    required this.onTap,
    required this.onClose,
  });

  final List<String> words;
  final ColorScheme colors;
  final void Function(String word) onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Material(
      color: colors.surface,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      loc.dictionaryHeaderHistoryTitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    tooltip: loc.closePanel,
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 4),
                itemCount: words.length,
                itemBuilder: (context, i) {
                  final word = words[words.length - 1 - i];
                  return SuggestionTile(
                    word: word,
                    colors: colors,
                    onTap: () => onTap(word),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
