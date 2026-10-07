/// Regression: the in-book find bar must scroll to the first match as soon as
/// the search finishes, and Enter on an unchanged query must move to the next
/// match. Before the fix the search computed its matches but only the
/// next/previous buttons ever scrolled, so a pasted word stayed off screen.
///
/// Drives the REAL [ReaderScreen] against the REAL router with a seeded
/// in-memory database, so a break anywhere in the chain fails the test.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/core/database/epitaka_database.dart';
import 'package:epitaka/core/providers/database_provider.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/reader/providers/reader_search_notifier.dart';
import 'package:epitaka/features/reader/providers/reader_tabs_provider.dart';
import 'package:epitaka/features/reader/widgets/reader_keyboard_navigation.dart';
import 'package:epitaka/router/app_router.dart';
import 'package:epitaka/shared/utils/app_shortcuts.dart';

const _paraCount = 40;
const _linesPerPara = 8;
const _word = 'zzqword';

/// The two lines that contain [_word].
const _firstMatch = (para: 30, line: 3);
const _secondMatch = (para: 35, line: 2);

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

  await db.into(db.books).insert(
        BooksCompanion.insert(
          bookId: 'dn1',
          bookName: const Value('Dīgha Nikāya 1'),
        ),
      );

  for (var i = 1; i <= _paraCount; i++) {
    for (var l = 1; l <= _linesPerPara; l++) {
      final isMatch = (i == _firstMatch.para && l == _firstMatch.line) ||
          (i == _secondMatch.para && l == _secondMatch.line);
      await db.into(db.sentences).insert(
            SentencesCompanion.insert(
              bookId: 'dn1',
              paraId: i,
              lineId: l,
              pali: Value(
                isMatch
                    ? 'pāli $_word paragraph $i line $l'
                    : 'pāli text paragraph $i line $l',
              ),
            ),
          );
    }
  }

  // A second, small book for the "switching book" test.
  await db.into(db.books).insert(
        BooksCompanion.insert(
          bookId: 'dn2',
          bookName: const Value('Dīgha Nikāya 2'),
        ),
      );
  for (var i = 1; i <= 5; i++) {
    await db.into(db.sentences).insert(
          SentencesCompanion.insert(
            bookId: 'dn2',
            paraId: i,
            lineId: 1,
            pali: Value('pāli other book paragraph $i line 1'),
          ),
        );
  }

  return db;
}

/// Whether paragraph [para] is drawn inside the viewport right now. This is
/// what the user sees. The tab's stored current paragraph is updated on the
/// reader's own schedule and can lag a finished scroll, so it is not used.
///
/// Walks the [RichText] widgets by hand: with a search highlight the
/// paragraph is split into several spans, and `find.textContaining` only
/// reads the first one, so it would never find the paragraph.
bool paragraphOnScreen(WidgetTester tester, int para) {
  final viewport = Offset.zero & tester.view.physicalSize;
  for (final element in find.byType(RichText).evaluate()) {
    final text = (element.widget as RichText).text.toPlainText();
    if (!text.contains('paragraph $para line')) continue;
    final box = element.renderObject! as RenderBox;
    if ((box.localToGlobal(Offset.zero) & box.size).overlaps(viewport)) {
      return true;
    }
  }
  return false;
}

/// Pumps frames until [done] is true, for at most [limit] of test time. A
/// fixed number of pumps is brittle: the book load and the scroll animation
/// take a varying number of frames. Only the fake clock is used, so no real
/// service (app database, preferences) starts up.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() done, {
  Duration limit = const Duration(seconds: 10),
}) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; !done() && t < limit; t += step) {
    await tester.pump(step);
  }
}

/// Lets a jump finish (animation plus the line fine-scroll) in small frames.
/// One big pump is not the same: the scroll list swaps its temporary second
/// list differently when a whole animation fits in a single frame, which a
/// real app never does. Ending a test mid-jump also tears the screen down
/// under it and throws.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late EpitakaDatabase db;

  setUp(() async {
    db = await _seedDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  /// Opens the reader on para 1, opens the find bar and enters [_word].
  Future<ProviderContainer> openFindAndType(
    WidgetTester tester, {
    Size size = const Size(600, 800),
    String word = _word,
    int expectedMatches = 2,
  }) async {
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

    tester.view.physicalSize = size;
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

    container.read(readerTabsProvider.notifier).openTab(
          const ReaderTabInfo(bookId: 'dn1', bookName: 'Dīgha Nikāya 1'),
        );
    // The search runs once per query, so the book must be loaded first.
    await pumpUntil(
      tester,
      () => find
          .textContaining('paragraph 1 line', findRichText: true)
          .evaluate()
          .isNotEmpty,
    );

    container.read(inBookSearchToggleProvider.notifier).toggle();
    await tester.pump();
    await tester.pump();

    // Enter the word the way a paste does: one text change, no Enter.
    await tester.enterText(find.byType(TextField).first, word);
    // Past the 300 ms debounce.
    await pumpUntil(
      tester,
      () => container.read(inBookSearchProvider).matchCount == expectedMatches,
    );
    return container;
  }

  testWidgets('a new search scrolls to the first match without pressing next',
      (tester) async {
    final container = await openFindAndType(tester);

    final search = container.read(inBookSearchProvider);
    expect(search.matchCount, 2, reason: 'the seeded word occurs on 2 lines');
    expect(search.matchIndex, 0);

    await pumpUntil(tester, () => paragraphOnScreen(tester, _firstMatch.para));
    await settle(tester);

    expect(
      paragraphOnScreen(tester, _firstMatch.para),
      isTrue,
      reason: 'the first match (para ${_firstMatch.para}) must be on screen '
          'with no press of the next button',
    );
  });

  testWidgets('Enter on an unchanged query moves to the next match',
      (tester) async {
    final container = await openFindAndType(tester);

    // Let the first jump finish before pressing Enter, as a person would:
    // Enter after the view has stopped.
    await pumpUntil(tester, () => paragraphOnScreen(tester, _firstMatch.para));
    await settle(tester);

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await pumpUntil(tester, () => paragraphOnScreen(tester, _secondMatch.para));
    await settle(tester);

    expect(container.read(inBookSearchProvider).matchIndex, 1);
    expect(
      paragraphOnScreen(tester, _secondMatch.para),
      isTrue,
      reason: 'Enter must scroll to the second match '
          '(para ${_secondMatch.para})',
    );
    // The test host is desktop, where the field keeps focus so a second
    // Enter keeps working.
    expect(
      container.read(inBookSearchProvider.notifier).searchFocusNode.hasFocus,
      isTrue,
    );
  });

  testWidgets('Down and Up in the find field step through the matches',
      (tester) async {
    final container = await openFindAndType(tester);
    await pumpUntil(tester, () => paragraphOnScreen(tester, _firstMatch.para));
    await settle(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await pumpUntil(tester, () => paragraphOnScreen(tester, _secondMatch.para));
    await settle(tester);
    expect(container.read(inBookSearchProvider).matchIndex, 1);
    expect(paragraphOnScreen(tester, _secondMatch.para), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await pumpUntil(tester, () => paragraphOnScreen(tester, _firstMatch.para));
    await settle(tester);
    expect(container.read(inBookSearchProvider).matchIndex, 0);
    expect(paragraphOnScreen(tester, _firstMatch.para), isTrue);
  });

  testWidgets('Down and Up with the page focused step through the matches',
      (tester) async {
    // Wide enough for the desktop shell, which owns the page key handler.
    final container = await openFindAndType(tester, size: const Size(1400, 900));
    await pumpUntil(tester, () => paragraphOnScreen(tester, _firstMatch.para));
    await settle(tester);

    // Move focus from the find field to the page, as clicking the text does.
    container.read(inBookSearchProvider.notifier).searchFocusNode.unfocus();
    final pageFocus = tester
        .widget<Focus>(
          find
              .descendant(
                of: find.byType(ReaderKeyboardNavigation),
                matching: find.byType(Focus),
              )
              .first,
        )
        .focusNode!;
    pageFocus.requestFocus();
    await tester.pump();
    expect(
      container.read(inBookSearchProvider.notifier).searchFocusNode.hasFocus,
      isFalse,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await pumpUntil(tester, () => paragraphOnScreen(tester, _secondMatch.para));
    await settle(tester);
    expect(container.read(inBookSearchProvider).matchIndex, 1);
    expect(paragraphOnScreen(tester, _secondMatch.para), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await pumpUntil(tester, () => paragraphOnScreen(tester, _firstMatch.para));
    await settle(tester);
    expect(container.read(inBookSearchProvider).matchIndex, 0);
    expect(paragraphOnScreen(tester, _firstMatch.para), isTrue);
  });

  testWidgets('arrows with no matches still move the caret in the field',
      (tester) async {
    final container = await openFindAndType(
      tester,
      word: 'qqqq',
      expectedMatches: 0,
    );
    // "No results" is the settled state: the query is stored, no matches.
    await pumpUntil(
      tester,
      () => container.read(inBookSearchProvider).query == 'qqqq',
    );
    final controller =
        container.read(inBookSearchProvider.notifier).searchController;
    expect(controller.selection.baseOffset, 4, reason: 'caret starts at end');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(
      controller.selection.baseOffset,
      0,
      reason: 'with nothing to step to, Up must reach the text field',
    );
  });

  testWidgets('Enter is not undone by a search still waiting to run',
      (tester) async {
    final container = await openFindAndType(tester);
    await pumpUntil(tester, () => paragraphOnScreen(tester, _firstMatch.para));
    await settle(tester);

    // Type one more letter and delete it again, then press Enter inside the
    // 300 ms debounce: the query is back to the searched one, with a search
    // for it still queued.
    final field = find.byType(TextField).first;
    await tester.enterText(field, '${_word}x');
    await tester.enterText(field, _word);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await pumpUntil(tester, () => paragraphOnScreen(tester, _secondMatch.para));
    // Long enough for the queued search to have run, if it was not cancelled.
    await settle(tester);

    expect(container.read(inBookSearchProvider).matchIndex, 1);
    expect(paragraphOnScreen(tester, _secondMatch.para), isTrue);
  });

  testWidgets('switching to another book closes the find bar', (tester) async {
    final container = await openFindAndType(tester);
    await pumpUntil(tester, () => paragraphOnScreen(tester, _firstMatch.para));
    await settle(tester);
    expect(container.read(inBookSearchProvider).showSearchBar, isTrue);

    container.read(readerTabsProvider.notifier).openTab(
          const ReaderTabInfo(bookId: 'dn2', bookName: 'Dīgha Nikāya 2'),
        );
    await settle(tester);

    final search = container.read(inBookSearchProvider);
    expect(search.showSearchBar, isFalse);
    expect(search.matchCount, 0);
    expect(find.byType(TextField), findsNothing);
  });
}
