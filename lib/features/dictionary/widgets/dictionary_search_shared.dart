import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;

import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';

/// Minimum query length before "Did you mean?" prefix suggestions are shown
/// in the dictionary (sheet and panel). Short prefixes are too ambiguous to
/// suggest from, and matching on them floods the results with noise.
///
/// Note: the "no matches found" empty state lives inside the suggestion
/// section, so below this threshold a short query with no DPD match renders
/// a blank results area rather than a noise card — intentional.
const int kDictionarySuggestionMinLength = 3;

// ── HTML → plain text ─────────────────────────────────────────────────────

/// Strips HTML tags and collapses whitespace so dictionary definitions from
/// the `dictionary` table (which are stored as HTML) render as readable
/// plain text instead of raw markup.
String stripHtmlToPlainText(String html) {
  return html
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'&nbsp;'), ' ')
      .replaceAll(RegExp(r'&amp;'), '&')
      .replaceAll(RegExp(r'&lt;'), '<')
      .replaceAll(RegExp(r'&gt;'), '>')
      .replaceAll(RegExp(r'&quot;'), '"')
      .replaceAll(RegExp(r'&#39;'), "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

// ── Cached dictionary definitions provider (shared by panel and sheet) ─────

/// Cache key for dictionary definitions from epitaka.dictionary.
class DictLookupKey {
  final int bookId;
  final String word;
  const DictLookupKey(this.bookId, this.word);

  @override
  bool operator ==(Object other) =>
      other is DictLookupKey && bookId == other.bookId && word == other.word;

  @override
  int get hashCode => Object.hash(bookId, word);
}

/// Provider that caches dictionary definitions from epitaka.dictionary.
final dictionaryDefinitionProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, DictLookupKey>((ref, key) async {
      try {
        final db = await ref.read(epitakaDbProvider.future);
        final rows = await db
            .customSelect(
              'SELECT definition FROM dictionary WHERE word = ? AND book_id = ? LIMIT 5',
              variables: [
                Variable.withString(key.word.toLowerCase()),
                Variable.withInt(key.bookId),
              ],
            )
            .get();
        return rows.map((r) => r.data).toList();
      } catch (_) {
        return [];
      }
    });

// ── HTML Rich Text Widget ──────────────────────────────────────────────────

/// Renders DPD `meaning_html` using real HTML rendering with `flutter_html`.
/// Supports `<details>/<summary>` expand/collapse, `<b>`, `<i>`, and proper
/// text spacing.
///
/// The raw HTML is rendered as-is — identical to how the other dictionaries'
/// definitions render ([DictHtmlContent]) — with no clickable-word
/// transformation. (DPD entries used to have every Pāli word wrapped in
/// `lookup://` anchors via two regex passes over the whole HTML string,
/// which was the most expensive step in rendering a DPD entry and slowed
/// the first dictionary load; word-links in the meaning were dropped in
/// favor of parity with the other dictionaries.)
class DpdHtmlRichText extends StatelessWidget {
  final String html;
  final TextStyle baseStyle;
  final Color linkColor;

  const DpdHtmlRichText({
    super.key,
    required this.html,
    required this.baseStyle,
    required this.linkColor,
  });

  @override
  Widget build(BuildContext context) {
    // flutter_html's Html widget emits WidgetSpan placeholders for inline
    // elements (links, <details>/<summary>, etc). During flushSemantics,
    // Flutter groups sibling placeholder fragments and asserts they merge
    // up compatibly; several of these in the same tree (e.g. multiple
    // headword cards stacked in a scroll view) can produce incompatible
    // merge groups and trip the framework's '!conflict' assertion, or a
    // re-entrant flush that trips '!semantics.parentDataDirty'. The content
    // isn't independently tappable, so excluding this subtree from the
    // semantics tree loses no accessibility.
    return ExcludeSemantics(
      child: Html(
        data: html,
        style: {
          'body': Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            fontSize: FontSize(baseStyle.fontSize ?? 14),
            lineHeight: LineHeight(1.5),
            color: baseStyle.color,
            fontFamily: baseStyle.fontFamily,
          ),
          'p': Style(margin: Margins.only(bottom: 6)),
          'b': Style(fontWeight: FontWeight.bold),
          'strong': Style(fontWeight: FontWeight.bold),
          'i': Style(fontStyle: FontStyle.italic),
          'em': Style(fontStyle: FontStyle.italic),
          'u': Style(textDecoration: TextDecoration.underline),
          // No fontWeight here on purpose: this used to hardcode w500,
          // which silently downgraded any <b> ancestor's bold weight
          // whenever a word inside it got linkified (e.g. bold section
          // labels, or the highlighted headword inside an example verse).
          // Leaving weight unset lets it inherit from the ancestor as
          // normal HTML cascade would.
          'a': Style(color: linkColor, textDecoration: TextDecoration.none),
          // Keep expand/collapse controls compact and aligned to the
          // trailing edge; the definition itself remains full width.
          'details': Style(margin: Margins.only(bottom: 4)),
          'summary': Style(
            display: Display.inlineBlock,
            fontWeight: FontWeight.w600,
            color: linkColor,
            margin: Margins.only(left: 4, bottom: 2),
            padding: HtmlPaddings.zero,
          ),
          'div': Style(margin: Margins.only(bottom: 2)),
          'ul': Style(
            margin: Margins.only(bottom: 4),
            padding: HtmlPaddings.only(left: 16),
          ),
          'li': Style(margin: Margins.only(bottom: 2)),
        },
      ),
    );
  }
}

// ── Generic dictionary HTML content ────────────────────────────────────────

/// Renders HTML content from epitaka.dictionary definitions.
class DictHtmlContent extends StatelessWidget {
  final String html;
  final TextStyle baseStyle;
  final Map<String, Style>? extraStyles;

  const DictHtmlContent({
    super.key,
    required this.html,
    required this.baseStyle,
    this.extraStyles,
  });

  @override
  Widget build(BuildContext context) {
    if (html.trim().isEmpty) return const SizedBox.shrink();

    // Same WidgetSpan merge-up hazard as DpdHtmlRichText above — this
    // widget renders raw HTML from arbitrary dictionary books via
    // flutter_html, so it's just as exposed to the semantics '!conflict'
    // assertion. This content isn't independently tappable, so excluding
    // it from semantics is a straightforward safety measure.
    return ExcludeSemantics(
      child: Html(
        data: html,
        style: {
          'body': Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            fontSize: FontSize(baseStyle.fontSize ?? 14),
            lineHeight: const LineHeight(1.4),
            color: baseStyle.color,
            fontFamily: baseStyle.fontFamily,
          ),
          'p': Style(margin: Margins.only(bottom: 2)),
          'b': Style(fontWeight: FontWeight.bold),
          'i': Style(fontStyle: FontStyle.italic),
          'u': Style(textDecoration: TextDecoration.underline),
          'ul': Style(
            margin: Margins.zero,
            padding: HtmlPaddings.only(left: 16),
          ),
          'li': Style(margin: Margins.only(bottom: 2)),
          if (extraStyles != null) ...extraStyles!,
        },
      ),
    );
  }
}

// ── DPD Headword Card ──────────────────────────────────────────────────────

/// Displays a DPD headword with lemma and HTML meaning (rendered as-is,
/// like the other dictionaries' definitions).
///
/// Collapsed by default: the headword row carries the expand/collapse
/// chevron plus a short plain-text preview of the meaning (the first
/// `summary` gloss of the entry, clipped to two lines). Tapping the
/// headword expands the full detail HTML.
///
/// Font sizes follow the app's Pāli typography settings so they scale with
/// the reader (Ctrl/Cmd + / − and the Typography settings screen).
class DpdHeadwordCard extends ConsumerStatefulWidget {
  final String lemma;
  final String? meaningHtml;
  final ColorScheme colors;
  final bool compact;
  final bool showBorder;

  const DpdHeadwordCard({
    super.key,
    required this.lemma,
    this.meaningHtml,
    required this.colors,
    this.compact = false,
    this.showBorder = true,
  });

  @override
  ConsumerState<DpdHeadwordCard> createState() => _DpdHeadwordCardState();
}

class _DpdHeadwordCardState extends ConsumerState<DpdHeadwordCard> {
  // Collapsed by default: the card shows the headword + a short meaning
  // preview; tapping the headword expands the full detail.
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant DpdHeadwordCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // New word → collapsed by default.
    if (oldWidget.lemma != widget.lemma) _expanded = false;
  }

  /// Strip <details>/<summary> HTML so flutter_html doesn't render its own
  /// expand/collapse chevrons — we handle that at the lemma heading level.
  String _stripDetailsTags(String html) {
    return html
        .replaceAll(RegExp(r'<details[^>]*>'), '')
        .replaceAll(RegExp(r'</details>'), '')
        .replaceAll(RegExp(r'<summary[^>]*>'), '')
        .replaceAll(RegExp(r'</summary>'), '');
  }

  /// The summary HTML shown in the collapsed state: the first `summary`
  /// gloss of the DPD entry (e.g. "free from desire"), or the whole entry
  /// when there is no `summary` tag. Rendered as HTML so bold/italic
  /// styling is preserved, with no line truncation.
  String _summaryHtml(String html) {
    final summaryMatch = RegExp(
      r'<summary[^>]*>(.*?)</summary>',
      dotAll: true,
    ).firstMatch(html);
    if (summaryMatch != null) return summaryMatch.group(1)!;
    return _stripDetailsTags(html);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final pali = settings.typography.pali;
    final paliFontFamily = pali.fontFamily.fontFamily;
    // The dictionary uses a slightly smaller type scale than the reader.
    final baseSize = (pali.fontSize * 0.8).clamp(13.0, 26.0);
    final lemmaSize = widget.compact
        ? (baseSize * 0.9).clamp(12.0, 22.0)
        : baseSize;
    final meaningSize = widget.compact
        ? (baseSize * 0.85).clamp(11.0, 20.0)
        : baseSize;

    final hasMeaning =
        widget.meaningHtml != null && widget.meaningHtml!.isNotEmpty;
    final colors = widget.colors;

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: hasMeaning ? () => setState(() => _expanded = !_expanded) : null,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: AppDimensions.sm),
          padding: EdgeInsets.zero,
          decoration: widget.showBorder
              ? BoxDecoration(
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.55),
                  ),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Lemma heading — tappable to expand/collapse meaning.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.lemma,
                        style: TextStyle(
                          fontSize: lemmaSize,
                          height: pali.lineHeight * 0.9,
                          fontWeight: FontWeight.w600,
                          fontFamily: paliFontFamily,
                        ),
                      ),
                    ),
                    if (hasMeaning)
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 20,
                        color: colors.onSurfaceVariant,
                      ),
                  ],
                ),
              ),
              // Summary preview — shown only when collapsed. Full summary
              // HTML (no line truncation) so `<b>` / `<i>` render correctly.
              if (hasMeaning && !_expanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                  child: DpdHtmlRichText(
                    html: _summaryHtml(widget.meaningHtml!),
                    baseStyle: TextStyle(
                      fontSize: meaningSize * 0.95,
                      height: pali.lineHeight * 0.95,
                      color: colors.onSurfaceVariant,
                      fontFamily: paliFontFamily,
                    ),
                    linkColor: colors.primary,
                  ),
                ),
              // Detail meaning — shown only when expanded.
              if (hasMeaning && _expanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                  child: DpdHtmlRichText(
                    html: _stripDetailsTags(widget.meaningHtml!),
                    baseStyle: TextStyle(
                      fontSize: meaningSize,
                      height: pali.lineHeight,
                      color: colors.onSurface,
                      fontFamily: paliFontFamily,
                    ),
                    linkColor: colors.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dictionary definition section ──────────────────────────────────────────

/// Shows definitions from a specific dictionary book (not DPD).
class DictDefinitionSection extends ConsumerStatefulWidget {
  final int bookId;
  final String bookName;
  final String searchWord;
  final ColorScheme colors;
  final bool compact;

  const DictDefinitionSection({
    super.key,
    required this.bookId,
    required this.bookName,
    required this.searchWord,
    required this.colors,
    this.compact = false,
  });

  @override
  ConsumerState<DictDefinitionSection> createState() =>
      _DictDefinitionSectionState();
}

class _DictDefinitionSectionState extends ConsumerState<DictDefinitionSection> {
  bool _expanded = true;

  @override
  void didUpdateWidget(covariant DictDefinitionSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchWord != widget.searchWord) _expanded = true;
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final settings = ref.watch(settingsProvider);
    final pali = settings.typography.pali;
    final defFontFamily = pali.fontFamily.fontFamily;
    final defFontSize = (pali.fontSize * 0.8).clamp(12.0, 24.0);
    final defLineHeight = pali.lineHeight;

    final key = DictLookupKey(widget.bookId, widget.searchWord);
    final defsAsync = ref.watch(dictionaryDefinitionProvider(key));
    final colors = widget.colors;

    Widget header() => Row(
      children: [
        Icon(Icons.book, size: 12, color: colors.onSurfaceVariant),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            widget.bookName,
            style: TextStyle(
              fontSize: (pali.fontSize * 0.55).clamp(9.0, 14.0),
              fontWeight: FontWeight.w600,
              color: colors.onSurfaceVariant,
              fontFamily: defFontFamily,
            ),
          ),
        ),
      ],
    );

    return defsAsync.when(
      // While loading, show the header + a small spinner.
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header(),
          const SizedBox(height: 4),
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ),
      // No record for this word in this dictionary → hide entirely
      // (no header, no "No entry found" text).
      error: (_, _) => const SizedBox.shrink(),
      data: (definitions) {
        if (definitions.isEmpty) return const SizedBox.shrink();
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.sm,
                  vertical: AppDimensions.xs,
                ),
                child: Row(
                  children: [
                    Expanded(child: header()),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.xs,
                  2,
                  AppDimensions.xs,
                  AppDimensions.xs,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: definitions.map((def) {
                    final definition = def['definition'] as String? ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: DictHtmlContent(
                        html: definition,
                        baseStyle: TextStyle(
                          fontSize: defFontSize,
                          height: defLineHeight,
                          color: colors.onSurface,
                          fontFamily: defFontFamily,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        );

        if (widget.compact) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.xs),
            child: content,
          );
        }

        return Container(
          margin: const EdgeInsets.only(bottom: AppDimensions.sm),
          decoration: BoxDecoration(
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.55),
            ),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          child: content,
        );
      },
    );
  }
}

// ── Suggestion Card (fallback "Did you mean?" tile) ────────────────────────

/// A compact suggestion tile for prefix search results.
///
/// Font sizes follow the app's typography settings.
class SuggestionTile extends ConsumerWidget {
  final String word;
  final String? meaningPreview;
  final VoidCallback onTap;
  final ColorScheme colors;

  const SuggestionTile({
    super.key,
    required this.word,
    this.meaningPreview,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final pali = settings.typography.pali;
    final paliFontFamily = pali.fontFamily.fontFamily;
    final paliSize = (pali.fontSize * 0.8).clamp(13.0, 26.0);
    final previewSize = (pali.fontSize * 0.64).clamp(11.0, 20.0);

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      color: colors.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: EdgeInsets.all(
            colors.brightness == Brightness.light ? 8 : 10,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      word,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                        fontSize: paliSize,
                        fontFamily: paliFontFamily,
                      ),
                    ),
                    if (meaningPreview != null && meaningPreview!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          _stripHtml(meaningPreview!),
                          style: TextStyle(
                            fontSize: previewSize,
                            height: pali.lineHeight * 0.95,
                            color: colors.onSurfaceVariant,
                            fontFamily: paliFontFamily,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: colors.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
