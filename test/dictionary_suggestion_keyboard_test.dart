// Arrow Up/Down moves through the dictionary suggestion dropdown and Enter
// accepts the highlighted row (desktop keyboard flow). Typing alone only
// fills the draft; without a highlight Enter still submits the raw text.
//
// Runs on the real DPD fixture database. `kam` has five lookup keys, in the
// DPD suggestion order: kamaṃ, kammaṃ, khamaṃ, kkamaṃ, kāmaṃ.
library;

import 'dart:io';

import 'package:epitaka/features/dictionary/widgets/dictionary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dpd/dpd_fixture.dart';
import 'dpd/shell_harness.dart';

void main() {
  late Directory dir;
  late File dbFile;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('dpd_keyboard_test');
    dbFile = buildDpdFixture(dir);
  });

  tearDownAll(() async {
    await dir.delete(recursive: true);
  });

  Future<void> pumpPanel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = await makeShellContainer(
      tester,
      dbFile,
      prefixes: ['kam'],
    );
    await tester.pumpWidget(wrapShell(container, const DictionaryPanel()));
    await tester.pump();
  }

  Future<void> typePrefix(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), 'kam');
    await settleShell(tester);
    expect(find.textContaining('kammaṃ', findRichText: true), findsOneWidget);
  }

  testWidgets('ArrowDown then Enter accepts the highlighted suggestion', (
    tester,
  ) async {
    await pumpPanel(tester);
    await typePrefix(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleShell(tester);

    expect(
      fieldText(tester),
      'kamaṃ',
      reason: 'Enter accepts the first (highlighted) suggestion',
    );
  });

  testWidgets('ArrowUp from the field wraps to the last suggestion', (
    tester,
  ) async {
    await pumpPanel(tester);
    await typePrefix(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleShell(tester);

    expect(
      fieldText(tester),
      'kāmaṃ',
      reason: 'Up with nothing highlighted jumps to the last row',
    );
  });

  testWidgets('Enter with no highlight submits the typed text', (tester) async {
    await pumpPanel(tester);
    await typePrefix(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleShell(tester);

    expect(
      fieldText(tester),
      'kam',
      reason: 'no highlight: Enter falls through to the normal submit',
    );
  });

  testWidgets('ArrowDown right after typing selects once rows arrive', (
    tester,
  ) async {
    await pumpPanel(tester);

    // Type without settling: the 300ms debounce has not fired yet, so the
    // suggestion draft is stale when the arrow arrives (the real-world
    // "type then immediately press Down" flow, no Tab needed).
    await tester.tap(find.byType(TextField));
    await tester.pump();
    tester.testTextInput.enterText('kam');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settleShell(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleShell(tester);

    expect(
      fieldText(tester),
      'kamaṃ',
      reason:
          'the flushed draft loads rows and the queued Down highlights '
          'the first one, straight from the textbox',
    );
  });
}
