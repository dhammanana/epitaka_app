library;

import 'dart:io';

import 'package:epitaka/core/database/dpd_dictionary_database.dart';
import 'package:epitaka/core/utils/pali_search_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('foldPaliDiacritics strips diacritics and lowercases', () {
    expect(foldPaliDiacritics('Sīla'), 'sila');
    expect(foldPaliDiacritics('Ariyamaṃsa'), 'ariyamamsa');
    expect(foldPaliDiacritics('ñāṇa'), 'nana');
    expect(foldPaliDiacritics('ṭhāna'), 'thana');
    expect(foldPaliDiacritics('dukkha'), 'dukkha');
    expect(foldPaliDiacritics('saṅgha'), 'sangha');
  });

  test('ascii prefix finds diacritic keys once norm index is ready', () async {
    final dir = await Directory.systemTemp.createTemp('dpd_norm_test');
    final path = '${dir.path}/dpd-dictionary.db';
    final setup = sqlite3.open(path);
    setup.execute(
      'CREATE TABLE dpd_lookup ('
      'lookup_key TEXT, headwords TEXT, deconstructor TEXT)',
    );
    setup.execute(
      'CREATE TABLE dpd_headwords ('
      'id INTEGER PRIMARY KEY, lemma_1 TEXT, meaning_html TEXT, '
      'antonym TEXT, synonym TEXT, stem TEXT, pattern TEXT)',
    );
    setup.execute("INSERT INTO dpd_lookup VALUES ('sīla', '[1]', '[]')");
    setup.execute("INSERT INTO dpd_lookup VALUES ('sīlabbata', '[2]', '[]')");
    setup.execute("INSERT INTO dpd_lookup VALUES ('ariyamaṃsa', '[3]', '[]')");
    setup.execute(
      "INSERT INTO dpd_headwords VALUES "
      "(1, 'sīla', '<p>virtue</p>', NULL, NULL, NULL, NULL)",
    );
    setup.execute(
      "INSERT INTO dpd_headwords VALUES "
      "(2, 'sīlabbata', '<p>rites</p>', NULL, NULL, NULL, NULL)",
    );
    setup.execute(
      "INSERT INTO dpd_headwords VALUES "
      "(3, 'ariyamaṃsa', '<p>flesh of the noble</p>', NULL, NULL, NULL, NULL)",
    );
    setup.dispose();

    final db = await DpdDictionaryDatabase.open(path);
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (!db.isNormReady) {
      if (DateTime.now().isAfter(deadline)) {
        fail('norm index was not ready in time');
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    final rows = db.searchLookup('sila');
    expect(rows.map((r) => r.lookupKey), contains('sīla'));
    expect(rows.map((r) => r.lookupKey), contains('sīlabbata'));

    final exact = db.getLookup('ariyamamsa');
    expect(exact, isNotNull);
    expect(exact!.lookupKey, 'ariyamaṃsa');
    expect(exact.headwords, [3]);

    db.dispose();
    await dir.delete(recursive: true);
  });
}
