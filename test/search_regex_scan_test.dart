/// The regex scan reads the REAL `search_fts` index, built by
/// [AppDatabase.buildSearchIndex] into a file, through its own read-only
/// connection in a background isolate.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:epitaka/core/database/app_database.dart';
import 'package:epitaka/core/database/epitaka_database.dart';
import 'package:epitaka/features/search/services/regex_search.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Lines from the real canon (`search_fts_test.dart` plus two more).
const _sentences = <(String, int, int, String)>[
  ('dn1', 1, 1, 'cakkhuñca paṭicca rūpe ca'),
  ('dn1', 1, 2, 'uppajjati cakkhuviññāṇaṃ'),
  ('dn1', 2, 1, 'sabbe saṅkhārā aniccā'),
  ('dn1', 3, 1, 'katvā na upeti so paṇḍito'),
  ('dn1', 4, 1, 'dhammaṃ khetta'),
  ('dn1', 5, 1, 'sabbe dhammā anattā'),
  ('dn1', 6, 1, 'katvā katvā yathā'),
  ('dn1', 7, 1, 'namo tassa bhagavato arahato sammāsambuddhassa'),
  // Nāmakkp 81: `cakka` only inside a compound, which normal search misses.
  ('dn1', 8, 1, 'Tahimakusalachedaṃ dhammacakkaṃ pavatto,'),
  ('dn1', 9, 1, 'Evaṃ me sutaṃ'),
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

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('regex_scan_');
    dbPath = p.join(dir.path, 'app_data.db');
    // WAL, as the app opens it, so the scan reads beside a live writer.
    appDb = AppDatabase(
      NativeDatabase(
        File(dbPath),
        setup: (db) => db.execute('PRAGMA journal_mode=WAL'),
      ),
    );
    final epiDb = await _fixtureEpitakaDb();
    await appDb.buildSearchIndex(epiDb);
    await epiDb.close();
  });

  tearDown(() async {
    await appDb.close();
    await dir.delete(recursive: true);
  });

  Future<List<(String, int)>> scan(String pattern) async => [
    for (final h in await scanPaliRegex(dbPath, pattern).result)
      (h.bookId, h.paraId),
  ];

  test('finds a pattern inside a word, which normal search misses', () async {
    expect(await scan('cakka'), [('dn1', 8)]);
    final normal = await appDb.searchFts('cakka');
    expect([for (final r in normal) (r.bookId, r.firstParaId)], isEmpty);
  });

  test('diacritics are exact; case is not', () async {
    expect(await scan('rupe'), isEmpty);
    expect(await scan('rūpe'), [('dn1', 1)]);
    expect(await scan('dhammā'), [('dn1', 5)]);
    expect(await scan('[aā]nattā'), [('dn1', 5)]);
    expect(await scan('Evaṃ'), [('dn1', 9)]);
  });

  test('runs over the cleaned search copy: lines joined, '
      'punctuation gone', () async {
    // Paragraph 1's two lines are one row joined by a space.
    expect(await scan(r'ca uppajjati'), [('dn1', 1)]);
    expect(await scan(r'pavatto$'), [('dn1', 8)]);
    // A space is the word edge: `katvāna` (kv 10) is left out.
    expect(await scan(r'^katvā '), [('dn1', 3), ('dn1', 6), ('vbh', 20)]);
  });

  test('hits come in index order', () async {
    expect(await scan('katv'), [
      ('dn1', 3),
      ('dn1', 6),
      ('kv', 10),
      ('vbh', 20),
    ]);
  });

  test('a scan past its time limit stops itself as too slow', () async {
    // The limit is checked before each row: with none left, the first row
    // ends the scan, which closes its database.
    final job = scanPaliRegex(dbPath, 'katv', limit: Duration.zero);
    await expectLater(job.result, throwsA(isA<RegexTooSlow>()));
  });

  test('a scan stuck inside one row is killed 2 s past its limit', () async {
    final clock = Stopwatch()..start();
    final job = scanPaliRegex(
      dbPath,
      r'([^ ]+ ?)+x',
      limit: const Duration(milliseconds: 100),
    );
    await expectLater(job.result, throwsA(isA<RegexTooSlow>()));
    expect(clock.elapsed, lessThan(const Duration(seconds: 5)));
  });

  test('regexError names a pattern that does not compile', () {
    expect(regexError('cakka'), isNull);
    expect(regexError(r'sammā\S*diṭṭh'), isNull);
    expect(regexError('('), isNotNull);
    expect(regexError('[a'), isNotNull);
  });
}
