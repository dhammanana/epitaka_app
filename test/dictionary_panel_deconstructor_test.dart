// Regression: the desktop [DictionaryPanel] used to render only the DPD
// headwords — compound words that have a deconstructor (word breakup) but no
// direct headword showed nothing but the searched-word title. The panel must
// show the deconstructor card for them.
//
// Runs on the real DPD fixture database: `abba` has a deconstruction
// (`na + ba`) and no headword.
library;

import 'dart:io';

import 'package:epitaka/features/dictionary/widgets/dictionary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dpd/dpd_fixture.dart';
import 'dpd/shell_harness.dart';

void main() {
  late Directory dir;
  late File dbFile;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('dpd_decon_panel_test');
    dbFile = buildDpdFixture(dir);
  });

  tearDownAll(() async {
    await dir.delete(recursive: true);
  });

  testWidgets(
    'a deconstructor-only compound word shows its word breakup in the panel',
    (tester) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = await makeShellContainer(
        tester,
        dbFile,
        words: ['abba'],
      );
      await tester.pumpWidget(wrapShell(container, const DictionaryPanel()));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'abba');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settleShell(tester, frames: 12);

      // The deconstructor card names the word…
      expect(
        find.textContaining('deconstructor: abba', findRichText: true),
        findsOneWidget,
        reason: 'the desktop panel must show the deconstructor card',
      );
      // …and lists the breakup — the bug was that ONLY the title showed.
      expect(
        find.textContaining('na + ba', findRichText: true),
        findsOneWidget,
        reason: 'the deconstruction itself must be shown',
      );
    },
  );
}
