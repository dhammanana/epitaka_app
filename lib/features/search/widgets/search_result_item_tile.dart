import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/pali_text_utils.dart';
import '../providers/search_provider.dart';

/// A single search result card showing book info, Pāli/translation snippet,
/// and VRI page badge.
class SearchResultItemTile extends ConsumerWidget {
  final SearchResultItem result;
  final String? searchQuery;
  final VoidCallback onTap;

  const SearchResultItemTile({
    super.key,
    required this.result,
    this.searchQuery,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final script = ref.watch(settingsProvider).paliScript;
    final paliText = convertPaliToScript(result.paliText, script);
    final paliFont = scriptFontFamily(script);
    final translation = result.translation;
    final convertedQuery =
        searchQuery != null ? convertSearchQueryForScript(searchQuery!, script) : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: AppDimensions.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: book name + para badge
            Row(
              children: [
                Icon(
                  Icons.import_contacts,
                  size: 14,
                  color: colors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    result.bookId,
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: Text(
                    '§${result.firstParaId}',
                    style: AppTypography.labelSmall.copyWith(
                      fontSize: 10,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Pāli snippet with highlighted search terms
            if (paliText.isNotEmpty)
              _HighlightedText(
                text: paliText,
                query: convertedQuery,
                style: AppTypography.bodyPali.copyWith(
                  fontFamily: paliFont,
                  fontSize: 15,
                  color: colors.onSurface,
                ),
                maxLines: 2,
              ),
            // Translation snippet
            if (translation != null && translation.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _HighlightedText(
                  text: translation,
                  query: searchQuery,
                  style: AppTypography.bodyTranslation.copyWith(
                    fontSize: 13,
                    color: colors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A text widget that highlights matching query terms.
class _HighlightedText extends StatelessWidget {
  final String text;
  final String? query;
  final TextStyle style;
  final int maxLines;

  const _HighlightedText({
    required this.text,
    this.query,
    required this.style,
    this.maxLines = 3,
  });

  @override
  Widget build(BuildContext context) {
    final q = query;
    if (q == null || q.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final queryLower = q.toLowerCase();
    final textLower = text.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final index = textLower.indexOf(queryLower, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      spans.add(TextSpan(
        text: text.substring(index, index + q.length),
        style: style.copyWith(
          backgroundColor: Colors.yellow.withValues(alpha: 0.3),
          fontWeight: FontWeight.w600,
        ),
      ));

      start = index + q.length;
    }

    return RichText(
      text: TextSpan(children: spans, style: style),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
