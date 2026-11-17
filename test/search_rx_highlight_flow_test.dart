/// The whole Rx path for `assā`: the real scan, the real [SearchNotifier],
/// and the real result card. The sentence is real text from MN 2.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:epitaka/core/database/app_database.dart';
import 'package:epitaka/core/database/epitaka_database.dart';
import 'package:epitaka/core/providers/app_db_provider.dart';
import 'package:epitaka/core/providers/database_provider.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/search/providers/search_provider.dart';
import 'package:epitaka/features/search/services/regex_search.dart';
import 'package:epitaka/features/search/widgets/search_panel.dart';
import 'package:epitaka/features/search/widgets/search_results_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// Holds finished results, and keeps the panel off the real index build and
/// the word list, as `search_panel_lazy_test.dart` does.
class _FixedSearchNotifier extends SearchNotifier {
  _FixedSearchNotifier(super.ref, SearchResults results) {
    state = results;
  }

  @override
  Future<void> ensureIndexBuilt() async {}

  @override
  Future<List<SearchSuggestion>> getSuggestions(String prefix) async => [];
}

/// MN 2, §9, line 3, as stored in epitaka.db: it holds one `assā`
/// (`dukkhadomanassānaṃ`) and two plain `assa` (`ñāyassa`, `nibbānassa`).
const _line =
    'Yāva supaññattā cime, bhante, bhagavatā cattāro satipaṭṭhānā sattānaṃ '
    'visuddhiyā sokaparidevānaṃ [sokapariddavānaṃ (sī. pī.)] samatikkamāya '
    'dukkhadomanassānaṃ atthaṅgamāya ñāyassa adhigamāya nibbānassa '
    'sacchikiriyāya.';

Future<EpitakaDatabase> _fixtureEpitakaDb(File file) async {
  final db = EpitakaDatabase(NativeDatabase(file));
  await db.customStatement('''
    CREATE TABLE books (
      id INTEGER PRIMARY KEY AUTOINCREMENT, ref_id INTEGER, vri_id TEXT,
      book_id TEXT NOT NULL, category TEXT, nikaya TEXT, sub_nikaya TEXT,
      book_name TEXT, description TEXT, mula_ref TEXT, attha_ref TEXT,
      tika_ref TEXT, para_id INTEGER, chapter_len INTEGER
    )
  ''');
  await db.customStatement('''
    CREATE TABLE headings (
      book_id TEXT NOT NULL, para_id INTEGER NOT NULL, level INTEGER,
      title TEXT, chapter_len INTEGER, parent INTEGER, sc_id TEXT,
      PRIMARY KEY (book_id, para_id)
    )
  ''');
  await db.customStatement('''
    CREATE TABLE sentences (
      book_id TEXT NOT NULL, para_id INTEGER NOT NULL, line_id INTEGER NOT NULL,
      vripara TEXT, pali TEXT, PRIMARY KEY (book_id, para_id, line_id)
    )
  ''');
  await db.customStatement(
    "INSERT INTO books(book_id, category, nikaya, book_name) "
    "VALUES ('m3', 'Mūla', 'Sutta Piṭaka', 'MN3')",
  );
  await db.customStatement(
    "INSERT INTO headings(book_id, para_id, level, title) VALUES ('m3', 1, 1, 'MN3')",
  );
  await db.customStatement(
    "INSERT INTO sentences(book_id, para_id, line_id, pali) VALUES ('m3', 18, 1, ?)",
    [_line],
  );
  return db;
}

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
  late Directory dir;
  late AppDatabase appDb;
  late EpitakaDatabase epiDb;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('rx_flow_');
    appDb = AppDatabase(NativeDatabase(File(p.join(dir.path, 'app_data.db'))));
    epiDb = await _fixtureEpitakaDb(File(p.join(dir.path, 'epitaka.db')));
    await appDb.buildSearchIndex(epiDb);
  });

  tearDown(() async {
    await appDb.close();
    await epiDb.close();
    await dir.delete(recursive: true);
  });

  Future<ProviderContainer> searchRx(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        appDbProvider.overrideWith((ref) async => appDb),
        epitakaDbProvider.overrideWith((ref) async => epiDb),
        translationDbProvider('en').overrideWith((ref) async => null),
        settingsProvider.overrideWith((ref) => SettingsNotifier(null)),
        regexScanProvider.overrideWithValue(
          (pattern) async =>
              scanPaliRegex(p.join(dir.path, 'epitaka.db'), pattern),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(
      () => container
          .read(searchProvider.notifier)
          .search(query: 'assā', regex: true),
    );
    final state = container.read(searchProvider) as SearchResults;
    expect(state.regex, isTrue);
    expect(state.bookSummaries.single.totalCount, 1);
    return container;
  }

  Widget app(ProviderContainer container, Widget body) =>
      UncontrolledProviderScope(
        container: container,
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
              alignment: Alignment.topLeft,
              child: SizedBox(width: 400, height: 600, child: body),
            ),
          ),
        ),
      );

  testWidgets('Rx assā marks only assā in the results screen card', (
    tester,
  ) async {
    final container = await searchRx(tester);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      app(
        container,
        SearchResultsView(
          state: container.read(searchProvider) as SearchResults,
          resultsFocusNode: focus,
        ),
      ),
    );
    await tester.pump();

    expect(_highlighted(tester), ['assā']);
  });

  testWidgets('Rx assā marks only assā in the sidebar panel', (tester) async {
    final done = await searchRx(tester);
    final results = done.read(searchProvider) as SearchResults;
    final container = ProviderContainer(
      overrides: [
        searchProvider.overrideWith(
          (ref) => _FixedSearchNotifier(ref, results),
        ),
        settingsProvider.overrideWith((ref) => SettingsNotifier(null)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(app(container, const SearchPanel()));
    await tester.pump();

    expect(_highlighted(tester), ['assā']);
  });
}
