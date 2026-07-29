import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../core/utils/pali_search_utils.dart';
import '../../../core/utils/pali_script_converter.dart';
import '../../../core/utils/platform_info.dart';
import '../../../core/utils/responsive_breakpoint.dart';
import '../../../core/providers/app_db_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/utils/reading_clipboard.dart';
import '../utils/reader_quote_utils.dart' show buildCitationFromTemplate;
import '../../../shared/utils/app_shortcuts.dart';
import '../../../shared/providers/side_panel_provider.dart';
import '../../dictionary/widgets/dictionary_sheet.dart';
import '../../dictionary/providers/dictionary_sheet_open_provider.dart';

import '../../settings/widgets/settings_dialog.dart';
import '../../library/screens/library_screen.dart';
import '../../library/widgets/library_dialog.dart';
import '../../settings/providers/tts_provider.dart';
import '../../settings/providers/tts_replacements_provider.dart';
import '../providers/tts_reading_provider.dart';
import '../providers/reader_tts_sync_provider.dart';
import '../providers/reader_provider.dart';
import '../providers/reader_tabs_provider.dart';
import '../widgets/bookmark_dialog.dart';
import '../widgets/jump_sheet.dart';
import '../widgets/reader_app_bar.dart';
import '../widgets/reader_bottom_toolbar.dart';
import '../widgets/reader_context_menu.dart';
import '../widgets/reader_drag_thumb.dart';
import '../widgets/display_layout_popup.dart';
import '../widgets/reader_in_book_search_bar.dart';
import '../widgets/reader_tts_widgets.dart';
import '../widgets/reader_content_with_selection.dart';
import '../widgets/tab_strip.dart';
import '../services/reader_copy_service.dart';
import '../providers/reader_search_notifier.dart';
import '../providers/reader_selection_notifier.dart';

/// Reader screen with multiple tabs, showing Pāli text with translations.
/// Each tab has its own scroll position stored in [ReaderTabInfo].
///
/// Tab switching is driven by a finger-following horizontal drag
/// ([GestureDetector] + a [Transform] on the active reader content). On
/// release the active tab slides fully off one edge and the target tab
/// slides in from the opposite edge, giving a smooth, physical page-turn
/// feel without mounting a [PageView] (which previously caused duplicate
/// [GlobalKey]/controller assertions when the same book was shown twice).
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
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  /// Horizontal drag offset (px) of the active reader content while the
  /// user is swiping between tabs or while a settle animation is running.
  /// Driven through a [ValueNotifier] so the [Transform] can update without
  /// rebuilding the (heavy) reader content on every pointer move.
  final ValueNotifier<double> _dragDxNotifier = ValueNotifier(0);

  /// Whether a finger drag is currently in progress (suppresses the
  /// programmatic slide animation triggered by external tab switches).
  bool _isDragging = false;

  /// The tab index the current drag is heading toward (null if the drag
  /// hasn't passed the threshold in either direction).
  int? _dragTargetIndex;

  /// Animation controller that drives the settle (snap-back / commit)
  /// animation after a drag ends, and the slide-in for external switches.
  late final AnimationController _settleController;

  /// Token guarding against stale settle-completion callbacks (e.g. when a
  /// new drag interrupts an in-flight commit animation).
  int _settleToken = 0;

  /// Set while a programmatic slide is playing so the [readerTabsProvider]
  /// listener doesn't start a second, conflicting animation.
  bool _suppressIndexAnim = false;

  /// Direction of a pending external (non-drag) tab switch that should play
  /// a slide-in animation. Set in the [readerTabsProvider] listener and
  /// consumed at the top of [build] so the off-screen offset is applied
  /// before the first frame (no flash). null = no pending animation.
  bool? _pendingExternalAnim;

  // One controller/listener pair per open book tab.
  final Map<String, ItemScrollController> _itemScrollControllers = {};
  final Map<String, ItemPositionsListener> _itemPositionsListeners = {};
  final Map<String, VoidCallback> _positionsListenerRefs = {};

  /// The bookId whose reader list was last served a controller by
  /// [_scrollControllerFor]. When the next request is for a *different*
  /// bookId it's a tab switch, so a fresh [ItemScrollController] is handed to
  /// the incoming list. This avoids sharing one controller between the
  /// outgoing list (still animating out inside [AnimatedSwitcher]) and the
  /// incoming list, which trips scrollable_positioned_list's
  /// "_scrollableListState == null" assertion and stalls jumps.
  String? _lastControllerFetchBookId;

  /// Tracks the last word we looked up via double-tap, to avoid
  /// re-triggering the dictionary for the same word.
  String? _lastLookedUpWord;

  /// Key for the [SelectionArea]'s [SelectableRegionState] so we can clear
  /// any selection it created after our own double-tap detector looks up a
  /// word (keeping the region in a clean state for the next tap).
  final GlobalKey<SelectableRegionState> _selectableRegionKey =
      GlobalKey<SelectableRegionState>();

  /// Key for the [Listener] wrapping the reader content. We hit-test from
  /// this widget's render object (a plain [RenderProxyBox]) to locate the
  /// [RenderParagraph] under the tap. We deliberately do NOT hit-test from
  /// the [SelectionArea]'s render object, whose `hitTest` is overridden to
  /// only consider selection handles/toolbar and would never find the text.
  final GlobalKey _contentHitTestKey = GlobalKey();

  /// Double-tap detection state (raw pointer events, independent of the
  /// gesture arena that [SelectionArea] and the tab-swipe [GestureDetector]
  /// fight over).
  int? _lastTapDownTime;
  Offset? _lastTapDownPosition;
  int _tapCounter = 0;

  /// Tab-swipe tracking via raw pointer events (bypasses gesture arena).
  /// The outer GestureDetector was removed because it added a
  /// HorizontalDragGestureRecognizer that competed with SelectionArea's
  /// MultiDragGestureRecognizer, blocking vertical scrolling when text
  /// was selected. We now track horizontal drags passively from the
  /// existing Listener (which doesn't participate in the gesture arena).
  Offset? _swipeStartPos;
  bool _isSwiping = false;
  double _lastSwipeDx = 0;

  // ── Auto-scroll when dragging selection handle near viewport edge ──
  //
  // Flutter's built-in SelectionArea auto-scroll can't drive
  // ScrollablePositionedList because the SelectableRegion is outside the
  // list's internal Scrollable. We manually detect edge proximity from
  // raw pointer events and drive the scroll ourselves.
  //
  // Uses a persistent timer (not recreated on every pointer move) and a
  // small non-zero duration (16ms) for animateScroll to avoid flicker.
  static const double _kAutoScrollEdgeThreshold = 50.0;
  static const double _kAutoScrollBaseSpeed = 3.0; // px per 16ms tick

  /// Controller attached to the active tab's ScrollablePositionedList
  /// for pixel-based auto-scrolling.
  final ScrollOffsetController _autoScrollOffsetController =
      ScrollOffsetController();

  /// Persistent timer that scrolls the list while the pointer is near the
  /// viewport edge. Created once, stays alive until auto-scroll stops.
  Timer? _autoScrollTimer;

  /// Current auto-scroll speed. 0 = stopped. Positive = scroll down.
  /// Updated by [_checkAutoScrollEdge] on each pointer move; read by the
  /// persistent timer on each tick. This avoids recreating the timer.
  double _autoScrollSpeed = 0;



  // Track the last paraId we've jumped to per book, so we don't re-jump
  // every time the tab rebuilds (e.g. on unrelated provider changes).
  final Map<String, int> _lastJumpedParaId = {};

  // Guards against overlapping jump attempts for the same (bookId, paraId)
  // request racing each other.
  final Map<String, int> _pendingJumpParaId = {};

  // App lifecycle state for background TTS optimization
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  // Silverbar: collapsible app bar on scroll
  bool _appBarCollapsed = false;

  // Pixel-based scroll tracking (per book)
  final Map<String, ScrollOffsetListener> _scrollOffsetListeners = {};
  final Map<String, StreamSubscription<double>> _scrollOffsetSubs = {};
  final Map<String, double> _scrollAccum = {};
  static const double _kScrollThreshold = 20.0; // px

  /// Precise (fractional) scroll offset per book, updated on every position
  /// callback. Used by tab restoration to reproduce the exact position,
  /// including any within-paragraph scroll. Kept out of the provider so it
  /// doesn't trigger a reader rebuild on every scroll frame.
  final Map<String, double> _preciseScrollOffset = {};

  /// Whether an initial paragraph jump is in progress (from opening a
  /// book via history, search result, etc.). While true, the scroll
  /// collapse logic is suppressed to prevent the app bar/toolbar from
  /// getting stuck in a collapsed state during position restoration.
  bool _isInitialJumpPending = false;

  /// Suppresses app bar collapse/expand during programmatic scrolls
  /// (TTS jumps, TOC jumps, search result jumps, tab restore, etc.).
  /// Set to true before any controlled scroll, cleared when the scroll
  /// animation is expected to be complete. This prevents programmatic
  /// jumps from accidentally hiding or showing the app bar — only real
  /// human finger scrolling should trigger the collapse/expand.
  bool _suppressAppBarScroll = false;

  /// Tracks which bookId we already restored position for (prevents
  /// re-snapping on rebuild).
  String? _lastRestoredBookId;

  /// Last saved paraId per book (to avoid duplicate saves).
  final Map<String, int> _lastSavedParaIdPerBook = {};

  /// Debounce timer for scroll-based history saves.
  Timer? _saveHistoryTimer;

  /// Throttle: only update scroll state once per distinct paraId per book.
  final Map<String, int> _lastScrollParaId = {};

  // ── In-book search state lives in [inBookSearchProvider] ─────────────

  /// Delegate in-book search to [ReaderSearchNotifier].
  Future<void> _runInBookSearch(String query) async {
    ref.read(inBookSearchProvider.notifier).onQueryChanged(query);
  }

  /// Jump to the [index]th in-book search match.
  void _jumpToInBookMatch(int index) {
    final searchState = ref.read(inBookSearchProvider);
    final activeTab = ref.read(readerTabsProvider).activeTab;
    if (activeTab == null) return;
    if (index < 0 || index >= searchState.matchParaIds.length) return;

    final lineId = index < searchState.matchLineIds.length
        ? searchState.matchLineIds[index]
        : 1;
    _jumpToParagraph(
      activeTab.bookId,
      searchState.matchParaIds[index],
      animate: true,
      lineId: lineId,
    );
  }

  /// Toggle the in-book search bar.
  void _toggleInBookSearch() {
    ref.read(inBookSearchProvider.notifier).toggleSearchBar();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _settleController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 260),
        )..addListener(() {
          if (mounted) _dragDxNotifier.value = _settleController.value;
        });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _appLifecycleState = state);
  }

  // ── Scroll-position restoration helpers ─────────────────────────────
  //
  // [_onPositionsChanged] stores a *fractional* scroll offset per tab:
  //   offset = topmostVisibleIndex + itemLeadingEdge
  // where itemLeadingEdge is in [-1, 0] (negative when scrolled down within
  // the topmost paragraph). Tab restoration (see the isTabRestore branch in
  // build) converts that offset into a precise `alignment` for
  // [_jumpToParagraph], so a tab restores to the exact position — including
  // the within-paragraph offset — instead of always snapping the paragraph
  // to the top of the viewport.
  ItemScrollController _scrollControllerFor(String bookId) {
    final existing = _itemScrollControllers[bookId];
    // A request for the same bookId as the last fetch means the list element
    // is being reused (same tab, e.g. a settings/scroll rebuild): keep the
    // controller that is still attached to it. Creating a new one here would
    // detach the live list and break jumps.
    if (existing != null && _lastControllerFetchBookId == bookId) {
      return existing;
    }
    // Different bookId (tab switch) or first time: hand the incoming list a
    // fresh controller. The outgoing list keeps the controller it captured at
    // its own build and detaches on its own dispose, so the two never share
    // one controller.
    final fresh = ItemScrollController();
    _itemScrollControllers[bookId] = fresh;
    _lastControllerFetchBookId = bookId;
    return fresh;
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

    // Suppress app bar collapse/expand for ALL programmatic scrolls,
    // not just the initial position restoration. This prevents TTS
    // auto-scroll, TOC jumps, search-result jumps, and Follow-TTS
    // button taps from accidentally hiding/showing the app bar.
    // Only real human finger scrolling should trigger this.
    if (_isInitialJumpPending || _suppressAppBarScroll) {
      developer.log(
        '[UI_SCROLL] book=$bookId delta=$delta SUPPRESSED by '
        '_isInitialJumpPending=$_isInitialJumpPending '
        '_suppressAppBarScroll=$_suppressAppBarScroll',
        name: 'epitaka.reader.ui',
      );
      return;
    }

    // Issue 2: Check if at top of document before collapsing
    final positions = _itemPositionsListeners[bookId]?.itemPositions.value;
    if (positions != null && positions.isNotEmpty) {
      final visible = positions.where((p) => p.itemTrailingEdge > 0).toList()
        ..sort((a, b) => a.itemLeadingEdge.compareTo(b.itemLeadingEdge));
      if (visible.isNotEmpty && visible.first.index == 0) {
        // At the very top — never collapse
        developer.log(
          '[UI_SCROLL] book=$bookId delta=$delta at TOP → force-expand',
          name: 'epitaka.reader.ui',
        );
        if (_appBarCollapsed) setState(() => _appBarCollapsed = false);
        _scrollAccum[bookId] = 0;
        return;
      }
    }

    final acc = _scrollAccum[bookId] ?? 0;
    final sameDirection = acc == 0 || (delta > 0) == (acc > 0);
    final newAcc = sameDirection ? acc + delta : delta;

    if (newAcc > _kScrollThreshold) {
      developer.log(
        '[UI_SCROLL] book=$bookId delta=$delta acc=$acc→$newAcc '
        'COLLAPSE (wasCollapsed=$_appBarCollapsed)',
        name: 'epitaka.reader.ui',
      );
      _scrollAccum[bookId] = 0;
      if (!_appBarCollapsed) setState(() => _appBarCollapsed = true);
    } else if (newAcc < -_kScrollThreshold) {
      developer.log(
        '[UI_SCROLL] book=$bookId delta=$delta acc=$acc→$newAcc '
        'EXPAND (wasCollapsed=$_appBarCollapsed)',
        name: 'epitaka.reader.ui',
      );
      _scrollAccum[bookId] = 0;
      if (_appBarCollapsed) setState(() => _appBarCollapsed = false);
    } else {
      developer.log(
        '[UI_SCROLL] book=$bookId delta=$delta dir=${delta > 0 ? "down" : "up"} '
        'acc=$acc→$newAcc sameDir=$sameDirection',
        name: 'epitaka.reader.ui',
      );
      _scrollAccum[bookId] = newAcc;
    }
  }

  // ── Position tracking, silverbar, pagination ─────────────────────────
  //
  // Driven by ItemPositionsListener, which reports the *actual* visible
  // item indices from the layout.
  void _onPositionsChanged(String bookId) {
    // Only process positions for the active tab
    final activeTab = ref.read(readerTabsProvider).activeTab;
    if (activeTab?.bookId != bookId) return;

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
    // Fractional scroll offset: the topmost item's index plus its leading
    // edge (negative when scrolled *down* within the item). This captures
    // the within-paragraph offset so restoration can be exact instead of
    // always snapping the paragraph to the top of the viewport.
    final scrollOffset = topIndex + visible.first.itemLeadingEdge;

    final tabsState = ref.read(readerTabsProvider);
    final tabIndex = tabsState.tabs.indexWhere((t) => t.bookId == bookId);
    if (tabIndex >= 0) {
      final readerState = ref.read(readerDataProvider(bookId));
      if (topIndex >= 0 && topIndex < readerState.paragraphs.length) {
        final para = readerState.paragraphs[topIndex];
        final visibleParaId = para.paraId;
        final visibleLineId = para.lines.isNotEmpty
            ? para.lines.first.lineId
            : null;

        // Track the precise (fractional) offset in memory every frame so tab
        // restoration can reproduce the exact within-paragraph position. This
        // is kept out of the provider to avoid rebuilding the reader on every
        // scroll frame; the provider's scrollOffset (updated below, gated on
        // paragraph change) is only used as a fallback / for persistence.
        _preciseScrollOffset[bookId] = scrollOffset;

        if (_lastScrollParaId[bookId] != visibleParaId) {
          final posSw = Stopwatch()..start();
          developer.log(
            '[UI_POS] book=$bookId topIndex=$topIndex paraId=$visibleParaId',
            name: 'epitaka.reader.ui',
          );
          _lastScrollParaId[bookId] = visibleParaId;

          ref
              .read(readerTabsProvider.notifier)
              .updateScrollOffset(
                tabIndex,
                scrollOffset,
                paraId: visibleParaId,
                lineId: visibleLineId,
              );

          _scheduleSaveHistory(bookId, readerState.bookName, visibleParaId);

          // Detect manual scroll: if TTS is playing and this scroll
          // was NOT a TTS-initiated jump, disable auto-scroll.
          // ttsJumpInProgress is kept true by a timer after each
          // TTS jump to cover layout changes from highlighting.
          //
          // Bug fix: Check if the TTS paragraph is ANYWHERE in the
          // visible range, not just whether it's the TOP-MOST visible
          // paragraph. The top-most paragraph can differ from the TTS
          // paragraph after a fine-scroll (Scrollable.ensureVisible)
          // without the user having scrolled at all.
          final ttsSync = ref.read(ttsSyncProvider(bookId));
          if (!ttsSync.ttsJumpInProgress) {
            final ttsState = ref.read(ttsReadingProvider);
            if (ttsState.isActive && ttsState.bookId == bookId) {
              final ttsParaId = ttsState.currentParaId;
              if (ttsParaId != null) {
                // Check if any visible paragraph matches the TTS para
                final ttsIndex = readerState.paragraphs.indexWhere(
                  (p) => p.paraId == ttsParaId,
                );
                final isTtsInVisibleRange =
                    ttsIndex >= 0 && visible.any((p) => p.index == ttsIndex);
                if (!isTtsInVisibleRange) {
                  developer.log(
                    '[UI_POS] book=$bookId DISABLE auto-scroll: ttsPara=$ttsParaId '
                    'ttsIndex=$ttsIndex visible=${visible.map((p) => p.index).toList()}',
                    name: 'epitaka.reader.ui',
                  );
                  ref.read(ttsSyncProvider(bookId).notifier).disableAutoScroll();
                }
              }
            }
          } else {
            developer.log(
              '[UI_POS] book=$bookId ttsJumpInProgress=true → skip auto-scroll check',
              name: 'epitaka.reader.ui',
            );
          }
          posSw.stop();
          if (posSw.elapsedMilliseconds > 8) {
            developer.log(
              '[UI_POS] book=$bookId HEAVY position work ${posSw.elapsedMilliseconds}ms '
              'for paraId=$visibleParaId',
              name: 'epitaka.reader.ui',
            );
          }
        }
      }
    }

    // Track visible range for copy operations
    if (visible.isNotEmpty) {
      ref.read(readerSelectionProvider.notifier).updateVisibleRange(
        visible.first.index,
        visible.last.index,
      );
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
    int retryCount = 0,
  }) async {
    // Suppress app bar during this programmatic scroll
    _suppressAppBarScroll = true;

    _pendingJumpParaId[bookId] = paraId;

    var state = ref.read(readerDataProvider(bookId));
    var index = state.paragraphs.indexWhere((p) => p.paraId == paraId);

    if (index < 0) {
      if (!state.isLoaded) {
        developer.log(
          '[JUMP] book=$bookId paraId=$paraId data still loading, waiting…',
          name: 'epitaka.reader',
        );
        await ref.read(readerDataProvider(bookId).notifier).waitUntilLoaded();
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
      // Bounded retry: if the controller never attaches (e.g. the list is
      // still mounting), give up after a short grace period instead of
      // spinning every frame for seconds. The list will attach on its own
      // initState, and any later jump will succeed.
      const maxRetries = 30; // ~0.5s at 60fps
      if (retryCount >= maxRetries) {
        developer.log(
          '[JUMP] book=$bookId paraId=$paraId controller still not attached '
          'after $maxRetries retries — giving up',
          name: 'epitaka.reader.ui',
        );
        return;
      }
      developer.log(
        '[JUMP] book=$bookId paraId=$paraId controller not attached, retrying after frame '
        '(attempt ${retryCount + 1}/$maxRetries)',
        name: 'epitaka.reader.ui',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _jumpToParagraph(
          bookId,
          paraId,
          animate: animate,
          alignment: alignment,
          lineId: lineId,
          retryCount: retryCount + 1,
        ).then((_) {
          if (mounted) _isInitialJumpPending = false;
        });
      });
      return;
    }

    final jumpStart = DateTime.now().millisecondsSinceEpoch;
    developer.log(
      '[JUMP] book=$bookId paraId=$paraId index=$index '
      'lineId=$lineId animate=$animate isInitialJumpPending=$_isInitialJumpPending',
      name: 'epitaka.reader.ui',
    );

    _lastJumpedParaId[bookId] = paraId;

    // Issue 4: Create a GlobalKey for the target line so
    // Scrollable.ensureVisible can precisely scroll it into view.
    // Must call setState so the widget rebuilds with the new lineKeys.
    // Uses ttsSyncProvider as single source of truth for TTS scroll state.
    if (lineId != null) {
      ref.read(ttsSyncProvider(bookId).notifier).setTargetParaId(paraId);
      ref
          .read(ttsSyncProvider(bookId).notifier)
          .setTargetLineKey(lineId, GlobalKey());
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
      _scrollToLine(bookId, lineId);
    }

    // Clear initialParaId / initialLineId
    final tabsNotifier = ref.read(readerTabsProvider.notifier);
    final tabsState = ref.read(readerTabsProvider);
    final tabIndex = tabsState.tabs.indexWhere((t) => t.bookId == bookId);
    if (tabIndex >= 0) {
      tabsNotifier.clearInitialParaId(tabIndex);
    }
    _pendingJumpParaId.remove(bookId);

    final jumpElapsed = DateTime.now().millisecondsSinceEpoch - jumpStart;
    developer.log(
      '[JUMP] book=$bookId paraId=$paraId COMPLETE in ${jumpElapsed}ms '
      'wasInitialJump=$_isInitialJumpPending',
      name: 'epitaka.reader.ui',
    );

    // Programmatic scroll done — clear flags.
    // Use addPostFrameCallback so any in-flight scroll offset
    // notifications from this jump's paragraph scroll are still
    // suppressed.
    //
    // When lineId is set, _scrollToLine handles the
    // _suppressAppBarScroll lifecycle (because Scrollable
    // .ensureVisible's 100ms animation generates scroll events
    // that arrive after this postFrameCallback fires).
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          developer.log(
            '[JUMP] book=$bookId clearing _isInitialJumpPending '
            '(lineId=$lineId → _suppressAppBarScroll handled by _scrollToLine)',
            name: 'epitaka.reader.ui',
          );
          _isInitialJumpPending = false;
          // When there's a fine-scroll, _scrollToLine manages
          // _suppressAppBarScroll (set before ensureVisible,
          // cleared in .then() or retry-exhaustion).
          if (lineId == null) {
            _suppressAppBarScroll = false;
          }
        }
      });
    }
  }

  /// Issue 4: After a paragraph has been scrolled into view, fine-scroll
  /// to the specific line using Scrollable.ensureVisible on the line's
  /// GlobalKey context (the precise, non-guess-based way).
  /// Uses a local retry counter in the closure so concurrent retry loops
  /// from rapid TTS advances don't interfere with each other.
  static const int _kMaxTtsScrollRetries = 15;

  void _scrollToLine(String bookId, int lineId) {
    final ttsSync = ref.read(ttsSyncProvider(bookId));
    final key = ttsSync.ttsTargetLineKeys[lineId];
    if (key == null) {
      // No key means no fine-scroll needed — clear the suppression
      // that was set by _jumpToParagraph.
      _suppressAppBarScroll = false;
      return;
    }
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
        _suppressAppBarScroll = true;
        // When the in-book search bar is visible, use a slightly lower
        // alignment (0.38 instead of 0.3) so the line doesn't end up
        // directly behind the search bar at the top of the content area.
        final lineAlignment = _searchBarVisible ? 0.38 : 0.3;
        Scrollable.ensureVisible(
          lineContext,
          alignment: lineAlignment, // show line in upper third of viewport
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        ).then((_) {
          if (mounted) {
            ref
                .read(ttsSyncProvider(bookId).notifier)
                .removeTargetLineKey(lineId);
            ref
                .read(ttsSyncProvider(bookId).notifier)
                .clearTargetParaId();
            _suppressAppBarScroll = false;
          }
        });
      } else {
        retries++;
        if (retries >= _kMaxTtsScrollRetries) {
          ref
              .read(ttsSyncProvider(bookId).notifier)
              .removeTargetLineKey(lineId);
          ref
              .read(ttsSyncProvider(bookId).notifier)
              .clearTargetParaId();
          _suppressAppBarScroll = false;
          developer.log(
            '[TTS_LINE] line=$lineId scroll retries exhausted, cleared _suppressAppBarScroll',
            name: 'epitaka.tts',
          );
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) attemptScroll();
        });
      }
    }

    // Set suppression before the post-frame callback fires
    _suppressAppBarScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => attemptScroll());
  }

  /// Read whether the in-book search bar is currently visible.
  bool get _searchBarVisible =>
      ref.read(inBookSearchProvider).showSearchBar;

  /// TTS voices cache for the controls dialog (loaded on demand).
  List<Map<String, String>>? _cachedSystemVoices;
  bool _voicesLoading = false;

  // ── Swipe between tabs (finger-following) ─────────────────────────────
  //
  // A horizontal drag translates the active reader content in real time.
  // On release we either snap back (cancel) or play a two-phase slide:
  // the current tab slides fully off one edge, then the target tab slides
  // in from the opposite edge. This is driven by [_settleController] so it
  // stays smooth and respects a proper easing curve. External switches
  // (tab-strip tap, open-from-search) animate via the [readerTabsProvider]
  // listener in [build].
  void _onDragStart(DragStartDetails details) {
    _isDragging = true;
    _dragTargetIndex = null;
    // Invalidate any in-flight settle callback (e.g. an interrupted commit)
    // and clear suppression so a fresh drag takes over cleanly.
    _settleToken++;
    _suppressIndexAnim = false;
    _settleController.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final tabs = ref.read(readerTabsProvider);
    if (tabs.tabs.length <= 1) return;

    final width = MediaQuery.of(context).size.width;
    final next = (_dragDxNotifier.value + details.delta.dx).clamp(
      -width,
      width,
    );
    final active = tabs.activeIndex;

    if (next < -8 && active < tabs.tabs.length - 1) {
      _dragTargetIndex = active + 1; // swipe left → next
    } else if (next > 8 && active > 0) {
      _dragTargetIndex = active - 1; // swipe right → previous
    } else {
      _dragTargetIndex = null;
    }

    _dragDxNotifier.value = next;
  }

  void _onDragEnd(DragEndDetails details) {
    _isDragging = false;
    final width = MediaQuery.of(context).size.width;
    final tabs = ref.read(readerTabsProvider);
    final active = tabs.activeIndex;
    final velocity = details.primaryVelocity ?? 0; // px/s, <0 = left
    final target = _dragTargetIndex;

    final committed =
        target != null &&
        (_dragDxNotifier.value.abs() > width * 0.3 || velocity.abs() > 600);

    if (committed) {
      final forward = target > active; // next → exit left
      _suppressIndexAnim = true;
      _animateSettle(
        from: _dragDxNotifier.value,
        to: forward ? -width : width,
        onComplete: () {
          // Mount the target tab off-screen on the entry edge, then slide in.
          _dragDxNotifier.value = forward ? width : -width;
          ref.read(readerTabsProvider.notifier).switchTo(target);
          _animateSettle(
            from: _dragDxNotifier.value,
            to: 0,
            onComplete: () => _suppressIndexAnim = false,
          );
        },
      );
    } else {
      _animateSettle(from: _dragDxNotifier.value, to: 0);
    }
    _dragTargetIndex = null;
  }

  /// Animate [_dragDxNotifier] (via [_settleController]) from [from] to [to].
  /// [onComplete] only fires for the most recent call, so an interrupted
  /// settle can't trigger a stale tab switch.
  void _animateSettle({
    required double from,
    required double to,
    VoidCallback? onComplete,
  }) {
    final token = ++_settleToken;
    _settleController
      ..stop()
      ..value = from
      ..animateTo(
        to,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      ).then((_) {
        if (token == _settleToken && mounted) onComplete?.call();
      });
  }

  /// Get the current paraId from approximately 1/3 of the screen height.
  /// This uses the item positions listener to find the first paragraph
  /// whose leading edge is >= 0.3 (i.e., about 1/3 from the top).
  int? _getCurrentParaId(String bookId) {
    final listener = _itemPositionsListeners[bookId];
    final positions = listener?.itemPositions.value;
    if (positions == null || positions.isEmpty) return null;

    final visible = positions.where((p) => p.itemTrailingEdge > 0).toList()
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
  Future<void> _onJumpTap(
    ReaderTabInfo activeTab,
    ReaderDataState readerState,
  ) async {
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
    final pageNumber =
        readerState.paragraphs.isNotEmpty &&
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
    developer.log('[DBG] _onWordLookup word="$word"', name: 'epitaka.dict');
    developer.log(
      '[DICT] reader word lookup tap word="$word"',
      name: 'epitaka.dict',
    );
    final sidePanels = ref.read(sidePanelProvider);
    final isDictionaryPinned =
        sidePanels.right.openPanel == SidePanelType.dictionary &&
        sidePanels.right.isPinned;
    if (ResponsiveBreakpoint.isDesktop(context) && isDictionaryPinned) {
      // The dictionary is docked in the right side panel: route the lookup
      // there instead of opening the bottom sheet.
      ref.read(sidePanelProvider.notifier).updateDictionaryWord(word.trim());
      return;
    }
    // Default: show as a bottom sheet on all platforms. The user can pin it
    // (via the toolbar pin button) to dock it in the right side panel.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await showDictionarySheet(context, word.trim());
      } finally {
        if (mounted) {
          _lastLookedUpWord = null;
          // Clear any text selection that SelectionArea may have made
          // during the double-tap, so the user can start a fresh
          // long-press selection after dismissing the sheet.
          _selectableRegionKey.currentState?.clearSelection();
        }
      }
    });
  }

  void _handleSelectionChanged(SelectedContent? selection) {
    ref.read(readerSelectionProvider.notifier).onSelectionChanged(selection);
    developer.log(
      '[DBG] onSelectionChanged plain="${selection?.plainText}" '
      'hasSelection=${selection != null}',
      name: 'epitaka.dict',
    );

    // Dictionary lookup is now driven explicitly by our own double-tap
    // detector (see [_handlePointerDown] + [_selectWordAt]), which hit-tests
    // the render tree to find the word under the tap. We no longer infer a
    // double-tap from a single-word selection here, because that heuristic
    // competed with the tab-swipe [GestureDetector] and was flaky from the
    // second tap onward.
    //
    // We still cache the selection for the copy context menu / Ctrl+C
    // (long-press selection, which is a separate gesture from double-tap).
  }

  /// Detect a double-tap from raw pointer-down events. This runs *before*
  /// the gesture arena resolves, so it is not subject to the race between
  /// [SelectionArea]'s double-tap recognizer and the tab-swipe
  /// [GestureDetector]. When a double-tap is detected we look up the word
  /// at the tap point ourselves and open the dictionary.
  void _handlePointerDown(PointerDownEvent event) {
    // Record start position for potential tab-swipe (mobile/tablet only)
    if (!PlatformInfo.isDesktop) {
      _swipeStartPos = event.localPosition;
      _isSwiping = false;
      _lastSwipeDx = 0;
    }

    final now = event.timeStamp.inMilliseconds;
    final lastTime = _lastTapDownTime;
    final lastPos = _lastTapDownPosition;
    _lastTapDownTime = now;
    _lastTapDownPosition = event.localPosition;
    developer.log(
      '[DBG] pointerDown #${_tapCounter++} at=${event.localPosition} '
      'dt=${lastTime != null ? now - lastTime : '-'} '
      'dist=${lastPos != null ? (event.localPosition - lastPos).distance : '-'}',
      name: 'epitaka.dict',
    );

    if (lastTime != null && lastPos != null) {
      final dt = now - lastTime;
      final dist = (event.localPosition - lastPos).distance;
      const kDoubleTapTime = 400; // ms
      const kDoubleTapSlop = 40.0; // px
      if (dt >= 0 && dt <= kDoubleTapTime && dist <= kDoubleTapSlop) {
        // Double-tap confirmed. Look up the word at this point.
        developer.log('[DBG] DOUBLE-TAP detected', name: 'epitaka.dict');
        _lastTapDownTime = null;
        _lastTapDownPosition = null;
        _selectWordAt(event.position);
      } else {
        developer.log(
          '[DBG] tap too slow/far (dt=$dt dist=$dist) — not a double-tap',
          name: 'epitaka.dict',
        );
      }
    }
  }

  /// Find the Pāli word rendered at the global [globalPosition] and open the
  /// dictionary for it.
  ///
  /// We hit-test the reader content (via [_contentHitTestKey], a plain
  /// [RenderProxyBox] that descends into its children) to locate the
  /// [RenderParagraph] under the tap, then ask it for the word boundary at
  /// that offset. This is fully self-contained: it does not depend on
  /// [SelectionArea]'s own (flaky) double-tap recognition, which competes
  /// with the tab-swipe [GestureDetector] in the gesture arena and caused
  /// the lookup to work only intermittently (reliably on the first tap,
  /// then sporadically afterwards).
  void _selectWordAt(Offset globalPosition) {
    final context = _contentHitTestKey.currentContext;
    if (context == null) {
      developer.log('[DBG] _selectWordAt: no context', name: 'epitaka.dict');
      return;
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) {
      developer.log(
        '[DBG] _selectWordAt: renderObject not RenderBox '
        '(${renderObject.runtimeType})',
        name: 'epitaka.dict',
      );
      return;
    }

    // Walk the hit-test path to find the RenderParagraph under the tap.
    final local = renderObject.globalToLocal(globalPosition);
    final result = BoxHitTestResult();
    renderObject.hitTest(result, position: local);
    developer.log(
      '[DBG] _selectWordAt: hitTest path len=${result.path.length} '
      'firstTarget=${result.path.isNotEmpty ? result.path.first.target.runtimeType : 'none'}',
      name: 'epitaka.dict',
    );

    RenderParagraph? paragraph;
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderParagraph) {
        paragraph = target;
        break;
      }
    }
    // Fallback: if the path didn't contain a RenderParagraph (e.g. the hit
    // landed on a non-text decorator), walk up from the first hit target's
    // parent chain to find an enclosing RenderParagraph.
    if (paragraph == null && result.path.isNotEmpty) {
      RenderObject? node = result.path.first.target as RenderObject?;
      while (node != null) {
        if (node is RenderParagraph) {
          paragraph = node;
          break;
        }
        node = node.parent;
      }
    }
    if (paragraph == null) {
      developer.log(
        '[DBG] _selectWordAt: NO RenderParagraph found',
        name: 'epitaka.dict',
      );
      return;
    }

    // Position must be local to the paragraph's coordinate system.
    final paragraphOrigin = paragraph.localToGlobal(Offset.zero);
    final localInParagraph = globalPosition - paragraphOrigin;
    if (localInParagraph.dx < 0 ||
        localInParagraph.dy < 0 ||
        localInParagraph.dx > paragraph.size.width ||
        localInParagraph.dy > paragraph.size.height) {
      return;
    }

    final textPosition = paragraph.getPositionForOffset(localInParagraph);
    final boundary = paragraph.getWordBoundary(textPosition);
    if (!boundary.isValid || boundary.isCollapsed) return;

    final fullText = paragraph.text.toPlainText();
    if (boundary.end > fullText.length) {
      developer.log(
        '[DBG] _selectWordAt: boundary.end(${boundary.end}) > text len '
        '(${fullText.length})',
        name: 'epitaka.dict',
      );
      return;
    }
    final rawWord = fullText.substring(boundary.start, boundary.end);
    developer.log(
      '[DBG] _selectWordAt: rawWord="$rawWord" boundary=$boundary',
      name: 'epitaka.dict',
    );

    // Convert from any Pali script to Roman for dictionary lookup.
    final romanWord = convertToRomanPali(rawWord);
    final word = _cleanPali(romanWord);
    if (word.length >= 2 &&
        word.length <= 50 &&
        !word.contains(' ') &&
        !word.contains('\n') &&
        word != _lastLookedUpWord) {
      _lastLookedUpWord = word;
      developer.log(
        '[DBG] _selectWordAt: LOOKUP word="$word"',
        name: 'epitaka.dict',
      );
      _onWordLookup(word);
      // NOTE: We deliberately do NOT call clearSelection() here. Clearing the
      // selection while the modal dictionary sheet is opening was fighting
      // SelectionArea's own (now suppressed) selection and triggered
      // '!conflict' / 'parentDataDirty' framework assertions. Because the
      // double-tap is now claimed by the inner GestureDetector, SelectionArea
      // no longer selects the word, so there is nothing to clear.
    }
  }

  /// Handle raw pointer move for tab-swipe detection and auto-scroll.
  /// Uses the existing [Listener] (passive — no gesture arena participation)
  /// to track horizontal drags without competing with [SelectionArea].
  ///
  /// When there's an active text selection and the pointer is near the
  /// viewport edge, starts auto-scrolling to extend selection beyond the
  /// visible area. Flutter's built-in SelectionArea auto-scroll can't drive
  /// ScrollablePositionedList because the SelectableRegion is outside the
  /// list's internal Scrollable, so we handle it manually.
  void _handlePointerMoveForTabSwipe(PointerMoveEvent event) {
    // ── Auto-scroll when dragging selection handle near viewport edge ──
    if (ref.read(readerSelectionProvider).hasSelection) {
      _checkAutoScrollEdge(event);
    } else {
      _stopAutoScroll();
    }

    // ── Tab-swipe detection (mobile/tablet only, and not while selecting text) ──
    if (PlatformInfo.isDesktop) return;
    if (ref.read(readerSelectionProvider).hasSelection) return;
    if (_swipeStartPos == null) return;

    final dx = event.localPosition.dx - _swipeStartPos!.dx;
    final dy = (event.localPosition.dy - _swipeStartPos!.dy).abs();

    // Clear double-tap state on significant movement in any direction.
    // When the user scrolls (vertical movement), the old tap-down position
    // stays cached and the NEXT pointer-down can be misinterpreted as the
    // second tap of a double-tap, triggering a false dictionary lookup.
    if (dx.abs() > 10 || dy > 10) {
      _lastTapDownTime = null;
      _lastTapDownPosition = null;
    }

    // Must be primarily horizontal and past a small threshold
    if (!_isSwiping) {
      if (dx.abs() < 10 || dx.abs() < dy) return;
      _isSwiping = true;
      _lastSwipeDx = dx;
      _onDragStart(DragStartDetails(
        globalPosition: event.position,
        localPosition: event.localPosition,
      ));
      return;
    }

    final deltaDx = dx - _lastSwipeDx;
    _lastSwipeDx = dx;

    if (deltaDx != 0) {
      _onDragUpdate(DragUpdateDetails(
        delta: Offset(deltaDx, 0),
        globalPosition: event.position,
        localPosition: event.localPosition,
      ));
    }
  }

  /// Check if the pointer is near the viewport edge and start/stop
  /// auto-scroll accordingly.
  ///
  /// Instead of recreating the timer on every move, we just update
  /// [_autoScrollSpeed]. A persistent timer reads this value on each
  /// tick and scrolls if non-zero. This avoids the flicker caused by
  /// constantly cancelling and re-creating timers.
  void _checkAutoScrollEdge(PointerMoveEvent event) {
    final renderBox =
        _contentHitTestKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      _setAutoScrollSpeed(0);
      return;
    }

    final viewportHeight = renderBox.size.height;
    final localY = event.localPosition.dy;
    final clampedY = localY.clamp(0.0, viewportHeight);

    double speed;
    if (clampedY < _kAutoScrollEdgeThreshold) {
      // Near top edge — scroll backward (up)
      final intensity =
          1.0 - (clampedY / _kAutoScrollEdgeThreshold);
      speed = -_kAutoScrollBaseSpeed * (0.5 + 0.5 * intensity);
    } else if (clampedY > viewportHeight - _kAutoScrollEdgeThreshold) {
      // Near bottom edge — scroll forward (down)
      final intensity =
          ((clampedY - (viewportHeight - _kAutoScrollEdgeThreshold)) /
              _kAutoScrollEdgeThreshold);
      speed = _kAutoScrollBaseSpeed * (0.5 + 0.5 * intensity);
    } else {
      speed = 0;
    }

    _setAutoScrollSpeed(speed);
  }

  /// Update the auto-scroll speed and ensure the persistent timer is
  /// running (or stopped) as needed.
  void _setAutoScrollSpeed(double speed) {
    // No change — nothing to do
    if (speed == _autoScrollSpeed) return;

    _autoScrollSpeed = speed;

    if (speed == 0) {
      // Stop scrolling
      _autoScrollTimer?.cancel();
      _autoScrollTimer = null;
      return;
    }
    // Start the persistent timer (only when transitioning from stopped)
    _autoScrollTimer ??= Timer.periodic(
        const Duration(milliseconds: 16),
        (_) {
          if (!mounted) {
            _autoScrollTimer?.cancel();
            _autoScrollTimer = null;
            _autoScrollSpeed = 0;
            return;
          }
          final currentSpeed = _autoScrollSpeed;
          if (currentSpeed == 0) return;
          try {
            _autoScrollOffsetController.animateScroll(
              offset: currentSpeed,
              duration: const Duration(milliseconds: 16),
              curve: Curves.linear,
            );
          } catch (e) {
            developer.log(
              '[AUTO_SCROLL] animateScroll error: $e',
              name: 'epitaka.reader.ui',
            );
          }
        },
      );
    // If timer is already running, it will pick up the new speed
    // on the next tick automatically.
  }

  /// Stop auto-scrolling and cancel the timer.
  void _stopAutoScroll() {
    _autoScrollSpeed = 0;
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  /// Handle raw pointer up for tab-swipe completion.
  void _handlePointerUpForTabSwipe(PointerUpEvent event) {
    _finishTabSwipe();
  }

  /// Handle raw pointer cancel (e.g. system gesture interrupts).
  void _handlePointerCancelForTabSwipe(PointerCancelEvent event) {
    _finishTabSwipe();
  }

  /// Common cleanup for tab-swipe completion/cancellation.
  /// Velocity from raw pointer events is unreliable, so we rely on the
  /// position-based threshold (_dragDxNotifier.abs() > width * 0.3).
  void _finishTabSwipe() {
    _stopAutoScroll();
    if (_isSwiping) {
      _onDragEnd(DragEndDetails(
        velocity: Velocity.zero,
        primaryVelocity: 0,
      ));
    }
    _swipeStartPos = null;
    _isSwiping = false;
    _lastSwipeDx = 0;
  }

  String _cleanPali(String text) {
    return text.replaceAll(RegExp(r'[^\wāīūōṅñṭḍṇḷṃĀĪŪŌṄÑṬḌṆḶṀ\s]'), '').trim();
  }

  // ── Copy with style ──────────────────────────────────────────────────

  Widget _buildCopyContextMenu(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    final activeTab = ref.read(readerTabsProvider).activeTab;
    final selectionState = ref.read(readerSelectionProvider);
    final colors = Theme.of(context).colorScheme;

    final selectedText = selectionState.lastSelectedContent?.plainText.trim();

    return ReaderCopyService.buildContextMenu(
      context: context,
      selectableRegionState: selectableRegionState,
      colors: colors,
      lastSelectedContent: selectionState.lastSelectedContent,
      ref: ref,
      visibleStartIndex: selectionState.visibleStartIndex,
      visibleEndIndex: selectionState.visibleEndIndex,
      bookId: activeTab?.bookId ?? '',
      currentParaId: activeTab?.currentParaId,
      currentLineId: activeTab?.currentLineId,
      selectedText: selectedText,
    );
  }

  /// Copy using the rich HTML mechanism (preserves bold, italic, newlines).
  /// Delegates to [ReaderCopyService] which builds HTML from visible
  /// paragraphs and writes both rich HTML and newline-preserving plain
  /// text to the clipboard.
  void _copyPlainText() {
    final selectionState = ref.read(readerSelectionProvider);
    final activeTab = ref.read(readerTabsProvider).activeTab;
    if (activeTab == null) return;

    final readerState = ref.read(readerDataProvider(activeTab.bookId));
    if (readerState.paragraphs.isEmpty) return;

    final settings = ref.read(settingsProvider);
    ReaderCopyService.copySelectedContent(
      ref: ref,
      context: context,
      scope: CopyScope.both,
      addQuote: false,
      lastSelectedContent: selectionState.lastSelectedContent,
      visibleStartIndex: selectionState.visibleStartIndex,
      visibleEndIndex: selectionState.visibleEndIndex,
      script: settings.paliScript,
    );
  }

  void _onCopyShortcut() {
    final selectionState = ref.read(readerSelectionProvider);
    final activeTab = ref.read(readerTabsProvider).activeTab;
    if (activeTab == null) return;

    final readerState = ref.read(readerDataProvider(activeTab.bookId));
    if (readerState.paragraphs.isEmpty) return;

    final settings = ref.read(settingsProvider);
    ReaderCopyService.copySelectedContent(
      ref: ref,
      context: context,
      scope: CopyScope.both,
      addQuote: false,
      lastSelectedContent: selectionState.lastSelectedContent,
      visibleStartIndex: selectionState.visibleStartIndex,
      visibleEndIndex: selectionState.visibleEndIndex,
      script: settings.paliScript,
    );
  }

  Future<void> _copySelectedContent(
    CopyScope scope, {
    required bool addQuote,
  }) async {
    final selectionState = ref.read(readerSelectionProvider);
    final activeTab = ref.read(readerTabsProvider).activeTab;
    if (activeTab == null) return;

    final readerState = ref.read(readerDataProvider(activeTab.bookId));
    if (readerState.paragraphs.isEmpty) return;

    final settings = ref.read(settingsProvider);
    await ReaderCopyService.copySelectedContent(
      ref: ref,
      context: context,
      scope: scope,
      addQuote: addQuote,
      lastSelectedContent: selectionState.lastSelectedContent,
      visibleStartIndex: selectionState.visibleStartIndex,
      visibleEndIndex: selectionState.visibleEndIndex,
      script: settings.paliScript,
    );
  }

  Future<void> _copyVisibleContent(
    CopyScope scope, {
    required bool addQuote,
  }) async {
    final selectionState = ref.read(readerSelectionProvider);
    final settings = ref.read(settingsProvider);

    await ReaderCopyService.copySelectedContent(
      ref: ref,
      context: context,
      scope: scope,
      addQuote: addQuote,
      lastSelectedContent: selectionState.lastSelectedContent,
      visibleStartIndex: selectionState.visibleStartIndex,
      visibleEndIndex: selectionState.visibleEndIndex,
      script: settings.paliScript,
    );
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
    final ttsReadingState = ref.read(ttsReadingProvider);
    final isTtsLineVisible = _isTtsLineVisible(
      bookId,
      ttsReadingState.currentParaId,
    );

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
    ref.read(ttsSyncProvider(bookId).notifier).enableAutoScroll();
    // Bug fix: Must set the jump-in-progress flag so the scroll
    // triggered by _jumpToParagraph doesn't immediately re-disable
    // auto-scroll in _onPositionsChanged.
    ref.read(ttsSyncProvider(bookId).notifier).setJumpInProgress();
    final ttsState = ref.read(ttsReadingProvider);
    if (ttsState.currentParaId != null) {
      _jumpToParagraph(
        bookId,
        ttsState.currentParaId!,
        lineId: ttsState.currentLineId,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoScrollTimer?.cancel();
    _settleController.dispose();
    _dragDxNotifier.dispose();
    _saveHistoryTimer?.cancel();
    // In-book search state is managed by [inBookSearchProvider] (auto-disposed)
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

    // Apply a pending external tab-switch slide-in. Setting the notifier
    // value here (before the AnimatedBuilder reads it) means the incoming
    // tab is painted off-screen on its very first frame, then animates in.
    if (_pendingExternalAnim != null) {
      final width = MediaQuery.of(context).size.width;
      final forward = _pendingExternalAnim!;
      _dragDxNotifier.value = forward ? width : -width;
      _pendingExternalAnim = null;
      _suppressIndexAnim = true;
      _animateSettle(
        from: _dragDxNotifier.value,
        to: 0,
        onComplete: () => _suppressIndexAnim = false,
      );
    }

    if (tabsState.isEmpty) {
      final colors = Theme.of(context).colorScheme;
      final isDesktop = ResponsiveBreakpoint.isDesktop(context);
      if (isDesktop) {
        // Desktop: show a centered "Open Library" prompt that opens the
        // library as a dialog so the user can pick a book.
        return Scaffold(
          backgroundColor: colors.surface,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.menu_book,
                  size: 56,
                  color: colors.primary.withValues(alpha: 0.3),
                ),
                const SizedBox(height: AppDimensions.md),
                Text(
                  'No book open',
                  style: AppTypography.headlineSmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppDimensions.sm),
                FilledButton.icon(
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Open Library'),
                  onPressed: () => showLibraryDialog(context),
                ),
              ],
            ),
          ),
        );
      }
      // Phone/tablet: show the book list directly so a book can be chosen.
      return const LibraryScreen();
    }

    final activeTab = tabsState.activeTab!;
    final readerState = ref.watch(readerDataProvider(activeTab.bookId));
    final settings = ref.watch(settingsProvider);
    final colors = Theme.of(context).colorScheme;

    final brightness = Theme.of(context).brightness;
    final resolvedPaliColor = settings.paliColorPair.resolve(brightness);
    final resolvedTransColor = settings.translationColorPair.resolve(
      brightness,
    );

    final enabledLangs = settings.enabledTranslations.isNotEmpty
        ? settings.enabledTranslations.toList()
        : (settings.showTranslation
              ? [settings.primaryTranslationLang]
              : <String>[]);

    final langTypographies = <String, LanguageTypography>{};
    for (final langCode in enabledLangs) {
      langTypographies[langCode] = settings.typography.typographyFor(langCode);
    }

    // ── Resolve which paragraph to jump to ───────────────────────────
    final isNewInitialParaId =
        activeTab.initialParaId != null &&
        _lastJumpedParaId[activeTab.bookId] != activeTab.initialParaId;
    final isTabRestore =
        !isNewInitialParaId &&
        activeTab.currentParaId != null &&
        _lastRestoredBookId != activeTab.bookId;

    if (isNewInitialParaId) {
      _isInitialJumpPending = true;
      final targetParaId = activeTab.initialParaId!;
      final targetLineId = activeTab.initialLineId;
      _lastJumpedParaId[activeTab.bookId] = targetParaId;
      _lastRestoredBookId = activeTab.bookId;
      developer.log(
        '[BUILD] ${activeTab.bookId} isNewInitialParaId → jump to $targetParaId'
        ' line=$targetLineId (isInitialJumpPending=$_isInitialJumpPending)',
        name: 'epitaka.reader.ui',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // When a lineId is available, the fine-scroll in _scrollToLine will
        // position the line at 30% of the viewport. Without a lineId, use a
        // small alignment (5%) so the paragraph isn't flush with the top and
        // hidden behind the app bar / search bar.
        _jumpToParagraph(
          activeTab.bookId,
          targetParaId,
          alignment: targetLineId != null ? 0.0 : 0.05,
          lineId: targetLineId,
        );
      });
    } else if (isTabRestore) {
      _isInitialJumpPending = true;
      _lastRestoredBookId = activeTab.bookId;
      final targetParaId = activeTab.currentParaId!;
      // Restore the exact within-paragraph offset via a precise alignment
      // derived from the saved fractional scrollOffset. We use _jumpToParagraph
      // (a post-layout jumpTo) rather than initialScrollIndex, because
      // initialScrollIndex relies on item-extent *estimates* and is wildly
      // inaccurate for variable-height Pali paragraphs (off by ~a screen).
      final offset =
          _preciseScrollOffset[activeTab.bookId] ?? activeTab.scrollOffset;
      // alignment must be the *negative* fractional part of the offset, i.e.
      // the item's leading edge. Because itemLeadingEdge is in [-1, 0] when
      // scrolled down within the top paragraph, offset = topIndex + leading
      // and ceil(offset) == topIndex, so (offset - ceil(offset)) == leading.
      // Using floor() here would yield leading + 1 (~a full viewport off).
      final double alignment = offset != null ? (offset - offset.ceil()) : 0.0;
      developer.log(
        '[BUILD] ${activeTab.bookId} isTabRestore → jump to $targetParaId '
        'alignment=$alignment (isInitialJumpPending=$_isInitialJumpPending)',
        name: 'epitaka.reader.ui',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _jumpToParagraph(
          activeTab.bookId,
          targetParaId,
          animate: false,
          alignment: alignment,
        );
      });
    }

    final ttsReadingState = ref.watch(ttsReadingProvider);
    final globalTtsState = ref.watch(ttsProvider);
    final isCurrentBookTts = ttsReadingState.bookId == activeTab.bookId;
    final ttsPlaybackStateForTab = isCurrentBookTts
        ? globalTtsState
        : TtsPlaybackState.stopped;

    final ttsCurrentLineId =
        _appLifecycleState == AppLifecycleState.resumed && isCurrentBookTts
        ? ttsReadingState.currentLineId
        : null;
    final ttsCurrentParaId =
        _appLifecycleState == AppLifecycleState.resumed && isCurrentBookTts
        ? ttsReadingState.currentParaId
        : null;

    // Save reading history when switching tabs
    ref.listen(readerTabsProvider, (
      ReaderTabsState? prev,
      ReaderTabsState next,
    ) {
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

      // ── Queue a slide animation for external (non-drag) tab switches ──
      // (tab-strip tap, open from search/contents/history). Drag commits
      // set [_suppressIndexAnim] so this is skipped and the drag's own
      // two-phase animation plays instead. We only *record* the direction
      // here; the offset is applied at the top of [build] so the incoming
      // tab starts off-screen on the first frame (no flash).
      final prevIndex = prev?.activeIndex ?? next.activeIndex;
      final prevBookId = prev?.activeTab?.bookId;
      final lengthChanged = next.length != prev?.length;
      if (next.activeIndex != prevIndex &&
          !lengthChanged &&
          next.activeTab?.bookId != prevBookId &&
          !_suppressIndexAnim &&
          !_isDragging) {
        _pendingExternalAnim = next.activeIndex > prevIndex;
      }
    });

    // ── In-book search global shortcut listener ───────────────────
    // The Ctrl/Cmd+F shortcut (wired at the app level) flips this provider;
    // we react by toggling the in-book search bar. Reset it afterwards so
    // the shortcut can fire again.
    ref.listen(inBookSearchToggleProvider, (prev, next) {
      if (next != prev) {
        _toggleInBookSearch();
        if (mounted) {
          ref.read(inBookSearchToggleProvider.notifier).state = false;
        }
      }
    });

    // ── TTS auto-scroll listener ───────────────────────────────────────
    // Issue 3: Use timer-based _ttsJumpInProgress to cover highlighting
    //          layout changes.
    // Issue 4: Also scroll when lineId changes within the same paragraph,
    //          not just when paraId changes.
    ref.listen(ttsReadingProvider, (
      TtsReadingState? prev,
      TtsReadingState next,
    ) {
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
      final ttsSync = ref.read(ttsSyncProvider(currentBookId));
      developer.log(
        '[TTS_UI] listener: prevParaId=$prevParaId nextParaId=$nextParaId '
        'prevLineId=$prevLineId nextLineId=$nextLineId '
        'ttsAutoScroll=${ttsSync.ttsAutoScroll}',
        name: 'epitaka.tts',
      );
      _saveReadingHistory(
        currentBookId,
        bookName,
        explicitParaId: nextParaId,
        explicitLineId: nextLineId,
      );

      if (!ttsSync.ttsAutoScroll) {
        developer.log(
          '[TTS_UI] auto-scroll off, skipping jump',
          name: 'epitaka.tts',
        );
        if (mounted) setState(() {});
        return;
      }

      ref.read(ttsSyncProvider(currentBookId).notifier).setJumpInProgress();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        developer.log(
          '[TTS_UI] post-frame jump to $nextParaId line=$nextLineId',
          name: 'epitaka.tts',
        );
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
        padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
        child: Column(
          children: [
            // ── Animated app bar ─────────────────────────────────
            ReaderAppBar(
              bookId: activeTab.bookId,
              bookName: readerState.bookName ?? activeTab.bookId,
              colors: colors,
              showCollapsed: showCollapsed,
              onSettingsTap: () {
                if (ResponsiveBreakpoint.isDesktop(context)) {
                  showSettingsDialog(context);
                } else {
                  context.push('/settings');
                }
              },
              actions: ResponsiveBreakpoint.isDesktop(context)
                  ? [
                      IconButton(
                        icon: const Icon(Icons.menu_book_outlined),
                        color: colors.onSurfaceVariant,
                        tooltip: 'Library',
                        onPressed: () => showLibraryDialog(context),
                      ),
                      IconButton(
                        icon: const Icon(Icons.search),
                        color: colors.onSurfaceVariant,
                        tooltip: 'Search',
                        onPressed: () => ref
                            .read(sidePanelProvider.notifier)
                            .toggle(SidePanelType.search),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        color: colors.onSurfaceVariant,
                        tooltip: 'Settings',
                        onPressed: () {
                          if (ResponsiveBreakpoint.isDesktop(context)) {
                            showSettingsDialog(context);
                          } else {
                            context.push('/settings');
                          }
                        },
                      ),
                    ]
                  : null,
            ),
            const TabStrip(),
            Expanded(
              child: Stack(
                children: [
                  // ── Swipeable tab content with finger-following slide ──
                  CallbackShortcuts(
                    bindings: {
                    SingleActivator(LogicalKeyboardKey.keyC, control: true):
                        _onCopyShortcut,
                    SingleActivator(LogicalKeyboardKey.keyC, meta: true):
                        _onCopyShortcut,
                    },
                    child: Focus(
                      autofocus: true,
                      child: _buildReaderContentWithSelection(
                          context,
                          readerState,
                          settings,
                          colors,
                          activeTab,
                          resolvedPaliColor,
                          resolvedTransColor,
                          enabledLangs,
                          langTypographies,
                          ttsCurrentLineId,
                          ttsCurrentParaId,
                      ),
                    ),
                  ),
                  // ── Overlays (only for the active tab) ─────────────────
                  // Draggable scroll thumb
                  Positioned(
                    right: 2,
                    top: 0,
                    bottom: 0,
                    width: 28,
                    child:
                        readerState.isLoaded &&
                            readerState.paragraphs.isNotEmpty
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
                  if (ref.watch(inBookSearchProvider).showSearchBar)
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
                        isAutoScroll: ref.read(ttsSyncProvider(activeTab.bookId)).ttsAutoScroll,
                        isJumpPending: ref.read(ttsSyncProvider(activeTab.bookId)).ttsJumpInProgress,
                        isTtsLineVisible: _isTtsLineVisible(
                          activeTab.bookId,
                          ttsReadingState.currentParaId,
                        ),
                        onTap: () =>
                            _showTtsControlsPopup(context, activeTab.bookId),
                        onFollowTap: () => _followTts(activeTab.bookId),
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
                        onJumpTap: () => _onJumpTap(activeTab, readerState),                        onDisplayLayoutTap: () {
                          showDialog(
                            context: context,
                            barrierColor: Colors.transparent,
                            barrierDismissible: true,
                            builder: (_) => const Align(
                              alignment: Alignment(0, 0.88),
                              child: DisplayLayoutPopup(),
                            ),
                          );
                        },
                        onContentsTap: () {
                          final currentParaId = activeTab.currentParaId;
                          var url =
                              '/contents/${activeTab.bookId}?bookName=${Uri.encodeComponent(readerState.bookName ?? activeTab.bookId)}';
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
                          final positions =
                              _itemPositionsListeners[activeTab.bookId]
                                  ?.itemPositions
                                  .value;
                          int startParaIndex = 0;
                          if (positions != null && positions.isNotEmpty) {
                            final visible =
                                positions
                                    .where((p) => p.itemTrailingEdge > 0)
                                    .toList()
                                  ..sort(
                                    (a, b) => a.itemLeadingEdge.compareTo(
                                      b.itemLeadingEdge,
                                    ),
                                  );
                            if (visible.isNotEmpty) {
                              startParaIndex = visible.first.index.clamp(
                                0,
                                readerState.paragraphs.isEmpty
                                    ? 0
                                    : readerState.paragraphs.length - 1,
                              );
                            }
                          }

                          final lines = <TtsLineItem>[];
                          final lang = enabledLangs.isNotEmpty
                              ? enabledLangs.first
                              : null;
                          if (lang == null) return;

                          // Load TTS replacements
                          final replaceAsyncState = ref.read(
                            ttsReplacementsNotifierProvider,
                          );
                          if (replaceAsyncState is AsyncLoading ||
                              replaceAsyncState is AsyncError) {
                            await ref
                                .read(ttsReplacementsNotifierProvider.notifier)
                                .load();
                          }
                          final activeReplacements = ref.read(
                            activeTtsReplacementsProvider,
                          );

                          for (
                            int i = startParaIndex;
                            i < readerState.paragraphs.length;
                            i++
                          ) {
                            final para = readerState.paragraphs[i];
                            for (final line in para.lines) {
                              final rawText = line.translations[lang] ?? '';
                              final stripped = stripHtmlForTts(rawText);
                              var text = stripped;
                              for (final rule in activeReplacements) {
                                try {
                                  if (rule.isRegex) {
                                    text = text.replaceAll(
                                      RegExp(rule.pattern),
                                      rule.replacement,
                                    );
                                  } else {
                                    text = text.replaceAll(
                                      rule.pattern,
                                      rule.replacement,
                                    );
                                  }
                                } catch (_) {}
                              }
                              lines.add(
                                TtsLineItem(
                                  paraId: para.paraId,
                                  lineId: line.lineId,
                                  text: text,
                                ),
                              );
                            }
                          }

                          if (lines.isNotEmpty) {
                            // Cache the book name so the Android
                            // notification shows a human-readable
                            // title instead of the raw bookId.
                            TtsReadingNotifier.cacheBookName(
                              activeTab.bookId,
                              readerState.bookName ?? activeTab.bookId,
                            );
                            ref
                                .read(ttsReadingProvider.notifier)
                                .startReading(activeTab.bookId, lines);
                          }
                        },
                        onStopTap: () {
                          ref.read(ttsReadingProvider.notifier).stopReading();
                        },
                        onBookmarkTap: () =>
                            _onBookmarkTap(activeTab, readerState),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the reader content wrapped in a permanently-mounted [SelectionArea]
  /// (used for long-press/drag text selection). The [SelectionArea] is never
  /// added/removed from the tree — doing so mid-focus-shift crashes the
  /// selection system.
  Widget _buildReaderContentWithSelection(
    BuildContext context,
    ReaderDataState data,
    AppSettings settings,
    ColorScheme colors,
    ReaderTabInfo activeTab,
    Color paliColor,
    Color translationColor,
    List<String> enabledLangs,
    Map<String, LanguageTypography> langTypographies,
    int? ttsHighlightLineId,
    int? ttsHighlightParaId,
  ) {
    final dictSheetOpen = ref.watch(dictionarySheetOpenProvider);

    Widget content = ReaderContentWithSelection(
      bookId: activeTab.bookId,
      data: data,
      settings: settings,
      colors: colors,
      paliColor: paliColor,
      translationColor: translationColor,
      enabledLangs: enabledLangs,
      langTypographies: langTypographies,
      itemScrollController: _scrollControllerFor(activeTab.bookId),
      itemPositionsListener: _positionsListenerFor(activeTab.bookId),
      scrollOffsetListener: _scrollOffsetListenerFor(activeTab.bookId),
      contentHitTestKey: _contentHitTestKey,
      dragDxNotifier: _dragDxNotifier,
      selectableRegionKey: _selectableRegionKey,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMoveForTabSwipe,
      onPointerUp: _handlePointerUpForTabSwipe,
      onPointerCancel: _handlePointerCancelForTabSwipe,
      scrollOffsetController: _autoScrollOffsetController,
      onSelectionChanged: _handleSelectionChanged,
      contextMenuBuilder: _buildCopyContextMenu,
      ttsHighlightLineId: ttsHighlightLineId,
      ttsHighlightParaId: ttsHighlightParaId,
      ttsTargetParaId: ref.read(ttsSyncProvider(activeTab.bookId)).ttsTargetParaId,
      ttsTargetLineKeys: ref.read(ttsSyncProvider(activeTab.bookId)).ttsTargetLineKeys,
      searchQuery: ref.watch(inBookSearchProvider).effectiveQuery ?? activeTab.searchQuery,
    );

    // When the dictionary sheet is open, Flutter adds bottom padding to the
    // underlying route's MediaQuery (the "sheet's inset"), which can cause
    // ScrollablePositionedList to re-layout and change its scroll position.
    // Removing this padding prevents the reader behind the sheet from
    // scrolling/jumping while the sheet appears.
    if (dictSheetOpen) {
      content = MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: content,
      );
    }

    return content;
  }

  /// Build the in-book search bar shown as an overlay at the top of the reader.
  Widget _buildInBookSearchBar(ColorScheme colors) {
    return ReaderInBookSearchBar(
      colors: colors,
      controller: ref.read(inBookSearchProvider.notifier).searchController,
      focusNode: ref.read(inBookSearchProvider.notifier).searchFocusNode,
      matchCount: ref.watch(inBookSearchProvider).matchCount,
      currentMatchIndex: ref.watch(inBookSearchProvider).matchIndex,
      query: ref.watch(inBookSearchProvider).query,
      onClose: _toggleInBookSearch,
      onQueryChanged: (v) {
        ref.read(inBookSearchProvider.notifier).onQueryChanged(v);
      },
      onSubmitted: (v) {
        ref.read(inBookSearchProvider.notifier).onSubmitted(v);
      },
      onPrevious: () {
        final searchState = ref.read(inBookSearchProvider);
        if (!searchState.hasMatches) return;
        final newIdx = (searchState.matchIndex - 1).clamp(
          0,
          searchState.matchCount - 1,
        );
        _jumpToInBookMatch(newIdx);
      },
      onNext: () {
        final searchState = ref.read(inBookSearchProvider);
        if (!searchState.hasMatches) return;
        final newIdx = (searchState.matchIndex + 1).clamp(
          0,
          searchState.matchCount - 1,
        );
        _jumpToInBookMatch(newIdx);
      },
      onSearchEntire: () {
        _toggleInBookSearch();
        if (ResponsiveBreakpoint.isDesktop(context)) {
          ref.read(sidePanelProvider.notifier).open(SidePanelType.search);
        } else {
          context.push('/search');
        }
      },
    );
  }}


