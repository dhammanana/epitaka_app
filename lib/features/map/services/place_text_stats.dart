import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_db_provider.dart';
import '../../../core/providers/database_provider.dart';
import '../providers/map_data_provider.dart';

/// How often a name is mentioned in the Pāli text, counted by paragraph (the
/// reader's unit) and grouped by book.
class PlaceTextStats {
  const PlaceTextStats({required this.paragraphs, required this.books});

  const PlaceTextStats.empty() : paragraphs = 0, books = const [];

  final int paragraphs;
  final List<PlaceBookCount> books;

  int get bookCount => books.length;
  bool get isEmpty => books.isEmpty;
}

/// The matches of one name in one book.
class PlaceBookCount {
  const PlaceBookCount({
    required this.bookId,
    required this.name,
    required this.category,
    required this.nikaya,
    required this.paragraphs,
    required this.paraIds,
  });

  final String bookId;
  final String name;
  final String category;
  final String nikaya;
  final int paragraphs;

  /// The matching paragraph ids, earliest first.
  final List<int> paraIds;
}

/// Counts a name's inflected forms in the app's FTS index, grouped by book.
///
/// The strict (`search_fts_exact`) index is used on purpose: the forms come
/// from the gazetteer's inflection table, so a prefix match would also catch
/// unrelated words that merely start with the same letters.
final placeTextStatsProvider = FutureProvider.family<PlaceTextStats, String>((
  ref,
  slug,
) async {
  final data = await ref.watch(mapDataProvider.future);
  final name = data.nameBySlug(slug);
  if (name == null) throw StateError('Unknown name: $slug');
  if (name.forms.isEmpty) return const PlaceTextStats.empty();

  final appDb = await ref.watch(appDbProvider.future);

  // Search each form via FTS5, collecting book_id → {para_id, …}.
  final byBook = <String, Set<int>>{};
  for (final form in name.forms) {
    // A quoted phrase: FTS5 would otherwise read `-`, `:`, `*` in the form
    // as query syntax, and the exact index matches only the whole word.
    final query = '"${form.replaceAll('"', '""')}"';
    final rows = await appDb
        .customSelect(
          'SELECT m.book_id AS book_id, m.para_id AS para_id '
          'FROM search_fts_exact f '
          'JOIN search_fts_map m ON m.id = f.rowid '
          'WHERE f.pali_text MATCH ?',
          variables: [Variable.withString(query)],
        )
        .get();
    for (final row in rows) {
      final bookId = row.read<String>('book_id');
      if (bookId.isEmpty) continue;
      final paraId = row.read<int>('para_id');
      (byBook[bookId] ??= <int>{}).add(paraId);
    }
  }

  if (byBook.isEmpty) return const PlaceTextStats.empty();

  // The FTS index lives in the app database; the book table in epitaka.db.
  final epitakaDb = await ref.watch(epitakaDbProvider.future);
  final bookIds = byBook.keys.toList();
  final placeholders = List.filled(bookIds.length, '?').join(',');
  final rows = await epitakaDb
      .customSelect(
        'SELECT book_id, book_name, category, nikaya FROM books '
        'WHERE book_id IN ($placeholders)',
        variables: [for (final id in bookIds) Variable.withString(id)],
      )
      .get();

  final meta = <String, Map<String, String>>{};
  for (final row in rows) {
    meta[row.read<String>('book_id')] = {
      'name': row.readNullable<String>('book_name') ?? '',
      'category': row.readNullable<String>('category') ?? '',
      'nikaya': row.readNullable<String>('nikaya') ?? '',
    };
  }

  final books = <PlaceBookCount>[
    for (final entry in byBook.entries)
      PlaceBookCount(
        bookId: entry.key,
        name: meta[entry.key]?['name'] ?? entry.key,
        category: meta[entry.key]?['category'] ?? '',
        nikaya: meta[entry.key]?['nikaya'] ?? '',
        paragraphs: entry.value.length,
        paraIds: entry.value.toList()..sort(),
      ),
  ]..sort((a, b) => b.paragraphs.compareTo(a.paragraphs));

  final totalParagraphs = books.fold(0, (sum, b) => sum + b.paragraphs);
  return PlaceTextStats(paragraphs: totalParagraphs, books: books);
});
