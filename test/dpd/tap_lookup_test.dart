/// A tap on a word in a dictionary other than DPD looks that word up in the
/// same sheet, as it does inside a DPD entry.
library;

import 'dart:io';

import 'package:epitaka/core/providers/dictionary_books_provider.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_search_shared.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_sheet.dart';
import 'package:epitaka/features/dpd/database/dpd_database.dart';
import 'package:epitaka/features/dpd/providers/dict_entries_provider.dart';
import 'package:epitaka/features/dpd/widgets/dict_html_card.dart';
import 'package:epitaka/features/dpd/widgets/tap_search_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'dpd_fixture.dart';
import 'shell_harness.dart';

Offset pointInWord(WidgetTester tester, String paragraphText, String word) {
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
  final at = paragraph.text.toPlainText().indexOf(word) + 1;
  final caret = paragraph.getOffsetForCaret(
    TextPosition(offset: at),
    Rect.zero,
  );
  final height = paragraph.getFullHeightForCaret(TextPosition(offset: at));
  return paragraph.localToGlobal(caret + Offset(2, height / 2));
}

String fieldTextOf(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField).first).controller!.text;

void main() {
  late Directory dir;
  late File dbFile;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('tap_lookup_test');
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

  testWidgets('an external dictionary card', (tester) async {
    bigView(tester);
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
    await tester.pumpWidget(wrapShell(c, const DictionarySheet(initialWord: 'ca')));
    await settleShell(tester);

    await tester.tapAt(
      pointInWord(tester, 'There are two kinds of grammar', 'grammar'),
    );
    await settleShell(tester);
    expect(fieldTextOf(tester), 'grammar');
  });

  testWidgets('an ePitaka book', (tester) async {
    bigView(tester);
    final c = await makeShellContainer(
      tester,
      dbFile,
      words: ['ca', 'sample'],
      overrides: [
        dictionaryBooksProvider.overrideWith(
          (ref) async => const [
            DictionaryBook(id: 1, name: 'Book', userOrder: 1, userChoice: true),
          ],
        ),
        dictionaryDefinitionProvider.overrideWith(
          (ref, key) async => [
            {'definition': '<p>the sample bookword</p>'},
          ],
        ),
      ],
    );
    await tester.pumpWidget(wrapShell(c, const DictionarySheet(initialWord: 'ca')));
    await settleShell(tester);

    await tester.tapAt(pointInWord(tester, 'the sample bookword', 'sample'));
    await settleShell(tester);
    expect(fieldTextOf(tester), 'sample');
  });

  testWidgets('a tapped English word is not turned into Velthuis', (
    tester,
  ) async {
    bigView(tester);
    final c = await makeShellContainer(
      tester,
      dbFile,
      words: ['ca', 'vacuum'],
      overrides: [
        dictionaryBooksProvider.overrideWith(
          (ref) async => const [
            DictionaryBook(id: 1, name: 'Book', userOrder: 1, userChoice: true),
          ],
        ),
        dictionaryDefinitionProvider.overrideWith(
          (ref, key) async => [
            {'definition': '<p>an empty vacuum bookword</p>'},
          ],
        ),
      ],
    );
    await tester.pumpWidget(wrapShell(c, const DictionarySheet(initialWord: 'ca')));
    await settleShell(tester);

    await tester.tapAt(pointInWord(tester, 'an empty vacuum', 'vacuum'));
    await settleShell(tester);
    expect(fieldTextOf(tester), 'vacuum', reason: 'not vacūm');
  });

  testWidgets('a sutta number keeps its dot', (tester) async {
    bigView(tester);
    final c = await makeShellContainer(tester, dbFile);
    final looked = <String>[];
    await tester.pumpWidget(
      wrapShell(
        c,
        SingleChildScrollView(
          child: TapSearchWrapper(
            onWordTap: looked.add,
            child: const Text('as in SN1.16, the sutta on the flood'),
          ),
        ),
      ),
    );
    await settleShell(tester);
    await tester.tapAt(pointInWord(tester, 'as in SN1.16', 'SN1.16'));
    await tester.pump();
    expect(looked, ['SN1.16']);
  });

  testWidgets('a link inside a card opens its tooltip and looks nothing up', (
    tester,
  ) async {
    bigView(tester);
    final c = await makeShellContainer(tester, dbFile);
    final db = sqlite3.open(dbFile.path);
    final mwHtml =
        db.select("SELECT definition_html FROM dict_entries WHERE dict_id='mw'").first.values.first as String;
    db.dispose();
    final looked = <String>[];
    await tester.pumpWidget(
      wrapShell(
        c,
        SingleChildScrollView(
          child: TapSearchWrapper(
            onWordTap: looked.add,
            child: DictHtmlCard(
              dictId: 'mw',
              entries: [
                DictEntry(
                  id: 1,
                  dictId: 'mw',
                  word: 'anugā',
                  wordFuzzy: 'anuga',
                  definitionHtml: mwHtml,
                ),
              ],
              baseStyle: const TextStyle(fontSize: 15),
            ),
          ),
        ),
      ),
    );
    await settleShell(tester, frames: 3);

    final tap = pointInWord(tester, 'RV.', 'RV.');
    await tester.tapAt(tap);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Ṛg-veda'), findsOneWidget);
    expect(looked, isEmpty);
    // The pop-up opens beside the tap: centred on it, just below it.
    final pop = tester.getRect(find.ancestor(of: find.text('Ṛg-veda'), matching: find.byType(Material)).first);
    expect((pop.center.dx - tap.dx).abs(), lessThan(60));
    expect(pop.top, greaterThan(tap.dy));
    expect(pop.top - tap.dy, lessThan(40));
    await tester.pump(const Duration(seconds: 4));
  });
}
