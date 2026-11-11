/// The dictionary icon row working on the real panel and sheet: jump to top,
/// the history list, the hidden row and the Settings item that shows it.
library;

import 'dart:io';

import 'package:epitaka/features/dictionary/providers/dictionary_header_provider.dart';
import 'package:epitaka/features/dictionary/providers/dictionary_sheet_open_provider.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_header_icons.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_panel.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_sheet.dart';
import 'package:epitaka/features/dictionary/widgets/lookup_history_list.dart';
import 'package:epitaka/shared/widgets/history_list.dart';
import 'package:epitaka/features/dpd/providers/lookup_history.dart';
import 'package:epitaka/features/settings/screens/dictionary_settings_screen.dart';
import 'package:epitaka/features/settings/widgets/settings_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          .widget<HistoryList>(find.byType(HistoryList))
          .items
          .map((i) => i.key)
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
            of: find.byKey(const ValueKey('kamma')),
            matching: find.byType(InkWell),
          )
          .first,
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

  group('history list in an empty box', () {
    testWidgets('shows with no word on screen, hides when a word is typed', (
      tester,
    ) async {
      screen(tester);
      final c = await container(tester);
      await tester.pumpWidget(wrapShell(c, const DictionaryPanel()));
      await settleShell(tester);
      // The panel opens on the current word; the user clears the box.
      await tester.enterText(find.byType(TextField).first, '');
      await settleShell(tester, frames: 3);
      expect(find.byType(LookupHistoryList), findsOneWidget);
      // Shown because the box is empty, so it has nothing to close.
      expect(
        find.descendant(
          of: find.byType(LookupHistoryList),
          matching: find.byIcon(Icons.close),
        ),
        findsNothing,
      );
      final list = tester.widget<HistoryList>(find.byType(HistoryList));
      expect(list.items.map((i) => i.key).toList(), ['dhamma', 'kamma', 'citta']);

      await tester.enterText(find.byType(TextField).first, 'k');
      await tester.pump();
      expect(find.byType(LookupHistoryList), findsNothing);
    });

    testWidgets('the trash icon removes a word and Clear empties the list', (
      tester,
    ) async {
      screen(tester);
      final c = await container(tester);
      await tester.pumpWidget(wrapShell(c, const DictionaryPanel()));
      await settleShell(tester);
      // The panel opens on the current word; the user clears the box.
      await tester.enterText(find.byType(TextField).first, '');
      await settleShell(tester, frames: 3);
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await settleShell(tester, frames: 3);
      expect(c.read(lookupHistoryProvider).words, ['citta', 'kamma']);
      await tester.tap(find.text('Clear history'));
      await settleShell(tester, frames: 3);
      expect(c.read(lookupHistoryProvider).words, isEmpty);
      expect(find.byType(LookupHistoryList), findsNothing);
    });
  });

  group('history list keys', () {
    void keyboardInput() {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
    }

    FocusNode searchNode(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField).first).focusNode!;

    Future<void> openList(WidgetTester tester, ProviderContainer c) async {
      c.read(dictionaryHistoryRequestProvider.notifier).state++;
      await settleShell(tester, frames: 3);
      expect(find.byType(LookupHistoryList), findsOneWidget);
    }

    testWidgets('Down, Down, Enter looks up the second newest word', (
      tester,
    ) async {
      keyboardInput();
      screen(tester);
      final c = await container(tester);
      await tester.pumpWidget(
        wrapShell(c, withIcons(const DictionaryPanel(initialWord: 'dhamma'))),
      );
      await settleShell(tester);
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      await openList(tester, c);

      // The box keeps the cursor; the first Down highlights the newest row
      // (dhamma, the word on screen), the second the one before it.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleShell(tester);
      expect(find.byType(LookupHistoryList), findsNothing);
      expect(fieldText(tester), 'kamma');
    });

    testWidgets('Escape closes the list and the field keeps its focus', (
      tester,
    ) async {
      keyboardInput();
      screen(tester);
      final c = await container(tester);
      await tester.pumpWidget(
        wrapShell(c, withIcons(const DictionaryPanel(initialWord: 'dhamma'))),
      );
      await settleShell(tester);
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      await openList(tester, c);
      expect(searchNode(tester).hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settleShell(tester, frames: 3);
      expect(find.byType(LookupHistoryList), findsNothing);
      expect(searchNode(tester).hasFocus, isTrue);
      expect(fieldText(tester), 'dhamma');
    });

    testWidgets('Down, Down, Up, Up leaves no highlight and typing works', (
      tester,
    ) async {
      keyboardInput();
      screen(tester);
      final c = await container(tester);
      await tester.pumpWidget(
        wrapShell(c, withIcons(const DictionaryPanel(initialWord: 'dhamma'))),
      );
      await settleShell(tester);
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      await openList(tester, c);
      int? selected() =>
          tester.widget<HistoryList>(find.byType(HistoryList)).selectedIndex;

      expect(selected(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(selected(), 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(selected(), 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(selected(), isNull);

      await tester.enterText(find.byType(TextField).first, 'k');
      await settleShell(tester, frames: 3);
      expect(find.byType(LookupHistoryList), findsNothing);
    });

    testWidgets('Down never goes past the oldest word', (tester) async {
      keyboardInput();
      screen(tester);
      final c = await container(tester);
      await tester.pumpWidget(
        wrapShell(c, withIcons(const DictionaryPanel(initialWord: 'dhamma'))),
      );
      await settleShell(tester);
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      await openList(tester, c);
      for (var i = 0; i < 8; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      }
      await tester.pump();
      final list = tester.widget<HistoryList>(find.byType(HistoryList));
      expect(list.selectedIndex, list.items.length - 1);
    });

    testWidgets('Escape closes the list in the sheet too', (tester) async {
      keyboardInput();
      screen(tester);
      final c = await container(tester);
      await tester.pumpWidget(
        wrapShell(c, const DictionarySheet(initialWord: 'dhamma')),
      );
      await settleShell(tester);
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      await openList(tester, c);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settleShell(tester, frames: 3);
      expect(find.byType(LookupHistoryList), findsNothing);
      expect(searchNode(tester).hasFocus, isTrue);
    });

    testWidgets('Down keeps going through a list longer than the window', (
      tester,
    ) async {
      keyboardInput();
      screen(tester, h: 400);
      final c = await makeShellContainer(tester, dbFile, words: ['dhamma']);
      final history = c.read(lookupHistoryProvider);
      for (var i = 0; i < 40; i++) {
        history.navigateTo('w${i.toString().padLeft(2, '0')}');
      }
      await tester.pumpWidget(
        wrapShell(c, withIcons(const DictionaryPanel(initialWord: 'dhamma'))),
      );
      await settleShell(tester);
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      await openList(tester, c);

      // Row 0 is dhamma, the word just looked up; row i is w(40 - i).
      for (var i = 0; i < 30; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump(const Duration(milliseconds: 60));
      }
      // Thirty Downs from no highlight reach row 29, which is w11.
      final list = tester.widget<HistoryList>(find.byType(HistoryList));
      expect(list.selectedIndex, 29);
      expect(list.items[29].key, 'w11');
    });

    testWidgets('a touch device keeps its focus when the list opens', (
      tester,
    ) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      screen(tester);
      final c = await container(tester);
      await tester.pumpWidget(
        wrapShell(c, withIcons(const DictionaryPanel(initialWord: 'dhamma'))),
      );
      await settleShell(tester);
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      await openList(tester, c);

      expect(searchNode(tester).hasFocus, isTrue);
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
