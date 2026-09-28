// Arrow Up/Down moves through the dictionary suggestion dropdown and Enter
// accepts the highlighted row (desktop keyboard flow). Typing alone only
// fills the draft; without a highlight Enter still submits the raw text.
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
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

DpdDictionaryDatabase _makeDpdDb() {
  final sqlite = sqlite3.openInMemory();
  sqlite.execute(
    'CREATE TABLE dpd_lookup ('
    'lookup_key TEXT, headwords TEXT, deconstructor TEXT)',
  );
  sqlite.execute(
    'CREATE TABLE dpd_headwords ('
    'id INTEGER PRIMARY KEY, lemma_1 TEXT, meaning_html TEXT, '
    'antonym TEXT, synonym TEXT, stem TEXT, pattern TEXT)',
  );
  sqlite.execute("INSERT INTO dpd_lookup VALUES ('añña 1.1', '[1]', '[]')");
  sqlite.execute("INSERT INTO dpd_lookup VALUES ('aññā 2.1', '[2]', '[]')");
  sqlite.execute("INSERT INTO dpd_lookup VALUES ('amma 1.1', '[3]', '[]')");
  sqlite.execute(
    "INSERT INTO dpd_headwords VALUES "
    "(1, 'añña 1.1', '<p>another (indefinite)</p>', NULL, NULL, NULL, NULL)",
  );
  sqlite.execute(
    "INSERT INTO dpd_headwords VALUES "
    "(2, 'aññā 2.1', '<p>other</p>', NULL, NULL, NULL, NULL)",
  );
  sqlite.execute(
    "INSERT INTO dpd_headwords VALUES "
    "(3, 'amma 1.1', '<p>mother</p>', NULL, NULL, NULL, NULL)",
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

  Future<void> pumpPanel(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
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

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> typePrefix(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), 'aññ');
    await settle(tester);
    expect(find.textContaining('añña 1.1', findRichText: true), findsOneWidget);
  }

  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets('ArrowDown then Enter accepts the highlighted suggestion', (
    tester,
  ) async {
    await pumpPanel(tester, await makeContainer());
    await typePrefix(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);

    expect(
      fieldText(tester),
      'añña',
      reason: 'Enter accepts the first (highlighted) suggestion, cleaned',
    );
  });

  testWidgets('ArrowUp from the field wraps to the last suggestion', (
    tester,
  ) async {
    await pumpPanel(tester, await makeContainer());
    await typePrefix(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);

    expect(
      fieldText(tester),
      'aññā',
      reason: 'Up with nothing highlighted jumps to the last row',
    );
  });

  testWidgets('Enter with no highlight submits the typed text', (tester) async {
    await pumpPanel(tester, await makeContainer());
    await typePrefix(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);

    expect(
      fieldText(tester),
      'aññ',
      reason: 'no highlight: Enter falls through to the normal submit',
    );
  });

  testWidgets('ArrowDown right after typing selects once rows arrive', (
    tester,
  ) async {
    await pumpPanel(tester, await makeContainer());

    // Type without settling: the 300ms debounce has not fired yet, so the
    // suggestion draft is stale when the arrow arrives (the real-world
    // "type then immediately press Down" flow, no Tab needed).
    await tester.tap(find.byType(TextField));
    await tester.pump();
    tester.testTextInput.enterText('amm');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settle(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);

    expect(
      fieldText(tester),
      'amma',
      reason:
          'the flushed draft loads rows and the queued Down highlights '
          'the first one, straight from the textbox',
    );
  });
}
