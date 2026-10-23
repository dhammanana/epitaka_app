/// The rx button in the Dictionary sheet (phone) and panel (desktop), on the
/// real DPD fixture database.
library;

import 'dart:io';

import 'package:epitaka/features/dictionary/widgets/dictionary_panel.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_sheet.dart';
import 'package:epitaka/features/dpd/providers/dpd_lookup_provider.dart';
import 'package:epitaka/features/dpd/providers/lookup_history.dart';
import 'package:epitaka/shared/utils/app_shortcuts.dart';
import 'package:epitaka/shared/widgets/search_box_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dpd/dpd_fixture.dart';
import 'dpd/shell_harness.dart';
import 'helpers/regex_hotkey.dart';
import 'helpers/type_keys.dart';

Finder get _field => find.byType(TextField).first;
Finder get _menuButton =>
    find.descendant(of: _field, matching: find.byIcon(Icons.more_vert));

Finder _rich(String text) => find.byWidgetPredicate(
  (w) => w is RichText && w.text.toPlainText().contains(text),
);

/// Loads the regex lookups inside `runAsync`, as the harness loads plain
/// ones: real file work never finishes on the fake clock.
Future<void> _preloadPatterns(
  WidgetTester tester,
  ProviderContainer container,
  List<String> patterns,
) => tester.runAsync(() async {
  for (final p in patterns) {
    container.listen(dpdRegexLookupProvider(p), (_, _) {});
    await container.read(dpdRegexLookupProvider(p).future);
  }
});

Future<void> _toggle(WidgetTester tester) async {
  await regexToggleByTapIn(tester, _field);
  await settleShell(tester);
}

Future<void> _submit(WidgetTester tester, String keys) async {
  await typeKeys(tester, _field, keys);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await settleShell(tester);
}

void main() {
  late Directory dir;
  late File dbFile;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('dictionary_regex_test');
    dbFile = buildDpdFixture(dir);
  });

  tearDownAll(() async {
    await dir.delete(recursive: true);
  });

  for (final (name, box) in [
    ('Dictionary sheet', const DictionarySheet(initialWord: '')),
    ('Dictionary panel', const DictionaryPanel()),
  ]) {
    group(name, () {
      Future<ProviderContainer> pump(
        WidgetTester tester, {
        List<String> words = const [],
        List<String> patterns = const [],
      }) async {
        tester.view.physicalSize = const Size(500, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final c = await makeShellContainer(tester, dbFile, words: words);
        await _preloadPatterns(tester, c, patterns);
        await tester.pumpWidget(wrapShell(c, box));
        await tester.pump();
        return c;
      }

      testWidgets('an empty box ends in the more menu, and X appears '
          'before it while there is text; on, rx keeps `.m`', (
        tester,
      ) async {
        await pump(tester);
        expect(_menuButton, findsOneWidget);
        // The Velthuis help and rx live in the menu now.
        await tester.tap(_menuButton);
        await settleShell(tester);
        expect(find.text('Velthuis typing'), findsOneWidget);
        expect(find.text('Regular expression'), findsOneWidget);
        await closeMoreMenu(tester);
        await settleShell(tester);

        // Off, the batch-notation dot turns into the nasal sign.
        await typeKeys(tester, _field, 'a.m');
        await settleShell(tester);
        expect(fieldText(tester), 'aṃ');
        final clear = find.byIcon(Icons.clear);
        expect(clear, findsOneWidget);
        expect(
          tester.getCenter(_menuButton).dx,
          greaterThan(tester.getCenter(clear).dx),
        );

        // On, `.m` is a pattern piece and stays as typed.
        await _toggle(tester);
        await tester.tap(find.byIcon(Icons.clear));
        await settleShell(tester);
        await typeKeys(tester, _field, 'a.m');
        await settleShell(tester);
        expect(fieldText(tester), 'a.m');
      });

      testWidgets('`^dhamma\$` lists the dhamma headwords and stays out of '
          'the lookup history', (tester) async {
        final c = await pump(tester, patterns: [r'^dhamma$']);
        await _toggle(tester);
        await _submit(tester, r'^dhamma$');

        expect(_rich('dhamma 1.01'), findsWidgets);
        expect(_rich('dhammā'), findsNothing);
        expect(c.read(lookupHistoryProvider).words, isEmpty);
      });

      testWidgets('more than 100 hits shows the count line; rx off and on '
          'runs the lookup again in each mode', (tester) async {
        // The fixture has 126 headwords; `.` matches every one.
        final c = await pump(tester, words: ['.'], patterns: ['.']);
        await _toggle(tester);
        await _submit(tester, '.');
        expect(find.text('126 matches, first 100 shown'), findsOneWidget);

        await _toggle(tester);
        expect(c.read(dictionaryRegexProvider), isFalse);
        expect(find.text('126 matches, first 100 shown'), findsNothing);

        await _toggle(tester);
        expect(find.text('126 matches, first 100 shown'), findsOneWidget);
      });

      testWidgets('a pattern that does not compile says why, at the field',
          (tester) async {
        await pump(tester);
        await _toggle(tester);
        await _submit(tester, '(');
        // The message sits at the field itself and in the results body.
        expect(
          find.descendant(
            of: _field,
            matching: find.textContaining('Invalid pattern:'),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Invalid pattern:'), findsWidgets);
        // Editing the pattern hides the field error until the next submit.
        await typeKeys(tester, _field, '(');
        await settleShell(tester);
        expect(
          find.descendant(
            of: _field,
            matching: find.textContaining('Invalid pattern:'),
          ),
          findsNothing,
        );
      });

      testWidgets('the Alt+R key, through the app bindings, turns rx on, '
          'then off', (tester) async {
        tester.view.physicalSize = const Size(500, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        AppShortcuts.overrides = const {};
        final c = await makeShellContainer(tester, dbFile);
        await tester.pumpWidget(wrapShell(c, withAppShortcuts(box)));
        await tester.pump();
        await tester.showKeyboard(_field);
        await sendAltR(tester);
        await settleShell(tester);
        expect(rxOnIn(tester, _field), isTrue);
        await sendAltR(tester);
        await settleShell(tester);
        expect(rxOnIn(tester, _field), isFalse);
      });

      testWidgets('rx on or off, by key or by tap, keeps the cursor in a box '
          'that holds a word', (tester) async {
        await pump(tester, words: ['dhamma'], patterns: ['dhamma']);
        await _submit(tester, 'dhamma');
        await tester.showKeyboard(_field);
        toggleRegexInFocusedBox();
        await settleShell(tester);
        expect(rxOnIn(tester, _field), isTrue);
        expect(fieldHasFocus(tester, _field), isTrue, reason: 'key on');
        toggleRegexInFocusedBox();
        await settleShell(tester);
        expect(fieldHasFocus(tester, _field), isTrue, reason: 'key off');
        await _toggle(tester);
        expect(rxOnIn(tester, _field), isTrue);
        expect(fieldHasFocus(tester, _field), isTrue, reason: 'tap on');
      });

      testWidgets('Enter keeps the cursor in the box, rx on or off', (
        tester,
      ) async {
        await pump(tester, words: ['dhamma'], patterns: ['dhamma']);
        await _toggle(tester);
        await tester.showKeyboard(_field);
        await _submit(tester, 'dhamma');
        expect(fieldHasFocus(tester, _field), isTrue, reason: 'rx on');
        await _toggle(tester);
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await settleShell(tester);
        expect(fieldHasFocus(tester, _field), isTrue, reason: 'rx off');
      });

      testWidgets('Alt+R in the box turns rx on, then off', (tester) async {
        await pump(tester);
        expect(rxOnIn(tester, _field), isFalse);
        await regexHotkeyIn(tester, _field);
        await settleShell(tester);
        expect(rxOnIn(tester, _field), isTrue);
        await regexHotkeyIn(tester, _field);
        await settleShell(tester);
        expect(rxOnIn(tester, _field), isFalse);
      });
    });
  }
}
