import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents a single open reader tab.
class ReaderTabInfo {
  final String bookId;
  final String bookName;
  final String? bookDescription;
  final int? initialParaId;

  /// Specific line ID to scroll to within [initialParaId] on first load.
  final int? initialLineId;

  /// Monotonically increasing id assigned by [ReaderTabsNotifier.openTab]
  /// to every explicit jump request (annotation/book-link/history tap). The
  /// reader compares this instead of the para value so a SECOND request to
  /// the same paragraph still triggers a jump — the old para-value guard
  /// silently swallowed re-requests for the paragraph the reader was
  /// already on.
  final int? initialJumpId;

  /// Optional search query to highlight in the reader content.
  final String? searchQuery;

  /// Saved scroll offset for position preservation when switching tabs.
  final double? scrollOffset;

  /// Last visible paragraph ID for this tab (for position restoration).
  final int? currentParaId;

  /// Last visible line ID for this tab (for position restoration).
  final int? currentLineId;

  const ReaderTabInfo({
    required this.bookId,
    required this.bookName,
    this.bookDescription,
    this.initialParaId,
    this.initialLineId,
    this.initialJumpId,
    this.searchQuery,
    this.scrollOffset,
    this.currentParaId,
    this.currentLineId,
  });
}

/// State holding the list of open tabs and the active index.
class ReaderTabsState {
  final List<ReaderTabInfo> tabs;
  final int activeIndex;

  const ReaderTabsState({
    required this.tabs,
    this.activeIndex = 0,
  });

  bool get isEmpty => tabs.isEmpty;
  bool get isNotEmpty => tabs.isNotEmpty;
  int get length => tabs.length;

  ReaderTabInfo? get activeTab =>
      tabs.isNotEmpty && activeIndex < tabs.length ? tabs[activeIndex] : null;
}

/// StateNotifier that manages a list of open reader tabs.
class ReaderTabsNotifier extends StateNotifier<ReaderTabsState> {
  ReaderTabsNotifier() : super(const ReaderTabsState(tabs: []));

  /// Incremented for every explicit jump request so the reader can tell a
  /// NEW request (even for the same paragraph) from a stale rebuild.
  int _jumpRequestCounter = 0;

  /// Open a tab (by bookId). If already open, switch to it and update
  /// fields like [searchQuery].
  void openTab(ReaderTabInfo tab) {
    // Assign a fresh jump id whenever a position is requested, so a repeat
    // request for the paragraph the reader is already on still jumps (and
    // fine-scrolls to the line).
    final resolvedTab = tab.initialParaId != null
        ? ReaderTabInfo(
            bookId: tab.bookId,
            bookName: tab.bookName,
            bookDescription: tab.bookDescription,
            initialParaId: tab.initialParaId,
            initialLineId: tab.initialLineId,
            initialJumpId: ++_jumpRequestCounter,
            searchQuery: tab.searchQuery,
          )
        : tab;

    final existingIndex =
        state.tabs.indexWhere((t) => t.bookId == resolvedTab.bookId);
    if (existingIndex >= 0) {
      final existing = state.tabs[existingIndex];
      final updated = ReaderTabInfo(
        bookId: existing.bookId,
        bookName: existing.bookName,
        bookDescription: existing.bookDescription,
        initialParaId: resolvedTab.initialParaId ?? existing.initialParaId,
        initialLineId: resolvedTab.initialLineId ?? existing.initialLineId,
        initialJumpId:
            resolvedTab.initialJumpId ?? existing.initialJumpId,
        searchQuery: resolvedTab.searchQuery ?? existing.searchQuery,
        scrollOffset: existing.scrollOffset,
        currentParaId: existing.currentParaId,
        currentLineId: existing.currentLineId,
      );
      final newTabs = [...state.tabs];
      newTabs[existingIndex] = updated;
      state = ReaderTabsState(
        tabs: newTabs,
        activeIndex: existingIndex,
      );
      return;
    }
    state = ReaderTabsState(
      tabs: [...state.tabs, resolvedTab],
      activeIndex: state.tabs.length,
    );
  }

  /// Close the tab at [index]. If the active tab is closed, switch to an
  /// adjacent tab. If all tabs are closed, state becomes empty.
  void closeTab(int index) {
    if (state.tabs.isEmpty || index >= state.tabs.length) return;

    final newTabs = [...state.tabs]..removeAt(index);

    if (newTabs.isEmpty) {
      state = const ReaderTabsState(tabs: []);
      return;
    }

    int newActiveIndex = state.activeIndex;
    if (index <= newActiveIndex) {
      newActiveIndex = (newActiveIndex - 1).clamp(0, newTabs.length - 1);
    }

    state = ReaderTabsState(
      tabs: newTabs,
      activeIndex: newActiveIndex,
    );
  }

  /// Switch to the tab at [index].
  void switchTo(int index) {
    if (index >= 0 && index < state.tabs.length) {
      state = ReaderTabsState(
        tabs: state.tabs,
        activeIndex: index,
      );
    }
  }

  /// Switch to the next tab (wrapping around to the first).
  void nextTab() {
    if (state.tabs.length <= 1) return;
    final next = (state.activeIndex + 1) % state.tabs.length;
    switchTo(next);
  }

  /// Switch to the previous tab (wrapping around to the last).
  void previousTab() {
    if (state.tabs.length <= 1) return;
    final prev = (state.activeIndex - 1 + state.tabs.length) % state.tabs.length;
    switchTo(prev);
  }

  /// Update the scroll offset and visible position for a specific tab.
  void updateScrollOffset(int index, double offset, {int? paraId, int? lineId}) {
    if (index < 0 || index >= state.tabs.length) return;
    final tab = state.tabs[index];      final updated = ReaderTabInfo(
        bookId: tab.bookId,
        bookName: tab.bookName,
        bookDescription: tab.bookDescription,
        initialParaId: tab.initialParaId,
        initialLineId: tab.initialLineId,
        initialJumpId: tab.initialJumpId,
        searchQuery: tab.searchQuery,
        scrollOffset: offset,
        currentParaId: paraId ?? tab.currentParaId,
        currentLineId: lineId ?? tab.currentLineId,
      );
    final newTabs = [...state.tabs];
    newTabs[index] = updated;
    state = ReaderTabsState(
      tabs: newTabs,
      activeIndex: state.activeIndex,
    );
  }

  /// Clear the initialParaId for a specific tab.
  void clearInitialParaId(int index) {
    if (index < 0 || index >= state.tabs.length) return;
    final tab = state.tabs[index];
    if (tab.initialParaId == null) return;
    final updated = ReaderTabInfo(
      bookId: tab.bookId,
      bookName: tab.bookName,
      bookDescription: tab.bookDescription,
      initialParaId: null,
      initialLineId: null,
      initialJumpId: null,
      searchQuery: tab.searchQuery,
      scrollOffset: tab.scrollOffset,
      currentParaId: tab.currentParaId,
      currentLineId: tab.currentLineId,
    );
    final newTabs = [...state.tabs];
    newTabs[index] = updated;
    state = ReaderTabsState(
      tabs: newTabs,
      activeIndex: state.activeIndex,
    );
  }

  /// Reorder tabs — move the tab at [oldIndex] to [newIndex].
  /// Uses ReorderableListView conventions:
  /// - When moving DOWN (oldIndex < newIndex), newIndex is already
  ///   adjusted by ReorderableListView and must be decremented here.
  void reorderTab(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.tabs.length) return;
    if (oldIndex == newIndex) return;

    // Adjust newIndex when moving down (after removal, indices shift).
    // ReorderableListView passes newIndex before the item is removed,
    // so when dragging DOWN, newIndex can equal state.tabs.length
    // (dropping at the very end). We must adjust BEFORE validating.
    if (oldIndex < newIndex) newIndex--;

    if (newIndex < 0 || newIndex >= state.tabs.length) return;

    final newTabs = [...state.tabs];
    final tab = newTabs.removeAt(oldIndex);
    newTabs.insert(newIndex, tab);

    // Update active index after the move
    int newActiveIndex = state.activeIndex;
    if (state.activeIndex == oldIndex) {
      // The active tab was the one that was moved
      newActiveIndex = newIndex;
    } else if (oldIndex < state.activeIndex && newIndex >= state.activeIndex) {
      // Moved item from below the active tab to above/at it → active shifts down
      newActiveIndex--;
    } else if (oldIndex > state.activeIndex && newIndex <= state.activeIndex) {
      // Moved item from above the active tab to below/at it → active shifts up
      newActiveIndex++;
    }

    state = ReaderTabsState(
      tabs: newTabs,
      activeIndex: newActiveIndex,
    );
  }

  /// Close all tabs.
  void closeAll() {
    state = const ReaderTabsState(tabs: []);
  }
}

/// Provider for managing open reader tabs.
final readerTabsProvider =
    StateNotifierProvider<ReaderTabsNotifier, ReaderTabsState>((ref) {
  return ReaderTabsNotifier();
});
