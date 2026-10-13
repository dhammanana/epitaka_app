/// Inflection tables (Vitthāra): the table builder against the real template
/// rows in the fixture, and the section inside the dictionary sheet.
library;

import 'dart:convert';
import 'dart:io';

import 'package:epitaka/core/providers/settings_provider.dart'
    show WordLookupGesture;
import 'package:epitaka/features/dictionary/widgets/dictionary_sheet.dart';
import 'package:epitaka/features/dpd/database/dpd_database.dart';
import 'package:epitaka/features/dpd/models/inflection_table_builder.dart';
import 'package:epitaka/features/dpd/models/inflection_table_data.dart';
import 'package:epitaka/features/dpd/providers/dpd_settings_provider.dart';
import 'package:epitaka/features/dpd/providers/template_cache_provider.dart';
import 'package:epitaka/features/dpd/widgets/inflection_section.dart';
import 'package:flutter/material.dart';
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
  late DpdHeadwordWithRoot dhamma;
  late DpdHeadwordWithRoot indeclinable;
  late InflectionTemplate aMasc;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('dpd_inflection_test');
    dbFile = buildDpdFixture(dir);
    db = DpdDatabase(dbFile);
    final dao = DpdDao(db);
    dhamma = (await dao.searchExact('dhamma')).first;
    indeclinable = (await dao.searchExact('evaṃ')).first;
    aMasc = (await dao.getInflectionTemplate('a masc'))!;
  });

  tearDownAll(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  InflectionTableData? build(DpdHeadwordWithRoot h, {Set<String>? keys}) =>
      buildInflectionTable(
        stem: h.stem,
        pattern: h.pattern,
        pos: h.pos,
        lemma1: h.lemma1,
        templateLike: aMasc.templateLike,
        templateData: aMasc.data,
        lookupKeys: keys,
      );

  group('buildInflectionTable', () {
    test('lays the dhamma noun table out as the template rows say', () {
      expect(dhamma.stem, 'dhamm');
      final table = build(dhamma)!;
      expect(table.headers, ['', 'masc sg', 'masc pl']);
      expect(table.rows.map((r) => r.$1), [
        'nom',
        'acc',
        'instr',
        'dat',
        'abl',
        'gen',
        'loc',
        'voc',
        'in comps',
      ]);
      List<String> words(String row, int col) => table.rows
          .firstWhere((r) => r.$1 == row)
          .$2[col]
          .forms
          .map((f) => f.word)
          .toList();
      expect(words('nom', 0), ['dhammo']);
      expect(words('nom', 1), ['dhammā', 'dhammāse']);
      expect(words('instr', 0), ['dhammā', 'dhammena']);
      expect(words('abl', 0), ['dhammato', 'dhammamhā', 'dhammasmā', 'dhammā']);
      expect(words('in comps', 1), isEmpty);
    });

    test('holds every ending of the template, none more, none less', () {
      final grid = jsonDecode(aMasc.data) as List;
      var endings = 0;
      for (var r = 1; r < grid.length; r++) {
        final row = grid[r] as List;
        for (var c = 1; c < row.length; c += 2) {
          endings += (row[c] as List).where((e) => (e as String).isNotEmpty).length;
        }
      }
      final table = build(dhamma)!;
      final forms = [
        for (final r in table.rows)
          for (final cell in r.$2) ...cell.forms,
      ];
      expect(endings, greaterThan(20));
      expect(forms.length, endings);
      expect(
        extractWordForms(stem: dhamma.stem, templateData: aMasc.data),
        forms.map((f) => f.word).toSet(),
      );
    });

    test('the heading names the lemma, pattern and kind of table', () {
      final table = build(dhamma)!;
      expect(table.headingLemma, 'dhamma');
      expect(table.headingPattern, 'a masc');
      expect(table.headingDeclLabel, 'declension');
      expect(table.buttonLabel, 'Declension');
    });

    test('marks forms that are not in the lookup table', () {
      final table = build(dhamma, keys: {'dhammo'})!;
      final forms = [
        for (final r in table.rows)
          for (final cell in r.$2) ...cell.forms,
      ];
      expect(forms.where((f) => f.isOccurring).map((f) => f.word), ['dhammo']);
      expect(forms.where((f) => !f.isOccurring), isNotEmpty);
    });

    test('an indeclinable has no table', () {
      expect(indeclinable.stem, '-');
      expect(build(indeclinable), isNull);
    });
  });

  group('in the sheet', () {
    void bigScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    Future<void> open(
      WidgetTester tester,
      DictionaryLevel level,
    ) async {
      bigScreen(tester);
      final container = await makeShellContainer(
        tester,
        dbFile,
        words: ['dhamma', 'dhammena'],
        gesture: WordLookupGesture.singleTap,
      );
      container.read(dpdSettingsProvider.notifier).setLevel(level);
      await tester.runAsync(() async {
        container.listen(templateCacheProvider, (_, _) {});
        await container.read(templateCacheProvider.future);
      });
      await tester.pumpWidget(
        wrapShell(container, const DictionarySheet(initialWord: 'dhamma')),
      );
      await settleShell(tester);
    }

    testWidgets('Majjhima has no declension button', (tester) async {
      await open(tester, DictionaryLevel.majjhima);
      expect(find.text('declension'), findsNothing);
      expect(find.text('grammar'), findsWidgets);
    });

    testWidgets('Vitthāra opens the table from its button', (tester) async {
      await open(tester, DictionaryLevel.vitthara);
      expect(find.byType(InflectionSection), findsNothing);
      await tester.ensureVisible(find.text('declension').first);
      await tester.tap(find.text('declension').first);
      await settleShell(tester);
      expect(find.byType(InflectionSection), findsOneWidget);
      final text = _plain(tester);
      expect(text, contains('dhamma is a masc declension'));
      expect(text, contains('dhammo'));
      expect(text, contains('dhammena'));
    });

    testWidgets('tapping a form searches it in the same sheet', (tester) async {
      await open(tester, DictionaryLevel.vitthara);
      await tester.ensureVisible(find.text('declension').first);
      await tester.tap(find.text('declension').first);
      await settleShell(tester);

      final form = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText() == 'dhammena',
      );
      expect(form, findsWidgets);
      await tester.ensureVisible(form.first);
      await tester.tap(form.first);
      await settleShell(tester);
      expect(fieldText(tester), 'dhammena');
    });
  });
}
