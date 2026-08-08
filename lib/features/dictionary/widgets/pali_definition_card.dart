import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/pali_definition_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/pali_text_utils.dart';
import '../../../core/utils/responsive_breakpoint.dart';
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
    final settings = ref.watch(settingsProvider);
    final script = settings.paliScript;
    final pali = settings.typography.pali;
    final trans = settings.typography.typographyFor(
      settings.primaryTranslationLang,
    );

    // Pāli text is rendered in the same script as the reading book, using
    // the user's Pāli typography (font family / size / line-height). The
    // dictionary uses a slightly smaller scale than the reader.
    final paliStyle = TextStyle(
      fontSize: (pali.fontSize * 0.8).clamp(12.0, 26.0),
      height: pali.lineHeight,
      color: colors.onSurface,
      fontFamily: scriptFontFamily(script) ?? pali.fontFamily.fontFamily,
    );
    final contextStyle = TextStyle(
      fontSize: (pali.fontSize * 0.72).clamp(11.0, 24.0),
      height: pali.lineHeight,
      color: colors.onSurfaceVariant.withValues(alpha: 0.7),
      fontFamily: scriptFontFamily(script) ?? pali.fontFamily.fontFamily,
    );
    final transStyle = TextStyle(
      fontSize: (trans.fontSize * 0.8).clamp(11.0, 24.0),
      height: trans.lineHeight,
      fontStyle: FontStyle.italic,
      color: colors.onSurfaceVariant.withValues(alpha: 0.8),
      fontFamily: trans.fontFamily.fontFamily,
    );

    return Material(
      // Material (not Container+DecoratedBox) so any ListTile rendered inside
      // the HTML (e.g. <details>/<summary>) finds a Material ancestor and
      // avoids Flutter's "ListTile background color or ink splashes may be
      // invisible" assertion.
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(6),
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
                  fontSize: FontSize(paliStyle.fontSize ?? 13),
                  lineHeight: LineHeight(pali.lineHeight),
                  fontStyle: FontStyle.italic,
                  color: colors.onSurface,
                  fontFamily: paliStyle.fontFamily,
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
                      fontSize: FontSize(transStyle.fontSize ?? 12),
                      lineHeight: LineHeight(trans.lineHeight),
                      fontStyle: FontStyle.italic,
                      color: transStyle.color,
                      fontFamily: transStyle.fontFamily,
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
      ),
    );
  }

  /// A faded context line (before/after the main sentence) rendered with
  /// `Html` so inline markup like `<b>` / `<i>` is honoured, matching the
  /// main Pāli sentence and translation above.
  Widget _contextLine(String line, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Html(
        data: line,
        style: {
          'body': Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            fontSize: FontSize(style.fontSize ?? 11),
            lineHeight: LineHeight(style.height ?? 1.4),
            color: style.color,
            fontFamily: style.fontFamily,
          ),
          'b': Style(fontWeight: FontWeight.bold),
          'i': Style(fontStyle: FontStyle.italic),
        },
      ),
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
    if (!ResponsiveBreakpoint.isDesktop(context)) {
      context.push('/reader');
    }
  }
}

/// Number of `pali_definition` cards shown before the "Show more" button.
const int _paliDefinitionInitialCount = 3;

/// Section wrapper that loads and displays pali_definition results for a word.
///
/// Results are sorted by the provider so the closest words appear first;
/// only the first [_paliDefinitionInitialCount] cards are shown by default,
/// with a "Show more" button to reveal the rest.
class PaliDefinitionSection extends ConsumerStatefulWidget {
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
  ConsumerState<PaliDefinitionSection> createState() =>
      _PaliDefinitionSectionState();
}

class _PaliDefinitionSectionState extends ConsumerState<PaliDefinitionSection> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant PaliDefinitionSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new search word starts collapsed again.
    if (oldWidget.searchWord != widget.searchWord) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(paliDefinitionProvider(widget.searchWord));
    final colors = widget.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.marginMobile,
        AppDimensions.sm,
        AppDimensions.marginMobile,
        0,
      ),
      child: resultsAsync.when(
        // While loading, show the header + a small spinner.
        loading: () => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: 4),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
        // No linked sentence for this word → hide the section entirely.
        error: (_, _) => const SizedBox.shrink(),
        data: (results) {
          if (results.isEmpty) return const SizedBox.shrink();

          final visible = _expanded
              ? results
              : results.take(_paliDefinitionInitialCount).toList();
          final hiddenCount = results.length - visible.length;
          // Show the toggle whenever there is something to collapse back
          // (i.e. when expanded, or when hidden cards remain collapsed).
          final showToggle = _expanded || hiddenCount > 0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: 4),
              ...visible.map(
                (r) => PaliDefinitionCard(result: r, colors: colors),
              ),
              if (showToggle)
                _PaliMoreButton(
                  label: _expanded
                      ? AppLocalizations.of(context).lessLabel
                      : AppLocalizations.of(context)
                            .showNMore(hiddenCount),
                  icon: _expanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  colors: colors,
                  onTap: () => setState(() => _expanded = !_expanded),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _header() => Row(
    children: [
      Icon(Icons.auto_stories, size: 12, color: widget.colors.onSurfaceVariant),
      const SizedBox(width: 4),
      Text(
        widget.bookName,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: widget.colors.onSurfaceVariant,
        ),
      ),
    ],
  );
}

/// A compact "Show N more" / "Less" toggle for the pali_definition section.
class _PaliMoreButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final ColorScheme colors;
  final VoidCallback onTap;

  const _PaliMoreButton({
    required this.label,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: SelectionContainer.disabled(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colors.outlineVariant.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.3),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: colors.onSurfaceVariant),
                const SizedBox(width: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
