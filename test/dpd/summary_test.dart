/// The Saṅkhitta level: one summary line per headword, root and secondary
/// source, read from rows copied out of the real DPD export.
library;

import 'dart:io';

import 'package:epitaka/features/dictionary/widgets/dictionary_sheet.dart';
import 'package:epitaka/features/dpd/models/summary_entry.dart';
import 'package:epitaka/features/dpd/providers/dpd_database_provider.dart';
import 'package:epitaka/features/dpd/providers/dpd_lookup_provider.dart';
import 'package:epitaka/features/dpd/providers/dpd_settings_provider.dart';
import 'package:epitaka/features/dpd/providers/summary_provider.dart';
import 'package:epitaka/features/dpd/widgets/summary_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dpd_fixture.dart';
import 'shell_harness.dart';

String _drawn(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((r) => r.text.toPlainText())
    .join('\n');

void main() {
  late Directory dir;
  late File dbFile;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('dpd_summary_test');
    dbFile = buildDpdFixture(dir);
  });

  tearDownAll(() async {
    await dir.delete(recursive: true);
  });

  late ProviderContainer lookups;

  setUpAll(() {
    // Saved settings outlive a test file when files share a process. A
    // partial or fuzzy switch left on by an earlier file makes these
    // unwatched lookups fail with "disposed during loading state".
    SharedPreferences.setMockInitialValues({});
    lookups = ProviderContainer(
      overrides: [dpdDatabaseFileProvider.overrideWith((ref) async => dbFile)],
    );
  });

  tearDownAll(() => lookups.dispose());

  Future<DpdLookup> lookupOf(String word) =>
      lookups.read(dpdLookupProvider(word).future);

  List<SummaryEntry> summaryOf(DpdLookup l) =>
      buildSummaryEntries(l.headwords, l.roots, l.secondary);

  group('buildSummaryEntries', () {
    test('has one line per headword, with lemma, pos and meaning', () async {
      final lookup = await lookupOf('dhamma');
      final entries = summaryOf(lookup!);
      expect(lookup.headwords.length, greaterThan(1));
      expect(entries.length, lookup.headwords.length + lookup.secondary.length);
      final first = entries.first;
      final h = lookup.headwords.first.headword;
      expect(first.type, SummaryEntryType.headword);
      expect(first.label, h.lemma1);
      expect(first.typeLabel, '${h.pos}.');
      expect(first.meaning, startsWith(h.meaning1!));
      expect(first.meaningHasBold, isTrue);
    });

    test('with sources, lists only those, in that order', () async {
      final lookup = await lookupOf('dhamma');
      List<SummaryEntry> of(List<String> sources) => buildSummaryEntries(
        lookup.headwords,
        lookup.roots,
        lookup.secondary,
        sources: sources,
      );
      final grammarFirst = of(['dpd_grammar', 'dpd_headwords']);
      expect(grammarFirst.first.type, SummaryEntryType.grammar);
      expect(grammarFirst.last.type, SummaryEntryType.headword);
      expect(of(['dpd_grammar']).map((e) => e.type), [
        SummaryEntryType.grammar,
      ]);
      expect(of(const []), isEmpty);
    });

    test('has one line per root', () async {
      final lookup = await lookupOf('anugā');
      final roots = summaryOf(
        lookup,
      ).where((e) => e.type == SummaryEntryType.root);
      expect(roots.map((e) => e.label), ['√gā']);
      expect(roots.single.typeLabel, 'root.');
    });

    test('has one line for each kind of secondary source', () async {
      const expected = {
        'abba': SummaryEntryType.deconstructor,
        'tithī': SummaryEntryType.variant,
        'virocatī': SummaryEntryType.see,
        'rokho': SummaryEntryType.spelling,
        'word family': SummaryEntryType.help,
        'neut': SummaryEntryType.abbreviation,
        'sandhi': SummaryEntryType.abbreviationOther,
        'weed': SummaryEntryType.epd,
      };
      for (final MapEntry(key: word, value: type) in expected.entries) {
        final lookup = await lookupOf(word);
        final types = summaryOf(lookup!).map((e) => e.type);
        expect(types, contains(type), reason: word);
        expect(
          types.where((t) => t != SummaryEntryType.headword).length,
          lookup.roots.length + lookup.secondary.length,
          reason: word,
        );
      }
    });
  });

  group('splitSummaryLemma', () {
    test('splits the homograph number off the lemma', () {
      expect(splitSummaryLemma('dhamma 1.01').lemma, 'dhamma');
      expect(splitSummaryLemma('dhamma 1.01').suffix, '1.01');
      expect(splitSummaryLemma('dhamma').suffix, isNull);
      expect(splitSummaryLemma('word family').suffix, isNull);
    });
  });

  group('the level on screen', () {
    void bigScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    // A secondary line with no content is a label for a card, and Saṅkhitta
    // has no cards, so it is left out (user, 2026-10-14).
    testWidgets('Saṅkhitta draws every line with content and no grammar button', (
      tester,
    ) async {
      bigScreen(tester);
      final container = await makeShellContainer(
        tester,
        dbFile,
        words: ['dhamma', 'anugā'],
      );
      container
          .read(dpdSettingsProvider.notifier)
          .setLevel(DictionaryLevel.sankhitta);
      for (final word in ['dhamma', 'anugā']) {
        final lookup = await tester.runAsync(
          () => container.read(dpdLookupProvider(word).future),
        );
        // A new sheet for each word: the old one keeps its first word.
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          wrapShell(container, DictionarySheet(initialWord: word)),
        );
        // The localisations load asynchronously, so the first frame is empty.
        await settleShell(tester);
        final text = _drawn(tester);
        expect(find.byType(SummarySection), findsOneWidget, reason: word);
        final lines = summaryOf(lookup!);
        for (final line in lines.where((l) => l.meaning.isEmpty)) {
          expect(text, isNot(contains(line.typeLabel)), reason: word);
        }
        for (final line in lines.where((l) => l.meaning.isNotEmpty)) {
          // Homographs share one lemma heading, so the label is checked by
          // its lemma and the rest of the line is checked on its own.
          final lemma = splitSummaryLemma(line.label).lemma;
          final rest = [
            line.typeLabel,
            line.meaning,
          ].where((p) => p.isNotEmpty).join(' ');
          expect(text, contains(lemma), reason: '$word: ${line.label}');
          expect(text, contains(rest), reason: '$word: ${line.label}');
        }
        expect(find.text('grammar'), findsNothing);
        expect(find.text('example'), findsNothing);
      }
    });

    // `kkamaṃ` has only a deconstruction. Brief drops the lines that only
    // label a card, but this one carries the splits, or the page is blank.
    testWidgets('Saṅkhitta shows a deconstruction with its splits', (
      tester,
    ) async {
      bigScreen(tester);
      final container = await makeShellContainer(
        tester,
        dbFile,
        words: ['kkamaṃ'],
      );
      container
          .read(dpdSettingsProvider.notifier)
          .setLevel(DictionaryLevel.sankhitta);
      await tester.pumpWidget(
        wrapShell(container, const DictionarySheet(initialWord: 'kkamaṃ')),
      );
      await settleShell(tester);
      final text = _drawn(tester);
      // The splits sit on their own line, under the word.
      expect(text, contains('deconstructor.\nkamaṃ'));
    });

    testWidgets('changing the level in an open sheet changes the content', (
      tester,
    ) async {
      bigScreen(tester);
      final container = await makeShellContainer(
        tester,
        dbFile,
        words: ['dhamma'],
      );
      await tester.pumpWidget(
        wrapShell(container, const DictionarySheet(initialWord: 'dhamma')),
      );
      await settleShell(tester);
      expect(find.text('grammar'), findsWidgets);
      expect(find.byType(SummarySection), findsNothing);

      container
          .read(dpdSettingsProvider.notifier)
          .setLevel(DictionaryLevel.sankhitta);
      await settleShell(tester);
      expect(find.text('grammar'), findsNothing);
      expect(find.byType(SummarySection), findsOneWidget);

      container
          .read(dpdSettingsProvider.notifier)
          .setLevel(DictionaryLevel.majjhima);
      await settleShell(tester);
      expect(find.text('grammar'), findsWidgets);
      expect(find.byType(SummarySection), findsNothing);
    });
  });
}
