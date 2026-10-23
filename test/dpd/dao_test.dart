import 'dart:io';

import 'package:epitaka/features/dpd/database/dpd_dao_epitaka.dart';
import 'package:epitaka/features/dpd/database/dpd_database.dart';
import 'package:epitaka/features/dpd/models/lookup_results.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dpd_fixture.dart';

void main() {
  late Directory dir;
  late DpdDatabase db;
  late DpdDao dao;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('dpd_dao_test');
    db = DpdDatabase(buildDpdFixture(dir));
    dao = DpdDao(db);
  });

  tearDownAll(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  test('exact search returns every headword of the key, Pāḷi-sorted', () async {
    final results = await dao.searchExact('dhamma');
    final lemmas = results.map((r) => r.headword.lemma1).toList();
    expect(lemmas.take(4), [
      'dhamma 1.01',
      'dhamma 1.02',
      'dhamma 1.03',
      'dhamma 1.04',
    ]);
    expect(results.first.headword.meaning1, 'nature; character');
  });

  test('exact search misses a mistyped key; the fuzzy rescue finds it', () async {
    expect(await dao.searchExact('kammam'), isEmpty);
    final rescued = await dao.searchFuzzyExactKeyMatches('kammam');
    expect(rescued.first, 'kammaṃ');
    expect(rescued, containsAll(['kamaṃ', 'kāmaṃ', 'khamaṃ', 'kkamaṃ']));
    final headwords = await dao.searchFuzzyExact('kammam');
    expect(headwords, isNotEmpty);
  });

  test('roots come from the lookup row', () async {
    final roots = await dao.searchRoots('anugā');
    expect(roots.map((r) => r.root.root), ['√gā']);
    expect(roots.single.root.rootMeaning, 'sing');
  });

  test('sutta codes match the upper-case key', () async {
    final results = await dao.searchExact('dn1');
    expect(
      results.map((r) => r.headword.lemma1),
      contains('brahmajālasutta'),
    );
    expect(await dao.getSuttaInfo('brahmajālasutta'), isNotNull);
  });

  test('secondary columns parse into their result types', () async {
    Future<String?> column(String key, String? Function(LookupData) pick) async =>
        pick((await dao.getLookupRow(key))!);

    final decon = DeconstructorResult.fromJson(
      'abba',
      await column('abba', (r) => r.deconstructor),
    );
    expect(decon!.deconstructions, ['na + ba']);

    final grammar = GrammarDictResult.fromJson(
      'dhamma',
      await column('dhamma', (r) => r.grammar),
    );
    expect(grammar!.entries.first.components, ['masc', 'voc', 'sg']);

    final variant = VariantResult.fromJson(
      'tithī',
      await column('tithī', (r) => r.variant),
    );
    expect(variant!.variants['CST']!['AP'], [
      ['tithī', 'tithi'],
    ]);

    final spelling = SpellingResult.fromJson(
      'rokho',
      await column('rokho', (r) => r.spelling),
    );
    expect(spelling!.spellings, ['kho']);

    final see = SeeResult.fromJson(
      'virocatī',
      await column('virocatī', (r) => r.see),
    );
    expect(see!.seeHeadwords, ['virocati']);

    final epd = EpdResult.fromJson(
      'weed',
      await column('weed', (r) => r.epd),
    );
    expect(epd!.entries.single.headword, 'tiṇa');

    final abbrev = AbbreviationResult.fromJson(
      'neut',
      await column('neut', (r) => r.abbrev),
    );
    expect(abbrev!.meaning, 'neuter noun');

    final help = HelpResult.fromJson(
      'word family',
      await column('word family', (r) => r.help),
    );
    expect(help!.helpText, startsWith('All words comprised'));
  });

  test('db_info carries the schema and release version', () async {
    expect(await dao.getDbValue('db_schema_version'), '7');
    expect(await dao.getDbValue('dpd_release_version'), startsWith('v0.4.'));
  });

  test('suggestions fold diacritics, so plain typing finds the real word', () async {
    expect(await dao.searchSuggestions('dhamm'), contains('dhamma'));
    expect(await dao.searchSuggestions('satip'), contains('satipaṭṭhāna'));
    // Capitals fold the same way as lower case.
    expect(await dao.searchSuggestions('Satip'), contains('satipaṭṭhāna'));
    expect(await dao.searchSuggestions('kam'), contains('kāmaṃ'));
  });

  test('suggestions come in the DPD order and need two letters', () async {
    final keys = await dao.searchSuggestions('ka');
    expect(keys, containsAll(['kamaṃ', 'kammaṃ', 'khamaṃ', 'kkamaṃ', 'kāmaṃ']));
    expect(keys, [...keys]..sort(suggestionComparator));
    expect(await dao.searchSuggestions('d'), isEmpty);
  });

  group('lemma regex (rx in the dictionary)', () {
    List<String> lemmas(List<DpdHeadwordWithRoot> r) => [
      for (final h in r) h.headword.lemma1,
    ];

    test('`^…\$` finds every homograph of one clean lemma', () async {
      final r = await dao.searchLemmaRegex(r'^dhamma$');
      expect(r.total, 16);
      expect(lemmas(r.first).take(2), ['dhamma 1.01', 'dhamma 1.02']);
      expect(r.first.every((h) => h.headword.lemma1.startsWith('dhamma ')), isTrue);
    });

    test('more hits than the limit: the first ones in Pāḷi order, and the '
        'true total', () async {
      final r = await dao.searchLemmaRegex('^k', limit: 3);
      expect(r.total, 24);
      expect(lemmas(r.first), ['kama 1', 'kama 2', 'kama 3']);
    });

    test('diacritics are exact', () async {
      expect(lemmas((await dao.searchLemmaRegex(r'^dhammā$')).first), [
        'dhammā',
      ]);
      expect((await dao.searchLemmaRegex(r'^kāma$')).total, 4);
      expect((await dao.searchLemmaRegex(r'^kama$')).total, 3);
    });
  });

  test('the handle refuses writes and leaves no side files', () async {
    await expectLater(
      db.customStatement(
        "INSERT INTO db_info (key, value) VALUES ('probe', 'x')",
      ),
      throwsA(anything),
    );
    expect(await dao.getDbValue('probe'), isNull);

    final names = dir
        .listSync()
        .map((e) => e.uri.pathSegments.last)
        .toList();
    expect(names, ['dpd-mobile.db']);
  });
}
