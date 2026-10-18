import 'dart:io';

import 'package:epitaka/core/providers/dictionary_books_provider.dart';
import 'package:epitaka/features/dpd/providers/dictionary_list_provider.dart';
import 'package:epitaka/features/dpd/providers/dpd_database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import 'dpd_fixture.dart';

DictionaryListItem item(String id, {bool? override}) => DictionaryListItem(
  id: id,
  label: id,
  kind: DictionaryItemKind.external,
  enabledOverride: override,
);

const _books = [
  DictionaryBook(id: 11, name: 'DPD', userOrder: 0, userChoice: true),
  DictionaryBook(id: 8, name: 'PEA', userOrder: 1, userChoice: true),
  DictionaryBook(id: 6, name: 'Concise', userOrder: 2, userChoice: false),
  DictionaryBook(id: 5, name: 'PTS', userOrder: 3, userChoice: false),
  DictionaryBook(id: 9, name: 'DPPN', userOrder: 4, userChoice: false),
  DictionaryBook(id: 1, name: 'Myanmar 1', userOrder: 5, userChoice: false),
  DictionaryBook(id: 100, name: 'Bold', userOrder: 8, userChoice: true),
];

void main() {
  group('mergeDictionaryList', () {
    test('keeps the saved order, adds new ids at the end, drops absent', () {
      final merged = mergeDictionaryList(
        savedOrder: ['c', 'gone', 'a'],
        disabled: {},
        available: [item('a'), item('b'), item('c')],
      );
      expect(merged.map((e) => e.item.id), ['c', 'a', 'b']);
    });

    test('a new id is on, a saved disabled id is off', () {
      final merged = mergeDictionaryList(
        savedOrder: ['a'],
        disabled: {'a'},
        available: [item('a'), item('b')],
      );
      expect(merged.map((e) => e.enabled), [false, true]);
    });

    test('an MDX dictionary reads its own flag', () {
      final merged = mergeDictionaryList(
        savedOrder: [],
        disabled: {'a'},
        available: [item('a', override: true)],
      );
      expect(merged.single.enabled, isTrue);
    });
  });

  group('lists from a fixture', () {
    late Directory dir;
    late File file;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        dictionaryListPrefsKey: '{"order":[],"disabled":[]}',
      });
      dir = await Directory.systemTemp.createTemp('dictionary_list_test');
      file = buildDpdFixture(dir);
    });

    tearDown(() async {
      await dir.delete(recursive: true);
    });

    ProviderContainer open() {
      final c = ProviderContainer(
        overrides: [
          dpdDatabaseFileProvider.overrideWith((ref) async => file),
          dictionaryBooksProvider.overrideWith((ref) async => _books),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    Future<List<DictionaryListEntry>> shown(ProviderContainer c) async {
      c.listen(dictionaryListProvider, (_, _) {});
      await c.read(dictionaryAvailableProvider.future);
      await pumpEventQueue();
      return c.read(dictionaryListProvider).requireValue;
    }

    test('lists DPD sources, then external dictionaries, then kept books',
        () async {
      final ids = (await shown(open())).map((e) => e.item.id).toList();
      expect(ids.take(kDpdSources.length), kDpdSources.map((s) => s.id));
      expect(ids, containsAll(['cone', 'cpd', 'mw', 'book_1', 'book_100']));
      expect(ids.indexOf('cone'), lessThan(ids.indexOf('book_1')));
      expect((await shown(open())).every((e) => e.enabled), isTrue);
    });

    // Valid JSON of the wrong shape throws a TypeError, not a FormatException.
    for (final bad in ['{"order":null}', '{"order":[1,2],"disabled":[]}']) {
      test('a saved list of the wrong shape falls back to the defaults: $bad',
          () async {
        SharedPreferences.setMockInitialValues({dictionaryListPrefsKey: bad});
        final ids = (await shown(open())).map((e) => e.item.id).toList();
        expect(ids.take(kDpdSources.length), kDpdSources.map((s) => s.id));
      });
    }

    test('the old DPD block and the dropped books never appear', () async {
      final ids = (await shown(open())).map((e) => e.item.id);
      for (final hidden in ['book_11', 'book_5', 'book_6', 'book_8', 'book_9']) {
        expect(ids, isNot(contains(hidden)));
      }
    });

    test('a dictionary added later shows up on, at the end; a removed one drops',
        () async {
      final first = open();
      await shown(first);
      await first
          .read(dictionaryListStoreProvider.notifier)
          .setOrder((await shown(first)).map((e) => e.item.id).toList());

      final db = sqlite3.open(file.path);
      db.execute("DELETE FROM dict_entries WHERE dict_id = 'cpd'");
      db.execute("DELETE FROM dict_meta WHERE dict_id = 'cpd'");
      db.execute(
        "INSERT INTO dict_meta (dict_id, name, author, css, entry_count) "
        "VALUES ('newdict', 'New Dict', '', '', 0)",
      );
      db.dispose();

      final second = open();
      final entries = await shown(second);
      final ids = entries.map((e) => e.item.id).toList();
      expect(ids, isNot(contains('cpd')));
      expect(ids, contains('newdict'));
      expect(entries.firstWhere((e) => e.item.id == 'newdict').enabled, isTrue);
      expect(ids.last, 'newdict');
    });

    test('order and switches survive a new container', () async {
      final first = open();
      final entries = await shown(first);
      final ids = entries.map((e) => e.item.id).toList();
      final moved = [ids.last, ...ids.take(ids.length - 1)];
      final store = first.read(dictionaryListStoreProvider.notifier);
      await store.setOrder(moved);
      await store.setEnabled(
        entries.firstWhere((e) => e.item.id == 'mw').item,
        false,
      );

      final again = await shown(open());
      expect(again.map((e) => e.item.id), moved);
      expect(
        again.where((e) => !e.enabled).map((e) => e.item.id),
        ['mw'],
      );
    });

    test('an id that is not installed keeps its place in the saved list',
        () async {
      final first = open();
      await shown(first);
      final store = first.read(dictionaryListStoreProvider.notifier);
      await store.setOrder(['cpd', 'dpd_roots']);
      await store.setOrder(['dpd_roots']);
      expect(first.read(dictionaryListStoreProvider)!.order, [
        'dpd_roots',
        'cpd',
      ]);
    });
  });

  group('migration of the old order', () {
    // Real rows of the maintainer's `dictionary_books` (this machine, 2026-10-13).
    const old = [
      DictionaryBook(id: 11, name: 'DPD', userOrder: 0, userChoice: true),
      DictionaryBook(id: 8, name: 'PEA', userOrder: 1, userChoice: true),
      DictionaryBook(id: 6, name: 'Concise', userOrder: 2, userChoice: false),
      DictionaryBook(id: 5, name: 'PTS', userOrder: 3, userChoice: false),
      DictionaryBook(id: 9, name: 'DPPN', userOrder: 4, userChoice: false),
      DictionaryBook(id: 1, name: 'M1', userOrder: 5, userChoice: false),
      DictionaryBook(id: 2, name: 'M2', userOrder: 6, userChoice: false),
      DictionaryBook(id: 3, name: 'M3', userOrder: 7, userChoice: false),
      DictionaryBook(id: 4, name: 'M4', userOrder: 8, userChoice: false),
      DictionaryBook(id: 100, name: 'Bold', userOrder: 8, userChoice: true),
      DictionaryBook(id: 31, name: 'S1', userOrder: 12, userChoice: false),
      DictionaryBook(id: 32, name: 'S2', userOrder: 13, userChoice: false),
    ];

    test('DPD becomes its sources, hidden books go, switches carry over', () {
      final m = migrateOldBookOrder(old);
      expect(m.order, [
        ...kDpdSources.map((s) => s.id),
        'book_1', 'book_2', 'book_3', 'book_4', 'book_100', 'book_31',
        'book_32',
      ]);
      expect(m.disabled, {
        'book_1', 'book_2', 'book_3', 'book_4', 'book_31', 'book_32',
      });
    });

    test('a switched-off DPD switches off all its sources', () {
      final m = migrateOldBookOrder([
        const DictionaryBook(id: 1, name: 'M1', userOrder: 0, userChoice: true),
        const DictionaryBook(id: 11, name: 'DPD', userOrder: 1, userChoice: false),
      ]);
      expect(m.order.first, 'book_1');
      expect(m.disabled, kDpdSources.map((s) => s.id).toSet());
    });

    test('a book moved above DPD stays above it', () {
      final m = migrateOldBookOrder([
        const DictionaryBook(id: 100, name: 'Bold', userOrder: 0, userChoice: true),
        const DictionaryBook(id: 11, name: 'DPD', userOrder: 1, userChoice: true),
      ]);
      expect(m.order, ['book_100', ...kDpdSources.map((s) => s.id)]);
    });

    test('the store migrates once and a second run changes nothing', () async {
      SharedPreferences.setMockInitialValues({});
      ProviderContainer open(List<DictionaryBook> books) {
        final c = ProviderContainer(
          overrides: [dictionaryBooksProvider.overrideWith((ref) async => books)],
        );
        addTearDown(c.dispose);
        return c;
      }

      final first = open(old);
      first.read(dictionaryListStoreProvider);
      await pumpEventQueue();
      final after1 = first.read(dictionaryListStoreProvider)!;
      expect(after1.order, contains('book_100'));

      final reversed = [
        for (var i = 0; i < old.length; i++)
          old[i].copyWith(userOrder: old.length - i, userChoice: true),
      ];
      final second = open(reversed);
      second.read(dictionaryListStoreProvider);
      await pumpEventQueue();
      final after2 = second.read(dictionaryListStoreProvider)!;
      expect(after2.order, after1.order);
      expect(after2.disabled, after1.disabled);
    });

    test('a failed read of the books saves nothing, so it tries again', () async {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer(
        overrides: [
          dictionaryBooksProvider.overrideWith((ref) async => throw 'no db'),
        ],
      );
      addTearDown(c.dispose);
      c.read(dictionaryListStoreProvider);
      await pumpEventQueue();
      expect(c.read(dictionaryListStoreProvider)!.order, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(dictionaryListPrefsKey), isNull);
    });
  });
}
