// The suggestion list asks one tier at a time and stops at the first that
// finds anything. Runs on the real DPD fixture database.
library;

import 'dart:io';

import 'package:epitaka/core/providers/dictionary_books_provider.dart';
import 'package:epitaka/features/dpd/database/dpd_dao_epitaka.dart';
import 'package:epitaka/features/dpd/providers/dictionary_list_provider.dart';
import 'package:epitaka/features/dpd/providers/dpd_database_provider.dart';
import 'package:epitaka/features/dpd/providers/dpd_lookup_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import 'dpd_fixture.dart';
import 'shell_harness.dart';

void main() {
  late Directory dir;
  late File dbFile;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('suggestion_tiers_test');
    dbFile = buildDpdFixture(dir);
    final db = sqlite3.open(dbFile.path);
    // A lookup key the fuzzy_key range cannot reach: only the last tier sees it.
    // A sutta code with no fuzzy key: the literal and fuzzy ranges (lower case)
    // cannot reach it, only the last tier's upper-case range can.
    db.execute("INSERT INTO lookup (lookup_key) VALUES ('SN99')");
    // Shorter folded spellings that share `dhamma`'s fuzzy key, as in the real
    // database: they must not outrank the word the user actually typed.
    db.execute(
      "INSERT INTO lookup (lookup_key, fuzzy_key) VALUES "
      "('dam','dam'), ('dama','dama'), ('dhammaṃ','damam'), ('dhammā','dama')",
    );
    // Real keys that sort before `dhammo` in key order but are longer.
    db.execute(
      "INSERT INTO lookup (lookup_key, fuzzy_key) VALUES "
      "('dhammaabhiñño','damaabino'), ('dhammaadhikaraṇaṃ','damaadikaranam'), "
      "('dhammaanuttarā','damaanutara'), ('dhammo','damo')",
    );
    db.dispose();
  });

  tearDownAll(() async {
    await dir.delete(recursive: true);
  });

  Future<ProviderContainer> makeContainer() async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        dpdDatabaseFileProvider.overrideWith((ref) async => dbFile),
        dictionaryBooksProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(container.dispose);
    await preloadDictionaryList(container);
    return container;
  }

  Future<List<String>> suggest(ProviderContainer c, String prefix) =>
      c.read(dpdSuggestionsProvider(prefix).future);

  test('the typed word leads: dhamma before dama and dam', () async {
    final c = await makeContainer();
    final found = await suggest(c, 'dhamma');
    expect(found.first, 'dhamma');
    expect(found, containsAll(['dama', 'dhammā', 'dhammaṃ']));
  });

  test('words that start with the typed prefix come before the folded ones', () async {
    final c = await makeContainer();
    final found = await suggest(c, 'dhamm');
    expect(
      found.take(4),
      unorderedEquals(['dhamma', 'dhammā', 'dhammaṃ', 'dhammo']),
    );
    expect(found.indexOf('dhamma'), lessThan(found.indexOf('dam')));
    expect(found.indexOf('dhamma'), lessThan(found.indexOf('dama')));
  });

  // The real range `dhamm` holds 6,711 keys; in key order the first 100 are
  // long compounds and `dhammo` is not among them.
  test('the literal tier takes the shortest keys before its limit', () async {
    final c = await makeContainer();
    final dao = await c.read(dpdDaoProvider.future);
    final found = await dao.searchLiteralPrefix('dhamm', limit: 3);
    expect(found, contains('dhammo'));
    expect(found, isNot(contains('dhammaadhikaraṇaṃ')));
  });

  test('tier 1: a prefix that is not a prefix of the spelling still matches', () async {
    final c = await makeContainer();
    // `dam` is the fuzzy key of `dhamma`. No later tier can find it.
    expect(await suggest(c, 'dam'), contains('dhamma'));
  });

  test('tier 2: a typed hyphen is rescued by the exact fuzzy_key match', () async {
    final c = await makeContainer();
    final found = await suggest(c, 'kam-maṃ');
    expect(found, containsAll(['kammaṃ', 'kamaṃ']));
  });

  test('tier 3: an enabled external dictionary word is offered', () async {
    final c = await makeContainer();
    expect(await suggest(c, 'footno'), ['footnote']);
  });

  test('tier 3: a switched-off external dictionary is not asked', () async {
    final c = await makeContainer();
    final wordnet = (await c.read(dictionaryAvailableProvider.future))
        .firstWhere((i) => i.id == 'wordnet');
    await c.read(dictionaryListStoreProvider.notifier).setEnabled(wordnet, false);
    await pumpEventQueue();
    expect(await suggest(c, 'footno'), isEmpty);
  });

  test('tier 4: an upper-case sutta code is found only by the last tier', () async {
    final c = await makeContainer();
    expect(await suggest(c, 'sn9'), ['SN99']);
  });

  test('a sutta code in lower case finds the upper-case key', () async {
    final c = await makeContainer();
    expect(await suggest(c, 'dn1'), contains('DN1'));
  });

  test('a one-letter prefix suggests nothing', () async {
    final c = await makeContainer();
    expect(await suggest(c, 'd'), isEmpty);
  });
}
