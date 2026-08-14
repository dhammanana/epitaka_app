/// Regression: text inside dictionary results is selectable, and the
/// selection toolbar offers a "Search '…'" action that re-looks-up the
/// selected word — the cheap alternative to per-word tappable links (which
/// were dropped for performance).
///
/// Both the mobile bottom sheet ([DictionarySheet]) and the desktop sidebar
/// panel ([DictionaryPanel]) wrap their results in a [SelectionArea] with
/// this toolbar. Double-tapping a Pāli word inside a definition must select
/// it and show `Search “word”`; tapping that re-searches the dictionary.
library;

import 'package:epitaka/core/database/dpd_dictionary_database.dart';
import 'package:epitaka/core/providers/dictionary_books_provider.dart';
import 'package:epitaka/core/providers/dpd_dictionary_provider.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_panel.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stubbed DPD lookup: querying 'dhamma' returns one headword whose lemma is
/// a *different* word ('khetta') — so the test can select a word that isn't
/// already the search term and observe the re-search.
DpdFullLookup _lookup(String word) => DpdFullLookup(
      searchedKey: word,
      headwords: const [
        DpdHeadwordRow(
          id: 1,
          lemma1: 'khetta',
          meaningHtml: '<b>khetta</b>',
        ),
      ],
    );

/// Stub for [DictionaryBooksNotifier]: skips the real database and reports
/// one enabled dictionary (the DPD, id 11) so results render in the test.
class _FakeBooksNotifier extends DictionaryBooksNotifier {
  _FakeBooksNotifier(super.ref);

  @override
  Future<void> load() async {
    state = AsyncData(const [
      DictionaryBook(id: 11, name: 'DPD', userOrder: 1, userChoice: true),
    ]);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ProviderContainer> makeContainer() async {
    final container = ProviderContainer(overrides: [
      // Override every word the test might search (the initial 'dhamma' and
      // the re-search target 'khetta') so neither hits the real database.
      dpdDictionaryLookupProvider('dhamma').overrideWith(
        (ref) async => _lookup('dhamma'),
      ),
      dpdDictionaryLookupProvider('khetta').overrideWith(
        (ref) async => _lookup('khetta'),
      ),
      dictionaryBooksNotifierProvider.overrideWith(
        (ref) => _FakeBooksNotifier(ref),
      ),
    ]);
    addTearDown(container.dispose);
    final prefs = await SharedPreferences.getInstance();
    container.read(settingsProvider.notifier).init(prefs);
    return container;
  }

  Widget wrap(ProviderContainer container, Widget child) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizationsDelegate.supportedLocales,
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: child),
      ),
    );
  }

  /// Two taps ~90ms apart, the second held past kPressTimeout — the same
  /// gesture sequence SelectionArea needs to land its word selection.
  Future<void> doubleTapAt(WidgetTester tester, Offset pos) async {
    final g1 = await tester.startGesture(pos);
    await tester.pump();
    await g1.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final g2 = await tester.startGesture(pos);
    await tester.pump(const Duration(milliseconds: 150));
    await g2.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('dictionary sheet: double-tap selects a word and Search '
      're-looks it up', (tester) async {
    // Wide enough that the selection toolbar's three buttons (Search / Copy /
    // Select All) fit without overflowing into the "…" menu. Still mobile
    // (the test platform is Android, so isDesktop is false) — the sheet
    // renders as the bottom sheet either way.
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = await makeContainer();
    await tester.pumpWidget(
      wrap(container, const DictionarySheet(initialWord: 'dhamma')),
    );
    await tester.pumpAndSettle();

    // The results render the headword lemma ('khetta') — a word to select.
    expect(find.text('khetta'), findsWidgets);

    // Double-tap the bold Pāli word inside the definition.
    await doubleTapAt(tester, tester.getCenter(find.text('khetta').first));
    await tester.pumpAndSettle();

    // The selection toolbar offers the Search action + Copy + Select All.
    expect(find.text('Search “khetta”'), findsOneWidget,
        reason: 'toolbar lets the user re-search the selected word');
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Select All'), findsOneWidget);

    // Tapping Search re-runs the dictionary lookup for the selected word.
    await tester.tap(find.text('Search “khetta”'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'khetta',
        reason: 'the search field now holds the selected word');
  });

  testWidgets('dictionary panel: Search toolbar re-looks up the selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = await makeContainer();
    await tester.pumpWidget(
      wrap(
        container,
        const SizedBox(
          width: 400,
          height: 600,
          child: DictionaryPanel(initialWord: 'dhamma'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('khetta'), findsWidgets);

    await doubleTapAt(tester, tester.getCenter(find.text('khetta').first));
    await tester.pumpAndSettle();

    expect(find.text('Search “khetta”'), findsOneWidget);

    await tester.tap(find.text('Search “khetta”'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'khetta',
        reason: 'the panel search field now holds the selected word');
  });
}
