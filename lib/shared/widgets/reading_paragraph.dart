import 'dart:collection';

import 'package:flutter/material.dart';

import '../../core/providers/settings_provider.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/app_localizations.dart';
import '../../features/reader/providers/reader_provider.dart';
import '../../core/utils/pali_search_utils.dart';
import '../../core/utils/pali_text_utils.dart';
import '../../core/utils/pali_script_converter.dart';
import '../../features/reader/data/book_link_data.dart';
import '../../features/reader/widgets/book_link_chip.dart';
import '../../features/reader/widgets/book_link_section_sheet.dart';
import '../../shared/widgets/pali_text.dart';
import '../../shared/widgets/nissaya_text.dart';

/// Display mode for translation in the reader.
enum ParagraphDisplayMode { hideJoinLines, lineByLine, sideBySide }

/// Displays a paragraph block with line-by-line Pāli and translations,
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

  /// Optional per-line GlobalKeys, keyed by lineId. When provided (only
  /// meaningful in [ParagraphDisplayMode.lineByLine], since the other
  /// modes join every line's text into one continuous block), the reader
  /// screen can use these to fine-scroll to a specific line inside this
  /// paragraph via `Scrollable.ensureVisible`, since
  /// ScrollablePositionedList can only address whole items (paragraphs),
  /// not individual lines within them.
  final Map<int, GlobalKey>? lineKeys;

  /// Book links for this paragraph, keyed by lineId.
  /// When non-empty, chips are rendered below the linked lines.
  final ParaBookLinks bookLinks;

  /// Whether inlined book-link chips (commentary links) are rendered.
  /// When false, linked words are shown as plain text with no chips.
  final bool showBookLinks;

  /// Per-language version badge labels (e.g. "EN", "MY-N", "TH-V2").
  /// When non-empty, small chips are shown next to each translation block.
  final Map<String, String> translationVersionLabels;

  /// Pāli script conversion target. Extracted from settings by the parent
  /// widget so this paragraph does not need to watch [settingsProvider].
  final Script script;

  /// Page numbering system label ("VRI", "PTS", "Thai", "Myanmar").
  /// Extracted from settings by the parent so this paragraph does not
  /// need to watch [settingsProvider].
  final String pageNumberingSystem;

  /// The page number (in the selected system) of the previous paragraph's
  /// LAST line, used to seed the per-line page tracking so a page break on
  /// the very first line of this paragraph is detected correctly even
  /// though the paragraph doesn't know what came before it.
  final String? previousLinePageNumber;

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
    this.bookLinks = const {},
    this.showBookLinks = true,
    this.translationVersionLabels = const {},
    this.searchQuery,
    this.ttsHighlightLineId,
    this.ttsHighlightParaId,
    this.lineKeys,
    required this.script,
    required this.pageNumberingSystem,
    this.previousLinePageNumber,
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

        // Page break marker at paragraph page start. In lineByLine mode the
        // marker is rendered at the exact line where the page begins (see
        // _buildLinesStacked), which is more accurate than this paragraph-level
        // marker when a page break falls mid-paragraph. The joined/side-by-side
        // modes have no per-line anchors, so they keep this paragraph-level
        // marker.
        if (displayMode != ParagraphDisplayMode.lineByLine &&
            paragraph.isPageStart &&
            paragraph.pageNumber != null)
          _buildPageBreakMarker(paragraph.pageNumber!, colors),

        // Content with vertical line flush to left
        _buildContentWithVerticalLine(context, colors),
      ],
    );
  }

  Widget _buildBookTitle(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32, left: 12),
      child: Column(
        children: [
          PaliTextStatic(
            bookName ?? '',
            script,
            style: AppTypography.displayPali.copyWith(color: colors.primary),
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
          Container(
            width: 40,
            height: 3,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          PaliTextStatic(
            heading.title,
            script,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: weight,
              color: colors.primary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  /// Page break marker styled like a printed book / PDF page break: a thin
  /// horizontal divider with a page number chip at the right end. Shown at
  /// every page start, including page breaks that fall in the middle of a
  /// paragraph (lineByLine mode). The chip shows the page numbering system
  /// label (e.g. "VRI") alongside the page number; the volume prefix is
  /// stripped from the raw page number ("1.17" renders as "17").
  Widget _buildPageBreakMarker(String pageNumber, ColorScheme colors) {
    final systemLabel = _pageSystemLabel(pageNumberingSystem);
    return SelectionContainer.disabled(
      child: Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      colors.outlineVariant.withValues(alpha: 0.05),
                      colors.outlineVariant.withValues(alpha: 0.25),
                      colors.outlineVariant.withValues(alpha: 0.45),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.8),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$systemLabel ',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                        color: colors.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                    ),
                    TextSpan(
                      text: _displayPageNumber(pageNumber),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentWithVerticalLine(
    BuildContext context,
    ColorScheme colors,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: colors.primary.withValues(alpha: 0.25),
              width: 3,
            ),
          ),
        ),
        padding: const EdgeInsets.only(left: 3, top: 4, bottom: 4),
        child: _buildContentBlock(context, colors),
      ),
    );
  }

  Widget _buildContentBlock(BuildContext context, ColorScheme colors) {
    switch (displayMode) {
      case ParagraphDisplayMode.sideBySide:
        return _buildSideBySide(colors);
      case ParagraphDisplayMode.hideJoinLines:
        return _buildJoinedPali(colors);
      case ParagraphDisplayMode.lineByLine:
        return _buildLinesStacked(context, colors);
    }
  }

  Widget _buildSideBySide(ColorScheme colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildJoinedPali(colors),
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
    );
  }

  Widget _buildLinesStacked(BuildContext context, ColorScheme colors) {
    final para = paragraph;
    // Track the current page (selected system) across lines so a page break
    // marker can be drawn at the exact line where the page begins. Seeded from
    // the previous paragraph's last line to catch page breaks that fall on a
    // paragraph's first line.
    String? runningPage = previousLinePageNumber;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: para.lines.map((line) {
        final lineId = line.lineId;
        final linePage = line.pageNumbers[pageNumberingSystem];
        final startsNewPage = linePage != null && linePage != runningPage;
        if (linePage != null) runningPage = linePage;

        final isHighlighted =
            ttsHighlightLineId != null &&
            ttsHighlightParaId != null &&
            paragraph.paraId == ttsHighlightParaId &&
            lineId == ttsHighlightLineId;

        final lineLinks = bookLinks[lineId];

        final hasPali =
            showPali && line.paliText != null && line.paliText!.isNotEmpty;

        return Padding(
          key: lineKeys?[lineId],
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page break marker at the exact line where a new page begins —
              // a divider with the page number on the right, like a printed
              // book (PDF page break). Drawn even when this line carries no
              // Pāli text, so a mid-paragraph break is always visible.
              if (startsNewPage) _buildPageBreakMarker(linePage, colors),
              // Build the Pāli line lazily (only when it exists) so a line
              // carrying page data but no Pāli text can't crash.
              if (hasPali) _buildPaliLine(line.paliText!, colors),
              if (displayMode == ParagraphDisplayMode.lineByLine &&
                  showTranslation)
                _buildTranslationBlock(
                  line.translations,
                  colors,
                  isHighlighted,
                ),
              if (showBookLinks && lineLinks != null && lineLinks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: _buildChips(lineLinks, colors, context),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChips(
    List<BookLinkData> links,
    ColorScheme colors,
    BuildContext context,
  ) {
    if (links.length <= 6) {
      return Wrap(
        spacing: 4,
        runSpacing: 2,
        children: links.map((link) {
          final chipColor = link.isSource ? colors.primary : colors.tertiary;
          return BookLinkChip(
            word: link.word,
            color: chipColor,
            script: script,
            onTap: () => showBookLinkSectionSheet(context, link: link),
          );
        }).toList(),
      );
    }

    return _ExpandableChips(
      links: links,
      colors: colors,
      script: script,
      onChipTap: (link) => showBookLinkSectionSheet(context, link: link),
    );
  }

  /// Translation lines with optional TTS highlight.
  Widget _buildTranslationBlock(
    Map<String, String> translations,
    ColorScheme colors,
    bool isHighlighted,
  ) {
    final langs = enabledLangCodes.isNotEmpty ? enabledLangCodes : null;
    if (langs == null || langs.isEmpty) return const SizedBox.shrink();

    final children = <Widget>[];
    for (final langCode in langs) {
      final text = translations[langCode];
      if (text == null || text.trim().isEmpty) continue;
      final typo = langTypographies[langCode];
      children.add(_buildTranslationLine(langCode, text, typo, colors));
    }
    if (children.isEmpty) return const SizedBox.shrink();

    if (!isHighlighted) {
      // Fast path: no highlight container.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    }

    // Highlighted path: wrap in tinted container.
    return Container(
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildTranslationLine(
    String langCode,
    String text,
    LanguageTypography? typo,
    ColorScheme colors,
  ) {
    final versionLabel = translationVersionLabels[langCode];

    final style = typo != null
        ? typo.toTextStyle(fallbackColor: translationColor)
        : TextStyle(
            fontFamily: AppTypography.translationFont,
            fontSize: translationFontSize,
            fontWeight: FontWeight.w400,
            height: translationLineHeight,
            color: translationColor.withValues(alpha: 0.8),
          );

    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (versionLabel != null && versionLabel.isNotEmpty) ...[
            _buildVersionBadge(versionLabel, colors),
            const SizedBox(width: 6),
          ],
          Expanded(child: _buildTranslationText(text, style, colors)),
        ],
      ),
    );
  }

  Widget _buildVersionBadge(String label, ColorScheme colors) {
    final isNissaya = label.contains('-N');
    final badgeColor = isNissaya ? Colors.teal : colors.primary;

    return Container(
      margin: const EdgeInsets.only(top: 1),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: badgeColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildJoinedPali(ColorScheme colors) {
    if (!showPali) return const SizedBox.shrink();

    final text = paragraph.lines
        .map((l) => l.paliText)
        .where((t) => t != null && t.trim().isNotEmpty)
        .join(' ');

    if (text.isEmpty) return const SizedBox.shrink();

    return _buildPaliLine(text, colors);
  }

  Widget _buildAllTranslations(ColorScheme colors) {
    if (!showTranslation) return const SizedBox.shrink();

    final langs = enabledLangCodes.isNotEmpty ? enabledLangCodes : null;

    if (langs == null || langs.isEmpty) return const SizedBox.shrink();

    final widgets = <Widget>[];
    for (final langCode in langs) {
      final texts = paragraph.lines
          .map((l) => l.translations[langCode])
          .where((t) => t != null && t.trim().isNotEmpty)
          .join(' ');

      if (texts.isEmpty) continue;

      final typo = langTypographies[langCode];
      widgets.add(_buildTranslationLine(langCode, texts, typo, colors));
    }
    if (widgets.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets.expand((w) => [w, const SizedBox(height: 4)]).toList()
        ..removeLast(),
    );
  }

  Widget _buildPaliLine(String text, ColorScheme colors) {
    final paliTypography = this.paliTypography;
    final effectiveColor = paliTypography.effectiveColor(paliColor);
    final baseStyle = TextStyle(
      fontSize: paliTypography.fontSize,
      fontWeight: paliTypography.bold ? FontWeight.w700 : FontWeight.w400,
      fontStyle: paliTypography.italic ? FontStyle.italic : FontStyle.normal,
      decoration: paliTypography.underline
          ? TextDecoration.underline
          : TextDecoration.none,
      height: paliTypography.lineHeight,
      color: effectiveColor,
    );

    final query = searchQuery;

    if (query != null && query.isNotEmpty) {
      final convertedText = convertPaliToScriptPreservingHtml(text, script);
      final convertedQuery = convertSearchQueryForScript(query, script);
      // The non-search path renders through [PaliTextWithVariants], which
      // applies the script-specific font. The highlight path builds spans
      // directly from [baseStyle], so the script font must be applied here
      // too — otherwise scripts with a dedicated bundled font (Lao,
      // Myanmar, Sinhala, …) fall back to the platform default and render
      // incorrectly (e.g. missing the Pali-specific Lao characters).
      final scriptStyle =
          baseStyle.copyWith(fontFamily: scriptFontFamily(script));
      return _buildHighlightedText(
        convertedText,
        convertedQuery,
        scriptStyle,
        colors,
      );
    }

    return PaliTextWithVariants(
      text,
      script: script,
      colors: colors,
      style: baseStyle,
    );
  }

  Widget _buildTranslationText(
    String text,
    TextStyle style,
    ColorScheme colors,
  ) {
    if (NissayaTextParser.isNissayaFormat(text)) {
      return NissayaText(text: text, baseStyle: style, plainStyle: style);
    }

    final query = searchQuery;
    if (query != null && query.isNotEmpty) {
      return _buildHighlightedText(text, query, style, colors);
    }

    final spans = _parseHtml(text);
    return Text.rich(TextSpan(style: style, children: spans));
  }

  Widget _buildHighlightedText(
    String text,
    String query,
    TextStyle baseStyle,
    ColorScheme colors,
  ) {
    if (query.isEmpty) {
      final spans = _parseHtml(text);
      return Text.rich(TextSpan(style: baseStyle, children: spans));
    }

    final spans = _parseHtml(text);
    final result = <InlineSpan>[];
    for (final span in spans) {
      if (span is TextSpan) {
        final text = span.text;
        if (text == null) {
          result.add(span);
          continue;
        }
        final subSpans = _highlightInText(
          text,
          query,
          span.style ?? baseStyle,
          colors,
        );
        result.addAll(subSpans);
      } else {
        result.add(span);
      }
    }
    return Text.rich(TextSpan(style: baseStyle, children: result));
  }

  List<_HighlightInterval> _findTermIntervals(String text, List<String> terms) {
    final intervals = <_HighlightInterval>[];
    if (terms.isEmpty) return intervals;

    final lowerText = text.toLowerCase();
    final textLen = lowerText.length;

    for (final term in terms) {
      if (term.isEmpty) continue;
      final termLen = term.length;
      final maxStart = textLen - termLen;
      if (maxStart < 0) continue;

      int pos = 0;
      while (pos <= maxStart) {
        bool match = true;
        for (int i = 0; i < termLen; i++) {
          if (_normChar(lowerText.codeUnitAt(pos + i)) != term.codeUnitAt(i)) {
            match = false;
            break;
          }
        }
        if (match) {
          intervals.add(_HighlightInterval(pos, pos + termLen));
          pos += termLen;
        } else {
          pos++;
        }
      }
    }
    return intervals;
  }

  static int _normChar(int c) {
    switch (c) {
      case 0x0101:
        return 0x61;
      case 0x012B:
        return 0x69;
      case 0x016B:
        return 0x75;
      case 0x014D:
        return 0x6F;
      case 0x1E45:
        return 0x6E;
      case 0x00F1:
        return 0x6E;
      case 0x1E6D:
        return 0x74;
      case 0x1E0D:
        return 0x64;
      case 0x1E47:
        return 0x6E;
      case 0x1E37:
        return 0x6C;
      case 0x1E3B:
        return 0x6C;
      case 0x1E43:
        return 0x6D;
      case 0x1E41:
        return 0x6D;
      case 0x1E25:
        return 0x68;
      default:
        return c;
    }
  }

  List<InlineSpan> _highlightInText(
    String text,
    String query,
    TextStyle baseStyle,
    ColorScheme colors,
  ) {
    if (query.isEmpty) return [TextSpan(text: text, style: baseStyle)];

    final terms = normalizePaliFuzzy(
      query,
    ).toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (terms.isEmpty) return [TextSpan(text: text, style: baseStyle)];

    final intervals = _findTermIntervals(text, terms);
    if (intervals.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    intervals.sort((a, b) {
      final cmp = a.start.compareTo(b.start);
      if (cmp != 0) return cmp;
      return b.end.compareTo(a.end);
    });

    final merged = <_HighlightInterval>[];
    var current = intervals.first;
    for (int i = 1; i < intervals.length; i++) {
      final next = intervals[i];
      if (next.start <= current.end) {
        if (next.end > current.end) {
          current = _HighlightInterval(current.start, next.end);
        }
      } else {
        merged.add(current);
        current = next;
      }
    }
    merged.add(current);

    final spans = <InlineSpan>[];
    int lastIdx = 0;
    for (final interval in merged) {
      if (interval.start > lastIdx) {
        spans.add(
          TextSpan(
            text: text.substring(lastIdx, interval.start),
            style: baseStyle,
          ),
        );
      }
      spans.add(
        TextSpan(
          text: text.substring(interval.start, interval.end),
          style: baseStyle.copyWith(
            backgroundColor: colors.primary.withValues(alpha: 0.2),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      lastIdx = interval.end;
    }

    if (lastIdx < text.length) {
      spans.add(TextSpan(text: text.substring(lastIdx), style: baseStyle));
    }

    return spans;
  }

  /// Parse HTML tags into [InlineSpan]s.
  /// Supports: `<b>`, `<i>`, `<u>`, `<h1-6>`, `<br>`
  ///
  /// The produced spans carry only the markup indicator (bold/italic/…);
  /// every other style property inherits from the root [TextSpan] at paint
  /// time, so the per-HTML cache stays correct across callers with
  /// different base styles (Pāli lines, translations, …).
  ///
  /// Caches results per input HTML string to avoid redundant regex work
  /// when the same text appears on multiple rebuilds.
  static final LinkedHashMap<String, List<InlineSpan>> _htmlParseCache =
      LinkedHashMap<String, List<InlineSpan>>();
  static const int _htmlParseCacheLimit = 3000;

  List<InlineSpan> _parseHtml(String html) {
    if (!html.contains('<')) return [TextSpan(text: html)];

    final cached = _htmlParseCache[html];
    if (cached != null) return cached;

    final spans = <InlineSpan>[];
    // Marker-only styles: spans are cached by HTML string and shared across
    // callers with different base styles (Pāli lines with script fonts,
    // translations, …), so only the markup property is baked in here. Font
    // family, size, color, etc. inherit from the root TextSpan style when
    // the paragraph is painted, keeping the cache correct for every base.
    final boldStyle = TextStyle(fontWeight: FontWeight.w700);
    final italicStyle = TextStyle(fontStyle: FontStyle.italic);
    final underlineStyle = TextStyle(decoration: TextDecoration.underline);

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

    if (_htmlParseCache.length >= _htmlParseCacheLimit) {
      _htmlParseCache.remove(_htmlParseCache.keys.first);
    }
    _htmlParseCache[html] = spans;
    return spans;
  }
}

/// Display form of a raw page number: strips the leading "volume." prefix so
/// "1.17" renders as "17", like the folio of a printed book. Values without a
/// dot are returned unchanged.
String _displayPageNumber(String pageNumber) {
  final dot = pageNumber.indexOf('.');
  if (dot > 0 && dot < pageNumber.length - 1) {
    return pageNumber.substring(dot + 1);
  }
  return pageNumber;
}

/// Short label for a page numbering system code ('vri' → 'VRI', …).
String _pageSystemLabel(String code) {
  switch (code) {
    case 'vri':
      return 'VRI';
    case 'pts':
      return 'PTS';
    case 'thai':
      return 'Thai';
    case 'my':
      return 'Myanmar';
    default:
      return 'VRI';
  }
}

class _HighlightInterval {
  final int start;
  final int end;
  const _HighlightInterval(this.start, this.end);
}

/// A small expandable row of book link chips.
///
/// Shows at most 6 chips initially, with an expand button to reveal all.
class _ExpandableChips extends StatefulWidget {
  final List<BookLinkData> links;
  final ColorScheme colors;
  final Script? script;
  final void Function(BookLinkData link) onChipTap;

  const _ExpandableChips({
    required this.links,
    required this.colors,
    this.script,
    required this.onChipTap,
  });

  @override
  State<_ExpandableChips> createState() => _ExpandableChipsState();
}

class _ExpandableChipsState extends State<_ExpandableChips> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    const int maxVisible = 6;
    final links = widget.links;
    final displayLinks = _expanded ? links : links.take(maxVisible).toList();

    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: [
        ...displayLinks.map(_buildChip),
        if (!_expanded) _buildExpandButton(),
        if (_expanded) _buildCollapseButton(),
      ],
    );
  }

  Widget _buildChip(BookLinkData link) {
    final chipColor = link.isSource
        ? widget.colors.primary
        : widget.colors.tertiary;
    return BookLinkChip(
      word: link.word,
      color: chipColor,
      script: widget.script,
      onTap: () => widget.onChipTap(link),
    );
  }

  Widget _buildExpandButton() {
    final remaining = widget.links.length - 6;
    return _buildToggleChip(
      icon: Icons.expand_more,
      label: '+$remaining',
      onTap: () => setState(() => _expanded = true),
    );
  }

  Widget _buildCollapseButton() {
    return _buildToggleChip(
      icon: Icons.expand_less,
      label: AppLocalizations.of(context).lessLabel,
      onTap: () => setState(() => _expanded = false),
    );
  }

  Widget _buildToggleChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final colors = widget.colors;
    return Padding(
      padding: const EdgeInsets.only(right: 4, bottom: 2),
      child: SelectionContainer.disabled(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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

/// Helper: extract all words (without tags) from an HTML string.
List<String> extractWords(String? htmlText) {
  if (htmlText == null || htmlText.isEmpty) return [];
  final clean = htmlText
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(RegExp(r'[^\wāīūōṅñṭḍṇḷṃĀĪŪŌṄÑṬḌṆḶṀ\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (clean.isEmpty) return [];
  return clean.split(' ');
}
