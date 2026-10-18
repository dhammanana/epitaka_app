/// The desktop sidebar search must build only the hits near the screen, as
/// the full results screen does (`search_results_lazy_test.dart`). Before the
/// fix an expanded book was one list item holding a Column of every hit, so
/// "dhamma" with Paṭṭh-v open held about 1.28 GB in the Linux app.
library;

import 'package:epitaka/core/database/app_database.dart';
import 'package:epitaka/core/models/app_models.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/search/providers/search_provider.dart';
import 'package:epitaka/features/search/widgets/search_panel.dart';
import 'package:epitaka/shared/widgets/velthuis_help_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/type_keys.dart';

const _hitCount = 500;

class _FixedSearchNotifier extends SearchNotifier {
  _FixedSearchNotifier(super.ref, SearchResults results) {
    state = results;
  }

  @override
  Future<void> ensureIndexBuilt() async {}

  @override
  Future<List<SearchSuggestion>> getSuggestions(String prefix) async => [];
}

SearchResults _results() {
  final items = [
    for (var p = 1; p <= _hitCount; p++)
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
    totalResults: _hitCount,
    bookSummaries: [
      BookResultSummary(
        book: BookInfo(id: 1, bookId: 'b1', bookName: 'Book One'),
        totalCount: _hitCount,
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

ScrollPosition _resultsPosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    )
    .position;

Future<void> _pump(WidgetTester tester) async {
  final results = _results();
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
        home: const Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 320, height: 700, child: SearchPanel()),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Focus the results list, as a search from the panel's field does.
Future<void> _focusResults(WidgetTester tester) async {
  tester
      .widget<Focus>(
        find
            .ancestor(of: find.byType(ListView), matching: find.byType(Focus))
            .first,
      )
      .focusNode!
      .requestFocus();
  await tester.pump();
}

void main() {
  testWidgets(
      'Velthuis turns into diacritics; the help icon shows, empty or with text',
      (tester) async {
    await _pump(tester);
    final help = find.descendant(
      of: find.byType(TextField),
      matching: find.byType(VelthuisHelpIcon),
    );
    expect(help, findsOneWidget);

    await typeKeys(tester, find.byType(TextField), 'paali');
    // The box redraws after the 120 ms suggestion pause.
    await tester.pump(const Duration(milliseconds: 200));
    expect(help, findsOneWidget);
    expect(find.byIcon(Icons.clear), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'pāli',
    );
  });

  testWidgets('only the hits near the screen are built', (tester) async {
    await _pump(tester);
    expect(find.text('§1'), findsOneWidget);
    expect(_builtTiles(), lessThan(50));
  });

  testWidgets('a hit sits where it sat inside the old book card', (
    tester,
  ) async {
    await _pump(tester);
    // Measured with the old Card-per-book panel in this same layout, plus
    // the 8 px gap now under the search box (spec J). A border that pads the
    // row (a Container's border does) moves both.
    expect(tester.getTopLeft(find.text('§1')), const Offset(19.2, 167.6));
    expect(tester.getTopLeft(find.text('Book One')), const Offset(37.2, 132.7));
  });

  testWidgets('scrolling to the end shows the last hit', (tester) async {
    await _pump(tester);
    final position = _resultsPosition(tester);
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
    await _pump(tester);
    await _focusResults(tester);

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
    await _pump(tester);
    await _focusResults(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    // Scroll far down with the mouse; hit 1 and hit 2 are no longer built.
    final position = _resultsPosition(tester);
    position.jumpTo(position.maxScrollExtent / 2);
    await tester.pumpAndSettle();
    expect(find.text('§2', skipOffstage: false), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(find.text('§2'), findsOneWidget);
    expect(_isHighlighted(tester, 2), isTrue);
  });
}
