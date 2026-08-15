// Regression: DPD headwords carry a homograph number suffix ("añña 1.1").
// The "Did you mean?" suggestion tiles show the full lemma, but TAPPING one
// must fill the search field with the CLEANED word ("añña"), not the raw
// "añña 1.1" — otherwise the re-search misses the lookup table.
//
// Drives the real [DictionaryPanel] against an in-memory DPD database seeded
// with homograph-numbered headwords, types a prefix, taps the suggestion,
// and asserts the search field got the number stripped.
library;

import 'package:drift/native.dart';
import 'package:epitaka/core/database/dpd_dictionary_database.dart';
import 'package:epitaka/core/database/epitaka_database.dart';
import 'package:epitaka/core/providers/database_provider.dart';
import 'package:epitaka/core/providers/dpd_dictionary_provider.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

/// In-memory DPD dictionary: lookup rows for homograph-numbered headwords so
/// a prefix search for 'aññ' returns them as "Did you mean?" suggestions.
DpdDictionaryDatabase _makeDpdDb() {
  final sqlite = sqlite3.openInMemory();
  sqlite.execute('CREATE TABLE dpd_lookup ('
      'lookup_key TEXT, headwords TEXT, deconstructor TEXT)');
  sqlite.execute('CREATE TABLE dpd_headwords ('
      'id INTEGER PRIMARY KEY, lemma_1 TEXT, meaning_html TEXT, '
      'antonym TEXT, synonym TEXT, stem TEXT, pattern TEXT)');
  // The real DPD stores lookup keys WITH the homograph number; the headword
  // lemma_1 also carries it ("añña 1.1", "aññā 2.1").
  sqlite.execute("INSERT INTO dpd_lookup VALUES ('añña 1.1', '[1]', '[]')");
  sqlite.execute("INSERT INTO dpd_lookup VALUES ('aññā 2.1', '[2]', '[]')");
  sqlite.execute(
    "INSERT INTO dpd_headwords VALUES "
    "(1, 'añña 1.1', '<p>another (indefinite)</p>', NULL, NULL, NULL, NULL)",
  );
  sqlite.execute(
    "INSERT INTO dpd_headwords VALUES "
    "(2, 'aññā 2.1', '<p>other</p>', NULL, NULL, NULL, NULL)",
  );
  return DpdDictionaryDatabase(sqlite);
}

Future<EpitakaDatabase> _makeEpitakaDb() async {
  final db = EpitakaDatabase(NativeDatabase.memory());
  await db.customStatement(
    'CREATE TABLE dictionary_books ('
    'id INTEGER, name TEXT, user_order INTEGER, user_choice INTEGER)',
  );
  await db.customStatement(
    "INSERT INTO dictionary_books VALUES (11, 'DPD Dictionary', 0, 1)",
  );
  return db;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ProviderContainer> makeContainer() async {
    final epitakaDb = await _makeEpitakaDb();
    final container = ProviderContainer(
      overrides: [
        epitakaDbProvider.overrideWith((ref) async => epitakaDb),
        dpdDictionaryDbProvider.overrideWith((ref) async => _makeDpdDb()),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(epitakaDb.close);
    final prefs = await SharedPreferences.getInstance();
    container.read(settingsProvider.notifier).init(prefs);
    return container;
  }

  Future<void> pumpPanel(WidgetTester tester, ProviderContainer container) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
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
          home: const Scaffold(body: DictionaryPanel()),
        ),
      ),
    );
    await tester.pump();
  }

  /// Advance the fake clock and flush the post-frame DB callbacks + debounce
  /// timers the panel relies on.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  testWidgets(
    'tapping a homograph-numbered "Did you mean?" suggestion fills the '
    'cleaned word without the number',
    (tester) async {
      final container = await makeContainer();
      await pumpPanel(tester, container);

      // Type a prefix that matches the numbered lookups exactly (no headword
      // for the bare prefix itself, so suggestions show).
      await tester.enterText(find.byType(TextField), 'aññ');
      await settle(tester);

      // The suggestions show the full lemma WITH the homograph number.
      expect(find.text('añña 1.1'), findsOneWidget);
      expect(find.text('aññā 2.1'), findsOneWidget);

      // Tap the first suggestion.
      await tester.tap(find.text('añña 1.1'));
      await settle(tester);

      // The search field must hold the CLEANED word — the re-search would
      // otherwise miss the lookup table.
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(
        field.controller!.text,
        'añña',
        reason: 'the homograph number " 1.1" must be stripped on tap',
      );
      expect(field.controller!.text, isNot(contains('1.1')));
    },
  );
}
