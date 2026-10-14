// The suggestion box held at most 10 words and stopped at about four rows of
// height, so a word further down the list could not be reached.
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

/// Forty words, `w00` to `w39`, all starting with the typed `kam`.
final _words = [for (var i = 0; i < 40; i++) 'kam${i.toString().padLeft(2, '0')}'];

void main() {
  late Directory dir;
  late File dbFile;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('suggestion_rows_test');
    dbFile = buildDpdFixture(dir);
  });

  tearDownAll(() async {
    await dir.delete(recursive: true);
  });

  Future<ProviderContainer> container(
    WidgetTester tester, {
    List<String>? words,
  }) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    return makeShellContainer(
      tester,
      dbFile,
      overrides: [
        dpdSuggestionsProvider.overrideWith(
          (ref, prefix) async => words ?? _words,
        ),
      ],
    );
  }

  /// The tallest `Center` on the page: the empty state under the box.
  double emptyStateHeight(WidgetTester tester) => tester
      .widgetList<Center>(find.byType(Center))
      .map((w) => tester.getSize(find.byWidget(w).first).height)
      .reduce((a, b) => a > b ? a : b);

  double boxHeight(WidgetTester tester) => tester
      .getSize(
        find
            .ancestor(
              of: find.byType(SuggestionTile).first,
              matching: find.byType(ListView),
            )
            .first,
      )
      .height;

  String? selectedWord(WidgetTester tester) {
    final selected = tester
        .widgetList<SuggestionTile>(
          find.byType(SuggestionTile, skipOffstage: false),
        )
        .where((t) => t.selected);
    return selected.isEmpty ? null : selected.single.word;
  }

  Future<void> typeAndWait(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, 'kam');
    await settleShell(tester);
  }

  for (final inSheet in [false, true]) {
    final where = inSheet ? 'the sheet' : 'the panel';
    Widget host(ProviderContainer c) => wrapShell(
      c,
      inSheet ? const DictionarySheet() : const DictionaryPanel(),
    );

    testWidgets('$where fills its height with suggestions', (tester) async {
      final c = await container(tester);
      await tester.pumpWidget(host(c));
      await tester.pump();
      await typeAndWait(tester);

      // The old box stopped at 220 px (panel) or 260 px (sheet).
      expect(boxHeight(tester), greaterThan(300));
    });

    // A box sized by its content, over the whole area: a short list leaves the
    // rest of the page as it was, not a quarter of it.
    testWidgets('$where: a short list is as tall as its words', (tester) async {
      final c = await container(tester, words: ['kamaṃ', 'kammaṃ']);
      await tester.pumpWidget(host(c));
      await tester.pump();
      await typeAndWait(tester);

      expect(boxHeight(tester), lessThan(150));
      // The room under the field is 500 to 850 px; a quarter of it is 125 to
      // 215 px.
      expect(emptyStateHeight(tester), greaterThan(300));
    });

    testWidgets('$where: arrow up from the first row leaves the list at the top', (
      tester,
    ) async {
      final c = await container(tester);
      await tester.pumpWidget(host(c));
      await tester.pump();
      await typeAndWait(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settleShell(tester);
      expect(selectedWord(tester), 'kam00');
      final list = find.ancestor(
        of: find.byType(SuggestionTile).first,
        matching: find.byType(Scrollable),
      );
      double offset() =>
          tester.state<ScrollableState>(list.first).position.pixels;
      final before = offset();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settleShell(tester);

      expect(selectedWord(tester), isNull);
      expect(offset(), before);
    });

    testWidgets('$where reaches the 30th word and no further', (tester) async {
      final c = await container(tester);
      await tester.pumpWidget(host(c));
      await tester.pump();
      await typeAndWait(tester);

      // Arrow up from the field goes to the last row.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settleShell(tester);
      expect(selectedWord(tester), 'kam29');
      expect(find.text('kam30', findRichText: true, skipOffstage: false), findsNothing);

      // The row is on screen, inside the box, not only built.
      final row = tester.getRect(find.text('kam29', findRichText: true).first);
      final box = tester.getRect(
        find
            .ancestor(
              of: find.byType(SuggestionTile).first,
              matching: find.byType(ListView),
            )
            .first,
      );
      expect(row.top, greaterThanOrEqualTo(box.top - 1));
      expect(row.bottom, lessThanOrEqualTo(box.bottom + 1));
    });
  }
}
