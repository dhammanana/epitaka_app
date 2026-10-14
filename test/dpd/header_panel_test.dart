/// The dictionary icon row working on the real panel and sheet: jump to top,
/// the history list, the hidden row and the Settings item that shows it.
library;

import 'dart:io';

import 'package:epitaka/features/dictionary/providers/dictionary_header_provider.dart';
import 'package:epitaka/features/dictionary/providers/dictionary_sheet_open_provider.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_header_icons.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_panel.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_search_shared.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_sheet.dart';
import 'package:epitaka/features/dictionary/widgets/lookup_history_list.dart';
import 'package:epitaka/features/dpd/providers/lookup_history.dart';
import 'package:epitaka/features/settings/screens/dictionary_settings_screen.dart';
import 'package:epitaka/features/settings/widgets/settings_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dpd_fixture.dart';
import 'shell_harness.dart';

void main() {
  late Directory dir;
  late File dbFile;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('dpd_header_panel_test');
    dbFile = buildDpdFixture(dir);
  });

  tearDownAll(() async {
    await dir.delete(recursive: true);
  });

  void screen(WidgetTester tester, {double w = 900, double h = 1000}) {
    tester.view.physicalSize = Size(w, h);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<ProviderContainer> container(WidgetTester tester) async {
    final c = await makeShellContainer(
      tester,
      dbFile,
      words: ['dhamma', 'kamma', 'citta'],
    );
    final history = c.read(lookupHistoryProvider);
    for (final w in ['citta', 'kamma', 'dhamma']) {
      history.navigateTo(w);
    }
    return c;
  }

  Widget withIcons(Widget panel) => Column(
    children: [
      const DictionaryHeaderIcons(),
      Expanded(child: panel),
    ],
  );

  ScrollableState resultsScroll(WidgetTester tester) {
    final states = tester
        .stateList<ScrollableState>(
          find.descendant(
            of: find.byType(DictionaryPanel),
            matching: find.byType(Scrollable),
          ),
        )
        .where((s) => s.position.maxScrollExtent > 0);
    expect(
      states,
      isNotEmpty,
      reason: 'the results must be taller than the window',
    );
    return states.first;
  }

  group('panel', () {
    testWidgets('the jump icon scrolls the results to the top', (tester) async {
      screen(tester, h: 300);
      final c = await container(tester);
      await tester.pumpWidget(
        wrapShell(c, withIcons(const DictionaryPanel(initialWord: 'dhamma'))),
      );
      await settleShell(tester);
      final scroll = resultsScroll(tester);
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
      expect(scroll.position.pixels, greaterThan(0));

      await tester.tap(find.byIcon(Icons.vertical_align_top));
      await settleShell(tester, frames: 3);
      expect(scroll.position.pixels, 0);
    });

    testWidgets('the history icon lists the words, newest first', (
      tester,
    ) async {
      screen(tester);
      final c = await container(tester);
      await tester.pumpWidget(
        wrapShell(c, withIcons(const DictionaryPanel(initialWord: 'dhamma'))),
      );
      await settleShell(tester);
      expect(find.byType(LookupHistoryList), findsNothing);

      await tester.tap(find.byIcon(Icons.history));
      await settleShell(tester, frames: 3);
      expect(find.byType(LookupHistoryList), findsOneWidget);
      final shown = tester
          .widgetList<SuggestionTile>(
            find.descendant(
              of: find.byType(LookupHistoryList),
              matching: find.byType(SuggestionTile),
            ),
          )
          .map((t) => t.word)
          .toList();
      expect(shown, ['dhamma', 'kamma', 'citta']);
    });

    testWidgets('a word in the list is looked up and the list closes', (
      tester,
    ) async {
      screen(tester);
      final c = await container(tester);
      await tester.pumpWidget(
        wrapShell(c, withIcons(const DictionaryPanel(initialWord: 'dhamma'))),
      );
      await settleShell(tester);
      await tester.tap(find.byIcon(Icons.history));
      await settleShell(tester, frames: 3);

      await tester.tap(
        find.descendant(
          of: find.byType(LookupHistoryList),
          matching: find.text('citta'),
        ),
      );
      await settleShell(tester);
      expect(find.byType(LookupHistoryList), findsNothing);
      expect(fieldText(tester), 'citta');
    });

    testWidgets('the close button closes the list and keeps the word', (
      tester,
    ) async {
      screen(tester);
      final c = await container(tester);
      await tester.pumpWidget(
        wrapShell(c, withIcons(const DictionaryPanel(initialWord: 'dhamma'))),
      );
      await settleShell(tester);
      await tester.tap(find.byIcon(Icons.history));
      await settleShell(tester, frames: 3);

      await tester.tap(
        find.descendant(
          of: find.byType(LookupHistoryList),
          matching: find.byIcon(Icons.close),
        ),
      );
      await settleShell(tester, frames: 3);
      expect(find.byType(LookupHistoryList), findsNothing);
      expect(fieldText(tester), 'dhamma');
    });
  });

  testWidgets('a history row shows the same hover tint as the chips', (
    tester,
  ) async {
    screen(tester);
    final c = await container(tester);
    await tester.pumpWidget(
      wrapShell(c, withIcons(const DictionaryPanel(initialWord: 'dhamma'))),
    );
    await settleShell(tester);
    await tester.tap(find.byIcon(Icons.history));
    await settleShell(tester, frames: 3);
    final row = tester.widget<InkWell>(
      find
          .descendant(
            of: find.byType(LookupHistoryList),
            matching: find.byType(InkWell),
          )
          .at(1),
    );
    final scheme = Theme.of(
      tester.element(find.byType(LookupHistoryList)),
    ).colorScheme;
    expect(row.hoverColor, scheme.onSurface.withValues(alpha: 0.08));
  });

  group('panel under a sheet and typing', () {
    testWidgets('a panel under an open sheet ignores the icon requests', (
      tester,
    ) async {
      screen(tester, h: 300);
      final c = await container(tester);
      await tester.pumpWidget(
        wrapShell(c, withIcons(const DictionaryPanel(initialWord: 'dhamma'))),
      );
      await settleShell(tester);
      final scroll = resultsScroll(tester);
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();

      c.read(dictionarySheetOpenProvider.notifier).state = 1;
      await tester.tap(find.byIcon(Icons.history));
      await tester.tap(find.byIcon(Icons.vertical_align_top));
      await settleShell(tester, frames: 3);
      expect(find.byType(LookupHistoryList), findsNothing);
      expect(scroll.position.pixels, greaterThan(0));

      c.read(dictionarySheetOpenProvider.notifier).state = 0;
      await tester.tap(find.byIcon(Icons.history));
      await settleShell(tester, frames: 3);
      expect(find.byType(LookupHistoryList), findsOneWidget);
    });

    testWidgets('typing in the field closes the history list', (tester) async {
      screen(tester);
      final c = await container(tester);
      await tester.pumpWidget(
        wrapShell(c, withIcons(const DictionaryPanel(initialWord: 'dhamma'))),
      );
      await settleShell(tester);
      await tester.tap(find.byIcon(Icons.history));
      await settleShell(tester, frames: 3);
      expect(find.byType(LookupHistoryList), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'kam');
      await settleShell(tester, frames: 3);
      expect(find.byType(LookupHistoryList), findsNothing);
    });
  });

  group('sheet', () {
    testWidgets(
      'the sheet holds the row, and the history icon opens the list',
      (tester) async {
        screen(tester);
        final c = await container(tester);
        await tester.pumpWidget(
          wrapShell(c, const DictionarySheet(initialWord: 'dhamma')),
        );
        await settleShell(tester);
        expect(find.byType(DictionaryHeaderIcons), findsOneWidget);

        await tester.tap(find.byIcon(Icons.history));
        await settleShell(tester, frames: 3);
        expect(find.byType(LookupHistoryList), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: find.byType(LookupHistoryList),
            matching: find.text('kamma'),
          ),
        );
        await settleShell(tester);
        expect(find.byType(LookupHistoryList), findsNothing);
        expect(fieldText(tester), 'kamma');
      },
    );

    testWidgets('the jump icon scrolls the sheet to the top', (tester) async {
      screen(tester, h: 500);
      final c = await container(tester);
      await tester.pumpWidget(
        wrapShell(c, const DictionarySheet(initialWord: 'dhamma')),
      );
      await settleShell(tester);
      final scrolls = tester
          .stateList<ScrollableState>(
            find.descendant(
              of: find.byType(DictionarySheet),
              matching: find.byType(Scrollable),
            ),
          )
          .where((s) => s.position.maxScrollExtent > 0);
      expect(scrolls, isNotEmpty);
      final scroll = scrolls.first;
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
      expect(scroll.position.pixels, greaterThan(0));

      await tester.tap(find.byIcon(Icons.vertical_align_top));
      await settleShell(tester, frames: 3);
      expect(scroll.position.pixels, 0);
    });

    testWidgets('a hidden row is gone from the sheet', (tester) async {
      screen(tester);
      final c = await container(tester);
      await c.read(dictionaryHeaderIconsProvider.notifier).set(false);
      await tester.pumpWidget(
        wrapShell(c, const DictionarySheet(initialWord: 'dhamma')),
      );
      await settleShell(tester);
      expect(find.byType(DictionaryHeaderIcons), findsNothing);
    });
  });

  testWidgets('the Settings item shows and hides the row', (tester) async {
    screen(tester, h: 1400);
    final c = await makeShellContainer(tester, dbFile);
    await tester.pumpWidget(wrapShell(c, const DictionarySettingsBody()));
    await settleShell(tester);
    final tile = find.text('Show the icons in the dictionary header');
    await tester.scrollUntilVisible(
      tile,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tile, findsOneWidget);
    // In the same section as the level choice, not among the other options.
    expect(
      find.descendant(
        of: find.ancestor(of: tile, matching: find.byType(SettingsSection)),
        matching: find.text('Standard'),
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(tile);
    await tester.pump();
    // The switch on the same line as the label, found again after each tap
    // because the tap replaces the widget.
    Finder toggle() {
      final labelY = tester.getCenter(tile).dy;
      final switches = find.byType(Switch).evaluate().map((e) => e.widget);
      double away(Widget w) =>
          (tester.getCenter(find.byWidget(w)).dy - labelY).abs();
      return find.byWidget(
        switches.reduce((a, b) => away(a) <= away(b) ? a : b),
      );
    }

    expect(c.read(dictionaryHeaderIconsProvider), isTrue);

    await tester.tap(toggle());
    await settleShell(tester, frames: 3);
    expect(c.read(dictionaryHeaderIconsProvider), isFalse);

    await tester.tap(toggle());
    await settleShell(tester, frames: 3);
    expect(c.read(dictionaryHeaderIconsProvider), isTrue);
  });
}
