import 'dart:io';

import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/features/dictionary/providers/dictionary_font_scale_provider.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_search_shared.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_sheet.dart';
import 'package:epitaka/features/mdx_dictionary/providers/mdx_lookup_providers.dart';
import 'package:epitaka/features/mdx_dictionary/widgets/mdx_definition_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dpd_fixture.dart';
import 'shell_harness.dart';

/// The height of the first line of the paragraph that draws [text].
double lineHeightOf(WidgetTester tester, String text) {
  final finder = find.byWidgetPredicate(
    (w) => w is RichText && w.text.toPlainText().contains(text),
  );
  final p = tester.renderObject<RenderParagraph>(finder.first);
  return p.getBoxesForSelection(const TextSelection(baseOffset: 0, extentOffset: 1)).first.bottom -
      p.getBoxesForSelection(const TextSelection(baseOffset: 0, extentOffset: 1)).first.top;
}

void main() {
  group('the scale', () {
    test('snaps to the slider steps and range', () {
      expect(snapDictionaryFontScale(1.0), closeTo(1.0, 1e-9));
      expect(snapDictionaryFontScale(1.02), closeTo(1.0, 1e-9));
      expect(snapDictionaryFontScale(0.1), closeTo(0.5, 1e-9));
      expect(snapDictionaryFontScale(9), closeTo(1.2, 1e-9));
    });

    test('100% is the default Pāḷi size, 120% is 1.2 times it', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(dictionaryPaliProvider).fontSize, 19);
      c.read(dictionaryFontScaleProvider.notifier).setScale(1.2);
      expect(c.read(dictionaryPaliProvider).fontSize, closeTo(22.8, 1e-9));
    });

    test('the reader size does not move it, the reader font family does', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final reader = c.read(settingsProvider).typography.pali;
      c.read(settingsProvider.notifier).increasePaliFontSize();
      final after = c.read(dictionaryPaliProvider);
      expect(after.fontSize, 19);
      expect(after.fontFamily, reader.fontFamily);
    });

    test('it survives a new container', () async {
      SharedPreferences.setMockInitialValues({});
      final first = ProviderContainer();
      addTearDown(first.dispose);
      await first.read(dictionaryFontScaleProvider.notifier).setScale(1.15);
      final second = ProviderContainer();
      addTearDown(second.dispose);
      second.read(dictionaryFontScaleProvider);
      await pumpEventQueue();
      expect(second.read(dictionaryFontScaleProvider), closeTo(1.15, 1e-9));
    });
  });

  group('every surface follows it', () {
    late Directory dir;
    late File dbFile;

    setUpAll(() async {
      dir = await Directory.systemTemp.createTemp('dictionary_font_scale_test');
      dbFile = buildDpdFixture(dir);
    });

    tearDownAll(() async {
      await dir.delete(recursive: true);
    });

    void bigView(WidgetTester tester) {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    testWidgets('a DPD entry: 120% draws the lemma 1.2 times as tall', (
      tester,
    ) async {
      bigView(tester);
      final c = await makeShellContainer(tester, dbFile, words: ['dhamma']);
      Future<(double, double)> measure(double scale) async {
        await c.read(dictionaryFontScaleProvider.notifier).setScale(scale);
        await tester.pumpWidget(
          wrapShell(c, const DictionarySheet(initialWord: 'dhamma')),
        );
        await settleShell(tester);
        return (
          lineHeightOf(tester, 'dhamma 1.01'),
          lineHeightOf(tester, 'nature; character'),
        );
      }

      final (title100, body100) = await measure(1.0);
      final (title150, body150) = await measure(1.2);
      expect(title150 / title100, closeTo(1.2, 0.1));
      expect(body150 / body100, closeTo(1.2, 0.1));
      expect(title100, greaterThanOrEqualTo(body100));
      expect(title150, greaterThanOrEqualTo(body150));
    });

    testWidgets('the lowest setting is really smaller than 80%', (tester) async {
      bigView(tester);
      final c = await makeShellContainer(tester, dbFile, words: ['dhamma']);
      Future<double> measure(double scale) async {
        await c.read(dictionaryFontScaleProvider.notifier).setScale(scale);
        await tester.pumpWidget(
          wrapShell(c, const DictionarySheet(initialWord: 'dhamma')),
        );
        await settleShell(tester);
        return lineHeightOf(tester, 'nature; character');
      }

      final low = await measure(0.5);
      final eighty = await measure(0.8);
      final full = await measure(1.0);
      expect(low / full, closeTo(0.5, 0.1));
      expect(low, lessThan(eighty * 0.75));
    });

    testWidgets('moving the slider changes an open entry at once', (
      tester,
    ) async {
      bigView(tester);
      final c = await makeShellContainer(tester, dbFile, words: ['dhamma']);
      await tester.pumpWidget(
        wrapShell(c, const DictionarySheet(initialWord: 'dhamma')),
      );
      await settleShell(tester);
      final before = lineHeightOf(tester, 'dhamma 1.01');
      await c.read(dictionaryFontScaleProvider.notifier).setScale(1.2);
      await settleShell(tester);
      expect(lineHeightOf(tester, 'dhamma 1.01'), greaterThan(before * 1.12));
    });

    testWidgets('a kept book: 120% draws its text 1.2 times as tall', (
      tester,
    ) async {
      bigView(tester);
      final c = await makeShellContainer(
        tester,
        dbFile,
        overrides: [
          dictionaryDefinitionProvider.overrideWith(
            (ref, key) async => [
              {'definition': '<p>sample bookword</p>'},
            ],
          ),
        ],
      );
      Future<double> measure(double scale) async {
        await c.read(dictionaryFontScaleProvider.notifier).setScale(scale);
        await tester.pumpWidget(
          wrapShell(
            c,
            const DictDefinitionSection(
              bookId: 1,
              bookName: 'Book',
              searchWord: 'x',
              colors: ColorScheme.light(),
            ),
          ),
        );
        await settleShell(tester);
        return lineHeightOf(tester, 'sample bookword');
      }

      final h100 = await measure(1.0);
      final h150 = await measure(1.2);
      expect(h150 / h100, closeTo(1.2, 0.1));
    });

    testWidgets('a suggestion row: 120% draws the word 1.2 times as tall', (
      tester,
    ) async {
      bigView(tester);
      final c = await makeShellContainer(tester, dbFile);
      Future<double> measure(double scale) async {
        await c.read(dictionaryFontScaleProvider.notifier).setScale(scale);
        await tester.pumpWidget(
          wrapShell(
            c,
            SuggestionTile(
              word: 'satiphāle',
              onTap: () {},
              colors: const ColorScheme.light(),
              highlightQuery: '',
            ),
          ),
        );
        await settleShell(tester, frames: 3);
        return lineHeightOf(tester, 'satiphāle');
      }

      final h100 = await measure(1.0);
      final h150 = await measure(1.2);
      expect(h150 / h100, closeTo(1.2, 0.1));
    });

    testWidgets('an MDX definition: 120% draws its text 1.2 times as tall', (
      tester,
    ) async {
      bigView(tester);
      final c = await makeShellContainer(
        tester,
        dbFile,
        overrides: [
          mdxDefinitionsProvider.overrideWith(
            (ref, key) async => ['<p>sample mdxword</p>'],
          ),
        ],
      );
      Future<double> measure(double scale) async {
        await c.read(dictionaryFontScaleProvider.notifier).setScale(scale);
        await tester.pumpWidget(
          wrapShell(
            c,
            const MdxDefinitionSection(
              dictId: 'm',
              dictTitle: 'M',
              searchWord: 'x',
            ),
          ),
        );
        await settleShell(tester);
        return lineHeightOf(tester, 'sample mdxword');
      }

      final h100 = await measure(1.0);
      final h150 = await measure(1.2);
      expect(h150 / h100, closeTo(1.2, 0.1));
    });
  });
}
