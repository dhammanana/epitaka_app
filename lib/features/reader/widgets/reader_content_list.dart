import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../shared/widgets/reading_paragraph.dart';
import '../providers/reader_provider.dart';

/// Displays a scrollable list of [ReadingParagraph] widgets powered by
/// [ScrollablePositionedList].
///
/// This widget encapsulates everything related to rendering the paragraph
/// list: loading/error/empty states, TTS line highlighting, search query
/// highlighting, and the per-paragraph builder with all styling parameters.
///
/// All scroll controllers/listeners are injected from the parent so the
/// parent retains full control over scroll position, programmatic jumps,
/// and position tracking.
class ReaderContentList extends StatelessWidget {
  const ReaderContentList({
    super.key,
    required this.bookId,
    required this.data,
    required this.settings,
    required this.colors,
    required this.paliColor,
    required this.translationColor,
    required this.enabledLangs,
    required this.langTypographies,
    required this.itemScrollController,
    required this.itemPositionsListener,
    required this.scrollOffsetListener,
    this.scrollOffsetController,
    this.ttsHighlightLineId,
    this.ttsHighlightParaId,
    this.ttsTargetParaId,
    this.ttsTargetLineKeys = const {},
    this.searchQuery,
    this.onFirstContentFrame,
  });

  /// Book ID for keying the list instance.
  final String bookId;

  /// Reader data state (paragraphs, headings, links, etc.).
  final ReaderDataState data;

  /// Current app settings (showPali, showTranslation, displayMode, typography).
  final AppSettings settings;

  /// Color scheme from the current theme.
  final ColorScheme colors;

  /// Resolved Pāli text color.
  final Color paliColor;

  /// Resolved translation text color.
  final Color translationColor;

  /// Enabled translation language codes.
  final List<String> enabledLangs;

  /// Per-language typography overrides.
  final Map<String, LanguageTypography> langTypographies;

  // ── Scroll controllers / listeners ──────────────────────────────────

  final ItemScrollController itemScrollController;
  final ItemPositionsListener itemPositionsListener;
  final ScrollOffsetListener scrollOffsetListener;
  final ScrollOffsetController? scrollOffsetController;

  // ── TTS highlight ───────────────────────────────────────────────────

  /// Line ID to highlight (TTS current spoken line).
  final int? ttsHighlightLineId;

  /// Para ID that [ttsHighlightLineId] belongs to.
  final int? ttsHighlightParaId;

  /// Para ID for which TTS line keys are provided (for fine-scroll).
  final int? ttsTargetParaId;

  /// Per-line GlobalKeys for fine-scroll to a specific line.
  final Map<int, GlobalKey> ttsTargetLineKeys;

  // ── Search ──────────────────────────────────────────────────────────

  /// Current search query for highlighting, or null if none.
  final String? searchQuery;

  /// Called the first time content is actually built for this book
  /// (for performance measurement).
  final VoidCallback? onFirstContentFrame;

  /// Convert translation display mode settings into [ParagraphDisplayMode].
  static ParagraphDisplayMode _toParagraphDisplayMode(
    TranslationDisplayMode mode,
    bool showTranslation,
  ) {
    if (!showTranslation) return ParagraphDisplayMode.hideJoinLines;
    switch (mode) {
      case TranslationDisplayMode.sideBySide:
        return ParagraphDisplayMode.sideBySide;
      case TranslationDisplayMode.lineByLine:
        return ParagraphDisplayMode.lineByLine;
      case TranslationDisplayMode.hideJoinLines:
        return ParagraphDisplayMode.hideJoinLines;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (data.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (data.error != null) {
      return Center(child: Text('Error loading text: ${data.error}'));
    }

    if (data.paragraphs.isEmpty) {
      return const Center(child: Text('No content found.'));
    }

    final displayMode = _toParagraphDisplayMode(
      settings.translationDisplayMode,
      settings.showTranslation,
    );

    // Log the first time content is actually built for this book.
    onFirstContentFrame?.call();

    return ScrollablePositionedList.builder(
      key: ValueKey('reader-$bookId'),
      itemScrollController: itemScrollController,
      itemPositionsListener: itemPositionsListener,
      scrollOffsetListener: scrollOffsetListener,
      scrollOffsetController: scrollOffsetController ?? ScrollOffsetController(),
      padding: const EdgeInsets.fromLTRB(
        0,
        AppDimensions.lg,
        AppDimensions.marginMobile,
        120,
      ),
      itemCount: data.paragraphs.length,
      itemBuilder: (context, index) {
        final paragraph = data.paragraphs[index];

        // Pass line keys for the TTS target paragraph so
        // Scrollable.ensureVisible can precisely scroll to the line.
        Map<int, GlobalKey>? lineKeys;
        if (ttsTargetParaId != null &&
            paragraph.paraId == ttsTargetParaId &&
            ttsTargetLineKeys.isNotEmpty) {
          lineKeys = Map.from(ttsTargetLineKeys);
        }

        return RepaintBoundary(
          child: ReadingParagraph(
          // Stable key for every paragraph — never a shared GlobalKey.
          // Re-keying a list item at runtime forces a semantics re-parent
          // that crashes (see reader_screen.dart).
          key: ValueKey('para-$bookId-${paragraph.paraId}'),
          paragraph: paragraph,
          isFirst: index == 0,
          bookName: index == 0 ? data.bookName : null,
          bookDescription: index == 0 ? data.bookDescription : null,
          showPali: settings.showPali,
          showTranslation: settings.showTranslation,
          displayMode: displayMode,
          paliColor: paliColor,
          translationColor: translationColor,
          paliTypography: settings.typography.pali,
          langTypographies: langTypographies,
          enabledLangCodes: enabledLangs,
          bookLinks: data.bookLinks[paragraph.paraId] ?? const {},
          searchQuery: searchQuery,
          ttsHighlightLineId: ttsHighlightLineId,
          ttsHighlightParaId: ttsHighlightParaId,
          lineKeys: lineKeys,
          // Pass script and pageNumberingSystem from parent instead of
          // forcing ReadingParagraph to watch settingsProvider directly.
          // This avoids rebuilding ALL visible paragraphs on every
          // unrelated settings change.
          script: settings.paliScript,
          pageNumberingSystem: settings.pageNumberingSystem,
          paliFontSize: settings.typography.pali.fontSize,
          paliLineHeight: settings.typography.pali.lineHeight,
          translationFontSize: settings.typography.fontSizeFor(
            settings.primaryTranslationLang,
          ),
          translationLineHeight: settings.typography.lineHeightFor(
            settings.primaryTranslationLang,
          ),
        ),
        );
      },
    );
  }
}
