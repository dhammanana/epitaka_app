import 'package:flutter/material.dart';

import '../../core/providers/settings_provider.dart';
import '../../core/theme/app_typography.dart';
import '../../features/reader/providers/reader_provider.dart';

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
class ReadingParagraph extends StatelessWidget {
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
    this.paliFontSize = 19,
    this.paliLineHeight = 32 / 19,
    this.translationFontSize = 17,
    this.translationLineHeight = 28 / 17,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Book title at the very top
        if (isFirst) _buildBookTitle(colors),

        // Heading (if this paragraph starts a new section)
        if (paragraph.heading != null)
          _buildHeading(paragraph.heading!, colors),

        // Page number badge at page start
        if (paragraph.isPageStart && paragraph.pageNumber != null)
          _buildPageBadge(paragraph.pageNumber!, colors),

        // Content with vertical line flush to left
        _buildContentWithVerticalLine(colors),
      ],
    );
  }

  Widget _buildBookTitle(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32, left: 12),
      child: Column(
        children: [
          Text(
            bookName ?? '',
            style: AppTypography.displayPali.copyWith(
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
  Widget _buildHeading(ParagraphHeading heading, ColorScheme colors) {
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
            heading.title,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: weight,
              fontFamily: paliTypography.fontFamily.fontFamily,
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
  Widget _buildContentWithVerticalLine(ColorScheme colors) {
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
                  ? _buildSideBySide(colors)
                  : _buildLinesStacked(colors),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideBySide(ColorScheme colors) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: showPali
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: paragraph.lines
                        .where((l) => l.paliText != null && l.paliText!.isNotEmpty)
                        .map((l) => Padding(
                              padding: const EdgeInsets.only(right: 8, bottom: 6),
                              child: _buildPaliLine(l.paliText!, colors),
                            ))
                        .toList(),
                  )
                : const SizedBox.shrink(),
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
  /// Issue 4 fix: highlight only the translation text row, not the whole block.
  Widget _buildLinesStacked(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraph.lines.map((line) {
        final isHighlighted = ttsHighlightLineId != null &&
            ttsHighlightParaId != null &&
            paragraph.paraId == ttsHighlightParaId &&
            line.lineId == ttsHighlightLineId;

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pali line — never highlighted for TTS (Issue 4)
              if (showPali && line.paliText != null && line.paliText!.isNotEmpty)
                _buildPaliLine(line.paliText!, colors),
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

  Widget _buildPaliLine(String text, ColorScheme colors) {
    final effectiveColor = paliTypography.effectiveColor(paliColor);
    final baseStyle = TextStyle(
      fontFamily: paliTypography.fontFamily.fontFamily,
      fontSize: paliTypography.fontSize,
      fontWeight: paliTypography.bold ? FontWeight.w700 : FontWeight.w400,
      fontStyle: paliTypography.italic ? FontStyle.italic : FontStyle.normal,
      decoration:
          paliTypography.underline ? TextDecoration.underline : TextDecoration.none,
      height: paliTypography.lineHeight,
      color: effectiveColor,
    );

    if (searchQuery != null && searchQuery!.isNotEmpty) {
      return _buildHighlightedText(text, searchQuery!, baseStyle, colors);
    }

    final spans = _parseHtml(text, baseStyle);
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

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <InlineSpan>[];
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: baseStyle));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: baseStyle.copyWith(
          backgroundColor: colors.primary.withValues(alpha: 0.2),
          fontWeight: FontWeight.w700,
        ),
      ));
      start = index + query.length;
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