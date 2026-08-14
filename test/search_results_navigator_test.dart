import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/core/models/app_models.dart';
import '../lib/features/search/providers/search_provider.dart';
import '../lib/features/search/widgets/search_results_navigator.dart';

SearchResultItem _item(String bookId, int paraId) => SearchResultItem(
      bookId: bookId,
      paraId: paraId,
      lines: const [
        SearchResultLine(lineId: 1, pali: 'text', isMatch: true),
      ],
    );

BookResultSummary _summary(
  String bookId, {
  bool expanded = false,
  List<SearchResultItem> items = const [],
  int totalCount = 0,
  bool fullyLoaded = true,
}) {
  return BookResultSummary(
    book: BookInfo(id: 0, bookId: bookId, bookName: bookId),
    totalCount: totalCount,
    isExpanded: expanded,
    loadedPages: items.isEmpty ? const [] : [items],
    forceFullyLoaded: fullyLoaded,
  );
}

void main() {
  group('SearchResultsNavigator', () {
  test('flattens collapsed + expanded books into rows', () {
    final nav = SearchResultsNavigator();
    nav.rebuild(
      SearchResults(
        query: 'dhamma',
        totalResults: 3,
        bookSummaries: [
          _summary(
            'b1',
            expanded: true,
            items: [_item('b1', 1), _item('b1', 2)],
            totalCount: 2,
          ),
          _summary('b2'),
        ],
      ),
      includeHeadings: false,
    );

    expect(nav.rows.length, 4);
    expect(nav.rows[0].kind, SearchRowKind.bookHeader);
    expect(nav.rows[1].kind, SearchRowKind.resultItem);
    expect(nav.rows[2].kind, SearchRowKind.resultItem);
    expect(nav.rows[3].kind, SearchRowKind.bookHeader);
    expect(nav.rows[3].summaryIndex, 1);
    expect(nav.selectedRow?.kind, SearchRowKind.bookHeader);
  });

  test('a book with more matches than a loaded page gets a load-more row', () {
    final nav = SearchResultsNavigator();
    nav.rebuild(
      SearchResults(
        query: 'dhamma',
        totalResults: 40,
        bookSummaries: [
          _summary(
            'b1',
            expanded: true,
            items: [for (var i = 0; i < 30; i++) _item('b1', i + 1)],
            totalCount: 40,
            fullyLoaded: false,
          ),
        ],
      ),
      includeHeadings: false,
    );

    expect(nav.rows.length, 32); // header + 30 items + load-more
    expect(nav.rows.last.kind, SearchRowKind.loadMore);
  });

    test('j/k move the selection through the rows', () {
      final nav = SearchResultsNavigator();
      nav.rebuild(
        SearchResults(
          query: 'dhamma',
          totalResults: 2,
          bookSummaries: [
            _summary('b1', expanded: true, items: [_item('b1', 1)], totalCount: 1),
            _summary('b2'),
          ],
        ),
        includeHeadings: false,
      );

      nav.moveNext();
      expect(nav.selectedRow?.kind, SearchRowKind.resultItem);
      nav.moveNext();
      expect(nav.selectedRow?.kind, SearchRowKind.bookHeader);
      expect(nav.selectedRow?.summaryIndex, 1);

      // Rebuild keeps the selection on the same logical row.
      nav.rebuild(
        SearchResults(
          query: 'dhamma',
          totalResults: 2,
          bookSummaries: [
            _summary('b1', expanded: true, items: [_item('b1', 1)], totalCount: 1),
            _summary('b2'),
          ],
        ),
        includeHeadings: false,
      );
      expect(nav.selectedRow?.summaryIndex, 1);
    });

    test('movePrevious stops at the first row', () {
      final nav = SearchResultsNavigator();
      nav.rebuild(
        SearchResults(
          query: 'x',
          totalResults: 1,
          bookSummaries: [_summary('b1')],
        ),
        includeHeadings: false,
      );
      nav.movePrevious(); // no-op at top
      expect(nav.selected, 0);
    });

    test('handleSearchNavKey maps j/k/enter/escape', () {
      final nav = SearchResultsNavigator();
      nav.rebuild(
        SearchResults(
          query: 'x',
          totalResults: 1,
          bookSummaries: [_summary('b1')],
        ),
        includeHeadings: false,
      );

      var activated = 0;
      var escaped = 0;
      KeyEventResult handle(LogicalKeyboardKey key) => handleSearchNavKey(
            KeyDownEvent(
              physicalKey: PhysicalKeyboardKey.keyA,
              logicalKey: key,
              timeStamp: Duration.zero,
            ),
            nav,
            onActivate: () => activated++,
            onEscape: () => escaped++,
          );

      expect(handle(LogicalKeyboardKey.keyJ), KeyEventResult.handled);
      expect(nav.selected, 0); // single row — stays
      expect(handle(LogicalKeyboardKey.enter), KeyEventResult.handled);
      expect(activated, 1);
      expect(handle(LogicalKeyboardKey.escape), KeyEventResult.handled);
      expect(escaped, 1);
      expect(handle(LogicalKeyboardKey.keyA), KeyEventResult.ignored);
    });
  });
}
