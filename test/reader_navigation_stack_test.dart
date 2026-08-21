/// Regression: in-book navigation must NOT push a second reader route.
///
/// The user story: while reading a book, using "Jump to page" (or any other
/// action that only changes the position within the same book, like
/// connected-book jumps or opening a commentary link) used to
/// `context.push('/reader')` after updating the shared reader-tabs state.
/// Because the reader is already the current route, that stacked a SECOND
/// reader screen on the history — so pressing Back once just returned to the
/// same book, and reaching the book list needed two (or more) Back presses.
///
/// This test drives the REAL [ReaderScreen] and router: it jumps to a page
/// from the reader's toolbar and asserts the sheet closes, the book actually
/// moves to the target page, AND exactly one [ReaderScreen] exists (no
/// duplicate pushed route).
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/core/database/epitaka_database.dart';
import '../lib/core/providers/database_provider.dart';
import '../lib/core/providers/settings_provider.dart';
import '../lib/core/utils/app_localizations.dart';
import '../lib/features/reader/providers/reader_tabs_provider.dart';
import '../lib/features/reader/screens/reader_screen.dart';
import '../lib/router/app_router.dart';

/// Paragraphs in the test book. paraId 105 carries `vripage = '105'` so the
/// page-jump lookup (`SELECT para_id … WHERE vripage = ?`) resolves to it.
const _paraCount = 120;
const _jumpPageLabel = '105';
const _jumpTargetParaId = 105;

Future<EpitakaDatabase> _seedDatabase() async {
  final db = EpitakaDatabase(NativeDatabase.memory());

  await db.customStatement(
    'CREATE TABLE books ('
    'id INTEGER PRIMARY KEY AUTOINCREMENT, ref_id INTEGER, vri_id TEXT, '
    'book_id TEXT, category TEXT, nikaya TEXT, sub_nikaya TEXT, '
    'book_name TEXT, description TEXT, mula_ref TEXT, attha_ref TEXT, '
    'tika_ref TEXT, para_id INTEGER, chapter_len INTEGER)',
  );
  await db.customStatement(
    'CREATE TABLE headings ('
    'book_id TEXT NOT NULL, para_id INTEGER NOT NULL, level INTEGER, '
    'title TEXT, chapter_len INTEGER, parent INTEGER, sc_id TEXT, '
    'PRIMARY KEY (book_id, para_id))',
  );
  await db.customStatement(
    'CREATE TABLE sentences ('
    'book_id TEXT NOT NULL, para_id INTEGER NOT NULL, line_id INTEGER NOT NULL, '
    'vripara TEXT, thaipage TEXT, vripage TEXT, ptspage TEXT, mypage TEXT, '
    'pali TEXT, PRIMARY KEY (book_id, para_id, line_id))',
  );

  await db
      .into(db.books)
      .insert(
        BooksCompanion.insert(
          bookId: 'dn1',
          bookName: const Value('Dīgha Nikāya 1'),
        ),
      );

  for (var i = 1; i <= _paraCount; i++) {
    await db
        .into(db.sentences)
        .insert(
          SentencesCompanion.insert(
            bookId: 'dn1',
            paraId: i,
            lineId: 1,
            pali: Value('pāli text paragraph $i'),
            // One page number so "Jump to page" can find this paragraph.
            vripage: Value(i == _jumpTargetParaId ? _jumpPageLabel : null),
          ),
        );
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

  Future<ProviderContainer> pumpReader(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        epitakaDbProvider.overrideWith((ref) async => db),
        settingsProvider.overrideWith((ref) {
          final notifier = SettingsNotifier(null);
          notifier.state = const AppSettings(showTranslation: false);
          return notifier;
        }),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(readerTabsProvider.notifier)
        .openTab(
          const ReaderTabInfo(bookId: 'dn1', bookName: 'Dīgha Nikāya 1'),
        );

    // Wide enough that the jump sheet's two tab labels never overflow
    // (the tab bar Row overflows on very narrow surfaces).
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = buildRouter();
    router.go('/reader');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          supportedLocales: AppLocalizationsDelegate.supportedLocales,
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    'Jump to page closes the sheet and moves in place without stacking '
    'a second reader',
    (tester) async {
      final container = await pumpReader(tester);

      // Exactly one reader on the stack before jumping.
      expect(find.byType(ReaderScreen), findsOneWidget);

      // Open the jump sheet from the reader's floating bottom toolbar.
      await tester.tap(find.byIcon(Icons.open_in_new));
      await tester.pumpAndSettle();

      // Switch to the "Jump to page" tab.
      final jumpToPageTab = find.text(
        AppLocalizations.of(
          tester.element(find.byType(ReaderScreen)),
        ).jumpToPage,
      );
      expect(
        jumpToPageTab,
        findsOneWidget,
        reason: 'the jump sheet must expose the Jump to page tab',
      );
      await tester.tap(jumpToPageTab);
      await tester.pumpAndSettle();

      // Enter the page and submit. Find the page-input field precisely (by its
      // hint) so we never hit some other TextField in the tree.
      final pageInput = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText ==
                AppLocalizations.of(
                  tester.element(find.byType(ReaderScreen)),
                ).pageInputHint,
      );
      expect(pageInput, findsOneWidget);
      await tester.enterText(pageInput, _jumpPageLabel);
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pumpAndSettle();

      // The sheet closed (only the reader is left).
      expect(
        find.text(
          AppLocalizations.of(
            tester.element(find.byType(ReaderScreen)),
          ).jumpToPage,
        ),
        findsNothing,
        reason: 'the jump sheet must close after a successful jump',
      );

      // The book really moved to the target page (the shared tab state is
      // enough — the already-open reader picked it up without a new route).
      final tab = container.read(readerTabsProvider).activeTab;
      expect(tab != null, isTrue);
      expect(
        tab!.currentParaId,
        inInclusiveRange(_jumpTargetParaId - 2, _jumpTargetParaId),
        reason:
            'after jumping to page $_jumpPageLabel the reader must be at '
            'para ~$_jumpTargetParaId (topmost-visible can be one paragraph '
            'above the target)',
      );

      // THE regression: no duplicate reader route was pushed, so Back once
      // returns to the book list instead of showing the same book again.
      expect(
        find.byType(ReaderScreen),
        findsOneWidget,
        reason:
            'jumping to a page must NOT push a second /reader route; if '
            'this finds 2 readers, a context.push("/reader") was re-added',
      );

      // Flush the reader's debounced reading-history save timer.
      await tester.pump(const Duration(seconds: 4));
    },
  );
}
