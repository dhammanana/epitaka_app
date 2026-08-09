import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:drift/drift.dart' show Variable;

import '../../../core/providers/app_db_provider.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/pali_script_converter.dart';
import '../../../core/utils/platform_info.dart';
import '../../../core/utils/responsive_breakpoint.dart';
import '../../../shared/providers/side_panel_provider.dart';
import '../../../shared/utils/app_shortcuts.dart';
import '../../../shared/utils/reading_clipboard.dart';
import '../../../shared/widgets/reader_toolbar_controller.dart';
import '../../../features/ai_qa/providers/ai_qa_provider.dart' show aiQaInitialPromptProvider;
import '../../dictionary/providers/dictionary_sheet_open_provider.dart';
import '../../dictionary/widgets/dictionary_open.dart';
import '../../dictionary/widgets/dictionary_sheet.dart';
import '../../library/screens/library_screen.dart';
import '../../library/widgets/library_dialog.dart';
import '../../settings/providers/tts_provider.dart';
import '../../settings/providers/tts_replacements_provider.dart';
import '../../settings/widgets/settings_dialog.dart';
import '../providers/reader_provider.dart';
import '../providers/reader_search_notifier.dart';
import '../providers/reader_selection_notifier.dart';
import '../providers/reader_tabs_provider.dart';
import '../providers/reader_tts_sync_provider.dart';
import '../providers/tts_reading_provider.dart';
import '../services/reader_copy_service.dart';
import '../utils/reader_word_hit_test.dart' show wordRangeAt;
import '../widgets/bookmark_dialog.dart';
import '../widgets/display_layout_popup.dart';
import '../widgets/jump_sheet.dart';
import '../widgets/reader_app_bar.dart';
import '../widgets/reader_bottom_toolbar.dart';
import '../widgets/reader_content_with_selection.dart';
import '../widgets/reader_drag_thumb.dart';
import '../widgets/reader_in_book_search_bar.dart';
import '../widgets/reader_tts_widgets.dart';
import '../widgets/tab_strip.dart';

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

  /// (dx, timestamp-ms) samples captured during an in-progress swipe, used
  /// to estimate a fling velocity on release. Raw pointer events carry no
  /// velocity, so without this a quick flick could never commit a tab
  /// switch — only slow drags past the distance threshold would. This
  /// restores the fling behaviour the old GestureDetector-based swipe had
  /// (its [DragEndDetails] came with a real [Velocity]).
  final List<({double dx, int ms})> _swipeSamples = [];

  /// Time window (ms) used to estimate fling velocity on release.
  static const int _kSwipeVelocityWindowMs = 120;

  /// Fling speed (px/s) that commits a tab switch even for short travel.
  static const double _kSwipeFlingVelocity = 500;

  /// Fraction of screen width a slow drag must cover to commit.
  static const double _kSwipeCommitFraction = 0.2;

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

  // Monotonic token per book so a stale fine-scroll from a superseded jump
  // can never clear jump flags while a newer jump is in progress.
  final Map<String, int> _jumpTokens = {};

  // App lifecycle state for background TTS optimization
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  /// Reader display mode before TTS started, restored when reading stops.
  ///
  /// TTS temporarily forces [TranslationDisplayMode.lineByLine] because it
  /// is the only display mode that renders per-line widgets — and therefore
  /// the only one where the per-line GlobalKeys used by the fine-scroll
  /// ([_fineScrollToLine]) can be attached. null = TTS is not forcing a mode.
  TranslationDisplayMode? _ttsModeBefore;

  // Silverbar: collapsible app bar on scroll
  // Using ValueNotifier so only the app bar/toolbar rebuild, not the full screen.
  final ValueNotifier<bool> _appBarCollapsed = ValueNotifier(false);

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

  /// Last known viewInsets.bottom — used to detect keyboard-triggered
  /// layout changes (which fire _onPositionsChanged but are not real
  /// user scrolls). When the keyboard shows/hides while a modal bottom
  /// sheet is open, the viewport shrinks/grows and the scrollable list
  /// reports new positions — we skip those to avoid unwanted scroll saves
  /// and TTS-auto-scroll disabling.
  double _lastViewInsets = 0;

  /// Throttle: skip _onPositionsChanged heavy work if called too frequently.
  DateTime? _lastPositionThrottle;
  static const Duration _kPositionThrottleDuration = Duration(milliseconds: 50);

  /// Millis counter for tab-switch timing breakdown.
  /// Reset at the start of build() when a different tab becomes active.
  int? _tabSwitchStartMs;

  /// The bookId of the active tab at the previous build().
  /// Used to detect tab switches and start _tabSwitchStartMs.
  String? _lastBuildBookId;

  // ── In-book search state lives in [inBookSearchProvider] ─────────────

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

  // ── Toolbar actions ──────────────────────────────────────────────────
  //
  // Single source of truth for the reader's toolbar actions. Both the mobile
  // floating pill and the desktop status bar (via [ReaderToolbarController])
  // invoke these, so behavior can never drift between the two UIs. They
  // resolve the current active tab / reader state from providers at call
  // time (never capturing stale build-scope values), which also keeps the
  // status bar's [ReaderToolbarController.update] from firing on every
  // reader rebuild (method tear-offs are identity-stable).

  ReaderTabInfo? _toolbarActiveTab() {
    return ref.read(readerTabsProvider).activeTab;
  }

  ReaderDataState _toolbarReaderState(ReaderTabInfo tab) {
    return ref.read(readerDataProvider(tab.bookId));
  }

  void _handleToolbarContents() {
    final activeTab = _toolbarActiveTab();
    if (activeTab == null) return;
    if (ResponsiveBreakpoint.isDesktop(context)) {
      // Desktop: open the dockable contents panel instead of pushing a
      // full screen over the shell.
      ref.read(sidePanelProvider.notifier).toggle(SidePanelType.contents);
      return;
    }
    final readerState = _toolbarReaderState(activeTab);
    // The TOC must highlight the section the reader is actually in. Use the
    // live position (first paragraph fully past the viewport top) rather
    // than the tab's topmost-visible paragraph: after jumping to a heading
    // the target sits a few percent below the top, so the topmost visible
    // paragraph is the one ABOVE the jump target and the TOC would
    // highlight the wrong section.
    final currentParaId =
        _getCurrentParaId(activeTab.bookId) ?? activeTab.currentParaId;
    var url =
        '/contents/${activeTab.bookId}?bookName=${Uri.encodeComponent(readerState.bookName ?? activeTab.bookId)}';
    if (currentParaId != null) {
      url += '&currentParaId=$currentParaId';
    }
    context.push(url);
  }

  void _handleToolbarSearch() => _toggleInBookSearch();

  void _handleToolbarDictionary() {
    if (!PlatformInfo.isDesktop) {
      // Mobile: the dictionary is a modal bottom sheet — easy to close
      // with the back button, by pulling it down, or by tapping outside.
      showDictionarySheet(context, '');
      return;
    }
    final notifier = ref.read(sidePanelProvider.notifier);
    if (ref.read(sidePanelProvider).right.openPanel ==
        SidePanelType.dictionary) {
      notifier.close(SidePanelType.dictionary);
      return;
    }
    // Open the docked panel and focus its search field (desktop).
    notifier.open(SidePanelType.dictionary, autoFocus: true);
  }

  void _handleToolbarJump() {
    final activeTab = _toolbarActiveTab();
    if (activeTab == null) return;
    _onJumpTap(activeTab, _toolbarReaderState(activeTab));
  }

  void _handleToolbarDisplayLayout() {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      builder: (_) => const Align(
        alignment: Alignment(0, 0.88),
        child: DisplayLayoutPopup(),
      ),
    );
  }

  Future<void> _handleToolbarListen() async {
    final activeTab = _toolbarActiveTab();
    if (activeTab == null) return;
    final readerState = _toolbarReaderState(activeTab);

    final positions =
        _itemPositionsListeners[activeTab.bookId]?.itemPositions.value;
    int startParaIndex = 0;
    if (positions != null && positions.isNotEmpty) {
      final visible =
          positions
              .where((p) => p.itemTrailingEdge > 0)
              .toList()
            ..sort(
              (a, b) => a.itemLeadingEdge.compareTo(b.itemLeadingEdge),
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
    final enabledLangs =
        ref.read(settingsProvider).visibleTranslationLangs;
    final lang = enabledLangs.isNotEmpty ? enabledLangs.first : null;
    if (lang == null) return;

    // Load TTS replacements
    final replaceAsyncState = ref.read(ttsReplacementsNotifierProvider);
    if (replaceAsyncState is AsyncLoading ||
        replaceAsyncState is AsyncError) {
      await ref.read(ttsReplacementsNotifierProvider.notifier).load();
    }
    final activeReplacements = ref.read(activeTtsReplacementsProvider);

    for (int i = startParaIndex; i < readerState.paragraphs.length; i++) {
      final para = readerState.paragraphs[i];
      for (final line in para.lines) {
        final rawText = line.translations[lang] ?? '';
        final stripped = stripHtmlForTts(rawText);
        var text = stripped;
        for (final rule in activeReplacements) {
          try {
            if (rule.isRegex) {
              text = text.replaceAll(RegExp(rule.pattern), rule.replacement);
            } else {
              text = text.replaceAll(rule.pattern, rule.replacement);
            }
          } catch (_) {}
        }
        lines.add(
          TtsLineItem(paraId: para.paraId, lineId: line.lineId, text: text),
        );
      }
    }

    if (lines.isNotEmpty) {
      // Cache the book name so the Android notification shows a
      // human-readable title instead of the raw bookId.
      TtsReadingNotifier.cacheBookName(
        activeTab.bookId,
        readerState.bookName ?? activeTab.bookId,
      );
      ref
          .read(ttsReadingProvider.notifier)
          .startReading(activeTab.bookId, lines);
    }
  }

  void _handleToolbarStop() {
    ref.read(ttsReadingProvider.notifier).stopReading();
  }

  void _handleToolbarBookmark() {
    final activeTab = _toolbarActiveTab();
    if (activeTab == null) return;
    _onBookmarkTap(activeTab, _toolbarReaderState(activeTab));
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
        if (_appBarCollapsed.value) _appBarCollapsed.value = false;
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
      if (!_appBarCollapsed.value) _appBarCollapsed.value = true;
    } else if (newAcc < -_kScrollThreshold) {
      developer.log(
        '[UI_SCROLL] book=$bookId delta=$delta acc=$acc→$newAcc '
        'EXPAND (wasCollapsed=$_appBarCollapsed)',
        name: 'epitaka.reader.ui',
      );
      _scrollAccum[bookId] = 0;
      if (_appBarCollapsed.value) _appBarCollapsed.value = false;
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
    final insetsBottom = MediaQuery.of(context).viewInsets.bottom;
    if (insetsBottom != _lastViewInsets) {
      _lastViewInsets = insetsBottom;
      // Also force-expand app bar when keyboard dismisses (sheet closed)
      if (insetsBottom == 0 && _appBarCollapsed.value) {
        _appBarCollapsed.value = false;
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
      if (topIndex == 0 && _appBarCollapsed.value) {
        _appBarCollapsed.value = false;
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
          if (_tabSwitchStartMs != null) {
            final posElapsed =
                DateTime.now().millisecondsSinceEpoch - _tabSwitchStartMs!;
            developer.log(
              '[TAB_SW] book=$bookId FIRST visible position in ${posElapsed}ms '
              'topIndex=$topIndex paraId=$visibleParaId',
              name: 'epitaka.reader.ui',
            );
            _tabSwitchStartMs = null; // one-shot
          }
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
                  ref
                      .read(ttsSyncProvider(bookId).notifier)
                      .disableAutoScroll();
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
      ref
          .read(readerSelectionProvider.notifier)
          .updateVisibleRange(visible.first.index, visible.last.index);
    }

    // Always force-expand at the very top of the document.
    if (topIndex == 0 && _appBarCollapsed.value) {
      _appBarCollapsed.value = false;
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

    // Always update the last-jumped paraId so that the next
    // _jumpToParagraph call has fresh state.
    _lastJumpedParaId[bookId] = paraId;

    // Resolve the target line. AI-generated citations can reference a line
    // that doesn't exist in this paragraph (search chunks span multiple
    // paragraphs) or a hallucinated number — this used to fall back to
    // alignment 0.0 and land the jump at the paragraph start. Snap to the
    // nearest real line so the fine-scroll still lands on actual text.
    final effectiveLineId = lineId != null && index >= 0
        ? _nearestLineId(state.paragraphs[index], lineId)
        : lineId;

    // Issue 4: Create a GlobalKey for the target line so
    // Scrollable.ensureVisible can precisely scroll it into view.
    // Must call setState so the widget rebuilds with the new lineKeys.
    // Uses ttsSyncProvider as single source of truth for TTS scroll state.
    //
    // Fix: Clear any stale target line keys FIRST so that a subsequent jump
    // from rapid TTS advancement doesn't leave orphaned keys from the
    // previous jump. Then set the new key for the current line.
    if (effectiveLineId != null) {
      final ttsSyncNotifier = ref.read(ttsSyncProvider(bookId).notifier);
      ttsSyncNotifier.clearTargetLineKeys();
      ttsSyncNotifier.setTargetParaId(paraId);
      ttsSyncNotifier.setTargetLineKey(effectiveLineId, GlobalKey());
      if (mounted) setState(() {});
    }

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
      'wasInitialJump=$_isInitialJumpPending',
      name: 'epitaka.reader.ui',
    );

    // ── Precise line fine-scroll ──────────────────────────────────
    // The paragraph scroll above only positions the whole paragraph.
    // ScrollablePositionedList addresses whole items (paragraphs), not
    // individual lines, so citations previously landed at the paragraph
    // start. Use the line's GlobalKey to precisely bring the cited line
    // to ~30% of the viewport. Jump flags stay suppressed until this
    // fine-scroll finishes.
    if (effectiveLineId != null) {
      _fineScrollToLine(bookId, effectiveLineId, jumpToken: jumpToken);
    } else if (mounted) {
      // Programmatic scroll done — clear flags.
      // Use addPostFrameCallback so any in-flight scroll offset
      // notifications from this jump's paragraph scroll are still
      // suppressed.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          developer.log(
            '[JUMP] book=$bookId clearing _isInitialJumpPending',
            name: 'epitaka.reader.ui',
          );
          _isInitialJumpPending = false;
          _suppressAppBarScroll = false;
        }
      });
    }
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
  /// [_jumpToParagraph] scrolls to the containing paragraph, but
  /// ScrollablePositionedList can only address whole items (paragraphs),
  /// not individual lines within them. The per-line GlobalKey registered
  /// via [ttsSyncProvider] is used with `Scrollable.ensureVisible` so the
  /// cited line lands at ~30% of the viewport instead of the paragraph
  /// start. The line widget may not be laid out yet, so this retries for a
  /// few frames until it becomes available.
  void _fineScrollToLine(
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
        if (!mounted) return;
        _fineScrollToLine(
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
      if (!mounted) return;
      ref.read(ttsSyncProvider(bookId).notifier).removeTargetLineKey(lineId);
      _finishJumpFlags(bookId, jumpToken);
    });
  }

  /// Clears the initial-jump pending flag and app-bar scroll suppression
  /// after a programmatic jump (and any fine-scroll) finishes. Only acts if
  /// [jumpToken] is still the latest token for [bookId], so a stale
  /// fine-scroll from a superseded jump can't clobber a newer jump's flags.
  void _finishJumpFlags(String bookId, int jumpToken) {
    if (!mounted) return;
    if (_jumpTokens[bookId] != jumpToken) return;
    developer.log(
      '[JUMP] book=$bookId clearing _isInitialJumpPending (fine-scroll done)',
      name: 'epitaka.reader.ui',
    );
    _isInitialJumpPending = false;
    _suppressAppBarScroll = false;
  }

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

    // Commit on either a quick fling (the natural swipe gesture) or a slow
    // drag past [_kSwipeCommitFraction] of the screen width.
    final committed =
        target != null &&
        (_dragDxNotifier.value.abs() > width * _kSwipeCommitFraction ||
            velocity.abs() > _kSwipeFlingVelocity);

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

  /// Get the paraId of the paragraph the user is actually reading.
  ///
  /// This uses the item positions listener to find the first paragraph
  /// whose leading edge is >= 0.0, i.e. whose top has fully scrolled past
  /// the top of the viewport.
  ///
  /// Why not the topmost visible paragraph? After a programmatic jump the
  /// target paragraph is placed a few percent below the top (alignment
  /// 0.05), so the PREVIOUS paragraph still peeks in at the very top and
  /// would be reported as "topmost". Feeding that into the table of
  /// contents highlighted the section ABOVE the one jumped to. The first
  /// paragraph past the viewport top is the one whose text actually fills
  /// the screen, which is what the TOC / jump sheet / bookmark naming
  /// should reflect.
  int? _getCurrentParaId(String bookId) {
    final listener = _itemPositionsListeners[bookId];
    final positions = listener?.itemPositions.value;
    if (positions == null || positions.isEmpty) return null;

    final visible = positions.where((p) => p.itemTrailingEdge > 0).toList()
      ..sort((a, b) => a.itemLeadingEdge.compareTo(b.itemLeadingEdge));

    if (visible.isEmpty) return null;

    // Find the first paragraph with leading edge >= 0.0
    int? targetIndex;
    for (final pos in visible) {
      if (pos.itemLeadingEdge >= 0.0) {
        targetIndex = pos.index;
        break;
      }
    }
    // Fallback to the topmost visible paragraph (e.g. a paragraph taller
    // than the viewport, or scrolled to the very end of the book).
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
    // Route the lookup into the dictionary dock/panel FIRST — the
    // dictionary must receive the word before any selection is cleared
    // (clearing first broke lookups and triggered framework assertions).
    openDictionaryInPanel(context, ref, word);
    _lastLookedUpWord = null;
    // Clear any pre-existing selection right away (the dictionary already
    // has the word by now). Leftover selections from THIS double-tap are
    // handled event-driven in [_handleSelectionChanged] (the framework
    // creates its word selection after the sheet is already open) and the
    // context menu is suppressed in [_buildCopyContextMenu].
    _selectableRegionKey.currentState?.clearSelection();
  }

  void _handleSelectionChanged(SelectedContent? selection) {
    ref.read(readerSelectionProvider.notifier).onSelectionChanged(selection);
    developer.log(
      '[DBG] onSelectionChanged plain="${selection?.plainText}" '
      'hasSelection=${selection != null}',
      name: 'epitaka.dict',
    );

    // When a modal dictionary/book-link sheet is open, any NEW selection
    // reported here is a leftover from the double-tap that opened it: the
    // sheet is pushed on the second tap's pointer-*down*, while
    // SelectionArea creates its word selection on that same gesture *after*
    // the push (and shows its context menu on the pointer-up). Clearing it
    // here — the instant it appears — keeps the selection highlight and its
    // context menu from ever covering the sheet. This is event-driven, so it
    // works regardless of when the framework happens to land the selection
    // (the earlier pointer-up + post-frame flag approach was timing-sensitive
    // and missed the second and later double-taps). Desktop is unaffected:
    // the sheet-open counter stays 0 there.
    //
    // The dictionary has already received the word by this point (the lookup
    // runs before any selection can exist), so clearing can't race the lookup.
    if (selection != null && ref.read(dictionarySheetOpenProvider) > 0) {
      _selectableRegionKey.currentState?.clearSelection();
    }

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
      _swipeSamples.clear();
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

    // Extract the word with a script-aware expansion instead of
    // [RenderParagraph.getWordBoundary], which splits words in scripts like
    // Myanmar/Thai/Tamil (e.g. "ဘဂဝတော" → "ဘ","ဂ","ဝ","တော") and would
    // look up only part of the word.
    final textPosition = paragraph.getPositionForOffset(localInParagraph);
    final fullText = paragraph.text.toPlainText();
    final range = wordRangeAt(fullText, textPosition.offset);
    if (range.isCollapsed) return;
    final rawWord = fullText.substring(range.start, range.end);
    developer.log(
      '[DBG] _selectWordAt: rawWord="$rawWord" range=$range',
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
      _swipeSamples.clear();
      _swipeSamples.add((dx: dx, ms: event.timeStamp.inMilliseconds));
      _onDragStart(
        DragStartDetails(
          globalPosition: event.position,
          localPosition: event.localPosition,
        ),
      );
      return;
    }

    final deltaDx = dx - _lastSwipeDx;
    _lastSwipeDx = dx;
    _swipeSamples.add((dx: dx, ms: event.timeStamp.inMilliseconds));

    if (deltaDx != 0) {
      _onDragUpdate(
        DragUpdateDetails(
          delta: Offset(deltaDx, 0),
          globalPosition: event.position,
          localPosition: event.localPosition,
        ),
      );
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
      final intensity = 1.0 - (clampedY / _kAutoScrollEdgeThreshold);
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
    _autoScrollTimer ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
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
    });
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
  /// A cancelled gesture never commits a tab switch — see [_finishTabSwipe].
  void _handlePointerCancelForTabSwipe(PointerCancelEvent event) {
    _finishTabSwipe(cancelled: true);
  }

  /// Estimate horizontal fling velocity (px/s, negative = left) from the
  /// raw pointer samples of the swipe currently in progress. Uses the
  /// movement over the last ~120ms so a quick flick registers as a fast
  /// fling even when its total travel is short.
  double _estimateSwipeVelocity() {
    if (_swipeSamples.length < 2) return 0;
    final last = _swipeSamples.last;
    final cutoff = last.ms - _kSwipeVelocityWindowMs;
    while (_swipeSamples.length > 1 && _swipeSamples.first.ms < cutoff) {
      _swipeSamples.removeAt(0);
    }
    if (_swipeSamples.length < 2) return 0;
    final first = _swipeSamples.first;
    final dtMs = last.ms - first.ms;
    if (dtMs <= 0) return 0;
    return (last.dx - first.dx) / (dtMs / 1000.0);
  }

  /// Common cleanup for tab-swipe completion/cancellation.
  /// A fling velocity is estimated from the raw pointer samples so quick
  /// flicks commit a tab switch, not just slow drags past the distance
  /// threshold. A [cancelled] gesture (system back-swipe, notification
  /// shade, …) must never switch tabs — it always snaps back.
  void _finishTabSwipe({bool cancelled = false}) {
    _stopAutoScroll();
    if (_isSwiping) {
      if (cancelled) {
        _isDragging = false;
        _dragTargetIndex = null;
        _animateSettle(from: _dragDxNotifier.value, to: 0);
      } else {
        final velocity = _estimateSwipeVelocity();
        _onDragEnd(
          DragEndDetails(
            velocity: Velocity(pixelsPerSecond: Offset(velocity, 0)),
            primaryVelocity: velocity,
          ),
        );
      }
    }
    _swipeStartPos = null;
    _isSwiping = false;
    _lastSwipeDx = 0;
    _swipeSamples.clear();
  }

  String _cleanPali(String text) {
    return text.replaceAll(RegExp(r'[^\wāīūōṅñṭḍṇḷṃĀĪŪŌṄÑṬḌṆḶṀ\s]'), '').trim();
  }

  // ── Copy with style ──────────────────────────────────────────────────

  /// Called when user taps "Explain" in the context menu.
  /// Sends the selected text to Vimaṃsa AI asking for explanation.
  /// The AI uses its get_commentaries tool to fetch relevant context
  /// (Aṭṭhakathā and Ṭīkā) from the current section.
  void _onExplainTap() {
    final activeTab = ref.read(readerTabsProvider).activeTab;
    if (activeTab == null) return;

    final selectionState = ref.read(readerSelectionProvider);
    final selectedText =
        selectionState.lastSelectedContent?.plainText.trim() ?? '';
    if (selectedText.isEmpty) return;

    final readerState = ref.read(readerDataProvider(activeTab.bookId));
    final bookName = readerState.bookName ?? activeTab.bookId;
    final currentParaId = activeTab.currentParaId;

    _stageExplainPrompt(activeTab, selectedText, bookName, currentParaId);
  }

  /// Gather heading context and stage the explain prompt.
  void _stageExplainPrompt(
    ReaderTabInfo activeTab,
    String selectedText,
    String bookName,
    int? currentParaId,
  ) async {
    // Query the level=10 heading (section title) from the database
    String headingContext = '';
    if (currentParaId != null) {
      try {
        final db = await ref.read(epitakaDbProvider.future);
        final rows = await db.customSelect(
          'SELECT title FROM headings '
          'WHERE book_id = ? AND para_id <= ? AND level = 10 '
          'ORDER BY para_id DESC LIMIT 1',
          variables: [
            Variable.withString(activeTab.bookId),
            Variable.withInt(currentParaId),
          ],
        ).get();
        if (rows.isNotEmpty) {
          final title = rows.first.data['title'] as String?;
          if (title != null && title.isNotEmpty) {
            headingContext = 'Section heading: "$title" (para_id=$currentParaId)\n';
          }
        }
      } catch (_) {
        // Silently ignore DB errors
      }
    }

    final paraIdStr = currentParaId != null ? ' at para_id=$currentParaId' : '';
    final prompt =
        'Explain this passage from $bookName (${activeTab.bookId}).\n'
        '${headingContext}'
        'Use the get_commentaries tool to fetch the relevant '
        'commentaries (Aṭṭhakathā and Ṭīkā) for this section$paraIdStr.\n\n'
        'Focus on explaining the selected text below, using the '
        'broader section context and commentaries as reference:\n\n'
        '$selectedText';

    ref.read(aiQaInitialPromptProvider.notifier).state = prompt;
    if (context.mounted) context.push('/ai-qa');
  }

  /// Called when user taps "Summarize Ch." in the context menu.
  /// Builds the current chapter/section content and sends to Vimaṃsa AI.
  void _onSummarizeChapterTap() {
    final activeTab = ref.read(readerTabsProvider).activeTab;
    if (activeTab == null) return;

    final readerState = ref.read(readerDataProvider(activeTab.bookId));
    final paragraphs = readerState.paragraphs;
    if (paragraphs.isEmpty) return;

    final bookName = readerState.bookName ?? activeTab.bookId;
    final currentParaId = activeTab.currentParaId;
    if (currentParaId == null) return;

    // Find the section start (nearest heading at or before currentParaId)
    int sectionStart = 0;
    String? headingTitle;
    for (int i = paragraphs.length - 1; i >= 0; i--) {
      final p = paragraphs[i];
      if (p.paraId <= currentParaId && p.heading != null) {
        sectionStart = i;
        headingTitle = p.heading!.title;
        break;
      }
    }

    // Find the section end (next heading after sectionStart)
    int sectionEnd = paragraphs.length;
    for (int i = sectionStart + 1; i < paragraphs.length; i++) {
      if (paragraphs[i].heading != null) {
        sectionEnd = i;
        break;
      }
    }

    // Cap at 150 paragraphs to avoid sending too much content
    const int maxParagraphs = 150;
    if (sectionEnd - sectionStart > maxParagraphs) {
      sectionEnd = sectionStart + maxParagraphs;
    }

    // Build the chapter text
    final buf = StringBuffer();
    buf.writeln('Book: $bookName');
    if (headingTitle != null && headingTitle.isNotEmpty) {
      buf.writeln('Section: $headingTitle');
    }
    buf.writeln('');

    for (int i = sectionStart; i < sectionEnd; i++) {
      final para = paragraphs[i];
      for (final line in para.lines) {
        if (line.paliText != null && line.paliText!.trim().isNotEmpty) {
          buf.writeln(ReaderCopyService.stripTags(line.paliText!.trim()));
        }
        for (final entry in line.translations.entries) {
          if (entry.value.trim().isNotEmpty) {
            buf.writeln(ReaderCopyService.stripTags(entry.value.trim()));
          }
        }
      }
      if (i < sectionEnd - 1) buf.writeln();
    }

    final chapterText = buf.toString().trim();
    if (chapterText.isEmpty) return;

    final prompt =
        'Please summarize this chapter from $bookName. '
        'Include the key teachings, main points, and structure:\n\n$chapterText';

    ref.read(aiQaInitialPromptProvider.notifier).state = prompt;
    context.push('/ai-qa');
  }

  Widget _buildCopyContextMenu(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    // While a modal dictionary/book-link sheet is open, SelectionArea builds
    // this menu on the double-tap's pointer-up — a leftover of the tap that
    // already pushed the sheet on the pointer-down. Never render it: it would
    // pop up over the sheet. The leftover selection itself is cleared by the
    // guard in [_handleSelectionChanged]. Desktop is unaffected (the sheet
    // counter stays 0 there, and double-click menus are not shown anyway).
    if (ref.read(dictionarySheetOpenProvider) > 0) {
      return const SizedBox.shrink();
    }

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
      // Let the Dictionary context-menu item hit-test the render tree at
      // the toolbar anchor — the same word lookup the double-tap performs.
      contentHitTestKey: _contentHitTestKey,
      onExplainTap: selectedText != null && selectedText.isNotEmpty
          ? _onExplainTap
          : null,
      onSummarizeChapterTap: _onSummarizeChapterTap,
      // Custom AI prompts run against the selected text (see the Context
      // Menu settings screen). {selectedText} is already substituted in
      // by ReaderCopyService — just stage the prompt and open Vimaṃsa AI.
      onAiPrompt: (prompt) {
        ref.read(aiQaInitialPromptProvider.notifier).state = prompt;
        if (context.mounted) context.push('/ai-qa');
      },
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
    _appBarCollapsed.dispose();
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

    // The mobile dictionary dock is driven by the same panel state as the
    // desktop shell. While it's open, the floating pill and the TTS chip
    // are hidden so nothing overlaps it.
    final dictDockOpen =
        ref.watch(sidePanelProvider).right.openPanel ==
        SidePanelType.dictionary;

    // Inside the desktop shell, the attached status bar drives the reader's
    // toolbar actions through this scope; the floating pill is hidden and
    // the handlers below are registered into the shell's controller.
    final toolbarScope = ReaderToolbarScope.maybeOf(context);
    toolbarScope?.controller.update(
      enabled: tabsState.isNotEmpty,
      onContents: _handleToolbarContents,
      onSearch: _handleToolbarSearch,
      onDictionary: _handleToolbarDictionary,
      onJump: _handleToolbarJump,
      onDisplayLayout: _handleToolbarDisplayLayout,
      onListen: _handleToolbarListen,
      onStop: _handleToolbarStop,
      onBookmark: _handleToolbarBookmark,
    );

    // ── Detect tab switch and start timing ───────────────────────────
    final tabSwitchBookId = tabsState.activeTab?.bookId;
    if (tabSwitchBookId != null && _lastBuildBookId != tabSwitchBookId) {
      _tabSwitchStartMs = DateTime.now().millisecondsSinceEpoch;
      _lastBuildBookId = tabSwitchBookId;
      developer.log(
        '[TAB_SW] Switch → book=$tabSwitchBookId '
        'totalTabs=${tabsState.tabs.length} activeIdx=${tabsState.activeIndex}',
        name: 'epitaka.reader.ui',
      );
    }

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
                  label: Text(AppLocalizations.of(context).openLibraryShort),
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
    if (_tabSwitchStartMs != null) {
      final elapsed =
          DateTime.now().millisecondsSinceEpoch - _tabSwitchStartMs!;
      developer.log(
        '[TAB_SW] book=${activeTab.bookId} readerData available in ${elapsed}ms '
        'isLoaded=${readerState.isLoaded} paras=${readerState.paragraphs.length}',
        name: 'epitaka.reader.ui',
      );
    }
    final settings = ref.watch(settingsProvider);
    final colors = Theme.of(context).colorScheme;

    final brightness = Theme.of(context).brightness;
    final resolvedPaliColor = settings.paliColorPair.resolve(brightness);
    final resolvedTransColor = settings.translationColorPair.resolve(
      brightness,
    );

    final enabledLangs = settings.visibleTranslationLangs;

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
      final frameTime = DateTime.now().millisecondsSinceEpoch;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final frameElapsed = DateTime.now().millisecondsSinceEpoch - frameTime;
        if (_tabSwitchStartMs != null) {
          final totalElapsed =
              DateTime.now().millisecondsSinceEpoch - _tabSwitchStartMs!;
          developer.log(
            '[TAB_SW] book=${activeTab.bookId} isNewInitialParaId '
            'postFrameCallback fired in ${frameElapsed}ms '
            '(total from tab switch: ${totalElapsed}ms)',
            name: 'epitaka.reader.ui',
          );
        }
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
      final frameTime = DateTime.now().millisecondsSinceEpoch;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final frameElapsed = DateTime.now().millisecondsSinceEpoch - frameTime;
        if (_tabSwitchStartMs != null) {
          final totalElapsed =
              DateTime.now().millisecondsSinceEpoch - _tabSwitchStartMs!;
          developer.log(
            '[TAB_SW] book=${activeTab.bookId} isTabRestore '
            'postFrameCallback fired in ${frameElapsed}ms '
            '(total from tab switch: ${totalElapsed}ms) '
            'targetPara=$targetParaId alignment=${alignment.toStringAsFixed(3)}',
            name: 'epitaka.reader.ui',
          );
        }
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
      // Auto-switch the reader to line-by-line while TTS plays — it is the
      // only display mode that renders per-line widgets (and thus per-line
      // GlobalKeys for the fine-scroll), so the spoken line can be followed
      // precisely. Restore the previous mode when reading stops.
      final wasActive = prev?.isActive ?? false;
      final isActive = next.isActive;
      if (isActive && !wasActive && _ttsModeBefore == null) {
        _ttsModeBefore = ref.read(settingsProvider).translationDisplayMode;
        if (_ttsModeBefore != TranslationDisplayMode.lineByLine) {
          // Temporary (non-persisting) override so the user's saved mode
          // is untouched even if this is never undone.
          ref
              .read(settingsProvider.notifier)
              .setTranslationDisplayModeTemporary(
                TranslationDisplayMode.lineByLine,
              );
        }
      } else if (!isActive && wasActive && _ttsModeBefore != null) {
        final currentMode = ref.read(settingsProvider).translationDisplayMode;
        // Respect a manual display-mode change made during playback;
        // otherwise restore what the reader used before TTS started.
        if (currentMode == TranslationDisplayMode.lineByLine ||
            currentMode == _ttsModeBefore) {
          ref.read(settingsProvider.notifier).setTranslationDisplayModeTemporary(
            _ttsModeBefore!,
          );
        }
        _ttsModeBefore = null;
      }

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

      // Same-paragraph line change: the paragraph is already on screen, so a
      // full paragraph-level re-scroll would re-anchor it at a new alignment
      // (causing visible jumping / the "line not following" effect). Instead
      // fine-scroll directly to the new line via its GlobalKey.
      if (!paraChanged && nextLineId != null) {
        final ttsSyncNotifier =
            ref.read(ttsSyncProvider(currentBookId).notifier);
        ttsSyncNotifier.setJumpInProgress();
        ttsSyncNotifier.clearTargetLineKeys();
        ttsSyncNotifier.setTargetParaId(nextParaId);
        ttsSyncNotifier.setTargetLineKey(nextLineId, GlobalKey());
        if (mounted) setState(() {});
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final jumpToken = (_jumpTokens[currentBookId] ?? 0) + 1;
          _jumpTokens[currentBookId] = jumpToken;
          developer.log(
            '[TTS_UI] fine-scroll same-para to line=$nextLineId '
            'token=$jumpToken',
            name: 'epitaka.tts',
          );
          _fineScrollToLine(currentBookId, nextLineId, jumpToken: jumpToken);
        });
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

    // On tab restore, compute an initial scroll index so the list starts
    // near the saved position instead of flashing to the top of the book
    // before the post-frame jump correction.
    final initialScrollIdx = () {
      if (readerState.paragraphs.isEmpty) return 0;
      final restoreParaId = activeTab.initialParaId ?? activeTab.currentParaId;
      if (restoreParaId == null) return 0;
      final idx = readerState.paragraphs.indexWhere(
        (p) => p.paraId == restoreParaId,
      );
      return idx >= 0 ? idx : 0;
    }();

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
        child: Column(
          children: [
            // ── Animated app bar (only this rebuilds on collapse) ──
            // Hidden entirely on desktop: the shell's activity bar and
            // status bar cover these actions, and the back button is the
            // source of the "pop past the end → black screen" bug (books
            // are never pushed onto the history stack on desktop).
            if (!ResponsiveBreakpoint.isDesktop(context))
              ValueListenableBuilder<bool>(
                valueListenable: _appBarCollapsed,
                builder: (context, collapsed, _) => ReaderAppBar(
                  bookId: activeTab.bookId,
                  bookName: readerState.bookName ?? activeTab.bookId,
                  colors: colors,
                  showCollapsed: collapsed,
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
                            tooltip: AppLocalizations.of(context).libraryLabel,
                            onPressed: () => showLibraryDialog(context),
                          ),
                          IconButton(
                            icon: const Icon(Icons.search),
                            color: colors.onSurfaceVariant,
                            tooltip: AppLocalizations.of(context).search,
                            onPressed: () => ref
                                .read(sidePanelProvider.notifier)
                                .toggle(SidePanelType.search),
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings),
                            color: colors.onSurfaceVariant,
                            tooltip: AppLocalizations.of(context).settings,
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
                        initialScrollIdx,
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
                      !dictDockOpen &&
                      (globalTtsState == TtsPlaybackState.playing ||
                          globalTtsState == TtsPlaybackState.paused))
                    Positioned(
                      right: 16,
                      bottom: 84,
                      child: TtsFloatingChip(
                        colors: colors,
                        isAutoScroll: ref
                            .read(ttsSyncProvider(activeTab.bookId))
                            .ttsAutoScroll,
                        isJumpPending: ref
                            .read(ttsSyncProvider(activeTab.bookId))
                            .ttsJumpInProgress,
                        isTtsLineVisible: _isTtsLineVisible(
                          activeTab.bookId,
                          ttsReadingState.currentParaId,
                        ),
                        onTap: () =>
                            _showTtsControlsPopup(context, activeTab.bookId),
                        onFollowTap: () => _followTts(activeTab.bookId),
                      ),
                    ),

                  // Floating bottom toolbar (animated). Hidden inside the
                  // desktop shell, where the attached status bar hosts the
                  // same actions (via ReaderToolbarScope).
                  if (toolbarScope == null && !dictDockOpen)
                    ValueListenableBuilder<bool>(
                      valueListenable: _appBarCollapsed,
                      builder: (context, collapsed, _) => AnimatedPositioned(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        bottom: collapsed ? -80.0 : 24.0,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: ReaderBottomToolbar(
                            colors: colors,
                            displayMode: settings.translationDisplayMode,
                            showTranslation: settings.showTranslation,
                            ttsPlayback: ttsPlaybackStateForTab,
                            onJumpTap: _handleToolbarJump,
                            onDisplayLayoutTap: _handleToolbarDisplayLayout,
                            onContentsTap: _handleToolbarContents,
                            onDictionaryTap: _handleToolbarDictionary,
                            onSearchTap: _handleToolbarSearch,
                            onListenTap: _handleToolbarListen,
                            onStopTap: _handleToolbarStop,
                            onBookmarkTap: _handleToolbarBookmark,
                          ),
                        ),
                      ),
                    ),

                  // (Mobile dictionary is a modal bottom sheet, opened via
                  // showDictionarySheet — see _handleToolbarDictionary.)
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
    int initialScrollIndex,
  ) {
    final dictSheetOpen = ref.watch(dictionarySheetOpenProvider) > 0;

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
      initialScrollIndex: initialScrollIndex,
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
      ttsTargetParaId: ref
          .read(ttsSyncProvider(activeTab.bookId))
          .ttsTargetParaId,
      ttsTargetLineKeys: ref
          .read(ttsSyncProvider(activeTab.bookId))
          .ttsTargetLineKeys,
      searchQuery:
          ref.watch(inBookSearchProvider).effectiveQuery ??
          activeTab.searchQuery,
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
        final notifier = ref.read(inBookSearchProvider.notifier);
        notifier.previousMatch();
        final searchState = ref.read(inBookSearchProvider);
        if (!searchState.hasMatches) return;
        _jumpToInBookMatch(searchState.matchIndex);
      },
      onNext: () {
        final notifier = ref.read(inBookSearchProvider.notifier);
        notifier.nextMatch();
        final searchState = ref.read(inBookSearchProvider);
        if (!searchState.hasMatches) return;
        _jumpToInBookMatch(searchState.matchIndex);
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
  }
}
