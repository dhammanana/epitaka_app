import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/pali_script_converter.dart' show Script;
import '../../../core/utils/pali_text_utils.dart' show stripVariantAnnotations;
import '../../annotations/models/annotation.dart';
import '../../reader/data/book_link_data.dart';
import '../../../shared/widgets/reading_paragraph.dart';
import '../providers/reader_provider.dart';
import 'reader_highlight_bundle.dart';

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
///
/// ## Per-paragraph rebuild memoization
///
/// The list is stateful and caches the last-built [ReadingParagraph] widget
/// per paragraph id. On every rebuild each paragraph compares its
/// "render inputs" — the data paragraph object, its annotation list, its
/// typography/colour settings, and its [ReaderHighlightSlice] of the
/// highlight bundle — and when nothing changed, the previously built widget
/// is returned as-is. A highlight change (search query, dictionary lookup,
/// TTS line, jump flash, keyboard cursor) therefore rebuilds only the one
/// or two paragraphs it actually touches instead of every visible one.
///
/// Comparisons are identity- or value-based depending on the type:
/// [ParagraphData] and annotation lists are compared by identity (the
/// providers produce fresh instances on real changes), typography and the
/// highlight slice by value equality, and book links by identity (they only
/// change with the data).
class ReaderContentList extends StatefulWidget {
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
    required this.onScrollDelta,
    required this.highlightBundle,
    this.scrollOffsetController,
    this.showBookLinks = true,
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

  /// Reports finger/programmatic scroll deltas to the parent. Sourced from a
  /// [NotificationListener] around the list instead of [scrollOffsetListener]:
  /// after any long programmatic jump the package swaps its internal
  /// primary/secondary lists and the listener attached in `initState` keeps
  /// watching the detached controller, so it goes permanently silent and the
  /// app bar would never collapse again.
  final ValueChanged<double> onScrollDelta;

  /// Cross-paragraph highlight state (search, lookup, TTS, jump, keyboard
  /// cursor). Each paragraph only rebuilds when ITS slice of this bundle
  /// changes — see [ReaderHighlightBundle.sliceFor].
  final ReaderHighlightBundle highlightBundle;

  /// Whether inlined book-link chips (commentary links) are rendered.
  final bool showBookLinks;

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

  @override
  State<ReaderContentList> createState() => _ReaderContentListState();
}

/// Everything outside the highlight bundle that changes how a paragraph
/// renders, compared by value so the memo can distinguish "settings tweak"
/// from "unrelated rebuild".
class _ReaderContentConfig {
  final String bookId;
  final bool showPali;
  final bool showTranslation;
  final ParagraphDisplayMode displayMode;
  final Color paliColor;
  final Color translationColor;
  final LanguageTypography paliTypography;
  final Map<String, LanguageTypography> langTypographies;
  final List<String> enabledLangs;
  final bool showBookLinks;
  final Script script;
  final String pageNumberingSystem;
  final double translationFontSize;
  final double translationLineHeight;

  const _ReaderContentConfig({
    required this.bookId,
    required this.showPali,
    required this.showTranslation,
    required this.displayMode,
    required this.paliColor,
    required this.translationColor,
    required this.paliTypography,
    required this.langTypographies,
    required this.enabledLangs,
    required this.showBookLinks,
    required this.script,
    required this.pageNumberingSystem,
    required this.translationFontSize,
    required this.translationLineHeight,
  });

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

  factory _ReaderContentConfig.from(ReaderContentList widget) {
    final settings = widget.settings;
    return _ReaderContentConfig(
      bookId: widget.bookId,
      showPali: settings.showPali,
      showTranslation: settings.showTranslation,
      displayMode: _toParagraphDisplayMode(
        settings.translationDisplayMode,
        settings.showTranslation,
      ),
      paliColor: widget.paliColor,
      translationColor: widget.translationColor,
      paliTypography: settings.typography.pali,
      langTypographies: widget.langTypographies,
      enabledLangs: widget.enabledLangs,
      showBookLinks: widget.showBookLinks,
      script: settings.paliScript,
      pageNumberingSystem: settings.pageNumberingSystem,
      translationFontSize: settings.typography.fontSizeFor(
        settings.primaryTranslationLang,
      ),
      translationLineHeight: settings.typography.lineHeightFor(
        settings.primaryTranslationLang,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _ReaderContentConfig &&
        other.bookId == bookId &&
        other.showPali == showPali &&
        other.showTranslation == showTranslation &&
        other.displayMode == displayMode &&
        other.paliColor == paliColor &&
        other.translationColor == translationColor &&
        other.paliTypography == paliTypography &&
        mapEquals(other.langTypographies, langTypographies) &&
        listEquals(other.enabledLangs, enabledLangs) &&
        other.showBookLinks == showBookLinks &&
        identical(other.script, script) &&
        other.pageNumberingSystem == pageNumberingSystem &&
        other.translationFontSize == translationFontSize &&
        other.translationLineHeight == translationLineHeight;
  }

  @override
  int get hashCode => Object.hash(
    bookId,
    showPali,
    showTranslation,
    displayMode,
    paliColor,
    translationColor,
    paliTypography,
    Object.hashAllUnordered(langTypographies.keys),
    Object.hashAll(enabledLangs),
    showBookLinks,
    script,
    pageNumberingSystem,
    translationFontSize,
    translationLineHeight,
  );
}

/// Last-built widget + the render inputs it was built with, for one
/// paragraph slot.
class _ParagraphMemoEntry {
  final ParagraphData paragraph;
  final List<Annotation> annotations;
  final ParaBookLinks bookLinks;
  final ReaderHighlightSlice slice;
  final bool isFirst;
  final Widget child;

  const _ParagraphMemoEntry({
    required this.paragraph,
    required this.annotations,
    required this.bookLinks,
    required this.slice,
    required this.isFirst,
    required this.child,
  });
}

class _ReaderContentListState extends State<ReaderContentList> {
  /// Render-input snapshot the memo was built against. When this changes
  /// (settings, theme colours, book), every cached paragraph is rebuilt.
  _ReaderContentConfig _config = _ReaderContentConfig(
    bookId: '',
    showPali: false,
    showTranslation: false,
    displayMode: ParagraphDisplayMode.lineByLine,
    paliColor: const Color(0x00000000),
    translationColor: const Color(0x00000000),
    paliTypography: const LanguageTypography(),
    langTypographies: const {},
    enabledLangs: const [],
    showBookLinks: true,
    script: Script.roman,
    pageNumberingSystem: 'vri',
    translationFontSize: 17,
    translationLineHeight: 28 / 17,
  );

  /// Identity of the data / annotations the memo was built against. New
  /// instances mean the underlying content changed.
  ReaderDataState? _lastData;
  Map<int, List<Annotation>>? _lastAnnotations;

  /// paraId → last built widget + its inputs.
  final Map<int, _ParagraphMemoEntry> _memo = {};

  @override
  void initState() {
    super.initState();
    _config = _ReaderContentConfig.from(widget);
    _lastData = widget.data;
    _lastAnnotations = widget.annotations;
  }

  @override
  void didUpdateWidget(covariant ReaderContentList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newConfig = _ReaderContentConfig.from(widget);
    if (newConfig != _config) {
      // Any render-affecting setting changed → rebuild every paragraph.
      _config = newConfig;
      _memo.clear();
    }
    if (!identical(widget.data, _lastData)) {
      // New paragraph data (book opened/reloaded) → rebuild everything.
      _lastData = widget.data;
      _memo.clear();
    }
    if (!identical(widget.annotations, _lastAnnotations)) {
      // Annotations refreshed: drop only the paragraphs whose annotation
      // list actually changed (per-paragraph lists are rebuilt by the
      // grouping provider, unchanged paragraphs keep their list instance).
      final oldMap = _lastAnnotations!;
      final newMap = widget.annotations;
      _lastAnnotations = newMap;
      _memo.removeWhere((paraId, _) {
        final oldList = oldMap[paraId] ?? const <Annotation>[];
        final newList = newMap[paraId] ?? const <Annotation>[];
        return !identical(oldList, newList);
      });
    }
  }

  /// Build (or reuse) the widget for one paragraph.
  Widget _buildParagraph(BuildContext context, int index) {
    final data = widget.data;
    final paragraph = data.paragraphs[index];
    final settings = widget.settings;
    final config = _config;

    // Seed the per-line page tracking with the previous paragraph's last
    // page (selected system) so a page break on this paragraph's first line
    // is still detected. ParagraphData.pageNumbers holds the merged
    // (last-line) page values, which is exactly the carry-forward value.
    final previousLinePage = index > 0
        ? data.paragraphs[index - 1].pageNumbers[settings.pageNumberingSystem]
        : null;

    final paraAnnotations = widget.annotations[paragraph.paraId] ?? const [];
    final paraLinks = data.bookLinks[paragraph.paraId] ?? const {};
    final slice = widget.highlightBundle.sliceFor(paragraph.paraId);
    final isFirst = index == 0;

    final existing = _memo[paragraph.paraId];
    if (existing != null &&
        identical(existing.paragraph, paragraph) &&
        identical(existing.annotations, paraAnnotations) &&
        identical(existing.bookLinks, paraLinks) &&
        existing.slice == slice &&
        existing.isFirst == isFirst) {
      return existing.child;
    }

    final child = RepaintBoundary(
      child: ReadingParagraph(
        // Stable key for every paragraph — never a shared GlobalKey.
        // Re-keying a list item at runtime forces a semantics re-parent
        // that crashes (see reader_screen.dart).
        key: ValueKey('para-${config.bookId}-${paragraph.paraId}'),
        paragraph: paragraph,
        isFirst: isFirst,
        bookId: config.bookId,
        bookName: isFirst ? data.bookName : null,
        bookDescription: isFirst ? data.bookDescription : null,
        showPali: config.showPali,
        showTranslation: config.showTranslation,
        displayMode: config.displayMode,
        paliColor: config.paliColor,
        translationColor: config.translationColor,
        paliTypography: config.paliTypography,
        langTypographies: config.langTypographies,
        enabledLangCodes: config.enabledLangs,
        bookLinks: paraLinks,
        showBookLinks: config.showBookLinks,
        searchQuery: slice.searchQuery,
        lookupHighlight: slice.lookupHighlight,
        ttsHighlightLineId: slice.ttsHighlightLineId,
        // The slice only carries a TTS line for THIS paragraph, so the
        // paraId gate always passes: the slice's line implies its para.
        ttsHighlightParaId: slice.ttsHighlightLineId != null
            ? paragraph.paraId
            : null,
        jumpHighlightLineId: slice.jumpHighlightLineId,
        jumpHighlightParaId: slice.jumpHighlightLineId != null
            ? paragraph.paraId
            : null,
        lineKeys: slice.lineKeys.isEmpty ? null : slice.lineKeys,
        keyboardFocusParaId: slice.keyboardFocusParaId,
        keyboardFocusLineId: slice.keyboardFocusLineId,
        keyboardFocusChipIndex: slice.keyboardFocusChipIndex,
        annotations: paraAnnotations,
        // Script and page system come from the config so paragraphs don't
        // rebuild on unrelated settings changes (see ReadingParagraph docs).
        script: config.script,
        pageNumberingSystem: config.pageNumberingSystem,
        previousLinePageNumber: previousLinePage,
        paliFontSize: config.paliTypography.fontSize,
        paliLineHeight: config.paliTypography.lineHeight,
        translationFontSize: config.translationFontSize,
        translationLineHeight: config.translationLineHeight,
      ),
    );

    // Hygiene: only the ~15 visible paragraphs can ever be reused, so a
    // very long book scrolled end-to-end would otherwise accumulate dead
    // entries. Resetting occasionally just costs one visible rebuild.
    if (_memo.length >= 2048) _memo.clear();

    _memo[paragraph.paraId] = _ParagraphMemoEntry(
      paragraph: paragraph,
      annotations: paraAnnotations,
      bookLinks: paraLinks,
      slice: slice,
      isFirst: isFirst,
      child: child,
    );
    return child;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;

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
    stripVariantAnnotations = widget.settings.stripVariantAnnotations;

    // Log the first time content is actually built for this book.
    widget.onFirstContentFrame?.call();

    // Use initialScrollIndex when available (tab restore) to start at the
    // saved position instead of index 0, avoiding a flash-to-top before
    // the post-frame [_jumpToParagraph] correction.
    final scrollIndex = widget.initialScrollIndex != null
        ? widget.initialScrollIndex!.clamp(0, data.paragraphs.length - 1)
        : 0;

    // Animate the collapse padding in lockstep with the app bar's
    // AnimatedSize (same 250ms / easeInOut) so the book text stays fixed
    // throughout the collapse/expand transition.
    Widget buildList(double pad) => TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: pad),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      builder: (context, pad, _) =>
          NotificationListener<ScrollUpdateNotification>(
            onNotification: (notification) {
              final delta = notification.scrollDelta;
              if (delta != null && delta != 0) widget.onScrollDelta(delta);
              return false;
            },
            child: ScrollablePositionedList.builder(
              key: ValueKey('reader-${widget.bookId}'),
              initialScrollIndex: scrollIndex,
              itemScrollController: widget.itemScrollController,
              itemPositionsListener: widget.itemPositionsListener,
              scrollOffsetListener: widget.scrollOffsetListener,
              scrollOffsetController:
                  widget.scrollOffsetController ?? ScrollOffsetController(),
              padding: EdgeInsets.fromLTRB(
                0,
                AppDimensions.lg + pad,
                AppDimensions.marginMobile,
                120,
              ),
              itemCount: data.paragraphs.length,
              itemBuilder: _buildParagraph,
            ),
          ),
    );

    // Only phones collapse the app bar; elsewhere there is no compensation.
    final collapseNotifier = widget.appBarCollapsed;
    if (collapseNotifier == null) return buildList(0);
    return ValueListenableBuilder<bool>(
      valueListenable: collapseNotifier,
      builder: (context, collapsed, _) =>
          buildList(collapsed ? AppDimensions.appBarHeight + 1 : 0),
    );
  }
}
