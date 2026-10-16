// Enter in the search field on a word that was not typed (a chip, a tap, the
// reader) must keep the word: Velthuis would turn its real `aa` into a macron.
library;

import 'dart:io';

import 'package:epitaka/features/dictionary/widgets/dictionary_panel.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_sheet.dart';
import 'package:epitaka/features/dpd/providers/lookup_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dpd_fixture.dart';
import 'shell_harness.dart';

const _word = 'dhammaabhiñño';

void main() {
  late Directory dir;
  late File dbFile;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('shown_word_submit_test');
    dbFile = buildDpdFixture(dir);
  });

  tearDownAll(() async {
    await dir.delete(recursive: true);
  });

  Future<ProviderContainer> container(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    return makeShellContainer(tester, dbFile);
  }

  Future<void> pressEnter(WidgetTester tester) async {
    // Focus the field without changing its text, as a key press on it would.
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settleShell(tester);
  }

  testWidgets('the panel keeps a shown word with a double vowel', (
    tester,
  ) async {
    final c = await container(tester);
    await tester.pumpWidget(
      wrapShell(c, const DictionaryPanel(initialWord: _word)),
    );
    await settleShell(tester);
    await pressEnter(tester);
    expect(c.read(lookupHistoryProvider).current, _word);
  });

  testWidgets('the sheet keeps a shown word with a double vowel', (
    tester,
  ) async {
    final c = await container(tester);
    await tester.pumpWidget(
      wrapShell(c, const DictionarySheet(initialWord: _word)),
    );
    await settleShell(tester);
    await pressEnter(tester);
    expect(c.read(lookupHistoryProvider).current, _word);
  });

  testWidgets('typed text still goes through Velthuis', (tester) async {
    final c = await container(tester);
    await tester.pumpWidget(wrapShell(c, const DictionaryPanel()));
    await settleShell(tester);
    await tester.enterText(find.byType(TextField), 'kaaya');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settleShell(tester);
    expect(c.read(lookupHistoryProvider).current, 'kāya');
  });
}
