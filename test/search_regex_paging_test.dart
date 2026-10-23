/// Regex mode past one page: "Show more" and "load all" slice the one scan,
/// list every hit once in text order, and stop at the last (review item 7).
/// The REAL [SearchNotifier] over a real `search_fts` built into a file.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:epitaka/core/database/app_database.dart';
import 'package:epitaka/core/database/epitaka_database.dart';
import 'package:epitaka/core/providers/app_db_provider.dart';
import 'package:epitaka/core/providers/database_provider.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/features/reader/providers/reader_tabs_provider.dart';
import 'package:epitaka/features/search/providers/search_provider.dart';
import 'package:epitaka/features/search/services/regex_search.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// Book b1 has 75 paragraphs with `dhammacakka`, b2 has 40; every other
/// paragraph has none.
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
  for (final b in ['b1', 'b2']) {
    await db.customStatement(
      "INSERT INTO books(book_id, category, nikaya, book_name) "
      "VALUES ('$b', 'Mūla', 'Sutta Piṭaka', '$b')",
    );
  }
  for (final (book, hits) in [('b1', 75), ('b2', 40)]) {
    for (var p = 1; p <= hits * 2; p++) {
      await db.customStatement(
        'INSERT INTO sentences(book_id, para_id, line_id, pali) '
        'VALUES (?, ?, 1, ?)',
        [book, p, p.isEven ? 'anuttaraṃ dhammacakkaṃ $p' : 'sabbe saṅkhārā $p'],
      );
    }
  }
  return db;
}

void main() {
  late Directory dir;
  late String dbPath;
  late AppDatabase appDb;
  late EpitakaDatabase epiDb;
  late int scans;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('regex_paging_');
    dbPath = p.join(dir.path, 'app_data.db');
    appDb = AppDatabase(NativeDatabase(File(dbPath)));
    epiDb = await _fixtureEpitakaDb();
    await appDb.buildSearchIndex(epiDb);
    scans = 0;
  });

  tearDown(() async {
    await appDb.close();
    await epiDb.close();
    await dir.delete(recursive: true);
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        appDbProvider.overrideWith((ref) async => appDb),
        epitakaDbProvider.overrideWith((ref) async => epiDb),
        translationDbProvider('en').overrideWith((ref) async => null),
        settingsProvider.overrideWith((ref) => SettingsNotifier(null)),
        readerTabsProvider.overrideWith(
          (ref) => ReaderTabsNotifier(const ReaderTabsState(tabs: [])),
        ),
        regexScanProvider.overrideWithValue((pattern) async {
          scans++;
          return scanPaliRegex(dbPath, pattern);
        }),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  BookResultSummary book(ProviderContainer c, String id) =>
      (c.read(searchProvider) as SearchResults).bookSummaries.firstWhere(
        (s) => s.book.bookId == id,
      );

  List<int> ids(BookResultSummary s) => [
    for (final page in s.loadedPages)
      for (final item in page) item.paraId,
  ];

  test('"Show more" pages through every hit once, in text order', () async {
    final c = makeContainer();
    final notifier = c.read(searchProvider.notifier);
    await notifier.search(query: 'cakka', regex: true);
    expect(book(c, 'b1').totalCount, 75);
    expect(book(c, 'b1').isExpanded, isFalse);

    await notifier.expandBook(0);
    var taps = 0;
    while (!book(c, 'b1').fullyLoaded && taps < 10) {
      await notifier.loadMoreForBook(0);
      taps++;
    }
    final b1 = book(c, 'b1');
    expect([for (final page in b1.loadedPages) page.length], [30, 30, 15]);
    expect(ids(b1), [for (var p = 2; p <= 150; p += 2) p]);
    expect(b1.fullyLoaded, isTrue);
    expect(scans, 1);
  });

  test('"load all" brings every hit of the book in one go', () async {
    final c = makeContainer();
    final notifier = c.read(searchProvider.notifier);
    await notifier.search(query: 'cakka', regex: true);
    await notifier.loadAllForBook(1);
    final b2 = book(c, 'b2');
    expect([for (final page in b2.loadedPages) page.length], [30, 10]);
    expect(ids(b2), [for (var p = 2; p <= 80; p += 2) p]);
    expect(b2.fullyLoaded, isTrue);
    expect(scans, 1);
  });
}
