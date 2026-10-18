// When DPD has no entry for the typed word, the sheet and the panel offer the
// nearest lookup keys. Runs on the real DPD fixture database.
library;

import 'dart:io';

import 'package:epitaka/features/dictionary/widgets/dictionary_panel.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_search_shared.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_sheet.dart';
import 'package:epitaka/features/dpd/providers/dpd_lookup_provider.dart';
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
    dir = await Directory.systemTemp.createTemp('closest_matches_test');
    dbFile = buildDpdFixture(dir);
  });

  tearDownAll(() async {
    await dir.delete(recursive: true);
  });

  Future<ProviderContainer> miss(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = await makeShellContainer(
      tester,
      dbFile,
      words: ['dhammx'],
    );
    await tester.runAsync(() async {
      container.listen(dpdClosestMatchesProvider('dhammx'), (_, _) {});
      await container.read(dpdClosestMatchesProvider('dhammx').future);
    });
    return container;
  }

  testWidgets('the panel offers dhamma for dhammx', (tester) async {
    final container = await miss(tester);
    await tester.pumpWidget(wrapShell(container, const DictionaryPanel()));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'dhammx');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settleShell(tester);

    expect(find.byType(SuggestionTile), findsOneWidget);
    expect(find.textContaining('dhamma', findRichText: true), findsWidgets);
  });

  testWidgets('the sheet offers dhamma for dhammx', (tester) async {
    final container = await miss(tester);
    await tester.pumpWidget(
      wrapShell(container, const DictionarySheet(initialWord: 'dhammx')),
    );
    await settleShell(tester);

    expect(find.byType(SuggestionTile, skipOffstage: false), findsOneWidget);
  });
}
