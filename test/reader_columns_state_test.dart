import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/core/providers/pali_definition_provider.dart';
import 'package:epitaka/features/reader/providers/reader_columns_controller.dart';
import 'package:epitaka/features/reader/providers/reader_tabs_provider.dart';
import 'package:epitaka/features/reader/services/book_family_service.dart';
import 'package:epitaka/features/reader/services/paragraph_number_index.dart';

// Rows copied from the `books` table of epitaka.db.
final _families = buildBookFamilies(const [
  BookRefsRow(
    bookId: 'A-v',
    category: 'Mūla',
    atthaRef: 'Mp-v',
    tikaRef: 'Mp-t-v',
  ),
  BookRefsRow(
    bookId: 'Vin-i',
    category: 'Mūla',
    atthaRef: 'Sp-i',
    tikaRef: 'Sp-t-i-a Sp-t-i-b Vjb-prj Vmv-i',
  ),
  BookRefsRow(
    bookId: 'Mp-v',
    category: 'Aṭṭhakathā',
    mulaRef: 'A-v',
    tikaRef: 'Mp-t-v',
  ),
  BookRefsRow(
    bookId: 'Sp-i',
    category: 'Aṭṭhakathā',
    mulaRef: 'Vin-i',
    tikaRef: 'Sp-t-i-a Sp-t-i-b Vjb-prj Vmv-i',
  ),
  BookRefsRow(
    bookId: 'Mp-t-v',
    category: 'Ṭīkā',
    mulaRef: 'A-v',
    atthaRef: 'Mp-v',
  ),
  BookRefsRow(
    bookId: 'Sp-t-i-a',
    category: 'Ṭīkā',
    mulaRef: 'Vin-i',
    atthaRef: 'Sp-i',
  ),
  BookRefsRow(
    bookId: 'Vjb-prj',
    category: 'Ṭīkā',
    mulaRef: 'Vin-i',
    atthaRef: 'Sp-i',
  ),
]);

const _an5 = ReaderTabInfo(bookId: 'A-v', bookName: 'AN5');
const _vinaya = ReaderTabInfo(bookId: 'Vin-i', bookName: 'Pārājika');

ReaderTabInfo _tab(String bookId, {int? paraId}) =>
    ReaderTabInfo(bookId: bookId, bookName: bookId, initialParaId: paraId);

ReaderTabsNotifier _open(List<ReaderTabInfo> tabs) {
  final notifier = ReaderTabsNotifier();
  for (final tab in tabs) {
    notifier.openTab(tab);
  }
  return notifier;
}

void main() {
  final an5 = _families['A-v']!;
  final vinaya = _families['Vin-i']!;

  test('a family book opens beside the source, which stays active', () {
    final notifier = _open([_an5])
      ..toggleFamilyColumn(
        _tab('Mp-v', paraId: 99),
        sourceBookId: 'A-v',
        family: an5,
      );
    final state = notifier.state;
    expect(state.columns, ['A-v', 'Mp-v']);
    expect(state.activeTab!.bookId, 'A-v');
    final attha = state.tabs.singleWhere((t) => t.bookId == 'Mp-v');
    expect(attha.initialParaId, 99);
    expect(attha.initialJumpId, isNotNull);
  });

  test('columns keep mūla, aṭṭhakathā, ṭīkā order whatever opens first', () {
    final notifier = _open([_an5])
      ..toggleFamilyColumn(_tab('Mp-t-v'), sourceBookId: 'A-v', family: an5)
      ..toggleFamilyColumn(_tab('Mp-v'), sourceBookId: 'A-v', family: an5);
    expect(notifier.state.columns, ['A-v', 'Mp-v', 'Mp-t-v']);
  });

  test('the same book again closes its tab', () {
    final notifier = _open([_an5])
      ..toggleFamilyColumn(_tab('Mp-v'), sourceBookId: 'A-v', family: an5)
      ..toggleFamilyColumn(_tab('Mp-t-v'), sourceBookId: 'A-v', family: an5)
      ..toggleFamilyColumn(_tab('Mp-v'), sourceBookId: 'A-v', family: an5);
    expect(notifier.state.columns, ['A-v', 'Mp-t-v']);
    expect(notifier.state.tabs.map((t) => t.bookId), ['A-v', 'Mp-t-v']);

    notifier.toggleFamilyColumn(
      _tab('Mp-t-v'),
      sourceBookId: 'A-v',
      family: an5,
    );
    expect(notifier.state.columns, isEmpty, reason: 'one book is no columns');
  });

  test('another book of a shown level replaces that column', () {
    final notifier = _open([_vinaya])
      ..toggleFamilyColumn(
        _tab('Sp-t-i-a'),
        sourceBookId: 'Vin-i',
        family: vinaya,
      )
      ..toggleFamilyColumn(
        _tab('Vjb-prj'),
        sourceBookId: 'Vin-i',
        family: vinaya,
      );
    expect(notifier.state.columns, ['Vin-i', 'Vjb-prj']);
    expect(notifier.state.tabs.map((t) => t.bookId), contains('Sp-t-i-a'));
  });

  test('an open tab of the target is reused, with a fresh jump', () {
    final notifier = _open([_an5, _tab('Mp-v', paraId: 5)])
      ..updateScrollOffset(1, 40, paraId: 7)
      ..switchTo(0);
    final firstJump = notifier.state.tabs[1].initialJumpId;
    notifier.toggleFamilyColumn(
      _tab('Mp-v', paraId: 99),
      sourceBookId: 'A-v',
      family: an5,
    );
    final tabs = notifier.state.tabs;
    expect(tabs.length, 2);
    expect(tabs[1].initialParaId, 99);
    expect(tabs[1].initialJumpId, isNot(firstJump));
    expect(tabs[1].currentParaId, 7);
    expect(notifier.state.activeIndex, 0);
  });

  test('a source outside the columns starts a new set', () {
    final notifier = _open([_an5, _vinaya])
      ..switchTo(0)
      ..toggleFamilyColumn(_tab('Mp-v'), sourceBookId: 'A-v', family: an5)
      ..switchTo(1)
      ..toggleFamilyColumn(_tab('Sp-i'), sourceBookId: 'Vin-i', family: vinaya);
    expect(notifier.state.columns, ['Vin-i', 'Sp-i']);
    expect(notifier.state.activeTab!.bookId, 'Vin-i');
  });

  test('the own book and books outside the family change nothing', () {
    final notifier = _open([_an5])
      ..toggleFamilyColumn(_tab('A-v'), sourceBookId: 'A-v', family: an5)
      ..toggleFamilyColumn(_tab('Sp-i'), sourceBookId: 'A-v', family: an5);
    expect(notifier.state.columns, isEmpty);
    expect(notifier.state.tabs.length, 1);
  });

  test('closing a column tab takes it out; one left clears columns', () {
    final notifier = _open([_an5])
      ..toggleFamilyColumn(_tab('Mp-v'), sourceBookId: 'A-v', family: an5)
      ..toggleFamilyColumn(_tab('Mp-t-v'), sourceBookId: 'A-v', family: an5);
    notifier.closeTab(
      notifier.state.tabs.indexWhere((t) => t.bookId == 'Mp-v'),
    );
    expect(notifier.state.columns, ['A-v', 'Mp-t-v']);
    notifier.closeTab(0);
    expect(notifier.state.columns, isEmpty);
  });

  test('closing the focused column keeps the others on screen', () {
    // A tab that is not a column sits just before the ṭīkā, where closing
    // the active tab would otherwise move focus.
    final notifier = _open([_an5])
      ..toggleFamilyColumn(_tab('Mp-v'), sourceBookId: 'A-v', family: an5)
      ..openTab(_tab('Mil'))
      ..switchTo(0)
      ..toggleFamilyColumn(_tab('Mp-t-v'), sourceBookId: 'A-v', family: an5)
      ..reorderTab(3, 2);
    expect(notifier.state.tabs.map((t) => t.bookId), [
      'A-v',
      'Mp-v',
      'Mil',
      'Mp-t-v',
    ]);
    notifier
      ..switchTo(3)
      ..closeTab(3);
    expect(notifier.state.columns, ['A-v', 'Mp-v']);
    expect(
      notifier.state.activeTab!.bookId,
      'Mp-v',
      reason: 'the reader shows columns only while one is active',
    );
  });

  test('a new family tab goes in level order, beside the columns', () {
    // The user's case: the aṭṭhakathā tab was closed, then A added it back.
    final notifier = _open([_an5, _tab('Mil')])
      ..switchTo(0)
      ..toggleFamilyColumn(_tab('Mp-t-v'), sourceBookId: 'A-v', family: an5)
      ..toggleFamilyColumn(_tab('Mp-v'), sourceBookId: 'Mp-t-v', family: an5);
    expect(notifier.state.tabs.map((t) => t.bookId), [
      'A-v',
      'Mp-v',
      'Mp-t-v',
      'Mil',
    ]);
    expect(notifier.state.columns, ['A-v', 'Mp-v', 'Mp-t-v']);
    expect(notifier.state.activeTab!.bookId, 'Mp-t-v');
  });

  test('columns follow the tab order; a new order relocks the splits', () {
    final notifier = _open([_an5])
      ..toggleFamilyColumn(_tab('Mp-v'), sourceBookId: 'A-v', family: an5)
      ..toggleFamilyColumn(_tab('Mp-t-v'), sourceBookId: 'A-v', family: an5)
      ..toggleColumnLock(0)
      ..reorderTab(2, 0);
    expect(notifier.state.tabs.map((t) => t.bookId), ['Mp-t-v', 'A-v', 'Mp-v']);
    expect(notifier.state.columns, ['Mp-t-v', 'A-v', 'Mp-v']);
    expect(notifier.state.columnLocks, isEmpty);
  });

  test('closing a tab that is not a column keeps the locks', () {
    final notifier = _open([_an5, _tab('Mil')])
      ..switchTo(0)
      ..toggleFamilyColumn(_tab('Mp-v'), sourceBookId: 'A-v', family: an5)
      ..toggleFamilyColumn(_tab('Mp-t-v'), sourceBookId: 'A-v', family: an5)
      ..toggleColumnLock(0);
    expect(notifier.state.columnLocks, [false, true]);
    notifier.closeTab(notifier.state.tabs.indexWhere((t) => t.bookId == 'Mil'));
    expect(notifier.state.columnLocks, [false, true]);
    notifier.closeTab(
      notifier.state.tabs.indexWhere((t) => t.bookId == 'Mp-t-v'),
    );
    expect(notifier.state.columnLocks, isEmpty, reason: 'the splits moved');
  });

  test('columns survive tab switches, scroll updates and reorders', () {
    final notifier = _open([_an5])
      ..toggleFamilyColumn(_tab('Mp-v'), sourceBookId: 'A-v', family: an5)
      ..switchTo(1)
      ..updateScrollOffset(0, 12, paraId: 30)
      ..clearInitialParaId(1)
      ..openTab(_tab('Mil'))
      ..reorderTab(2, 0);
    expect(notifier.state.columns, ['A-v', 'Mp-v']);
    notifier.closeAll();
    expect(notifier.state.columns, isEmpty);
  });

  group('openFamilyColumn', () {
    final an5Numbers =
        jsonDecode(
              File(
                'test/fixtures/an5_paragraph_numbers.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;

    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [
          bookFamiliesProvider.overrideWith((ref) async => _families),
          canonBookNamesProvider.overrideWith(
            (ref) async => {'Mp-v': 'Pañcakanipāta-aṭṭhakathā'},
          ),
          paragraphNumberIndexProvider.overrideWith((ref, bookId) async {
            final book = an5Numbers[bookId] as Map<String, dynamic>;
            return ParagraphNumberIndex.fromRows([
              for (final row in book['rows'] as List)
                (paraId: row[0] as int, vripara: row[1] as String?),
            ], lastParaId: book['last'] as int);
          }),
          paragraphLinksProvider.overrideWith((ref, books) async => []),
        ],
      );
      addTearDown(c.dispose);
      c.read(readerTabsProvider.notifier).openTab(_an5);
      return c;
    }

    test('AN 5.36 opens the aṭṭhakathā at its paragraph 99', () async {
      final c = container();
      await c
          .read(readerColumnsControllerProvider)
          .openFamilyColumn('Mp-v', sourceBookId: 'A-v', sourceParaId: 222);
      final state = c.read(readerTabsProvider);
      expect(state.columns, ['A-v', 'Mp-v']);
      final attha = state.tabs.singleWhere((t) => t.bookId == 'Mp-v');
      expect(attha.initialParaId, 99);
      expect(attha.bookName, 'Pañcakanipāta-aṭṭhakathā');
    });

    test('a second press while the first loads does nothing', () async {
      final c = container();
      final controller = c.read(readerColumnsControllerProvider);
      await Future.wait([
        controller.openFamilyColumn(
          'Mp-v',
          sourceBookId: 'A-v',
          sourceParaId: 222,
        ),
        controller.openFamilyColumn(
          'Mp-v',
          sourceBookId: 'A-v',
          sourceParaId: 222,
        ),
      ]);
      expect(c.read(readerTabsProvider).columns, ['A-v', 'Mp-v']);
    });

    test('the same call again closes the column', () async {
      final c = container();
      final controller = c.read(readerColumnsControllerProvider);
      await controller.openFamilyColumn(
        'Mp-v',
        sourceBookId: 'A-v',
        sourceParaId: 222,
      );
      await controller.openFamilyColumn(
        'Mp-v',
        sourceBookId: 'A-v',
        sourceParaId: 222,
      );
      expect(c.read(readerTabsProvider).columns, isEmpty);
    });
  });
}
