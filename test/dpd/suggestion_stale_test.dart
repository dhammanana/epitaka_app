// A suggestion answer that arrives after the user pressed Enter must not
// reopen the dropdown over the results.
library;

import 'dart:async';
import 'dart:io';

import 'package:epitaka/features/dictionary/widgets/dictionary_panel.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_search_shared.dart';
import 'package:epitaka/features/dpd/providers/dpd_lookup_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dpd_fixture.dart';
import 'shell_harness.dart';

void main() {
  late Directory dir;
  late File dbFile;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('suggestion_stale_test');
    dbFile = buildDpdFixture(dir);
  });

  tearDownAll(() async {
    await dir.delete(recursive: true);
  });

  testWidgets('a slow suggestion answer after Enter does not reopen the list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final slow = Completer<List<String>>();
    final container = await makeShellContainer(
      tester,
      dbFile,
      overrides: [
        dpdSuggestionsProvider.overrideWith((ref, prefix) => slow.future),
      ],
    );
    await tester.pumpWidget(wrapShell(container, const DictionaryPanel()));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'kam');
    await settleShell(tester);
    expect(find.byType(SuggestionTile), findsNothing, reason: 'still waiting');

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settleShell(tester);

    slow.complete(['kammaṃ', 'kamaṃ']);
    await settleShell(tester);
    expect(find.byType(SuggestionTile), findsNothing);
  });

  // Typing on: the answer for an older draft that arrives last must not
  // replace the list of the newer draft (5C review).
  testWidgets('a late answer for an older draft does not replace the list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final answers = {
      'kam': Completer<List<String>>(),
      'kamm': Completer<List<String>>(),
    };
    final container = await makeShellContainer(
      tester,
      dbFile,
      overrides: [
        dpdSuggestionsProvider.overrideWith(
          (ref, prefix) => answers[prefix]?.future ?? Future.value(<String>[]),
        ),
      ],
    );
    await tester.pumpWidget(wrapShell(container, const DictionaryPanel()));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'kam');
    await settleShell(tester);
    await tester.enterText(find.byType(TextField), 'kamm');
    await settleShell(tester);

    answers['kamm']!.complete(['kammaṃ']);
    await settleShell(tester);
    answers['kam']!.complete(['kamaṃ', 'kāmaṃ']);
    await settleShell(tester);

    final tiles = tester
        .widgetList<SuggestionTile>(find.byType(SuggestionTile))
        .toList();
    expect(tiles, hasLength(1));
    expect(find.textContaining('kāmaṃ', findRichText: true), findsNothing);
  });

  testWidgets('the same answer in time does show the list', (tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = await makeShellContainer(
      tester,
      dbFile,
      overrides: [
        dpdSuggestionsProvider.overrideWith(
          (ref, prefix) async => ['kammaṃ', 'kamaṃ'],
        ),
      ],
    );
    await tester.pumpWidget(wrapShell(container, const DictionaryPanel()));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'kam');
    await settleShell(tester);
    expect(find.byType(SuggestionTile), findsNWidgets(2));
  });
}
