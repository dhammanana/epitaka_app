/// Repro: does typing into the library search filter throw?
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/core/database/epitaka_database.dart';
import 'package:epitaka/core/providers/database_provider.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/library/widgets/library_browser.dart';

Future<EpitakaDatabase> _seedDatabase() async {
  final db = EpitakaDatabase(NativeDatabase.memory());

  await db.customStatement(
    'CREATE TABLE books ('
    'id INTEGER PRIMARY KEY AUTOINCREMENT, ref_id INTEGER, vri_id TEXT, '
    'book_id TEXT, category TEXT, nikaya TEXT, sub_nikaya TEXT, '
    'book_name TEXT, description TEXT, mula_ref TEXT, attha_ref TEXT, '
    'tika_ref TEXT, para_id INTEGER, chapter_len INTEGER)',
  );

  for (final book in [
    BooksCompanion.insert(
      bookId: 'dn1',
      category: const Value('Mūla'),
      nikaya: const Value('Dīgha Nikāya'),
      subNikaya: const Value(''),
      bookName: const Value('Dīgha Nikāya 1'),
    ),
    BooksCompanion.insert(
      bookId: 'dn2',
      category: const Value('Mūla'),
      nikaya: const Value('Dīgha Nikāya'),
      subNikaya: const Value(''),
      bookName: const Value('Dīgha Nikāya 2'),
    ),
  ]) {
    await db.into(db.books).insert(book);
  }

  return db;
}

void main() {
  late EpitakaDatabase db;

  setUp(() async {
    db = await _seedDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpBrowser(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        epitakaDbProvider.overrideWith((ref) async => db),
        settingsProvider.overrideWith((ref) {
          final notifier = SettingsNotifier(null);
          notifier.state = const AppSettings();
          return notifier;
        }),
      ],
    );
    addTearDown(container.dispose);

    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizationsDelegate.supportedLocales,
          home: const Scaffold(body: LibraryBrowser()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// On phone the search field starts hidden; pull the book list down to
  /// reveal it, then return the tester in a state where [TextField] exists.
  Future<void> revealSearch(WidgetTester tester) async {
    // Start at the top (pixels == 0) and pull down to trigger the
    // overscroll reveal.
    await tester.drag(find.byType(ListView).first, const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget,
        reason: 'pulling down must reveal the search field');
  }

  testWidgets('search field is hidden until pulled down on phone',
      (tester) async {
    await pumpBrowser(tester);

    expect(find.byType(TextField), findsNothing,
        reason: 'search must be hidden by default on phone');

    await revealSearch(tester);
  });

  testWidgets('typing in the library search filter does not throw',
      (tester) async {
    await pumpBrowser(tester);

    await revealSearch(tester);
    await tester.enterText(find.byType(TextField), 'digha');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'searching the library threw an exception');
  });

  testWidgets('non-matching query shows the empty state, no error',
      (tester) async {
    await pumpBrowser(tester);

    await revealSearch(tester);
    await tester.enterText(find.byType(TextField), 'zzz-no-such-book');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('no'), findsWidgets,
        reason: 'expected the no-results state');
  });
}
