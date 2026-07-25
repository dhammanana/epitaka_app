import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;

import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';

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

// ── Clickable-word HTML transform (memoized) ───────────────────────────────
//
// Turning plain-text Pāli words inside DPD's meaning_html into clickable
// <a href="lookup://..."> anchors is the most expensive step in rendering a
// DPD entry (two regex passes over the whole HTML string). The bottom sheet
// (DraggableScrollableSheet) rebuilds its entire content tree on every drag
// frame, so without caching this work was being redone dozens of times per
// second while the user simply resized the sheet. Since the same raw HTML
// keeps coming back for a given headword, a small cache makes repeat calls
// effectively free.

final RegExp _htmlTagContentRegex = RegExp(r'>([^<]+)<');
final RegExp _paliWordRegex = RegExp(
  r'[āīūṅñṭḍṇḷṃṛṣūēōĀĪŪṄÑṬḌṆḶṂṚṢŪĒŌa-zA-Z]+(?:\.[\d]+)?',
);

// Spans that should never be broken up into individual clickable words:
//  - <summary>...</summary> — the headword's own gloss (e.g. "free from
//    desire") reads as one heading, not a list of lookup targets, and its
//    English gloss words aren't valid Pāli dictionary entries anyway.
//  - <b>Label:</b> — bold section labels like "Grammar:", "Root:",
//    "Example:" are structural headings, not text to look up.
// Both were previously getting wrapped in <a> like everything else, which
// visually fragmented them (some letters linked/colored, some plain) and,
// combined with the <a> style below, stripped their bold weight entirely.
final RegExp _protectedSpanRegex = RegExp(
  r'(<summary>.*?</summary>)|(<b>[^<]*:</b>)',
  dotAll: true,
);

final Map<String, String> _clickableHtmlCache = {};
const int _clickableHtmlCacheLimit = 200;

/// Wraps Pāli words in [html] with clickable anchor tags so tapping them
/// triggers a dictionary lookup, caching the result per input string.
String _clickableHtmlFor(String html) {
  final cached = _clickableHtmlCache[html];
  if (cached != null) return cached;

  // Swap out protected spans for placeholders so the word-linking pass
  // below can't touch them, then restore the originals afterward.
  final protectedSpans = <String>[];
  final withPlaceholders = html.replaceAllMapped(_protectedSpanRegex, (m) {
    protectedSpans.add(m.group(0)!);
    return '\u0000${protectedSpans.length - 1}\u0000';
  });

  final linked = withPlaceholders.replaceAllMapped(_htmlTagContentRegex, (
    match,
  ) {
    final text = match.group(1)!;
    final processed = text.splitMapJoin(
      _paliWordRegex,
      onMatch: (m) {
        final word = m.group(0)!;
        return '<a href="lookup://$word">$word</a>';
      },
      onNonMatch: (s) => s,
    );
    return '>$processed<';
  });

  final result = linked.replaceAllMapped(RegExp(r'\u0000(\d+)\u0000'), (m) {
    return protectedSpans[int.parse(m.group(1)!)];
  });

  if (_clickableHtmlCache.length >= _clickableHtmlCacheLimit) {
    _clickableHtmlCache.remove(_clickableHtmlCache.keys.first);
  }
  _clickableHtmlCache[html] = result;
  return result;
}

// ── HTML Rich Text Widget ──────────────────────────────────────────────────

/// Renders DPD `meaning_html` using real HTML rendering with `flutter_html`.
/// Supports `<details>/<summary>` expand/collapse, `<b>`, `<i>`, and proper
/// text spacing. Pāli words in the text are wrapped in clickable anchors that
/// trigger [onWordTap] when tapped.
class DpdHtmlRichText extends StatelessWidget {
  final String html;
  final TextStyle baseStyle;
  final Color linkColor;
  final ValueChanged<String> onWordTap;

  const DpdHtmlRichText({
    super.key,
    required this.html,
    required this.baseStyle,
    required this.linkColor,
    required this.onWordTap,
  });

  @override
  Widget build(BuildContext context) {
    final processedHtml = _clickableHtmlFor(html);

    // flutter_html's Html widget emits WidgetSpan placeholders for inline
    // elements (links, <details>/<summary>, etc). During flushSemantics,
    // Flutter groups sibling placeholder fragments and asserts they merge
    // up compatibly; several of these in the same tree (e.g. multiple
    // headword cards stacked in a scroll view) can produce incompatible
    // merge groups and trip the framework's '!conflict' assertion, or a
    // re-entrant flush that trips '!semantics.parentDataDirty'. Word taps
    // are already handled by onLinkTap/onWordTap, so no accessibility is
    // lost by excluding this subtree from the semantics tree.
    return ExcludeSemantics(
      child: Html(
        data: processedHtml,
        onLinkTap: (url, attributes, element) {
          if (url != null && url.startsWith('lookup://')) {
            final word = url.substring(9);
            if (word.isNotEmpty) {
              onWordTap(word);
            }
          }
        },
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
          'details': Style(margin: Margins.only(bottom: 4)),
          'summary': Style(
            fontWeight: FontWeight.w600,
            color: linkColor,
            margin: Margins.only(bottom: 2),
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

/// Displays a DPD headword with lemma and clickable HTML meaning.
///
/// Font sizes follow the app's Pāli typography settings so they scale with
/// the reader (Ctrl/Cmd + / − and the Typography settings screen).
class DpdHeadwordCard extends ConsumerWidget {
  final String lemma;
  final String? meaningHtml;
  final ColorScheme colors;
  final ValueChanged<String> onWordTap;
  final bool compact;

  const DpdHeadwordCard({
    super.key,
    required this.lemma,
    this.meaningHtml,
    required this.colors,
    required this.onWordTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final pali = settings.typography.pali;
    final paliFontFamily = pali.fontFamily.fontFamily;
    // The dictionary uses a slightly smaller type scale than the reader.
    final baseSize = (pali.fontSize * 0.8).clamp(13.0, 26.0);
    final lemmaSize = compact ? (baseSize * 0.9).clamp(12.0, 22.0) : baseSize;
    final meaningSize = compact
        ? (baseSize * 0.85).clamp(11.0, 20.0)
        : baseSize;

    return Material(
      // Use Material (not a Container+DecoratedBox) for the card background so
      // that any ListTile rendered inside the HTML (e.g. <details>/<summary>)
      // finds a Material ancestor and doesn't trigger Flutter's
      // "ListTile background color or ink splashes may be invisible" assertion.
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 6),
        padding: EdgeInsets.all(compact ? 6 : 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lemma,
              style: TextStyle(
                fontSize: lemmaSize,
                height: pali.lineHeight,
                fontWeight: FontWeight.w600,
                color: colors.primary,
                fontFamily: paliFontFamily,
              ),
            ),
            const SizedBox(height: 4),
            if (meaningHtml != null && meaningHtml!.isNotEmpty)
              DpdHtmlRichText(
                html: meaningHtml!,
                baseStyle: TextStyle(
                  fontSize: meaningSize,
                  height: pali.lineHeight,
                  color: colors.onSurface,
                  fontFamily: paliFontFamily,
                ),
                linkColor: colors.primary,
                onWordTap: onWordTap,
              )
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

// ── Dictionary definition section ──────────────────────────────────────────

/// Shows definitions from a specific dictionary book (not DPD).
class DictDefinitionSection extends ConsumerWidget {
  final int bookId;
  final String bookName;
  final String searchWord;
  final ColorScheme colors;

  const DictDefinitionSection({
    super.key,
    required this.bookId,
    required this.bookName,
    required this.searchWord,
    required this.colors,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final typo = settings.typography.typographyFor(
      settings.primaryTranslationLang,
    );
    final defFontFamily = typo.fontFamily.fontFamily;
    final defFontSize = (typo.fontSize * 0.8).clamp(12.0, 24.0);
    final defLineHeight = typo.lineHeight;

    final key = DictLookupKey(bookId, searchWord);
    final defsAsync = ref.watch(dictionaryDefinitionProvider(key));

    Widget header() => Row(
      children: [
        Icon(Icons.book, size: 12, color: colors.onSurfaceVariant),
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
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.marginMobile,
        AppDimensions.sm,
        AppDimensions.marginMobile,
        0,
      ),
      child: defsAsync.when(
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
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header(),
              const SizedBox(height: 4),
              ...definitions.map((def) {
                final definition = def['definition'] as String? ?? '';
                final plain = stripHtmlToPlainText(definition);
                return Material(
                  color: colors.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: BorderSide(
                      color: colors.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      plain,
                      style: TextStyle(
                        fontSize: defFontSize,
                        height: defLineHeight,
                        color: colors.onSurface,
                        fontFamily: defFontFamily,
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
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
    final trans = settings.typography.typographyFor(
      settings.primaryTranslationLang,
    );
    final paliFontFamily = pali.fontFamily.fontFamily;
    final paliSize = (pali.fontSize * 0.8).clamp(13.0, 26.0);
    final transSize = (trans.fontSize * 0.8).clamp(12.0, 24.0);

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
                            fontSize: transSize * 0.8,
                            color: colors.onSurfaceVariant,
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
