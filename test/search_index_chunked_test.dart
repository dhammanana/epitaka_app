/// The search index build reads the canon in pages of paragraphs, so the
/// whole text (101.9 M characters of Pāli, 152 M of English) is never held at
/// once (1,303 MB peak on a Pixel 8 Pro). A build in small pages must give the
/// same index rows, word tables and search results as a build in one page.
///
/// The fixture puts a multi-line paragraph across a page edge, paragraphs 9
/// and 10 (numeric order, not text order), three books, and a paragraph that
/// cleans to nothing as the last row of a page.
library;

import 'package:drift/native.dart';
import 'package:epitaka/core/database/app_database.dart';
import 'package:epitaka/core/database/epitaka_database.dart';
import 'package:epitaka/core/database/translation_database.dart';
import 'package:flutter_test/flutter_test.dart';

/// (book, para, line, pali). With pages of 3 paragraphs: page 1 is a1/1,
/// a1/2, a1/9 (a1/9 cleans to nothing); page 2 starts at a1/10.
const _pali = <(String, int, int, String)>[
  ('a1', 1, 1, 'evaṃ me sutaṃ'),
  ('a1', 1, 2, 'ekaṃ samayaṃ bhagavā'),
  ('a1', 2, 1, 'dhammaṃ desessāmi'),
  ('a1', 9, 1, '[ka.517]'),
  ('a1', 10, 1, 'dhammo ca vinayo ca'),
  ('a1', 10, 2, 'bhikkhave dhamma'),
  ('b2', 1, 1, 'sabbe saṅkhārā aniccā'),
  ('b2', 3, 1, 'dhamma desanā'),
  ('c3', 1, 1, 'atha kho bhagavā'),
  ('c3', 1, 2, 'bhikkhū āmantesi'),
  ('c3', 2, 1, 'dhammo'),
];

/// (book, para, line, English).
const _english = <(String, int, int, String)>[
  ('a1', 1, 1, 'Thus have I heard.'),
  ('a1', 2, 1, 'I will teach the dhamma.'),
  ('a1', 10, 1, 'The dhamma and the discipline'),
  ('a1', 10, 2, '[monks] the dhamma'),
  ('b2', 3, 1, 'a teaching of the dhamma'),
  ('c3', 1, 1, 'Then the Blessed One'),
  ('c3', 2, 1, 'the dhamma'),
];

Future<EpitakaDatabase> _canon() async {
  final db = EpitakaDatabase(NativeDatabase.memory());
  await db.customStatement('''
    CREATE TABLE sentences (
      book_id TEXT NOT NULL, para_id INTEGER NOT NULL, line_id INTEGER NOT NULL,
      vripara TEXT, pali TEXT, PRIMARY KEY (book_id, para_id, line_id)
    )
  ''');
  for (final (book, para, line, pali) in _pali) {
    await db.customStatement(
      'INSERT INTO sentences(book_id, para_id, line_id, pali) VALUES (?, ?, ?, ?)',
      [book, para, line, pali],
    );
  }
  return db;
}

Future<TranslationDatabase> _englishDb() async {
  final db = TranslationDatabase(NativeDatabase.memory());
  for (final (book, para, line, text) in _english) {
    await db.customStatement(
      'INSERT INTO sentences(book_id, para_id, line_id, translation) '
      'VALUES (?, ?, ?, ?)',
      [book, para, line, text],
    );
  }
  return db;
}

/// Every row of the tables the build writes, in rowid/id order.
Future<List<String>> _dump(AppDatabase db) async {
  final out = <String>[];
  for (final sql in [
    'SELECT * FROM search_fts ORDER BY rowid',
    'SELECT * FROM search_words ORDER BY id',
    'SELECT * FROM search_fts_en ORDER BY rowid',
    'SELECT * FROM search_words_en ORDER BY id',
  ]) {
    final rows = await db.customSelect(sql).get();
    out.add('$sql: ${rows.length}');
    out.addAll(rows.map((r) => r.data.toString()));
  }
  return out;
}

Future<AppDatabase> _build(int chunk) async {
  final saved = AppDatabase.indexReadChunk;
  AppDatabase.indexReadChunk = chunk;
  addTearDown(() => AppDatabase.indexReadChunk = saved);

  final canon = await _canon();
  final english = await _englishDb();
  final app = AppDatabase(NativeDatabase.memory());
  addTearDown(() async {
    await app.close();
    await english.close();
    await canon.close();
  });
  AppDatabase.indexLargestRead = 0;
  final pali = await app.buildSearchIndex(canon);
  expect(pali.pages, 7, reason: '8 paragraphs; a1/9 cleans to nothing');
  expect(AppDatabase.indexLargestRead, lessThanOrEqualTo(chunk));
  AppDatabase.indexLargestRead = 0;
  expect(await app.buildTranslationSearchIndex('en', english), 6);
  expect(AppDatabase.indexLargestRead, lessThanOrEqualTo(chunk));
  return app;
}

void main() {
  test('a build in pages of 3 equals a build in one page', () async {
    final paged = await _build(3);
    final whole = await _build(1000000);

    final pagedRows = await _dump(paged);
    expect(pagedRows, await _dump(whole));
    expect(pagedRows.first, 'SELECT * FROM search_fts ORDER BY rowid: 7');

    expect(
      await paged.countPaliResultsByBook('dhamma'),
      await whole.countPaliResultsByBook('dhamma'),
    );
    expect(await paged.countPaliResultsByBook('dhamma'), isNotEmpty);
  });
}
