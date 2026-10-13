/// Regression: text inside dictionary results is selectable, and the
/// selection toolbar offers a "Search '…'" action that re-looks-up the
/// selected word — the cheap alternative to per-word tappable links (which
/// were dropped for performance).
///
/// Both the mobile bottom sheet ([DictionarySheet]) and the desktop sidebar
/// panel ([DictionaryPanel]) wrap their results in a [SelectionArea] with
/// this toolbar. Double-tapping a Pāli word inside a definition must select
/// it and show `Search “word”`; tapping that re-searches the dictionary.
library;

import 'dart:io';

import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_panel.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dpd/dpd_fixture.dart';
import 'dpd/shell_harness.dart';

void main() {
  late Directory dir;
  late File dbFile;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('dpd_select_search_test');
    dbFile = buildDpdFixture(dir);
  });

  tearDownAll(() async {
    await dir.delete(recursive: true);
  });

  // The selection toolbar is how the double-tap setting looks a word up, so
  // these tests use it. (With the single-tap setting a tap searches at once.)
  Future<ProviderContainer> makeContainer(WidgetTester tester) =>
      makeShellContainer(
        tester,
        dbFile,
        words: ['dhamma', 'character'],
        // `character` has no DPD entry, so the sheet asks for suggestions.
        prefixes: ['character'],
        gesture: WordLookupGesture.doubleTap,
      );

  Widget wrap(ProviderContainer container, Widget child) =>
      wrapShell(container, child);

  /// The screen position of the character at [index] in the paragraph that
  /// draws [paragraphText], found through the render tree.
  Offset pointInParagraph(
    WidgetTester tester,
    String paragraphText,
    int index,
  ) {
    RenderParagraph? found;
    void visit(RenderObject node) {
      if (found == null &&
          node is RenderParagraph &&
          node.text.toPlainText().contains(paragraphText)) {
        found = node;
        return;
      }
      node.visitChildren(visit);
    }

    visit(tester.binding.renderViews.first);
    final paragraph = found!;
    final at = paragraph.text.toPlainText().indexOf(paragraphText) + index;
    final caret = paragraph.getOffsetForCaret(
      TextPosition(offset: at),
      Rect.zero,
    );
    final height = paragraph.getFullHeightForCaret(TextPosition(offset: at));
    return paragraph.localToGlobal(caret + Offset(2, height / 2));
  }

  /// Two taps ~90ms apart, the second held past kPressTimeout — the same
  /// gesture sequence SelectionArea needs to land its word selection.
  Future<void> doubleTapAt(WidgetTester tester, Offset pos) async {
    final g1 = await tester.startGesture(pos);
    await tester.pump();
    await g1.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final g2 = await tester.startGesture(pos);
    await tester.pump(const Duration(milliseconds: 150));
    await g2.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('dictionary sheet: double-tap selects a word and Search '
      're-looks it up', (tester) async {
    // Wide enough that the selection toolbar's three buttons (Search / Copy /
    // Select All) fit without overflowing into the "…" menu. Still mobile
    // (the test platform is Android, so isDesktop is false) — the sheet
    // renders as the bottom sheet either way.
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = await makeContainer(tester);
    await tester.pumpWidget(
      wrap(container, const DictionarySheet(initialWord: 'dhamma')),
    );
    await tester.pumpAndSettle();

    // The summary line "nature; character" holds a word to select.
    final target = pointInParagraph(tester, 'nature; character', 12);

    // Double-tap the word "character" inside the entry.
    await doubleTapAt(tester, target);
    await tester.pumpAndSettle();

    // The selection toolbar offers the Search action + Copy + Select All.
    expect(find.text('Search “character”'), findsOneWidget,
        reason: 'toolbar lets the user re-search the selected word');
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Select All'), findsOneWidget);

    // Tapping Search re-runs the dictionary lookup for the selected word.
    await tester.tap(find.text('Search “character”'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'character',
        reason: 'the search field now holds the selected word');
  });

  testWidgets('dictionary panel: Search toolbar re-looks up the selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = await makeContainer(tester);
    await tester.pumpWidget(
      wrap(
        container,
        const SizedBox(
          width: 400,
          height: 600,
          child: DictionaryPanel(initialWord: 'dhamma'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final target = pointInParagraph(tester, 'nature; character', 12);

    await doubleTapAt(tester, target);
    await tester.pumpAndSettle();

    expect(find.text('Search “character”'), findsOneWidget);

    await tester.tap(find.text('Search “character”'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'character',
        reason: 'the panel search field now holds the selected word');
  });
}
