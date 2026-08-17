import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/pali_text_utils.dart' show stripVariantAnnotations;
import '../../annotations/models/annotation.dart';
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
    this.keyboardFocusParaId,
    this.keyboardFocusLineId,
    this.keyboardFocusChipIndex,
    this.showBookLinks = true,
    this.searchQuery,
    this.onFirstContentFrame,
    this.initialScrollIndex,
    this.annotations = const {},
    this.appBarCollapsed,
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

  /// Keyboard-navigation focus line (reading cursor) to highlight.
  final int? keyboardFocusParaId;
  final int? keyboardFocusLineId;
  final int? keyboardFocusChipIndex;

  /// Whether inlined book-link chips (commentary links) are rendered.
  final bool showBookLinks;

  // ── Search ──────────────────────────────────────────────────────────

  /// Current search query for highlighting, or null if none.
  final String? searchQuery;

  /// Called the first time content is actually built for this book
  /// (for performance measurement).
  final VoidCallback? onFirstContentFrame;

  /// Starting scroll index. When set, the list initially renders at this
  /// index instead of 0, preventing a flash-to-top on tab switch before
  /// the post-frame [_jumpToParagraph] correction.
  final int? initialScrollIndex;

  /// User annotations (highlights/notes) grouped by paragraph id, for the
  /// reader's highlight painting.
  final Map<int, List<Annotation>> annotations;

  /// App-bar collapse state (phone reader only). When the app bar
  /// collapses, its layout height shrinks and the tab strip below moves up
  /// into its space — the list viewport grows taller at the top. This list
  /// compensates by growing an equal top padding on the scrollable CONTENT,
  /// which keeps the visible text at exactly the same screen position: the
  /// viewport top moves up by the collapse amount while the content is
  /// pushed down by the same amount.
  ///
  /// The padding animates with the same duration/curve as the app bar
  /// collapse (250ms / easeInOut), so the text never moves during the
  /// transition either — and because it is a layout change (not a scroll),
  /// it never interrupts an in-progress finger drag. Null on desktop, where
  /// the reader has no collapsible app bar.
  final ValueNotifier<bool>? appBarCollapsed;

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

    final loc = AppLocalizations.of(context);
    if (data.error != null) {
      return Center(child: Text('${loc.errorLoadingText} ${data.error}'));
    }

    if (data.paragraphs.isEmpty) {
      return Center(child: Text(loc.noContentFound));
    }

    // Push the variant-stripping flag into the shared converter global.
    // PaliText/PaliHtmlText normally do this themselves, but the reader
    // renders through PaliTextWithVariants and direct converter calls
    // (heading / highlight paths), which only READ the global — so without
    // this push, toggling "Show variant readings" would have no effect in
    // the reader until some unrelated screen rebuilt.
    stripVariantAnnotations = settings.stripVariantAnnotations;

    final displayMode = _toParagraphDisplayMode(
      settings.translationDisplayMode,
      settings.showTranslation,
    );

    // Log the first time content is actually built for this book.
    onFirstContentFrame?.call();

    // Use initialScrollIndex when available (tab restore) to start at the
    // saved position instead of index 0, avoiding a flash-to-top before
    // the post-frame [_jumpToParagraph] correction.
    final scrollIndex = initialScrollIndex != null
        ? initialScrollIndex!.clamp(0, data.paragraphs.length - 1)
        : 0;

    // Animate the collapse padding in lockstep with the app bar's
    // AnimatedSize (same 250ms / easeInOut) so the book text stays fixed
    // throughout the collapse/expand transition.
    Widget buildList(double pad) => TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: pad),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      builder: (context, pad, _) => ScrollablePositionedList.builder(
        key: ValueKey('reader-$bookId'),
        initialScrollIndex: scrollIndex,
        itemScrollController: itemScrollController,
        itemPositionsListener: itemPositionsListener,
        scrollOffsetListener: scrollOffsetListener,
        scrollOffsetController:
            scrollOffsetController ?? ScrollOffsetController(),
        padding: EdgeInsets.fromLTRB(
          0,
          AppDimensions.lg + pad,
          AppDimensions.marginMobile,
          120,
        ),
        itemCount: data.paragraphs.length,
        itemBuilder: (context, index) {
          final paragraph = data.paragraphs[index];

          // Seed the per-line page tracking with the previous paragraph's last
          // page (selected system) so a page break on this paragraph's first
          // line is still detected. ParagraphData.pageNumbers holds the merged
          // (last-line) page values, which is exactly the carry-forward value.
          final previousLinePage = index > 0
              ? data.paragraphs[index - 1].pageNumbers[settings
                    .pageNumberingSystem]
              : null;

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
              bookId: bookId,
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
              showBookLinks: showBookLinks,
              searchQuery: searchQuery,
              ttsHighlightLineId: ttsHighlightLineId,
              ttsHighlightParaId: ttsHighlightParaId,
              lineKeys: lineKeys,
              keyboardFocusParaId: keyboardFocusParaId,
              keyboardFocusLineId: keyboardFocusLineId,
              keyboardFocusChipIndex: keyboardFocusChipIndex,
              annotations: annotations[paragraph.paraId] ?? const [],
              // Pass script and pageNumberingSystem from parent instead of
              // forcing ReadingParagraph to watch settingsProvider directly.
              // This avoids rebuilding ALL visible paragraphs on every
              // unrelated settings change.
              script: settings.paliScript,
              pageNumberingSystem: settings.pageNumberingSystem,
              previousLinePageNumber: previousLinePage,
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
      ),
    );

    // Only phones collapse the app bar; elsewhere there is no compensation.
    final collapseNotifier = appBarCollapsed;
    if (collapseNotifier == null) return buildList(0);
    return ValueListenableBuilder<bool>(
      valueListenable: collapseNotifier,
      builder: (context, collapsed, _) =>
          buildList(collapsed ? AppDimensions.appBarHeight + 1 : 0),
    );
  }
}
