import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show BoxHitTestResult, RenderParagraph;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/settings_provider.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/pali_script_converter.dart';
import '../../core/utils/pali_text_utils.dart';
import '../../features/reader/utils/reader_word_hit_test.dart'
    show cleanPali, wordRangeAt;
import 'nissaya_text.dart';
import '../utils/html_text_parser.dart';

/// A single line of preview content.
class PreviewLineData {
  final int paraId;
  final int lineId;
  final String pali;
  final Map<String, String> translations;

  const PreviewLineData({
    required this.paraId,
    required this.lineId,
    required this.pali,
    this.translations = const {},
  });
}

/// Renders a list of Pāli + translation lines using the same typography
/// settings as the reader (LanguageTypography, color pairs, script).
///
/// Used by [ParagraphPreviewSheet] (book-link sections and search previews).
/// Highlights the matched paragraph (or, when [highlightLineId] is given,
/// only the exact matched line) with a left border + background tint.
/// Supports optional Pāli word tap via [onPaliWordTap] (e.g. dictionary lookup).
class PreviewContent extends ConsumerWidget {
  static final Map<String, String> _scriptCache = {};

  final List<PreviewLineData> lines;

  /// Paragraph to highlight. When [highlightLineId] is null the whole
  /// paragraph is highlighted; otherwise only the matching line is.
  final int? highlightParaId;

  /// When set together with [highlightParaId], only this line of that
  /// paragraph gets the highlight (used by search previews).
  final int? highlightLineId;
  final int? firstSnippetIndex;
  final String? paliSnippet;

  /// Key for the target line the owning sheet scrolls to on open. All other
  /// lines get a lightweight [ValueKey], so only the target carries the cost
  /// of a [GlobalKey].
  final GlobalKey? targetLineKey;

  /// Index into [lines] of the target line (matches [targetLineKey]).
  final int? targetLineIndex;

  /// Called when the user double-taps on a Pāli text (opens dictionary).
  final ValueChanged<String>? onPaliWordTap;

  const PreviewContent({
    super.key,
    required this.lines,
    this.highlightParaId,
    this.highlightLineId,
    this.firstSnippetIndex,
    this.paliSnippet,
    this.targetLineKey,
    this.targetLineIndex,
    this.onPaliWordTap,
  });

  /// Script conversion with a small FIFO cache: rebuilds (scroll, unrelated
  /// settings changes) must not re-run the expensive converter for every
  /// line. Keyed by script + source text so identical lines share entries.
  static String _cachedConvert(String text, Script script) {
    final key = '${script.name}|$text';
    final hit = _scriptCache[key];
    if (hit != null) return hit;
    final converted = convertPaliToScriptPreservingHtml(text, script);
    if (_scriptCache.length >= 500) {
      _scriptCache.remove(_scriptCache.keys.first);
    }
    _scriptCache[key] = converted;
    return converted;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final script = ref.watch(settingsProvider.select((s) => s.paliScript));
    final paliTypo = ref.watch(
      settingsProvider.select((s) => s.typography.pali),
    );
    final paliColor = ref
        .watch(settingsProvider.select((s) => s.paliColorPair))
        .resolve(brightness);
    final transColor = ref
        .watch(settingsProvider.select((s) => s.translationColorPair))
        .resolve(brightness);
    final typography = ref.watch(settingsProvider.select((s) => s.typography));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.asMap().entries.map((entry) {
        final index = entry.key;
        final line = entry.value;
        final isTargetPara = line.paraId == highlightParaId;
        // When [highlightLineId] is given (search previews) highlight only
        // the exact matched line; otherwise keep the paragraph-level
        // highlight used by book-link / AI-citation previews.
        final isMatch =
            isTargetPara &&
            (highlightLineId == null || line.lineId == highlightLineId);
        // The snippet (with <mark> highlights) always shows on the line the
        // caller pointed at, independent of which line is highlighted.
        final isFirstSnippetLine =
            isTargetPara &&
            firstSnippetIndex != null &&
            index == firstSnippetIndex;

        return RepaintBoundary(
          child: PreviewLine(
            key: index == targetLineIndex && targetLineKey != null
                ? targetLineKey
                : ValueKey('${line.paraId}_${line.lineId}_$index'),
            line: line,
            isMatch: isMatch,
            isNewPara: index > 0 && line.paraId != lines[index - 1].paraId,
            paliSnippet: isFirstSnippetLine ? paliSnippet : null,
            script: script,
            colors: colors,
            paliColor: paliColor,
            transColor: transColor,
            paliTypo: paliTypo,
            typography: typography,
            onPaliWordTap: onPaliWordTap,
          ),
        );
      }).toList(),
    );
  }
}

/// One preview line: Pāli + translations with match highlight.
///
/// Const-constructible so list parents rebuild cheaply; callers wrap it in a
/// [RepaintBoundary] to isolate repaints while scrolling.
class PreviewLine extends StatelessWidget {
  final PreviewLineData line;

  /// Whether this line gets the match highlight (left border + tint).
  final bool isMatch;

  /// Whether to render the paragraph gap above this line.
  final bool isNewPara;

  /// When non-null/non-empty, rendered instead of [line.pali] (search hit
  /// with `<mark>` highlights).
  final String? paliSnippet;

  final Script script;
  final ColorScheme colors;
  final Color paliColor;
  final Color transColor;
  final LanguageTypography paliTypo;
  final TypographySettings typography;

  /// Called when the user double-taps on a Pāli text (opens dictionary).
  final ValueChanged<String>? onPaliWordTap;

  const PreviewLine({
    super.key,
    required this.line,
    required this.isMatch,
    required this.isNewPara,
    this.paliSnippet,
    required this.script,
    required this.colors,
    required this.paliColor,
    required this.transColor,
    required this.paliTypo,
    required this.typography,
    this.onPaliWordTap,
  });

  @override
  Widget build(BuildContext context) {
    final snippet = paliSnippet;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Paragraph gap
        if (isNewPara) const SizedBox(height: 12),

        // Match-highlighted paragraph block
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isMatch
                ? colors.primaryContainer.withValues(alpha: 0.25)
                : null,
            border: isMatch
                ? Border(left: BorderSide(color: colors.primary, width: 3))
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pāli text
              if (snippet != null && snippet.isNotEmpty)
                _buildPaliSnippet(snippet)
              else if (line.pali.isNotEmpty)
                _buildPaliLine(line.pali),
              // Translations
              ...line.translations.entries.map((tEntry) {
                if (tEntry.value.isEmpty) return const SizedBox.shrink();
                // Resolve the effective typography (override or scaled
                // default) so previews follow the global font-size
                // controls, matching the reader.
                final langTypo = typography.typographyFor(tEntry.key);
                return _buildTranslationLine(
                  tEntry.value,
                  transColor,
                  langTypo,
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaliSnippet(String snippet) {
    // Convert the snippet to match the target script (preserving HTML <mark> tags)
    final converted = PreviewContent._cachedConvert(snippet, script);
    final effectiveColor = paliTypo.effectiveColor(paliColor);
    final baseStyle = TextStyle(
      fontFamily: scriptFontFamily(script),
      fontSize: paliTypo.fontSize,
      height: paliTypo.lineHeight,
      fontWeight: paliTypo.bold ? FontWeight.w700 : FontWeight.w400,
      fontStyle: paliTypo.italic ? FontStyle.italic : FontStyle.normal,
      decoration: paliTypo.underline
          ? TextDecoration.underline
          : TextDecoration.none,
      color: effectiveColor,
    );

    return _buildTappablePali(
      child: HtmlTextParser.richText(converted, baseStyle, maxLines: null),
    );
  }

  Widget _buildPaliLine(String text) {
    final effectiveColor = paliTypo.effectiveColor(paliColor);
    final baseStyle = TextStyle(
      fontFamily: scriptFontFamily(script),
      fontSize: paliTypo.fontSize,
      height: paliTypo.lineHeight,
      fontWeight: paliTypo.bold ? FontWeight.w700 : FontWeight.w400,
      fontStyle: paliTypo.italic ? FontStyle.italic : FontStyle.normal,
      decoration: paliTypo.underline
          ? TextDecoration.underline
          : TextDecoration.none,
      color: effectiveColor,
    );

    // Pre-converted via the shared cache; parse directly instead of going
    // through PaliHtmlText (which would re-watch settings + re-convert).
    final converted = PreviewContent._cachedConvert(text, script);
    return _buildTappablePali(
      child: HtmlTextParser.richText(converted, baseStyle, maxLines: null),
    );
  }

  /// Wrap Pāli content in GestureDetector for double-tap dictionary lookup.
  ///
  /// The double-tap resolves the word UNDER the pointer (hit-tested from the
  /// tap position), not the first word of the line — the line text may wrap
  /// onto multiple visual rows and may have been converted to a non-Roman
  /// script, so a plain text split cannot locate the tapped word. The
  /// [Builder] provides a context whose render subtree contains exactly this
  /// line's text paragraph, which the hit-test needs.
  Widget _buildTappablePali({required Widget child}) {
    if (onPaliWordTap == null) return child;

    return Builder(
      builder: (context) {
        Offset? doubleTapPosition;
        return GestureDetector(
          onDoubleTapDown: (details) {
            doubleTapPosition = details.globalPosition;
          },
          onDoubleTap: () {
            final pos = doubleTapPosition;
            if (pos == null) return;
            _lookupWordAtTap(context, pos);
          },
          child: child,
        );
      },
    );
  }

  /// Look up the Pāli word rendered under [globalPosition] inside [context]'s
  /// render subtree (one Pāli line).
  ///
  /// Hit-tests the subtree to find the [RenderParagraph] under the pointer,
  /// maps the tap offset to a text position, expands to the surrounding word
  /// (space/punctuation-delimited, same rules as the reader), converts it
  /// back to Roman for the dictionary, and reports it via [onPaliWordTap].
  /// Taps on whitespace/punctuation (no word there) look up nothing.
  void _lookupWordAtTap(BuildContext context, Offset globalPosition) {
    final onTap = onPaliWordTap;
    if (onTap == null) return;

    final renderBox = context.findRenderObject();
    if (renderBox is! RenderBox || !renderBox.attached) return;

    final result = BoxHitTestResult();
    renderBox.hitTest(
      result,
      position: renderBox.globalToLocal(globalPosition),
    );

    RenderParagraph? paragraph;
    for (final entry in result.path) {
      if (entry.target is RenderParagraph) {
        paragraph = entry.target as RenderParagraph;
        break;
      }
    }
    if (paragraph == null) return;

    final localInParagraph =
        globalPosition - paragraph.localToGlobal(Offset.zero);
    final textPosition = paragraph.getPositionForOffset(localInParagraph);
    final fullText = paragraph.text.toPlainText();
    final range = wordRangeAt(fullText, textPosition.offset);
    if (range.isCollapsed) return;

    final rawWord = fullText.substring(range.start, range.end);
    // Convert from the display script (if any) back to Roman for lookup.
    final cleaned = cleanPali(convertToRomanPali(rawWord));
    if (cleaned.length < 2) return;
    onTap(cleaned);
  }

  Widget _buildTranslationLine(
    String text,
    Color transColor,
    LanguageTypography? langTypo,
  ) {
    final effectiveFallback = transColor;
    final style = langTypo != null
        ? langTypo.toTextStyle(fallbackColor: effectiveFallback)
        : TextStyle(
            fontFamily: AppTypography.translationFont,
            fontSize: 17,
            fontWeight: FontWeight.w400,
            height: 28 / 17,
            color: effectiveFallback.withValues(alpha: 0.85),
          );

    // Check for nissaya-formatted text
    if (NissayaTextParser.isNissayaFormat(text)) {
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: NissayaText(text: text, baseStyle: style, plainStyle: style),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: HtmlTextParser.richText(text, style, maxLines: null),
    );
  }
}
