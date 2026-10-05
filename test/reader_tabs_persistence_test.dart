import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:epitaka/features/reader/providers/reader_tabs_persistence.dart';
import 'package:epitaka/features/reader/providers/reader_tabs_provider.dart';

void main() {
  group('encode/decode', () {
    test('round trip keeps three tabs, their order, places and active index',
        () {
      const state = ReaderTabsState(
        activeIndex: 1,
        tabs: [
          ReaderTabInfo(
            bookId: 'mula_di_01',
            bookName: 'Sīlakkhandhavagga',
            bookDescription: 'Dīgha 1',
            currentParaId: 120,
            currentLineId: 4,
            scrollOffset: 37.25,
          ),
          ReaderTabInfo(
            bookId: 'mula_ma_01',
            bookName: 'Mūlapaṇṇāsa',
            currentParaId: 9,
            scrollOffset: 3.5,
          ),
          ReaderTabInfo(
            bookId: 'mula_sa_01',
            bookName: 'Sagāthāvagga',
            currentParaId: 1,
            currentLineId: 2,
            scrollOffset: 0,
          ),
        ],
      );

      final decoded = decodeReaderTabs(encodeReaderTabs(state))!;

      expect(decoded.activeIndex, 1);
      expect(decoded.tabs.map((t) => t.bookId),
          ['mula_di_01', 'mula_ma_01', 'mula_sa_01']);
      final first = decoded.tabs[0];
      expect(first.bookName, 'Sīlakkhandhavagga');
      expect(first.bookDescription, 'Dīgha 1');
      expect(first.currentParaId, 120);
      expect(first.currentLineId, 4);
      expect(first.scrollOffset, 37.25);
      expect(decoded.tabs[1].currentLineId, isNull);
      expect(decoded.tabs[2].scrollOffset, 0.0);
    });

    test('a tab with no saved place decodes with null positions', () {
      const state = ReaderTabsState(
        tabs: [ReaderTabInfo(bookId: 'mula_di_01', bookName: 'DN 1')],
      );

      final tab = decodeReaderTabs(encodeReaderTabs(state))!.tabs.single;

      expect(tab.currentParaId, isNull);
      expect(tab.currentLineId, isNull);
      expect(tab.scrollOffset, isNull);
      expect(tab.initialParaId, isNull);
    });

    test('corrupt or wrong-shaped data gives null and does not throw', () {
      expect(decodeReaderTabs('not json'), isNull);
      expect(decodeReaderTabs('[1, 2]'), isNull);
      expect(decodeReaderTabs('{"active": 0, "tabs": [{"bookId": 5}]}'),
          isNull);
    });

    test('an out-of-range active index is clamped', () {
      final decoded = decodeReaderTabs(
          '{"active": 7, "tabs": [{"bookId": "a", "bookName": "A"}]}')!;

      expect(decoded.activeIndex, 0);
    });
  });

  group('saving', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('a tab change made through the listener lands in prefs', () {
      final notifier = ReaderTabsNotifier();
      notifier.addListener((s) => saveReaderTabs(prefs, s),
          fireImmediately: false);

      notifier.openTab(
          const ReaderTabInfo(bookId: 'mula_di_01', bookName: 'DN 1'));

      final saved = loadSavedReaderTabs(prefs);
      expect(saved, isNotNull);
      expect(saved!.tabs.single.bookId, 'mula_di_01');
      notifier.dispose();
    });

    test('closing every tab saves an empty list', () {
      final notifier = ReaderTabsNotifier();
      notifier.addListener((s) => saveReaderTabs(prefs, s),
          fireImmediately: false);

      notifier.openTab(
          const ReaderTabInfo(bookId: 'mula_di_01', bookName: 'DN 1'));
      notifier.closeTab(0);

      final saved = loadSavedReaderTabs(prefs);
      expect(saved, isNotNull);
      expect(saved!.tabs, isEmpty);
      notifier.dispose();
    });

    test('nothing saved loads as null', () {
      expect(loadSavedReaderTabs(prefs), isNull);
    });
  });
}
