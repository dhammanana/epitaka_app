import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../providers/search_provider.dart';

/// What a single keyboard-navigable row in the results list represents.
enum SearchRowKind {
  /// The "Section headings" card (only the full-screen view renders it).
  headingCard,

  /// A collapsible book header row (Enter toggles expand/collapse).
  bookHeader,

  /// A single search-result paragraph inside an expanded book.
  resultItem,

  /// The "load more" button of an expanded, partially loaded book.
  loadMore,
}

/// One flattened, keyboard-navigable row of a [SearchResults] list.
class SearchResultRow {
  final SearchRowKind kind;

  /// For [SearchRowKind.bookHeader] / [resultItem] / [loadMore].
  final BookResultSummary? summary;
  final int summaryIndex;

  /// For [SearchRowKind.resultItem].
  final SearchResultItem? item;

  /// For [SearchRowKind.headingCard].
  final List<HeadingResult>? headings;

  const SearchResultRow.book({
    required this.summary,
    required this.summaryIndex,
  }) : kind = SearchRowKind.bookHeader,
       item = null,
       headings = null;

  const SearchResultRow.item({
    required this.summary,
    required this.summaryIndex,
    required this.item,
  }) : kind = SearchRowKind.resultItem,
       headings = null;

  const SearchResultRow.loadMore({
    required this.summary,
    required this.summaryIndex,
  }) : kind = SearchRowKind.loadMore,
       item = null,
       headings = null;

  const SearchResultRow.headings(this.headings)
    : kind = SearchRowKind.headingCard,
      summary = null,
      summaryIndex = -1,
      item = null;
}

/// Flattens a [SearchResults] state into keyboard-navigable rows and tracks
/// the selection. Shared by the sidebar search panel and the full-screen
/// search view so j/k + Enter behave identically everywhere.
class SearchResultsNavigator extends ChangeNotifier {
  List<SearchResultRow> rows = const [];
  int selected = 0;

  bool get isEmpty => rows.isEmpty;

  SearchResultRow? get selectedRow =>
      rows.isEmpty || selected < 0 || selected >= rows.length
      ? null
      : rows[selected];

  /// Rebuild the flattened rows from [state], keeping the selection on the
  /// same logical row (by book + item identity) when possible. The sidebar
  /// panel doesn't render heading results, so it passes
  /// [includeHeadings] = false to keep the row list in sync with its UI.
  ///
  /// Deliberately does NOT call [notifyListeners]: the views call this from
  /// `build` (they are already rebuilding), and only the key handlers
  /// ([moveNext] / [movePrevious] / [selectFirst]) notify.
  void rebuild(SearchResults state, {bool includeHeadings = true}) {
    final previous = selectedRow;
    final newRows = <SearchResultRow>[];

    if (includeHeadings && state.headings.isNotEmpty) {
      newRows.add(SearchResultRow.headings(state.headings));
    }
    for (var i = 0; i < state.bookSummaries.length; i++) {
      final summary = state.bookSummaries[i];
      newRows.add(SearchResultRow.book(summary: summary, summaryIndex: i));
      if (summary.isExpanded) {
        for (final page in summary.loadedPages) {
          for (final item in page) {
            newRows.add(
              SearchResultRow.item(
                summary: summary,
                summaryIndex: i,
                item: item,
              ),
            );
          }
        }
        if (!summary.fullyLoaded) {
          newRows.add(SearchResultRow.loadMore(summary: summary, summaryIndex: i));
        }
      }
    }

    rows = newRows;
    // Restore the selection on the same row (or fall back to the closest
    // valid index — usually 0 or the previous index).
    if (previous != null) {
      final match = newRows.indexWhere(
        (r) =>
            r.kind == previous.kind &&
            r.summaryIndex == previous.summaryIndex &&
            (r.item?.paraId == previous.item?.paraId),
      );
      if (match >= 0) {
        selected = match;
      } else if (selected >= newRows.length) {
        selected = newRows.isEmpty ? 0 : newRows.length - 1;
      }
    } else if (selected >= newRows.length) {
      selected = newRows.isEmpty ? 0 : newRows.length - 1;
    }
  }

  void moveNext() {
    if (rows.isEmpty) return;
    if (selected < rows.length - 1) {
      selected++;
      notifyListeners();
    }
  }

  void movePrevious() {
    if (rows.isEmpty) return;
    if (selected > 0) {
      selected--;
      notifyListeners();
    }
  }

  /// Point the selection at the first result item (used when results first
  /// appear so j immediately moves into the list).
  void selectFirst() {
    if (rows.isEmpty || selected == 0) return;
    selected = 0;
    notifyListeners();
  }
}

/// Handle the search-navigation keys (j/k, ↑/↓, Enter/Space, Esc) for a
/// focused results list. Returns whether the key was consumed.
KeyEventResult handleSearchNavKey(
  KeyEvent event,
  SearchResultsNavigator nav, {
  required VoidCallback onActivate,
  required VoidCallback onEscape,
}) {
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
    return KeyEventResult.ignored;
  }
  final key = event.logicalKey;
  if (key == LogicalKeyboardKey.keyJ ||
      key == LogicalKeyboardKey.arrowDown) {
    nav.moveNext();
    return KeyEventResult.handled;
  }
  if (key == LogicalKeyboardKey.keyK ||
      key == LogicalKeyboardKey.arrowUp) {
    nav.movePrevious();
    return KeyEventResult.handled;
  }
  if (key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter ||
      key == LogicalKeyboardKey.space) {
    onActivate();
    return KeyEventResult.handled;
  }
  if (key == LogicalKeyboardKey.escape) {
    onEscape();
    return KeyEventResult.handled;
  }
  return KeyEventResult.ignored;
}
