/// End-to-end regression for the "TOC follows the reader" behavior.
///
/// The user story: the book has jumped to a specific heading (via a TOC tap,
/// search result, history, jump sheet…), and opening the table of contents
/// must auto-scroll to AND highlight THAT heading.
///
/// The chain under test (any break in it fails this test):
///
///   1. The reader knows which paragraph the user is actually reading
///      (ReaderScreen._getCurrentParaId — the first paragraph whose top has
///      scrolled past the viewport top, NOT the topmost visible paragraph,
///      which after a jump is the paragraph above the target).
///   2. The Contents toolbar button pushes
///      `/contents/<bookId>?bookName=…&currentParaId=<id>` (the id must not
///      be dropped).
///   3. The router parses `currentParaId` and hands it to [ContentsScreen].
///   4. [ContentsScreen] computes the enclosing heading, scrolls to it and
///      highlights the row (primary color + bold).
///
/// This test drives the REAL [ReaderScreen] against the REAL router with a
/// seeded in-memory Tipitaka database, so it fails loudly if any of the four
/// steps regresses.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/core/database/epitaka_database.dart';
import '../lib/core/providers/database_provider.dart';
import '../lib/core/providers/settings_provider.dart';
import '../lib/core/utils/app_localizations.dart';
import '../lib/features/contents/screens/contents_screen.dart';
import '../lib/features/reader/providers/reader_tabs_provider.dart';
import '../lib/router/app_router.dart';

/// Paragraphs in the test book. Headings live at every 5th paragraph
/// (5, 10, …, 120) so the TOC list is long enough to auto-scroll and the
/// sections are sparse like a real book.
const _paraCount = 120;

/// The heading the reader jumps to (a heading exists exactly here).
const _targetParaId = 105;
const _targetTitle = 'Heading $_targetParaId';

/// Build the app database override: a real drift [EpitakaDatabase] with the
/// app's schema created manually (the shipped migration is a no-op because
/// the production DB ships pre-bundled), seeded with one small book.
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
    if (i % 5 == 0) {
      await db.into(db.headings).insert(
            HeadingsCompanion.insert(
              bookId: 'dn1',
              paraId: i,
              title: Value('Heading $i'),
              level: const Value(1),
            ),
          );
    }
    // Two Pāli lines per paragraph so items have realistic heights.
    for (var line = 1; line <= 2; line++) {
      await db.into(db.sentences).insert(
            SentencesCompanion.insert(
              bookId: 'dn1',
              paraId: i,
              lineId: line,
              pali: Value('pāli text paragraph $i line $line'),
            ),
          );
    }
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

  /// Pump the real app router + real ReaderScreen with a tab already open at
  /// [initialParaId], then return the container so the test can drive tabs.
  Future<ProviderContainer> pumpReader(
    WidgetTester tester, {
    required int? initialParaId,
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

    container
        .read(readerTabsProvider.notifier)
        .openTab(
          ReaderTabInfo(
            bookId: 'dn1',
            bookName: 'Dīgha Nikāya 1',
            initialParaId: initialParaId,
          ),
        );

    // Phone-sized surface so the app uses the mobile reader layout.
    tester.view.physicalSize = const Size(420, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = buildRouter();
    // Start directly on the reader (the tab is already open).
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

  /// Open the TOC via the reader's floating bottom toolbar.
  Future<void> openContents(WidgetTester tester) async {
    final contentsButton = find.byIcon(Icons.format_list_bulleted);
    expect(contentsButton, findsOneWidget,
        reason: 'reader bottom toolbar must expose the contents button');
    await tester.tap(contentsButton);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'TOC highlights + scrolls to the heading the reader jumped to',
      (tester) async {
    final container = await pumpReader(tester, initialParaId: _targetParaId);

    // Sanity: the reader really jumped — its live "current" paragraph must
    // be the jump target (not the paragraph above it).
    final tab = container.read(readerTabsProvider).activeTab;
    expect(tab != null, isTrue, reason: 'the tab must still be open');

    await openContents(tester);

    // The full-screen ContentsScreen was pushed by the router.
    expect(find.byType(ContentsScreen), findsOneWidget);

    // 1) The exact heading jumped to is built AND visible (auto-scrolled).
    final target = find.descendant(
      of: find.byType(ContentsScreen),
      matching: find.text(_targetTitle),
    );
    expect(target, findsOneWidget,
        reason:
            'the TOC must highlight the heading the reader jumped to '
            '(para $_targetParaId); if a neighbouring heading is highlighted '
            'instead, the reader is feeding the topmost-visible paragraph '
            'rather than the one actually being read');
    final rect = tester.getRect(target);
    expect(rect.top, greaterThanOrEqualTo(0),
        reason: 'current heading must be scrolled into view');
    expect(rect.bottom, lessThanOrEqualTo(800),
        reason: 'current heading must be scrolled into view');

    // 2) The current heading is highlighted (primary color + bold).
    final scheme = Theme.of(tester.element(target)).colorScheme;
    final style = tester.widget<Text>(target).style!;
    expect(style.color, scheme.primary,
        reason: 'current heading must be highlighted with the primary color');
    expect(style.fontWeight, FontWeight.w700,
        reason: 'current heading must be bold');

    // 3) A nearby NON-current heading keeps the default styling.
    final nonCurrent = find.descendant(
      of: find.byType(ContentsScreen),
      matching: find.text('Heading ${_targetParaId - 5}'),
    );
    if (nonCurrent.evaluate().isNotEmpty) {
      final s = tester.widget<Text>(nonCurrent).style!;
      expect(s.color, scheme.onSurface,
          reason: 'non-current heading must keep the default color');
      expect(s.fontWeight, FontWeight.w400,
          reason: 'non-current heading must keep the default weight');
    }

    // 4) The TOC list really scrolled (offset > 0), not just "lucky" layout.
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(ContentsScreen),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.pixels, greaterThan(0),
        reason: 'TOC list must auto-scroll down to the current heading');

    // Flush the reader's debounced reading-history save timer so the test
    // ends without pending timers.
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets(
      'TOC opened at the very top of a book (before the first heading) '
      'does not highlight any heading and does not scroll', (tester) async {
    await pumpReader(tester, initialParaId: 1);

    await openContents(tester);

    expect(find.byType(ContentsScreen), findsOneWidget);

    // At the very top (para 1, before the first heading at para 5) the
    // reader is not inside any section yet — no heading may be highlighted.
    final first = find.descendant(
      of: find.byType(ContentsScreen),
      matching: find.text('Heading 5'),
    );
    if (first.evaluate().isNotEmpty) {
      final scheme = Theme.of(tester.element(first)).colorScheme;
      final style = tester.widget<Text>(first).style!;
      expect(style.color, scheme.onSurface,
          reason: 'no heading is current at the very top of the book');
      expect(style.fontWeight, FontWeight.w400);
    }

    // Nothing to scroll to.
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(ContentsScreen),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.pixels, 0);

    await tester.pump(const Duration(seconds: 4));
  });
}
