import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_models.dart';
import 'database_provider.dart';

/// Categories in the Tipitaka hierarchy.
class BookCategory {
  final String name;
  final List<BookNikaya> nikayas;

  const BookCategory({required this.name, required this.nikayas});
}

class BookNikaya {
  final String name;
  final List<BookSubNikaya> subNikayas;

  const BookNikaya({required this.name, required this.subNikayas});
}

class BookSubNikaya {
  final String name;
  final List<BookItem> books;

  const BookSubNikaya({required this.name, required this.books});
}

class BookItem {
  final BookInfo book;
  final List<RelatedBookRef> relatedBooks;

  const BookItem({required this.book, this.relatedBooks = const []});
}

/// A reference to a related book (mūla, aṭṭha, or tīka).
class RelatedBookRef {
  final String type; // 'mūla', 'aṭṭha', or 'tīka'
  final String bookId;
  final String bookName;

  const RelatedBookRef({
    required this.type,
    required this.bookId,
    required this.bookName,
  });
}

/// Parses comma-separated book IDs and resolves them to names.
List<RelatedBookRef> _resolveRefs(
  String? refList,
  String type,
  Map<String, String> nameMap,
) {
  if (refList == null || refList.trim().isEmpty) return [];
  return refList
      .split(' ')
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .map((id) => RelatedBookRef(
            type: type,
            bookId: id,
            bookName: nameMap[id] ?? id,
          ))
      .toList();
}

/// Provider that fetches all books grouped by category → nikaya → sub-nikaya.
final booksTreeProvider = FutureProvider<List<BookCategory>>((ref) async {
  final db = await ref.watch(epitakaDbProvider.future);

  final rows = await db.select(db.books).get();

  // Build bookId → bookName map first
  final nameMap = <String, String>{};
  for (final row in rows) {
    nameMap[row.bookId] = row.bookName ?? row.bookId;
  }

  // Group by category
  final categoryMap = <String, List<BookInfo>>{};
  for (final row in rows) {
    final cat = row.category ?? 'Other';
    categoryMap.putIfAbsent(cat, () => []).add(BookInfo(
          id: row.id,
          refId: row.refId,
          vriId: row.vriId,
          bookId: row.bookId,
          category: row.category,
          nikaya: row.nikaya,
          subNikaya: row.subNikaya,
          bookName: row.bookName,
          description: row.description,
          mulaRef: row.mulaRef,
          atthaRef: row.atthaRef,
          tikaRef: row.tikaRef,
          paraId: row.paraId,
          chapterLen: row.chapterLen,
        ));
  }

  final categories = <BookCategory>[];
  // Desired category order
  const categoryOrder = ['Mūla', 'Aṭṭhakathā', 'Ṭīkā', 'Añña'];

  for (final catName in categoryOrder) {
    final books = categoryMap.remove(catName);
    if (books == null || books.isEmpty) continue;

    // Group by nikaya
    final nikayaMap = <String, List<BookInfo>>{};
    for (final book in books) {
      final nik = book.nikaya ?? 'General';
      nikayaMap.putIfAbsent(nik, () => []).add(book);
    }

    // Desired nikaya order for Tipitaka
    const nikayaOrder = [
      'Vinaya Piṭaka',
      'Sutta Piṭaka',
      'Abhidhamma Piṭaka',
    ];

    final nikayas = <BookNikaya>[];
    // Process in order, then add remaining
    final processed = <String>{};
    for (final nikName in nikayaOrder) {
      if (!nikayaMap.containsKey(nikName)) continue;
      processed.add(nikName);
      nikayas.add(_buildNikaya(nikName, nikayaMap[nikName]!, nameMap));
    }
    for (final entry in nikayaMap.entries) {
      if (processed.contains(entry.key)) continue;
      nikayas.add(_buildNikaya(entry.key, entry.value, nameMap));
    }

    categories.add(BookCategory(name: catName, nikayas: nikayas));
  }

  // Add any remaining categories
  for (final entry in categoryMap.entries) {
    final books = entry.value;
    final nikayaMap = <String, List<BookInfo>>{};
    for (final book in books) {
      final nik = book.nikaya ?? 'General';
      nikayaMap.putIfAbsent(nik, () => []).add(book);
    }
    final nikayas = nikayaMap.entries
        .map((e) => _buildNikaya(e.key, e.value, nameMap))
        .toList();
    categories.add(BookCategory(name: entry.key, nikayas: nikayas));
  }

  return categories;
});

BookNikaya _buildNikaya(
  String name,
  List<BookInfo> books,
  Map<String, String> nameMap,
) {
  // Group by sub-nikaya
  final subMap = <String, List<BookInfo>>{};
  for (final book in books) {
    final sub = book.subNikaya ?? book.nikaya ?? 'General';
    subMap.putIfAbsent(sub, () => []).add(book);
  }

  final subNikayas = subMap.entries.map((e) {
    final items = e.value.map((b) {
      final related = <RelatedBookRef>[
        ..._resolveRefs(b.mulaRef, 'mūla', nameMap),
        ..._resolveRefs(b.atthaRef, 'aṭṭha', nameMap),
        ..._resolveRefs(b.tikaRef, 'tīka', nameMap),
      ];
      return BookItem(book: b, relatedBooks: related);
    }).toList();
    return BookSubNikaya(name: e.key, books: items);
  }).toList();

  return BookNikaya(name: name, subNikayas: subNikayas);
}
