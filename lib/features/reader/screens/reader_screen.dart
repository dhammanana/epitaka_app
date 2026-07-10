import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/settings/providers/tts_provider.dart';
import '../providers/tts_reading_provider.dart';
import '../../../shared/utils/reading_clipboard.dart';
import '../../../shared/widgets/reading_paragraph.dart';
import '../../../core/utils/platform_info.dart';
import '../../../core/providers/app_db_provider.dart';
import '../../dictionary/widgets/dictionary_sheet.dart';
import '../../search/widgets/search_sheet.dart';
import '../providers/reader_provider.dart';
import '../providers/reader_tabs_provider.dart';
import '../widgets/bookmark_dialog.dart';
import '../widgets/tab_strip.dart';

/// Reader screen with multiple tabs, showing Pāli text with translations.
/// Each tab has its own scroll position stored in [ReaderTabInfo].
///
/// Jumping (TOC, TTS auto-scroll, search-result jump, tab restore) is done
/// purely by paragraph *index* via [ScrollablePositionedList] / an
/// [ItemScrollController]. We never estimate pixel offsets from paragraph
/// count — paragraph height varies too much (Pali-only vs Pali+N
/// translations, side-by-side vs line-by-line) for that to be reliable.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with WidgetsBindingObserver {
  final _selectionAreaKey = GlobalKey<SelectionAreaState>();

  // One controller/listener pair per open book tab.
  final Map<String, ItemScrollController> _itemScrollControllers = {};
  final Map<String, ItemPositionsListener> _itemPositionsListeners = {};
  final Map<String, VoidCallback> _positionsListenerRefs = {};

  int _lastTapTime = 0;
  bool _awaitingSelection = false;
  Timer? _fallbackTimer;

  // Track the last paraId we've jumped to per book, so we don't re-jump
  // every time the tab rebuilds (e.g. on unrelated provider changes).
  final Map<String, int> _lastJumpedParaId = {};

  // Guards against overlapping jump attempts for the same (bookId, paraId)
  // request racing each other.
  final Map<String, int> _pendingJumpParaId = {};

  /// Visible paragraph indices for the active tab (used for copying fallback).
  int _visibleStartIndex = 0;
  int _visibleEndIndex = 0;

  /// Cached selection content from [SelectionArea.onSelectionChanged] for
  /// Ctrl+C and context-menu copy buttons.
  SelectedContent? _lastSelectedContent;

  // App lifecycle state for background TTS optimization
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  // Silverbar: collapsible app bar on scroll
  bool _appBarCollapsed = false;

  // Pixel-based scroll tracking (per book) — replaces the old fractional
  // itemLeadingEdge approach, which reset every time the top item changed
  // and caused flicker.
  final Map<String, ScrollOffsetListener> _scrollOffsetListeners = {};
  final Map<String, StreamSubscription<double>> _scrollOffsetSubs = {};
  final Map<String, double> _scrollAccum = {};
  static const double _kScrollThreshold = 20.0; // px

  /// Tracks which bookId we already restored position for (prevents
  /// re-snapping on rebuild).
  String? _lastRestoredBookId;

  /// Last saved paraId per book (to avoid duplicate saves).
  final Map<String, int> _lastSavedParaIdPerBook = {};

  /// Debounce timer for scroll-based history saves.
  Timer? _saveHistoryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _appLifecycleState = state);
  }

  ItemScrollController _scrollControllerFor(String bookId) {
    return _itemScrollControllers.putIfAbsent(
      bookId,
      () => ItemScrollController(),
    );
  }

  ItemPositionsListener _positionsListenerFor(String bookId) {
    return _itemPositionsListeners.putIfAbsent(bookId, () {
      final listener = ItemPositionsListener.create();
      void onPositionsChanged() => _onPositionsChanged(bookId);
      _positionsListenerRefs[bookId] = onPositionsChanged;
      listener.itemPositions.addListener(onPositionsChanged);
      return listener;
    });
  }

  ScrollOffsetListener _scrollOffsetListenerFor(String bookId) {
    return _scrollOffsetListeners.putIfAbsent(bookId, () {
      final listener = ScrollOffsetListener.create();
      _scrollOffsetSubs[bookId] = listener.changes.listen((delta) {
        _onScrollOffsetChanged(bookId, delta);
      });
      return listener;
    });
  }

  // Pixel-accurate scroll direction tracking. Accumulates movement in one
  // direction; flips/resets the accumulator if direction reverses. Once the
  // accumulator crosses _kScrollThreshold px, flips the appbar state once
  // and resets — no bounce, no fractional-viewport noise.
  void _onScrollOffsetChanged(String bookId, double delta) {
    if (!mounted || delta == 0) return;
    if (ref.read(readerTabsProvider).activeTab?.bookId != bookId) return;
    if (!Mobile.isPhone(context)) return;

    final acc = _scrollAccum[bookId] ?? 0;
    final sameDirection = acc == 0 || (delta > 0) == (acc > 0);
    final newAcc = sameDirection ? acc + delta : delta;

    if (newAcc > _kScrollThreshold) {
      _scrollAccum[bookId] = 0;
      if (!_appBarCollapsed) setState(() => _appBarCollapsed = true);
    } else if (newAcc < -_kScrollThreshold) {
      _scrollAccum[bookId] = 0;
      if (_appBarCollapsed) setState(() => _appBarCollapsed = false);
    } else {
      _scrollAccum[bookId] = newAcc;
    }
  }

  // ── Position tracking, silverbar, pagination ─────────────────────────
  //
  // Driven by ItemPositionsListener, which reports the *actual* visible
  // item indices from the layout — no "pixels / assumedRowHeight" guess.
  void _onPositionsChanged(String bookId) {
    final listener = _itemPositionsListeners[bookId];
    final positions = listener?.itemPositions.value;
    if (positions == null || positions.isEmpty) return;

    // The item with the smallest (most negative/zero) leading edge that's
    // still at least partially visible (trailingEdge > 0) is the topmost
    // visible item.
    final visible = positions.where((p) => p.itemTrailingEdge > 0).toList()
      ..sort((a, b) => a.itemLeadingEdge.compareTo(b.itemLeadingEdge));
    if (visible.isEmpty) return;
    final topIndex = visible.first.index;

    final tabsState = ref.read(readerTabsProvider);
    final tabIndex = tabsState.tabs.indexWhere((t) => t.bookId == bookId);
    if (tabIndex >= 0) {
      final readerState = ref.read(readerDataProvider(bookId));
      if (topIndex >= 0 && topIndex < readerState.paragraphs.length) {
        final para = readerState.paragraphs[topIndex];
        final visibleParaId = para.paraId;
        final visibleLineId =
            para.lines.isNotEmpty ? para.lines.first.lineId : null;

        ref.read(readerTabsProvider.notifier).updateScrollOffset(
          tabIndex,
          topIndex.toDouble(), // kept for backward compatibility with the
                                // tab-state shape; no longer used to jump.
          paraId: visibleParaId,
          lineId: visibleLineId,
        );

        // Save reading history with debounce when user scrolls
        _scheduleSaveHistory(
            bookId, readerState.bookName, visibleParaId);

        developer.log(
          '[SCROLL] book=$bookId tabIdx=$tabIndex topIndex=$topIndex '
          'paraId=$visibleParaId lineId=$visibleLineId',
          name: 'epitaka.reader',
        );
      }
    }

    // Track visible range for copy operations
    if (visible.isNotEmpty) {
      _visibleStartIndex = visible.first.index;
      _visibleEndIndex = visible.last.index;
    }

    // Always force-expand at the very top of the document.
    if (topIndex == 0 && _appBarCollapsed) {
      setState(() => _appBarCollapsed = false);
      _scrollAccum[bookId] = 0;
    }
  }

  // ── Unified precise jump-by-paraId (and optional lineId) ─────────────
  //
  // This is the single entry point for TOC jumps, TTS auto-scroll, search
  // result jumps, tab-restore, and bookmark restore. It resolves paraId ->
  // index against the currently loaded paragraphs; if the paragraph isn't
  // loaded yet it waits for the data provider. If a lineId is provided, it
  // adjusts the alignment to show the first lines of the paragraph.
  Future<void> _jumpToParagraph(
    String bookId,
    int paraId, {
    bool animate = true,
    double alignment = 0.0,
    int? lineId,
  }) async {
    _pendingJumpParaId[bookId] = paraId;

    var state = ref.read(readerDataProvider(bookId));
    var index = state.paragraphs.indexWhere((p) => p.paraId == paraId);

    if (index < 0) {
      if (!state.isLoaded) {
        // Data is still loading — wait for it.
        developer.log(
          '[JUMP] book=$bookId paraId=$paraId data still loading, waiting…',
          name: 'epitaka.reader',
        );
        await ref
            .read(readerDataProvider(bookId).notifier)
            .waitUntilLoaded();
        if (!mounted) return;

        // If a newer jump request came in while we were loading, bail out
        // and let that one win.
        if (_pendingJumpParaId[bookId] != paraId) return;

        state = ref.read(readerDataProvider(bookId));
        index = state.paragraphs.indexWhere((p) => p.paraId == paraId);
      }
      if (index < 0) {
        developer.log(
          '[JUMP] book=$bookId paraId=$paraId not found (total=${state.paragraphs.length})',
          name: 'epitaka.reader',
        );
        return;
      }
    }

    final controller = _itemScrollControllers[bookId];
    if (controller == null || !controller.isAttached) {
      // Not laid out yet (e.g. tab just became active this frame) —
      // retry next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _jumpToParagraph(bookId, paraId, animate: animate, alignment: alignment, lineId: lineId);
      });
      return;
    }

    developer.log(
      '[JUMP] book=$bookId paraId=$paraId index=$index '
      'lineId=$lineId animate=$animate',
      name: 'epitaka.reader',
    );

    _lastJumpedParaId[bookId] = paraId;

    // When a specific lineId is requested, use a small alignment offset
    // to push the paragraph slightly down, making the first few lines
    // visible rather than scrunched at the very top edge.
    final effectiveAlignment = (lineId != null && alignment == 0.0)
        ? 0.15
        : alignment;

    if (animate) {
      await controller.scrollTo(
        index: index,
        alignment: effectiveAlignment,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      controller.jumpTo(index: index, alignment: effectiveAlignment);
    }

    // Clear initialParaId / initialLineId and remove from _lastJumpedParaId
    // so we can re-jump to the same paragraph/heading/search result if
    // requested again.
    final tabsNotifier = ref.read(readerTabsProvider.notifier);
    final tabsState = ref.read(readerTabsProvider);
    final tabIndex = tabsState.tabs.indexWhere((t) => t.bookId == bookId);
    if (tabIndex >= 0) {
      tabsNotifier.clearInitialParaId(tabIndex);
    }
    _lastJumpedParaId.remove(bookId);
  }

  // ── Swipe between tabs ───────────────────────────────────────────────
  void _onHorizontalSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 300) return;

    final state = ref.read(readerTabsProvider);
    if (state.tabs.length <= 1) return;

    if (velocity < 0) {
      if (state.activeIndex < state.tabs.length - 1) {
        ref.read(readerTabsProvider.notifier).switchTo(state.activeIndex + 1);
      }
    } else {
      if (state.activeIndex > 0) {
        ref.read(readerTabsProvider.notifier).switchTo(state.activeIndex - 1);
      }
    }
  }

  // ── Bookmark ─────────────────────────────────────────────────────────
  void _onBookmarkTap(ReaderTabInfo activeTab, ReaderDataState readerState) {
    final pageNumber = readerState.paragraphs.isNotEmpty &&
            readerState.paragraphs.first.pageNumber != null
        ? readerState.paragraphs.first.pageNumber
        : null;
    showBookmarkDialog(
      context,
      bookId: activeTab.bookId,
      bookName: readerState.bookName ?? activeTab.bookId,
      pageNumber: pageNumber,
    );
  }

  // ── Reading History ──────────────────────────────────────────────────
  Future<void> _saveReadingHistory(
    String bookId,
    String? bookName, {
    int? explicitParaId,
    int? explicitLineId,
  }) async {
    try {
      final db = await ref.read(appDbProvider.future);
      final tabsState = ref.read(readerTabsProvider);
      final tab = tabsState.tabs.firstWhere((t) => t.bookId == bookId);
      await db.recordReading(
        bookId: bookId,
        bookName: bookName,
        paraId: explicitParaId ?? tab.currentParaId,
        lineId: explicitLineId ?? tab.currentLineId,
      );
      // Invalidate the history provider so the library screen refreshes
      ref.invalidate(historyProvider);
    } catch (_) {
      // Silently fail — history is non-critical
    }
  }

  /// Debounced history save triggered by scrolling. Only saves when
  /// [paraId] changes for this book, then waits 3s of inactivity
  /// before writing to the database.
  void _scheduleSaveHistory(String bookId, String? bookName, int paraId) {
    if (_lastSavedParaIdPerBook[bookId] == paraId) return;
    _lastSavedParaIdPerBook[bookId] = paraId;

    _saveHistoryTimer?.cancel();
    _saveHistoryTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _saveReadingHistory(bookId, bookName);
    });
  }

  // ── Word lookup ──────────────────────────────────────────────────────
  void _onWordLookup(String word) {
    if (word.trim().isEmpty) return;
    showDictionarySheet(context, word.trim());
  }

  void _handleSelectionChanged(SelectedContent? selection) {
    // debugPrint(
    //   '[CopyDebug] onSelectionChanged fired: null=${selection == null}, '
    //   'plainText.length=${selection?.plainText.length}, '
    //   'plainText="${selection?.plainText}"',
    // );
    _lastSelectedContent = selection;
    if (_awaitingSelection &&
        selection != null &&
        selection.plainText.isNotEmpty) {
      _awaitingSelection = false;
      _fallbackTimer?.cancel();
      _onWordLookup(_cleanPali(selection.plainText));
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final delta = now - _lastTapTime;

    if (delta < 500) {
      _awaitingSelection = true;
      _fallbackTimer?.cancel();
      _fallbackTimer = Timer(const Duration(milliseconds: 400), () {
        if (_awaitingSelection && mounted) {
          _awaitingSelection = false;
        }
      });
    }
    _lastTapTime = now;
  }

  String _cleanPali(String text) {
    return text
        .replaceAll(RegExp(r'[^\wāīūōṅñṭḍṇḷṃĀĪŪŌṄÑṬḌṆḶṀ\s]'), '')
        .trim();
  }

/// Characters unique to Pali romanization (diacritics). Kept in sync
  /// with the set used in _cleanPali, plus ṁ (alt. niggahita).
  static const String _paliDiacritics =
      r'āīūōṅñṭḍṇḷṃṁĀĪŪŌṄÑṬḌṆḶṀ';

  /// Strip HTML for TTS:
  /// - <i>...</i> is removed ENTIRELY (tag + inner text), since it wraps
  ///   retained Pali terms that shouldn't be spoken by the translation voice.
  /// - Any (...) whose contents include a Pali diacritic is removed
  ///   ENTIRELY (parens + inner text) for the same reason.
  /// - Any other HTML tags are stripped, keeping their inner text.
  /// - Leftover whitespace is collapsed.
  String _stripHtmlForTts(String text) {
    return text
        .replaceAll(RegExp(r'<i>.*?</i>', caseSensitive: false, dotAll: true), '')
        .replaceAll(
            RegExp(r'\([^()]*[' + _paliDiacritics + r'][^()]*\)'), '')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // ── Copy with style ──────────────────────────────────────────────────
  //
  // Builds a custom context menu that replaces the default "Copy" with
  // a rich-text (HTML) clipboard write via super_clipboard, plus scope
  // options (Pāli only, Translation only) and quote/citation support.

  Widget _buildCopyContextMenu(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    final anchors = selectableRegionState.contextMenuAnchors;
    final colors = Theme.of(context).colorScheme;

    return AdaptiveTextSelectionToolbar(
      anchors: anchors,
      children: [          _ContextMenuButton(
            icon: Icons.copy_all,
            label: 'Copy with Style',
            onTap: () {
              _copySelectedContent(CopyScope.both, addQuote: false);
              selectableRegionState.clearSelection();
            },
            colors: colors,
          ),
          _ContextMenuButton(
            icon: Icons.text_fields,
            label: 'Pāli Only',
            onTap: () {
              _copySelectedContent(CopyScope.pali, addQuote: false);
              selectableRegionState.clearSelection();
            },
            colors: colors,
          ),
          _ContextMenuButton(
            icon: Icons.translate,
            label: 'Translation Only',
            onTap: () {
              _copySelectedContent(CopyScope.translation, addQuote: false);
              selectableRegionState.clearSelection();
            },
            colors: colors,
          ),
          _ContextMenuButton(
            icon: Icons.format_quote,
            label: 'Copy with Quote',
            onTap: () {
              _copySelectedContent(CopyScope.both, addQuote: true);
              selectableRegionState.clearSelection();
            },
            colors: colors,
          ),
        _ContextMenuButton(
          icon: Icons.select_all,
          label: 'Select All',
          onTap: () => selectableRegionState.selectAll(),
          colors: colors,
        ),
      ],
    );
  }

  /// Intercept Ctrl+C / Cmd+C and write rich HTML alongside the default
  /// plain-text copy.
  void _onCopyShortcut() {
    _copySelectedContent(CopyScope.both, addQuote: false);
  }

  /// Copy the **selected** content as rich HTML (uses cached selection from
  /// [onSelectionChanged]). Falls back to visible paragraphs when no text
  /// is selected.
  Future<void> _copySelectedContent(
    CopyScope scope, {
    required bool addQuote,
  }) async {
    final activeTab = ref.read(readerTabsProvider).activeTab;
    if (activeTab == null) return;

    final readerState = ref.read(readerDataProvider(activeTab.bookId));
    if (readerState.paragraphs.isEmpty) return;

    // Use the cached selection from onSelectionChanged
    final selectedContent = _lastSelectedContent;
    // debugPrint(
    //   '[CopyDebug] _lastSelectedContent == null: ${selectedContent == null}, '
    //   'plainText.length: ${selectedContent?.plainText.length}, '
    //   'plainText: "${selectedContent?.plainText}"',
    // );
    if (selectedContent == null || selectedContent.plainText.trim().isEmpty) {
      // Fallback: copy visible paragraphs
      // debugPrint('[CopyDebug] No selection -> falling back to _copyVisibleContent');
      await _copyVisibleContent(scope, addQuote: addQuote);
      return;
    }

    // Map the selected text to paragraphs
    final selectedParagraphs = _findSelectedParagraphs(
      selectedContent.plainText,
      readerState.paragraphs,
      enabledLangCodes: scope == CopyScope.translation
          ? null // Use all langs when copying translation only
          : ref.read(settingsProvider).enabledTranslations.isNotEmpty
              ? ref.read(settingsProvider).enabledTranslations
              : (ref.read(settingsProvider).showTranslation
                  ? {ref.read(settingsProvider).primaryTranslationLang}
                  : null as Set<String>?),
    );

    // debugPrint(
    //   '[CopyDebug] _findSelectedParagraphs returned ${selectedParagraphs.length} paragraph(s), '
    //   'total lines: ${selectedParagraphs.fold<int>(0, (sum, p) => sum + p.lines.length)}',
    // );

    if (selectedParagraphs.isEmpty) {
      // Fallback: copy visible content
      // debugPrint('[CopyDebug] selectedParagraphs empty -> falling back to _copyVisibleContent');
      await _copyVisibleContent(scope, addQuote: addQuote);
      return;
    }

    // Copy the selected paragraphs as rich HTML
    final settings = ref.read(settingsProvider);
    final quoteFormat = addQuote ? settings.copyQuoteFormat : CopyQuoteFormat.none;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paliColor = isDark
        ? settings.paliColor.withValues(alpha: 0.9)
        : settings.paliColor;
    final transColor = isDark
        ? settings.translationColor.withValues(alpha: 0.85)
        : settings.translationColor;
    final pageSystemLabel = _pageSystemLabel(settings.pageNumberingSystem);
    final enabledLangs = settings.enabledTranslations.isNotEmpty
        ? settings.enabledTranslations.toList()
        : (settings.showTranslation
            ? [settings.primaryTranslationLang]
            : <String>[]);

    await ReadingClipboard.copy(
      selectedParagraphs,
      scope: scope,
      quoteFormat: quoteFormat,
      bookId: activeTab.bookId,
      bookName: readerState.bookName,
      htmlColor: transColor,
      paliCssColor: paliColor,
      pageNumberingSystem: pageSystemLabel,
      enabledLangCodes: enabledLangs.isNotEmpty ? enabledLangs.toSet() : null,
    );
  }

  /// Find which *lines* fall inside the selected text by matching the plain
  /// text of each line (not each whole paragraph) against the selection,
  /// then rebuilds only those matching lines into minimal ParagraphData
  /// objects — so an in-paragraph selection doesn't pull in sibling lines
  /// (other translations, other verses) that weren't actually highlighted.
  List<ParagraphData> _findSelectedParagraphs(
    String selectedText,
    List<ParagraphData> allParagraphs, {
    Set<String>? enabledLangCodes,
  }) {
    if (selectedText.isEmpty || allParagraphs.isEmpty) return [];

    final normSelected = _stripTags(selectedText).toLowerCase().trim();
    if (normSelected.isEmpty) return [];

    // Build concatenated plain text with one offset range per LINE (not
    // per paragraph), so overlap can be resolved at line granularity.
    final buffer = StringBuffer();
    final lineParaIndex = <int>[];
    final lineIndexInPara = <int>[];
    final lineStart = <int>[];
    final lineEnd = <int>[];

    for (int pi = 0; pi < allParagraphs.length; pi++) {
      final para = allParagraphs[pi];

      // Mirror ReadingParagraph's render order (heading, then page badge,
      // then lines) so the buffer matches what the user actually selected
      // on screen. This text is NOT added to lineStart/lineEnd, so it can
      // never itself be "matched" as a line — it just keeps offsets correct.
      if (para.heading != null) {
        buffer.writeln(_stripTags(para.heading!.title));
      }
      if (para.isPageStart && para.pageNumber != null) {
        buffer.writeln('p. ${para.pageNumber}');
      }

      for (int li = 0; li < para.lines.length; li++) {
        final line = para.lines[li];
        final start = buffer.length;
        if (line.paliText != null) {
          buffer.writeln(_stripTags(line.paliText!));
        }
        for (final entry in line.translations.entries) {
          if (enabledLangCodes != null && !enabledLangCodes.contains(entry.key)) continue;
          buffer.writeln(_stripTags(entry.value));
        }
        final end = buffer.length;
        if (end > start) {
          lineParaIndex.add(pi);
          lineIndexInPara.add(li);
          lineStart.add(start);
          lineEnd.add(end);
        }
      }
    }

    final fullText = buffer.toString().toLowerCase();

    // Match on a WHITESPACE-STRIPPED version of both strings. Flutter's
    // SelectedContent.plainText joins lines/spans with whatever separator
    // (or none) the render objects happen to produce, which will never
    // reliably match the \n we insert via writeln() above. Stripping all
    // whitespace from both sides before matching makes this robust to any
    // such separator differences, while collapsedToOrig lets us translate
    // the match position back to real offsets in fullText for the line
    // overlap check below.
    final collapsedBuffer = StringBuffer();
    final collapsedToOrig = <int>[];
    for (int idx = 0; idx < fullText.length; idx++) {
      final ch = fullText[idx];
      if (ch.trim().isEmpty) continue; // skip whitespace (space, \n, etc.)
      collapsedBuffer.write(ch);
      collapsedToOrig.add(idx);
    }
    final collapsedFullText = collapsedBuffer.toString();
    final collapsedSelected = normSelected.replaceAll(RegExp(r'\s+'), '');

    // debugPrint(
    //   '[CopyDebug] collapsedFullText.length: ${collapsedFullText.length}, '
    //   'collapsedSelected.length: ${collapsedSelected.length}',
    // );

    if (collapsedSelected.isEmpty) return [];

    int cStart = collapsedFullText.indexOf(collapsedSelected);
    int cMatchLen = collapsedSelected.length;
    if (cStart < 0) {
      // Exact match failed even whitespace-stripped (e.g. selection spans
      // a disabled/hidden language, or tag-stripping differs slightly) —
      // fall back to a prefix match within the SAME collapsed space so we
      // still narrow to the right neighbourhood instead of grabbing
      // everything.
      final prefixLen = collapsedSelected.length.clamp(0, 100);
      final prefix = collapsedSelected.substring(0, prefixLen);
      cStart = collapsedFullText.indexOf(prefix);
      // debugPrint(
      //   '[CopyDebug] Collapsed exact match FAILED. Falling back to prefix match. '
      //   'prefixLen: $prefixLen, prefix found at: $cStart',
      // );
      if (cStart < 0) {
        // debugPrint('[CopyDebug] Prefix match also failed -> returning empty');
        return [];
      }
      cMatchLen = prefixLen;
    }
    final cEnd = (cStart + cMatchLen).clamp(0, collapsedToOrig.length);
    if (cEnd <= cStart || collapsedToOrig.isEmpty) return [];

    // Translate collapsed-space [cStart, cEnd) back into real offsets in
    // fullText so we can reuse the line boundaries computed above.
    final selStart = collapsedToOrig[cStart];
    final selEnd = collapsedToOrig[(cEnd - 1).clamp(0, collapsedToOrig.length - 1)] + 1;
    // debugPrint('[CopyDebug] selStart: $selStart, selEnd: $selEnd (fullText.length: ${fullText.length})');

    // Which lines overlap the selection range.
    final matches = <int>[]; // indices into the line* arrays, in order
    for (int i = 0; i < lineStart.length; i++) {
      if (selStart < lineEnd[i] && selEnd > lineStart[i]) {
        matches.add(i);
      }
    }
    // debugPrint(
    //   '[CopyDebug] matched line count: ${matches.length} '
    //   '(paragraphs touched: ${matches.map((i) => lineParaIndex[i]).toSet().length})',
    // );
    if (matches.isEmpty) return [];

    // Re-group matched lines back into paragraphs, keeping only the
    // matched lines within each paragraph (not the whole paragraph).
    final result = <ParagraphData>[];
    final resultParaIndices = <int>[];
    int i = 0;
    while (i < matches.length) {
      final pi = lineParaIndex[matches[i]];
      final keptLineIndices = <int>[];
      while (i < matches.length && lineParaIndex[matches[i]] == pi) {
        keptLineIndices.add(lineIndexInPara[matches[i]]);
        i++;
      }
      final original = allParagraphs[pi];
      final trimmedLines = keptLineIndices.map((li) => original.lines[li]).toList();
      result.add(original.copyWith(
        lines: trimmedLines,
        isPageStart: false, // don't render a page badge in copied/pasted content
      ));
      resultParaIndices.add(pi);
    }

    // debugPrint(
    //   '[CopyDebug] Final result: ${result.length} paragraph(s), '
    //   'source paragraph indices: $resultParaIndices',
    // );

    return result;
  }

  /// Strips HTML tags from a string (for text matching).
  String _stripTags(String s) =>
      s.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Copy the currently visible paragraphs (plus context) to clipboard as
  /// rich HTML via [ReadingClipboard.copy]. Used as a fallback when no
  /// selection exists.
  Future<void> _copyVisibleContent(CopyScope scope, {required bool addQuote}) async {
    final activeTab = ref.read(readerTabsProvider).activeTab;
    if (activeTab == null) return;

    final readerState = ref.read(readerDataProvider(activeTab.bookId));
    if (readerState.paragraphs.isEmpty) return;

    final settings = ref.read(settingsProvider);

    // Determine paragraph range: visible area + 5 above + 5 below
    final bufferBefore = 5;
    final bufferAfter = 5;
    final start = (_visibleStartIndex - bufferBefore).clamp(0, readerState.paragraphs.length - 1);
    final end = (_visibleEndIndex + bufferAfter).clamp(0, readerState.paragraphs.length - 1);
    final paragraphs = readerState.paragraphs.sublist(start, end + 1);

    final quoteFormat = addQuote ? settings.copyQuoteFormat : CopyQuoteFormat.none;
    final effectiveScope = scope;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paliColor = isDark
        ? settings.paliColor.withValues(alpha: 0.9)
        : settings.paliColor;
    final transColor = isDark
        ? settings.translationColor.withValues(alpha: 0.85)
        : settings.translationColor;

    final pageSystemLabel = _pageSystemLabel(settings.pageNumberingSystem);

    final enabledLangs = settings.enabledTranslations.isNotEmpty
        ? settings.enabledTranslations.toList()
        : (settings.showTranslation
            ? [settings.primaryTranslationLang]
            : <String>[]);

    await ReadingClipboard.copy(
      paragraphs,
      scope: effectiveScope,
      quoteFormat: quoteFormat,
      bookId: activeTab.bookId,
      bookName: readerState.bookName,
      htmlColor: transColor,
      paliCssColor: paliColor,
      pageNumberingSystem: pageSystemLabel,
      enabledLangCodes: enabledLangs.isNotEmpty ? enabledLangs.toSet() : null,
    );
  }

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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fallbackTimer?.cancel();
    _saveHistoryTimer?.cancel();
    for (final entry in _itemPositionsListeners.entries) {
      final listener = _positionsListenerRefs[entry.key];
      if (listener != null) {
        entry.value.itemPositions.removeListener(listener);
      }
    }
    for (final sub in _scrollOffsetSubs.values) {
      sub.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabsState = ref.watch(readerTabsProvider);

    if (tabsState.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pop();
      });
      return const SizedBox.shrink();
    }

    final activeTab = tabsState.activeTab!;
    final readerState = ref.watch(readerDataProvider(activeTab.bookId));
    final settings = ref.watch(settingsProvider);
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Resolve Pali color
    final resolvedPaliColor = isDark
        ? settings.paliColor.withValues(alpha: 0.9)
        : settings.paliColor;
    final resolvedTransColor = isDark
        ? settings.translationColor.withValues(alpha: 0.85)
        : settings.translationColor;

    // Determine which translations to show.
    final enabledLangs = settings.enabledTranslations.isNotEmpty
        ? settings.enabledTranslations.toList()
        : (settings.showTranslation
            ? [settings.primaryTranslationLang]
            : <String>[]);

    // Build per-language typography map
    final langTypographies = <String, LanguageTypography>{};
    for (final langCode in enabledLangs) {
      langTypographies[langCode] =
          settings.typography.typographyFor(langCode);
    }

    // ── Resolve which paragraph (if any) we should jump to this build ──
    //
    // Priority: an explicit TOC/search/bookmark jump (initialParaId, changed
    // since last time) > a tab-restore target (currentParaId) the first time
    // this book becomes active. Both go through the same precise
    // _jumpToParagraph path — no pixel estimation, no GlobalKey retries.
    // If a matching initialLineId is set, the method will also scroll to the
    // specific line within the paragraph.
    final isNewInitialParaId = activeTab.initialParaId != null &&
        _lastJumpedParaId[activeTab.bookId] != activeTab.initialParaId;
    final isTabRestore = !isNewInitialParaId &&
        activeTab.currentParaId != null &&
        _lastRestoredBookId != activeTab.bookId;

    if (isNewInitialParaId) {
      final targetParaId = activeTab.initialParaId!;
      final targetLineId = activeTab.initialLineId;
      _lastJumpedParaId[activeTab.bookId] = targetParaId;
      _lastRestoredBookId = activeTab.bookId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _jumpToParagraph(
          activeTab.bookId,
          targetParaId,
          lineId: targetLineId,
        );
      });
    } else if (isTabRestore) {
      _lastRestoredBookId = activeTab.bookId;
      final targetParaId = activeTab.currentParaId!;
      final targetLineId = activeTab.currentLineId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _jumpToParagraph(
          activeTab.bookId,
          targetParaId,
          animate: false,
          lineId: targetLineId,
        );
      });
    }

    final ttsReadingState = ref.watch(ttsReadingProvider);
    final globalTtsState = ref.watch(ttsProvider);
    final isCurrentBookTts = ttsReadingState.bookId == activeTab.bookId;
    final ttsPlaybackStateForTab = isCurrentBookTts
        ? globalTtsState
        : TtsPlaybackState.stopped;

    // Don't pass highlight ID when in background to reduce UI churn
    // Also, only highlight if the TTS reading state is for the active tab's book!
    final ttsCurrentLineId = _appLifecycleState == AppLifecycleState.resumed && isCurrentBookTts
        ? ttsReadingState.currentLineId
        : null;
    final ttsCurrentParaId = _appLifecycleState == AppLifecycleState.resumed && isCurrentBookTts
        ? ttsReadingState.currentParaId
        : null;

    // Save reading history when a new book tab becomes active
    // (fires both on first open and when switching between tabs)
    ref.listen(readerTabsProvider, (ReaderTabsState? prev, ReaderTabsState next) {
      if (next.activeTab?.bookId != prev?.activeTab?.bookId) {
        final tab = next.activeTab;
        if (tab != null && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _saveReadingHistory(tab.bookId, tab.bookName);
            }
          });
        }
      }
    });

    // Auto-scroll when TTS moves to a new paragraph — same precise
    // paraId-based jump used everywhere else.
    ref.listen(ttsReadingProvider, (TtsReadingState? prev, TtsReadingState next) {
      final prevParaId = prev?.currentParaId;
      final nextParaId = next.currentParaId;
      if (!mounted || nextParaId == null || prevParaId == nextParaId) return;
      if (_appLifecycleState != AppLifecycleState.resumed) return;
      final currentBookId = ref.read(readerTabsProvider).activeTab?.bookId;
      if (currentBookId == null || next.bookId != currentBookId) return;
      // Save reading history immediately when TTS moves to a new paragraph
      final bookName = ref.read(readerDataProvider(currentBookId)).bookName;
      _saveReadingHistory(currentBookId, bookName,
          explicitParaId: nextParaId, explicitLineId: next.currentLineId);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Keep the TTS-highlighted paragraph a little below the top edge
        // rather than jammed against it.
        _jumpToParagraph(currentBookId, nextParaId, alignment: 0.1);
      });
    });

    // Read topPadding BEFORE the Scaffold because Scaffold removes
    // MediaQuery.padding.top from the body context when appBar is non-null.
    // When the appBar is collapsed (preferredSize.height == 0), the Scaffold
    // still removes that inset from the body MediaQuery but positions the body
    // at y=0 — so we must push the body down manually.
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isPhone = Mobile.isPhone(context);
    final showCollapsed = isPhone && _appBarCollapsed;

    return Scaffold(
      appBar: _ReaderAppBar(
        bookId: activeTab.bookId,
        bookName: readerState.bookName ?? activeTab.bookId,
        colors: colors,
        showCollapsed: showCollapsed,
        onSettingsTap: () => context.push('/settings'),
      ),
      body: Padding(
        padding: EdgeInsets.only(
          // When collapsed, appBar height == 0 but body is positioned at y=0
          // (behind the status bar).  Push it down manually so TabStrip is
          // always below the clock bar.
          top: showCollapsed ? topPadding : 0,
          bottom: bottomPadding,
        ),
        child: Column(
          children: [
            const TabStrip(),
            Expanded(
              child: GestureDetector(
                onHorizontalDragEnd: _onHorizontalSwipe,
                child: Stack(
                  children: [
                    Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: _handlePointerDown,
                      child: CallbackShortcuts(
                        bindings: {
                          SingleActivator(LogicalKeyboardKey.keyC, control: true): _onCopyShortcut,
                          SingleActivator(LogicalKeyboardKey.keyC, meta: true): _onCopyShortcut,
                        },
                        child: Focus(
                          autofocus: true,
                          child: SelectionArea(
                            key: _selectionAreaKey,
                            onSelectionChanged: _handleSelectionChanged,
                            contextMenuBuilder: _buildCopyContextMenu,
                            child: _buildReaderContent(
                              context,
                              readerState,
                              settings,
                              colors,
                              activeTab,
                              resolvedPaliColor,
                              resolvedTransColor,
                              enabledLangs,
                              langTypographies,
                              ttsHighlightLineId: ttsCurrentLineId,
                              ttsHighlightParaId: ttsCurrentParaId,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Draggable scroll thumb on the right edge
                    Positioned(
                      right: 2,
                      top: 0,
                      bottom: 0,
                      width: 28,
                      child: readerState.isLoaded && readerState.paragraphs.isNotEmpty
                          ? _ReaderDragThumb(
                              readerState: readerState,
                              itemScrollController:
                                  _itemScrollControllers[activeTab.bookId],
                              itemPositionsListener:
                                  _itemPositionsListeners[activeTab.bookId],
                            )
                          : const SizedBox.shrink(),
                    ),
                    // Floating bottom toolbar
                    Positioned(
                      bottom: 24,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _ReaderBottomToolbar(
                          colors: colors,
                          displayMode: settings.translationDisplayMode,
                          showTranslation: settings.showTranslation,
                          ttsPlayback: ttsPlaybackStateForTab,
                          onToggleTranslation: () {
                            if (!settings.showTranslation) {
                              ref
                                  .read(settingsProvider.notifier)
                                  .setShowTranslation(true);
                              ref
                                  .read(settingsProvider.notifier)
                                  .setTranslationDisplayMode(
                                      TranslationDisplayMode.lineByLine);
                            } else {
                              ref
                                  .read(settingsProvider.notifier)
                                  .setShowTranslation(false);
                            }
                          },
                          onCycleDisplayMode: () {
                            final newMode = settings.translationDisplayMode ==
                                    TranslationDisplayMode.lineByLine
                                ? TranslationDisplayMode.sideBySide
                                : TranslationDisplayMode.lineByLine;
                            ref
                                .read(settingsProvider.notifier)
                                .setTranslationDisplayMode(newMode);
                          },
                          onContentsTap: () {
                            final currentParaId = activeTab.currentParaId;
                            var url = '/contents/${activeTab.bookId}?bookName=${Uri.encodeComponent(readerState.bookName ?? activeTab.bookId)}';
                            if (currentParaId != null) {
                              url += '&currentParaId=$currentParaId';
                            }
                            context.push(url);
                          },
                          onDictionaryTap: () {
                            showDictionarySheet(context, '');
                          },
                          onListenTap: () {
                            // Find the first visible paragraph precisely
                            // via the positions listener instead of
                            // guessing from a pixel offset.
                            final positions = _itemPositionsListeners[
                                    activeTab.bookId]
                                ?.itemPositions
                                .value;
                            int startParaIndex = 0;
                            if (positions != null && positions.isNotEmpty) {
                              final visible = positions
                                  .where((p) => p.itemTrailingEdge > 0)
                                  .toList()
                                ..sort((a, b) => a.itemLeadingEdge
                                    .compareTo(b.itemLeadingEdge));
                              if (visible.isNotEmpty) {
                                startParaIndex = visible.first.index.clamp(
                                    0,
                                    readerState.paragraphs.isEmpty
                                        ? 0
                                        : readerState.paragraphs.length - 1) as int;
                              }
                            }

                            // Build line items from visible position onwards.
                            // Include ALL lines (not just translated ones)
                            // so lineId indices match the rendered list.
                            // Empty-text lines are skipped during speaking.
                            final lines = <TtsLineItem>[];
                            final lang =
                                enabledLangs.isNotEmpty ? enabledLangs.first : null;
                            if (lang == null) return;
                            
                            for (int i = startParaIndex;
                                i < readerState.paragraphs.length &&
                                    lines.length < 200;
                                i++) {
                              final para = readerState.paragraphs[i];
                              for (final line in para.lines) {
                                final rawText = line.translations[lang] ?? '';
                                final text = _stripHtmlForTts(rawText);
                                if (lines.length < 200) {
                                  lines.add(TtsLineItem(
                                    paraId: para.paraId,
                                    lineId: line.lineId,
                                    text: text,
                                  ));
                                }
                              }
                            }

                            if (lines.isNotEmpty) {
                              ref
                                  .read(ttsReadingProvider.notifier)
                                  .startReading(activeTab.bookId, lines);
                            }
                          },
                          onStopTap: () {
                            // stopReading already calls ttsProvider.notifier.stop()
                            ref.read(ttsReadingProvider.notifier).stopReading();
                          },
                          onBookmarkTap: () => _onBookmarkTap(activeTab, readerState),
                        ),
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

  Widget _buildReaderContent(
    BuildContext context,
    ReaderDataState data,
    AppSettings settings,
    ColorScheme colors,
    ReaderTabInfo activeTab,
    Color paliColor,
    Color translationColor,
    List<String> enabledLangs,
    Map<String, LanguageTypography> langTypographies,
    {int? ttsHighlightLineId, int? ttsHighlightParaId,}
  ) {
    if (data.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (data.error != null) {
      return Center(child: Text('Error loading text: ${data.error}'));
    }

    if (data.paragraphs.isEmpty) {
      return const Center(child: Text('No content found.'));
    }

    // All paragraphs loaded at once — no loading spinner at the bottom

    final displayMode = _toParagraphDisplayMode(
        settings.translationDisplayMode, settings.showTranslation);

    return ScrollablePositionedList.builder(
      key: ValueKey('reader-${activeTab.bookId}'),
      itemScrollController: _scrollControllerFor(activeTab.bookId),
      itemPositionsListener: _positionsListenerFor(activeTab.bookId),
      scrollOffsetListener: _scrollOffsetListenerFor(activeTab.bookId),
      padding: const EdgeInsets.fromLTRB(
        0,
        AppDimensions.lg,
        AppDimensions.marginMobile,
        120,
      ),
      itemCount: data.paragraphs.length,
      itemBuilder: (context, index) {
        final paragraph = data.paragraphs[index];

        return ReadingParagraph(
          key: ValueKey('para-${activeTab.bookId}-${paragraph.paraId}'),
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
          searchQuery: activeTab.searchQuery,
          ttsHighlightLineId: ttsHighlightLineId,
          ttsHighlightParaId: ttsHighlightParaId,
          // Legacy fallbacks
          paliFontSize: settings.typography.pali.fontSize,
          paliLineHeight: settings.typography.pali.lineHeight,
          translationFontSize:
              settings.typography.fontSizeFor(settings.primaryTranslationLang),
          translationLineHeight:
              settings.typography.lineHeightFor(settings.primaryTranslationLang),
        );
      },
    );
  }

  ParagraphDisplayMode _toParagraphDisplayMode(
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
}

// ── Draggable Scroll Thumb ──────────────────────────────────────────────

/// A thin draggable handle on the right edge of the reader that the user can
/// grab and drag to scroll through the book quickly. No scrollbar track is
/// rendered — just the thumb (a small rounded pill).
///
/// Position tracking: the thumb's vertical position follows the first visible
/// item's index as a fraction of the total item count. When dragged, it
/// jumps (or scrolls via [ItemScrollController]) to the corresponding index.
class _ReaderDragThumb extends StatefulWidget {
  final ReaderDataState readerState;
  final ItemScrollController? itemScrollController;
  final ItemPositionsListener? itemPositionsListener;

  const _ReaderDragThumb({
    required this.readerState,
    this.itemScrollController,
    this.itemPositionsListener,
  });

  @override
  State<_ReaderDragThumb> createState() => _ReaderDragThumbState();
}

class _ReaderDragThumbState extends State<_ReaderDragThumb> {
  static const double _thumbHeight = 48.0;
  static const double _thumbWidth = 20.0;

  /// Scroll position ratio 0.0–1.0 computed from ItemPositionsListener.
  double _scrollRatio = 0.0;

  /// Thumb's vertical offset (px from top) during a drag (overrides ratio).
  double? _dragOffset;

  /// Available height for thumb movement (parent height - thumb height).
  double _availableDragHeight = 0;

  @override
  void initState() {
    super.initState();
    widget.itemPositionsListener?.itemPositions.addListener(_onPositionsChanged);
  }

  @override
  void didUpdateWidget(_ReaderDragThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemPositionsListener != widget.itemPositionsListener) {
      oldWidget.itemPositionsListener?.itemPositions
          .removeListener(_onPositionsChanged);
      widget.itemPositionsListener?.itemPositions
          .addListener(_onPositionsChanged);
    }
    if (oldWidget.readerState.paragraphs.length !=
        widget.readerState.paragraphs.length) {
      // Total count changed — recalculate ratio from current position
      final positions = widget.itemPositionsListener?.itemPositions.value;
      if (positions != null) {
        _updateScrollRatio(positions);
      }
    }
  }

  @override
  void dispose() {
    widget.itemPositionsListener?.itemPositions
        .removeListener(_onPositionsChanged);
    super.dispose();
  }

  void _onPositionsChanged() {
    final positions = widget.itemPositionsListener?.itemPositions.value;
    if (positions == null) return;
    _updateScrollRatio(positions);
  }

  void _updateScrollRatio(Iterable<ItemPosition>? positions) {
    if (positions == null || positions.isEmpty) return;

    final visible = positions.where((p) => p.itemTrailingEdge > 0).toList()
      ..sort((a, b) => a.itemLeadingEdge.compareTo(b.itemLeadingEdge));
    if (visible.isEmpty) return;

    final topIndex = visible.first.index;
    final total = widget.readerState.paragraphs.length;
    if (total <= 1) return;

    // Avoid setState if the thumb is being dragged by the user
    if (_dragOffset != null) return;

    setState(() {
      _scrollRatio = topIndex / (total - 1);
    });
  }

  void _onDragStart(DragStartDetails details) {
    setState(() {
      _dragOffset = details.localPosition.dy - _thumbHeight / 2;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_dragOffset == null) return;
    final newOffset = _dragOffset! + details.delta.dy;
    setState(() {
      _dragOffset = newOffset.clamp(0.0, _availableDragHeight);
    });

    // Scroll in real-time while dragging
    final total = widget.readerState.paragraphs.length;
    if (total <= 1) return;
    final ratio = (_dragOffset! / _availableDragHeight).clamp(0.0, 1.0);
    final targetIndex = (ratio * (total - 1)).round();

    widget.itemScrollController?.jumpTo(
      index: targetIndex.clamp(0, total - 1),
      alignment: 0.0,
    );
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() {
      _dragOffset = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        _availableDragHeight =
            (constraints.maxHeight - _thumbHeight).clamp(0.0, double.infinity);

        final total = widget.readerState.paragraphs.length;
        if (total <= 1) return const SizedBox.shrink();

        // Compute thumb position
        final effectiveRatio = _dragOffset != null
            ? (_dragOffset! / _availableDragHeight).clamp(0.0, 1.0)
            : _scrollRatio;
        final top = effectiveRatio * _availableDragHeight;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragStart: _onDragStart,
          onVerticalDragUpdate: _onDragUpdate,
          onVerticalDragEnd: _onDragEnd,
          child: Stack(
            children: [
              // Hit area extension (invisible) for easier grabbing
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(
                    color: Colors.transparent,
                  ),
                ),
              ),
              // The visible thumb
              Positioned(
                top: top,
                left: 0,
                right: 0,
                height: _thumbHeight,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: _thumbWidth,
                    height: _thumbHeight * 0.6,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(
                        alpha: _dragOffset != null ? 0.5 : 0.3,
                      ),
                      borderRadius: BorderRadius.circular(9999),
                      boxShadow: _dragOffset != null
                          ? [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── App Bar ──────────────────────────────────────────────────────────────

/// Reader app bar built on Flutter's [AppBar] for correct safe-area handling.
///
/// On phones the bar animates to zero height when [showCollapsed] is true,
/// keeping it completely out of the clock bar at all times.  On tablets and
/// desktops [showCollapsed] is always false.
class _ReaderAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String bookId;
  final String bookName;
  final ColorScheme colors;
  final bool showCollapsed;
  final VoidCallback onSettingsTap;

  const _ReaderAppBar({
    required this.bookId,
    required this.bookName,
    required this.colors,
    required this.showCollapsed,
    required this.onSettingsTap,
  });

  static const double _toolbarHeight = AppDimensions.appBarHeight;

  @override
  // When collapsed the AppBar still exists (so Scaffold consumes the top
  // inset for the body) but has 0 visible height.  Flutter's AppBar adds
  // the status-bar height automatically on top of toolbarHeight.
  Size get preferredSize => showCollapsed
      ? const Size.fromHeight(0)
      : const Size.fromHeight(_toolbarHeight);

  @override
  Widget build(BuildContext context) {
    if (showCollapsed) {
      // Zero-height transparent bar — keeps Scaffold's body below the
      // status bar (Scaffold removes the top inset from the body whenever
      // appBar is non-null, even at height 0).
      return const SizedBox.shrink();
    }

    return AppBar(
      toolbarHeight: _toolbarHeight,
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: colors.outlineVariant),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        color: colors.onSurfaceVariant,
        onPressed: () => context.pop(),
      ),
      titleSpacing: AppDimensions.sm,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bookName,
            style: AppTypography.headlineSmall.copyWith(
              color: colors.primary,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          Text(
            'Reading',
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          color: colors.onSurfaceVariant,
          onPressed: onSettingsTap,
        ),                        // Bookmark removed from appbar — use toolbar button instead
      ],
    );
  }
}

// ── Bottom Toolbar ───────────────────────────────────────────────────────

class _ReaderBottomToolbar extends StatelessWidget {
  final ColorScheme colors;
  final TranslationDisplayMode displayMode;
  final bool showTranslation;
  final TtsPlaybackState ttsPlayback;
  final VoidCallback onToggleTranslation;
  final VoidCallback onCycleDisplayMode;
  final VoidCallback onContentsTap;
  final VoidCallback onDictionaryTap;
  final VoidCallback onListenTap;
  final VoidCallback onStopTap;
  final VoidCallback onBookmarkTap;

  const _ReaderBottomToolbar({
    required this.colors,
    required this.displayMode,
    required this.showTranslation,
    required this.ttsPlayback,
    required this.onToggleTranslation,
    required this.onCycleDisplayMode,
    required this.onContentsTap,
    required this.onDictionaryTap,
    required this.onListenTap,
    required this.onStopTap,
    required this.onBookmarkTap,
  });

  @override
  Widget build(BuildContext context) {
    IconData displayIcon;
    String displayLabel;
    if (!showTranslation) {
      displayIcon = Icons.translate;
      displayLabel = 'No Trans';
    } else {
      switch (displayMode) {
        case TranslationDisplayMode.lineByLine:
          displayIcon = Icons.view_headline;
          displayLabel = 'Line/L';
        case TranslationDisplayMode.sideBySide:
          displayIcon = Icons.view_column;
          displayLabel = 'Side/S';
        case TranslationDisplayMode.hideJoinLines:
          displayIcon = Icons.translate;
          displayLabel = 'No Trans';
      }
    }

    final isPlaying = ttsPlayback == TtsPlaybackState.playing;
    final isLoading = ttsPlayback == TtsPlaybackState.loading;

    return Container(
      height: 56,
      constraints: const BoxConstraints(maxWidth: 500),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolbarButton(
            icon: Icons.format_list_bulleted,
            label: 'Contents',
            onTap: onContentsTap,
          ),
          const SizedBox(width: 8),
          _ToolbarButton(
            icon: Icons.search,
            label: 'Search',
            onTap: () => showSearchSheet(context),
          ),
          const SizedBox(width: 8),
          _ToolbarButton(
            icon: Icons.menu_book,
            label: 'Dictionary',
            onTap: onDictionaryTap,
          ),
          const SizedBox(width: 8),
          _ToolbarButton(
            icon: displayIcon,
            label: displayLabel,
            onTap: showTranslation ? onCycleDisplayMode : onToggleTranslation,
          ),
          const SizedBox(width: 8),
          _ToolbarButton(
            icon: isPlaying ? Icons.volume_up : (isLoading ? Icons.hourglass_top : Icons.volume_up),
            label: isPlaying ? 'Playing…' : (isLoading ? 'Loading…' : 'Listen'),
            onTap: onListenTap,
          ),
          if (isPlaying) ...[const SizedBox(width: 4),
          _ToolbarButton(
            icon: Icons.stop,
            label: 'Stop',
            onTap: onStopTap,
          ),],
          const SizedBox(width: 2),
          _ToolbarButton(
            icon: Icons.bookmark,
            label: 'Save',
            onTap: onBookmarkTap,
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9999),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: colors.onSurfaceVariant, size: 22),
        ),
      ),
    );
  }
}

// ── Context Menu Button ──────────────────────────────────────────────────

/// Button used inside the custom copy context menu.
class _ContextMenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme colors;

  const _ContextMenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: colors.onSurface),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: colors.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}