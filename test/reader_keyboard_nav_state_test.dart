import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/reader/providers/reader_keyboard_bridge.dart';

void main() {
  group('ReaderKeyboardNavNotifier', () {
    test('starts disengaged and engages on focus', () {
      final n = ReaderKeyboardNavNotifier();
      expect(n.state.engaged, isFalse);

      n.focus('book1', 3, 5);
      expect(n.state.engaged, isTrue);
      expect(n.state.bookId, 'book1');
      expect(n.state.paraId, 3);
      expect(n.state.lineId, 5);
      expect(n.state.matches('book1', 3, 5), isTrue);
      expect(n.state.matches('book1', 3, 6), isFalse);
    });

    test('chip selection requires an engaged cursor', () {
      final n = ReaderKeyboardNavNotifier();
      n.selectChip(2); // not engaged — no-op
      expect(n.state.chipIndex, -1);

      n.focus('book1', 1, 1);
      n.selectChip(2);
      expect(n.state.chipIndex, 2);
      expect(n.state.engaged, isTrue);
    });

    test('disengage clears the cursor', () {
      final n = ReaderKeyboardNavNotifier();
      n.focus('book1', 1, 1);
      n.selectChip(1);
      n.disengage();
      expect(n.state.engaged, isFalse);
      expect(n.state.paraId, isNull);
      expect(n.state.chipIndex, -1);
    });

    test('clearIfDifferentBook only clears a cursor from another book', () {
      final n = ReaderKeyboardNavNotifier();
      n.focus('book1', 1, 1);
      n.clearIfDifferentBook('book1'); // same book — keep
      expect(n.state.engaged, isTrue);

      n.clearIfDifferentBook('book2'); // different book — clear
      expect(n.state.engaged, isFalse);
    });

    test('focus carries line keys; selectChip preserves them', () {
      final n = ReaderKeyboardNavNotifier();
      final keys = {11: GlobalKey(), 12: GlobalKey()};
      n.focus('book1', 1, 11, lineKeys: keys);
      expect(n.state.lineKeys, same(keys));

      // Chip selection moves no line — keys must survive.
      n.selectChip(0);
      expect(n.state.chipIndex, 0);
      expect(n.state.lineKeys, same(keys));
    });

    test('clearLineKeys drops keys, keeps the cursor state', () {
      final n = ReaderKeyboardNavNotifier();
      n.focus('book1', 1, 1, lineKeys: {1: GlobalKey()});

      n.clearLineKeys();
      expect(n.state.lineKeys, isEmpty);
      expect(n.state.engaged, isTrue);
      expect(n.state.paraId, 1);
      expect(n.state.lineId, 1);
    });

    test('clearLineKeys is a no-op when there are no keys', () {
      final n = ReaderKeyboardNavNotifier();
      n.focus('book1', 1, 1);
      n.clearLineKeys();
      expect(n.state.engaged, isTrue);
      expect(n.state.paraId, 1);
    });

    test('disengage drops the line keys with the cursor', () {
      final n = ReaderKeyboardNavNotifier();
      n.focus('book1', 1, 1, lineKeys: {1: GlobalKey()});
      n.disengage();
      expect(n.state.engaged, isFalse);
      expect(n.state.lineKeys, isEmpty);
    });

    test('focus without keys replaces stale keys from a previous step', () {
      final n = ReaderKeyboardNavNotifier();
      n.focus('book1', 1, 1, lineKeys: {1: GlobalKey()});
      // Next j/k step focuses a line in another paragraph without keys —
      // the old paragraph's keys must not linger.
      n.focus('book1', 2, 3);
      expect(n.state.lineKeys, isEmpty);
      expect(n.state.paraId, 2);
    });
  });
}
