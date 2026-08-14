// lib/features/reader/providers/reader_scroll_controller.dart
//
// All reader scroll machinery, extracted from _ReaderScreenState:
//
//   * per-book [ItemScrollController] / [ItemPositionsListener] /
//     [ScrollOffsetListener] lifecycle,
//   * position tracking ([onPositionsChanged]) — fractional scroll offset,
//     tab scroll-offset updates, history scheduling, TTS auto-scroll
//     detection, selection visible range,
//   * the collapsible app-bar pixel accumulator ([onScrollOffsetChanged]),
//   * unified jump-by-paraId + precise per-line fine-scroll
//     ([jumpToParagraph] / [fineScrollToLine]),
//   * reading-history persistence ([saveReadingHistory]).
//
// The screen owns the [ValueNotifier<bool> appBarCollapsed] (so only the
// app bar rebuilds) and passes it in; everything else the controller needs
// from the widget layer (mounted/setState/context-derived values, the TTS
// hook) is injected as callbacks, matching the [ReaderTtsController]
// pattern.

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../core/providers/app_db_provider.dart';
import '../../dictionary/providers/dictionary_sheet_open_provider.dart';
import '../providers/reader_provider.dart';
import '../providers/reader_selection_notifier.dart';
import '../providers/reader_tabs_provider.dart';
import '../providers/reader_tts_sync_provider.dart';
import '../utils/reader_position_utils.dart' show getCurrentParaId;

/// Owns the reader's scroll controllers, position tracking, jumping, and
/// reading-history persistence.
class ReaderScrollController {
  ReaderScrollController({
    required this.ref,
    required this.isMounted,
    required this.isPhone,
    required this.viewInsetsBottom,
    required this.appBarCollapsed,
    required this.onTtsManualScroll,
    this.onFirstVisiblePosition,
  });

  /// Riverpod reference for provider reads/writes.
  final WidgetRef ref;

  /// Whether the owning screen is still mounted (guards async callbacks).
  final bool Function() isMounted;

  /// Whether the device is a phone (only phones collapse the app bar).
  final bool Function() isPhone;

  /// Current `MediaQuery.viewInsets.bottom` (keyboard-triggered layout
  /// changes fire position callbacks that must be skipped).
  final double Function() viewInsetsBottom;

  /// App-bar collapse state, owned by the screen so a
  /// [ValueListenableBuilder] can rebuild only the app bar/toolbar.
  final ValueNotifier<bool> appBarCollapsed;

  /// TTS hook: called when the visible paragraph changes so the TTS
  /// controller can disable auto-scroll on manual scrolls.
  final void Function(
    String bookId,
    List<ItemPosition> visible,
    List<ParagraphData> paragraphs,
  ) onTtsManualScroll;

  /// Called once per book when a new topmost paragraph first becomes
  /// visible (used by the screen for tab-switch timing + position logs).
  final void Function(String bookId, int topIndex, int paraId)?
  onFirstVisiblePosition;

  // One controller/listener pair per open book tab.
  final Map<String, ItemScrollController> _itemScrollControllers = {};
  final Map<String, ItemPositionsListener> _itemPositionsListeners = {};
  final Map<String, VoidCallback> _positionsListenerRefs = {};

  /// The bookId whose reader list was last served a controller by
  /// [scrollControllerFor]. When the next request is for a *different*
  /// bookId it's a tab switch, so a fresh [ItemScrollController] is handed
  /// to the incoming list. This avoids sharing one controller between the
  /// outgoing list (still animating out inside [AnimatedSwitcher]) and the
  /// incoming list, which trips scrollable_positioned_list's
  /// "_scrollableListState == null" assertion and stalls jumps.
  String? _lastControllerFetchBookId;

  // Track the last EXPLICIT jump request id consumed per book. The tabs
  // provider stamps every openTab-with-position call with a fresh
  // initialJumpId, so comparing ids (instead of the para value) lets a
  // repeat request for the paragraph the reader is already on still jump
  // and fine-scroll to the line.
  final Map<String, int?> _lastInitialJumpId = {};

  // Guards against overlapping jump attempts for the same (bookId, paraId)
  // request racing each other.
  final Map<String, int> _pendingJumpParaId = {};

  // Monotonic token per book so a stale fine-scroll from a superseded jump
  // can never clear jump flags while a newer jump is in progress.
  final Map<String, int> _jumpTokens = {};

  // Pixel-based scroll tracking (per book)
  final Map<String, ScrollOffsetListener> _scrollOffsetListeners = {};
  final Map<String, StreamSubscription<double>> _scrollOffsetSubs = {};
  final Map<String, double> _scrollAccum = {};
  static const double _kScrollThreshold = 20.0; // px

  /// Maximum frames to wait for a fine-scroll target line widget to be
  /// laid out before giving up.
  static const int _kMaxLineScrollRetries = 15;

  /// Precise (fractional) scroll offset per book, updated on every position
  /// callback. Used by tab restoration to reproduce the exact position,
  /// including any within-paragraph scroll. Kept out of the provider so it
  /// doesn't trigger a reader rebuild on every scroll frame.
  final Map<String, double> _preciseScrollOffset = {};

  /// Whether an initial paragraph jump is in progress (from opening a
  /// book via history, search result, etc.). While true, the scroll
  /// collapse logic is suppressed to prevent the app bar/toolbar from
  /// getting stuck in a collapsed state during position restoration.
  bool isInitialJumpPending = false;


  /// Suppresses app bar collapse/expand during programmatic scrolls
  /// (TTS jumps, TOC jumps, search result jumps, tab restore, etc.).
  /// Set to true before any controlled scroll, cleared when the scroll
  /// animation is expected to be complete. This prevents programmatic
  /// jumps from accidentally hiding or showing the app bar — only real
  /// human finger scrolling should trigger the collapse/expand.
  bool suppressAppBarScroll = false;

  /// Tracks which bookId we already restored position for (prevents
  /// re-snapping on rebuild).
  String? lastRestoredBookId;

  /// Last saved paraId per book (to avoid duplicate saves).
  final Map<String, int> _lastSavedParaIdPerBook = {};

  /// Debounce timer for scroll-based history saves.
  Timer? _saveHistoryTimer;

  /// Throttle: only update scroll state once per distinct paraId per book.
  final Map<String, int> _lastScrollParaId = {};

  /// Last known viewInsets.bottom — used to detect keyboard-triggered
  /// layout changes (which fire [onPositionsChanged] but are not real
  /// user scrolls). When the keyboard shows/hides while a modal bottom
  /// sheet is open, the viewport shrinks/grows and the scrollable list
  /// reports new positions — we skip those to avoid unwanted scroll saves
  /// and TTS-auto-scroll disabling.
  double _lastViewInsets = 0;

  /// Throttle: skip [onPositionsChanged] heavy work if called too
  /// frequently.
  DateTime? _lastPositionThrottle;
  static const Duration _kPositionThrottleDuration = Duration(milliseconds: 50);

  /// The item positions of the reader list for [bookId], or null when the
  /// tab has no mounted list yet (no listener is created by this getter).
  Iterable<ItemPosition>? positionsFor(String bookId) =>
      _itemPositionsListeners[bookId]?.itemPositions.value;

  /// Raw [ItemScrollController] for [bookId] if one was handed out (used by
  /// the drag thumb; does NOT apply the fresh-controller tab-switch logic).
  ItemScrollController? itemScrollControllerFor(String bookId) =>
      _itemScrollControllers[bookId];

  /// Raw [ItemPositionsListener] for [bookId] if one was created (used by
  /// the drag thumb).
  ItemPositionsListener? itemPositionsListenerFor(String bookId) =>
      _itemPositionsListeners[bookId];

  /// The last explicit jump request id consumed for [bookId].
  int? lastInitialJumpId(String bookId) => _lastInitialJumpId[bookId];

  /// Record the explicit jump request id consumed for [bookId].
  void setLastInitialJumpId(String bookId, int? id) {
    _lastInitialJumpId[bookId] = id;
  }

  /// Precise fractional scroll offset saved for [bookId] (tab restoration).
  double? preciseScrollOffsetFor(String bookId) => _preciseScrollOffset[bookId];

  /// Hand [bookId]'s reader list its [ItemScrollController].
  ///
  /// A request for the same bookId as the last fetch means the list element
  /// is being reused (same tab, e.g. a settings/scroll rebuild): keep the
  /// controller that is still attached to it. Creating a new one here would
  /// detach the live list and break jumps. A different bookId (tab switch)
  /// or first time hands the incoming list a fresh controller — the
  /// outgoing list keeps the controller it captured at its own build and
  /// detaches on its own dispose, so the two never share one controller.
  ItemScrollController scrollControllerFor(String bookId) {
    final existing = _itemScrollControllers[bookId];
    if (existing != null && _lastControllerFetchBookId == bookId) {
      return existing;
    }
    final fresh = ItemScrollController();
    _itemScrollControllers[bookId] = fresh;
    _lastControllerFetchBookId = bookId;
    return fresh;
  }

  ItemPositionsListener positionsListenerFor(String bookId) {
    return _itemPositionsListeners.putIfAbsent(bookId, () {
      final listener = ItemPositionsListener.create();
      void onPositionsChanged() => this.onPositionsChanged(bookId);
      _positionsListenerRefs[bookId] = onPositionsChanged;
      listener.itemPositions.addListener(onPositionsChanged);
      return listener;
    });
  }

  ScrollOffsetListener scrollOffsetListenerFor(String bookId) {
    return _scrollOffsetListeners.putIfAbsent(bookId, () {
      final listener = ScrollOffsetListener.create();
      _scrollOffsetSubs[bookId] = listener.changes.listen((delta) {
        onScrollOffsetChanged(bookId, delta);
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
  void onScrollOffsetChanged(String bookId, double delta) {
    if (!isMounted() || delta == 0) return;
    if (ref.read(readerTabsProvider).activeTab?.bookId != bookId) return;
    if (!isPhone()) return;

    // Suppress app bar collapse/expand for ALL programmatic scrolls,
    // not just the initial position restoration. This prevents TTS
    // auto-scroll, TOC jumps, search-result jumps, and Follow-TTS
    // button taps from accidentally hiding/showing the app bar.
    // Only real human finger scrolling should trigger this.
    if (isInitialJumpPending || suppressAppBarScroll) {
      developer.log(
        '[UI_SCROLL] book=$bookId delta=$delta SUPPRESSED by '
        '_isInitialJumpPending=$isInitialJumpPending '
        '_suppressAppBarScroll=$suppressAppBarScroll',
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
        if (appBarCollapsed.value) appBarCollapsed.value = false;
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
        'COLLAPSE (wasCollapsed=$appBarCollapsed)',
        name: 'epitaka.reader.ui',
      );
      _scrollAccum[bookId] = 0;
      if (!appBarCollapsed.value) appBarCollapsed.value = true;
    } else if (newAcc < -_kScrollThreshold) {
      developer.log(
        '[UI_SCROLL] book=$bookId delta=$delta acc=$acc→$newAcc '
        'EXPAND (wasCollapsed=$appBarCollapsed)',
        name: 'epitaka.reader.ui',
      );
      _scrollAccum[bookId] = 0;
      if (appBarCollapsed.value) appBarCollapsed.value = false;
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
  void onPositionsChanged(String bookId) {
    // ── Sheet-open guard: skip provider writes when a modal bottom sheet
    // is open. The dictionary and book-link sheets increment
    // dictionarySheetOpenProvider while open.
    final dictSheetOpen = ref.read(dictionarySheetOpenProvider);
    if (dictSheetOpen > 0) {
      return;
    }

    // ── ViewInsets guard: keyboard show/hide changes the viewport size,
    // which can trigger position callbacks that look like user scrolls.
    // Track the last known value and skip when it changes.
    final insetsBottom = viewInsetsBottom();
    if (insetsBottom != _lastViewInsets) {
      _lastViewInsets = insetsBottom;
      // Also force-expand app bar when keyboard dismisses (sheet closed)
      if (insetsBottom == 0 && appBarCollapsed.value) {
        appBarCollapsed.value = false;
        _scrollAccum[bookId] = 0;
      }
      return;
    }

    // Throttle: skip heavy work if called too frequently (e.g. every scroll frame)
    final now = DateTime.now();
    final shouldThrottle =
        _lastPositionThrottle != null &&
        now.difference(_lastPositionThrottle!) < _kPositionThrottleDuration;

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

    // Always track precise offset (local map, no rebuild cost)
    _preciseScrollOffset[bookId] = scrollOffset;

    // When throttled, skip all provider writes but keep _preciseScrollOffset
    if (shouldThrottle && _lastScrollParaId[bookId] != null) {
      // Still update visible range for selection auto-scroll
      if (visible.isNotEmpty) {
        ref
            .read(readerSelectionProvider.notifier)
            .updateVisibleRange(visible.first.index, visible.last.index);
      }
      if (topIndex == 0 && appBarCollapsed.value) {
        appBarCollapsed.value = false;
        _scrollAccum[bookId] = 0;
      }
      return;
    }
    _lastPositionThrottle = now;

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

        if (_lastScrollParaId[bookId] != visibleParaId) {
          final posSw = Stopwatch()..start();
          onFirstVisiblePosition?.call(bookId, topIndex, visibleParaId);
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

          // Detect manual scroll: if TTS is playing and this scroll was NOT
          // a TTS-initiated jump, disable auto-scroll. (Delegated to the TTS
          // controller via the injected hook.)
          onTtsManualScroll(bookId, visible, readerState.paragraphs);
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
      ref
          .read(readerSelectionProvider.notifier)
          .updateVisibleRange(visible.first.index, visible.last.index);
    }

    // Always force-expand at the very top of the document.
    if (topIndex == 0 && appBarCollapsed.value) {
      appBarCollapsed.value = false;
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
  Future<void> jumpToParagraph(
    String bookId,
    int paraId, {
    bool animate = true,
    double alignment = 0.0,
    int? lineId,
    int retryCount = 0,
  }) async {
    // Suppress app bar during this programmatic scroll
    suppressAppBarScroll = true;

    _pendingJumpParaId[bookId] = paraId;
    final int jumpToken = (_jumpTokens[bookId] ?? 0) + 1;
    _jumpTokens[bookId] = jumpToken;

    var state = ref.read(readerDataProvider(bookId));
    var index = state.paragraphs.indexWhere((p) => p.paraId == paraId);

    if (index < 0) {
      if (!state.isLoaded) {
        developer.log(
          '[JUMP] book=$bookId paraId=$paraId data still loading, waiting…',
          name: 'epitaka.reader',
        );
        try {
          await ref.read(readerDataProvider(bookId).notifier).waitUntilLoaded();
        } catch (_) {
          // Load was cancelled or the provider disposed before it finished —
          // bail out cleanly instead of leaving the jump flags pending
          // forever (which silently kills every later jump for this book).
          developer.log(
            '[JUMP] book=$bookId paraId=$paraId waitUntilLoaded failed — aborting jump',
            name: 'epitaka.reader',
          );
          _pendingJumpParaId.remove(bookId);
          isInitialJumpPending = false;
          suppressAppBarScroll = false;
          return;
        }
        if (!isMounted()) return;
        if (_pendingJumpParaId[bookId] != paraId) return;

        state = ref.read(readerDataProvider(bookId));
        index = state.paragraphs.indexWhere((p) => p.paraId == paraId);
      }
      if (index < 0) {
        developer.log(
          '[JUMP] book=$bookId paraId=$paraId not found (total=${state.paragraphs.length})',
          name: 'epitaka.reader',
        );
        _pendingJumpParaId.remove(bookId);
        isInitialJumpPending = false;
        suppressAppBarScroll = false;
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
        if (!isMounted()) return;
        jumpToParagraph(
          bookId,
          paraId,
          animate: animate,
          alignment: alignment,
          lineId: lineId,
          retryCount: retryCount + 1,
        ).then((_) {
          if (isMounted()) isInitialJumpPending = false;
        });
      });
      return;
    }

    final jumpStart = DateTime.now().millisecondsSinceEpoch;
    developer.log(
      '[JUMP] book=$bookId paraId=$paraId index=$index '
      'lineId=$lineId animate=$animate isInitialJumpPending=$isInitialJumpPending',
      name: 'epitaka.reader.ui',
    );

    // Resolve the target line. AI-generated citations can reference a line
    // that doesn't exist in this paragraph (search chunks span multiple
    // paragraphs) or a hallucinated number — this used to fall back to
    // alignment 0.0 and land the jump at the paragraph start. Snap to the
    // nearest real line so the fine-scroll still lands on actual text.
    final effectiveLineId = lineId != null && index >= 0
        ? _nearestLineId(state.paragraphs[index], lineId)
        : lineId;

    // NOTE: we deliberately do NOT register a per-line GlobalKey here (the
    // old approach). scrollable_positioned_list builds a second overlay list
    // during long-distance scrollTo transitions and both lists run the same
    // itemBuilder, so a GlobalKey inside the target paragraph gets mounted
    // in TWO live widgets at once → "Multiple widgets used the same
    // GlobalKey" → the jump crashes and silently lands at the paragraph
    // start. The fine-scroll below uses paragraph-geometry instead, which
    // never touches GlobalKeys and cannot conflict.

    // ── Paragraph-level scroll ────────────────────────────────────
    // When a lineId is provided, compute alignment from the line's
    // position within the paragraph so the target line appears at or
    // near the center of the viewport — not just the paragraph start.
    final useAlignment = () {
      if (effectiveLineId != null &&
          index >= 0 &&
          index < state.paragraphs.length) {
        final para = state.paragraphs[index];
        final lineIndex = para.lines.indexWhere(
          (l) => l.lineId == effectiveLineId,
        );
        if (lineIndex >= 0 && para.lines.length > 1) {
          // Place the target line near the top ~third of the viewport so
          // the spoken line is always built & visible, then the per-line
          // fine-scroll (Scrollable.ensureVisible alignment 0.3) corrects
          // to exactly 30%. For a paragraph roughly one screen tall the
          // line at fraction f sits at a*H_v + f*H_p, so choosing
          // a = 0.3 - f lands it at ~30% regardless of f (clamped so the
          // paragraph top never drops below the viewport top).
          //   first line → 0.30 (line at ~30% from top)
          //   middle     → ~0.15
          //   last line  → 0.0  (paragraph top at viewport top)
          final lineFraction = lineIndex / (para.lines.length - 1);
          return (0.3 - lineFraction).clamp(0.0, 0.3);
        }
      }
      return alignment;
    }();
    if (animate) {
      await controller.scrollTo(
        index: index,
        alignment: useAlignment,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      controller.jumpTo(index: index, alignment: useAlignment);
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
      'wasInitialJump=$isInitialJumpPending',
      name: 'epitaka.reader.ui',
    );

    // ── Precise line fine-scroll ──────────────────────────────────
    // The paragraph scroll above only positions the whole paragraph.
    // ScrollablePositionedList addresses whole items (paragraphs), not
    // individual lines, so citations previously landed at the paragraph
    // start. Estimate the line's position from the paragraph's rendered
    // span and re-scroll the paragraph so the line sits at ~30% of the
    // viewport. Geometry-based (no GlobalKeys) so it works in every
    // display mode and can never hit the dual-list GlobalKey collision
    // that used to crash line jumps mid-scroll. Jump flags stay
    // suppressed until this fine-scroll finishes.
    if (effectiveLineId != null) {
      _fineScrollByGeometry(
        bookId,
        index,
        effectiveLineId,
        jumpToken: jumpToken,
      );
    } else if (isMounted()) {
      // Programmatic scroll done — clear flags.
      // Use addPostFrameCallback so any in-flight scroll offset
      // notifications from this jump's paragraph scroll are still
      // suppressed.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isMounted()) {
          developer.log(
            '[JUMP] book=$bookId clearing _isInitialJumpPending',
            name: 'epitaka.reader.ui',
          );
          isInitialJumpPending = false;
          suppressAppBarScroll = false;
        }
      });
    }
  }

  /// Allocate a fresh jump token for [bookId] so a stale fine-scroll from a
  /// superseded jump can never clear a newer jump's flags.
  int nextJumpToken(String bookId) {
    final token = (_jumpTokens[bookId] ?? 0) + 1;
    _jumpTokens[bookId] = token;
    return token;
  }

  /// Snap an AI-cited [lineId] to the nearest real line of [para].
  ///
  /// Citation line numbers come from the model and may reference a line
  /// outside this paragraph (search chunks span multiple paragraphs) or a
  /// hallucinated number. Falling back to the raw id previously made the
  /// alignment computation fail and land the jump at the paragraph start.
  int _nearestLineId(ParagraphData para, int lineId) {
    if (para.lines.isEmpty) return lineId;
    if (para.lines.any((l) => l.lineId == lineId)) return lineId;
    var best = para.lines.first;
    var bestDist = (best.lineId - lineId).abs();
    for (final l in para.lines.skip(1)) {
      final dist = (l.lineId - lineId).abs();
      if (dist < bestDist) {
        best = l;
        bestDist = dist;
      }
    }
    developer.log(
      '[JUMP] line=$lineId not in paragraph; snapped to line=${best.lineId}',
      name: 'epitaka.reader.ui',
    );
    return best.lineId;
  }

  /// Precise scroll to a specific line inside the just-scrolled paragraph.
  ///
  /// [jumpToParagraph] scrolls to the containing paragraph, but
  /// ScrollablePositionedList can only address whole items (paragraphs),
  /// not individual lines within them. The per-line GlobalKey registered
  /// via [ttsSyncProvider] is used with `Scrollable.ensureVisible` so the
  /// cited line lands at ~30% of the viewport instead of the paragraph
  /// start. The line widget may not be laid out yet, so this retries for a
  /// few frames until it becomes available.
  void fineScrollToLine(
    String bookId,
    int lineId, {
    required int jumpToken,
    int retryCount = 0,
  }) {
    final key = ref.read(ttsSyncProvider(bookId)).ttsTargetLineKeys[lineId];
    if (key == null) {
      // Key already consumed (fine-scroll done) or superseded by a newer
      // jump — nothing to scroll; make sure flags aren't left hanging.
      _finishJumpFlags(bookId, jumpToken);
      return;
    }
    final lineContext = key.currentContext;
    if (lineContext == null || !lineContext.mounted) {
      // Line widget not laid out yet — retry next frame.
      if (retryCount >= _kMaxLineScrollRetries) {
        ref.read(ttsSyncProvider(bookId).notifier).removeTargetLineKey(lineId);
        _finishJumpFlags(bookId, jumpToken);
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!isMounted()) return;
        fineScrollToLine(
          bookId,
          lineId,
          jumpToken: jumpToken,
          retryCount: retryCount + 1,
        );
      });
      return;
    }
    developer.log(
      '[JUMP] book=$bookId fine-scroll to line=$lineId',
      name: 'epitaka.reader.ui',
    );
    Scrollable.ensureVisible(
      lineContext,
      alignment: 0.3,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    ).then((_) {
      if (!isMounted()) return;
      ref.read(ttsSyncProvider(bookId).notifier).removeTargetLineKey(lineId);
      _finishJumpFlags(bookId, jumpToken);
    });
  }

  /// Fine-scroll to [lineId] without per-line widgets (side-by-side /
  /// hideJoinLines display modes, where [fineScrollToLine] can never attach
  /// its GlobalKey).
  ///
  /// The item positions report the target paragraph's rendered fraction of
  /// the viewport (`[itemLeadingEdge, itemTrailingEdge]`); the line's top is
  /// estimated at `lineIndex/lineCount` through that span, and the paragraph
  /// is re-scrolled so the estimate lands at ~30% of the viewport. This is
  /// exact for uniform-height lines and a good approximation for wrapped
  /// ones — far better than always landing at the paragraph start.
  void _fineScrollByGeometry(
    String bookId,
    int paraIndex,
    int lineId, {
    required int jumpToken,
    int retryCount = 0,
  }) {
    void finish() => _finishJumpFlags(bookId, jumpToken);

    final readerState = ref.read(readerDataProvider(bookId));
    if (paraIndex < 0 || paraIndex >= readerState.paragraphs.length) {
      finish();
      return;
    }
    final para = readerState.paragraphs[paraIndex];
    final lineIndex = para.lines.indexWhere((l) => l.lineId == lineId);
    if (lineIndex < 0 || para.lines.length <= 1) {
      // Line not in this paragraph (or a single-line paragraph): the
      // paragraph-level alignment already placed it — nothing to refine.
      finish();
      return;
    }

    final positions = _itemPositionsListeners[bookId]?.itemPositions.value;
    ItemPosition? pos;
    if (positions != null) {
      for (final p in positions) {
        if (p.index == paraIndex) {
          pos = p;
          break;
        }
      }
    }
    if (pos == null) {
      // Paragraph not laid out yet — retry a few frames, then give up
      // (same bounded retry as [fineScrollToLine]).
      if (retryCount >= _kMaxLineScrollRetries) {
        finish();
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!isMounted()) return;
        _fineScrollByGeometry(
          bookId,
          paraIndex,
          lineId,
          jumpToken: jumpToken,
          retryCount: retryCount + 1,
        );
      });
      return;
    }

    // The paragraph occupies [leading, trailing] as a fraction of the
    // viewport. Estimate the line's top fraction, then compute the item
    // alignment that moves it to ~30% (scrolling the item to alignment `a`
    // shifts every point in it by `a - leading`).
    final span = pos.itemTrailingEdge - pos.itemLeadingEdge;
    final lineFraction = lineIndex / para.lines.length;
    final targetAlignment = (0.3 - lineFraction * span).clamp(-1.0, 1.0);

    debugPrint(
      '[JUMP-GEO] book=$bookId line=$lineId lineIndex=$lineIndex '
      'lineFraction=$lineFraction alignment=$targetAlignment '
      'leading=${pos.itemLeadingEdge.toStringAsFixed(3)} '
      'trailing=${pos.itemTrailingEdge.toStringAsFixed(3)} '
      'span=${span.toStringAsFixed(3)}',
    );
    _itemScrollControllers[bookId]?.scrollTo(
      index: paraIndex,
      alignment: targetAlignment,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    ).whenComplete(finish);
  }

  /// Clears the initial-jump pending flag and app-bar scroll suppression
  /// after a programmatic jump (and any fine-scroll) finishes. Only acts if
  /// [jumpToken] is still the latest token for [bookId], so a stale
  /// fine-scroll from a superseded jump can't clobber a newer jump's flags.
  void _finishJumpFlags(String bookId, int jumpToken) {
    if (!isMounted()) return;
    if (_jumpTokens[bookId] != jumpToken) return;
    developer.log(
      '[JUMP] book=$bookId clearing _isInitialJumpPending (fine-scroll done)',
      name: 'epitaka.reader.ui',
    );
    isInitialJumpPending = false;
    suppressAppBarScroll = false;
  }

  /// Get the paraId of the paragraph the user is actually reading: the first
  /// paragraph whose leading edge is >= 0.0 (top fully scrolled past the
  /// viewport top). See [getCurrentParaId] for why 0.0 rather than the
  /// topmost visible paragraph.
  int? currentParaId(String bookId) {
    final positions =
        _itemPositionsListeners[bookId]?.itemPositions.value;
    final readerState = ref.read(readerDataProvider(bookId));
    return getCurrentParaId(positions, readerState, threshold: 0.0);
  }

  // ── Reading History ──────────────────────────────────────────────────

  /// Persist the current reading position (best-effort; failures are
  /// silent — history is non-critical).
  Future<void> saveReadingHistory(
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
      if (!isMounted()) return;
      saveReadingHistory(bookId, bookName);
    });
  }

  /// Cancel timers and detach all per-book listeners/subscriptions.
  void dispose() {
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
  }
}
