/// The code cells shipped with the app (assets/sutta_code_cells.tsv) replace
/// the codes of an older database, so a DPD code opens the sutta DPD means.
/// Seed rows are copied from the real epitaka.db (dated 2026-10-03), where
/// `sn45.172` sits on the Yogasutta although DPD's SN45.172 is the Oghasutta.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:epitaka/core/database/epitaka_database.dart';
import 'package:epitaka/features/sutta_jump/services/sutta_code_service.dart';
import 'package:flutter_test/flutter_test.dart';

Future<EpitakaDatabase> _seed() async {
  final db = EpitakaDatabase(NativeDatabase.memory());
  await db.customStatement(
    'CREATE TABLE books (id INTEGER PRIMARY KEY, ref_id INTEGER, vri_id TEXT, '
    'book_id TEXT NOT NULL UNIQUE, category TEXT, nikaya TEXT, '
    'sub_nikaya TEXT, book_name TEXT, description TEXT, mula_ref TEXT, '
    'attha_ref TEXT, tika_ref TEXT, para_id INTEGER, chapter_len INTEGER)',
  );
  await db.customStatement(
    'CREATE TABLE headings (book_id TEXT, para_id INT, level INT, '
    'title TEXT, chapter_len INT, parent INT, sc_id TEXT)',
  );
  await db.customStatement(
    "INSERT INTO books(book_id, book_name) VALUES "
    "('S-v', 'Mahāvaggapāḷi'), ('Dvem-bhk', 'Bhikkhupātimokkhapāḷi')",
  );
  await db.customStatement(
    "INSERT INTO headings(book_id, para_id, level, title, sc_id) VALUES "
    "('S-v', 380, 3, '8. Oghavaggo', NULL), "
    "('S-v', 381, 4, '1. Oghasuttaṃ', 'sn45.171'), "
    "('S-v', 382, 10, '172', NULL), "
    "('S-v', 383, 4, '2. Yogasuttaṃ', 'sn45.172'), "
    "('S-v', 385, 4, '3. Upādānasuttaṃ', 'sn45.173'), "
    "('Dvem-bhk', 3, 1, 'Bhikkhupātimokkhapāḷi', 'pli-tv-bu-pm')",
  );
  return db;
}

// Lines of the real asset for these headings.
SuttaCodeCells _cells() => SuttaCodeCells.parse(
  '# a comment line\n'
  'S-v\t380\t8. Oghavaggo\tsn45.172 sn45.172-181\n'
  'S-v\t383\t2. Yogasuttaṃ\tsn45.173\n'
  'S-v\t385\t3. Upādānasuttaṃ\tsn45.174\n',
);

void main() {
  test('the cells file is read line by line, comments skipped', () {
    final cells = _cells();
    expect(cells.rows, hasLength(3));
    expect(cells.rows[('S-v', 383)]!.cell, 'sn45.173');
    expect(cells.books, {'S-v'});
  });

  test('the shipped asset holds the Oghasutta under SN45.172', () {
    final cells = SuttaCodeCells.parse(
      File('assets/sutta_code_cells.tsv').readAsStringSync(),
    );
    expect(cells.rows.length, greaterThan(5000));
    expect(cells.rows[('S-v', 380)]!.cell, contains('sn45.172'));
    expect(cells.rows[('S-v', 383)]!.cell, 'sn45.173');
  });

  test('without the cells, the old database sends sn45.172 to the Yogasutta', () async {
    final db = await _seed();
    addTearDown(db.close);
    final cache = await loadSuttaCodeLookup(db);
    expect(resolveSuttaCode(cache, 'sn45.172')!.paraId, 383);
  });

  test('with the cells, sn45.172 is the Oghasutta and sn45.173 the Yogasutta', () async {
    final db = await _seed();
    addTearDown(db.close);
    for (final cache in [
      await loadSuttaCodeLookup(db, cells: _cells()),
      await loadSuttaLookup(db, cells: _cells()),
    ]) {
      expect(resolveSuttaCode(cache, 'sn45.172')!.paraId, 380);
      expect(resolveSuttaCode(cache, 'sn45.173')!.paraId, 383);
      expect(resolveSuttaCode(cache, 'sn45.174')!.paraId, 385);
      // The old code of the Oghasutta no longer sits beside the fresh ones.
      expect(resolveSuttaCode(cache, 'sn45.171'), isNull);
    }
  });

  test('a book the cells do not cover keeps the codes of the database', () async {
    final db = await _seed();
    addTearDown(db.close);
    final cache = await loadSuttaCodeLookup(db, cells: _cells());
    expect(resolveSuttaCode(cache, 'pli-tv-bu-pm')!.bookId, 'Dvem-bhk');
  });

  test('cells built for other paragraph numbers are not used', () async {
    final db = await _seed();
    addTearDown(db.close);
    // Same paragraphs, other titles: a database that was renumbered.
    final shifted = SuttaCodeCells.parse(
      'S-v\t380\tAnother title\tsn45.172\n'
      'S-v\t383\tAnother title\tsn45.173\n',
    );
    expect(await suttaCellsFit(db, shifted), isFalse);
    final cache = await loadSuttaCodeLookup(db, cells: shifted);
    expect(resolveSuttaCode(cache, 'sn45.172')!.paraId, 383);
  });

  test('the box shows the same titles, and name search still works', () async {
    final db = await _seed();
    addTearDown(db.close);
    final cache = await loadSuttaLookup(db, cells: _cells());
    expect(searchSuttaNames(cache, 'yogasutta').first.paraId, 383);
  });
}
