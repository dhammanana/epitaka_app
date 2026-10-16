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

/// Provider that reads dictionary_books from epitaka.db. Read only: the order
/// and switches the user sets live in the dictionary list's own preferences.
final dictionaryBooksProvider = FutureProvider<List<DictionaryBook>>((
  ref,
) async {
  final db = await ref.watch(epitakaDbProvider.future);
  return _loadDictionaryBooks(db);
});

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
