/// Regression tests for the @ mention heading/sutta search.
///
/// The old implementation ran a SQL `LIKE` pre-filter on the first two
/// query letters and then took `LIMIT 200` rows ordered by book id BEFORE
/// fuzzy ranking.  Because the first book in the fixture (`dn1`) has more
/// than 200 matching headings, every candidate came from `dn1` and perfect
/// matches in later books (e.g. the Dhammapada) were silently dropped.
///
/// The new implementation is FZF-style: the whole index is ranked in
/// memory, so later-book and fuzzy matches surface regardless of book
/// ordering.  These tests lock that behaviour in.
library;

import 'package:drift/native.dart';
import 'package:epitaka/core/database/app_database.dart';
import 'package:epitaka/core/database/epitaka_database.dart';
import 'package:epitaka/core/providers/app_db_provider.dart';
import 'package:epitaka/core/providers/database_provider.dart';
import 'package:epitaka/features/ai_qa/models/heading_attachment.dart';
import 'package:epitaka/features/ai_qa/services/mention_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory Tipiṭaka fixture.
///
/// Book ordering (by `id`) is deliberately canonical-but-later-ordered:
/// `dn1` first with **300+ headings** (enough to exhaust the old `LIMIT
/// 200` candidate set), then `dhp` (Dhammapada) and `an1` (Aṅguttara) —
/// the books the old code could never surface.
Future<EpitakaDatabase> _fixtureEpitakaDb() async {
  final db = EpitakaDatabase(NativeDatabase.memory());
  await db.customStatement('''
    CREATE TABLE books (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      book_id TEXT NOT NULL,
      book_name TEXT,
      mula_ref TEXT,
      attha_ref TEXT,
      tika_ref TEXT,
      chapter_len INTEGER
    )
  ''');
  await db.customStatement('''
    CREATE TABLE headings (
      book_id TEXT NOT NULL,
      para_id INTEGER NOT NULL,
      level INTEGER,
      title TEXT,
      parent INTEGER,
      PRIMARY KEY (book_id, para_id)
    )
  ''');

  await db.customStatement(
    "INSERT INTO books(id, book_id, book_name) VALUES (1, 'dn1', 'Dīgha Nikāya')",
  );
  await db.customStatement(
    "INSERT INTO books(id, book_id, book_name) VALUES (2, 'dhp', 'Dhammapadapāḷi')",
  );
  await db.customStatement(
    "INSERT INTO books(id, book_id, book_name) VALUES (3, 'an1', 'Aṅguttara Nikāya')",
  );

  // dn1: 300 generic headings (para 1..300) — enough to fill the old
  // LIMIT-200 candidate set on their own — plus a diacritic title.
  for (int p = 1; p <= 300; p++) {
    await db.customStatement(
      'INSERT INTO headings(book_id, para_id, level, title, parent) '
      'VALUES (?, ?, 1, ?, 0)',
      ['dn1', p, 'Dīgha Sutta $p'],
    );
  }
  await db.customStatement(
    'INSERT INTO headings(book_id, para_id, level, title, parent) '
    "VALUES ('dn1', 301, 4, 'Cankīsuttam', 0)",
  );

  // dhp + an1 headings live in later-ordered books.
  await db.customStatement(
    'INSERT INTO headings(book_id, para_id, level, title, parent) '
    "VALUES ('dhp', 1, 1, 'Dhammapadapāḷi', 0)",
  );
  await db.customStatement(
    'INSERT INTO headings(book_id, para_id, level, title, parent) '
    "VALUES ('an1', 1, 1, 'Ekakanipātapāḷi', 0)",
  );
  await db.customStatement(
    'INSERT INTO headings(book_id, para_id, level, title, parent) '
    "VALUES ('an1', 2, 2, 'Catukkanipātapāḷi', 1)",
  );
  await db.customStatement(
    'INSERT INTO headings(book_id, para_id, level, title, parent) '
    "VALUES ('an1', 3, 2, 'Dasakanipātapāḷi', 1)",
  );

  return db;
}

void main() {
  late EpitakaDatabase epiDb;
  late AppDatabase appDb;
  late ProviderContainer container;
  late MentionService service;

  setUp(() async {
    epiDb = await _fixtureEpitakaDb();
    appDb = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDbProvider.overrideWith((ref) async => appDb),
        epitakaDbProvider.overrideWith((ref) async => epiDb),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() => appDb.close());
    addTearDown(() => epiDb.close());

    service = container.read(mentionServiceProvider);
    await service.buildIndex();
  });

  Future<List<MentionSearchResult>> search(String query, {int limit = 20}) =>
      service.search(query, limit: limit);

  test('regression: later-ordered books are found (no LIMIT-200 bias)',
      () async {
    // 'dhp' never surfaced under the old code: the '%d%h%' pre-filter
    // matched every dn1 heading, the LIMIT 200 was all dn1 rows, and none
    // of them even contained a 'p' for the fuzzy pass.
    final dhp = await search('dhp');
    expect(dhp, isNotEmpty, reason: 'Dhammapada must be found');
    expect(dhp.map((r) => r.bookId), contains('dhp'));

    // Same for headings deep inside a later book.
    final catukka = await search('catukka');
    expect(catukka, isNotEmpty);
    expect(catukka.map((r) => r.title), contains('Catukkanipātapāḷi'));

    final dasaka = await search('dasaka');
    expect(dasaka.map((r) => r.title), contains('Dasakanipātapāḷi'));
  });

  test('a book-id query surfaces the book and its headings together',
      () async {
    final results = await search('an1');
    expect(results, isNotEmpty);
    // Everything on top relates to an1.
    expect(results.first.bookId, 'an1');
    expect(results.every((r) => r.bookId == 'an1'), isTrue);
    // The whole-book entry is part of the results (ranked right alongside
    // the headings — fzf scores both highly for an exact id prefix).
    expect(
      results.any((r) =>
          r.entryType == AttachmentEntryType.book && r.paraId == 0),
      isTrue,
    );
  });

  test('fzf-style subsequence matching works across books', () async {
    // 'dgsut' skips letters: d-i-g-h-a s-u-t-t-a → d,g,s,u,t.
    final results = await search('dgsut');
    expect(
      results.map((r) => r.title),
      contains('Dīgha Sutta 1'),
    );
  });

  test('diacritic-insensitive fuzzy matching', () async {
    // Query without diacritics matches a heading stored with diacritics.
    final plain = await search('canki');
    expect(plain.map((r) => r.title), contains('Cankīsuttam'));

    // Query WITH diacritics matches the same heading.
    final accented = await search('Cankīsuttam');
    expect(accented.map((r) => r.title), contains('Cankīsuttam'));
  });

  test('results span multiple books when the query matches broadly',
      () async {
    // 'an' matches the Aṅguttara rows (an1/...) and Cankīsuttam (dn1).
    final results = await search('an');
    expect(results, isNotEmpty);
    expect(results.map((r) => r.bookId).toSet(), containsAll({'an1', 'dn1'}));
  });

  test('limit caps the number of returned results', () async {
    final results = await search('sutta', limit: 5);
    expect(results, isNotEmpty);
    expect(results.length, lessThanOrEqualTo(5));
  });

  test('empty and non-matching queries return no results', () async {
    expect(await search(''), isEmpty);
    expect(await search('   '), isEmpty);
    expect(await search('zzzzqqq'), isEmpty);
  });

  test('cache reloads after the index is rebuilt', () async {
    // Before the rebuild the 'ud' book does not exist yet.
    expect((await search('udana')).map((r) => r.bookId), isNot(contains('ud')));

    // Add a new book + heading and rebuild.
    await epiDb.customStatement(
      "INSERT INTO books(id, book_id, book_name) VALUES (4, 'ud', 'Udānapāḷi')",
    );
    await epiDb.customStatement(
      'INSERT INTO headings(book_id, para_id, level, title, parent) '
      "VALUES ('ud', 1, 1, 'Udānapāḷi', 0)",
    );
    await service.buildIndex();

    final results = await search('udana');
    expect(results, isNotEmpty);
    expect(results.first.bookId, 'ud');
    expect(results.map((r) => r.bookId), contains('ud'));
  });
}
