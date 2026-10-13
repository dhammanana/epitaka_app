import 'dart:io';

import 'package:epitaka/core/providers/settings_provider.dart' show ThemePreference;
import 'package:epitaka/core/theme/app_theme.dart';
import 'package:epitaka/features/dpd/theme/dpd_palette.dart';
import 'package:epitaka/features/dictionary/providers/dictionary_expanded_provider.dart';
import 'package:epitaka/features/dictionary/providers/dictionary_font_scale_provider.dart';
import 'package:epitaka/features/dictionary/widgets/external_dictionary_section.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_sheet.dart';
import 'package:epitaka/features/dpd/providers/dict_entries_provider.dart';
import 'package:epitaka/features/dpd/providers/dictionary_list_provider.dart';
import 'package:epitaka/features/dpd/providers/dpd_database_provider.dart';
import 'package:epitaka/features/dpd/widgets/dict_html_card.dart';
import 'package:epitaka/features/dpd/database/dpd_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' show parse;
import 'package:sqlite3/sqlite3.dart';

import 'dpd_fixture.dart';
import 'shell_harness.dart';

void main() {
  late Directory dir;
  late File dbFile;
  late Map<String, String> html;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('external_dictionary_test');
    dbFile = buildDpdFixture(dir);
    final db = sqlite3.open(dbFile.path);
    html = {
      for (final r in db.select('SELECT dict_id, definition_html FROM dict_entries'))
        r['dict_id'] as String: r['definition_html'] as String,
    };
    db.dispose();
  });

  tearDownAll(() async {
    await dir.delete(recursive: true);
  });

  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('prepareDictHtml, on real entries', () {
    test('Cone: the lemma block is dropped', () {
      expect(html['cone'], contains('class="lemma"'));
      expect(
        prepareDictHtml('cone', html['cone']!),
        isNot(contains('<div class="lemma">')),
      );
    });

    test('MW: the page wrapper and the (H2) tag are dropped', () {
      expect(html['mw'], contains('<!DOCTYPE'));
      final out = prepareDictHtml('mw', html['mw']!);
      expect(out, isNot(contains('<!DOCTYPE')));
      expect(out, isNot(contains('(H2)')));
    });

    test('MW and Apte: a source abbreviation becomes a tooltip link', () {
      for (final id in ['mw', 'apte']) {
        final out = prepareDictHtml(id, html[id]!);
        expect(out, contains('<a href="tooltip:'), reason: id);
      }
    });

    test('CPD: the h2 headings become bold text', () {
      expect(html['cpd'], contains('<h2'));
      final out = prepareDictHtml('cpd', html['cpd']!);
      expect(out, isNot(contains('<h2')));
      expect(out, contains('<strong>'));
    });
  });

  group('applyDictStyles', () {
    test('a rule lands on the element as an inline style', () {
      final out = applyDictStyles(
        prepareDictHtml('mw', html['mw']!),
        (el) => el.classes.contains('sdata') ? {'font-style': 'italic'} : null,
      );
      final doc = parse(out);
      final styled = doc.querySelectorAll('span.sdata');
      expect(styled, isNotEmpty);
      expect(styled.every((e) => e.attributes['style'] == 'font-style:italic'), isTrue);
      expect(doc.querySelectorAll('span.record-id').first.attributes['style'], isNull);
    });

    test('px and pt sizes follow the scale, other values do not', () {
      final out = applyDictStyles(
        prepareDictHtml('mw', html['mw']!),
        (el) => el.classes.contains('ls')
            ? {'font-size': '10pt', 'color': 'inherit', 'margin-left': '1em'}
            : null,
        scale: 1.5,
      );
      final style = parse(out).querySelector('span.ls')!.attributes['style']!;
      expect(style, contains('font-size:15.00pt'));
      expect(style, contains('color:inherit'));
      expect(style, contains('margin-left:1em'));
    });
  });

  group('in the sheet', () {
    // The word has Pali English Ultimate, Edgerton, Apte and PTS entries.
    const word = 'ca';

    Future<ProviderContainer> open(WidgetTester tester) =>
        makeShellContainer(tester, dbFile, words: [word]);

    // Preload the external entries too: real file work cannot finish on the
    // test's fake clock.
    Future<void> preload(WidgetTester tester, ProviderContainer c) =>
        tester.runAsync(() async {
          final dao = await c.read(dpdDaoProvider.future);
          for (final id in ['peu', 'bhs', 'apte', 'pts', 'cone']) {
            c.listen(
              dictEntriesProvider(DictEntriesKey(id, word)),
              (_, _) {},
            );
            await c.read(dictEntriesProvider(DictEntriesKey(id, word)).future);
          }
          expect(dao, isNotNull);
        });

    double top(WidgetTester tester, String title) =>
        tester.getTopLeft(find.text(title, findRichText: true).first).dy;

    testWidgets('cards come in list order, and a switched-off one is gone', (
      tester,
    ) async {
      bigView(tester);
      final c = await open(tester);
      await preload(tester, c);
      // Folded, so every card is built: a long open entry would push the
      // later cards out of the lazy list.
      for (final id in ['peu', 'bhs', 'apte', 'pts']) {
        c.read(dictionaryExpandedProvider.notifier).setExpanded(id, false);
      }
      await tester.pumpWidget(
        wrapShell(c, const DictionarySheet(initialWord: word)),
      );
      await settleShell(tester);

      const titles = [
        'Pali English Ultimate',
        "Edgerton's Buddhist Hybrid Sanskrit Dictionary 1953",
        'Apte Practical Sanskrit-English Dictionary, 1890',
        'PTS Pāḷi-English Dictionary',
      ];
      for (final t in titles) {
        expect(find.text(t, findRichText: true), findsOneWidget, reason: t);
      }
      expect(find.text('Cone Dictionary of Pāli'), findsNothing);
      final ys = [for (final t in titles) top(tester, t)];
      expect(ys, orderedEquals([...ys]..sort()));

      final entries = c.read(dictionaryListProvider).requireValue;
      final store = c.read(dictionaryListStoreProvider.notifier);
      await tester.runAsync(() async {
        await store.setOrder([
          'pts',
          ...entries.map((e) => e.item.id).where((id) => id != 'pts'),
        ]);
        await store.setEnabled(
          entries.firstWhere((e) => e.item.id == 'bhs').item,
          false,
        );
      });
      await settleShell(tester);
      expect(find.text(titles[1], findRichText: true), findsNothing);
      expect(
        top(tester, titles[3]),
        lessThan(top(tester, titles[0])),
      );
    });
  });

  testWidgets('an external card: 120% draws its text 1.2 times as tall', (
    tester,
  ) async {
    bigView(tester);
    final c = await makeShellContainer(tester, dbFile);
    await tester.runAsync(() async {
      final key = DictEntriesKey('peu', 'ca');
      c.listen(dictEntriesProvider(key), (_, _) {});
      await c.read(dictEntriesProvider(key).future);
    });
    Future<double> measure(double scale) async {
      await c.read(dictionaryFontScaleProvider.notifier).setScale(scale);
      await tester.pumpWidget(
        wrapShell(
          c,
          const SingleChildScrollView(
            child: ExternalDictionarySection(
              dictId: 'peu',
              dictName: 'PEU',
              searchWord: 'ca',
              colors: ColorScheme.light(),
            ),
          ),
        ),
      );
      await settleShell(tester, frames: 3);
      return tester.getSize(find.text('ca').first).height;
    }

    final h100 = await measure(1.0);
    final h150 = await measure(1.2);
    expect(h150 / h100, closeTo(1.2, 0.1));
  });

  testWidgets('a rule colours the text, and a tooltip link opens its text', (
    tester,
  ) async {
    bigView(tester);
    final c = await makeShellContainer(tester, dbFile);
    final mw = DictEntry(
      id: 1,
      dictId: 'mw',
      word: 'anugā',
      wordFuzzy: 'anuga',
      definitionHtml: html['mw'],
    );
    await tester.pumpWidget(
      wrapShell(
        c,
        SingleChildScrollView(
          child: DictHtmlCard(
            dictId: 'mw',
            entries: [mw],
            baseStyle: const TextStyle(fontSize: 15),
          ),
        ),
      ),
    );
    await settleShell(tester, frames: 3);

    // The `sdata` rule: the palette's blue, in italics.
    final palette = AppTheme.forPreference(
      ThemePreference.light,
      platformBrightness: Brightness.light,
    ).extension<DpdPalette>()!;
    TextSpan? sdata;
    for (final rt in tester.widgetList<RichText>(find.byType(RichText))) {
      rt.text.visitChildren((s) {
        if (s is TextSpan && s.text == 'anu-ga') sdata = s;
        return true;
      });
    }
    expect(sdata, isNotNull);
    expect(sdata!.style?.fontStyle, FontStyle.italic);
    expect(sdata!.style?.color, palette.primaryText);

    // A source abbreviation opens its full name.
    await tester.tapOnText(find.textRange.ofSubstring('RV.'));
    await tester.pump();
    expect(find.text('Ṛg-veda'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
