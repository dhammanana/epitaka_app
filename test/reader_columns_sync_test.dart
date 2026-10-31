/// Locked columns follow the user's scrolling to the matching paragraph.
/// Rows copied from epitaka.db around AN 5.36–42 (see the harness).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/features/reader/providers/reader_columns_controller.dart';
import 'package:epitaka/features/reader/providers/reader_keyboard_bridge.dart';
import 'package:epitaka/features/reader/providers/reader_provider.dart';
import 'package:epitaka/features/reader/providers/reader_tabs_persistence.dart';
import 'package:epitaka/features/reader/providers/reader_tabs_provider.dart';

import 'helpers/reader_columns_harness.dart';

/// Moves [bookId]'s list the way a user scroll does: straight through its
/// list controller, with no app jump around it.
Future<void> userScroll(
  WidgetTester tester,
  ProviderContainer container,
  String bookId,
  int paraId,
) async {
  final index = container
      .read(readerDataProvider(bookId))
      .paragraphs
      .indexWhere((p) => p.paraId == paraId);
  container
      .read(readerKeyboardBridgeProvider)
      .scrollControllerFor(bookId)!
      .jumpTo(index: index);
  await pumpFrames(tester, 10);
}

void main() {
  late ProviderContainer container;
  int? reading(String bookId) =>
      container.read(readerColumnsControllerProvider).readingParaId(bookId);

  Future<void> start(WidgetTester tester) async {
    container = await pumpColumns(tester);
    expect(reading('A-v'), 222);
    expect(reading('Mp-v'), 99);
    expect(reading('Mp-t-v'), 96);
  }

  testWidgets('scrolling the mūla to sutta 40 moves both commentaries', (
    tester,
  ) async {
    await start(tester);
    await userScroll(tester, container, 'A-v', 262);

    expect(reading('A-v'), 262);
    expect(reading('Mp-v'), 108, reason: 'aṭṭhakathā 40');
    expect(reading('Mp-t-v'), 102, reason: 'ṭīkā 39-40');
  });

  testWidgets('scrolling the ṭīkā moves the mūla through the chain', (
    tester,
  ) async {
    await start(tester);
    await userScroll(tester, container, 'Mp-t-v', 99);

    expect(reading('Mp-t-v'), 99);
    expect(reading('Mp-v'), 103, reason: 'aṭṭhakathā 38');
    expect(reading('A-v'), 237, reason: 'mūla 38');
  });

  testWidgets('scrolling inside one section leaves the other columns still', (
    tester,
  ) async {
    await start(tester);
    // ṭīkā 96 covers suttas 36-37 (paragraphs 96-98). Reading 97 keeps the
    // mūla on 36 and the aṭṭhakathā on 36.
    await userScroll(tester, container, 'Mp-t-v', 97);
    expect(reading('Mp-t-v'), 97);
    expect(reading('A-v'), 222);
    expect(reading('Mp-v'), 99);

    // Sutta 37 still matches ṭīkā 96, which the ṭīkā is already inside.
    await userScroll(tester, container, 'A-v', 231);
    expect(reading('Mp-v'), 101);
    expect(reading('Mp-t-v'), 97, reason: 'not pulled back to 96');
  });

  testWidgets('an unlocked split stops the pair following', (tester) async {
    await start(tester);
    await tester.tap(find.byKey(const ValueKey('column-lock-0')));
    await pumpFrames(tester, 2);
    expect(container.read(readerTabsProvider).columnLocks, [false, true]);

    await userScroll(tester, container, 'A-v', 262);
    expect(reading('Mp-v'), 99);
    expect(reading('Mp-t-v'), 96, reason: 'the chain stops at the open lock');

    await userScroll(tester, container, 'Mp-v', 108);
    expect(reading('Mp-t-v'), 102, reason: 'the other split is locked');
    expect(reading('A-v'), 262);
  });

  testWidgets('a moved column does not move the others back', (tester) async {
    await start(tester);
    await userScroll(tester, container, 'A-v', 262);
    await pumpFrames(tester, 20);
    expect(reading('A-v'), 262);
    expect(reading('Mp-v'), 108);
    expect(reading('Mp-t-v'), 102);
  });

  testWidgets('a second move before the first ends keeps its column', (
    tester,
  ) async {
    await start(tester);
    final bridge = container.read(readerKeyboardBridgeProvider);
    int indexOf(int paraId) => container
        .read(readerDataProvider('A-v'))
        .paragraphs
        .indexWhere((p) => p.paraId == paraId);
    // Sutta 39, then sutta 40 while the commentaries still travel to 39.
    bridge.scrollControllerFor('A-v')!.jumpTo(index: indexOf(250));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    bridge.scrollControllerFor('A-v')!.jumpTo(index: indexOf(262));
    await pumpFrames(tester, 20);

    expect(reading('A-v'), 262, reason: 'not pulled back to 39');
    expect(reading('Mp-v'), 108);
    expect(reading('Mp-t-v'), 102);
  });

  testWidgets('a contents jump to a sutta title moves the commentaries '
      'to that sutta', (tester) async {
    await start(tester);
    // The contents panel opens a sutta at its title line: A-v 261,
    // "10. Mahāsālaputtasuttaṃ", just before number 40 at 262.
    container
        .read(readerTabsProvider.notifier)
        .openTab(
          ReaderTabInfo(
            bookId: 'A-v',
            bookName: bookName('A-v'),
            initialParaId: 261,
          ),
        );
    await pumpFrames(tester, 20);
    expect(reading('A-v'), 261);
    expect(reading('Mp-v'), 108, reason: 'aṭṭhakathā 40, not 39');
    expect(reading('Mp-t-v'), 102, reason: 'ṭīkā 39-40');
  });

  test('locks survive a save and a restore', () {
    const state = ReaderTabsState(
      tabs: [
        ReaderTabInfo(bookId: 'A-v', bookName: 'AN5'),
        ReaderTabInfo(bookId: 'Mp-v', bookName: 'Mp'),
        ReaderTabInfo(bookId: 'Mp-t-v', bookName: 'Mpṭ'),
      ],
      columns: ['A-v', 'Mp-v', 'Mp-t-v'],
      columnLocks: [false, true],
    );
    final decoded = decodeReaderTabs(encodeReaderTabs(state))!;
    expect(decoded.columnLocks, [false, true]);
    expect(decoded.isSplitLocked(0), isFalse);
    expect(decoded.isSplitLocked(1), isTrue);
  });
}
