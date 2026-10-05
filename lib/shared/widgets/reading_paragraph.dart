import 'dart:collection';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../../core/providers/settings_provider.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/app_localizations.dart';
import '../../features/reader/providers/reader_lookup_highlight_provider.dart';
import '../../features/reader/providers/reader_provider.dart';
import '../../features/reader/providers/tts_speak_unit.dart'
    show
        buildTtsWordIndexSpans,
        kTtsWordHighlightEnabled,
        ttsActiveLineDecoration;
import '../../features/reader/utils/reader_word_hit_test.dart'
    show ReaderLineMetadata;
import '../../core/utils/pali_search_utils.dart';
import '../../core/utils/pali_text_utils.dart';
import '../../core/utils/pali_script_converter.dart';
import '../../features/annotations/models/annotation.dart';
import '../../features/annotations/services/highlight_interval_resolver.dart';
import '../../features/annotations/services/highlight_span_painter.dart';
import '../../features/reader/data/book_link_data.dart';
import '../../features/reader/widgets/book_link_chip.dart';
import '../../features/reader/widgets/book_link_section_sheet.dart';
import '../../features/reader/widgets/section_copy_menu.dart';
import '../../features/reader/widgets/translation_remark_dialog.dart';
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

  /// Book id of the paragraph (used by the remark editor to save edits).
  final String? bookId;
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

  /// True when the TTS item being spoken is Pali, false for translation.
  /// Null highlights the translation (legacy behavior).
  final bool? ttsHighlightIsPali;

  // WORD-HIGHLIGHT: spoken word for [ttsHighlightLineId] — 0-based index
  // into the line's words plus the line's speak substring (translation:
  // rendered as-is; Pāli: converted to the display script so the line never
  // changes script mid-speech). Ignored unless [kTtsWordHighlightEnabled].
  final int? ttsHighlightWordIndex;
  final String? ttsHighlightWordLineText;

  /// Line ID to highlight after a jump (TOC, search, dictionary, etc.).
  /// The highlight fades out after a few seconds.
  final int? jumpHighlightLineId;

  /// Paragraph ID that [jumpHighlightLineId] belongs to.
  final int? jumpHighlightParaId;

  /// Optional per-line GlobalKeys, keyed by lineId. When provided (only
  /// meaningful in [ParagraphDisplayMode.lineByLine], since the other
  /// modes join every line's text into one continuous block), the reader
  /// screen can use these to fine-scroll to a specific line inside this
  /// paragraph via `Scrollable.ensureVisible`, since
  /// ScrollablePositionedList can only address whole items (paragraphs),
  /// not individual lines within them.
  final Map<int, GlobalKey>? lineKeys;

  /// Keyboard-navigation focus line: when this paragraph holds the focused
  /// line (keyboard reading cursor), that line gets a subtle highlight.
  final int? keyboardFocusParaId;
  final int? keyboardFocusLineId;

  /// Which book-link chip on the focused line is selected by the keyboard
  /// (0-based), or null when none. Only meaningful on the focus line.
  final int? keyboardFocusChipIndex;

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

  /// User annotations (highlights / notes) for THIS paragraph. Filtered by
  /// the widget per line + segment before painting.
  final List<Annotation> annotations;

  /// Active dictionary lookup highlight (for highlighting the tapped word).
  final ReaderLookupHighlight? lookupHighlight;

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
  final TextAlignOption textAlign;
  final int lineHeight; // Additional pixels for line height
  final int paragraphSpacing; // Extra space between paragraphs in pixels

  /// Converts [TextAlignOption] to Flutter's [TextAlign].
  TextAlign get _textAlign => switch (textAlign) {
    TextAlignOption.start => TextAlign.start,
    TextAlignOption.center => TextAlign.center,
    TextAlignOption.end => TextAlign.end,
    TextAlignOption.justify => TextAlign.justify,
  };

  /// Returns the effective line height for Pali text.
  double get _paliLineHeight => paliLineHeight + (lineHeight / paliFontSize);

  /// Returns the effective line height for translation text.
  double _translationLineHeight(LanguageTypography? typo) {
    final baseHeight = typo?.lineHeight ?? translationLineHeight;
    return baseHeight + (lineHeight / (typo?.fontSize ?? translationFontSize));
  }

  /// Returns the paragraph spacing to apply between paragraphs.
  double get _paragraphSpacing => paragraphSpacing.toDouble();

  const ReadingParagraph({
    super.key,
    required this.paragraph,
    this.isFirst = false,
    this.bookName,
    this.bookDescription,
    this.bookId,
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
    this.lookupHighlight,
    this.ttsHighlightLineId,
    this.ttsHighlightParaId,
    this.ttsHighlightIsPali,
    this.ttsHighlightWordIndex,
    this.ttsHighlightWordLineText,
    this.jumpHighlightLineId,
    this.jumpHighlightParaId,
    this.lineKeys,
    this.keyboardFocusParaId,
    this.keyboardFocusLineId,
    this.keyboardFocusChipIndex,
    required this.script,
    required this.pageNumberingSystem,
    this.previousLinePageNumber,
    this.paliFontSize = 19,
    this.paliLineHeight = 32 / 19,
    this.translationFontSize = 17,
    this.translationLineHeight = 28 / 17,
    this.textAlign = TextAlignOption.justify,
    this.lineHeight = 0,
    this.paragraphSpacing = 8,
    this.annotations = const [],
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (annotations.isNotEmpty) {
      developer.log(
        '[RENDER] para=${paragraph.paraId} received ${annotations.length} '
        'annotations types=[${annotations.map((a) => a.type.wire).join(',')}]',
        name: 'epitaka.annotations',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Book title at the very top
        if (isFirst) _buildBookTitle(context, colors),

        // Heading (if this paragraph starts a new section)
        if (paragraph.heading != null)
          _buildHeading(context, paragraph.heading!, colors),

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

        // Content with vertical line flush to left for line-by-line and
        // joined modes when both Pali and translation are shown;
        // side-by-side has its own left inset inside _buildSideBySide, and
        // single-language views (Pali-only / translation-only) render
        // without the line but with the same 12px text offset so they are
        // not flush to the screen edge on mobile.
        if (displayMode == ParagraphDisplayMode.sideBySide)
          _buildContentBlock(context, colors)
        else if (!showPali || !showTranslation)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
            child: _buildContentBlock(context, colors),
          )
        else
          _buildContentWithVerticalLine(context, colors),

        // Paragraph spacing
        if (_paragraphSpacing > 0)
          SizedBox(height: _paragraphSpacing),
      ],
    );
  }

  Widget _buildBookTitle(BuildContext context, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32, left: 12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: PaliTextStatic(
                  bookName ?? '',
                  script,
                  fontChoice: paliTypography.fontFamily,
                  style: AppTypography.displayPali.copyWith(
                    color: colors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (bookId != null && bookId!.isNotEmpty)
                BookCopyMenuButton(bookId: bookId!),
            ],
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
  Widget _buildHeading(
    BuildContext context,
    ParagraphHeading heading,
    ColorScheme colors,
  ) {
    final level = heading.level.clamp(1, 6);
    // Relative to the Pāli body size so headings grow/shrink with the
    // user's Pāli font setting. Scale factors preserve the previous
    // absolute sizes (22/20/18/16/15/14) at the default 19pt Pāli size.
    const scale = [22 / 19, 20 / 19, 18 / 19, 16 / 19, 15 / 19, 14 / 19];
    final fontSize = paliTypography.fontSize * scale[level - 1];
    final weight = level <= 2 ? FontWeight.w700 : FontWeight.w600;

    final baseStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: weight,
      color: colors.primary,
      height: 1.3,
    );
    final fontStyle = baseStyle.copyWith(
      fontFamily: paliReadingFontFamily(script, paliTypography.fontFamily),
    );

    // Headings are anchored with lineId == -1 and segment == 'pali'.
    final headingAnnotations = _annotationsForLine(-1, 'pali', null);
    final isLookupTarget =
        lookupHighlight != null &&
        lookupHighlight!.matches(
          paraId: paragraph.paraId,
          lineId: -1,
          segment: 'pali',
        );

    final Widget title;
    if (headingAnnotations.isNotEmpty || isLookupTarget) {
      final converted = convertPaliToScriptPreservingHtml(
        heading.title,
        script,
      );
      title = _buildHighlightedText(
        context,
        converted,
        null,
        fontStyle,
        colors,
        annotations: headingAnnotations,
        lookupHighlight: isLookupTarget ? lookupHighlight : null,
      );
    } else {
      title = PaliTextStatic(
        heading.title,
        script,
        fontChoice: paliTypography.fontFamily,
        style: baseStyle,
      );
    }

    final wrappedTitle = MetaData(
      metaData: ReaderLineMetadata(
        paraId: paragraph.paraId,
        lineId: -1,
        segment: 'pali',
      ),
      behavior: HitTestBehavior.translucent,
      child: title,
    );

    final showCopyMenu =
        heading.level <= 10 && bookId != null && bookId!.isNotEmpty;

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: wrappedTitle),
              if (showCopyMenu)
                SectionCopyMenuButton(bookId: bookId!, heading: heading),
            ],
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
      padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: colors.primary.withValues(alpha: 0.25),
              width: 3,
            ),
          ),
        ),
        padding: const EdgeInsets.only(left: 5, top: 4, bottom: 4),
        child: _buildContentBlock(context, colors),
      ),
    );
  }

  Widget _buildContentBlock(BuildContext context, ColorScheme colors) {
    switch (displayMode) {
      case ParagraphDisplayMode.sideBySide:
        return _buildSideBySide(context, colors);
      case ParagraphDisplayMode.hideJoinLines:
        if (!showPali) return _buildAllTranslations(context, colors);
        return _buildJoinedPali(context, colors);
      case ParagraphDisplayMode.lineByLine:
        return _buildLinesStacked(context, colors);
    }
  }

  Widget _buildSideBySide(BuildContext context, ColorScheme colors) {
    // Only-translation (showPali == false) or Pali-only: collapse to a
    // single column instead of leaving an empty half-width column.
    Widget content;
    if (!showPali) {
      content = _buildAllTranslations(context, colors);
    } else if (!showTranslation) {
      content = _buildJoinedPali(context, colors);
    } else {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildJoinedPali(context, colors),
            ),
          ),
          Container(
            width: 1,
            color: colors.outlineVariant.withValues(alpha: 0.4),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _buildAllTranslations(context, colors),
            ),
          ),
        ],
      );
    }
    // Side-by-side has no vertical accent line, so it needs its own left
    // inset — otherwise the text sits flush to the screen edge on mobile.
    // 12 matches the text offset of the lined modes (4 outer + 3 line + 5 gap).
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
      child: content,
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

        final isTtsLine =
            ttsHighlightLineId != null &&
            ttsHighlightParaId != null &&
            paragraph.paraId == ttsHighlightParaId &&
            lineId == ttsHighlightLineId;
        final isPaliHighlighted = isTtsLine && ttsHighlightIsPali == true;
        final isTranslationHighlighted =
            isTtsLine && ttsHighlightIsPali != true;
        final isHighlighted = isTtsLine;

        // WORD-HIGHLIGHT: the spoken word belongs to the spoken line
        // only. The flag short-circuits the whole word path when disabled.
        final ttsWordIndex = isTtsLine && kTtsWordHighlightEnabled
            ? ttsHighlightWordIndex
            : null;
        final ttsWordLineText = isTtsLine && kTtsWordHighlightEnabled
            ? ttsHighlightWordLineText
            : null;

        final isJumpHighlighted =
            jumpHighlightLineId != null &&
            jumpHighlightParaId != null &&
            paragraph.paraId == jumpHighlightParaId &&
            lineId == jumpHighlightLineId;

        final isKeyboardFocus =
            keyboardFocusParaId != null &&
            keyboardFocusLineId != null &&
            paragraph.paraId == keyboardFocusParaId &&
            lineId == keyboardFocusLineId;
        final selectedChipIndex = isKeyboardFocus
            ? keyboardFocusChipIndex
            : null;

        final lineLinks = bookLinks[lineId];

        final hasPali =
            showPali && line.paliText != null && line.paliText!.isNotEmpty;

        final lineContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page break marker at the exact line where a new page begins —
            // a divider with the page number on the right, like a printed
            // book (PDF page break). Drawn even when this line carries no
            // Pāli text, so a mid-paragraph break is always visible.
            if (startsNewPage) _buildPageBreakMarker(linePage, colors),
            // Build the Pāli line lazily (only when it exists) so a line
            // carrying page data but no Pāli text can't crash.
            if (hasPali)
              MetaData(
                metaData: ReaderLineMetadata(
                  paraId: paragraph.paraId,
                  lineId: lineId,
                  segment: 'pali',
                ),
                behavior: HitTestBehavior.translucent,
                child: isPaliHighlighted
                    ? Container(
                        decoration: ttsActiveLineDecoration(colors),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _buildTtsPaliLine(
                          context,
                          line.paliText!,
                          colors,
                          lineId: lineId,
                          wordIndex: ttsWordIndex,
                          wordLineText: ttsWordLineText,
                        ),
                      )
                    : _buildPaliLine(
                        context,
                        line.paliText!,
                        colors,
                        lineId: lineId,
                      ),
              ),
            if (showBookLinks && lineLinks != null && lineLinks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: _buildChips(
                  lineLinks,
                  colors,
                  context,
                  selectedIndex: selectedChipIndex,
                ),
              ),
            if (displayMode == ParagraphDisplayMode.lineByLine &&
                showTranslation)
              _buildTranslationBlock(
                context,
                line.translations,
                colors,
                isTranslationHighlighted,
                lineId: lineId,
                remarks: line.remarks,
                wordIndex: isTranslationHighlighted ? ttsWordIndex : null,
                wordLineText: isTranslationHighlighted ? ttsWordLineText : null,
              ),
          ],
        );

        // The jump highlight wraps the line in a tinted container that
        // fades out over time. TTS highlight and keyboard focus take
        // precedence when they would also apply.
        if (isJumpHighlighted && !isHighlighted && !isKeyboardFocus) {
          return Padding(
            key: lineKeys?[lineId],
            padding: const EdgeInsets.only(bottom: 6),
            child: _JumpHighlightContainer(colors: colors, child: lineContent),
          );
        }

        // The keyboard focus line gets a subtle backdrop so the reading
        // cursor is visible; the TTS highlight (isHighlighted) takes
        // precedence when both would apply.
        if (isKeyboardFocus && !isHighlighted) {
          return Padding(
            key: lineKeys?[lineId],
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(6),
                border: Border(
                  left: BorderSide(
                    color: colors.primary.withValues(alpha: 0.55),
                    width: 3,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: lineContent,
            ),
          );
        }
        return Padding(
          key: lineKeys?[lineId],
          padding: const EdgeInsets.only(bottom: 6),
          child: lineContent,
        );
      }).toList(),
    );
  }

  /// TTS-active Pāli line: child of the underlined container.
  ///
  /// Renders the SPOKEN line converted to the DISPLAY script, so the line
  /// never changes script mid-speech (e.g. Thai display stays Thai even
  /// when the engine speaks Roman/Kannada/Sinhala). The word index transfers
  /// across scripts because transliteration preserves word order/count.
  /// Falls back to the normal Pāli line when the spoken text is missing.
  /// WORD-HIGHLIGHT: delete the word branch (keep the fallback return) to
  /// drop word tracking here.
  Widget _buildTtsPaliLine(
    BuildContext context,
    String text,
    ColorScheme colors, {
    required int lineId,
    int? wordIndex,
    String? wordLineText,
  }) {
    final speakLine = wordLineText?.trim().isNotEmpty == true
        ? wordLineText!
        : null;
    if (speakLine != null) {
      // Same conversion as the display path, minus HTML/formatting: the
      // active line is transient, so plain text keeps offset math trivial.
      final display = convertPaliToScript(speakLine, script);
      if (display.trim().isNotEmpty) {
        final style = TextStyle(
          fontSize: paliTypography.fontSize,
          fontWeight: paliTypography.bold ? FontWeight.w700 : FontWeight.w400,
          fontStyle:
              paliTypography.italic ? FontStyle.italic : FontStyle.normal,
          height: _paliLineHeight,
          color: paliTypography.effectiveColor(paliColor),
          fontFamily: paliReadingFontFamily(script, paliTypography.fontFamily),
        );
        return Text.rich(
          TextSpan(
            style: style,
            children: buildTtsWordIndexSpans(
              plainText: display,
              baseStyle: style,
              colors: colors,
              wordIndex: wordIndex ?? -1,
            ),
          ),
          textAlign: _textAlign,
        );
      }
    }
    return _buildPaliLine(context, text, colors, lineId: lineId);
  }

  Widget _buildChips(
    List<BookLinkData> links,
    ColorScheme colors,
    BuildContext context, {
    int? selectedIndex,
  }) {
    if (links.length <= 3) {
      return Wrap(
        spacing: 4,
        runSpacing: 2,
        children: links.indexed.map((entry) {
          final (i, link) = entry;
          final chipColor = link.isSource ? colors.primary : colors.tertiary;
          return BookLinkChip(
            word: link.word,
            color: chipColor,
            script: script,
            fontChoice: paliTypography.fontFamily,
            selected: i == selectedIndex,
            onTap: () => showBookLinkSectionSheet(context, link: link),
          );
        }).toList(),
      );
    }

    return _ExpandableChips(
      links: links,
      colors: colors,
      script: script,
      fontChoice: paliTypography.fontFamily,
      selectedIndex: selectedIndex,
      onChipTap: (link) => showBookLinkSectionSheet(context, link: link),
    );
  }

  /// Translation lines with optional TTS highlight. When [remarks]
  /// (translation notes keyed by language code) contains a note for a
  /// rendered language, a small note is appended below that line.
  ///
  /// Only the FIRST (spoken) translation is ever highlighted — the engine
  /// speaks the first enabled language only, so the underline container
  /// wraps that line alone while the remaining languages render normally.
  /// [wordIndex]/[wordLineText] locate the spoken word inside the spoken
  /// (first-language) line's speak text.
  Widget _buildTranslationBlock(
    BuildContext context,
    Map<String, String> translations,
    ColorScheme colors,
    bool isHighlighted, {
    required int lineId,
    Map<String, List<TranslationRemark>> remarks = const {},
    int? wordIndex,
    String? wordLineText,
  }) {
    final langs = enabledLangCodes.isNotEmpty ? enabledLangCodes : null;
    if (langs == null || langs.isEmpty) return const SizedBox.shrink();

    Widget? firstLine;
    final rest = <Widget>[];
    for (final langCode in langs) {
      final text = translations[langCode];
      if (text == null || text.trim().isEmpty) continue;
      final typo = langTypographies[langCode];
      final lineWidget = _buildTranslationLine(
        context,
        langCode,
        text,
        typo,
        colors,
        lineId: lineId,
        // WORD-HIGHLIGHT: word range targets the spoken (first) language.
        wordIndex: firstLine == null ? wordIndex : null,
        wordLineText: firstLine == null ? wordLineText : null,
      );
      if (firstLine == null) {
        firstLine = lineWidget;
      } else {
        rest.add(lineWidget);
      }
      final remarkList = remarks[langCode];
      if (remarkList != null && remarkList.any((r) => r.hasContent)) {
        rest.add(
          _buildRemarkNote(context, langCode, lineId, remarkList, colors),
        );
      }
    }
    if (firstLine == null) return const SizedBox.shrink();

    if (!isHighlighted) {
      // Fast path: no highlight container.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [firstLine, ...rest],
      );
    }

    // Highlighted path: the spoken (first) line alone gets the shared
    // underline container; other languages and remark notes stay plain.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: ttsActiveLineDecoration(colors),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: firstLine,
        ),
        ...rest,
      ],
    );
  }

  Widget _buildTranslationLine(
    BuildContext context,
    String langCode,
    String text,
    LanguageTypography? typo,
    ColorScheme colors, {
    required int lineId,
    int? wordIndex,
    String? wordLineText,
  }) {
    final versionLabel = translationVersionLabels[langCode];

    final baseLineHeight = _translationLineHeight(typo);

    final style = typo != null
        ? typo.toTextStyle(fallbackColor: translationColor).copyWith(
            height: baseLineHeight,
          )
        : TextStyle(
            fontFamily: AppTypography.translationFont,
            fontSize: translationFontSize,
            fontWeight: FontWeight.w400,
            height: baseLineHeight,
            color: translationColor.withValues(alpha: 0.8),
          );

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (versionLabel != null && versionLabel.isNotEmpty) ...[
            _buildVersionBadge(versionLabel, colors),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: MetaData(
              metaData: ReaderLineMetadata(
                paraId: paragraph.paraId,
                lineId: lineId,
                segment: 'translation',
                langCode: langCode,
              ),
              behavior: HitTestBehavior.translucent,
              child: _buildTranslationText(
                context,
                text,
                style,
                colors,
                lineId: lineId,
                langCode: langCode,
                wordIndex: wordIndex,
                wordLineText: wordLineText,
              ),
            ),
          ),
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

  /// Small tappable mark shown under a translation line when the
  /// translation database carries a remark for that line.
  ///
  /// The remark text itself is intentionally NOT rendered inline — it would
  /// read like a second translation and clutter the page. Instead a tiny
  /// "note" chip marks the line; tapping it opens the full remark editor
  /// (every field of the remark, editable).
  Widget _buildRemarkNote(
    BuildContext context,
    String langCode,
    int lineId,
    List<TranslationRemark> remarks,
    ColorScheme colors,
  ) {
    final label = AppLocalizations.of(context).translationNote;
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Tooltip(
          message: label,
          child: InkWell(
            borderRadius: BorderRadius.circular(9999),
            onTap: () {
              showTranslationRemarkDialog(
                context,
                bookId: bookId ?? '',
                langCode: langCode,
                paraId: paragraph.paraId,
                lineId: lineId,
                initialRemarks: remarks,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.tertiary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(
                  color: colors.tertiary.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 11, color: colors.tertiary),
                  const SizedBox(width: 3),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: colors.tertiary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJoinedPali(BuildContext context, ColorScheme colors) {
    if (!showPali) return const SizedBox.shrink();

    final text = paragraph.lines
        .map((l) => l.paliText)
        .where((t) => t != null && t.trim().isNotEmpty)
        .join(' ');

    if (text.isEmpty) return const SizedBox.shrink();

    // Joined mode has no per-line anchors — pass every Pāli annotation for
    // this paragraph; the resolver re-anchors each by its quote text.
    // Joined mode keeps a roomier 1.8 base for readability, plus the
    // user's extra line-spacing setting so it applies here too.
    final joinedLineHeight = _paliLineHeight > 1.8
        ? _paliLineHeight
        : 1.8 + (lineHeight / paliFontSize);
    final paliBlock = MetaData(
      metaData: ReaderLineMetadata(
        paraId: paragraph.paraId,
        lineId: null,
        segment: 'pali',
      ),
      behavior: HitTestBehavior.translucent,
      child: _buildPaliLine(
        context,
        text,
        colors,
        lineId: null,
        extraAnnotations: annotations
            .where((a) => a.segment == 'pali' && a.paraId == paragraph.paraId)
            .toList(),
        textAlign: _textAlign,
        lineHeightOverride: joinedLineHeight,
      ),
    );

    // Joined mode renders every line as one continuous block, so there is no
    // per-line anchor to hang book-link chips on. Collect the paragraph's
    // links and show them at the end of the paragraph instead.
    final links = [
      for (final line in paragraph.lines)
        ...(bookLinks[line.lineId] ?? const <BookLinkData>[]),
    ];
    if (!showBookLinks || links.isEmpty) return paliBlock;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        paliBlock,
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _buildChips(links, colors, context),
        ),
      ],
    );
  }

  Widget _buildAllTranslations(BuildContext context, ColorScheme colors) {
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
      widgets.add(
        _buildTranslationLine(
          context,
          langCode,
          texts,
          typo,
          colors,
          lineId: -1,
        ),
      );

      // Translation remarks for this paragraph + language (notes are
      // sparse, so this is almost always empty). In joined mode there is
      // no single line anchor, so each line's remarks render their own
      // mark; the editor is opened for the line that owns them.
      for (final l in paragraph.lines) {
        final remarkList = l.remarks[langCode];
        if (remarkList == null || !remarkList.any((r) => r.hasContent)) {
          continue;
        }
        widgets.add(
          _buildRemarkNote(context, langCode, l.lineId, remarkList, colors),
        );
      }
    }
    if (widgets.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets.expand((w) => [w, const SizedBox(height: 4)]).toList()
        ..removeLast(),
    );
  }

  /// Build a single Pāli line, painting any user highlights for [lineId].
  /// When [lineId] is null (joined/side-by-side mode) [extraAnnotations]
  /// carries the annotations for the joined text instead.
  Widget _buildPaliLine(
    BuildContext context,
    String text,
    ColorScheme colors, {
    int? lineId,
    List<Annotation>? extraAnnotations,
    TextAlign? textAlign,
    double? lineHeightOverride,
  }) {
    final paliTypography = this.paliTypography;
    final effectiveColor = paliTypography.effectiveColor(paliColor);
    final baseLineHeight = lineHeightOverride ?? _paliLineHeight;
    final baseStyle = TextStyle(
      fontSize: paliTypography.fontSize,
      fontWeight: paliTypography.bold ? FontWeight.w700 : FontWeight.w400,
      fontStyle: paliTypography.italic ? FontStyle.italic : FontStyle.normal,
      decoration: paliTypography.underline
          ? TextDecoration.underline
          : TextDecoration.none,
      height: baseLineHeight,
      color: effectiveColor,
    );

    final query = searchQuery;
    final lineAnnotations =
        extraAnnotations ??
        (lineId != null
            ? _annotationsForLine(lineId, 'pali', null)
            : const <Annotation>[]);

    final isLookupTarget =
        lookupHighlight != null &&
        lookupHighlight!.matches(
          paraId: paragraph.paraId,
          lineId: lineId,
          segment: 'pali',
        );

    // Variants render inline (CST-style `[reading]`): the converter keeps
    // the brackets when "Show variant readings" is ON and strips the whole
    // span when OFF. A single render path is used whether or not a
    // search/lookup/annotation highlight is active, so variants stay
    // visible (and tappable for dictionary lookup) in every state.
    final convertedText = convertPaliToScriptPreservingHtml(text, script);
    final convertedQuery = query != null && query.isNotEmpty
        ? convertSearchQueryForScript(query, script)
        : null;
    // The script-specific font must be applied to the spans directly.
    final scriptStyle = baseStyle.copyWith(
      fontFamily: paliReadingFontFamily(script, paliTypography.fontFamily),
    );

    // Variant content between square brackets is styled distinctly; when
    // variants are hidden the converter has already removed the brackets,
    // so this is a no-op. The style is DERIVED from the current colours so
    // it recedes: the text is the line's own colour pulled toward the page
    // extremes — dimmer and grayer in both modes, never a saturated accent
    // that sticks out. Colour only: no background tint.
    final isDark = colors.brightness == Brightness.dark;
    final variantStyle = TextStyle(
      color: Color.lerp(
        effectiveColor,
        isDark ? Colors.black : Colors.white,
        0.35,
      ),
    );

    return _buildHighlightedText(
      context,
      convertedText,
      convertedQuery,
      scriptStyle,
      colors,
      variantStyle: variantStyle,
      annotations: lineAnnotations,
      lookupHighlight: isLookupTarget ? lookupHighlight : null,
      textAlign: textAlign ?? _textAlign,
    );
  }

  Widget _buildTranslationText(
    BuildContext context,
    String text,
    TextStyle style,
    ColorScheme colors, {
    required int lineId,
    String? langCode,
    int? wordIndex,
    String? wordLineText,
  }) {
    if (NissayaTextParser.isNissayaFormat(text)) {
      return NissayaText(
        text: text,
        baseStyle: style,
        plainStyle: style,
        textAlign: _textAlign,
      );
    }

    // WORD-HIGHLIGHT: the spoken translation line renders exactly what is
    // spoken (its speak substring, already plain) with the spoken word
    // filled as a rounded pill. Falls through to rich rendering when the
    // spoken text is missing (e.g. progress unsupported).
    final speakLine = wordLineText?.trim().isNotEmpty == true
        ? wordLineText!
        : null;
    if (speakLine != null) {
      return Text.rich(
        TextSpan(
          style: style,
          children: buildTtsWordIndexSpans(
            plainText: speakLine,
            baseStyle: style,
            colors: colors,
            wordIndex: wordIndex ?? -1,
          ),
        ),
        textAlign: _textAlign,
      );
    }

    final query = searchQuery;
    final lineAnnotations = _annotationsForLine(
      lineId,
      'translation',
      langCode,
    );
    final isLookupTarget =
        lookupHighlight != null &&
        lookupHighlight!.matches(
          paraId: paragraph.paraId,
          lineId: lineId,
          segment: 'translation',
          langCode: langCode,
        );

    if (query != null && query.isNotEmpty ||
        lineAnnotations.isNotEmpty ||
        isLookupTarget) {
      return _buildHighlightedText(
        context,
        text,
        query,
        style,
        colors,
        annotations: lineAnnotations,
        lookupHighlight: isLookupTarget ? lookupHighlight : null,
        textAlign: _textAlign,
      );
    }

    final spans = _parseHtml(text);
    return Text.rich(
      TextSpan(style: style, children: spans),
      textAlign: _textAlign,
    );
  }

  /// Filter this paragraph's annotations to one (line, segment, lang) slot.
  List<Annotation> _annotationsForLine(
    int lineId,
    String segment,
    String? langCode,
  ) {
    return annotations
        .where(
          (a) =>
              a.paraId == paragraph.paraId &&
              a.lineId == lineId &&
              a.segment == segment &&
              a.langCode == langCode,
        )
        .toList();
  }

  /// Resolve + paint user highlight intervals onto [text]'s spans, combined
  /// with search-term highlighting when [query] is non-empty and dictionary
  /// lookup word highlight when [lookupHighlight] is active.
  Widget _buildHighlightedText(
    BuildContext context,
    String text,
    String? query,
    TextStyle baseStyle,
    ColorScheme colors, {
    List<Annotation> annotations = const [],
    ReaderLookupHighlight? lookupHighlight,
    TextAlign? textAlign,
    TextStyle? variantStyle,
  }) {
    final spans = _parseHtml(text);

    // 0) Variant styling: content between square brackets (and the bracket
    //    characters themselves) gets a recessive text colour so readings
    //    stand out inline. A no-op when the text has no brackets (variants
    //    hidden).
    List<InlineSpan> result = variantStyle != null && text.contains('[')
        ? _applyVariantStyling(spans, variantStyle)
        : spans;
    if (query != null && query.isNotEmpty) {
      // Walk the VARIANT-STYLED spans (not the raw parse) so the variant
      // colours survive an active search highlight.
      final styled = result;
      result = <InlineSpan>[];
      for (final span in styled) {
        if (span is TextSpan) {
          final spanText = span.text;
          if (spanText == null) {
            result.add(span);
            continue;
          }
          final subSpans = _highlightInText(
            spanText,
            query,
            span.style ?? baseStyle,
            colors,
          );
          result.addAll(subSpans);
        } else {
          result.add(span);
        }
      }
    }

    // 2) Tapped word lookup highlight (optional).
    if (lookupHighlight != null) {
      final stripped = _stripHtmlTags(text);
      final interval = _resolveLookupInterval(
        strippedText: stripped,
        highlight: lookupHighlight,
      );
      if (interval != null) {
        result = _paintLookupSpan(
          spans: result,
          baseStyle: baseStyle,
          colors: colors,
          start: interval.$1,
          end: interval.$2,
        );
      }
    }

    // 3) User highlight annotations painted on top.
    if (annotations.isNotEmpty) {
      final stripped = _stripHtmlTags(text);
      final highlights = HighlightIntervalResolver.resolve(
        strippedText: stripped,
        annotations: annotations,
        segmentType: annotations.first.segment ?? 'pali',
        langCode: annotations.first.langCode,
        script: script,
      );
      developer.log(
        '[RENDER] para=${paragraph.paraId} resolver ${highlights.length}'
        '/${annotations.length} seg=${annotations.first.segment} '
        'text="${stripped.length > 40 ? stripped.substring(0, 40) : stripped}"',
        name: 'epitaka.annotations',
      );
      if (highlights.isNotEmpty) {
        result = HighlightSpanPainter.paint(
          context: context,
          spans: result,
          baseStyle: baseStyle,
          highlights: highlights,
        );
      }
    }

    return Text.rich(
      TextSpan(style: baseStyle, children: result),
      textAlign: textAlign,
    );
  }

  /// Locate the active lookup highlight interval in stripped character space.
  (int, int)? _resolveLookupInterval({
    required String strippedText,
    required ReaderLookupHighlight highlight,
  }) {
    if (strippedText.isEmpty) return null;
    final len = strippedText.length;

    // 1) If character range was captured and matches the tapped word:
    if (highlight.range != null && !highlight.range!.isCollapsed) {
      final s = highlight.range!.start.clamp(0, len);
      final e = highlight.range!.end.clamp(s, len);
      if (e > s) {
        final slice = strippedText.substring(s, e);
        if (_normWord(slice) == _normWord(highlight.rawWord) ||
            _normWord(slice) == _normWord(highlight.word)) {
          return (s, e);
        }
      }
    }

    // 2) Search for rawWord in strippedText:
    final raw = highlight.rawWord.trim();
    if (raw.isNotEmpty) {
      final idx = strippedText.indexOf(raw);
      if (idx >= 0) {
        return (idx, idx + raw.length);
      }
      final lowerStripped = strippedText.toLowerCase();
      final lowerRaw = raw.toLowerCase();
      final idx2 = lowerStripped.indexOf(lowerRaw);
      if (idx2 >= 0) {
        return (idx2, idx2 + raw.length);
      }
    }

    // 3) Search for converted word in target script:
    final converted = convertPaliToScript(highlight.word, script).trim();
    if (converted.isNotEmpty && converted != raw) {
      final idx = strippedText.indexOf(converted);
      if (idx >= 0) {
        return (idx, idx + converted.length);
      }
    }

    // 4) Search for clean Roman word:
    final roman = highlight.word.trim();
    if (roman.isNotEmpty) {
      final idx = strippedText.toLowerCase().indexOf(roman.toLowerCase());
      if (idx >= 0) {
        return (idx, idx + roman.length);
      }
    }

    return null;
  }

  static String _normWord(String s) =>
      s.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

  /// Paint the active word lookup highlight background onto [spans].
  static List<InlineSpan> _paintLookupSpan({
    required List<InlineSpan> spans,
    required TextStyle baseStyle,
    required ColorScheme colors,
    required int start,
    required int end,
  }) {
    if (spans.isEmpty || end <= start) return spans;
    final painted = <InlineSpan>[];
    int offset = 0;
    for (final span in spans) {
      offset = _paintSingleLookupSpan(
        span,
        baseStyle,
        colors,
        start,
        end,
        painted,
        offset,
      );
    }
    return painted;
  }

  static int _paintSingleLookupSpan(
    InlineSpan span,
    TextStyle baseStyle,
    ColorScheme colors,
    int start,
    int end,
    List<InlineSpan> out,
    int offset,
  ) {
    if (span is! TextSpan) {
      out.add(span);
      return offset;
    }

    if (span.text == null) {
      final children = <InlineSpan>[];
      var childOffset = offset;
      for (final child in span.children ?? const <InlineSpan>[]) {
        childOffset = _paintSingleLookupSpan(
          child,
          baseStyle,
          colors,
          start,
          end,
          children,
          childOffset,
        );
      }
      out.add(TextSpan(style: span.style, children: children));
      return childOffset;
    }

    final text = span.text!;
    final len = text.length;
    if (len == 0) {
      out.add(span);
      return offset;
    }

    final s = start.clamp(offset, offset + len);
    final e = end.clamp(offset, offset + len);
    if (e <= s) {
      out.add(span);
      return offset + len;
    }

    final localStart = s - offset;
    final localEnd = e - offset;

    if (localStart > 0) {
      out.add(TextSpan(text: text.substring(0, localStart), style: span.style));
    }

    final highlightStyle = (span.style ?? baseStyle).copyWith(
      decoration: TextDecoration.underline,
      decorationColor: colors.primary,
      decorationThickness: 1.0,
      decorationStyle: TextDecorationStyle.dashed,
      // backgroundColor: colors.primary.withValues(alpha: 0.08),
      // fontWeight: FontWeight.w600,
    );

    out.add(
      TextSpan(
        text: text.substring(localStart, localEnd),
        style: highlightStyle,
      ),
    );

    if (localEnd < len) {
      out.add(TextSpan(text: text.substring(localEnd), style: span.style));
    }

    return offset + len;
  }

  /// Strip HTML tags (normalizing `<br>` to `\n` like the display parser).
  static String _stripHtmlTags(String html) {
    final normalized = html.replaceAll('<br>', '\n').replaceAll('<br/>', '\n');
    return normalized.replaceAll(RegExp(r'<[^>]*>'), '');
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

  /// Re-splits [spans] so the text between `[` and `]` (and the bracket
  /// characters themselves) carries [variantStyle] (a recessive text
  /// colour, no background). The `inVariant` flag is threaded across the
  /// whole span list because HTML parsing may split a bracket and its
  /// content into separate spans.
  List<InlineSpan> _applyVariantStyling(
    List<InlineSpan> spans,
    TextStyle variantStyle,
  ) {
    final out = <InlineSpan>[];
    var inVariant = false;
    for (final span in spans) {
      if (span is! TextSpan || span.text == null) {
        out.add(span);
        continue;
      }
      final result = _styleVariantInText(
        span.text!,
        span.style,
        variantStyle,
        inVariant: inVariant,
      );
      out.addAll(result.$1);
      inVariant = result.$2;
    }
    return out;
  }

  (List<InlineSpan>, bool) _styleVariantInText(
    String text,
    TextStyle? base,
    TextStyle variantStyle, {
    required bool inVariant,
  }) {
    final pieces = <InlineSpan>[];
    var segStart = 0;
    final variantMerged = base?.merge(variantStyle) ?? variantStyle;

    void flush(int end, TextStyle? style) {
      if (end > segStart) {
        pieces.add(TextSpan(text: text.substring(segStart, end), style: style));
      }
      segStart = end;
    }

    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == '[') {
        flush(i, inVariant ? variantMerged : base);
        pieces.add(TextSpan(text: '[', style: variantMerged));
        inVariant = true;
        segStart = i + 1;
      } else if (ch == ']') {
        flush(i, inVariant ? variantMerged : base);
        pieces.add(TextSpan(text: ']', style: variantMerged));
        inVariant = false;
        segStart = i + 1;
      }
    }
    flush(text.length, inVariant ? variantMerged : base);

    return (pieces, inVariant);
  }

  /// Parse HTML tags into [InlineSpan]s.
  /// Supports: `<b>`, `<i>`, `<u>`, `<h1-6>`, `<br>`
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
    final normalized = html.replaceAll('<br>', '\n').replaceAll('<br/>', '\n');
    // A stack of open tag names lets a closing tag pop only its own element,
    // so nested markup like `<b><i>x</i></b>` (produced by the markdown
    // `***…***` converter) keeps the outer style active after the inner
    // close — the old `.*?` regex rendered nested tags literally instead.
    final tagStack = <String>[];
    final pattern = RegExp(
      r'<(/?)(b|i|u|h[1-6])(\s[^>]*)?/?>|([^<]+)',
      dotAll: true,
      caseSensitive: false,
    );

    TextStyle? currentStyle() {
      if (tagStack.isEmpty) return null;
      var style = const TextStyle();
      final hasBold = tagStack.any((t) {
        if (t == 'b') return true;
        if (t.length != 2 || t[0] != 'h') return false;
        final n = t.codeUnitAt(1);
        return n >= 0x31 && n <= 0x36; // '1'..'6'
      });
      if (hasBold) style = style.copyWith(fontWeight: FontWeight.w700);
      if (tagStack.contains('i')) {
        style = style.copyWith(fontStyle: FontStyle.italic);
      }
      if (tagStack.contains('u')) {
        style = style.copyWith(decoration: TextDecoration.underline);
      }
      return style;
    }

    for (final m in pattern.allMatches(normalized)) {
      if (m.group(1) == '/') {
        // Closing tag — remove the matching open tag (and anything opened
        // after it), leaving outer tags' styles active.
        final name = m.group(2)!.toLowerCase();
        final idx = tagStack.lastIndexOf(name);
        if (idx >= 0) tagStack.removeRange(idx, tagStack.length);
      } else if (m.group(2) != null) {
        tagStack.add(m.group(2)!.toLowerCase());
      } else if (m.group(4) != null) {
        final text = m.group(4)!;
        if (text.trim().isNotEmpty || text == '\n') {
          spans.add(TextSpan(text: text, style: currentStyle()));
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
/// Shows at most 3 chips initially, with an expand button to reveal all.
class _ExpandableChips extends StatefulWidget {
  final List<BookLinkData> links;
  final ColorScheme colors;
  final Script? script;
  final ReadingFontFamily fontChoice;
  final void Function(BookLinkData link) onChipTap;

  /// Index of the keyboard-selected chip; when it's hidden behind the
  /// "+N" button the row auto-expands so the selection is visible.
  final int? selectedIndex;

  const _ExpandableChips({
    required this.links,
    required this.colors,
    this.script,
    required this.fontChoice,
    required this.onChipTap,
    this.selectedIndex,
  });

  @override
  State<_ExpandableChips> createState() => _ExpandableChipsState();
}

class _ExpandableChipsState extends State<_ExpandableChips> {
  static const int maxVisible = 3;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final links = widget.links;
    // Auto-expand when the keyboard-selected chip would be hidden.
    final needsExpansion =
        widget.selectedIndex != null && widget.selectedIndex! >= maxVisible;
    final displayLinks = _expanded || needsExpansion
        ? links
        : links.take(maxVisible).toList();

    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: [
        ...displayLinks.indexed.map((entry) => _buildChip(entry.$2, entry.$1)),
        if (!_expanded && !needsExpansion) _buildExpandButton(),
        if (_expanded || needsExpansion) _buildCollapseButton(),
      ],
    );
  }

  Widget _buildChip(BookLinkData link, int index) {
    final chipColor = link.isSource
        ? widget.colors.primary
        : widget.colors.tertiary;
    return BookLinkChip(
      word: link.word,
      color: chipColor,
      script: widget.script,
      fontChoice: widget.fontChoice,
      selected: index == widget.selectedIndex,
      onTap: () => widget.onChipTap(link),
    );
  }

  Widget _buildExpandButton() {
    final remaining = widget.links.length - maxVisible;
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

/// Container that shows a jump-highlighted line with a fade-out animation.
/// Starts fully opaque with a tinted background, then fades to transparent
/// over [_kJumpHighlightDuration] seconds.
class _JumpHighlightContainer extends StatefulWidget {
  final ColorScheme colors;
  final Widget child;

  const _JumpHighlightContainer({required this.colors, required this.child});

  @override
  State<_JumpHighlightContainer> createState() =>
      _JumpHighlightContainerState();
}

class _JumpHighlightContainerState extends State<_JumpHighlightContainer>
    with SingleTickerProviderStateMixin {
  static const _kTotalDuration = Duration(seconds: 3);

  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _kTotalDuration);
    // Hold at full opacity for 2s, then fade out over 1s.
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.667, 1.0, curve: Curves.easeOut),
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) {
        final alpha = _opacity.value;
        // Warm amber/orange accent — stands out against both light and
        // dark backgrounds without looking harsh.
        final accent = Color(0xFFE8A040);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: accent.withValues(alpha: 0.85 * alpha),
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          child: child,
        );
      },
      child: widget.child,
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
