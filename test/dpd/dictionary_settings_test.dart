import 'dart:io';

import 'package:epitaka/features/dictionary/providers/dictionary_font_scale_provider.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_sheet.dart';
import 'package:epitaka/features/dictionary/widgets/ordered_dictionary_items.dart';
import 'package:epitaka/features/dpd/providers/dictionary_list_provider.dart';
import 'package:epitaka/features/dpd/providers/dpd_database_provider.dart';
import 'package:epitaka/features/dpd/providers/dpd_lookup_provider.dart';
import 'package:epitaka/features/dpd/providers/dpd_settings_provider.dart';
import 'package:epitaka/features/dpd/widgets/dpd_results_view.dart';
import 'package:epitaka/features/dpd/widgets/dpd_status_message.dart';
import 'package:epitaka/features/dpd/widgets/inline_entry_card.dart';
import 'package:epitaka/features/dpd/widgets/tap_search_wrapper.dart';
import 'package:epitaka/features/dpd/widgets/secondary/secondary_result_cards.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_search_shared.dart';
import 'package:epitaka/features/mdx_dictionary/widgets/mdx_definition_section.dart';
import 'package:epitaka/features/settings/screens/dictionary_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dpd_fixture.dart';
import 'shell_harness.dart';

/// The widget kind, looking through the tap handler that wraps other
/// dictionaries.
Type kindOf(Widget w) => w is TapSearchWrapper ? w.child.runtimeType : w.runtimeType;

DictionaryListEntry entry(
  String id,
  DictionaryItemKind kind, {
  bool enabled = true,
  bool ready = true,
}) => DictionaryListEntry(
  DictionaryListItem(id: id, label: id, kind: kind, ready: ready),
  enabled,
);

void main() {
  late Directory dir;
  late File dbFile;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('dictionary_settings_test');
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

  group('buildOrderedDictionaryItems', () {
    late DpdLookup lookup;

    setUpAll(() async {
      // Saved settings outlive a test file when files share a process. A
      // partial or fuzzy switch left on by an earlier file makes this
      // unwatched lookup fail with "disposed during loading state".
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer(
        overrides: [dpdDatabaseFileProvider.overrideWith((ref) async => dbFile)],
      );
      lookup = await c.read(dpdLookupProvider('abba').future);
      c.dispose();
    });

    List<Widget> build(List<DictionaryListEntry> entries, {DpdLookup? l}) =>
        buildOrderedDictionaryItems(
          entries: entries,
          lookup: l ?? lookup,
          level: DictionaryLevel.majjhima,
          searchWord: 'abba',
          colors: const ColorScheme.light(),
          onWordTap: (_) {},
        );

    test('a book between two DPD sources splits them into two runs', () {
      final w = build([
        entry('dpd_headwords', DictionaryItemKind.dpdSource),
        entry('book_1', DictionaryItemKind.book),
        entry('dpd_grammar', DictionaryItemKind.dpdSource),
      ]);
      expect(w.map(kindOf), [
        DpdResultsView,
        DictDefinitionSection,
        DpdResultsView,
      ]);
      expect((w[0] as DpdResultsView).sources, ['dpd_headwords']);
      expect((w[2] as DpdResultsView).sources, ['dpd_grammar']);
    });

    test('neighbouring DPD sources share one run, in list order', () {
      final w = build([
        entry('dpd_grammar', DictionaryItemKind.dpdSource),
        entry('dpd_headwords', DictionaryItemKind.dpdSource),
      ]);
      expect(w, hasLength(1));
      expect((w.single as DpdResultsView).sources, [
        'dpd_grammar',
        'dpd_headwords',
      ]);
    });

    test('a switched-off item, and an MDX file not ready, draw nothing', () {
      final w = build([
        entry('dpd_headwords', DictionaryItemKind.dpdSource, enabled: false),
        entry('book_1', DictionaryItemKind.book, enabled: false),
        entry('mdx_a', DictionaryItemKind.mdx, ready: false),
        entry('mdx_b', DictionaryItemKind.mdx),
      ]);
      expect(w.map(kindOf), [MdxDefinitionSection]);
    });
  });

  testWidgets('the settings list reorders, toggles and the page follows', (
    tester,
  ) async {
    bigView(tester);
    final container = await makeShellContainer(
      tester,
      dbFile,
      words: ['dhamma'],
    );

    await tester.pumpWidget(wrapShell(container, const DictionarySettingsBody()));
    await settleShell(tester);

    List<String> shownOrder() => container
        .read(dictionaryListProvider)
        .requireValue
        .map((e) => e.item.id)
        .toList();
    expect(shownOrder().take(6), [
      'dpd_summary',
      'dpd_headwords',
      'dpd_roots',
      'dpd_abbreviations',
      'dpd_deconstructor',
      'dpd_grammar',
    ]);

    // Drag the "DPD Grammar" handle to the top.
    final tile = find.ancestor(
      of: find.text('DPD Grammar'),
      matching: find.byType(Row),
    ).first;
    await tester.ensureVisible(tile);
    await settleShell(tester, frames: 3);
    final rowHeight =
        tester.getTopLeft(find.text('DPD Roots')).dy -
        tester.getTopLeft(find.text('DPD Headwords')).dy;
    final handle = find.descendant(
      of: tile,
      matching: find.byIcon(Icons.drag_handle),
    );
    await tester.timedDrag(
      handle,
      Offset(0, -rowHeight * 5.4),
      const Duration(milliseconds: 600),
    );
    await settleShell(tester, frames: 8);
    expect(shownOrder().first, 'dpd_grammar');

    // Switch "DPD Roots" off.
    final rootsRow = find.ancestor(
      of: find.text('DPD Roots'),
      matching: find.byType(Row),
    ).first;
    await tester.ensureVisible(rootsRow);
    await settleShell(tester, frames: 3);
    await tester.tap(
      find.descendant(of: rootsRow, matching: find.byType(AnimatedContainer)),
    );
    await settleShell(tester, frames: 4);
    final roots = container
        .read(dictionaryListProvider)
        .requireValue
        .firstWhere((e) => e.item.id == 'dpd_roots');
    expect(roots.enabled, isFalse);

    // The lookup page now draws the grammar above the headword.
    await tester.pumpWidget(
      wrapShell(container, const DictionarySheet(initialWord: 'dhamma')),
    );
    await settleShell(tester);
    expect(
      tester.getTopLeft(find.byType(GrammarDictCard)).dy,
      lessThan(tester.getTopLeft(find.byType(InlineEntryCard).first).dy),
    );
  });

  testWidgets('a switched-off DPD source is gone from the lookup page', (
    tester,
  ) async {
    bigView(tester);
    final container = await makeShellContainer(tester, dbFile, words: ['dhamma']);
    await tester.runAsync(() async {
      await container
          .read(dictionaryListStoreProvider.notifier)
          .setEnabled(
            container
                .read(dictionaryListProvider)
                .requireValue
                .firstWhere((e) => e.item.id == 'dpd_grammar')
                .item,
            false,
          );
    });

    await tester.pumpWidget(
      wrapShell(container, const DictionarySheet(initialWord: 'dhamma')),
    );
    await settleShell(tester);
    expect(find.byType(GrammarDictCard), findsNothing);
    expect(find.byType(InlineEntryCard), findsWidgets);
  });

  testWidgets('the text size percent stays on one line at 100% and above', (
    tester,
  ) async {
    bigView(tester);
    final container = await makeShellContainer(tester, dbFile);
    await tester.pumpWidget(wrapShell(container, const DictionarySettingsBody()));
    await settleShell(tester);
    final notifier = container.read(dictionaryFontScaleProvider.notifier);
    Future<double> heightAt(double scale, String label) async {
      await notifier.setScale(scale);
      await tester.pump();
      // `.last`: an invisible copy of the widest label sits under it.
      return tester.getSize(find.text(label).last).height;
    }

    final two = await heightAt(0.95, '95%');
    final three = await heightAt(1.0, '100%');
    final high = await heightAt(1.2, '120%');
    expect(three, two);
    expect(high, two);
  });

  // The label's minimum width keeps the slider still while the percent
  // changes length ("95%" to "100%"); without it the slider jumps.
  testWidgets('the text size slider keeps its width as the percent changes', (
    tester,
  ) async {
    bigView(tester);
    final container = await makeShellContainer(tester, dbFile);
    await tester.pumpWidget(wrapShell(container, const DictionarySettingsBody()));
    await settleShell(tester);
    final notifier = container.read(dictionaryFontScaleProvider.notifier);
    Future<double> sliderWidthAt(double scale) async {
      await notifier.setScale(scale);
      await tester.pump();
      return tester.getSize(find.byType(Slider)).width;
    }

    final at95 = await sliderWidthAt(0.95);
    expect(await sliderWidthAt(1.0), at95);
    expect(await sliderWidthAt(1.2), at95);
  });

  testWidgets('the sandhi option has the DPD app\'s name', (tester) async {
    bigView(tester);
    final container = await makeShellContainer(tester, dbFile);
    await tester.pumpWidget(wrapShell(container, const DictionarySettingsBody()));
    await settleShell(tester);
    expect(find.text('Sandhi apostrophes', skipOffstage: false), findsOneWidget);
  });

  testWidgets('the settings page has no overflow at text scale 2.0', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = await makeShellContainer(tester, dbFile);

    await tester.pumpWidget(
      wrapShell(
        container,
        MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 900),
            textScaler: TextScaler.linear(2.0),
          ),
          child: const DictionarySettingsBody(),
        ),
      ),
    );
    await settleShell(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with no DPD file, one status message stands where DPD was', (
    tester,
  ) async {
    bigView(tester);
    final missing = File('${dir.path}/absent/dpd-mobile.db');
    final container = await makeShellContainer(
      tester,
      missing,
      words: ['dhamma'],
    );
    await tester.pumpWidget(
      wrapShell(container, const DictionarySheet(initialWord: 'dhamma')),
    );
    await settleShell(tester);
    expect(find.byType(DpdStatusMessage), findsOneWidget);
  });
}
