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
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/platform_info.dart';
import '../../../core/utils/responsive_breakpoint.dart';
import '../../annotations/providers/annotations_provider.dart';
import '../../annotations/widgets/annotations_panel.dart';
import '../../../shared/providers/side_panel_provider.dart';
import '../../../shared/utils/app_shortcuts.dart';
import '../../../shared/widgets/reader_toolbar_controller.dart';
import '../../dictionary/providers/dictionary_sheet_open_provider.dart';
import '../../dictionary/widgets/dictionary_sheet.dart';
import '../../library/screens/library_screen.dart';
import '../../library/widgets/library_dialog.dart';
import '../../settings/providers/tts_provider.dart';
import '../../settings/widgets/settings_dialog.dart';
import '../providers/reader_dictionary_lookup_controller.dart';
import '../providers/reader_keyboard_bridge.dart';
import '../providers/reader_provider.dart';
import '../providers/reader_search_notifier.dart';
import '../providers/reader_scroll_controller.dart';
import '../providers/reader_selection_notifier.dart';
import '../providers/reader_tabs_provider.dart';
import '../providers/reader_tts_controller.dart';
import '../providers/reader_tts_sync_provider.dart';
import '../providers/tts_reading_provider.dart';
import '../services/reader_ai_service.dart';
import '../widgets/bookmark_dialog.dart';
import '../widgets/display_layout_popup.dart';
import '../widgets/jump_sheet.dart';
import '../widgets/reader_app_bar.dart';
import '../widgets/reader_bottom_toolbar.dart';
import '../widgets/reader_content_with_selection.dart';
import '../widgets/reader_context_menu_builder.dart';
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

  // App lifecycle state for background TTS optimization
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  // Silverbar: collapsible app bar on scroll
  // Using ValueNotifier so only the app bar/toolbar rebuild, not the full screen.
  final ValueNotifier<bool> _appBarCollapsed = ValueNotifier(false);

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
    _scroll.jumpToParagraph(
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
        _scroll.currentParaId(activeTab.bookId) ?? activeTab.currentParaId;
    var url =
        '/contents/${activeTab.bookId}?bookName=${Uri.encodeComponent(readerState.bookName ?? activeTab.bookId)}';
    if (currentParaId != null) {
      url += '&currentParaId=$currentParaId';
    }
    context.push(url);
  }

  /// Open the outline (every section with its study guide) of the current
  /// book as a full reading view. Desktop keeps the dockable contents panel
  /// (which hosts the outline button) instead of pushing over the shell.
  void _handleToolbarOutline() {
    final activeTab = _toolbarActiveTab();
    if (activeTab == null) return;
    if (ResponsiveBreakpoint.isDesktop(context)) {
      ref.read(sidePanelProvider.notifier).toggle(SidePanelType.contents);
      return;
    }
    final readerState = _toolbarReaderState(activeTab);
    context.push(
      '/outline/${activeTab.bookId}?bookName=${Uri.encodeComponent(readerState.bookName ?? activeTab.bookId)}',
    );
  }

  void _handleToolbarSearch() => _toggleInBookSearch();

  void _handleToolbarDictionary() {
    if (!ResponsiveBreakpoint.isDesktop(context)) {
      // Mobile (incl. a desktop window narrowed below the desktop
      // breakpoint): the dictionary is a modal bottom sheet — easy to
      // close with the back button, by pulling it down, or by tapping
      // outside.
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
    await _tts.startListening(activeTab, readerState);
  }

  void _handleToolbarStop() {
    _tts.stopListening();
  }

  void _handleToolbarBookmark() {
    final activeTab = _toolbarActiveTab();
    if (activeTab == null) return;
    _onBookmarkTap(activeTab, _toolbarReaderState(activeTab));
  }

  /// Summarize the current chapter with AI (Vimaṃsa). Shared by the mobile
  /// pill toolbar and the desktop status bar (via [onSummarizeTap]).
  void _handleToolbarSummarize() {
    final activeTab = _toolbarActiveTab();
    if (activeTab == null) return;
    final readerState = _toolbarReaderState(activeTab);
    ReaderAiService.stageChapterSummaryPrompt(
      context: context,
      ref: ref,
      activeTab: activeTab,
      readerState: readerState,
    );
  }

  /// Open the annotations manager (highlights / notes / bookmarks).
  /// Desktop opens the dockable sidebar panel; mobile shows a bottom sheet.
  void _handleToolbarAnnotations() {
    if (ResponsiveBreakpoint.isDesktop(context)) {
      ref.read(sidePanelProvider.notifier).toggle(SidePanelType.annotations);
      return;
    }
    _showMobileAnnotationsSheet();
  }

  /// Mobile: annotations list as a modal bottom sheet (uses the same panel
  /// widget, wrapped in a scroll view).
  void _showMobileAnnotationsSheet() {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
              child: Row(
                children: [
                  Icon(Icons.edit_note, size: 20, color: colors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).annotations,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: colors.onSurfaceVariant,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // AnnotationsPanel is a Column with an internal Expanded — it
            // must NOT be placed inside a ListView (unbounded height would
            // crash with "RenderFlex children have non-zero flex but
            // incoming height constraints are unbounded"). Give it bounded
            // height and pass the sheet's scroll controller so the
            // DraggableScrollableSheet keeps driving the list. The old
            // ListView applied 16px side padding — keep that look.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: AnnotationsPanel(scrollController: scrollController),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Owns the reader's scroll controllers, position tracking, jumping, and
  /// reading-history persistence. All scroll logic lives in
  /// [ReaderScrollController]; the screen only supplies context/rebuild
  /// hooks. Created before [_tts], whose callbacks target this controller.
  late final ReaderScrollController _scroll;

  /// Coordinates TTS playback with the reader UI. All TTS logic lives in
  /// [ReaderTtsController]; the screen only supplies scroll/rebuild hooks.
  late final ReaderTtsController _tts;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _scroll = ReaderScrollController(
      ref: ref,
      isMounted: () => mounted,
      isPhone: () => Mobile.isPhone(context),
      viewInsetsBottom: () => MediaQuery.of(context).viewInsets.bottom,
      appBarCollapsed: _appBarCollapsed,
      onTtsManualScroll: (bookId, visible, paragraphs) =>
          _tts.handleManualScroll(bookId, visible, paragraphs),
      onFirstVisiblePosition: (bookId, topIndex, paraId) {
        if (_tabSwitchStartMs != null) {
          final posElapsed =
              DateTime.now().millisecondsSinceEpoch - _tabSwitchStartMs!;
          developer.log(
            '[TAB_SW] book=$bookId FIRST visible position in ${posElapsed}ms '
            'topIndex=$topIndex paraId=$paraId',
            name: 'epitaka.reader.ui',
          );
          _tabSwitchStartMs = null; // one-shot
        }
        developer.log(
          '[UI_POS] book=$bookId topIndex=$topIndex paraId=$paraId',
          name: 'epitaka.reader.ui',
        );
      },
    );

    _tts = ReaderTtsController(
      ref: ref,
      isMounted: () => mounted,
      isAppResumed: () => _appLifecycleState == AppLifecycleState.resumed,
      positionsFor: _scroll.positionsFor,
      jumpToParagraph:
          (
            bookId,
            paraId, {
            bool animate = true,
            double alignment = 0.0,
            int? lineId,
          }) => _scroll.jumpToParagraph(
            bookId,
            paraId,
            animate: animate,
            alignment: alignment,
            lineId: lineId,
          ),
      fineScrollToLine: _scroll.fineScrollToLine,
      nextJumpToken: _scroll.nextJumpToken,
      saveHistory: _scroll.saveReadingHistory,
      requestRebuild: () {
        if (mounted) setState(() {});
      },
    );

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

  // ── Scroll machinery ─────────────────────────────────────────────────
  // Per-book scroll controllers/listeners, position tracking (app-bar
  // collapse, tab scroll-offset updates, history, TTS auto-scroll
  // detection), unified jumping + per-line fine-scroll, and reading-history
  // persistence live in [ReaderScrollController].
  //
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

  // ── Jump to connected book / page ─────────────────────────────────────
  Future<void> _onJumpTap(
    ReaderTabInfo activeTab,
    ReaderDataState readerState,
  ) async {
    final currentParaId = _scroll.currentParaId(activeTab.bookId);
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

  // ── Reading history persistence lives in [ReaderScrollController] ─────

  // ── Word lookup ──────────────────────────────────────────────────────
  void _onWordLookup(String word) {
    if (word.trim().isEmpty) return;
    developer.log('[DBG] _onWordLookup word="$word"', name: 'epitaka.dict');
    // Route the lookup into the dictionary dock/panel FIRST — the
    // dictionary must receive the word before any selection is cleared
    // (clearing first broke lookups and triggered framework assertions).
    ref
        .read(readerDictionaryLookupController)
        .openDictionary(ref, context, word);
    // The dictionary now owns the screen. Drop the reader's cached
    // selection state too: if SelectionArea's own double-tap word selection
    // (created on this same gesture, inside the framework) survives, the
    // reader must still not think text is selected. A lingering
    // `hasSelection` disables the scroll-time double-tap invalidation in
    // [_handlePointerMoveForTabSwipe] and leaves stale tap state that can
    // re-trigger a lookup after the sheet closes.
    _selectableRegionKey.currentState?.clearSelection();
    ref.read(readerSelectionProvider.notifier).clearSelection();

    // SelectionArea keeps processing this same double-tap AFTER the sheet
    // is pushed: on the second tap's pointer-DOWN it creates its own word
    // selection (the pin), and on the pointer-UP it shows selection handles
    // and creates its toolbar in the ROOT overlay (via the global
    // ContextMenuController). That toolbar is built while the sheet is open
    // (suppressed by [ReaderContextMenuBuilder.build]) but it PERSISTS: the moment
    // the sheet closes it rebuilds with the real menu and pops up over the
    // text, and its leftover selection state can even swallow the next
    // double-tap. Suppress the whole thing for the next ~250ms — clear the
    // selection, hide the handles, and dismiss the global context menu —
    // until the gesture and the sheet's route push have fully settled.
    // (Note: SelectableRegionState.hideToolbar alone does NOT remove the
    // ContextMenuController overlay; removeAny is required, and the
    // tap-up that creates it can land many frames after this lookup, so
    // the suppression re-schedules itself each frame.)
    final suppressUntil = DateTime.now().add(const Duration(milliseconds: 250));
    void suppressLeftoverSelection() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (ref.read(dictionarySheetOpenProvider) <= 0) return;
        final region = _selectableRegionKey.currentState;
        region?.clearSelection();
        region?.hideToolbar();
        ContextMenuController.removeAny();
        if (DateTime.now().isBefore(suppressUntil)) {
          suppressLeftoverSelection();
        }
      });
    }

    suppressLeftoverSelection();
  }

  void _handleSelectionChanged(SelectedContent? selection) {
    ref.read(readerSelectionProvider.notifier).onSelectionChanged(selection);
    developer.log(
      '[DBG] onSelectionChanged plain="${selection?.plainText}" '
      'hasSelection=${selection != null}',
      name: 'epitaka.dict',
    );

    // When a modal dictionary/book-link sheet is open, any NEW selection
    // reported here is a leftover of the double-tap that opened it — clear
    // it the instant it appears so its highlight and context menu can never
    // cover the sheet. Note this is a backstop only: the framework actually
    // lands its double-tap word selection on the second tap's pointer-DOWN
    // BEFORE [_onWordLookup] runs, so this guard usually fires while the
    // sheet counter is still 0. The reliable clears are in [_onWordLookup]
    // (synchronous + post-frame backstops + reader selection-state reset).
    if (selection != null && ref.read(dictionarySheetOpenProvider) > 0) {
      _selectableRegionKey.currentState?.clearSelection();
    }

    // Dictionary lookup is driven explicitly by the
    // [ReaderDictionaryLookupController] (see [_handlePointerDown] /
    // [_handlePointerUpForTabSwipe]), which hit-tests the render tree to
    // find the word under the tap. We no longer infer a tap from a
    // single-word selection here, because that heuristic competed with the
    // tab-swipe [GestureDetector] and was flaky from the second tap onward.
    //
    // We still cache the selection for the copy context menu / Ctrl+C
    // (long-press selection, which is a separate gesture from tap).
  }

  /// Handle raw pointer-down events: forward to the
  /// [readerDictionaryLookupController] (double-tap detection) and record the
  /// start of a potential tab-swipe. This runs *before* the gesture arena
  /// resolves, so it is not subject to the race between [SelectionArea]'s
  /// double-tap recognizer and the tab-swipe [GestureDetector].
  void _handlePointerDown(PointerDownEvent event) {
    // Record start position for potential tab-swipe (mobile/tablet only —
    // decided by the actual layout, so a narrow desktop window that fell
    // back to the phone UI keeps the swipe gestures)
    if (!ResponsiveBreakpoint.isDesktop(context)) {
      _swipeStartPos = event.localPosition;
      _isSwiping = false;
      _lastSwipeDx = 0;
      _swipeSamples.clear();
    }

    final controller = ref.read(readerDictionaryLookupController);
    controller.setGesture(ref.read(settingsProvider).wordLookupGesture);
    final result = controller.handlePointerDown(
      pointer: event.pointer,
      localPosition: event.localPosition,
      globalPosition: event.position,
      timestampMs: event.timeStamp.inMilliseconds,
      contentHitTestKey: _contentHitTestKey,
    );
    if (result.shouldLookup) {
      _onWordLookup(result.word!);
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

    // ── Invalidate pending tap state on any real movement ──
    // This MUST run before the selection/desktop early returns below: while
    // a selection lingers (e.g. the word highlight left by the double-tap
    // that opened the dictionary), `hasSelection` used to short-circuit
    // before this clearing, so a scroll never invalidated the cached
    // tap-down. The next pointer-down within the double-tap window (a
    // second scroll fling, or a tap right after a scroll) was then misread
    // as a double-tap and opened the dictionary for a random word. (Moved
    // into the [readerDictionaryLookupController].)
    ref
        .read(readerDictionaryLookupController)
        .handlePointerMove(event.pointer, event.localPosition);

    // ── Tab-swipe detection (mobile/tablet only, and not while selecting
    // text) — decided by the actual layout so a narrow desktop window that
    // fell back to the phone UI keeps the swipe gestures ──
    if (ResponsiveBreakpoint.isDesktop(context)) return;
    if (ref.read(readerSelectionProvider).hasSelection) return;
    if (_swipeStartPos == null) return;

    final dx = event.localPosition.dx - _swipeStartPos!.dx;
    final dy = (event.localPosition.dy - _swipeStartPos!.dy).abs();

    // Must be primarily horizontal and past a small threshold
    if (!_isSwiping) {
      if (dx.abs() < 10 || dx.abs() < dy) return;
      _isSwiping = true;
      // A confirmed tab-swipe can never be a tap — kill any half-detected
      // tap/double-tap state outright (covers the exact-threshold case where
      // the movement distance is at, not beyond, the controller's slop).
      ref.read(readerDictionaryLookupController).clearTapState();
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
    // Single-tap word lookup (when enabled in settings) is confirmed on
    // pointer-up — by then we know the pointer didn't move (no scroll/drag)
    // and no text selection was created (e.g. by a long-press).
    final result = ref
        .read(readerDictionaryLookupController)
        .handlePointerUp(
          pointer: event.pointer,
          globalPosition: event.position,
          timestampMs: event.timeStamp.inMilliseconds,
          contentHitTestKey: _contentHitTestKey,
          hasSelection: ref.read(readerSelectionProvider).hasSelection,
        );
    if (result.shouldLookup) {
      _onWordLookup(result.word!);
    }
    _finishTabSwipe();
  }

  /// Handle raw pointer cancel (e.g. system gesture interrupts).
  /// A cancelled gesture never commits a tab switch — see [_finishTabSwipe].
  void _handlePointerCancelForTabSwipe(PointerCancelEvent event) {
    ref
        .read(readerDictionaryLookupController)
        .handlePointerCancel(event.pointer);
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

  // ── Context menu (copy/annotations/AI) ───────────────────────────────
  // The selection context menu and the AI prompt actions live in
  // [ReaderContextMenuBuilder] / [ReaderAiService]; the screen only wires
  // them into the [SelectionArea] and the Ctrl/Cmd+C shortcut.

  // ── TTS floating controls ────────────────────────────────────────────
  // TTS playback coordination (start/stop, controls dialog, follow, mode
  // forcing, auto-scroll) lives in [ReaderTtsController].

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoScrollTimer?.cancel();
    _settleController.dispose();
    _dragDxNotifier.dispose();
    _appBarCollapsed.dispose();
    _scroll.dispose();
    // In-book search state is managed by [inBookSearchProvider] (auto-disposed)
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
    // initialJumpId distinguishes a NEW explicit jump request (annotation
    // tap, book link, history…) from a stale rebuild — so requesting the
    // same paragraph twice still re-jumps and reaches the exact line.
    final isNewInitialParaId =
        activeTab.initialParaId != null &&
        _scroll.lastInitialJumpId(activeTab.bookId) != activeTab.initialJumpId;
    final isTabRestore =
        !isNewInitialParaId &&
        activeTab.currentParaId != null &&
        _scroll.lastRestoredBookId != activeTab.bookId;

    if (isNewInitialParaId) {
      _scroll.isInitialJumpPending = true;
      final targetParaId = activeTab.initialParaId!;
      final targetLineId = activeTab.initialLineId;
      _scroll.setLastInitialJumpId(activeTab.bookId, activeTab.initialJumpId);
      _scroll.lastRestoredBookId = activeTab.bookId;
      developer.log(
        '[BUILD] ${activeTab.bookId} isNewInitialParaId → jump to $targetParaId'
        ' line=$targetLineId (isInitialJumpPending=${_scroll.isInitialJumpPending})',
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
        _scroll.jumpToParagraph(
          activeTab.bookId,
          targetParaId,
          alignment: targetLineId != null ? 0.0 : 0.05,
          lineId: targetLineId,
        );
      });
    } else if (isTabRestore) {
      _scroll.isInitialJumpPending = true;
      _scroll.lastRestoredBookId = activeTab.bookId;
      final targetParaId = activeTab.currentParaId!;
      // Restore the exact within-paragraph offset via a precise alignment
      // derived from the saved fractional scrollOffset. We use
      // jumpToParagraph (a post-layout jumpTo) rather than initialScrollIndex,
      // because initialScrollIndex relies on item-extent *estimates* and is
      // wildly inaccurate for variable-height Pali paragraphs (off by ~a
      // screen).
      final offset =
          _scroll.preciseScrollOffsetFor(activeTab.bookId) ??
          activeTab.scrollOffset;
      // alignment must be the *negative* fractional part of the offset, i.e.
      // the item's leading edge. Because itemLeadingEdge is in [-1, 0] when
      // scrolled down within the top paragraph, offset = topIndex + leading
      // and ceil(offset) == topIndex, so (offset - ceil(offset)) == leading.
      // Using floor() here would yield leading + 1 (~a full viewport off).
      final double alignment = offset != null ? (offset - offset.ceil()) : 0.0;
      developer.log(
        '[BUILD] ${activeTab.bookId} isTabRestore → jump to $targetParaId '
        'alignment=$alignment (isInitialJumpPending=${_scroll.isInitialJumpPending})',
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
        _scroll.jumpToParagraph(
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

    // ── Keyboard-navigation cleanup on tab close ──────────────────
    // Drop the bridge registrations for books that are no longer open (the
    // reader may have disposed their ScrollablePositionedList) and clear the
    // focus line when the active book changes.
    ref.listen(readerTabsProvider, (
      ReaderTabsState? prev,
      ReaderTabsState next,
    ) {
      if (prev == null) return;
      final prevIds = prev.tabs.map((t) => t.bookId).toSet();
      final nextIds = next.tabs.map((t) => t.bookId).toSet();
      final bridge = ref.read(readerKeyboardBridgeProvider);
      for (final id in prevIds) {
        if (!nextIds.contains(id)) bridge.unregister(id);
      }
      if (next.activeTab?.bookId != prev.activeTab?.bookId) {
        ref
            .read(readerKeyboardNavProvider.notifier)
            .clearIfDifferentBook(next.activeTab?.bookId);
      }
    });

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
              _scroll.saveReadingHistory(tab.bookId, tab.bookName);
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
    // TTS → reader coordination (display-mode forcing, history saving, and
    // auto-scroll to the spoken line) lives in [ReaderTtsController].
    ref.listen(
      ttsReadingProvider,
      (prev, next) => _tts.handleTtsStateChanged(prev, next),
    );

    // Keep the TTS sync provider alive for the active book while the reader
    // is mounted. It is autoDispose and every other access is ref.read, so
    // with no watcher it gets disposed right after the jump writes its
    // target-line GlobalKey — and `fineScrollToLine` then reads a fresh
    // empty provider, silently killing every line-level jump (book links,
    // dictionary, search, TTS follow). Watching it here pins its lifetime
    // to the reader.
    ref.watch(ttsSyncProvider(activeTab.bookId));

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
      // The on-screen keyboard (in-book search field) must NOT resize the
      // reader. The default resize re-lays-out the heavy book list on every
      // frame of the keyboard animation and shifts the visible text (the
      // ScrollablePositionedList viewport shrinks, so the content appears to
      // scroll). The keyboard overlays the bottom instead; the book keeps
      // its exact position and no per-frame relayout happens.
      resizeToAvoidBottomInset: false,
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
                      SingleActivator(
                        LogicalKeyboardKey.keyC,
                        control: true,
                      ): () => ReaderContextMenuBuilder.copyShortcut(
                        context: context,
                        ref: ref,
                      ),
                      SingleActivator(
                        LogicalKeyboardKey.keyC,
                        meta: true,
                      ): () => ReaderContextMenuBuilder.copyShortcut(
                        context: context,
                        ref: ref,
                      ),
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
                            itemScrollController: _scroll
                                .itemScrollControllerFor(activeTab.bookId),
                            itemPositionsListener: _scroll
                                .itemPositionsListenerFor(activeTab.bookId),
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
                        isTtsLineVisible: _tts.isTtsLineVisible(
                          activeTab.bookId,
                          ttsReadingState.currentParaId,
                        ),
                        onTap: () =>
                            _tts.showControls(context, activeTab.bookId),
                        onFollowTap: () => _tts.follow(activeTab.bookId),
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
                            items: settings.toolbarItems,
                            onJumpTap: _handleToolbarJump,
                            onDisplayLayoutTap: _handleToolbarDisplayLayout,
                            onContentsTap: _handleToolbarContents,
                            onOutlineTap: _handleToolbarOutline,
                            onDictionaryTap: _handleToolbarDictionary,
                            onSearchTap: _handleToolbarSearch,
                            onListenTap: _handleToolbarListen,
                            onStopTap: _handleToolbarStop,
                            onBookmarkTap: _handleToolbarBookmark,
                            onAnnotationsTap: _handleToolbarAnnotations,
                            onSummarizeTap: _handleToolbarSummarize,
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

    // Hand the scroll controller / positions listener to the keyboard
    // navigation layer (j/k reading cursor + Cmd/Ctrl+J). Registration is
    // idempotent per bookId and cleaned up when the tab closes.
    ref
        .read(readerKeyboardBridgeProvider)
        .register(
          activeTab.bookId,
          _scroll.scrollControllerFor(activeTab.bookId),
          _scroll.positionsListenerFor(activeTab.bookId),
        );

    // The keyboard reading cursor (focus line + selected chip), threaded
    // down to the paragraph renderer so the highlight is drawn.
    final kbNav = ref.watch(readerKeyboardNavProvider);
    final keyboardFocusParaId =
        kbNav.engaged && kbNav.bookId == activeTab.bookId ? kbNav.paraId : null;
    final keyboardFocusLineId =
        kbNav.engaged && kbNav.bookId == activeTab.bookId ? kbNav.lineId : null;
    final keyboardFocusChipIndex = keyboardFocusLineId != null
        ? kbNav.chipIndex
        : null;

    // Final cleanup the moment a dictionary sheet closes: the framework's
    // double-tap processing can land its leftover selection / toolbar after
    // the ~250ms suppression window in [_onWordLookup] (e.g. a second tap
    // held unusually long), and it would pop up over the text now that the
    // sheet is gone.
    ref.listen(dictionarySheetOpenProvider, (previous, next) {
      if (previous != null && previous > 0 && next <= 0 && mounted) {
        final region = _selectableRegionKey.currentState;
        region?.clearSelection();
        ContextMenuController.removeAny();
      }
    });

    Widget content = ReaderContentWithSelection(
      bookId: activeTab.bookId,
      data: data,
      settings: settings,
      colors: colors,
      paliColor: paliColor,
      translationColor: translationColor,
      enabledLangs: enabledLangs,
      langTypographies: langTypographies,
      itemScrollController: _scroll.scrollControllerFor(activeTab.bookId),
      itemPositionsListener: _scroll.positionsListenerFor(activeTab.bookId),
      scrollOffsetListener: _scroll.scrollOffsetListenerFor(activeTab.bookId),
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
      contextMenuBuilder: (context, state) => ReaderContextMenuBuilder.build(
        context: context,
        ref: ref,
        selectableRegionState: state,
        contentHitTestKey: _contentHitTestKey,
      ),
      annotations: ref.watch(paragraphAnnotationsProvider(activeTab.bookId)),
      ttsHighlightLineId: ttsHighlightLineId,
      ttsHighlightParaId: ttsHighlightParaId,
      appBarCollapsed: _appBarCollapsed,
      ttsTargetParaId: ref
          .read(ttsSyncProvider(activeTab.bookId))
          .ttsTargetParaId,
      ttsTargetLineKeys: ref
          .read(ttsSyncProvider(activeTab.bookId))
          .ttsTargetLineKeys,
      keyboardFocusParaId: keyboardFocusParaId,
      keyboardFocusLineId: keyboardFocusLineId,
      keyboardFocusChipIndex: keyboardFocusChipIndex,
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
