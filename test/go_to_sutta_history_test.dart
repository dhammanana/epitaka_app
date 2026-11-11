import 'package:drift/native.dart';
import 'package:epitaka/core/database/epitaka_database.dart';
import 'package:epitaka/core/providers/database_provider.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/reader/providers/reader_tabs_provider.dart';
import 'package:epitaka/features/sutta_jump/providers/sutta_history_provider.dart';
import 'package:epitaka/features/sutta_jump/services/sutta_code_service.dart';
import 'package:epitaka/features/sutta_jump/widgets/go_to_sutta_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// headings.sc_id cells as scripts/import_sutta_codes.py writes them.
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

final _mn100 = encodeSutta(
  const SuttaTarget(
    bookId: 'M-ii',
    paraId: 1653,
    displayCode: 'MN100',
    title: 'Saṅgāravasuttaṃ',
  ),
);
final _mn10 = encodeSutta(
  const SuttaTarget(
    bookId: 'M-i',
    paraId: 280,
    displayCode: 'MN10',
    title: 'Mahāsatipaṭṭhānasuttaṃ',
  ),
);

void main() {
  late EpitakaDatabase db;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'goto_sutta_history': [_mn100, _mn10],
    });
    db = await _seedDatabase();
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> pumpHost(
    WidgetTester tester, {
    Future<EpitakaDatabase> Function()? dbOverride,
    double height = 900,
  }) async {
    container = ProviderContainer(
      overrides: [
        epitakaDbProvider.overrideWith(
          (ref) => (dbOverride ?? () async => db)(),
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
    await tester.testTextInput.receiveAction(TextInputAction.go);
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


  // Lets the saved history load, which waits on the real clock.
  Future<void> loadHistory(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }

  Future<void> finishOpen(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  bool highlighted(WidgetTester tester, String key) {
    final m = tester.widget<Material>(
      find
          .descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(Material),
          )
          .first,
    );
    return m.color ==
        Theme.of(tester.element(find.byKey(ValueKey(key)))).colorScheme.primaryContainer;
  }

  testWidgets('an empty box shows the saved suttas, newest first', (
    tester,
  ) async {
    await pumpHost(tester);
    await loadHistory(tester);
    expect(find.text('MN100'), findsOneWidget);
    expect(find.text('MN10'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('MN100')).dy <
          tester.getTopLeft(find.text('MN10')).dy,
      isTrue,
    );
    await closeWithEscape(tester);
  });

  testWidgets('a tap on a row opens that sutta', (tester) async {
    await pumpHost(tester);
    await loadHistory(tester);
    await tester.tap(find.text('MN10'));
    await finishOpen(tester);
    expect(container.read(readerTabsProvider).activeTab!.bookId, 'M-i');
  });

  testWidgets('Down then Enter opens the first row, Down Down the second', (
    tester,
  ) async {
    await pumpHost(tester);
    await loadHistory(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(highlighted(tester, 'M-i|280'), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await finishOpen(tester);
    final tab = container.read(readerTabsProvider).activeTab!;
    expect(tab.bookId, 'M-i');
    expect(tab.initialParaId, 280);
    expect(find.byType(GoToSuttaDialog), findsNothing);
  });

  testWidgets('Down, Down, Up, Up leaves no highlight and typing works', (
    tester,
  ) async {
    await pumpHost(tester);
    await loadHistory(tester);
    for (final k in [
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowUp,
    ]) {
      await tester.sendKeyEvent(k);
      await tester.pump();
    }
    expect(highlighted(tester, 'M-ii|1653'), isFalse);
    expect(highlighted(tester, 'M-i|280'), isFalse);
    await typeCode(tester, 'mn10');
    expect(find.textContaining('MN10 · '), findsOneWidget);
    await closeWithEscape(tester);
  });

  testWidgets('typing drops the highlight, so the rows come back unlit', (
    tester,
  ) async {
    await pumpHost(tester);
    await loadHistory(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(highlighted(tester, 'M-ii|1653'), isTrue);
    await tester.enterText(find.byType(TextField), 'mn10');
    await tester.pump();
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.text('MN100'), findsOneWidget);
    expect(highlighted(tester, 'M-ii|1653'), isFalse);
    await closeWithEscape(tester);
  });

  testWidgets('Enter on an empty box with no highlight does nothing', (
    tester,
  ) async {
    await pumpHost(tester);
    await loadHistory(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await finishOpen(tester);
    expect(find.byType(GoToSuttaDialog), findsOneWidget);
    expect(container.read(readerTabsProvider).activeTab, isNull);
    await closeWithEscape(tester);
  });

  testWidgets('typing hides the rows and deleting the text shows them', (
    tester,
  ) async {
    await pumpHost(tester);
    await loadHistory(tester);
    await typeCode(tester, 'mn10');
    expect(find.text('MN100'), findsNothing);
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.text('MN100'), findsOneWidget);
    await closeWithEscape(tester);
  });

  testWidgets('opening saves the sutta and a second open moves it up', (
    tester,
  ) async {
    await pumpHost(tester);
    await loadHistory(tester);
    await typeCode(tester, 'an2.15');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await finishOpen(tester);
    final saved = container.read(suttaHistoryProvider);
    expect(saved.length, 3);
    expect(decodeSutta(saved.first)!.bookId, 'A-ii');

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MN10'));
    await finishOpen(tester);
    final again = container.read(suttaHistoryProvider);
    expect(again.length, 3);
    expect(decodeSutta(again.first)!.bookId, 'M-i');
  });

  testWidgets('X removes a row and Clear empties the store', (tester) async {
    await pumpHost(tester);
    await loadHistory(tester);
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pump();
    expect(find.text('MN100'), findsNothing);
    expect(container.read(suttaHistoryProvider).length, 1);
    await tester.tap(find.text('Clear history'));
    await tester.pump();
    expect(container.read(suttaHistoryProvider), isEmpty);
    await closeWithEscape(tester);
  });
}
