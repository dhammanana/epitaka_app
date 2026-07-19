import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/epitaka_database.dart';
import 'database_provider.dart';

/// A dictionary book with user preferences.
class DictionaryBook {
  final int id;
  final String name;
  final int userOrder;
  final bool userChoice;

  const DictionaryBook({
    required this.id,
    required this.name,
    required this.userOrder,
    required this.userChoice,
  });

  DictionaryBook copyWith({
    int? id,
    String? name,
    int? userOrder,
    bool? userChoice,
  }) {
    return DictionaryBook(
      id: id ?? this.id,
      name: name ?? this.name,
      userOrder: userOrder ?? this.userOrder,
      userChoice: userChoice ?? this.userChoice,
    );
  }
}

/// Provider that reads dictionary_books from epitaka.db.
final dictionaryBooksProvider = FutureProvider<List<DictionaryBook>>((
  ref,
) async {
  final db = await ref.watch(epitakaDbProvider.future);
  return _loadDictionaryBooks(db);
});

/// Provider that watches dictionary books and re-fetches when invalidated.
/// This allows the settings screen to update the list after changes.
final dictionaryBooksNotifierProvider =
    StateNotifierProvider<
      DictionaryBooksNotifier,
      AsyncValue<List<DictionaryBook>>
    >((ref) => DictionaryBooksNotifier(ref));

class DictionaryBooksNotifier
    extends StateNotifier<AsyncValue<List<DictionaryBook>>> {
  final Ref _ref;

  DictionaryBooksNotifier(this._ref) : super(const AsyncLoading()) {
    load();
  }

  /// Load dictionary books from the database.
  Future<void> load() async {
    state = const AsyncLoading();
    try {
      final db = await _ref.read(epitakaDbProvider.future);
      final books = await _loadDictionaryBooks(db);
      state = AsyncData(books);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Toggle a dictionary's enabled/disabled state.
  Future<void> toggleEnabled(int id, bool enabled) async {
    try {
      final db = await _ref.read(epitakaDbProvider.future);
      await db.customStatement(
        'UPDATE dictionary_books SET user_choice = ${enabled ? 1 : 0} WHERE id = $id',
      );
      await load();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Reorder dictionaries by setting user_order values.
  ///
  /// Applies an optimistic synchronous state update first so the
  /// ReorderableListView reflects the new order on the next rebuild
  /// (it needs an immediate update to avoid snapping the item back on
  /// release). The DB write then persists the change in the background;
  /// we intentionally do NOT call [load] afterwards, since that would
  /// flip state to AsyncLoading and cause a visible flicker, and the
  /// optimistic state already matches what a reload would produce.
  Future<void> reorder(List<int> orderedIds) async {
    final previous = state;
    if (previous is AsyncData<List<DictionaryBook>>) {
      final byId = {for (final b in previous.value) b.id: b};
      final reordered = <DictionaryBook>[
        for (final id in orderedIds)
          if (byId.containsKey(id)) byId[id]!,
      ];
      // Safety net: append any books not present in orderedIds.
      for (final b in previous.value) {
        if (!orderedIds.contains(b.id)) reordered.add(b);
      }
      state = AsyncData(reordered);
    }

    try {
      final db = await _ref.read(epitakaDbProvider.future);
      for (int i = 0; i < orderedIds.length; i++) {
        await db.customStatement(
          'UPDATE dictionary_books SET user_order = $i WHERE id = ${orderedIds[i]}',
        );
      }
    } catch (e) {
      // Revert to the previous state on failure.
      state = previous;
    }
  }
}

Future<List<DictionaryBook>> _loadDictionaryBooks(EpitakaDatabase db) async {
  final rows = await db
      .customSelect(
        'SELECT id, name, user_order, user_choice FROM dictionary_books ORDER BY user_order',
      )
      .get();

  return rows.map((row) {
    return DictionaryBook(
      id: row.data['id'] as int,
      name: row.data['name'] as String,
      userOrder: row.data['user_order'] as int,
      userChoice: (row.data['user_choice'] as int) == 1,
    );
  }).toList();
}
