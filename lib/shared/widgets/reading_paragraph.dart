import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/settings_provider.dart';
import '../../core/theme/app_typography.dart';
import '../../features/reader/providers/reader_provider.dart';
import '../../core/utils/pali_search_utils.dart';
import '../../core/utils/pali_text_utils.dart';
import '../../core/utils/pali_script_converter.dart';

/// Display mode for translation in the reader.
enum ParagraphDisplayMode {
  hideJoinLines,
  lineByLine,
  sideBySide,
}

/// Displays a paragraph block with line-by-line Pāli and translations,
/// a vertical line flush with the left edge to group lines in the same paragraph,
/// page number badges at page starts, heading titles at section starts,
/// and optional search highlighting.
class ReadingParagraph extends ConsumerWidget {
  final ParagraphData paragraph;
  final bool isFirst;
  final String? bookName;
  final String? bookDescription;
  final bool showPali;
  final bool showTranslation;
  final ParagraphDisplayMode displayMode;
  final Color paliColor;
  final Color translationColor;
  final LanguageTypography paliTypography;
  final Map<String, LanguageTypography> langTypographies;
  final List<String> enabledLangCodes;
  final String? searchQuery;

  /// Line ID to highlight during TTS reading.
  final int? ttsHighlightLineId;

  /// Paragraph ID that the highlighted line belongs to. Must match this
  /// paragraph's own paraId, otherwise a repeated/non-unique lineId would
  /// incorrectly highlight the same line number in other paragraphs.
  final int? ttsHighlightParaId;

  /// Optional per-line GlobalKeys, keyed by lineId. When provided (only
  /// meaningful in [ParagraphDisplayMode.lineByLine], since the other
  /// modes join every line's text into one continuous block), the reader
  /// screen can use these to fine-scroll to a specific line inside this
  /// paragraph via `Scrollable.ensureVisible`, since
  /// ScrollablePositionedList can only address whole items (paragraphs),
  /// not individual lines within them.
  final Map<int, GlobalKey>? lineKeys;

  // Legacy params
  final double paliFontSize;
  final double paliLineHeight;
  final double translationFontSize;
  final double translationLineHeight;

  const ReadingParagraph({
    super.key,
    required this.paragraph,
    this.isFirst = false,
    this.bookName,
    this.bookDescription,
    this.showPali = true,
    this.showTranslation = true,
    this.displayMode = ParagraphDisplayMode.lineByLine,
    this.paliColor = const Color(0xFF7A2E1D),
    this.translationColor = const Color(0xFF33312E),
    this.paliTypography = const LanguageTypography(fontSize: 19),
    this.langTypographies = const {},
    this.enabledLangCodes = const [],
    this.searchQuery,
    this.ttsHighlightLineId,
    this.ttsHighlightParaId,
    this.lineKeys,
    this.paliFontSize = 19,
    this.paliLineHeight = 32 / 19,
    this.translationFontSize = 17,
    this.translationLineHeight = 28 / 17,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final script = ref.watch(settingsProvider).paliScript;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Book title at the very top
        if (isFirst) _buildBookTitle(colors, script),

        // Heading (if this paragraph starts a new section)
        if (paragraph.heading != null)
          _buildHeading(paragraph.heading!, colors, script),

        // Page number badge at page start
        if (paragraph.isPageStart && paragraph.pageNumber != null)
          _buildPageBadge(paragraph.pageNumber!, colors),

        // Content with vertical line flush to left
        _buildContentWithVerticalLine(colors, script),
      ],
    );
  }

  Widget _buildBookTitle(ColorScheme colors, Script script) {
    final convertedTitle = convertPaliToScript(bookName ?? '', script);
    final scriptFont = scriptFontFamily(script);
    return Padding(
      padding: const EdgeInsets.only(bottom: 32, left: 12),
      child: Column(
        children: [
          Text(
            convertedTitle,
            style: AppTypography.displayPali.copyWith(
              fontFamily: scriptFont,
              color: colors.primary,
            ),
            textAlign: TextAlign.center,
          ),
          if (bookDescription != null && bookDescription!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                bookDescription!,
                style: AppTypography.bodyTranslation.copyWith(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  /// Render a heading with style matching its level (h1=largest, h6=smallest).
  Widget _buildHeading(ParagraphHeading heading, ColorScheme colors, Script script) {
    final convertedTitle = convertPaliToScript(heading.title, script);
    final level = heading.level.clamp(1, 6);
    final fontSize = [22.0, 20.0, 18.0, 16.0, 15.0, 14.0][level - 1];
    final weight = level <= 2 ? FontWeight.w700 : FontWeight.w600;

    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8, left: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Small decorative line above the heading
          Container(
            width: 40,
            height: 3,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            convertedTitle,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: weight,
              fontFamily: scriptFontFamily(script),
              color: colors.primary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageBadge(String pageNumber, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Column(
        children: [
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.outlineVariant.withValues(alpha: 0.1),
                  colors.outlineVariant.withValues(alpha: 0.4),
                  colors.outlineVariant.withValues(alpha: 0.1),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  'p. $pageNumber',
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Vertical line at the very left, with content spaced minimally.
  Widget _buildContentWithVerticalLine(ColorScheme colors, Script script) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, top: 4, bottom: 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vertical line with 5px left padding
            SizedBox(
              width: 3,
              child: Container(
                margin: const EdgeInsets.only(top: 4, bottom: 4),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Lines content - takes all remaining space
            Expanded(
              child: displayMode == ParagraphDisplayMode.sideBySide
                  ? _buildSideBySide(colors, script)
                  : displayMode == ParagraphDisplayMode.hideJoinLines
                      ? _buildJoinedPali(colors, script)
                      : _buildLinesStacked(colors, script),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideBySide(ColorScheme colors, Script script) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildJoinedPali(colors, script),
            ),
          ),
          Container(
            width: 1,
            color: colors.outlineVariant.withValues(alpha: 0.4),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _buildAllTranslations(colors),
            ),
          ),
        ],
      ),
    );
  }

  /// Stacked layout: line by line with Pāli then translation below.
  Widget _buildLinesStacked(ColorScheme colors, Script script) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraph.lines.map((line) {
        final isHighlighted = ttsHighlightLineId != null &&
            ttsHighlightParaId != null &&
            paragraph.paraId == ttsHighlightParaId &&
            line.lineId == ttsHighlightLineId;

        return Padding(
          key: lineKeys?[line.lineId],
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pali line — never highlighted for TTS (Issue 4)
              if (showPali && line.paliText != null && line.paliText!.isNotEmpty)
                _buildPaliLine(line.paliText!, colors, script),
              // Translation lines — highlighted wrapper ONLY here
              if (displayMode == ParagraphDisplayMode.lineByLine &&
                  showTranslation)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? colors.primary.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding: EdgeInsets.only(
                    left: isHighlighted ? 4 : 0,
                    right: isHighlighted ? 4 : 0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildTranslationLines(line.translations, colors),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Join all Pāli lines in this paragraph into one continuous block.
  Widget _buildJoinedPali(ColorScheme colors, Script script) {
    if (!showPali) return const SizedBox.shrink();

    final text = paragraph.lines
        .map((l) => l.paliText)
        .where((t) => t != null && t.trim().isNotEmpty)
        .join(' ');

    if (text.isEmpty) return const SizedBox.shrink();

    return _buildPaliLine(text, colors, script);
  }

  Widget _buildAllTranslations(ColorScheme colors) {
    if (!showTranslation) return const SizedBox.shrink();

    final langs = enabledLangCodes.isNotEmpty ? enabledLangCodes : null;

    if (langs != null && langs.isNotEmpty) {
      final widgets = <Widget>[];
      for (final langCode in langs) {
        final texts = paragraph.lines
            .map((l) => l.translations[langCode])
            .where((t) => t != null && t.trim().isNotEmpty)
            .join(' ');

        if (texts.isEmpty) continue;

        final typo = langTypographies[langCode];
        widgets.add(_buildTranslationText(texts, typo, colors));
      }
      if (widgets.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets
            .expand((w) => [w, const SizedBox(height: 4)])
            .toList()
          ..removeLast(),
      );
    }

    return const SizedBox.shrink();
  }

  List<Widget> _buildTranslationLines(
    Map<String, String> lineTranslations,
    ColorScheme colors,
  ) {
    final langs = enabledLangCodes.isNotEmpty ? enabledLangCodes : null;
    if (langs == null || langs.isEmpty) return [];

    final widgets = <Widget>[];
    for (final langCode in langs) {
      final text = lineTranslations[langCode];
      if (text == null || text.trim().isEmpty) continue;
      final typo = langTypographies[langCode];
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(left: 8, top: 2),
          child: _buildTranslationText(text, typo, colors),
        ),
      );
    }
    return widgets;
  }

  Widget _buildPaliLine(String text, ColorScheme colors, Script script) {
    final convertedText = convertPaliToScript(text, script);
    final effectiveColor = paliTypography.effectiveColor(paliColor);
    final scriptFont = scriptFontFamily(script);
    final baseStyle = TextStyle(
      fontFamily: scriptFont,
      fontSize: paliTypography.fontSize,
      fontWeight: paliTypography.bold ? FontWeight.w700 : FontWeight.w400,
      fontStyle: paliTypography.italic ? FontStyle.italic : FontStyle.normal,
      decoration:
          paliTypography.underline ? TextDecoration.underline : TextDecoration.none,
      height: paliTypography.lineHeight,
      color: effectiveColor,
    );

    if (searchQuery != null && searchQuery!.isNotEmpty) {
      final convertedQuery = convertSearchQueryForScript(searchQuery!, script);
      return _buildHighlightedText(convertedText, convertedQuery, baseStyle, colors);
    }

    final spans = _parseHtml(convertedText, baseStyle);
    return Text.rich(TextSpan(style: baseStyle, children: spans));
  }

  /// Build translation text with HTML tag support and search highlighting.
  Widget _buildTranslationText(
    String text,
    LanguageTypography? typo,
    ColorScheme colors,
  ) {
    final effectiveFallback = translationColor;
    final style = typo != null
        ? typo.toTextStyle(fallbackColor: effectiveFallback)
        : TextStyle(
            fontFamily: AppTypography.translationFont,
            fontSize: translationFontSize,
            fontWeight: FontWeight.w400,
            height: translationLineHeight,
            color: effectiveFallback.withValues(alpha: 0.8),
          );

    if (searchQuery != null && searchQuery!.isNotEmpty) {
      return _buildHighlightedText(text, searchQuery!, style, colors);
    }

    // Parse HTML tags in translation text (supports <b>, <i>, <u>)
    final spans = _parseHtml(text, style);
    return Text.rich(TextSpan(style: style, children: spans));
  }

  Widget _buildHighlightedText(
    String text,
    String query,
    TextStyle baseStyle,
    ColorScheme colors,
  ) {
    if (query.isEmpty) {
      final spans = _parseHtml(text, baseStyle);
      return Text.rich(TextSpan(style: baseStyle, children: spans));
    }

    // First parse HTML, then apply highlighting on top
    final spans = _parseHtml(text, baseStyle);
    final result = <InlineSpan>[];
    for (final span in spans) {
      if (span is TextSpan && span.text != null) {
        final subSpans = _highlightInText(span.text!, query, span.style ?? baseStyle, colors);
        result.addAll(subSpans);
      } else {
        result.add(span);
      }
    }
    return Text.rich(TextSpan(style: baseStyle, children: result));
  }

  /// Split a plain text and highlight occurrences of [query].
  List<InlineSpan> _highlightInText(
    String text,
    String query,
    TextStyle baseStyle,
    ColorScheme colors,
  ) {
    if (query.isEmpty) return [TextSpan(text: text, style: baseStyle)];

    final normalizedText = normalizePaliFuzzy(text).toLowerCase();
    
    // Get normalized terms
    final terms = normalizePaliFuzzy(query)
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    if (terms.isEmpty) return [TextSpan(text: text, style: baseStyle)];

    // Find all match intervals: [start, end] (exclusive end)
    final intervals = <_HighlightInterval>[];
    for (final term in terms) {
      int pos = 0;
      while (true) {
        final idx = normalizedText.indexOf(term, pos);
        if (idx == -1) break;
        intervals.add(_HighlightInterval(idx, idx + term.length));
        pos = idx + 1; // Slide forward to find other matches
      }
    }

    if (intervals.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    // Sort intervals by start, then by end descending
    intervals.sort((a, b) {
      final cmp = a.start.compareTo(b.start);
      if (cmp != 0) return cmp;
      return b.end.compareTo(a.end);
    });

    // Merge overlapping or adjacent intervals
    final merged = <_HighlightInterval>[];
    var current = intervals.first;
    for (int i = 1; i < intervals.length; i++) {
      final next = intervals[i];
      if (next.start <= current.end) {
        // Overlap or touch
        if (next.end > current.end) {
          current = _HighlightInterval(current.start, next.end);
        }
      } else {
        merged.add(current);
        current = next;
      }
    }
    merged.add(current);

    // Build spans using merged intervals
    final spans = <InlineSpan>[];
    int lastIdx = 0;
    for (final interval in merged) {
      if (interval.start > lastIdx) {
        spans.add(TextSpan(
          text: text.substring(lastIdx, interval.start),
          style: baseStyle,
        ));
      }
      spans.add(TextSpan(
        text: text.substring(interval.start, interval.end),
        style: baseStyle.copyWith(
          backgroundColor: colors.primary.withValues(alpha: 0.2),
          fontWeight: FontWeight.w700,
        ),
      ));
      lastIdx = interval.end;
    }

    if (lastIdx < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIdx),
        style: baseStyle,
      ));
    }

    return spans;
  }

  /// Parse HTML tags into [InlineSpan]s.
  /// Supports: `<b>`, `<i>`, `<u>`, `<h1-6>`, `<br>`
  List<InlineSpan> _parseHtml(String html, TextStyle base) {
    if (!html.contains('<')) return [TextSpan(text: html)];

    final spans = <InlineSpan>[];
    final boldStyle = base.copyWith(fontWeight: FontWeight.w700);
    final italicStyle = base.copyWith(fontStyle: FontStyle.italic);
    final underlineStyle = base.copyWith(decoration: TextDecoration.underline);

    final normalized = html.replaceAll('<br>', '\n').replaceAll('<br/>', '\n');
    final pattern = RegExp(
      r'<b>(.*?)</b>|<i>(.*?)</i>|<u>(.*?)</u>|'
      r'<h[1-6][^>]*>(.*?)</h[1-6]>|'
      r'([^<]+)',
      dotAll: true,
      caseSensitive: false,
    );

    for (final m in pattern.allMatches(normalized)) {
      if (m.group(1) != null) {
        spans.add(TextSpan(text: m.group(1), style: boldStyle));
      } else if (m.group(2) != null) {
        spans.add(TextSpan(text: m.group(2), style: italicStyle));
      } else if (m.group(3) != null) {
        spans.add(TextSpan(text: m.group(3), style: underlineStyle));
      } else if (m.group(4) != null) {
        spans.add(TextSpan(text: m.group(4), style: boldStyle));
      } else if (m.group(5) != null) {
        final text = m.group(5)!;
        if (text.trim().isNotEmpty || text == '\n') {
          spans.add(TextSpan(text: text));
        }
      }
    }

    return spans;
  }
}

class _HighlightInterval {
  final int start;
  final int end;
  const _HighlightInterval(this.start, this.end);
}

/// Helper: extract all words (without tags) from an HTML string.
List<String> extractWords(String? htmlText) {
  if (htmlText == null || htmlText.isEmpty) return [];
  final clean = htmlText
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(
        RegExp(r'[^\wāīūōṅñṭḍṇḷṃĀĪŪŌṄÑṬḌṆḶṀ\s]'),
        ' ',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (clean.isEmpty) return [];
  return clean.split(' ');
}
