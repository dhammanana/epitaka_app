import 'package:drift/drift.dart';

import '../../../core/database/epitaka_database.dart';

/// Result from looking up a connected book's heading match.
class ConnectedBookJump {
  final String bookId;
  final String bookName;
  final int paraId;
  final String title;

  const ConnectedBookJump({
    required this.bookId,
    required this.bookName,
    required this.paraId,
    required this.title,
  });
}

/// A linked book reference parsed from `mula_ref`, `attha_ref`, `tika_ref`.
class LinkedBookRef {
  final String type; // 'mula', 'attha', 'tika'
  final String bookId;

  const LinkedBookRef({required this.type, required this.bookId});
}

/// Service for the Jump-to-connected-book and Jump-to-page features.
class JumpService {
  final EpitakaDatabase _db;

  JumpService(this._db);

  /// Get the linked books (mula/attha/tika) for [bookId] from the `books` table.
  Future<List<LinkedBookRef>> getLinkedBooks(String bookId) async {
    final rows = await _db.customSelect(
      'SELECT mula_ref, attha_ref, tika_ref FROM books WHERE book_id = ? LIMIT 1',
      variables: [Variable.withString(bookId)],
    ).get();

    if (rows.isEmpty) return [];

    final row = rows.first.data;
    final result = <LinkedBookRef>[];

    void addRefs(String column, String type) {
      final raw = row[column] as String?;
      if (raw == null || raw.trim().isEmpty) return;
      for (final id in raw.split(RegExp(r'\s+'))) {
        final trimmed = id.trim();
        if (trimmed.isNotEmpty) {
          result.add(LinkedBookRef(type: type, bookId: trimmed));
        }
      }
    }

    addRefs('mula_ref', 'mula');
    addRefs('attha_ref', 'attha');
    addRefs('tika_ref', 'tika');

    return result;
  }

  /// Find the heading with `level = 10` at or before [paraId] in [bookId].
  /// Returns the heading title parsed as a number (section/chapter number).
  int? getSectionNumber(String bookId, int paraId) async {
    final rows = await _db.customSelect(
      'SELECT title FROM headings '
      'WHERE book_id = ? AND para_id <= ? AND level = 10 '
      'ORDER BY para_id DESC LIMIT 1',
      variables: [
        Variable.withString(bookId),
        Variable.withInt(paraId),
      ],
    ).get();

    if (rows.isEmpty) return null;
    final title = rows.first.data['title'] as String?;
    if (title == null) return null;
    return int.tryParse(title.trim());
  }

  /// Find the best matching heading in [linkedBookId] for [sectionNumber].
  /// Tries exact match first, then the nearest less-than match.
  Future<ConnectedBookJump?> findHeadingInBook(
    String linkedBookId,
    int sectionNumber,
  ) async {
    // First try exact match: heading whose title == sectionNumber
    final exactRows = await _db.customSelect(
      'SELECT h.para_id, h.title, b.book_name '
      'FROM headings h '
      'JOIN books b ON b.book_id = h.book_id '
      'WHERE h.book_id = ? AND h.title = ? AND h.level = 10 '
      'ORDER BY h.para_id ASC LIMIT 1',
      variables: [
        Variable.withString(linkedBookId),
        Variable.withString(sectionNumber.toString()),
      ],
    ).get();

    if (exactRows.isNotEmpty) {
      final r = exactRows.first.data;
      return ConnectedBookJump(
        bookId: linkedBookId,
        bookName: r['book_name'] as String? ?? linkedBookId,
        paraId: r['para_id'] as int,
        title: r['title'] as String? ?? '',
      );
    }

    // Try to find the nearest heading with level=10 whose title (as int)
    // is less than sectionNumber, using SQL with ordering.
    // We'll fetch all level=10 headings and compare in Dart since SQL
    // comparison of string titles as integers is tricky.
    final allRows = await _db.customSelect(
      'SELECT h.para_id, h.title, b.book_name '
      'FROM headings h '
      'JOIN books b ON b.book_id = h.book_id '
      'WHERE h.book_id = ? AND h.level = 10 '
      'ORDER BY h.para_id ASC',
      variables: [Variable.withString(linkedBookId)],
    ).get();

    ConnectedBookJump? best;
    for (final row in allRows) {
      final r = row.data;
      final title = r['title'] as String?;
      if (title == null) continue;
      final numTitle = int.tryParse(title.trim());
      if (numTitle == null) continue;
      if (numTitle <= sectionNumber) {
        best = ConnectedBookJump(
          bookId: linkedBookId,
          bookName: r['book_name'] as String? ?? linkedBookId,
          paraId: r['para_id'] as int,
          title: title,
        );
      } else {
        break; // Titles are ordered ascending
      }
    }

    return best;
  }

  /// Get all connected books with their heading matches for [bookId] at [paraId].
  Future<List<ConnectedBookJump>> getConnectedJumps(
    String bookId,
    int paraId,
  ) async {
    final linkedBooks = await getLinkedBooks(bookId);
    if (linkedBooks.isEmpty) return [];

    final sectionNumber = await getSectionNumber(bookId, paraId);
    if (sectionNumber == null) return [];

    final results = <ConnectedBookJump>[];
    for (final link in linkedBooks) {
      final match = await findHeadingInBook(link.bookId, sectionNumber);
      if (match != null) {
        results.add(match);
      }
    }

    return results;
  }

  /// Parse the page number prefix for a book.
  /// Some books have pages like "1.3", "1.10" where the first number is
  /// constant for the whole book. This returns the prefix (e.g. "1.") or null.
  Future<String?> getPagePrefix(String bookId, String column) async {
    final rows = await _db.customSelect(
      'SELECT $column FROM sentences '
      'WHERE book_id = ? AND $column IS NOT NULL AND $column != \'\' '
      'ORDER BY para_id ASC, line_id ASC LIMIT 5',
      variables: [Variable.withString(bookId)],
    ).get();

    for (final row in rows) {
      final value = row.data[column] as String?;
      if (value == null) continue;
      final dotIndex = value.indexOf('.');
      if (dotIndex > 0) {
        final prefix = value.substring(0, dotIndex + 1); // e.g. "1."
        // Verify this prefix is consistent across the first few pages
        bool consistent = true;
        for (final otherRow in rows) {
          final otherVal = otherRow.data[column] as String?;
          if (otherVal != null && otherVal.contains('.') &&
              !otherVal.startsWith(prefix)) {
            consistent = false;
            break;
          }
        }
        if (consistent) return prefix;
      }
    }
    return null;
  }

  /// Find the first para_id where the page column matches [pageInput].
  /// Supports both exact matches and short-form (prefix + number) matches.
  /// Returns the para_id, or null if not found.
  Future<int?> findParaIdByPage(
    String bookId,
    String pageInput,
    String column,
  ) async {
    if (pageInput.trim().isEmpty) return null;

    // Try exact match first
    final exactRows = await _db.customSelect(
      'SELECT para_id FROM sentences '
      'WHERE book_id = ? AND $column = ? '
      'ORDER BY para_id ASC LIMIT 1',
      variables: [
        Variable.withString(bookId),
        Variable.withString(pageInput.trim()),
      ],
    ).get();

    if (exactRows.isNotEmpty) {
      return exactRows.first.data['para_id'] as int;
    }

    // If the input doesn't contain a dot, try with prefix
    if (!pageInput.contains('.')) {
      final prefix = await getPagePrefix(bookId, column);
      if (prefix != null) {
        final fullPage = '$prefix${pageInput.trim()}';
        final prefixedRows = await _db.customSelect(
          'SELECT para_id FROM sentences '
          'WHERE book_id = ? AND $column = ? '
          'ORDER BY para_id ASC LIMIT 1',
          variables: [
            Variable.withString(bookId),
            Variable.withString(fullPage),
          ],
        ).get();

        if (prefixedRows.isNotEmpty) {
          return prefixedRows.first.data['para_id'] as int;
        }
      }
    }

    // Try partial match (containing the input)
    final likeRows = await _db.customSelect(
      'SELECT para_id FROM sentences '
      'WHERE book_id = ? AND $column LIKE ? '
      'ORDER BY para_id ASC LIMIT 1',
      variables: [
        Variable.withString(bookId),
        Variable.withString('%${pageInput.trim()}%'),
      ],
    ).get();

    if (likeRows.isNotEmpty) {
      return likeRows.first.data['para_id'] as int;
    }

    return null;
  }

  /// Get the first available page number for a book in the given column.
  /// Returns null if no page data exists.
  Future<String?> getFirstPage(String bookId, String column) async {
    final rows = await _db.customSelect(
      'SELECT $column FROM sentences '
      'WHERE book_id = ? AND $column IS NOT NULL AND $column != \'\' '
      'ORDER BY para_id ASC, line_id ASC LIMIT 1',
      variables: [Variable.withString(bookId)],
    ).get();

    if (rows.isEmpty) return null;
    return rows.first.data[column] as String?;
  }

  /// Get book name for a book ID.
  Future<String?> getBookName(String bookId) async {
    final rows = await _db.customSelect(
      'SELECT book_name FROM books WHERE book_id = ? LIMIT 1',
      variables: [Variable.withString(bookId)],
    ).get();
    if (rows.isEmpty) return null;
    return rows.first.data['book_name'] as String?;
  }
}
