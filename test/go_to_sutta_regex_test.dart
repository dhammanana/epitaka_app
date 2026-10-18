import 'package:drift/native.dart';
import 'package:epitaka/core/database/epitaka_database.dart';
import 'package:epitaka/core/providers/database_provider.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/reader/providers/reader_tabs_provider.dart';
import 'package:epitaka/features/sutta_jump/services/sutta_code_service.dart';
import 'package:epitaka/features/sutta_jump/widgets/go_to_sutta_dialog.dart';
import 'package:epitaka/shared/widgets/regex_toggle_button.dart';
import 'package:epitaka/shared/widgets/velthuis_help_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/type_keys.dart';

// --- service ---------------------------------------------------------------

SuttaLookupRow _row(String bookId, int paraId, String title, String scId) =>
    SuttaLookupRow(
      bookId: bookId,
      paraId: paraId,
      title: title,
      tokens: [
        for (final part in scId.split(' '))
          if (part.isNotEmpty) parseToken(part),
      ],
    );

/// The heading rows of `sutta_code_service_test.dart`'s fixture; the token
/// cells do not matter here, only titles and book names.
SuttaLookupCache _fixture({int fillers = 0}) => SuttaLookupCache(
  rows: [
    _row('M-i', 280, 'Mahāsatipaṭṭhānasuttaṃ', 'mn10'),
    _row('M-ii', 1653, 'Saṅgāravasuttaṃ', 'mn100'),
    _row('Thī', 175, 'Sāmātherīgāthā', 'thi28 =thig2.10 =thi2.10'),
    _row('A-ii', 35, 'Adhikaraṇavagga', 'an2.11-21'),
    _row('Vibh', 4, '1. Khandhavibhaṅgo', 'vb1'),
    _row('Vibh', 1520, '10. Bojjhaṅgavibhaṅgo', 'vb10'),
    for (var i = 1; i <= fillers; i++)
      _row('Vibh', 2000 + i, 'filler $i', 'zz$i'),
  ],
  bookNames: const {
    'M-i': 'Mūlapaṇṇāsapāḷi',
    'M-ii': 'Majjhimapaṇṇāsapāḷi',
    'Thī': 'Therīgāthāpāḷi',
    'A-ii': 'Dukanipātapāḷi',
    'Vibh': 'Vibhaṅgapāḷi',
  },
);

// --- dialog ----------------------------------------------------------------

Future<EpitakaDatabase> _seedDatabase() async {
  final db = EpitakaDatabase(NativeDatabase.memory());
  await db.customStatement(
    'CREATE TABLE books (id INTEGER PRIMARY KEY, ref_id INTEGER, vri_id TEXT, '
    'book_id TEXT NOT NULL UNIQUE, category TEXT, nikaya TEXT, '
    'sub_nikaya TEXT, book_name TEXT, description TEXT, mula_ref TEXT, '
    'attha_ref TEXT, tika_ref TEXT, para_id INTEGER, chapter_len INTEGER)',
  );
  await db.customStatement(
    'CREATE TABLE headings (book_id TEXT, para_id INT, level INT, '
    'title TEXT, chapter_len INT, parent INT, sc_id TEXT)',
  );
  await db.customStatement(
    "INSERT INTO books(book_id, book_name) VALUES "
    "('M-i', 'Mūlapaṇṇāsapāḷi'), "
    "('M-ii', 'Majjhimapaṇṇāsapāḷi'), "
    "('Thī', 'Therīgāthāpāḷi'), "
    "('A-ii', 'Dukanipātapāḷi'), "
    "('Vibh', 'Vibhaṅgapāḷi')",
  );
  await db.customStatement(
    "INSERT INTO headings(book_id, para_id, level, title, sc_id) VALUES "
    "('M-i', 280, 2, 'Mahāsatipaṭṭhānasuttaṃ', 'mn10'), "
    "('M-ii', 1653, 2, 'Saṅgāravasuttaṃ', 'mn100'), "
    "('Thī', 175, 2, 'Sāmātherīgāthā', 'thi28 =thig2.10 =thi2.10'), "
    "('A-ii', 35, 2, 'Adhikaraṇavagga', 'an2.11-21'), "
    "('Vibh', 4, 2, '1. Khandhavibhaṅgo', 'vb1'), "
    "('Vibh', 1520, 2, '10. Bojjhaṅgavibhaṅgo', 'vb10')",
  );
  return db;
}

void main() {
  final cache = _fixture();

  group('searchSuttaNamesRegex (service)', () {
    test('an anchored pattern matches the lower-cased title exactly', () async {
      final hits = await searchSuttaNamesRegex(cache, '^mahāsatipa');
      expect(hits, hasLength(1));
      expect(hits.first.title, 'Mahāsatipaṭṭhānasuttaṃ');
      expect(hits.first.displayCode, 'MN10');
    });

    test('diacritics are exact: plain letters do not match', () async {
      // `ā` and `ṭṭ` are needed; `mahasatipa` finds nothing.
      final hits = await searchSuttaNamesRegex(cache, '^mahasatipa');
      expect(hits, isEmpty);
    });

    test('case does not matter', () async {
      final hits = await searchSuttaNamesRegex(cache, '^MAHĀSATIPA');
      expect(hits, hasLength(1));
    });

    test(r'$ anchors the end of the title', () async {
      final hits = await searchSuttaNamesRegex(cache, r'suttaṃ$');
      expect(
        hits.map((t) => t.title),
        containsAll(['Mahāsatipaṭṭhānasuttaṃ', 'Saṅgāravasuttaṃ']),
      );
    });

    test('the second pass matches the book name', () async {
      // No title starts with vibhaṅga (they start with digits); the Vibh
      // book name does. Both Vibh rows come back, in row order.
      final hits = await searchSuttaNamesRegex(cache, '^vibhaṅga');
      expect(hits, hasLength(2));
      expect(hits.every((t) => t.bookId == 'Vibh'), isTrue);
    });

    test('codes are not searched', () async {
      // `mn10` is a stored code; as a pattern it matches no title or book
      // name, so nothing is found.
      final hits = await searchSuttaNamesRegex(cache, 'mn10');
      expect(hits, isEmpty);
    });

    test('the 20-result cap holds', () async {
      final big = _fixture(fillers: 25);
      final hits = await searchSuttaNamesRegex(big, '^filler');
      expect(hits, hasLength(20));
    });
  });

  group('rx in the Go to sutta dialog', () {
    late EpitakaDatabase db;
    late ProviderContainer container;

    setUp(() async {
      db = await _seedDatabase();
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    Future<void> pumpHost(WidgetTester tester) async {
      container = ProviderContainer(
        overrides: [
          epitakaDbProvider.overrideWith((ref) async => db),
          settingsProvider.overrideWith((ref) => SettingsNotifier(null)),
        ],
      );
      // Wide enough for the desktop layout, where opening a tab needs no
      // router.
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
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
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showGoToSuttaDialog(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Future<void> typeInto(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
    }

    Future<void> toggleRx(WidgetTester tester) async {
      await tester.tap(find.byType(RegexToggleButton));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
    }

    // The box must close before each test ends: its open-guard is a global
    // that stays set while a dialog is showing.
    Future<void> closeWithEscape(WidgetTester tester) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(GoToSuttaDialog), findsNothing);
    }

    testWidgets('rx sits before the Velthuis help; on, the help hides', (
      tester,
    ) async {
      await pumpHost(tester);
      final field = find.byType(TextField);
      final rx = find.descendant(
        of: field,
        matching: find.byType(RegexToggleButton),
      );
      final help = find.descendant(
        of: field,
        matching: find.byType(VelthuisHelpIcon),
      );
      expect(rx, findsOneWidget);
      expect(help, findsOneWidget);
      // Order: rx first, then the help icon.
      expect(tester.getTopLeft(rx).dx < tester.getTopLeft(help).dx, isTrue);

      await tester.tap(rx);
      await tester.pumpAndSettle();
      expect(help, findsNothing);
      expect(rx, findsOneWidget);
      await closeWithEscape(tester);
    });

    testWidgets('with rx on, `.m` stays `.m`; off, Velthuis converts it', (
      tester,
    ) async {
      await pumpHost(tester);
      await toggleRx(tester);
      await typeKeys(tester, find.byType(TextField), '.m');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '.m',
      );

      // Off: the same keys run through the Velthuis formatter.
      await toggleRx(tester);
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await typeKeys(tester, find.byType(TextField), 'a.m');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'aṃ',
      );
      await closeWithEscape(tester);
    });

    testWidgets('a title pattern lists the sutta, and Enter opens it', (
      tester,
    ) async {
      await pumpHost(tester);
      await toggleRx(tester);
      await typeInto(tester, '^mahāsatipa');
      expect(find.textContaining('MN10 · '), findsOneWidget);

      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      final tab = container.read(readerTabsProvider).activeTab!;
      expect(tab.bookId, 'M-i');
      expect(tab.initialParaId, 280);
      expect(find.byType(GoToSuttaDialog), findsNothing);
    });

    testWidgets('codes are not searched in rx mode', (tester) async {
      await pumpHost(tester);
      await toggleRx(tester);
      // `mn10` is a code: normal mode finds MN10, regex mode (pattern
      // matches no title) must not.
      await typeInto(tester, 'mn10');
      expect(find.textContaining('MN10 · '), findsNothing);
      expect(find.text('No sutta found for mn10'), findsOneWidget);
      await closeWithEscape(tester);
    });

    testWidgets('an invalid pattern shows at the field, not as "No sutta"', (
      tester,
    ) async {
      await pumpHost(tester);
      await toggleRx(tester);
      await typeInto(tester, '(');
      expect(
        find.descendant(
          of: find.byType(TextField),
          matching: find.textContaining('Invalid pattern:'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('No sutta found'), findsNothing);
      await closeWithEscape(tester);
    });

    testWidgets('toggling rx re-runs the box text in the other mode', (
      tester,
    ) async {
      await pumpHost(tester);
      await typeInto(tester, 'mn10');
      expect(find.textContaining('MN10 · '), findsOneWidget);

      await toggleRx(tester);
      expect(find.textContaining('MN10 · '), findsNothing);
      expect(find.text('No sutta found for mn10'), findsOneWidget);
      await closeWithEscape(tester);
    });
  });
}
