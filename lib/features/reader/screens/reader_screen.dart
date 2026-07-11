import 'dart:async';
import 'dart:developer' as developer;

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../core/models/app_models.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/utils/platform_info.dart';
import '../../../core/providers/app_db_provider.dart';
import '../../../core/providers/database_provider.dart';
import '../../../shared/utils/reading_clipboard.dart';
import '../../../shared/widgets/reading_paragraph.dart';
import '../../dictionary/widgets/dictionary_sheet.dart';

import '../../settings/providers/tts_provider.dart';
import '../../settings/providers/tts_replacements_provider.dart';
import '../providers/tts_reading_provider.dart';
import '../providers/reader_provider.dart';
import '../providers/reader_tabs_provider.dart';
import '../widgets/bookmark_dialog.dart';
import '../widgets/jump_sheet.dart';
import '../widgets/reader_app_bar.dart';
import '../widgets/reader_bottom_toolbar.dart';
import '../widgets/reader_context_menu.dart';
import '../widgets/reader_drag_thumb.dart';
import '../widgets/reader_tts_widgets.dart';
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

  // Pixel-based scroll tracking (per book)
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

  /// Throttle: only update scroll state once per distinct paraId per book.
  final Map<String, int> _lastScrollParaId = {};

  /// Whether TTS should auto-scroll to the spoken line.
  /// Set to false when the user manually scrolls away from the TTS position.
  bool _ttsAutoScroll = true;

  /// Flag to prevent _onPositionsChanged from disabling auto-scroll
  /// when a TTS-initiated jump is in progress. Cleared after a short
  /// timer delay to cover layout changes from highlighting.
  bool _ttsJumpInProgress = false;

  /// Timer to clear _ttsJumpInProgress after a short delay.
  Timer? _ttsJumpTimer;

  /// Cached system voices loaded from flutter_tts API.
  List<Map<String, String>>? _cachedSystemVoices;
  bool _voicesLoading = false;

  /// Issue 4: Target line GlobalKey for precise TTS line scroll.
  /// Created before a TTS jump, used by Scrollable.ensureVisible after
  /// the paragraph becomes visible, then cleared.
  final Map<int, GlobalKey> _ttsTargetLineKeys = {};

  /// The paraId that _ttsTargetLineKeys belong to (for passing to
  /// ReadingParagraph).
  int? _ttsTargetParaId;

  // ── In-book search ───────────────────────────────────────────────────

  /// Whether the in-book search bar is visible.
  bool _showInBookSearch = false;

  /// The current in-book search query.
  String _inBookQuery = '';

  /// ParaIds that match the current query (diacritic-insensitive, all terms
  /// in the same line).
  List<int> _inBookMatchParaIds = [];

  /// Corresponding lineIds for each match (same index as [_inBookMatchParaIds]).
  List<int> _inBookMatchLineIds = [];

  /// Index into [_inBookMatchParaIds] / [_inBookMatchLineIds] for the
  /// currently selected match.
  int _inBookMatchIndex = -1;

  /// Text editing controller for the in-book search field.
  final _inBookSearchController = TextEditingController();

  /// Focus node for the in-book search field.
  final _inBookSearchFocusNode = FocusNode();

  /// Get the query currently applied to ReadingParagraph for highlighting.
  String? get _effectiveSearchQuery {
    if (_showInBookSearch && _inBookQuery.isNotEmpty) return _inBookQuery;
    return null;
  }

  /// Debounce timer for in-book search.
  Timer? _inBookSearchTimer;

  /// Most recent in-book search query, used to ignore stale async results.
  String _lastInBookSearchQuery = '';

  /// Run an in-book search on the `sentences` table with a `book_id`
  /// b-tree filter.  Returns `(para_id, line_id)` pairs so the jump can
  /// scroll to the exact matching sentence (not just the paragraph start).
  /// Searches both Pāli text (epitaka.db) and enabled translation texts.
  Future<void> _runInBookSearch(String query) async {
    final activeTab = ref.read(readerTabsProvider).activeTab;
    if (activeTab == null) return;

    _lastInBookSearchQuery = query;

    if (query.trim().isEmpty) {
      setState(() {
        _inBookQuery = '';
        _inBookMatchParaIds = [];
        _inBookMatchLineIds = [];
        _inBookMatchIndex = -1;
      });
      return;
    }

    try {
      final words = query.trim()
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();

      if (words.isEmpty) {
        setState(() {
          _inBookQuery = '';
          _inBookMatchParaIds = [];
          _inBookMatchLineIds = [];
          _inBookMatchIndex = -1;
        });
        return;
      }

      // ── Collect matching (paraId, lineId) pairs ────────────────────
      //
      // Both epitaka.db.sentences and translation*.db.sentences have
      // `book_id`, `para_id`, `line_id` as a composite primary key, so we
      // can SELECT line_id and jump to the exact sentence.

      final seenKeys = <int>{};
      final matchParas = <int>[];
      final matchLines = <int>[];

      void addMatch(int paraId, int lineId) {
        // Encode (paraId, lineId) into a single int for dedup
        final key = paraId * 1000000 + lineId;
        if (seenKeys.add(key)) {
          matchParas.add(paraId);
          matchLines.add(lineId);
        }
      }

      // 1. Search Pāli text from epitaka.db ─────────────────────────────
      final epitakaDb = await ref.read(epitakaDbProvider.future);
      final paliConditions = words
          .map((_) => "pali LIKE '%' || ? || '%'")
          .join(' AND ');

      final paliRows = await epitakaDb.customSelect(
        'SELECT para_id, line_id FROM sentences '
        'WHERE book_id = ? AND $paliConditions '
        'ORDER BY para_id, line_id LIMIT 500',
        variables: [
          Variable.withString(activeTab.bookId),
          for (final w in words) Variable.withString(w),
        ],
      ).get();

      for (final row in paliRows) {
        addMatch(row.data['para_id'] as int, row.data['line_id'] as int);
      }

      // Guard between DB queries
      if (_lastInBookSearchQuery != query) return;

      // 2. Search translation texts from active translation DBs ─────────
      final settings = ref.read(settingsProvider);
      final enabledLangs = settings.enabledTranslations.isNotEmpty
          ? settings.enabledTranslations.toList()
          : (settings.showTranslation
              ? [settings.primaryTranslationLang]
              : <String>[]);

      for (final langCode in enabledLangs) {
        if (_lastInBookSearchQuery != query) return;

        try {
          final lang = TranslationLanguage.fromCode(langCode);
          final transDb =
              await ref.read(translationDbProvider(lang).future);
          if (transDb == null) continue;

          final transConditions = words
              .map((_) => "translation LIKE '%' || ? || '%'")
              .join(' AND ');

          final transRows = await transDb.customSelect(
            'SELECT para_id, line_id FROM sentences '
            'WHERE book_id = ? AND $transConditions '
            'ORDER BY para_id, line_id LIMIT 500',
            variables: [
              Variable.withString(activeTab.bookId),
              for (final w in words) Variable.withString(w),
            ],
          ).get();

          for (final row in transRows) {
            addMatch(row.data['para_id'] as int, row.data['line_id'] as int);
          }
        } catch (_) {
          // Translation db may not exist — skip
        }
      }

      // Guard
      if (_lastInBookSearchQuery != query) return;

      setState(() {
        _inBookQuery = query;
        _inBookMatchParaIds = matchParas;
        _inBookMatchLineIds = matchLines;
        _inBookMatchIndex = matchParas.isEmpty ? -1 : 0;
      });

      if (matchParas.isNotEmpty) {
        _jumpToInBookMatch(0);
      }
    } catch (e) {
      debugPrint('[IN-BOOK SEARCH] Error: $e');
      if (_lastInBookSearchQuery == query) {
        setState(() {
          _inBookQuery = '';
          _inBookMatchParaIds = [];
          _inBookMatchLineIds = [];
          _inBookMatchIndex = -1;
        });
      }
    }
  }

  /// Jump to the [_inBookMatchParaIds] at [index].
  /// `lineId: 1` scrolls the paragraph to the top of the viewport
  /// (alignment 0.0) and fine-scrolls to the first line.
  void _jumpToInBookMatch(int index) {
    final activeTab = ref.read(readerTabsProvider).activeTab;
    if (activeTab == null) return;
    if (index < 0 || index >= _inBookMatchParaIds.length) return;

    setState(() => _inBookMatchIndex = index);
    final lineId = index < _inBookMatchLineIds.length
        ? _inBookMatchLineIds[index]
        : 1;
    _jumpToParagraph(
      activeTab.bookId,
      _inBookMatchParaIds[index],
      animate: true,
      lineId: lineId,
    );
  }

  void _toggleInBookSearch() {
    setState(() {
      _showInBookSearch = !_showInBookSearch;
      if (!_showInBookSearch) {
        _inBookQuery = '';
        _inBookMatchParaIds = [];
        _inBookMatchLineIds = [];
        _inBookMatchIndex = -1;
        _inBookSearchController.clear();
      } else {
        // Focus the search field after it appears
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _inBookSearchFocusNode.requestFocus();
        });
      }
    });
  }



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

  // ── Scroll offset tracking (collapsible app bar) ───────────────────
  //
  // Pixel-accurate scroll direction tracking. Accumulates movement in one
  // direction; flips/resets the accumulator if direction reverses. Once the
  // accumulator crosses _kScrollThreshold px, flips the appbar state once
  // and resets.
  //
  // Fix (Issue 2): Don't collapse the appbar when at the top of the
  // document (topIndex == 0). Check the positions listener before
  // collapsing to avoid flicker.
  void _onScrollOffsetChanged(String bookId, double delta) {
    if (!mounted || delta == 0) return;
    if (ref.read(readerTabsProvider).activeTab?.bookId != bookId) return;
    if (!Mobile.isPhone(context)) return;

    // Issue 2: Check if at top of document before collapsing
    final positions = _itemPositionsListeners[bookId]?.itemPositions.value;
    if (positions != null && positions.isNotEmpty) {
      final visible = positions.where((p) => p.itemTrailingEdge > 0).toList()
        ..sort((a, b) => a.itemLeadingEdge.compareTo(b.itemLeadingEdge));
      if (visible.isNotEmpty && visible.first.index == 0) {
        // At the very top — never collapse
        if (_appBarCollapsed) setState(() => _appBarCollapsed = false);
        _scrollAccum[bookId] = 0;
        return;
      }
    }

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
  // item indices from the layout.
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

        if (_lastScrollParaId[bookId] != visibleParaId) {
          _lastScrollParaId[bookId] = visibleParaId;

          ref.read(readerTabsProvider.notifier).updateScrollOffset(
            tabIndex,
            topIndex.toDouble(),
            paraId: visibleParaId,
            lineId: visibleLineId,
          );

          _scheduleSaveHistory(bookId, readerState.bookName, visibleParaId);

          // Detect manual scroll: if TTS is playing and this scroll
          // was NOT a TTS-initiated jump, disable auto-scroll.
          // _ttsJumpInProgress is kept true by a timer after each
          // TTS jump to cover layout changes from highlighting.
          //
          // Bug fix: Check if the TTS paragraph is ANYWHERE in the
          // visible range, not just whether it's the TOP-MOST visible
          // paragraph. The top-most paragraph can differ from the TTS
          // paragraph after a fine-scroll (Scrollable.ensureVisible)
          // without the user having scrolled at all.
          if (!_ttsJumpInProgress) {
            final ttsState = ref.read(ttsReadingProvider);
            if (ttsState.isActive && ttsState.bookId == bookId) {
              final ttsParaId = ttsState.currentParaId;
              if (ttsParaId != null) {
                // Check if any visible paragraph matches the TTS para
                final ttsIndex = readerState.paragraphs
                    .indexWhere((p) => p.paraId == ttsParaId);
                final isTtsInVisibleRange = ttsIndex >= 0 &&
                    visible.any((p) => p.index == ttsIndex);
                if (!isTtsInVisibleRange) {
                  _ttsAutoScroll = false;
                }
              }
            }
          }
        }
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
  // Issue 4 fix: When a lineId is provided, create a GlobalKey for that
  // line, pass it to ReadingParagraph via lineKeys, and after the
  // paragraph becomes visible, use Scrollable.ensureVisible() to
  // precisely scroll the specific line into view (instead of guessing
  // alignment from line index ratio).
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
        developer.log(
          '[JUMP] book=$bookId paraId=$paraId data still loading, waiting…',
          name: 'epitaka.reader',
        );
        await ref
            .read(readerDataProvider(bookId).notifier)
            .waitUntilLoaded();
        if (!mounted) return;
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

    // Issue 4: Create a GlobalKey for the target line so
    // Scrollable.ensureVisible can precisely scroll it into view.
    // Must call setState so the widget rebuilds with the new lineKeys.
    if (lineId != null) {
      _ttsTargetParaId = paraId;
      _ttsTargetLineKeys[lineId] = GlobalKey();
      if (mounted) setState(() {});
    }

    // Scroll the paragraph into view using the caller's [alignment]
    // value (default 0.0 = top of viewport).
    if (animate) {
      await controller.scrollTo(
        index: index,
        alignment: alignment,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      controller.jumpTo(index: index, alignment: alignment);
    }

    // Issue 4: After the paragraph is visible, fine-scroll to the
    // specific line using Scrollable.ensureVisible on the line's
    // GlobalKey context.
    if (lineId != null && mounted) {
      _scrollToLine(lineId);
    }

    // Clear initialParaId / initialLineId
    final tabsNotifier = ref.read(readerTabsProvider.notifier);
    final tabsState = ref.read(readerTabsProvider);
    final tabIndex = tabsState.tabs.indexWhere((t) => t.bookId == bookId);
    if (tabIndex >= 0) {
      tabsNotifier.clearInitialParaId(tabIndex);
    }
    _pendingJumpParaId.remove(bookId);
  }

  /// Issue 4: After a paragraph has been scrolled into view, fine-scroll
  /// to the specific line using Scrollable.ensureVisible on the line's
  /// GlobalKey context (the precise, non-guess-based way).
  /// Uses a local retry counter in the closure so concurrent retry loops
  /// from rapid TTS advances don't interfere with each other.
  static const int _kMaxTtsScrollRetries = 15;

  void _scrollToLine(int lineId) {
    final key = _ttsTargetLineKeys[lineId];
    if (key == null) return;
    // Capture the GlobalKey instance so a subsequent TTS jump that
    // replaces the map entry doesn't affect this retry loop.
    final capturedKey = key;
    var retries = 0; // local to this call — not shared across calls

    void attemptScroll() {
      if (!mounted) return;
      final lineContext = capturedKey.currentContext;
      if (lineContext != null && lineContext.mounted) {
        developer.log(
          '[TTS_LINE] Scrollable.ensureVisible line=$lineId',
          name: 'epitaka.tts',
        );
        Scrollable.ensureVisible(
          lineContext,
          alignment: 0.3, // show line in upper third of viewport
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        ).then((_) {
          if (mounted) {
            _ttsTargetLineKeys.remove(lineId);
            _ttsTargetParaId = null;
          }
        });
      } else {
        retries++;
        if (retries >= _kMaxTtsScrollRetries) {
          _ttsTargetLineKeys.remove(lineId);
          _ttsTargetParaId = null;
          developer.log(
            '[TTS_LINE] line=$lineId scroll retries exhausted',
            name: 'epitaka.tts',
          );
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) attemptScroll();
        });
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => attemptScroll());
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

  /// Get the current paraId from approximately 1/3 of the screen height.
  /// This uses the item positions listener to find the first paragraph
  /// whose leading edge is >= 0.3 (i.e., about 1/3 from the top).
  int? _getCurrentParaId(String bookId) {
    final listener = _itemPositionsListeners[bookId];
    final positions = listener?.itemPositions.value;
    if (positions == null || positions.isEmpty) return null;

    final visible = positions
        .where((p) => p.itemTrailingEdge > 0)
        .toList()
      ..sort((a, b) => a.itemLeadingEdge.compareTo(b.itemLeadingEdge));

    if (visible.isEmpty) return null;

    // Find the first paragraph with leading edge >= 0.3
    int? targetIndex;
    for (final pos in visible) {
      if (pos.itemLeadingEdge >= 0.3) {
        targetIndex = pos.index;
        break;
      }
    }
    // Fallback to the topmost visible paragraph
    targetIndex ??= visible.first.index;

    final readerState = ref.read(readerDataProvider(bookId));
    if (targetIndex >= 0 && targetIndex < readerState.paragraphs.length) {
      return readerState.paragraphs[targetIndex].paraId;
    }
    return null;
  }

  // ── Jump to connected book / page ─────────────────────────────────────
  Future<void> _onJumpTap(ReaderTabInfo activeTab, ReaderDataState readerState) async {
    final currentParaId = _getCurrentParaId(activeTab.bookId);
    if (currentParaId == null) return;

    if (!context.mounted) return;
    await showJumpSheet(
      context,
      bookId: activeTab.bookId,
      bookName: readerState.bookName ?? activeTab.bookId,
      currentParaId: currentParaId,
    );
  }

  // ── Bookmark (Issue 1: suggest nearby heading) ──────────────────────
  void _onBookmarkTap(ReaderTabInfo activeTab, ReaderDataState readerState) {
    final pageNumber = readerState.paragraphs.isNotEmpty &&
            readerState.paragraphs.first.pageNumber != null
        ? readerState.paragraphs.first.pageNumber
        : null;

    // Issue 1: Find nearby heading to suggest as bookmark name
    final currentParaId = activeTab.currentParaId;
    String? suggestedHeading;
    if (currentParaId != null) {
      final notifier = ref.read(readerDataProvider(activeTab.bookId).notifier);
      final nearby = notifier.findNearbyHeading(currentParaId);
      if (nearby != null) {
        suggestedHeading = nearby.title;
      }
    }

    showBookmarkDialog(
      context,
      bookId: activeTab.bookId,
      bookName: readerState.bookName ?? activeTab.bookId,
      pageNumber: pageNumber,
      suggestedHeading: suggestedHeading,
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
      ref.invalidate(historyProvider);
    } catch (_) {
      // Silently fail — history is non-critical
    }
  }

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

  // ── Copy with style ──────────────────────────────────────────────────

  Widget _buildCopyContextMenu(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    final anchors = selectableRegionState.contextMenuAnchors;
    final colors = Theme.of(context).colorScheme;

    return AdaptiveTextSelectionToolbar(
      anchors: anchors,
      children: [
        ContextMenuButton(
          icon: Icons.copy_all,
          label: 'Copy with Style',
          onTap: () {
            _copySelectedContent(CopyScope.both, addQuote: false);
            selectableRegionState.clearSelection();
          },
          colors: colors,
        ),
        ContextMenuButton(
          icon: Icons.text_fields,
          label: 'Pāli Only',
          onTap: () {
            _copySelectedContent(CopyScope.pali, addQuote: false);
            selectableRegionState.clearSelection();
          },
          colors: colors,
        ),
        ContextMenuButton(
          icon: Icons.translate,
          label: 'Translation Only',
          onTap: () {
            _copySelectedContent(CopyScope.translation, addQuote: false);
            selectableRegionState.clearSelection();
          },
          colors: colors,
        ),
        ContextMenuButton(
          icon: Icons.format_quote,
          label: 'Copy with Quote',
          onTap: () {
            _copySelectedContent(CopyScope.both, addQuote: true);
            selectableRegionState.clearSelection();
          },
          colors: colors,
        ),
        ContextMenuButton(
          icon: Icons.select_all,
          label: 'Select All',
          onTap: () => selectableRegionState.selectAll(),
          colors: colors,
        ),
      ],
    );
  }

  void _onCopyShortcut() {
    _copySelectedContent(CopyScope.both, addQuote: false);
  }

  Future<void> _copySelectedContent(
    CopyScope scope, {
    required bool addQuote,
  }) async {
    final activeTab = ref.read(readerTabsProvider).activeTab;
    if (activeTab == null) return;

    final readerState = ref.read(readerDataProvider(activeTab.bookId));
    if (readerState.paragraphs.isEmpty) return;

    final selectedContent = _lastSelectedContent;
    if (selectedContent == null || selectedContent.plainText.trim().isEmpty) {
      await _copyVisibleContent(scope, addQuote: addQuote);
      return;
    }

    final selectedParagraphs = _findSelectedParagraphs(
      selectedContent.plainText,
      readerState.paragraphs,
      enabledLangCodes: scope == CopyScope.translation
          ? null
          : ref.read(settingsProvider).enabledTranslations.isNotEmpty
              ? ref.read(settingsProvider).enabledTranslations.toSet()
              : (ref.read(settingsProvider).showTranslation
                  ? {ref.read(settingsProvider).primaryTranslationLang}
                  : null as Set<String>?),
    );

    if (selectedParagraphs.isEmpty) {
      await _copyVisibleContent(scope, addQuote: addQuote);
      return;
    }

    final settings = ref.read(settingsProvider);
    final quoteFormat = addQuote ? settings.copyQuoteFormat : CopyQuoteFormat.none;
    final brightness = Theme.of(context).brightness;
    final paliColor = settings.paliColorPair.resolve(brightness);
    final transColor = settings.translationColorPair.resolve(brightness);
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

  List<ParagraphData> _findSelectedParagraphs(
    String selectedText,
    List<ParagraphData> allParagraphs, {
    Set<String>? enabledLangCodes,
  }) {
    if (selectedText.isEmpty || allParagraphs.isEmpty) return [];

    final normSelected = _stripTags(selectedText).toLowerCase().trim();
    if (normSelected.isEmpty) return [];

    final buffer = StringBuffer();
    final lineParaIndex = <int>[];
    final lineIndexInPara = <int>[];
    final lineStart = <int>[];
    final lineEnd = <int>[];

    for (int pi = 0; pi < allParagraphs.length; pi++) {
      final para = allParagraphs[pi];

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

    final collapsedBuffer = StringBuffer();
    final collapsedToOrig = <int>[];
    for (int idx = 0; idx < fullText.length; idx++) {
      final ch = fullText[idx];
      if (ch.trim().isEmpty) continue;
      collapsedBuffer.write(ch);
      collapsedToOrig.add(idx);
    }
    final collapsedFullText = collapsedBuffer.toString();
    final collapsedSelected = normSelected.replaceAll(RegExp(r'\s+'), '');

    if (collapsedSelected.isEmpty) return [];

    int cStart = collapsedFullText.indexOf(collapsedSelected);
    int cMatchLen = collapsedSelected.length;
    if (cStart < 0) {
      final prefixLen = collapsedSelected.length.clamp(0, 100);
      final prefix = collapsedSelected.substring(0, prefixLen);
      cStart = collapsedFullText.indexOf(prefix);
      if (cStart < 0) return [];
      cMatchLen = prefixLen;
    }
    final cEnd = (cStart + cMatchLen).clamp(0, collapsedToOrig.length);
    if (cEnd <= cStart || collapsedToOrig.isEmpty) return [];

    final selStart = collapsedToOrig[cStart];
    final selEnd = collapsedToOrig[(cEnd - 1).clamp(0, collapsedToOrig.length - 1)] + 1;

    final matches = <int>[];
    for (int i = 0; i < lineStart.length; i++) {
      if (selStart < lineEnd[i] && selEnd > lineStart[i]) {
        matches.add(i);
      }
    }
    if (matches.isEmpty) return [];

    final result = <ParagraphData>[];
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
        isPageStart: false,
      ));
    }

    return result;
  }

  String _stripTags(String s) =>
      s.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();

  Future<void> _copyVisibleContent(CopyScope scope, {required bool addQuote}) async {
    final activeTab = ref.read(readerTabsProvider).activeTab;
    if (activeTab == null) return;

    final readerState = ref.read(readerDataProvider(activeTab.bookId));
    if (readerState.paragraphs.isEmpty) return;

    final settings = ref.read(settingsProvider);
    final bufferBefore = 5;
    final bufferAfter = 5;
    final start = (_visibleStartIndex - bufferBefore).clamp(0, readerState.paragraphs.length - 1);
    final end = (_visibleEndIndex + bufferAfter).clamp(0, readerState.paragraphs.length - 1);
    final paragraphs = readerState.paragraphs.sublist(start, end + 1);

    final quoteFormat = addQuote ? settings.copyQuoteFormat : CopyQuoteFormat.none;

    final brightness = Theme.of(context).brightness;
    final paliColor = settings.paliColorPair.resolve(brightness);
    final transColor = settings.translationColorPair.resolve(brightness);

    final pageSystemLabel = _pageSystemLabel(settings.pageNumberingSystem);

    final enabledLangs = settings.enabledTranslations.isNotEmpty
        ? settings.enabledTranslations.toList()
        : (settings.showTranslation
            ? [settings.primaryTranslationLang]
            : <String>[]);

    await ReadingClipboard.copy(
      paragraphs,
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

  // ── TTS Floating Controls ────────────────────────────────────────────

  bool _isTtsLineVisible(String bookId, int? ttsParaId) {
    if (ttsParaId == null) return false;
    final listener = _itemPositionsListeners[bookId];
    final positions = listener?.itemPositions.value;
    if (positions == null || positions.isEmpty) return false;

    final visibleIndices = positions
        .where((p) => p.itemTrailingEdge > 0)
        .map((p) => p.index)
        .toSet();
    if (visibleIndices.isEmpty) return false;

    final readerState = ref.read(readerDataProvider(bookId));
    for (final idx in visibleIndices) {
      if (idx >= 0 && idx < readerState.paragraphs.length) {
        if (readerState.paragraphs[idx].paraId == ttsParaId) return true;
      }
    }
    return false;
  }

  Future<void> _showTtsControlsPopup(
    BuildContext context,
    String bookId,
  ) async {
    final colors = Theme.of(context).colorScheme;
    final settings = ref.read(settingsProvider);
    final ttsReadingState = ref.read(ttsReadingProvider);
    final isTtsLineVisible =
        _isTtsLineVisible(bookId, ttsReadingState.currentParaId);

    if (_cachedSystemVoices == null && !_voicesLoading) {
      _voicesLoading = true;
      try {
        final voices = await ref.read(ttsProvider.notifier).getVoices();
        _cachedSystemVoices = voices;
      } catch (_) {}
      _voicesLoading = false;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Consumer(
            builder: (ctx, watchRef, _) {
              final s = watchRef.watch(settingsProvider);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Spacer(),
                  TtsControlsCard(
                    colors: colors,
                    settings: s,
                    isTtsLineVisible: isTtsLineVisible,
                    onFollowTap: () {
                      Navigator.of(dialogContext).pop();
                      _followTts(bookId);
                    },
                    onSpeedChanged: (v) {
                      ref.read(settingsProvider.notifier).setTtsSpeed(v);
                    },
                    onPitchChanged: (v) {
                      ref.read(settingsProvider.notifier).setTtsPitch(v);
                    },
                    onVoiceChanged: (voice) {
                      ref.read(settingsProvider.notifier).setTtsVoice(voice);
                    },
                    onSystemConfigTap: () {
                      Navigator.of(dialogContext).pop();
                      context.push('/settings/tts');
                    },
                    onClose: () => Navigator.of(dialogContext).pop(),
                    voices: _cachedSystemVoices ?? [],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _followTts(String bookId) {
    _ttsAutoScroll = true;
    // Bug fix: Must set the jump-in-progress flag so the scroll
    // triggered by _jumpToParagraph doesn't immediately re-disable
    // auto-scroll in _onPositionsChanged.
    _setTtsJumpInProgress();
    final ttsState = ref.read(ttsReadingProvider);
    if (ttsState.currentParaId != null) {
      _jumpToParagraph(
        bookId,
        ttsState.currentParaId!,
        lineId: ttsState.currentLineId,
      );
    }
  }

  /// Set _ttsJumpInProgress true for a duration to prevent the position
  /// listener from disabling auto-scroll during TTS-initiated jumps and
  /// the subsequent layout changes from highlighting.
  void _setTtsJumpInProgress() {
    _ttsJumpInProgress = true;
    _ttsJumpTimer?.cancel();
    _ttsJumpTimer = Timer(const Duration(milliseconds: 200), () {
      _ttsJumpInProgress = false;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fallbackTimer?.cancel();
    _saveHistoryTimer?.cancel();
    _ttsJumpTimer?.cancel();
    _inBookSearchTimer?.cancel();
    _inBookSearchController.dispose();
    _inBookSearchFocusNode.dispose();
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

    final brightness = Theme.of(context).brightness;
    final resolvedPaliColor = settings.paliColorPair.resolve(brightness);
    final resolvedTransColor = settings.translationColorPair.resolve(brightness);

    final enabledLangs = settings.enabledTranslations.isNotEmpty
        ? settings.enabledTranslations.toList()
        : (settings.showTranslation
            ? [settings.primaryTranslationLang]
            : <String>[]);

    final langTypographies = <String, LanguageTypography>{};
    for (final langCode in enabledLangs) {
      langTypographies[langCode] =
          settings.typography.typographyFor(langCode);
    }

    // ── Resolve which paragraph to jump to ───────────────────────────
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

    final ttsCurrentLineId = _appLifecycleState == AppLifecycleState.resumed && isCurrentBookTts
        ? ttsReadingState.currentLineId
        : null;
    final ttsCurrentParaId = _appLifecycleState == AppLifecycleState.resumed && isCurrentBookTts
        ? ttsReadingState.currentParaId
        : null;

    // Save reading history when switching tabs
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

    // ── TTS auto-scroll listener ───────────────────────────────────────
    // Issue 3: Use timer-based _ttsJumpInProgress to cover highlighting
    //          layout changes.
    // Issue 4: Also scroll when lineId changes within the same paragraph,
    //          not just when paraId changes.
    ref.listen(ttsReadingProvider, (TtsReadingState? prev, TtsReadingState next) {
      final prevParaId = prev?.currentParaId;
      final nextParaId = next.currentParaId;
      final prevLineId = prev?.currentLineId;
      final nextLineId = next.currentLineId;
      if (!mounted || nextParaId == null) return;
      if (_appLifecycleState != AppLifecycleState.resumed) return;
      final currentBookId = ref.read(readerTabsProvider).activeTab?.bookId;
      if (currentBookId == null || next.bookId != currentBookId) return;

      // Issue 4: Also handle intra-paragraph line changes
      final paraChanged = prevParaId != nextParaId;
      final lineChanged = prevLineId != nextLineId;
      if (!paraChanged && !lineChanged) return;

      // Save reading history
      final bookName = ref.read(readerDataProvider(currentBookId)).bookName;
      developer.log(
        '[TTS_UI] listener: prevParaId=$prevParaId nextParaId=$nextParaId '
        'prevLineId=$prevLineId nextLineId=$nextLineId '
        'ttsAutoScroll=$_ttsAutoScroll',
        name: 'epitaka.tts',
      );
      _saveReadingHistory(currentBookId, bookName,
          explicitParaId: nextParaId, explicitLineId: nextLineId);

      if (!_ttsAutoScroll) {
        developer.log('[TTS_UI] auto-scroll off, skipping jump', name: 'epitaka.tts');
        if (mounted) setState(() {});
        return;
      }

      _setTtsJumpInProgress();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        developer.log('[TTS_UI] post-frame jump to $nextParaId line=$nextLineId',
            name: 'epitaka.tts');
        _jumpToParagraph(
          currentBookId,
          nextParaId,
          animate: false,
          lineId: nextLineId,
        );
      });
    });

    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isPhone = Mobile.isPhone(context);
    final showCollapsed = isPhone && _appBarCollapsed;

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.only(
          top: topPadding,
          bottom: bottomPadding,
        ),
        child: Column(
          children: [
            // ── Animated app bar ─────────────────────────────────
            ReaderAppBar(
              bookId: activeTab.bookId,
              bookName: readerState.bookName ?? activeTab.bookId,
              colors: colors,
              showCollapsed: showCollapsed,
              onSettingsTap: () => context.push('/settings'),
            ),
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
                    // Draggable scroll thumb
                    Positioned(
                      right: 2,
                      top: 0,
                      bottom: 0,
                      width: 28,
                      child: readerState.isLoaded && readerState.paragraphs.isNotEmpty
                          ? ReaderDragThumb(
                              readerState: readerState,
                              itemScrollController:
                                  _itemScrollControllers[activeTab.bookId],
                              itemPositionsListener:
                                  _itemPositionsListeners[activeTab.bookId],
                            )
                          : const SizedBox.shrink(),
                    ),
                    // In-book search bar overlay
                    if (_showInBookSearch)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Material(
                          elevation: 4,
                          color: colors.surface,
                          child: SafeArea(
                            top: true,
                            child: _buildInBookSearchBar(colors),
                          ),
                        ),
                      ),

                    // TTS floating controls chip
                    if (isCurrentBookTts &&
                        (globalTtsState == TtsPlaybackState.playing ||
                            globalTtsState == TtsPlaybackState.paused))
                      Positioned(
                        right: 16,
                        bottom: 84,
                        child: TtsFloatingChip(
                          colors: colors,
                          isAutoScroll: _ttsAutoScroll,
                          isJumpPending: _ttsJumpInProgress,
                          isTtsLineVisible: _isTtsLineVisible(
                              activeTab.bookId, ttsReadingState.currentParaId),
                          onTap: () =>
                              _showTtsControlsPopup(context, activeTab.bookId),
                          onFollowTap: () =>
                              _followTts(activeTab.bookId),
                        ),
                      ),

                    // Floating bottom toolbar (animated)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      bottom: showCollapsed ? -80.0 : 24.0,
                      left: 0,
                      right: 0,
                      child: Center(
                            child: ReaderBottomToolbar(
                              colors: colors,
                              displayMode: settings.translationDisplayMode,
                              showTranslation: settings.showTranslation,
                              ttsPlayback: ttsPlaybackStateForTab,
                              onJumpTap: () => _onJumpTap(activeTab, readerState),
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
                              onSearchTap: _toggleInBookSearch,
                              onListenTap: () async {
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
                                            : readerState.paragraphs.length - 1);
                                  }
                                }

                                final lines = <TtsLineItem>[];
                                final lang =
                                    enabledLangs.isNotEmpty ? enabledLangs.first : null;
                                if (lang == null) return;

                                // Load TTS replacements
                                final replaceAsyncState =
                                    ref.read(ttsReplacementsNotifierProvider);
                                if (replaceAsyncState is AsyncLoading ||
                                    replaceAsyncState is AsyncError) {
                                  await ref
                                      .read(ttsReplacementsNotifierProvider.notifier)
                                      .load();
                                }
                                final activeReplacements =
                                    ref.read(activeTtsReplacementsProvider);

                                for (int i = startParaIndex;
                                    i < readerState.paragraphs.length &&
                                        lines.length < 200;
                                    i++) {
                                  final para = readerState.paragraphs[i];
                                  for (final line in para.lines) {
                                    final rawText = line.translations[lang] ?? '';
                                    final stripped = stripHtmlForTts(rawText);
                                    var text = stripped;
                                    for (final rule in activeReplacements) {
                                      try {
                                        if (rule.isRegex) {
                                          text = text.replaceAll(
                                              RegExp(rule.pattern), rule.replacement);
                                        } else {
                                          text = text.replaceAll(
                                              rule.pattern, rule.replacement);
                                        }
                                      } catch (_) {}
                                    }
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

        // Issue 4: Pass line keys for the TTS target paragraph so
        // Scrollable.ensureVisible can precisely scroll to the line.
        Map<int, GlobalKey>? lineKeys;
        if (_ttsTargetParaId != null &&
            paragraph.paraId == _ttsTargetParaId &&
            _ttsTargetLineKeys.isNotEmpty) {
          lineKeys = Map.from(_ttsTargetLineKeys);
        }

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
          bookLinks: data.bookLinks[paragraph.paraId] ?? const {},
          searchQuery: _effectiveSearchQuery ?? activeTab.searchQuery,
          ttsHighlightLineId: ttsHighlightLineId,
          ttsHighlightParaId: ttsHighlightParaId,
          lineKeys: lineKeys,
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

  /// Build the in-book search bar shown as an overlay at the top of the reader.
  Widget _buildInBookSearchBar(ColorScheme colors) {
    final matchCount = _inBookMatchParaIds.length;
    final currentMatch = _inBookMatchIndex + 1; // 1-based display

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          // Close button
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            color: colors.onSurfaceVariant,
            onPressed: _toggleInBookSearch,
            tooltip: 'Close search',
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          // Search field
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _inBookSearchController,
                focusNode: _inBookSearchFocusNode,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Find in book…',
                  hintStyle: TextStyle(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: colors.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                  isDense: true,
                  suffixIcon: _inBookSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          color: colors.onSurfaceVariant,
                          onPressed: () {
                            _inBookSearchController.clear();
                            _runInBookSearch('');
                          },
                        )
                      : null,
                ),
                style: TextStyle(fontSize: 14, color: colors.onSurface),
                onChanged: (v) {
                  _inBookSearchTimer?.cancel();
                  _inBookSearchTimer = Timer(
                    const Duration(milliseconds: 200),
                    () => _runInBookSearch(v),
                  );
                },
                onSubmitted: (v) {
                  _inBookSearchTimer?.cancel();
                  _runInBookSearch(v);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Match counter
          if (matchCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '$currentMatch/$matchCount',
                style: TextStyle(
                  fontSize: 13,
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else if (_inBookQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'No results',
                style: TextStyle(
                  fontSize: 13,
                  color: colors.error.withValues(alpha: 0.7),
                ),
              ),
            ),
          // Previous match
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 22),
            color: matchCount > 0
                ? colors.onSurfaceVariant
                : colors.onSurfaceVariant.withValues(alpha: 0.3),
            onPressed: matchCount > 0
                ? () {
                    final newIdx = (_inBookMatchIndex - 1)
                        .clamp(0, matchCount - 1);
                    _jumpToInBookMatch(newIdx);
                  }
                : null,
            tooltip: 'Previous match',
            visualDensity: VisualDensity.compact,
          ),
          // Next match
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 22),
            color: matchCount > 0
                ? colors.onSurfaceVariant
                : colors.onSurfaceVariant.withValues(alpha: 0.3),
            onPressed: matchCount > 0
                ? () {
                    final newIdx = (_inBookMatchIndex + 1)
                        .clamp(0, matchCount - 1);
                    _jumpToInBookMatch(newIdx);
                  }
                : null,
            tooltip: 'Next match',
            visualDensity: VisualDensity.compact,
          ),
          // Separator
          Container(
            width: 1,
            height: 20,
            color: colors.outlineVariant.withValues(alpha: 0.3),
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          // Search entire Tipiṭaka
          IconButton(
            icon: const Icon(Icons.open_in_full, size: 18),
            color: colors.primary,
            onPressed: () {
              _toggleInBookSearch();
              context.push('/search');
            },
            tooltip: 'Search entire Tipiṭaka',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
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
