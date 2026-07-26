import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/pali_text_utils.dart';
import '../../../shared/utils/html_text_parser.dart';
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
    final paliText = convertPaliToScriptPreservingHtml(result.paliText, script);
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

              ],
            ),
            const SizedBox(height: 4),
            // Pāli snippet with highlighted search terms
            if (paliText.isNotEmpty)
              _HighlightedText(
                text: paliText,
                query: convertedQuery,
                style: AppTypography.bodyPali.copyWith(
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
      return HtmlTextParser.richText(
        text,
        style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final queryLower = q.toLowerCase();

    // Parse HTML into spans first, then highlight search terms within each
    // span's text content. This properly handles <b>/<i> tags in the text.
    final allSpans = HtmlTextParser.parse(text, style);
    final resultSpans = <InlineSpan>[];

    for (final span in allSpans) {
      if (span is! TextSpan || span.text == null || span.text!.isEmpty) {
        resultSpans.add(span);
        continue;
      }

      final spanText = span.text!;
      final spanStyle = span.style ?? style;
      final textLower = spanText.toLowerCase();

      // Find all match positions in this span's text
      final ranges = <MapEntry<int, int>>[];
      int pos = 0;
      while (true) {
        final index = textLower.indexOf(queryLower, pos);
        if (index == -1) break;
        ranges.add(MapEntry(index, index + q.length));
        pos = index + q.length;
      }

      if (ranges.isEmpty) {
        resultSpans.add(TextSpan(text: spanText, style: spanStyle));
        continue;
      }

      // Build highlighted spans
      int lastEnd = 0;
      for (final r in ranges) {
        if (r.key > lastEnd) {
          resultSpans.add(TextSpan(
            text: spanText.substring(lastEnd, r.key),
            style: spanStyle,
          ));
        }
        resultSpans.add(TextSpan(
          text: spanText.substring(r.key, r.value),
          style: spanStyle.copyWith(
            backgroundColor: Colors.yellow.withValues(alpha: 0.3),
            fontWeight: FontWeight.w600,
          ),
        ));
        lastEnd = r.value;
      }
      if (lastEnd < spanText.length) {
        resultSpans.add(TextSpan(
          text: spanText.substring(lastEnd),
          style: spanStyle,
        ));
      }
    }

    return Text.rich(
      TextSpan(style: style, children: resultSpans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
