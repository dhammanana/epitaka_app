part of 'reader_screen.dart';

/// Scroll-related state and methods for the reader screen.
///
/// Manages scroll controllers/listeners for each open book tab, position
/// tracking for the collapsible app bar (silverbar), programmatic jumps via
/// [ItemScrollController], and reading history persistence.
mixin ReaderScrollMixin on ConsumerState<ReaderScreen> {
  // ── Scroll controllers & listeners ──────────────────────────────────
  final Map<String, ItemScrollController> _itemScrollControllers = {};
  final Map<String, ItemPositionsListener> _itemPositionsListeners = {};
  final Map<String, VoidCallback> _positionsListenerRefs = {};

  /// The bookId whose reader list was last served a controller by
  /// [_scrollControllerFor].
  String? _lastControllerFetchBookId;

  // ── Pixel-based scroll tracking (collapsible app bar) ───────────────
  final Map<String, ScrollOffsetListener> _scrollOffsetListeners = {};
  final Map<String, StreamSubscription<double>> _scrollOffsetSubs = {};
  final Map<String, double> _scrollAccum = {};
  static const double _kScrollThreshold = 20.0;

  /// Precise (fractional) scroll offset per book.
  final Map<String, double> _preciseScrollOffset = {};

  bool _appBarCollapsed = false;
  bool _isInitialJumpPending = false;
  bool _suppressAppBarScroll = false;
  String? _lastRestoredBookId;

  // ── Jump tracking ──────────────────────────────────────────────────
  final Map<String, int> _lastJumpedParaId = {};
  final Map<String, int> _pendingJumpParaId = {};

  /// Visible paragraph indices (for copy fallback).
  int _visibleStartIndex = 0;
  int _visibleEndIndex = 0;

  // ── Reading history ────────────────────────────────────────────────
  final Map<String, int> _lastSavedParaIdPerBook = {};
  Timer? _saveHistoryTimer;
  final Map<String, int> _lastScrollParaId = {};

  // ── TTS fine-scroll target ─────────────────────────────────────────
  /// Target line GlobalKey for precise TTS line scroll.
  final Map<int, GlobalKey> _ttsTargetLineKeys = {};
  int? _ttsTargetParaId;

  // ── Performance logging ────────────────────────────────────────────
  final Set<String> _loggedFirstContentFrame = {};

  // ═════════════════════════════════════════════════════════════════════
  // SCROLL CONTROLLER FACTORIES
  // ═════════════════════════════════════════════════════════════════════

  ItemScrollController _scrollControllerFor(String bookId) {
    final existing = _itemScrollControllers[bookId];
    if (existing != null && _lastControllerFetchBookId == bookId) {
      return existing;
    }
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

  // ═════════════════════════════════════════════════════════════════════
  // SCROLL OFFSET TRACKING (collapsible app bar)
  // ═════════════════════════════════════════════════════════════════════

  void _onScrollOffsetChanged(String bookId, double delta) {
    if (!mounted || delta == 0) return;
    if (ref.read(readerTabsProvider).activeTab?.bookId != bookId) return;
    if (!Mobile.isPhone(context)) return;

    if (_isInitialJumpPending || _suppressAppBarScroll) {
      developer.log(
        '[UI_SCROLL] book=$bookId delta=$delta SUPPRESSED by '
        '_isInitialJumpPending=$_isInitialJumpPending '
        '_suppressAppBarScroll=$_suppressAppBarScroll',
        name: 'epitaka.reader.ui',
      );
      return;
    }

    // Never collapse at the very top of the document
    final positions = _itemPositionsListeners[bookId]?.itemPositions.value;
    if (positions != null && positions.isNotEmpty) {
      final visible = positions.where((p) => p.itemTrailingEdge > 0).toList()
        ..sort((a, b) => a.itemLeadingEdge.compareTo(b.itemLeadingEdge));
      if (visible.isNotEmpty && visible.first.index == 0) {
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

  // ═════════════════════════════════════════════════════════════════════
  // POSITION TRACKING (silverbar, pagination, history)
  // ═════════════════════════════════════════════════════════════════════

  void _onPositionsChanged(String bookId) {
    final activeTab = ref.read(readerTabsProvider).activeTab;
    if (activeTab?.bookId != bookId) return;

    final listener = _itemPositionsListeners[bookId];
    final positions = listener?.itemPositions.value;
    if (positions == null || positions.isEmpty) return;

    final visible = positions.where((p) => p.itemTrailingEdge > 0).toList()
      ..sort((a, b) => a.itemLeadingEdge.compareTo(b.itemLeadingEdge));
    if (visible.isEmpty) return;
    final topIndex = visible.first.index;
    final scrollOffset = topIndex + visible.first.itemLeadingEdge;

    final tabsState = ref.read(readerTabsProvider);
    final tabIndex = tabsState.tabs.indexWhere((t) => t.bookId == bookId);
    if (tabIndex >= 0) {
      final readerState = ref.read(readerDataProvider(bookId));
      if (topIndex >= 0 && topIndex < readerState.paragraphs.length) {
        final para = readerState.paragraphs[topIndex];
        final visibleParaId = para.paraId;
        final visibleLineId =
            para.lines.isNotEmpty ? para.lines.first.lineId : null;

        _preciseScrollOffset[bookId] = scrollOffset;

        if (_lastScrollParaId[bookId] != visibleParaId) {
          final posSw = Stopwatch()..start();
          developer.log(
            '[UI_POS] book=$bookId topIndex=$topIndex paraId=$visibleParaId '
            'ttsJumpInProgress=$_ttsJumpInProgress ttsAutoScroll=$_ttsAutoScroll',
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

          // Detect manual scroll away from TTS position
          if (!_ttsJumpInProgress) {
            final ttsState = ref.read(ttsReadingProvider);
            if (ttsState.isActive && ttsState.bookId == bookId) {
              final ttsParaId = ttsState.currentParaId;
              if (ttsParaId != null) {
                final ttsIndex = readerState.paragraphs
                    .indexWhere((p) => p.paraId == ttsParaId);
                final isTtsInVisibleRange =
                    ttsIndex >= 0 && visible.any((p) => p.index == ttsIndex);
                if (!isTtsInVisibleRange) {
                  developer.log(
                    '[UI_POS] book=$bookId DISABLE auto-scroll: ttsPara=$ttsParaId '
                    'ttsIndex=$ttsIndex visible=${visible.map((p) => p.index).toList()}',
                    name: 'epitaka.reader.ui',
                  );
                  _ttsAutoScroll = false;
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

    if (visible.isNotEmpty) {
      _visibleStartIndex = visible.first.index;
      _visibleEndIndex = visible.last.index;
    }

    if (topIndex == 0 && _appBarCollapsed) {
      setState(() => _appBarCollapsed = false);
      _scrollAccum[bookId] = 0;
    }
  }

  // ═════════════════════════════════════════════════════════════════════
  // PRECISE JUMP-BY-PARAID (with optional lineId fine-scroll)
  // ═════════════════════════════════════════════════════════════════════

  Future<void> _jumpToParagraph(
    String bookId,
    int paraId, {
    bool animate = true,
    double alignment = 0.0,
    int? lineId,
    int retryCount = 0,
  }) async {
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
      const maxRetries = 30;
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

    if (lineId != null) {
      _ttsTargetParaId = paraId;
      _ttsTargetLineKeys[lineId] = GlobalKey();
      if (mounted) setState(() {});
    }

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

    if (lineId != null && mounted) {
      _scrollToLine(lineId);
    }

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

    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          developer.log(
            '[JUMP] book=$bookId clearing _isInitialJumpPending '
            '(lineId=$lineId → _suppressAppBarScroll handled by _scrollToLine)',
            name: 'epitaka.reader.ui',
          );
          _isInitialJumpPending = false;
          if (lineId == null) _suppressAppBarScroll = false;
        }
      });
    }
  }

  static const int _kMaxTtsScrollRetries = 15;

  void _scrollToLine(int lineId) {
    final key = _ttsTargetLineKeys[lineId];
    if (key == null) {
      _suppressAppBarScroll = false;
      return;
    }
    final capturedKey = key;
    var retries = 0;

    void attemptScroll() {
      if (!mounted) return;
      final lineContext = capturedKey.currentContext;
      if (lineContext != null && lineContext.mounted) {
        developer.log(
          '[TTS_LINE] Scrollable.ensureVisible line=$lineId',
          name: 'epitaka.tts',
        );
        _suppressAppBarScroll = true;
        Scrollable.ensureVisible(
          lineContext,
          alignment: 0.3,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        ).then((_) {
          if (mounted) {
            _ttsTargetLineKeys.remove(lineId);
            _ttsTargetParaId = null;
            _suppressAppBarScroll = false;
          }
        });
      } else {
        retries++;
        if (retries >= _kMaxTtsScrollRetries) {
          _ttsTargetLineKeys.remove(lineId);
          _ttsTargetParaId = null;
          _suppressAppBarScroll = false;
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) attemptScroll();
        });
      }
    }

    _suppressAppBarScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => attemptScroll());
  }

  /// Get the current paraId from approximately 1/3 of the screen height.
  int? _getCurrentParaId(String bookId) {
    final listener = _itemPositionsListeners[bookId];
    final positions = listener?.itemPositions.value;
    if (positions == null || positions.isEmpty) return null;

    final visible = positions.where((p) => p.itemTrailingEdge > 0).toList()
      ..sort((a, b) => a.itemLeadingEdge.compareTo(b.itemLeadingEdge));

    if (visible.isEmpty) return null;

    int? targetIndex;
    for (final pos in visible) {
      if (pos.itemLeadingEdge >= 0.3) {
        targetIndex = pos.index;
        break;
      }
    }
    targetIndex ??= visible.first.index;

    final readerState = ref.read(readerDataProvider(bookId));
    if (targetIndex >= 0 && targetIndex < readerState.paragraphs.length) {
      return readerState.paragraphs[targetIndex].paraId;
    }
    return null;
  }

  // ═════════════════════════════════════════════════════════════════════
  // READING HISTORY
  // ═════════════════════════════════════════════════════════════════════

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
}
