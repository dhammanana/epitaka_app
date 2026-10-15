/// The search results list must build only the hits near the screen. Before
/// the fix an expanded book was one list item holding a Column of every hit,
/// so a book with 3,517 hits built 3,517 tiles on each redraw (a 5 s frame on
/// a Pixel 8 Pro while the hits loaded).
library;

import 'package:epitaka/core/models/app_models.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/search/providers/search_provider.dart';
import 'package:epitaka/features/search/widgets/search_results_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _hitCount = 500;

class _FixedSearchNotifier extends SearchNotifier {
  _FixedSearchNotifier(super.ref, SearchResults results) {
    state = results;
  }
}

SearchResults _results(int hitCount) {
  final items = [
    for (var p = 1; p <= hitCount; p++)
      SearchResultItem(
        bookId: 'b1',
        paraId: p,
        lines: const [
          SearchResultLine(lineId: 1, pali: 'dhamma', isMatch: true),
        ],
      ),
  ];
  return SearchResults(
    query: 'dhamma',
    totalResults: hitCount,
    bookSummaries: [
      BookResultSummary(
        book: BookInfo(id: 1, bookId: 'b1', bookName: 'Book One'),
        totalCount: hitCount,
        isExpanded: true,
        loadedPages: [
          for (var i = 0; i < items.length; i += kSearchPageSize)
            items.sublist(i, (i + kSearchPageSize).clamp(0, items.length)),
        ],
      ),
    ],
  );
}

/// Every hit tile shows its paragraph badge `§<paraId>`; counting them with
/// skipOffstage off counts the tiles that were built, on screen or not.
int _builtTiles() =>
    find.textContaining('§', skipOffstage: false).evaluate().length;

/// The selection highlight is the nearest AnimatedContainer above the tile.
bool _isHighlighted(WidgetTester tester, int paraId) {
  final box = tester.widget<AnimatedContainer>(
    find
        .ancestor(
          of: find.text('§$paraId'),
          matching: find.byType(AnimatedContainer),
        )
        .first,
  );
  final color = (box.decoration as BoxDecoration?)?.color;
  return color != null && color != Colors.transparent;
}

Future<FocusNode> _pump(WidgetTester tester, {int hitCount = _hitCount}) async {
  final results = _results(hitCount);
  final focus = FocusNode();
  addTearDown(focus.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        searchProvider.overrideWith(
          (ref) => _FixedSearchNotifier(ref, results),
        ),
      ],
      child: MaterialApp(
        supportedLocales: AppLocalizationsDelegate.supportedLocales,
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 400,
              height: 600,
              child: SearchResultsView(
                state: results,
                resultsFocusNode: focus,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return focus;
}

void main() {
  testWidgets('only the hits near the screen are built', (tester) async {
    await _pump(tester);
    expect(find.text('§1'), findsOneWidget);
    expect(_builtTiles(), lessThan(50));
  });

  testWidgets('a hit sits where it sat inside the old book card', (tester) async {
    await _pump(tester);
    // Measured with the old Card-per-book list in this same layout. A border
    // that pads the row (a Container's border does) moves both.
    expect(tester.getTopLeft(find.text('§1')), const Offset(237.2, 68.6));
    expect(tester.getTopLeft(find.text('Book One')), const Offset(273.2, 22.2));
  });

  testWidgets('scrolling to the end shows the last hit', (tester) async {
    await _pump(tester);
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    // A lazy list only estimates its length, so jump until the end holds.
    for (var i = 0; i < 20; i++) {
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      if (position.pixels == position.maxScrollExtent) break;
    }
    expect(find.text('§$_hitCount'), findsOneWidget);
    expect(_builtTiles(), lessThan(50));
  });

  testWidgets('the keyboard-selected hit is highlighted', (tester) async {
    final focus = await _pump(tester);
    focus.requestFocus();
    await tester.pump();

    // Row 0 is the book header; each Down moves one row.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_isHighlighted(tester, 1), isTrue);
    expect(_isHighlighted(tester, 2), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_isHighlighted(tester, 1), isFalse);
    expect(_isHighlighted(tester, 2), isTrue);
  });

  testWidgets('a selection scrolled far away comes back into view', (
    tester,
  ) async {
    final focus = await _pump(tester);
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    // Scroll far down with the mouse; hit 1 and hit 2 are no longer built.
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    position.jumpTo(position.maxScrollExtent / 2);
    await tester.pumpAndSettle();
    expect(find.text('§2', skipOffstage: false), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(find.text('§2'), findsOneWidget);
    expect(_isHighlighted(tester, 2), isTrue);
  });

  testWidgets('a selection thousands of rows away still comes back into view', (
    tester,
  ) async {
    // About 300 screens of rows: more than the 100 one-screen steps the
    // reveal may take, so a first jump toward the row must do most of it.
    final focus = await _pump(tester, hitCount: 6000);
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.text('§2', skipOffstage: false), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(find.text('§2'), findsOneWidget);
  });
}
