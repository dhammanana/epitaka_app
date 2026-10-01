import 'dart:io';

import 'package:drift/native.dart';
import 'package:epitaka/core/database/epitaka_database.dart';
import 'package:epitaka/core/providers/database_provider.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/reader/providers/reader_tabs_provider.dart';
import 'package:epitaka/features/sutta_jump/services/sutta_code_service.dart';
import 'package:epitaka/features/sutta_jump/widgets/go_to_sutta_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Lines copied from the generated assets/sutta_codes.tsv.
const _fixture = '''
mn1\tM-i\t3\tMN1\tmūlapariyāyasutta\t\t
mn10\tM-i\t280\tMN10\tmahāsatipaṭṭhānasutta\t\t
mn100\tM-ii\t1653\tMN100\tsaṅgāravasutta\t\t
thig2.10\tThī\t175\tTHI28\tsāmātherīgāthā\t\tTHIG2.10
''';

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
    "('M-i', 'Mūlapaṇṇāsapāḷi'), ('Vibh', 'Vibhaṅgapāḷi')",
  );
  // Real rows from epitaka.db.
  await db.customStatement(
    "INSERT INTO headings(book_id, para_id, level, title, sc_id) VALUES "
    "('Vibh', 4, 2, '1. Khandhavibhaṅgo', 'vb1'), "
    "('Vibh', 1520, 2, '10. Bojjhaṅgavibhaṅgo', 'vb10')",
  );
  return db;
}

void main() {
  late EpitakaDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = await _seedDatabase();
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> pumpHost(
    WidgetTester tester, {
    Future<Map<String, SuttaTarget>> Function()? codes,
    double height = 900,
  }) async {
    container = ProviderContainer(
      overrides: [
        epitakaDbProvider.overrideWith((ref) async => db),
        suttaCodesProvider.overrideWith(
          (ref) => (codes ?? () async => parseSuttaCodes(_fixture))(),
        ),
        settingsProvider.overrideWith((ref) => SettingsNotifier(null)),
      ],
    );
    // Wide enough for the desktop layout, where opening a tab needs no router.
    tester.view.physicalSize = Size(1400, height);
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

  Future<void> typeCode(WidgetTester tester, String code) async {
    await tester.enterText(find.byType(TextField), code);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  // The box must close before each test ends: its open-guard is a global
  // that stays set while a dialog is showing.
  Future<void> closeWithEscape(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(GoToSuttaDialog), findsNothing);
  }

  testWidgets('Enter opens the first match in a new tab', (tester) async {
    await pumpHost(tester);
    await typeCode(tester, 'MN 10');
    expect(find.textContaining('MN10 · '), findsOneWidget);
    expect(find.textContaining('MN100 · '), findsOneWidget);

    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    final tab = container.read(readerTabsProvider).activeTab!;
    expect(tab.bookId, 'M-i');
    expect(tab.initialParaId, 280);
    expect(tab.bookName, 'Mūlapaṇṇāsapāḷi');
    expect(find.byType(GoToSuttaDialog), findsNothing);
  });

  testWidgets('Down arrow moves the highlight that Enter opens', (tester) async {
    await pumpHost(tester);
    await typeCode(tester, 'mn10');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    expect(container.read(readerTabsProvider).activeTab!.bookId, 'M-ii');
  });

  testWidgets('a code missing from the map falls back to headings', (tester) async {
    await pumpHost(tester);
    await typeCode(tester, 'vb1');
    expect(find.textContaining('vb1 · '), findsOneWidget);
    expect(find.textContaining('vb10 · '), findsOneWidget);
    await closeWithEscape(tester);
  });

  testWidgets('the list shows the SuttaCentral code beside the DPD code', (tester) async {
    await pumpHost(tester);
    await typeCode(tester, 'thig2.10');
    expect(find.text('THI28 = THIG2.10 · '), findsOneWidget);
    await closeWithEscape(tester);
  });

  testWidgets('typed % and _ are not wildcards in the heading fallback', (tester) async {
    await pumpHost(tester);
    await typeCode(tester, '%');
    expect(find.text('No sutta with code %'), findsOneWidget);
    await typeCode(tester, 'vb_');
    expect(find.text('No sutta with code vb_'), findsOneWidget);
    await closeWithEscape(tester);
  });

  testWidgets('a failed lookup says so instead of "No sutta"', (tester) async {
    await pumpHost(tester, codes: () async => throw StateError('asset missing'));
    await typeCode(tester, 'mn10');
    expect(find.textContaining('Could not look up sutta codes'), findsOneWidget);
    expect(find.textContaining('No sutta with code'), findsNothing);
    await closeWithEscape(tester);
  });

  testWidgets('arrow keys keep the highlighted line on screen', (tester) async {
    final real = parseSuttaCodes(File(suttaCodesAsset).readAsStringSync());
    await pumpHost(tester, codes: () async => real, height: 400);
    await typeCode(tester, 'an1');
    for (var i = 0; i < 19; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    final highlighted = find.byWidgetPredicate(
      (w) => w is ListTile && w.selected == true,
    );
    expect(highlighted.hitTestable(), findsOneWidget);
    await closeWithEscape(tester);
  });

  testWidgets('an unknown code shows the empty state', (tester) async {
    await pumpHost(tester);
    await typeCode(tester, 'zz99');
    expect(find.text('No sutta with code zz99'), findsOneWidget);
    expect(container.read(readerTabsProvider).isEmpty, isTrue);
    await closeWithEscape(tester);
  });

  testWidgets('a second open while the box is up does not stack', (tester) async {
    await pumpHost(tester);
    final context = tester.element(find.byType(GoToSuttaDialog));
    showGoToSuttaDialog(context);
    await tester.pumpAndSettle();
    expect(find.byType(GoToSuttaDialog), findsOneWidget);
    await closeWithEscape(tester);
  });
}
