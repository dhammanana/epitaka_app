/// A main search with a book open loads every hit of that book. The old code
/// did it 30 hits at a time, re-running both FTS queries and publishing new
/// state per page (117 pages for "dhamma" in Paṭṭh-v, about 5 minutes on a
/// Pixel 8 Pro). The order of the hits and the page sizes must stay as the
/// page loop produced them, less the paragraphs it listed a second time;
/// only the number of queries and publishes may change.
///
/// Runs the REAL [SearchNotifier] against real FTS indexes built from
/// in-memory fixtures (the `search_fts_test.dart` set-up).
library;

import 'package:drift/native.dart';
import 'package:epitaka/core/database/app_database.dart';
import 'package:epitaka/core/database/epitaka_database.dart';
import 'package:epitaka/core/database/translation_database.dart';
import 'package:epitaka/core/providers/app_db_provider.dart';
import 'package:epitaka/core/providers/database_provider.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/features/reader/providers/reader_tabs_provider.dart';
import 'package:epitaka/features/search/providers/search_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Paragraphs 1–100 of the open book hit "dhamma" in the Pāli, with uneven
/// counts and lengths so the ranks vary and some tie. Paragraphs 101–125 hit
/// only in the English, and 1–15 hit in both, so translation rows fill the
/// first two windows and repeat some Pāli paragraphs.
const _openBook = 'b1';
const _paliHits = 100;
const _transOnly = 25;
const _transBoth = 15;

String _paliFor(int p) {
  if (p > _paliHits) return 'sīlaṃ samādhi paññā $p';
  final hits = List.filled(p % 3 + 1, 'dhammaṃ').join(' ');
  final filler = List.filled(p % 7, 'ca').join(' ');
  return '$hits $filler bhikkhave';
}

Future<EpitakaDatabase> _fixtureEpitakaDb() async {
  final db = EpitakaDatabase(NativeDatabase.memory());
  await db.customStatement('''
    CREATE TABLE books (
      id INTEGER PRIMARY KEY AUTOINCREMENT, ref_id INTEGER, vri_id TEXT,
      book_id TEXT NOT NULL, category TEXT, nikaya TEXT, sub_nikaya TEXT,
      book_name TEXT, description TEXT, mula_ref TEXT, attha_ref TEXT,
      tika_ref TEXT, para_id INTEGER, chapter_len INTEGER
    )
  ''');
  await db.customStatement('''
    CREATE TABLE headings (
      book_id TEXT NOT NULL, para_id INTEGER NOT NULL, level INTEGER,
      title TEXT, chapter_len INTEGER, parent INTEGER, sc_id TEXT,
      PRIMARY KEY (book_id, para_id)
    )
  ''');
  await db.customStatement('''
    CREATE TABLE sentences (
      book_id TEXT NOT NULL, para_id INTEGER NOT NULL, line_id INTEGER NOT NULL,
      vripara TEXT, pali TEXT, PRIMARY KEY (book_id, para_id, line_id)
    )
  ''');
  for (final b in [_openBook, 'b2']) {
    await db.customStatement(
      "INSERT INTO books(book_id, category, nikaya, book_name) "
      "VALUES ('$b', 'Mūla', 'Sutta Piṭaka', '$b')",
    );
  }
  for (var p = 1; p <= _paliHits + _transOnly; p++) {
    await db.customStatement(
      'INSERT INTO sentences(book_id, para_id, line_id, pali) VALUES (?, ?, ?, ?)',
      [_openBook, p, 1, _paliFor(p)],
    );
    if (p.isEven) {
      await db.customStatement(
        'INSERT INTO sentences(book_id, para_id, line_id, pali) '
        'VALUES (?, ?, ?, ?)',
        [_openBook, p, 2, 'evaṃ me sutaṃ'],
      );
    }
  }
  for (var p = 1; p <= 3; p++) {
    await db.customStatement(
      'INSERT INTO sentences(book_id, para_id, line_id, pali) VALUES (?, ?, ?, ?)',
      ['b2', p, 1, 'dhammo dhammaṃ'],
    );
  }
  return db;
}

Future<TranslationDatabase> _fixtureTranslationDb() async {
  final db = TranslationDatabase(NativeDatabase.memory());
  final paras = [
    for (var p = 1; p <= _transBoth; p++) p,
    for (var p = _paliHits + 1; p <= _paliHits + _transOnly; p++) p,
  ];
  for (final p in paras) {
    final hits = List.filled(p % 4 + 1, 'dhamma').join(' ');
    await db.customStatement(
      'INSERT INTO sentences(book_id, para_id, line_id, translation) '
      'VALUES (?, ?, ?, ?)',
      [_openBook, p, 1, 'the $hits of the monks'],
    );
  }
  return db;
}

void main() {
  late EpitakaDatabase epiDb;
  late TranslationDatabase transDb;
  late AppDatabase appDb;

  setUp(() async {
    epiDb = await _fixtureEpitakaDb();
    transDb = await _fixtureTranslationDb();
    appDb = AppDatabase(NativeDatabase.memory());
    await appDb.buildSearchIndex(epiDb);
    await appDb.buildTranslationSearchIndex('en', transDb);
  });

  tearDown(() async {
    await appDb.close();
    await transDb.close();
    await epiDb.close();
  });

  ProviderContainer makeContainer({bool bookOpen = true}) {
    final container = ProviderContainer(
      overrides: [
        appDbProvider.overrideWith((ref) async => appDb),
        epitakaDbProvider.overrideWith((ref) async => epiDb),
        translationDbProvider('en').overrideWith((ref) async => transDb),
        settingsProvider.overrideWith((ref) {
          final n = SettingsNotifier(null);
          n.state = const AppSettings(
            showTranslation: true,
            enabledTranslations: ['en'],
          );
          return n;
        }),
        readerTabsProvider.overrideWith(
          (ref) => ReaderTabsNotifier(
            bookOpen
                ? const ReaderTabsState(
                    tabs: [
                      ReaderTabInfo(bookId: _openBook, bookName: _openBook),
                    ],
                  )
                : const ReaderTabsState(tabs: []),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('the open book gets every hit in page-loop order, in two publishes', () async {
    final container = makeContainer();

    // Count the publishes that change the open book's loaded hits.
    var publishes = 0;
    List<List<SearchResultItem>>? lastPages;
    container.listen<SearchState>(searchProvider, (_, next) {
      if (next is! SearchResults) return;
      final pages = next.bookSummaries
          .firstWhere((s) => s.book.bookId == _openBook)
          .loadedPages;
      if (!identical(pages, lastPages) && pages.isNotEmpty) publishes++;
      lastPages = pages;
    });

    await container.read(searchProvider.notifier).search(query: 'dhamma');

    final results = container.read(searchProvider) as SearchResults;
    final summary = results.bookSummaries.first;
    expect(summary.book.bookId, _openBook);
    // Paragraphs 1–15 match in the Pāli and the English and count once.
    expect(summary.totalCount, _paliHits + _transOnly);

    expect(
      [
        for (final page in summary.loadedPages)
          [for (final item in page) item.paraId],
      ],
      _expectedPages(),
    );
    expect(summary.fullyLoaded, isTrue);
    expect(publishes, lessThanOrEqualTo(2));
  });

  test('"Show more" lists each paragraph once and stops at the last', () async {
    // No book open, so nothing loads until the book is expanded.
    final container = makeContainer(bookOpen: false);
    final notifier = container.read(searchProvider.notifier);
    await notifier.search(query: 'dhamma');
    BookResultSummary book() =>
        (container.read(searchProvider) as SearchResults).bookSummaries
            .firstWhere((s) => s.book.bookId == _openBook);
    expect(book().isExpanded, isFalse);

    final index = (container.read(searchProvider) as SearchResults)
        .bookSummaries
        .indexWhere((s) => s.book.bookId == _openBook);
    await notifier.expandBook(index);
    var taps = 0;
    while (!book().fullyLoaded && taps < 20) {
      await notifier.loadMoreForBook(index);
      taps++;
    }

    final ids = [
      for (final page in book().loadedPages)
        for (final item in page) item.paraId,
    ];
    expect(ids.toSet().length, ids.length, reason: 'a paragraph repeats');
    expect(ids.toSet(), {for (var p = 1; p <= 125; p++) p});
    expect(book().totalCount, ids.length);
    expect(book().fullyLoaded, isTrue);
  });

  test('a book collapsed while the rest of its hits load stays collapsed', () async {
    final container = makeContainer();
    final notifier = container.read(searchProvider.notifier);

    // Collapse the open book as soon as its first window shows. The rest of
    // its hits are still being fetched at that moment.
    var collapsed = false;
    container.listen<SearchState>(searchProvider, (_, next) {
      if (collapsed || next is! SearchResults) return;
      final first = next.bookSummaries.first;
      if (first.loadedPages.isEmpty) return;
      collapsed = true;
      Future.microtask(() => notifier.collapseBook(0));
    });

    await notifier.search(query: 'dhamma');

    expect(collapsed, isTrue);
    final summary = (container.read(searchProvider) as SearchResults)
        .bookSummaries
        .first;
    expect(summary.isExpanded, isFalse, reason: 'the late commit re-expanded it');
    expect(summary.loadedPages, isEmpty, reason: 'page 1 would be missing');
  });
}

// Written out from a run of the page loop before the change. That run listed
// a paragraph twice when it matched in the Pāli on one page and in the
// English on another; each now shows once, at its first place.
const _oldPageSizes = <int>[54, 40, 30, 10];
const _oldParaIds = <int>[
  35, 77, 29, 71, 7, 49, 91, 23, 65, 14, 17, 56, 59, 98, 1, 43, 85, 8, 11, 50,
  53, 92, 95, 37, 79, 2, 5, 44, 47, 86, 3, 15, 103, 107, 111, 115, 119, 123,
  6, 10, 102, 106, 110, 114, 118, 122, 9, 13, 101, 105, 109, 113, 117, 121,
  89, 38, 41, 80, 83, 28, 31, 70, 73, 21, 63, 32, 74, 22, 25, 64, 67, 26, 68,
  20, 62, 16, 19, 58, 61, 100, 15, 57, 99, 10, 125, 4, 8, 12, 104, 108, 112,
  116, 120, 124, 13, 52, 55, 94, 97, 4, 46, 88, 9, 51, 93, 40, 82, 34, 76, 3,
  42, 45, 84, 87, 36, 39, 78, 81, 30, 33, 72, 75, 24, 27, 66, 69, 18, 60, 12,
  54, 96, 6, 48, 90,
];

List<List<int>> _expectedPages() {
  final shown = <int>{};
  final pages = <List<int>>[];
  var start = 0;
  for (final size in _oldPageSizes) {
    pages.add([
      for (final id in _oldParaIds.sublist(start, start + size))
        if (shown.add(id)) id,
    ]);
    start += size;
  }
  return pages;
}
