// Tapping a suggestion fills the search field with that word.
//
// The suggestion list used to show DPD headwords, whose homograph number
// ("añña 1.1") had to be stripped on tap. It now lists lookup keys, which
// carry no number, so the word is filled as shown.
//
// Runs on the real DPD fixture database: `kam` has five lookup keys.
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
    dir = await Directory.systemTemp.createTemp('dpd_suggestion_tap_test');
    dbFile = buildDpdFixture(dir);
  });

  tearDownAll(() async {
    await dir.delete(recursive: true);
  });

  testWidgets('tapping a suggestion fills the field with that word', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = await makeShellContainer(
      tester,
      dbFile,
      words: ['kammaṃ'],
      prefixes: ['kam'],
    );
    await tester.pumpWidget(wrapShell(container, const DictionaryPanel()));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'kam');
    await settleShell(tester);

    // The suggestions show the diacritic forms the user did not type.
    // (findRichText: tiles render the word as highlighted RichText, so a
    // plain find.text does not match the split spans.)
    expect(find.textContaining('kammaṃ', findRichText: true), findsOneWidget);
    expect(find.textContaining('kāmaṃ', findRichText: true), findsOneWidget);

    await tester.tap(find.textContaining('kammaṃ', findRichText: true));
    await settleShell(tester);

    expect(fieldText(tester), 'kammaṃ');
  });
}
