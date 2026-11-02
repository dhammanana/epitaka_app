import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';

/// The three levels a book can sit at in its text's family.
enum BookLevel { mula, attha, tika }

/// The columns of one `books` row that link a book to its family.
class BookRefsRow {
  final String bookId;
  final String? category;
  final String? mulaRef;
  final String? atthaRef;
  final String? tikaRef;

  const BookRefsRow({
    required this.bookId,
    this.category,
    this.mulaRef,
    this.atthaRef,
    this.tikaRef,
  });
}

/// A book's mūla, aṭṭhakathā and ṭīkā books, in `books` table order.
class BookFamily {
  final String bookId;
  final BookLevel level;
  final Map<BookLevel, List<String>> books;

  const BookFamily({
    required this.bookId,
    required this.level,
    required this.books,
  });

  List<String> booksAt(BookLevel level) => books[level] ?? const [];
}

const _categoryLevels = {
  'Mūla': BookLevel.mula,
  'Aṭṭhakathā': BookLevel.attha,
  'Ṭīkā': BookLevel.tika,
};

List<String> _splitRefs(String? refs) =>
    (refs ?? '').split(' ').where((id) => id.isNotEmpty).toList();

/// Builds the family of every book that links to another, from all `books`
/// rows in table order.
///
/// The category gives the level, except where it would put a book on one
/// level with a book it links to: seven manuals filed as ṭīkā have a ṭīkā of
/// their own, also filed as ṭīkā, that names them as its aṭṭhakathā. Those
/// take the slot other books name them in. The slot does not win otherwise:
/// the Visuddhimagga ṭīkā names the Visuddhimagga as its mūla, but it is
/// filed, and read, as aṭṭhakathā. Some links are written on one side only,
/// so the family is every book linked in either direction.
Map<String, BookFamily> buildBookFamilies(Iterable<BookRefsRow> rows) {
  final order = <String, int>{};
  final namedLevel = <String, BookLevel>{};
  final linked = <String, Set<String>>{};
  final categoryLevel = <String, BookLevel?>{};

  for (final row in rows) {
    order[row.bookId] = order.length;
    categoryLevel[row.bookId] = _categoryLevels[row.category];
    final slots = {
      BookLevel.mula: row.mulaRef,
      BookLevel.attha: row.atthaRef,
      BookLevel.tika: row.tikaRef,
    };
    for (final MapEntry(key: level, value: refs) in slots.entries) {
      for (final other in _splitRefs(refs)) {
        namedLevel.putIfAbsent(other, () => level);
        linked.putIfAbsent(row.bookId, () => {}).add(other);
        linked.putIfAbsent(other, () => {}).add(row.bookId);
      }
    }
  }

  BookLevel? levelOf(String bookId) {
    final own = categoryLevel[bookId];
    if (own == null) return namedLevel[bookId];
    final sharesLevel = (linked[bookId] ?? const <String>{}).any(
      (other) => order.containsKey(other) && categoryLevel[other] == own,
    );
    return sharesLevel ? (namedLevel[bookId] ?? own) : own;
  }

  final families = <String, BookFamily>{};
  for (final MapEntry(key: bookId, value: others) in linked.entries) {
    final level = levelOf(bookId);
    if (level == null || !order.containsKey(bookId)) continue;
    final books = {for (final l in BookLevel.values) l: <String>[]};
    final members = [bookId, ...others.where(order.containsKey)]
      ..sort((a, b) => order[a]!.compareTo(order[b]!));
    for (final member in members) {
      final memberLevel = levelOf(member);
      if (memberLevel != null) books[memberLevel]!.add(member);
    }
    families[bookId] = BookFamily(bookId: bookId, level: level, books: books);
  }
  return families;
}

/// Every book's family, loaded once from the `books` table.
final bookFamiliesProvider = FutureProvider<Map<String, BookFamily>>((
  ref,
) async {
  final db = await ref.watch(epitakaDbProvider.future);
  final rows = await (db.select(
    db.books,
  )..orderBy([(b) => OrderingTerm.asc(b.id)])).get();
  return buildBookFamilies(
    rows.map(
      (r) => BookRefsRow(
        bookId: r.bookId,
        category: r.category,
        mulaRef: r.mulaRef,
        atthaRef: r.atthaRef,
        tikaRef: r.tikaRef,
      ),
    ),
  );
});

/// The family of [bookId], or null when the book links to no other book.
final bookFamilyProvider = FutureProvider.family<BookFamily?, String>((
  ref,
  bookId,
) async {
  final families = await ref.watch(bookFamiliesProvider.future);
  return families[bookId];
});
