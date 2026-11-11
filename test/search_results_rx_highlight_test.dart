/// An Rx result card lights up the exact text the pattern matched. The Rx
/// state carries the Fuzzy flag on, so a card that trusted it would mark
/// `assa` and cut its snippet around that, away from the real `assā`.
library;

import 'package:epitaka/core/models/app_models.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/search/providers/search_provider.dart';
import 'package:epitaka/features/search/widgets/search_results_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedSearchNotifier extends SearchNotifier {
  _FixedSearchNotifier(super.ref, SearchResults results) {
    state = results;
  }
}

/// A line whose first `assa` stands far from the `assā` the pattern matched.
final _line =
    'jātisahassampi ${List.filled(30, 'ca').join(' ')} lokassā ti';

SearchResults _rxResults() => SearchResults(
  query: 'assā',
  totalResults: 1,
  regex: true,
  bookSummaries: [
    BookResultSummary(
      book: BookInfo(id: 1, bookId: 'b1', bookName: 'Book One'),
      totalCount: 1,
      isExpanded: true,
      loadedPages: [
        [
          SearchResultItem(
            bookId: 'b1',
            paraId: 7,
            lines: [SearchResultLine(lineId: 1, pali: _line, isMatch: true)],
            highlightTerms: const ['assā'],
          ),
        ],
      ],
    ),
  ],
);

List<String> _highlighted(WidgetTester tester) {
  final found = <String>[];
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    rich.text.visitChildren((span) {
      if (span is TextSpan &&
          span.text != null &&
          span.style?.backgroundColor != null) {
        found.add(span.text!);
      }
      return true;
    });
  }
  return found;
}

void main() {
  testWidgets('Rx card marks only assā, and keeps it in the snippet', (
    tester,
  ) async {
    final results = _rxResults();
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
            body: SizedBox(
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
    );
    await tester.pump();

    expect(_highlighted(tester), ['assā']);
  });
}
