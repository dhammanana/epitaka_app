import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/pali_definition_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/pali_text_utils.dart';
import '../../reader/providers/reader_tabs_provider.dart';

/// A card showing a single `pali_definition` match: the Pāli sentence that
/// contains the definition, its translation (first activated language), and
/// optional context lines. Tapping the book button opens the source book in
/// the reader at the matching paragraph/line.
class PaliDefinitionCard extends ConsumerWidget {
  final PaliDefinitionResult result;
  final ColorScheme colors;

  const PaliDefinitionCard({
    super.key,
    required this.result,
    required this.colors,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = result.entry;
    final script = ref.watch(settingsProvider).paliScript;

    // Pāli text is rendered in the same script as the reading book.
    final paliStyle = TextStyle(
      fontSize: 13,
      height: 1.4,
      color: colors.onSurface,
      fontFamily: scriptFontFamily(script),
    );
    final contextStyle = TextStyle(
      fontSize: 12,
      height: 1.4,
      color: colors.onSurfaceVariant.withValues(alpha: 0.7),
      fontFamily: scriptFontFamily(script),
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: book id + open-book button
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.bookId,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              InkWell(
                onTap: () => _openBook(context, ref),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.menu_book_outlined,
                        size: 14,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'p${entry.paraId}.${entry.lineId}',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Context lines before (faded)
          if (result.beforeLines.isNotEmpty)
            ...result.beforeLines.map(
              (line) => _contextLine(
                convertPaliToScriptPreservingHtml(line, script),
                contextStyle,
              ),
            ),

          // Main Pāli sentence (converted to the reading-book script)
          Html(
            data: convertPaliToScriptPreservingHtml(result.pali, script),
            style: {
              'body': Style(
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
                fontSize: FontSize(12),
                lineHeight: const LineHeight(1.4),
                fontStyle: FontStyle.italic,
                color: colors.onSurfaceVariant,
              ),
              'b': Style(fontWeight: FontWeight.bold),
              'i': Style(fontStyle: FontStyle.italic),
            },
          ),

          // Translation of the first activated language (HTML: <b>, <i>)
          if (result.translation != null &&
              result.translation!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Html(
                data: result.translation,
                style: {
                  'body': Style(
                    margin: Margins.zero,
                    padding: HtmlPaddings.zero,
                    fontSize: FontSize(12),
                    lineHeight: const LineHeight(1.4),
                    fontStyle: FontStyle.italic,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                  'b': Style(fontWeight: FontWeight.bold),
                  'i': Style(fontStyle: FontStyle.italic),
                },
              ),
            ),

          // Context lines after (faded)
          if (result.afterLines.isNotEmpty)
            ...result.afterLines.map(
              (line) => _contextLine(
                convertPaliToScriptPreservingHtml(line, script),
                contextStyle,
              ),
            ),
        ],
      ),
    );
  }

  Widget _contextLine(String line, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(line, style: style),
    );
  }

  void _openBook(BuildContext context, WidgetRef ref) {
    final entry = result.entry;
    ref
        .read(readerTabsProvider.notifier)
        .openTab(
          ReaderTabInfo(
            bookId: entry.bookId,
            bookName: entry.bookId,
            initialParaId: entry.paraId,
            initialLineId: entry.lineId,
          ),
        );
    context.push('/reader');
  }
}

/// Section wrapper that loads and displays pali_definition results for a word.
class PaliDefinitionSection extends ConsumerWidget {
  final String searchWord;
  final String bookName;
  final ColorScheme colors;

  const PaliDefinitionSection({
    super.key,
    required this.searchWord,
    required this.bookName,
    required this.colors,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(paliDefinitionProvider(searchWord));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_stories, size: 12, color: colors.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              bookName,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        resultsAsync.when(
          loading: () => const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          error: (_, _) => Text(
            'No entry found',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: colors.onSurfaceVariant,
            ),
          ),
          data: (results) {
            if (results.isEmpty) {
              return Text(
                'No entry found',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: colors.onSurfaceVariant,
                ),
              );
            }
            return Column(
              children: results.map((r) {
                return PaliDefinitionCard(result: r, colors: colors);
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
