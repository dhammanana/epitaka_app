/// Main search in regex mode: the REAL [SearchNotifier] over a real
/// `search_fts` index built into a file, with the real scan
/// ([scanPaliRegex]) behind a counting [regexScanProvider].
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:epitaka/core/database/app_database.dart';
import 'package:epitaka/core/database/epitaka_database.dart';
import 'package:epitaka/core/providers/app_db_provider.dart';
import 'package:epitaka/core/providers/database_provider.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/features/search/providers/search_history_provider.dart';
import 'package:epitaka/features/search/providers/search_provider.dart';
import 'package:epitaka/features/search/services/regex_search.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// Lines from the real canon, as in `search_regex_scan_test.dart`.
const _sentences = <(String, int, int, String)>[
  ('dn1', 1, 1, 'cakkhuñca paṭicca rūpe ca'),
  ('dn1', 1, 2, 'uppajjati cakkhuviññāṇaṃ'),
  ('dn1', 2, 1, 'sabbe saṅkhārā aniccā'),
  ('dn1', 3, 1, 'katvā na upeti so paṇḍito'),
  ('dn1', 4, 1, 'dhammaṃ khetta'),
  ('dn1', 5, 1, 'sabbe dhammā anattā'),
  ('dn1', 6, 1, 'katvā katvā yathā'),
  ('dn1', 8, 1, 'Tahimakusalachedaṃ dhammacakkaṃ pavatto,'),
  ('kv', 10, 1, 'katvāna katvā dhammaṃ'),
  ('vbh', 20, 1, 'katvā rūpaṃ vedanā saññā'),
  // DN 1, 7 words: `([^ ]+ ?)+x` backtracks on it for about 30 s.
  ('vbh', 21, 1, 'ekaṃ samayaṃ bhagavā antarā ca rājagahaṃ antarā'),
];

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
  for (final (bookId, category, nikaya, name) in [
    ('dn1', 'Mūla', 'Sutta Piṭaka', 'Dīgha Nikāya'),
    ('kv', 'Aṭṭhakathā', 'Vinaya Piṭaka', 'Kaṅkhāvitaraṇī'),
    ('vbh', 'Mūla', 'Abhidhamma Piṭaka', 'Vibhaṅga'),
  ]) {
    await db.customStatement(
      'INSERT INTO books(book_id, category, nikaya, book_name) '
      'VALUES (?, ?, ?, ?)',
      [bookId, category, nikaya, name],
    );
    await db.customStatement(
      'INSERT INTO headings(book_id, para_id, level, title) VALUES (?, 1, 1, ?)',
      [bookId, name],
    );
  }
  for (final (bookId, paraId, lineId, pali) in _sentences) {
    await db.customStatement(
      'INSERT INTO sentences(book_id, para_id, line_id, pali) '
      'VALUES (?, ?, ?, ?)',
      [bookId, paraId, lineId, pali],
    );
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
    dir = await Directory.systemTemp.createTemp('regex_search_');
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

  ProviderContainer makeContainer({Duration scanDelay = Duration.zero}) {
    final container = ProviderContainer(
      overrides: [
        appDbProvider.overrideWith((ref) async => appDb),
        epitakaDbProvider.overrideWith((ref) async => epiDb),
        translationDbProvider('en').overrideWith((ref) async => null),
        settingsProvider.overrideWith((ref) => SettingsNotifier(null)),
        regexScanProvider.overrideWithValue((pattern) async {
          scans++;
          // Stands in for the database path lookup before the scan starts.
          await Future<void>.delayed(scanDelay);
          // A short limit, so a runaway pattern ends within the test.
          return scanPaliRegex(
            dbPath,
            pattern,
            limit: const Duration(milliseconds: 200),
          );
        }),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  SearchResults results(ProviderContainer c) =>
      c.read(searchProvider) as SearchResults;

  List<(String, int)> shown(SearchResults r) => [
    for (final b in r.bookSummaries)
      for (final page in b.loadedPages)
        for (final item in page) (item.bookId, item.paraId),
  ];

  test('one scan serves the counts and every page; paragraphs in text '
      'order', () async {
    final c = makeContainer();
    await c.read(searchProvider.notifier).search(query: 'katv', regex: true);

    final r = results(c);
    expect(r.regex, isTrue);
    expect(r.totalResults, 4);
    expect(
      {for (final b in r.bookSummaries) b.book.bookId: b.totalCount},
      {'dn1': 2, 'kv': 1, 'vbh': 1},
    );
    // 4 hits: every book opens and loads.
    expect(shown(r), [('dn1', 3), ('dn1', 6), ('kv', 10), ('vbh', 20)]);
    expect(scans, 1);
  });

  test('finds a word inside a compound, which normal search misses', () async {
    final c = makeContainer();
    await c.read(searchProvider.notifier).search(query: 'cakka', regex: true);
    expect(shown(results(c)), [('dn1', 8)]);
    expect(
      results(c).bookSummaries.single.loadedPages.single.single.highlightTerms,
      ['cakka'],
    );

    await c.read(searchProvider.notifier).search(query: 'cakka');
    expect(results(c).totalResults, 0);
  });

  test('a line is shown when the pattern matches it; when only the joined '
      'paragraph matches, every line is shown', () async {
    final c = makeContainer();
    final notifier = c.read(searchProvider.notifier);

    await notifier.search(query: 'cakkhuviññ', regex: true);
    var item = results(c).bookSummaries.single.loadedPages.single.single;
    expect([for (final l in item.lines) l.isMatch], [false, true]);
    expect(item.highlightTerms, ['cakkhuviññ']);

    // `ca` ends line 1 and `uppajjati` starts line 2.
    await notifier.search(query: 'ca uppajjati', regex: true);
    item = results(c).bookSummaries.single.loadedPages.single.single;
    expect([for (final l in item.lines) l.isMatch], [true, true]);
    expect(item.highlightTerms, ['ca uppajjati']);
  });

  test('an invalid pattern is an error and scans nothing', () async {
    final c = makeContainer();
    await c.read(searchProvider.notifier).search(query: '(', regex: true);
    final state = c.read(searchProvider);
    expect(state, isA<SearchError>());
    expect((state as SearchError).patternError, isNotNull);
    expect(scans, 0);
  });

  test('a regex search stays out of the search history', () async {
    final c = makeContainer();
    await c.read(searchProvider.notifier).search(query: 'katv', regex: true);
    expect(c.read(searchHistoryProvider), isNot(contains('katv')));
    await c.read(searchProvider.notifier).search(query: 'katva');
    expect(c.read(searchHistoryProvider), contains('katva'));
  });

  test('a filter re-runs the search in regex mode', () async {
    final c = makeContainer();
    final notifier = c.read(searchProvider.notifier);
    await notifier.search(query: 'katv', regex: true);
    await notifier.toggleCategory('aṭṭha');

    final r = results(c);
    expect(r.regex, isTrue);
    expect({for (final b in r.bookSummaries) b.book.bookId}, {'dn1', 'vbh'});
  });

  test('headings match the pattern with exact diacritics', () async {
    final c = makeContainer();
    final notifier = c.read(searchProvider.notifier);
    await notifier.search(query: 'nikāya', regex: true);
    expect([for (final h in results(c).headings) h.bookId], ['dn1']);
    await notifier.search(query: 'nikaya', regex: true);
    expect(results(c).headings, isEmpty);
  });

  test('a runaway pattern ends as "Pattern too slow"', () async {
    final c = makeContainer();
    await c
        .read(searchProvider.notifier)
        .search(query: r'([^ ]+ ?)+x', regex: true);
    final state = c.read(searchProvider);
    expect(state, isA<SearchError>());
    expect((state as SearchError).patternTooSlow, isTrue);
  });

  test('Clear during a runaway scan leaves the box idle', () async {
    final c = makeContainer();
    final notifier = c.read(searchProvider.notifier);
    final running = notifier.search(query: r'([^ ]+ ?)+x', regex: true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    notifier.clear();
    expect(c.read(searchProvider), isA<SearchIdle>());
    await running;
    expect(c.read(searchProvider), isA<SearchIdle>(), reason: 'no late error');
  });

  test('a filter change reuses the scan', () async {
    final c = makeContainer();
    final notifier = c.read(searchProvider.notifier);
    await notifier.search(query: 'katv', regex: true);
    await notifier.toggleCategory('aṭṭha');
    await notifier.toggleCategory('aṭṭha');
    expect(scans, 1);
    expect(results(c).totalResults, 4);
  });

  test('Clear while the scan is still starting is no uncaught error', () async {
    // The scan is cancelled before anyone awaits it; the test fails on an
    // uncaught async error, as the app reports one as a fatal crash.
    final c = makeContainer(scanDelay: const Duration(milliseconds: 300));
    final notifier = c.read(searchProvider.notifier);
    final running = notifier.search(query: 'katv', regex: true);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    notifier.clear();
    await running;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(c.read(searchProvider), isA<SearchIdle>());
  });
}
