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
  });
}
