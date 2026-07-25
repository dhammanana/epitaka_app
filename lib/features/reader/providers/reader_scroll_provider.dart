import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Scroll state for a single book tab.
///
/// Only *derived values* that other widgets need to read (e.g. app bar
/// collapse state, visible range for copy operations) are stored here.
/// The [ItemScrollController], [ItemPositionsListener], and
/// [ScrollOffsetController] themselves remain as widget-owned fields
/// because they are tied to the [ScrollablePositionedList]'s lifecycle.
class ReaderScrollState {
  final bool appBarCollapsed;
  final int visibleStartIndex;
  final int visibleEndIndex;

  const ReaderScrollState({
    this.appBarCollapsed = false,
    this.visibleStartIndex = 0,
    this.visibleEndIndex = 0,
  });

  ReaderScrollState copyWith({
    bool? appBarCollapsed,
    int? visibleStartIndex,
    int? visibleEndIndex,
  }) {
    return ReaderScrollState(
      appBarCollapsed: appBarCollapsed ?? this.appBarCollapsed,
      visibleStartIndex: visibleStartIndex ?? this.visibleStartIndex,
      visibleEndIndex: visibleEndIndex ?? this.visibleEndIndex,
    );
  }
}

/// Notifier that manages scroll-derived state for a single book tab.
///
/// Receives scroll events from the widget layer and derives high-level
/// state: app bar collapse/expand, visible paragraph range for copy.
class ReaderScrollNotifier extends StateNotifier<ReaderScrollState> {
  ReaderScrollNotifier() : super(const ReaderScrollState());

  /// Pixel-accurate scroll direction tracking per book.
  final Map<String, double> _scrollAccum = {};
  static const double _kScrollThreshold = 20.0;

  /// Whether to suppress app bar collapse/expand (set by jump/init).
  bool suppressAppBarScroll = false;

  /// Whether an initial jump is pending (suppresses app bar logic).
  bool isInitialJumpPending = false;

  /// Handle a scroll offset delta for the collapsible app bar.
  ///
  /// Returns the new [appBarCollapsed] state, or `null` when no change.
  bool? onScrollOffsetChanged(
    String bookId,
    double delta, {
    bool isAtTop = false,
  }) {
    if (delta == 0) return null;
    if (isInitialJumpPending || suppressAppBarScroll) {
      developer.log(
        '[UI_SCROLL] book=$bookId delta=$delta SUPPRESSED by '
        'isInitialJumpPending=$isInitialJumpPending '
        'suppressAppBarScroll=$suppressAppBarScroll',
        name: 'epitaka.reader.ui',
      );
      return null;
    }

    // Never collapse at the very top of the document
    if (isAtTop) {
      if (state.appBarCollapsed) {
        state = state.copyWith(appBarCollapsed: false);
        return false;
      }
      _scrollAccum[bookId] = 0;
      return null;
    }

    final acc = _scrollAccum[bookId] ?? 0;
    final sameDirection = acc == 0 || (delta > 0) == (acc > 0);
    final newAcc = sameDirection ? acc + delta : delta;

    if (newAcc > _kScrollThreshold) {
      developer.log(
        '[UI_SCROLL] book=$bookId delta=$delta acc=$acc→$newAcc '
        'COLLAPSE (wasCollapsed=${state.appBarCollapsed})',
        name: 'epitaka.reader.ui',
      );
      _scrollAccum[bookId] = 0;
      if (!state.appBarCollapsed) {
        state = state.copyWith(appBarCollapsed: true);
        return true;
      }
    } else if (newAcc < -_kScrollThreshold) {
      developer.log(
        '[UI_SCROLL] book=$bookId delta=$delta acc=$acc→$newAcc '
        'EXPAND (wasCollapsed=${state.appBarCollapsed})',
        name: 'epitaka.reader.ui',
      );
      _scrollAccum[bookId] = 0;
      if (state.appBarCollapsed) {
        state = state.copyWith(appBarCollapsed: false);
        return false;
      }
    } else {
      developer.log(
        '[UI_SCROLL] book=$bookId delta=$delta dir=${delta > 0 ? "down" : "up"} '
        'acc=$acc→$newAcc sameDir=$sameDirection',
        name: 'epitaka.reader.ui',
      );
      _scrollAccum[bookId] = newAcc;
    }
    return null;
  }

  /// Update the visible paragraph range.
  void updateVisibleRange(int startIndex, int endIndex) {
    state = state.copyWith(
      visibleStartIndex: startIndex,
      visibleEndIndex: endIndex,
    );
  }

  /// Force-expand the app bar (e.g. when scrolled to the top).
  void forceExpand() {
    if (state.appBarCollapsed) {
      state = state.copyWith(appBarCollapsed: false);
    }
  }

  /// Reset the scroll accumulator for [bookId].
  void resetAccumulator(String bookId) {
    _scrollAccum[bookId] = 0;
  }
}

/// Provider for scroll-derived state, scoped per bookId (family).
/// Uses autoDispose so state is cleaned up when the tab is closed.
final readerScrollProvider = StateNotifierProvider.autoDispose.family<
    ReaderScrollNotifier,
    ReaderScrollState,
    String>(
  (ref, bookId) => ReaderScrollNotifier(),
);
