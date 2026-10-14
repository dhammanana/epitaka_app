/// The partial and fuzzy groups also show the extra dictionaries inside the
/// DPD file (Q8), as the DPD app does: one card per dictionary under each
/// heading, in the user's list order, after the DPD headwords.
library;

import 'dart:io';

import 'package:epitaka/features/dictionary/widgets/dictionary_sheet.dart';
import 'package:epitaka/features/dpd/database/dpd_dao_epitaka.dart';
import 'package:epitaka/features/dpd/database/dpd_database.dart';
import 'package:epitaka/features/dpd/providers/dict_entries_provider.dart';
import 'package:epitaka/features/dpd/providers/dictionary_list_provider.dart';
import 'package:epitaka/features/dpd/providers/dpd_lookup_provider.dart';
import 'package:epitaka/features/dpd/providers/dpd_settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'dpd_fixture.dart';
import 'shell_harness.dart';

// Real rows from dpd-mobile.db v0.4.20261012, definitions shortened only by
// choosing short entries. pts 647593 `dhamma` is exact for `dhamma`;
// `dhammatta` starts with it; `dhama`, `dama` and cone's `damma` share its
// fuzzy key `dama` but do not start with it.
const _realRows = [
  "INSERT INTO dict_entries VALUES(647593,'pts','dhamma','dama','<p><sup>3</sup> (adjective) [Sanskrit <i>dhanvan</i>] having a bow: see <i>daḷha°;</i> also as <i>dhammin</i> in <i>daḷha°</i> <b>SN</b> I 185 (see <i>dhammin</i>).</p>','');",
  "INSERT INTO dict_entries VALUES(647596,'pts','dhammatta','damata','<p>(neuter) [Sanskrit <i>dharmatvaṃ</i>] liability to be judged <b>Vinaya</b> II 55 (and <i>a°</i>).</p>','');",
  "INSERT INTO dict_entries VALUES(647586,'pts','dhama','dama','<p>(—°) (adjective) [Sanskrit <i>dhama,</i> to <i>dhamati</i>] blowing, noun a blower, player (on a horn: <i>saṅkha°</i>) <b>DN</b> I 251; <b>SN</b> IV 322.</p>','');",
  "INSERT INTO dict_entries VALUES(647441,'pts','dama','dama','<p>(adjective/noun) taming, subduing; self-control, self-command, moderation <b>Dhp</b> 9, 25, 261.</p>','');",
  "INSERT INTO dict_entries VALUES(24115,'cone','damma','dama','<div id=\"gd3definition\" class=\"gd3definition\"><div class=\"lemPanel\"><div class=\"lemma\"><span id=\"spanHomLem\"><span id=\"gd3form_hom\" class=\"lemsuper\">1</span><span id=\"gd3form_lem\" class=\"lemma\">damma</span></span></div><div></div><div><p><span id=\"gd3form_etymology\"></span><span id=\"gd3form_phonetic\"></span><span id=\"gd3form_pos\" class=\"morph\"></span><span id=\"gd3form_def\"><i>mfn.</i>, <i>fpp of</i> (<i>caus. of)</i> dammati <i>qv</i>.</span></p></div><div id=\"crossrefs\"></div></div></div>','');",
];

DictEntry _row(int id, String dictId, String word, String fuzzy) =>
    DictEntry(id: id, dictId: dictId, word: word, wordFuzzy: fuzzy);

String _drawn(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((r) => r.text.toPlainText())
    .join('\n');

void main() {
  group('splitDictLoose', () {
    final rows = [
      _row(647593, 'pts', 'dhamma', 'dama'),
      _row(647596, 'pts', 'dhammatta', 'damata'),
      _row(647586, 'pts', 'dhama', 'dama'),
      _row(647441, 'pts', 'dama', 'dama'),
      _row(24115, 'cone', 'damma', 'dama'),
    ];

    test('drops the exact word, splits by prefix, groups by dictionary', () {
      final loose = splitDictLoose(
        query: 'dhamma',
        exactWord: 'dhamma',
        rows: rows,
      );
      expect(loose.partial, {
        'pts': [rows[1]],
      });
      expect(loose.fuzzy.keys, unorderedEquals(['pts', 'cone']));
      expect(loose.fuzzy['pts']!.map((r) => r.word), ['dhama', 'dama']);
      expect(loose.fuzzy['cone']!.map((r) => r.word), ['damma']);
    });

    test('a typed form with its own entry stays when the cards show the lemma', () {
      final loose = splitDictLoose(
        query: 'dhammatta',
        exactWord: 'dhamma',
        rows: rows,
      );
      expect(loose.partial['pts']!.map((r) => r.word), ['dhammatta']);
    });

    test('capitals and the circle niggahīta still match', () {
      final loose = splitDictLoose(
        query: 'ānanda',
        exactWord: 'ānandaṁ',
        rows: [
          _row(1, 'dppn', 'Ānanda', 'ananda'),
          _row(2, 'dppn', 'Ānandaṃ', 'anandam'),
          _row(3, 'dppn', 'Ānandakumāra', 'anandakumara'),
        ],
      );
      expect(loose.partial['dppn']!.map((r) => r.word), [
        'Ānanda',
        'Ānandakumāra',
      ]);
      expect(loose.fuzzy, isEmpty);
    });

    test('at most [cap] rows per dictionary in each group', () {
      final many = [
        for (var i = 0; i < 70; i++) _row(i, 'mw', 'dhamma$i', 'dama$i'),
      ];
      final loose = splitDictLoose(
        query: 'dhamma',
        exactWord: 'dhamma',
        rows: many,
      );
      expect(loose.partial['mw'], hasLength(50));
    });
  });

  group('in the sheet', () {
    late Directory dir;
    late File dbFile;

    setUpAll(() async {
      dir = await Directory.systemTemp.createTemp('dict_tiers_test');
      dbFile = buildDpdFixture(dir);
      final db = sqlite3.open(dbFile.path);
      try {
        _realRows.forEach(db.execute);
      } finally {
        db.dispose();
      }
    });

    tearDownAll(() async {
      await dir.delete(recursive: true);
    });

    Future<ProviderContainer> show(
      WidgetTester tester, {
      void Function(DpdSettingsNotifier s)? configure,
      bool headwordsOff = false,
    }) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = await makeShellContainer(tester, dbFile);
      // `dhamma` has many headwords; at the other levels the groups sit below
      // what the lazy list builds. The cards do not depend on the level.
      c.read(dpdSettingsProvider.notifier).setLevel(DictionaryLevel.sankhitta);
      configure?.call(c.read(dpdSettingsProvider.notifier));
      await tester.runAsync(() async {
        c.listen(dictionaryListProvider, (_, _) {});
        await c.read(dictionaryAvailableProvider.future);
        while (c.read(dictionaryListProvider).valueOrNull == null) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        if (headwordsOff) {
          final entries = c.read(dictionaryListProvider).requireValue;
          await c
              .read(dictionaryListStoreProvider.notifier)
              .setEnabled(
                entries.firstWhere((e) => e.item.id == 'dpd_headwords').item,
                false,
              );
        }
        c.listen(dpdLookupProvider('dhamma'), (_, _) {});
        final lookup = await c.read(dpdLookupProvider('dhamma').future);
        for (final id in ['pts', 'cone', 'nyanatiloka']) {
          final key = DictEntriesKey(id, lookup.searchWord);
          c.listen(dictEntriesProvider(key), (_, _) {});
          await c.read(dictEntriesProvider(key).future);
        }
      });
      await tester.pumpWidget(
        wrapShell(c, const DictionarySheet(initialWord: 'dhamma')),
      );
      await settleShell(tester);
      return c;
    }

    testWidgets('off by default: no other dictionary in a loose group', (
      tester,
    ) async {
      await show(tester);
      final text = _drawn(tester);
      expect(text, contains('having a bow'));
      expect(text, isNot(contains('liability to be judged')));
      expect(text, isNot(contains('blowing, noun a blower')));
    });

    testWidgets('partial: the PTS card under the heading', (tester) async {
      await show(tester, configure: (s) => s.setShowPartialResults(true));
      final text = _drawn(tester);
      expect(text, contains('Partial Results'));
      expect(text, contains('liability to be judged'));
      expect(
        text.indexOf('liability to be judged'),
        greaterThan(text.indexOf('Partial Results')),
      );
      expect(text, isNot(contains('blowing, noun a blower')));
      // The exact entry stays above the heading, in its own card.
      expect(
        text.lastIndexOf('having a bow'),
        lessThan(text.indexOf('Partial Results')),
      );
    });

    testWidgets('fuzzy: Cone and PTS cards under the heading, in list order', (
      tester,
    ) async {
      final c = await show(
        tester,
        configure: (s) => s.setShowFuzzyResults(true),
      );
      final text = _drawn(tester);
      final heading = text.indexOf('Fuzzy Results');
      expect(heading, isNot(-1));
      final cone = text.indexOf('fpp of');
      final pts = text.indexOf('blowing, noun a blower');
      expect(cone, greaterThan(heading));
      expect(pts, greaterThan(heading));
      final order = [
        for (final e in c.read(dictionaryListProvider).requireValue) e.item.id,
      ];
      expect(
        cone < pts,
        order.indexOf('cone') < order.indexOf('pts'),
        reason: 'the cards follow the dictionary list',
      );
      expect(text, isNot(contains('liability to be judged')));
    });

    testWidgets('the heading shows with DPD Headwords switched off', (
      tester,
    ) async {
      await show(
        tester,
        headwordsOff: true,
        configure: (s) => s.setShowPartialResults(true),
      );
      final text = _drawn(tester);
      expect(text, contains('Partial Results'));
      expect(text, contains('liability to be judged'));
    });
  });

  // PEU holds 1,152 rows under `dhamma`'s fuzzy key, 942 of them starting with
  // `dhamma`: the partial card must show the first 50 in Pāḷi order, not
  // whatever 100 rows the index returns first. Words and ids are real (from
  // dpd-mobile.db v0.4.20261012); the definitions are stand-ins.
  test('a crowded range still gives the first 50 in Pāḷi order, with definitions', () async {
    final dir = await Directory.systemTemp.createTemp('dict_loose_crowded');
    addTearDown(() => dir.delete(recursive: true));
    final file = buildDpdFixture(dir);
    final lines = File('test/fixtures/dpd_peu_dama.tsv')
        .readAsLinesSync()
        .where((l) => l.isNotEmpty)
        .map((l) => l.split('\t'))
        .toList();
    final raw = sqlite3.open(file.path);
    final insert = raw.prepare(
      'INSERT OR IGNORE INTO dict_entries VALUES(?, ?, ?, ?, ?, ?)',
    );
    for (final l in lines) {
      insert.execute([int.parse(l[0]), 'peu', l[1], l[2], '<p>def ${l[0]}</p>', '']);
    }
    insert.dispose();
    raw.dispose();
    final db = DpdDatabase(file);
    addTearDown(db.close);
    final dao = DpdDao(db);

    final light = await dao.searchDictLoose(['peu'], 'dhamma');
    final loose = await dao.withDefinitions(
      splitDictLoose(query: 'dhamma', exactWord: 'dhamma', rows: light),
    );

    final expected =
        [
            for (final l in lines)
              if (l[1].toLowerCase().startsWith('dhamma') &&
                  l[1].toLowerCase() != 'dhamma')
                l[1],
          ]
          ..sort((a, b) => paliSortKey(a).compareTo(paliSortKey(b)));
    expect(expected.length, greaterThan(900));
    final partial = loose.partial['peu']!;
    expect(partial.map((r) => r.word), expected.take(50));
    expect(partial.every((r) => r.definitionHtml == '<p>def ${r.id}</p>'), isTrue);
    expect(loose.fuzzy['peu']!.first.definitionHtml, isNotNull);
  });

  test('searchDictLoose reads each dictionary by its fuzzy-key range', () async {
    final dir = await Directory.systemTemp.createTemp('dict_loose_dao');
    addTearDown(() => dir.delete(recursive: true));
    final file = buildDpdFixture(dir);
    final raw = sqlite3.open(file.path);
    _realRows.forEach(raw.execute);
    raw.dispose();
    final db = DpdDatabase(file);
    addTearDown(db.close);
    final rows = await DpdDao(db).searchDictLoose(['pts', 'cone'], 'Dhammā');
    expect(rows.map((r) => r.id), unorderedEquals([
      647593, 647596, 647586, 647441, 24115,
    ]));
  });
}
