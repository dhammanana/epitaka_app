import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/startup_timing.dart';
import '../services/book_family_service.dart';

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

  /// Book ids of the tabs shown side by side (mūla, aṭṭhakathā, ṭīkā of one
  /// text, in that order), or empty. Never a single book.
  final List<String> columns;

  /// Whether each split line between two [columns] keeps the pair scrolling
  /// together, left to right. Missing entries are locked; a change of
  /// [columns] locks every split again.
  final List<bool> columnLocks;

  const ReaderTabsState({
    required this.tabs,
    this.activeIndex = 0,
    this.columns = const [],
    this.columnLocks = const [],
  });

  bool isSplitLocked(int split) =>
      split >= columnLocks.length || columnLocks[split];

  bool get isEmpty => tabs.isEmpty;
  bool get isNotEmpty => tabs.isNotEmpty;
  int get length => tabs.length;

  ReaderTabInfo? get activeTab =>
      tabs.isNotEmpty && activeIndex < tabs.length ? tabs[activeIndex] : null;
}

/// StateNotifier that manages a list of open reader tabs.
class ReaderTabsNotifier extends StateNotifier<ReaderTabsState> {
  ReaderTabsNotifier([super.state = const ReaderTabsState(tabs: [])]);

  /// Incremented for every explicit jump request so the reader can tell a
  /// NEW request (even for the same paragraph) from a stale rebuild.
  int _jumpRequestCounter = 0;

  /// Open a tab (by bookId). If already open, switch to it and update
  /// fields like [searchQuery].
  void openTab(ReaderTabInfo tab) {
    StartupTiming.mark('book open requested: ${tab.bookId}');
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
        columns: state.columns,
        columnLocks: state.columnLocks,
      );
      return;
    }
    state = ReaderTabsState(
      tabs: [...state.tabs, resolvedTab],
      activeIndex: state.tabs.length,
      columns: state.columns,
      columnLocks: state.columnLocks,
    );
  }

  /// Close the tab at [index]. If the active tab is closed, switch to an
  /// adjacent tab. If all tabs are closed, state becomes empty.
  void closeTab(int index) {
    if (state.tabs.isEmpty || index >= state.tabs.length) return;

    final closedBookId = state.tabs[index].bookId;
    final closedColumn = state.columns.indexOf(closedBookId);
    final newTabs = [...state.tabs]..removeAt(index);

    if (newTabs.isEmpty) {
      state = const ReaderTabsState(tabs: []);
      return;
    }

    int newActiveIndex = state.activeIndex;
    if (index <= newActiveIndex) {
      newActiveIndex = (newActiveIndex - 1).clamp(0, newTabs.length - 1);
    }

    // Closing the focused column hands focus to its neighbour column, so
    // the remaining columns stay on screen (the reader shows columns only
    // while the active tab is one of them).
    if (closedColumn >= 0 && state.activeTab?.bookId == closedBookId) {
      final rest = [...state.columns]..removeAt(closedColumn);
      final neighbour = rest[closedColumn > 0 ? closedColumn - 1 : 0];
      newActiveIndex = newTabs.indexWhere((t) => t.bookId == neighbour);
    }

    state = ReaderTabsState(
      tabs: newTabs,
      activeIndex: newActiveIndex,
      columns: _withoutColumn(state.columns, closedBookId),
      // The splits move when a column goes; closing any other tab keeps them.
      columnLocks: closedColumn >= 0 ? const [] : state.columnLocks,
    );
  }

  /// Switch to the tab at [index].
  void switchTo(int index) {
    if (index >= 0 && index < state.tabs.length) {
      state = ReaderTabsState(
        tabs: state.tabs,
        activeIndex: index,
        columns: state.columns,
        columnLocks: state.columnLocks,
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
      columns: state.columns,
      columnLocks: state.columnLocks,
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
      columns: state.columns,
      columnLocks: state.columnLocks,
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
    final columns = _inTabOrder(state.columns, newTabs);
    final columnsMoved = !_sameOrder(columns, state.columns);

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
      columns: columns,
      columnLocks: columnsMoved ? const [] : state.columnLocks,
    );
  }

  /// Show [target] as a column beside the tab of [sourceBookId], or close
  /// its tab when it already shows.
  ///
  /// The target opens as a tab (or reuses its tab, jumping to
  /// [target]'s `initialParaId` when set) while the source tab stays active.
  /// A new tab goes beside the other columns' tabs in [family]'s level
  /// order, and the columns show in tab order: the tab strip and the reader
  /// always list the books alike. A book on a level that already shows
  /// replaces that column; the replaced book stays open as a tab. When the
  /// source is not a column yet, the columns start again from the source
  /// alone.
  void toggleFamilyColumn(
    ReaderTabInfo target, {
    required String sourceBookId,
    required BookFamily family,
  }) {
    final sourceIndex = state.tabs.indexWhere((t) => t.bookId == sourceBookId);
    if (sourceIndex < 0 || target.bookId == sourceBookId) return;
    final levelOf = {
      for (final level in BookLevel.values)
        for (final bookId in family.booksAt(level)) bookId: level,
    };
    final targetLevel = levelOf[target.bookId];
    if (targetLevel == null) return;

    final current = state.columns.contains(sourceBookId)
        ? state.columns.where(levelOf.containsKey).toList()
        : [sourceBookId];

    if (current.contains(target.bookId)) {
      closeTab(state.tabs.indexWhere((t) => t.bookId == target.bookId));
      return;
    }

    final kept = current.where((id) => levelOf[id] != targetLevel).toList();

    final jumpTab = target.initialParaId != null
        ? ReaderTabInfo(
            bookId: target.bookId,
            bookName: target.bookName,
            bookDescription: target.bookDescription,
            initialParaId: target.initialParaId,
            initialLineId: target.initialLineId,
            initialJumpId: ++_jumpRequestCounter,
          )
        : null;
    final tabs = [...state.tabs];
    final existingIndex = tabs.indexWhere((t) => t.bookId == target.bookId);
    if (existingIndex < 0) {
      tabs.insert(
        _familyTabIndex(tabs, kept, levelOf, targetLevel),
        jumpTab ?? target,
      );
    } else if (jumpTab != null) {
      final existing = tabs[existingIndex];
      tabs[existingIndex] = ReaderTabInfo(
        bookId: existing.bookId,
        bookName: existing.bookName,
        bookDescription: existing.bookDescription,
        initialParaId: jumpTab.initialParaId,
        initialLineId: jumpTab.initialLineId,
        initialJumpId: jumpTab.initialJumpId,
        searchQuery: existing.searchQuery,
        scrollOffset: existing.scrollOffset,
        currentParaId: existing.currentParaId,
        currentLineId: existing.currentLineId,
      );
    }
    state = ReaderTabsState(
      tabs: tabs,
      activeIndex: tabs.indexWhere((t) => t.bookId == sourceBookId),
      columns: _inTabOrder([...kept, target.bookId], tabs),
    );
  }

  /// Where a new family tab goes: after the last column tab of a lower
  /// level, else before the first column tab of a higher one, else last.
  static int _familyTabIndex(
    List<ReaderTabInfo> tabs,
    List<String> columns,
    Map<String, BookLevel> levelOf,
    BookLevel level,
  ) {
    int? after;
    int? before;
    for (var i = 0; i < tabs.length; i++) {
      final columnLevel = columns.contains(tabs[i].bookId)
          ? levelOf[tabs[i].bookId]
          : null;
      if (columnLevel == null) continue;
      if (columnLevel.index < level.index) after = i;
      if (columnLevel.index > level.index) before ??= i;
    }
    if (after != null) return after + 1;
    return before ?? tabs.length;
  }

  static List<String> _inTabOrder(
    List<String> columns,
    List<ReaderTabInfo> tabs,
  ) => [
    for (final tab in tabs)
      if (columns.contains(tab.bookId)) tab.bookId,
  ];

  static bool _sameOrder(List<String> a, List<String> b) =>
      a.length == b.length &&
      [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((same) => same);

  /// Locks or unlocks the split line [split] (between columns [split] and
  /// [split] + 1).
  void toggleColumnLock(int split) {
    if (split < 0 || split >= state.columns.length - 1) return;
    final locks = [
      for (var i = 0; i < state.columns.length - 1; i++)
        state.isSplitLocked(i),
    ];
    locks[split] = !locks[split];
    state = ReaderTabsState(
      tabs: state.tabs,
      activeIndex: state.activeIndex,
      columns: state.columns,
      columnLocks: locks,
    );
  }

  /// One book left is not a set of columns, so it clears them.
  static List<String> _withoutColumn(List<String> columns, String bookId) {
    final rest = columns.where((id) => id != bookId).toList();
    return rest.length < 2 ? const [] : rest;
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
