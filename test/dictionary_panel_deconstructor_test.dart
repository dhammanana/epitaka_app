// Regression: the desktop [DictionaryPanel] used to render only the DPD
// headwords — compound words like "cirakālasamparicitaṃ" that have a
// deconstructor (word breakup) but no direct headword with a meaning showed
// nothing but the searched-word title. The mobile sheet always rendered the
// "Compound breakdown" section; the panel now does too.
//
// This test drives the real [DictionaryPanel] against an in-memory DPD
// database seeded with a deconstructor-only lookup (the user's exact case)
// and asserts the breakup renders, expands, and sub-looks-up a token.
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

const _compound = 'cirakālasamparicitaṃ';

/// In-memory DPD dictionary matching the real schema: a lookup for the
/// compound word with a deconstructor and NO headwords (so only the word
/// breakup can be shown), plus a `cira` lookup → headword 1 for the
/// token sub-lookup.
DpdDictionaryDatabase _makeDpdDb() {
  final sqlite = sqlite3.openInMemory();
  sqlite.execute('CREATE TABLE dpd_lookup ('
      'lookup_key TEXT, headwords TEXT, deconstructor TEXT)');
  sqlite.execute('CREATE TABLE dpd_headwords ('
      'id INTEGER PRIMARY KEY, lemma_1 TEXT, meaning_html TEXT, '
      'antonym TEXT, synonym TEXT, stem TEXT, pattern TEXT)');
  // The deconstructor column is a JSON array of CANDIDATE strings, each
  // candidate being one "+"-joined token sequence (as in the real DPD db).
  sqlite.execute(
    "INSERT INTO dpd_lookup VALUES ('$_compound', '[]', "
    "'[\"cira+kāla+samparicita\"]')",
  );
  sqlite.execute("INSERT INTO dpd_lookup VALUES ('cira', '[1]', '[]')");
  sqlite.execute(
    "INSERT INTO dpd_headwords VALUES "
    "(1, 'cira', '<p>long (time)</p>', NULL, NULL, NULL, NULL)",
  );
  return DpdDictionaryDatabase(sqlite);
}

/// In-memory epitaka.db with a `dictionary_books` row enabling the DPD
/// dictionary (id=11) so the panel renders the DPD section.
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

  /// Advance the fake clock and flush the post-frame DB callbacks that
  /// dpdDictionaryLookupProvider / dpdSubLookupProvider rely on.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets(
    'a deconstructor-only compound word shows its word breakup in the panel',
    (tester) async {
      final container = await makeContainer();
      await pumpPanel(tester, container);

      await tester.enterText(find.byType(TextField), _compound);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);

      // The searched word is the title…
      expect(find.textContaining(_compound), findsWidgets,
          reason: 'the searched word must appear as the DPD section title');
      // …and the word breakup (deconstructor) is rendered — the bug was
      // that ONLY the title showed for compound words.
      final loc = AppLocalizations.of(
        tester.element(find.byType(DictionaryPanel)),
      );
      expect(find.text(loc.compoundBreakdown), findsOneWidget,
          reason: 'the desktop panel must show the Compound breakdown section');
      expect(find.text('cira + kāla + samparicita'), findsOneWidget,
          reason: 'the deconstructor tokens joined with " + " must be shown');

      // Expand the card: token chips appear and the active token's
      // sub-lookup renders its headword meaning.
      await tester.tap(find.text('cira + kāla + samparicita'));
      await settle(tester);

      expect(find.text('cira'), findsWidgets,
          reason: 'expanding the card shows its token chips');
      expect(find.textContaining('long (time)'), findsOneWidget,
          reason: 'the active token sub-lookup renders the headword meaning');
    },
  );
}
