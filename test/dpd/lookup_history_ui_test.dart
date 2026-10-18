// Back and forward over the words looked up in one sheet or panel.
// Runs on the real DPD fixture database.
library;

import 'dart:io';

import 'package:epitaka/features/dictionary/widgets/dictionary_panel.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_sheet.dart';
import 'package:epitaka/features/dpd/providers/dict_entries_provider.dart';
import 'package:epitaka/features/dpd/providers/lookup_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dpd_fixture.dart';
import 'shell_harness.dart';
import 'tap_lookup_test.dart' show fieldTextOf, pointInWord;

void main() {
  late Directory dir;
  late File dbFile;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('lookup_history_ui_test');
    dbFile = buildDpdFixture(dir);
  });

  tearDownAll(() async {
    await dir.delete(recursive: true);
  });

  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Finder backButton() => find.widgetWithIcon(IconButton, Icons.arrow_back);
  Finder forwardButton() => find.widgetWithIcon(IconButton, Icons.arrow_forward);
  bool enabled(WidgetTester tester, Finder f) =>
      tester.widget<IconButton>(f).onPressed != null;

  Future<ProviderContainer> caContainer(WidgetTester tester) async {
    final c = await makeShellContainer(
      tester,
      dbFile,
      words: ['ca', 'grammar'],
    );
    await tester.runAsync(() async {
      final key = DictEntriesKey('peu', 'ca');
      c.listen(dictEntriesProvider(key), (_, _) {});
      await c.read(dictEntriesProvider(key).future);
    });
    return c;
  }

  Future<void> tapGrammar(WidgetTester tester) async {
    await tester.tapAt(
      pointInWord(tester, 'There are two kinds of grammar', 'grammar'),
    );
    await settleShell(tester);
  }

  final peuText = find.textContaining(
    'two kinds of grammar',
    findRichText: true,
    skipOffstage: false,
  );

  group('sheet', () {
    testWidgets('a word tapped in an entry, then back, then forward', (
      tester,
    ) async {
      bigView(tester);
      final c = await caContainer(tester);
      await tester.pumpWidget(
        wrapShell(c, const DictionarySheet(initialWord: 'ca')),
      );
      await settleShell(tester);
      expect(peuText, findsWidgets);

      await tapGrammar(tester);
      expect(fieldTextOf(tester), 'grammar');
      expect(peuText, findsNothing);

      await tester.tap(backButton());
      await settleShell(tester);
      expect(fieldTextOf(tester), 'ca');
      expect(peuText, findsWidgets, reason: 'the first word\'s results again');

      await tester.tap(forwardButton());
      await settleShell(tester);
      expect(fieldTextOf(tester), 'grammar');
      expect(peuText, findsNothing);
    });

    testWidgets('both buttons are off at the start; tooltips name the word', (
      tester,
    ) async {
      bigView(tester);
      final c = await caContainer(tester);
      await tester.pumpWidget(
        wrapShell(c, const DictionarySheet(initialWord: 'ca')),
      );
      await settleShell(tester);
      expect(enabled(tester, backButton()), isFalse);
      expect(enabled(tester, forwardButton()), isFalse);

      await tapGrammar(tester);
      expect(enabled(tester, backButton()), isTrue);
      expect(enabled(tester, forwardButton()), isFalse);
      expect(find.byTooltip('← ca'), findsOneWidget);

      await tester.tap(backButton());
      await settleShell(tester);
      expect(find.byTooltip('grammar →'), findsOneWidget);
      expect(enabled(tester, backButton()), isFalse);
    });

    testWidgets('a tap above the sheet closes it, even with history to go back', (
      tester,
    ) async {
      bigView(tester);
      final c = await caContainer(tester);
      await tester.pumpWidget(
        wrapShell(
          c,
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showDictionarySheet(context, 'ca'),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('open'));
      await settleShell(tester);
      await tapGrammar(tester);
      expect(c.read(lookupHistoryProvider).canGoBack, isTrue);

      await tester.tapAt(const Offset(450, 40));
      await settleShell(tester);
      expect(find.byType(DictionarySheet), findsNothing);
      expect(
        c.read(lookupHistoryProvider).current,
        'grammar',
        reason: 'closing must not step the history',
      );
    });

    // No word, so no results: this checks the search row. An old overflow in
    // a DPD secondary card at this scale is listed in plan.md (NOTICED).
    testWidgets('the search row does not overflow at text scale 2.0', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = await makeShellContainer(tester, dbFile);
      await tester.pumpWidget(
        wrapShell(
          c,
          MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 1000),
              textScaler: TextScaler.linear(2.0),
            ),
            child: const DictionarySheet(),
          ),
        ),
      );
      await settleShell(tester);
      expect(backButton(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('shared', () {
    testWidgets('the panel goes back over words looked up in the sheet', (
      tester,
    ) async {
      bigView(tester);
      final c = await caContainer(tester);
      await tester.pumpWidget(
        wrapShell(c, const DictionarySheet(initialWord: 'ca')),
      );
      await settleShell(tester);
      await tapGrammar(tester);
      expect(fieldTextOf(tester), 'grammar');

      await tester.pumpWidget(wrapShell(c, const SizedBox()));
      await tester.pump();
      await tester.pumpWidget(wrapShell(c, const DictionaryPanel()));
      await tester.pump();

      expect(enabled(tester, backButton()), isTrue);
      await tester.tap(backButton());
      await settleShell(tester);
      expect(fieldTextOf(tester), 'ca');
    });
  });

  group('one list for the sheet and the panel', () {
    testWidgets('the panel opens on the word the sheet left, with its chips', (
      tester,
    ) async {
      bigView(tester);
      final c = await caContainer(tester);
      await tester.pumpWidget(
        wrapShell(c, const DictionarySheet(initialWord: 'ca')),
      );
      await settleShell(tester);
      await tapGrammar(tester);

      await tester.pumpWidget(wrapShell(c, const SizedBox()));
      await tester.pump();
      await tester.pumpWidget(wrapShell(c, const DictionaryPanel()));
      await settleShell(tester);

      expect(fieldTextOf(tester), 'grammar');
      expect(find.widgetWithText(ActionChip, 'ca'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'grammar'), findsOneWidget);
    });

    testWidgets('the chips run oldest to newest and mark the word on screen', (
      tester,
    ) async {
      bigView(tester);
      final c = await caContainer(tester);
      await tester.pumpWidget(
        wrapShell(c, const DictionarySheet(initialWord: 'ca')),
      );
      await settleShell(tester);
      await tapGrammar(tester);

      final ca = find.widgetWithText(ActionChip, 'ca');
      final grammar = find.widgetWithText(ActionChip, 'grammar');
      expect(
        tester.getTopLeft(ca).dx,
        lessThan(tester.getTopLeft(grammar).dx),
        reason: 'the newest word is on the right',
      );
      expect(
        tester.getRect(grammar).right,
        greaterThan(900 - 40),
        reason: 'few chips sit at the right edge, not in the middle',
      );
      Color? fill(Finder f) => tester.widget<ActionChip>(f).backgroundColor;
      expect(fill(grammar), isNot(fill(ca)));
      final grammarTint = fill(grammar);

      await tester.tap(backButton());
      await settleShell(tester);
      expect(fill(ca), grammarTint, reason: 'the tint moved to ca');
      expect(fill(grammar), isNot(grammarTint));
    });

    testWidgets('a tap on an older chip moves that word to the end, no copy', (
      tester,
    ) async {
      bigView(tester);
      final c = await caContainer(tester);
      await tester.pumpWidget(
        wrapShell(c, const DictionarySheet(initialWord: 'ca')),
      );
      await settleShell(tester);
      await tapGrammar(tester);
      expect(c.read(lookupHistoryProvider).words, ['ca', 'grammar']);

      await tester.tap(find.widgetWithText(ActionChip, 'ca'));
      await settleShell(tester);
      expect(c.read(lookupHistoryProvider).words, ['grammar', 'ca']);
      expect(fieldTextOf(tester), 'ca');
    });

    testWidgets('a suggestion tap adds the word to the history', (tester) async {
      tester.view.physicalSize = const Size(900, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = await makeShellContainer(
        tester,
        dbFile,
        words: ['kammaṃ'],
        prefixes: ['kam'],
      );
      await tester.pumpWidget(wrapShell(c, const DictionaryPanel()));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'kam');
      await settleShell(tester);
      await tester.tap(find.textContaining('kammaṃ', findRichText: true).first);
      await settleShell(tester);
      expect(c.read(lookupHistoryProvider).current, 'kammaṃ');
    });

    testWidgets('a chip tap searches the word as stored, in the sheet and the panel', (
      tester,
    ) async {
      bigView(tester);
      for (final sheet in [true, false]) {
        final c = await makeShellContainer(tester, dbFile, words: ['vacuum']);
        c.read(lookupHistoryProvider).navigateTo('vacuum');
        await tester.pumpWidget(
          wrapShell(c, sheet ? const DictionarySheet() : const DictionaryPanel()),
        );
        await settleShell(tester);
        await tester.enterText(find.byType(TextField), '');
        await settleShell(tester);

        await tester.tap(find.widgetWithText(ActionChip, 'vacuum'));
        await settleShell(tester);
        expect(fieldTextOf(tester), 'vacuum', reason: 'sheet=$sheet, not vacūm');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('the sheet and the panel draw the chips the same size', (
      tester,
    ) async {
      bigView(tester);
      final sizes = <Size>[];
      for (final sheet in [true, false]) {
        final c = await makeShellContainer(tester, dbFile, words: ['ca']);
        c.read(lookupHistoryProvider).navigateTo('ca');
        await tester.pumpWidget(
          wrapShell(c, sheet ? const DictionarySheet() : const DictionaryPanel()),
        );
        await settleShell(tester);
        sizes.add(tester.getSize(find.widgetWithText(ActionChip, 'ca')));
        await tester.pumpWidget(const SizedBox());
      }
      expect(sizes[0], sizes[1]);
    });

    testWidgets('the sheet opens on the word the panel left', (tester) async {
      bigView(tester);
      final c = await caContainer(tester);
      await tester.pumpWidget(
        wrapShell(c, const DictionaryPanel(initialWord: 'ca')),
      );
      await settleShell(tester);

      await tester.pumpWidget(wrapShell(c, const SizedBox()));
      await tester.pump();
      await tester.pumpWidget(wrapShell(c, const DictionarySheet()));
      await settleShell(tester);
      expect(fieldTextOf(tester), 'ca');
    });

    // A shell opened with no word shows the current word but must not look it
    // up again: that moved a word the user had gone back to to the end of the
    // list, and dropped the words ahead of it.
    for (final reopenPanel in [true, false]) {
      testWidgets(
        'opening the ${reopenPanel ? 'panel' : 'sheet'} after going back keeps the order',
        (tester) async {
          bigView(tester);
          final c = await caContainer(tester);
          await tester.pumpWidget(
            wrapShell(c, const DictionarySheet(initialWord: 'ca')),
          );
          await settleShell(tester);
          await tapGrammar(tester);
          await tester.tap(backButton());
          await settleShell(tester);
          expect(fieldTextOf(tester), 'ca');

          await tester.pumpWidget(wrapShell(c, const SizedBox()));
          await tester.pump();
          await tester.pumpWidget(
            wrapShell(
              c,
              reopenPanel ? const DictionaryPanel() : const DictionarySheet(),
            ),
          );
          await settleShell(tester);

          expect(fieldTextOf(tester), 'ca');
          expect(c.read(lookupHistoryProvider).words, ['ca', 'grammar']);
          expect(enabled(tester, forwardButton()), isTrue);
        },
      );
    }
  });

  group('panel', () {
    testWidgets('typed words, back, forward, and clear then back', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = await makeShellContainer(
        tester,
        dbFile,
        words: ['dhamma', 'kammaṃ'],
      );
      await tester.pumpWidget(wrapShell(c, const DictionaryPanel()));
      await tester.pump();
      expect(enabled(tester, backButton()), isFalse);

      await tester.enterText(find.byType(TextField), 'dhamma');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settleShell(tester);
      await tester.enterText(find.byType(TextField), 'kammaṃ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settleShell(tester);
      expect(enabled(tester, backButton()), isTrue);

      await tester.tap(backButton());
      await settleShell(tester);
      expect(fieldTextOf(tester), 'dhamma');
      expect(enabled(tester, forwardButton()), isTrue);

      await tester.tap(forwardButton());
      await settleShell(tester);
      expect(fieldTextOf(tester), 'kammaṃ');

      // Clearing the field moves past the end: back returns to the last word.
      await tester.enterText(find.byType(TextField), '');
      await settleShell(tester);
      expect(enabled(tester, backButton()), isTrue);
      await tester.tap(backButton());
      await settleShell(tester);
      expect(fieldTextOf(tester), 'kammaṃ');
    });
  });
}
