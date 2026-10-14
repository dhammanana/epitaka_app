/// The summary at the top of the lookup page: one line per result in list
/// order, a tap that scrolls to the card, and the "Show the summary" option.
/// Rows are the real fixture rows for "ca" (Pali English Ultimate, Edgerton,
/// Apte and PTS have an entry; Cone has none).
library;

import 'dart:io';

import 'package:epitaka/features/dictionary/providers/dictionary_expanded_provider.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_panel.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_sheet.dart';
import 'package:epitaka/features/dpd/models/summary_entry.dart';
import 'package:epitaka/features/dpd/providers/dict_entries_provider.dart';
import 'package:epitaka/features/dpd/providers/dictionary_list_provider.dart';
import 'package:epitaka/features/dpd/providers/dpd_settings_provider.dart';
import 'package:epitaka/features/dpd/widgets/dpd_results_view.dart';
import 'package:epitaka/features/dpd/widgets/inline_entry_card.dart';
import 'package:epitaka/features/dpd/widgets/summary_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dpd_fixture.dart';
import 'shell_harness.dart';

const _word = 'ca';
const _externals = ['peu', 'bhs', 'apte', 'pts', 'cone'];
const _ptsTitle = 'PTS Pāḷi-English Dictionary';
const _windowHeight = 1000.0;

void main() {
  late Directory dir;
  late File dbFile;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('page_summary_test');
    dbFile = buildDpdFixture(dir);
  });

  tearDownAll(() async {
    await dir.delete(recursive: true);
  });

  /// A window too short for the whole page, so a jump has to scroll.
  void shortView(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, _windowHeight);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<ProviderContainer> open(
    WidgetTester tester, {
    bool summary = true,
  }) async {
    final c = await makeShellContainer(
      tester,
      dbFile,
      words: [_word],
      summary: summary,
    );
    // Real file work cannot finish on the fake clock.
    await tester.runAsync(() async {
      for (final id in _externals) {
        final key = DictEntriesKey(id, _word);
        c.listen(dictEntriesProvider(key), (_, _) {});
        await c.read(dictEntriesProvider(key).future);
      }
    });
    // Folded, so a long open entry cannot push later cards out of the list.
    for (final id in _externals) {
      c.read(dictionaryExpandedProvider.notifier).setExpanded(id, false);
    }
    return c;
  }

  Future<void> show(
    WidgetTester tester,
    ProviderContainer c, {
    bool panel = false,
  }) async {
    await tester.pumpWidget(
      wrapShell(
        c,
        panel
            ? const DictionaryPanel(initialWord: _word)
            : const DictionarySheet(initialWord: _word),
      ),
    );
    await settleShell(tester);
  }

  List<SummaryEntry> lines(WidgetTester tester) => tester
      .widget<SummarySection>(
        find.byType(SummarySection, skipOffstage: false),
      )
      .entries;

  List<String> externalTargets(WidgetTester tester) => [
    for (final e in lines(tester))
      if (e.type == SummaryEntryType.dict) e.targetId,
  ];

  double titleTop(WidgetTester tester, String title) => tester
      .getTopLeft(
        find.text(title, findRichText: true, skipOffstage: false).first,
      )
      .dy;

  group('lines', () {
    testWidgets('come in list order, DPD first then the dictionaries', (
      tester,
    ) async {
      shortView(tester);
      final c = await open(tester);
      await show(tester, c);

      final entries = lines(tester);
      final firstDict = entries.indexWhere(
        (e) => e.type == SummaryEntryType.dict,
      );
      expect(firstDict, greaterThan(0));
      expect(
        entries.take(firstDict).every((e) => e.type != SummaryEntryType.dict),
        isTrue,
      );
      expect(externalTargets(tester), [
        'item_peu',
        'item_bhs',
        'item_apte',
        'item_pts',
      ]);
    });

    testWidgets('a dictionary without an entry for the word has no line', (
      tester,
    ) async {
      shortView(tester);
      final c = await open(tester);
      await show(tester, c);

      final enabled = c
          .read(dictionaryListProvider)
          .requireValue
          .where((e) => e.enabled)
          .map((e) => e.item.id);
      expect(enabled, contains('cone'));
      expect(externalTargets(tester), isNot(contains('item_cone')));
    });

    testWidgets('a switched-off dictionary has no line', (tester) async {
      shortView(tester);
      final c = await open(tester);
      final entries = c.read(dictionaryListProvider).requireValue;
      await tester.runAsync(
        () => c
            .read(dictionaryListStoreProvider.notifier)
            .setEnabled(entries.firstWhere((e) => e.item.id == 'bhs').item, false),
      );
      await show(tester, c);

      expect(externalTargets(tester), [
        'item_peu',
        'item_apte',
        'item_pts',
      ]);
    });

    testWidgets('a summary moved to the end of the list draws last', (
      tester,
    ) async {
      shortView(tester);
      final c = await open(tester);
      final ids = c
          .read(dictionaryListProvider)
          .requireValue
          .map((e) => e.item.id)
          .toList();
      await tester.runAsync(
        () => c.read(dictionaryListStoreProvider.notifier).setOrder([
          ...ids.where((id) => id != kDpdSummaryId),
          kDpdSummaryId,
        ]),
      );
      await show(tester, c);

      final summaryTop = tester.getTopLeft(find.text('Summary', skipOffstage: false)).dy;
      final ptsTop = titleTop(tester, _ptsTitle);
      expect(summaryTop, greaterThan(ptsTop));
    });
  });

  group('a tap on a line', () {
    Future<void> tapPtsLine(WidgetTester tester) async {
      final line = find.descendant(
        of: find.byType(SummarySection),
        matching: find.textContaining('PTS.', findRichText: true),
      );
      expect(line, findsOneWidget);
      await tester.tap(line);
      await settleShell(tester, frames: 40);
    }

    testWidgets('scrolls the sheet to the card', (tester) async {
      shortView(tester);
      final c = await open(tester);
      await show(tester, c);
      final before = titleTop(tester, _ptsTitle);
      expect(before, greaterThan(_windowHeight));

      await tapPtsLine(tester);

      // The last card cannot reach the top of a short page: on screen is enough.
      final after = titleTop(tester, _ptsTitle);
      expect(after, lessThan(_windowHeight - 40));
      expect(after, greaterThanOrEqualTo(0));
    });

    // At Saṅkhitta the summary looks a tapped DPD word up (Q11); a dictionary
    // line has a card, so it keeps its jump.
    testWidgets('at Saṅkhitta a dictionary line still jumps', (tester) async {
      // Saṅkhitta draws no DPD cards, so the page is short: a short window.
      const height = 500.0;
      tester.view.physicalSize = const Size(900, height);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = await open(tester);
      c.read(dpdSettingsProvider.notifier).setLevel(DictionaryLevel.sankhitta);
      // The panel fills the window; the sheet opens at 70% of it.
      await show(tester, c, panel: true);
      expect(titleTop(tester, _ptsTitle), greaterThan(height));

      await tapPtsLine(tester);

      final after = titleTop(tester, _ptsTitle);
      expect(after, lessThan(height - 40));
      expect(after, greaterThanOrEqualTo(0));
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        _word,
      );
    });

    testWidgets('scrolls the panel to the card', (tester) async {
      shortView(tester);
      final c = await open(tester);
      await show(tester, c, panel: true);
      // The panel's list is lazy: the card has no widget until the jump.
      expect(
        find.text(_ptsTitle, findRichText: true, skipOffstage: false),
        findsNothing,
      );

      await tapPtsLine(tester);

      final after = titleTop(tester, _ptsTitle);
      expect(after, lessThan(_windowHeight - 40));
      expect(after, greaterThanOrEqualTo(0));
    });
  });

  // A DPD line jumps to its own headword card: here the last of the fifteen
  // `dhamma` homographs, far below the window in the panel's lazy list (5C
  // review: only a dictionary line's jump was tested).
  testWidgets('a headword line scrolls the panel to its card', (tester) async {
    shortView(tester);
    final c = await makeShellContainer(
      tester,
      dbFile,
      words: ['dhamma'],
      summary: true,
    );
    await tester.pumpWidget(
      wrapShell(c, const DictionaryPanel(initialWord: 'dhamma')),
    );
    await settleShell(tester);
    final target = lines(tester)
        .where((e) => e.type == SummaryEntryType.headword)
        .last;
    final id = int.parse(target.targetId.substring('hw_'.length));
    final card = find.byWidgetPredicate(
      (w) => w is InlineEntryCard && w.headword.headword.id == id,
      skipOffstage: false,
    );
    expect(tester.getTopLeft(card).dy, greaterThan(_windowHeight));

    // The last line is `dhammā`, the arahant nun; its meaning is unique.
    expect(target.meaning, startsWith('name of an arahant nun'));
    await tester.tap(
      find.descendant(
        of: find.byType(SummarySection),
        matching: find.textContaining(
          'name of an arahant nun',
          findRichText: true,
        ),
      ),
    );
    await settleShell(tester, frames: 40);

    // The last card cannot reach the top of a short page: on screen is enough.
    final top = tester.getTopLeft(card).dy;
    expect(top, lessThan(_windowHeight - 40));
    expect(top, greaterThanOrEqualTo(0));
  });

  group('a line', () {
    // The same line at Saṅkhitta (no target, so no tap) and at the other
    // levels (a target) must wrap alike.
    Future<Size> lineSize(WidgetTester tester, String targetId) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const SizedBox());
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        wrapShell(
          container,
          SummarySection(
            entries: [
              SummaryEntry(
                type: SummaryEntryType.headword,
                label: 'dhamma',
                typeLabel: 'masc.',
                meaning:
                    'nature; character; the teaching of the Buddha; law; '
                    'rule; justice; truth; virtue; a thing; a phenomenon',
                targetId: targetId,
              ),
            ],
            onTap: (_) {},
          ),
        ),
      );
      await settleShell(tester, frames: 3);
      return tester.getSize(find.byType(Text, skipOffstage: false).at(1));
    }

    testWidgets('wraps the same with and without a tap target', (
      tester,
    ) async {
      final withTap = await lineSize(tester, 'hw_1');
      final without = await lineSize(tester, '');
      expect(without.width, withTap.width);
      expect(without.height, withTap.height);
      expect(withTap.height, greaterThan(40)); // it does wrap
    });

    testWidgets('shows the arrow only when it can be tapped', (tester) async {
      bool arrowShown() => tester
          .widget<Visibility>(
            find.ancestor(of: find.text('►'), matching: find.byType(Visibility)),
          )
          .visible;
      await lineSize(tester, '');
      expect(arrowShown(), isFalse);
      await lineSize(tester, 'hw_1');
      expect(arrowShown(), isTrue);
    });
  });

  group('the option "Show the summary"', () {
    DictionaryLevel levelOf(WidgetTester tester) => tester
        .widget<DpdResultsView>(find.byType(DpdResultsView, skipOffstage: false).first)
        .level;

    testWidgets('on: the summary shows at every level', (tester) async {
      shortView(tester);
      final c = await open(tester);
      await show(tester, c);
      for (final level in DictionaryLevel.values) {
        c.read(dpdSettingsProvider.notifier).setLevel(level);
        await settleShell(tester);
        expect(levelOf(tester), level);
        expect(
          find.byType(SummarySection, skipOffstage: false),
          findsOneWidget,
          reason: level.name,
        );
      }
    });

    testWidgets('off: gone at Majjhima and Vitthāra, kept at Saṅkhitta', (
      tester,
    ) async {
      shortView(tester);
      final c = await open(tester, summary: false);
      await show(tester, c);
      for (final level in DictionaryLevel.values) {
        c.read(dpdSettingsProvider.notifier).setLevel(level);
        await settleShell(tester);
        expect(levelOf(tester), level);
        expect(
          find.byType(SummarySection, skipOffstage: false),
          level == DictionaryLevel.sankhitta ? findsOneWidget : findsNothing,
          reason: level.name,
        );
      }
    });

    testWidgets('Saṅkhitta draws the summary and no DPD cards', (tester) async {
      shortView(tester);
      final c = await open(tester);
      c.read(dpdSettingsProvider.notifier).setLevel(DictionaryLevel.sankhitta);
      await show(tester, c);

      expect(find.byType(SummarySection), findsOneWidget);
      expect(find.text('grammar'), findsNothing);
      expect(find.byType(InlineEntryCard, skipOffstage: false), findsNothing);
    });
  });

  group('a saved list without the summary', () {
    DictionaryListItem item(String id, DictionaryItemKind kind) =>
        DictionaryListItem(id: id, label: id, kind: kind);

    test('gets it before its first DPD source', () {
      final available = [
        item(kDpdSummaryId, DictionaryItemKind.dpdSource),
        item('dpd_headwords', DictionaryItemKind.dpdSource),
        item('dpd_roots', DictionaryItemKind.dpdSource),
        item('peu', DictionaryItemKind.external),
      ];
      final merged = mergeDictionaryList(
        savedOrder: ['peu', 'dpd_roots', 'dpd_headwords'],
        disabled: {},
        available: available,
      );
      expect(merged.map((e) => e.item.id), [
        'peu',
        kDpdSummaryId,
        'dpd_roots',
        'dpd_headwords',
      ]);
    });

    test('keeps it where the user put it when it is saved', () {
      final available = [
        item(kDpdSummaryId, DictionaryItemKind.dpdSource),
        item('dpd_headwords', DictionaryItemKind.dpdSource),
        item('peu', DictionaryItemKind.external),
      ];
      final merged = mergeDictionaryList(
        savedOrder: ['dpd_headwords', 'peu', kDpdSummaryId],
        disabled: {},
        available: available,
      );
      expect(merged.map((e) => e.item.id), [
        'dpd_headwords',
        'peu',
        kDpdSummaryId,
      ]);
    });
  });
}
