/// Family sections and the root card (Vitthāra): the parsers against real
/// fixture rows, and the sections inside an entry card and the sheet.
library;

import 'dart:io';

import 'package:epitaka/core/providers/settings_provider.dart'
    show WordLookupGesture;
import 'package:epitaka/features/dictionary/widgets/dictionary_sheet.dart';
import 'package:epitaka/features/dpd/database/dpd_database.dart';
import 'package:epitaka/features/dpd/database/dpd_headword_extensions.dart';
import 'package:epitaka/features/dpd/models/family_data.dart';
import 'package:epitaka/features/dpd/providers/dpd_settings_provider.dart';
import 'package:epitaka/features/dpd/providers/family_provider.dart';
import 'package:epitaka/features/dpd/widgets/family_table.dart';
import 'package:epitaka/features/dpd/widgets/inline_entry_card.dart';
import 'package:epitaka/features/dpd/widgets/inline_root_card.dart';
import 'package:epitaka/features/dpd/widgets/multi_family_section.dart';
import 'package:epitaka/features/dpd/widgets/root_info_table.dart';
import 'package:epitaka/features/dpd/widgets/root_matrix_builder.dart';
import 'package:epitaka/features/dpd/widgets/root_matrix_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dpd_fixture.dart';
import 'shell_harness.dart';

String _plain(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((r) => r.text.toPlainText())
    .join('\n');

void main() {
  late Directory dir;
  late File dbFile;
  late DpdDatabase db;
  late DpdDao dao;

  // Real fixture ids. The comment names the family kinds the row has.
  const ids = {
    'anuga': 4375, // root family only
    'evaṃ 1': 18134, // word family, compound family, idiom
    'kāmaṃ 1': 21082, // root family, compound family, idiom
    'kamma 7': 20238, // root family, set
    'cittasamuṭṭhāna': 26640, // two compound families
  };

  Future<DpdHeadwordWithRoot> word(String lemma1) async =>
      (await dao.getById(ids[lemma1]!))!;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('dpd_family_test');
    dbFile = buildDpdFixture(dir);
    db = DpdDatabase(dbFile);
    dao = DpdDao(db);
  });

  tearDownAll(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  group('family data', () {
    test('parses a real word-family row into lemma, pos, meaning, completion',
        () async {
      final row = (await dao.getWordFamily('eva'))!;
      final entries = parseFamilyData(row.data);
      expect(entries.length, row.count);
      expect(entries, isNotEmpty);
      for (final e in entries) {
        expect(e.lemma, isNotEmpty);
        expect(e.pos, isNotEmpty);
      }
    });

    test('a null, empty or broken value gives no entries', () {
      expect(parseFamilyData(null), isEmpty);
      expect(parseFamilyData(''), isEmpty);
      expect(parseFamilyData('[["only one"]]'), isEmpty);
    });
  });

  group('root matrix', () {
    test('puts the real headwords of √kam 1 under their part of speech',
        () async {
      final rows = await dao.getHeadwordsForRootMatrix('√kam 1');
      expect(rows.map((r) => r.lemma1).toSet(), {
        'kama 1',
        'kama 2',
        'kama 3',
        'kami',
      });
      final matrix = buildRootMatrix(rows);
      expect(matrix['nouns']!['masc'], ['kama ¹', 'kama ²']);
      expect(matrix['adjectives']!['adj'], ['kama ³']);
      expect(matrix['verbs']!['aor'], ['kami']);
      final filled = [
        for (final cat in matrix.values)
          for (final sub in cat.entries)
            if (sub.value.isNotEmpty) sub.key,
      ];
      expect(filled, unorderedEquals(['masc', 'adj', 'aor']));
    });
  });

  group('in an entry card', () {
    void bigScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    /// Real file reads never finish on the fake clock, so the card's own
    /// family load is waited for on the real one.
    Future<void> loaded(WidgetTester tester) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await settleShell(tester, frames: 4);
    }

    Future<ProviderContainer> openCard(
      WidgetTester tester,
      DpdHeadwordWithRoot h,
      DictionaryLevel level,
    ) async {
      bigScreen(tester);
      final container = await makeShellContainer(tester, dbFile);
      container.read(dpdSettingsProvider.notifier).setLevel(level);
      await tester.runAsync(() async {
        container.listen(compoundFamilyKeysProvider, (_, _) {});
        container.listen(idiomKeysProvider, (_, _) {});
        await container.read(compoundFamilyKeysProvider.future);
        await container.read(idiomKeysProvider.future);
      });
      await tester.pumpWidget(
        wrapShell(
          container,
          SingleChildScrollView(
            child: InlineEntryCard(
              headword: h,
              level: level,
              lookupKey: h.headword.lemmaClean,
            ),
          ),
        ),
      );
      await settleShell(tester, frames: 4);
      return container;
    }

    Future<void> press(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await settleShell(tester, frames: 2);
      await loaded(tester);
    }

    testWidgets('Majjhima has no family button', (tester) async {
      await openCard(
        tester,
        await word('anuga'),
        DictionaryLevel.majjhima,
      );
      expect(find.text('root family'), findsNothing);
      expect(find.text('grammar'), findsWidgets);
    });

    testWidgets('the root family button opens the root family table',
        (tester) async {
      final h = await word('anuga');
      await openCard(tester, h, DictionaryLevel.vitthara);
      expect(find.byType(FamilyTableWidget), findsNothing);
      await press(tester, 'root family');
      expect(find.byType(FamilyTableWidget), findsOneWidget);
      final text = _plain(tester);
      expect(text, contains('belong to the root family'));
      expect(text, contains('anu √gam'));
      expect(text, contains('Report it here'));
    });

    testWidgets('the word family button opens the word family table',
        (tester) async {
      await openCard(tester, await word('evaṃ 1'), DictionaryLevel.vitthara);
      await press(tester, 'word family');
      expect(_plain(tester), contains('words which belong to the'));
      expect(_plain(tester), contains('eva'));
    });

    testWidgets('the compound button opens the compound family',
        (tester) async {
      await openCard(
        tester,
        await word('kāmaṃ 1'),
        DictionaryLevel.vitthara,
      );
      await press(tester, 'compound family');
      expect(_plain(tester), contains('which contain'));
      expect(_plain(tester), contains('kāma'));
    });

    testWidgets('two compound families share one section with a jump list',
        (tester) async {
      await openCard(
        tester,
        await word('cittasamuṭṭhāna'),
        DictionaryLevel.vitthara,
      );
      await press(tester, 'compound families');
      expect(find.byType(MultiFamilySection), findsOneWidget);
      final text = _plain(tester);
      expect(text, contains('jump to:'));
      expect(text, contains('citta1'));
      expect(text, contains('samuṭṭhāna'));
      expect('Fix it here'.allMatches(text), hasLength(1));
    });

    testWidgets('the idioms button opens the idiom table', (tester) async {
      await openCard(
        tester,
        await word('kāmaṃ 1'),
        DictionaryLevel.vitthara,
      );
      await press(tester, 'idioms');
      expect(_plain(tester), contains('idiomatic expression'));
    });

    testWidgets('the set button opens the set table', (tester) async {
      await openCard(tester, await word('kamma 7'), DictionaryLevel.vitthara);
      await press(tester, 'set');
      expect(_plain(tester), contains('belongs to the set of'));
      expect(_plain(tester), contains('grammatical terms'));
    });

    testWidgets('one section at a time: a second family closes the first',
        (tester) async {
      await openCard(tester, await word('kāmaṃ 1'), DictionaryLevel.vitthara);
      await press(tester, 'root family');
      expect(_plain(tester), contains('belong to the root family'));
      await press(tester, 'idioms');
      expect(_plain(tester), contains('idiomatic expression'));
      expect(_plain(tester), isNot(contains('belong to the root family')));
      await press(tester, 'grammar');
      expect(_plain(tester), isNot(contains('idiomatic expression')));
    });

    testWidgets('with one-at-a-time off, two family sections stay open',
        (tester) async {
      final container = await openCard(
        tester,
        await word('kāmaṃ 1'),
        DictionaryLevel.vitthara,
      );
      container.read(dpdSettingsProvider.notifier).setOneButtonAtATime(false);
      await settleShell(tester, frames: 2);
      await press(tester, 'root family');
      await press(tester, 'idioms');
      expect(_plain(tester), contains('belong to the root family'));
      expect(_plain(tester), contains('idiomatic expression'));
    });
  });

  group('root card in the sheet', () {
    void bigScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    Future<ProviderContainer> open(
      WidgetTester tester,
      DictionaryLevel level,
    ) async {
      bigScreen(tester);
      final container = await makeShellContainer(
        tester,
        dbFile,
        words: ['hi'],
        gesture: WordLookupGesture.singleTap,
      );
      container.read(dpdSettingsProvider.notifier).setLevel(level);
      await tester.runAsync(() async {
        for (final key in ['√hi 1', '√hi 2']) {
          container.listen(basesForRootProvider(key), (_, _) {});
          container.listen(rootMatrixProvider(key), (_, _) {});
          await container.read(basesForRootProvider(key).future);
          await container.read(rootMatrixProvider(key).future);
        }
      });
      await tester.pumpWidget(
        wrapShell(container, const DictionarySheet(initialWord: 'hi')),
      );
      await settleShell(tester);
      return container;
    }

    testWidgets('Majjhima shows the root summary only', (tester) async {
      await open(tester, DictionaryLevel.majjhima);
      expect(find.byType(InlineRootCard), findsNothing);
      expect(find.text('root info'), findsNothing);
    });

    testWidgets('Vitthāra shows the info, matrix and family buttons',
        (tester) async {
      await open(tester, DictionaryLevel.vitthara);
      expect(find.byType(InlineRootCard), findsNWidgets(2));
      expect(find.text('root info'), findsNWidgets(2));
      expect(find.text('root matrix'), findsNWidgets(2));
    });

    testWidgets('a root family button opens that family', (tester) async {
      bigScreen(tester);
      final rwf = (await dao.getRootWithFamilies('√gam'))!;
      expect(rwf.families.map((f) => f.rootFamily), contains('anu √gam'));
      final container = await makeShellContainer(tester, dbFile);
      await tester.pumpWidget(
        wrapShell(
          container,
          SingleChildScrollView(child: InlineRootCard(rwf: rwf)),
        ),
      );
      await settleShell(tester, frames: 4);
      expect(find.byType(FamilyTableWidget), findsNothing);
      await tester.tap(find.text('anu √gam'));
      await settleShell(tester, frames: 4);
      expect(find.byType(FamilyTableWidget), findsOneWidget);
      expect(_plain(tester), contains('belong to the root family'));
    });

    testWidgets('root info opens the root table, then the matrix replaces it',
        (tester) async {
      await open(tester, DictionaryLevel.vitthara);
      await tester.ensureVisible(find.text('root info').first);
      await tester.tap(find.text('root info').first);
      await settleShell(tester);
      expect(find.byType(RootInfoTable), findsOneWidget);
      expect(_plain(tester), contains('Pāḷi Root:'));

      await tester.ensureVisible(find.text('root matrix').first);
      await tester.tap(find.text('root matrix').first);
      await settleShell(tester);
      expect(find.byType(RootInfoTable), findsNothing);
      expect(find.byType(RootMatrixTable), findsOneWidget);
    });
  });
}
