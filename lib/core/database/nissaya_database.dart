import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// A nissaya sentence with parsed Pāli + meaning pairs from JSON content.
class NissayaSentenceLine {
  final String bookId;
  final int paraId;
  final int lineId;
  final int nissayaId;

  /// The raw content (JSON string or plain text).
  final String content;

  /// Parsed Pāli + meaning pairs (only when content is JSON array).
  final List<NissayaWordPair> pairs;

  /// Whether the content was successfully parsed as JSON.
  final bool isJsonFormatted;

  const NissayaSentenceLine({
    required this.bookId,
    required this.paraId,
    required this.lineId,
    required this.nissayaId,
    required this.content,
    this.pairs = const [],
    this.isJsonFormatted = false,
  });

  /// Parse the content JSON and return a formatted string.
  ///
  /// If content is a JSON array of `{"pali": "...", "meaning": "..."}` objects,
  /// returns formatted text "pali: meaning | pali: meaning | ...".
  /// Otherwise returns the raw content text.
  String get formattedText {
    if (isJsonFormatted && pairs.isNotEmpty) {
      return pairs
          .map((p) => '${p.pali}: ${p.meaning}')
          .join(' | ');
    }
    return content;
  }
}

/// A word pair in a nissaya sentence.
class NissayaWordPair {
  final String pali;
  final String meaning;

  const NissayaWordPair({required this.pali, required this.meaning});
}

/// Database for nissaya-type translations.
///
/// Schema:
/// ```sql
/// CREATE TABLE sentences (
///   book_id TEXT NOT NULL,
///   para_id INTEGER NOT NULL,
///   line_id INTEGER NOT NULL,
///   content TEXT,
///   nissaya_id INTEGER NOT NULL,
///   PRIMARY KEY (nissaya_id, book_id, para_id, line_id)
/// );
/// CREATE TABLE books (
///   book_id INTEGER PRIMARY KEY,
///   book_name TEXT,
///   info TEXT
/// );
/// ```
class NissayaDatabase {
  final NativeDatabase _database;

  NissayaDatabase._(this._database);

  /// Open an existing nissaya database at [dbPath].
  static Future<NissayaDatabase> open(String dbPath) async {
    final file = File(dbPath);
    if (!await file.exists()) {
      throw Exception('Nissaya database not found at $dbPath');
    }

    final database = NativeDatabase(
      file,
      setup: (db) {
        db.execute('PRAGMA journal_mode=WAL');
        db.execute('PRAGMA foreign_keys=ON');
      },
      logStatements: false,
    );

    return NissayaDatabase._(database);
  }

  /// Get all sentences for a specific book and paragraph.
  Future<List<NissayaSentenceLine>> getSentences(
    String bookId,
    int paraId,
  ) async {
    final rows = await _database.runSelect(
      'SELECT book_id, para_id, line_id, content, nissaya_id FROM sentences '
      'WHERE book_id = ? AND para_id = ? '
      'ORDER BY line_id',
      [Variable.withString(bookId), Variable.withInt(paraId)],
    );

    return rows.map((row) => _parseRow(row)).toList();
  }

  /// Get all sentences for a specific book.
  Future<List<NissayaSentenceLine>> getBookSentences(String bookId) async {
    final rows = await _database.runSelect(
      'SELECT book_id, para_id, line_id, content, nissaya_id FROM sentences '
      'WHERE book_id = ? '
      'ORDER BY para_id, line_id',
      [Variable.withString(bookId)],
    );

    return rows.map((row) => _parseRow(row)).toList();
  }

  /// Get a single sentence by its primary key.
  Future<NissayaSentenceLine?> getSentence(
    String bookId,
    int paraId,
    int lineId,
  ) async {
    final rows = await _database.runSelect(
      'SELECT book_id, para_id, line_id, content, nissaya_id FROM sentences '
      'WHERE book_id = ? AND para_id = ? AND line_id = ? '
      'LIMIT 1',
      [
        Variable.withString(bookId),
        Variable.withInt(paraId),
        Variable.withInt(lineId),
      ],
    );

    if (rows.isEmpty) return null;
    return _parseRow(rows.first);
  }

  /// Get all sentences for a book, formatted for reader display.
  /// Returns Map<paraId, Map<lineId, transcript>> where transcript is the
  /// formatted text (e.g. "pali: meaning | pali: meaning") for nissaya content.
  Future<Map<int, Map<int, String>>> getBookSentencesFormatted(String bookId) async {
    final sentences = await getBookSentences(bookId);
    final result = <int, Map<int, String>>{};
    for (final s in sentences) {
      result.putIfAbsent(s.paraId, () => {});
      result[s.paraId]![s.lineId] = s.formattedText;
    }
    return result;
  }

  /// Get book info.
  Future<Map<String, Object?>?> getBookInfo(int bookId) async {
    final rows = await _database.runSelect(
      'SELECT book_id, book_name, info FROM books WHERE book_id = ? LIMIT 1',
      [Variable.withInt(bookId)],
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  /// Parse a row from the sentences table.
  NissayaSentenceLine _parseRow(Map<String, Object?> row) {
    final content = (row['content'] as String?) ?? '';
    return NissayaSentenceLine(
      bookId: row['book_id'] as String,
      paraId: row['para_id'] as int,
      lineId: row['line_id'] as int,
      nissayaId: row['nissaya_id'] as int,
      content: content,
      pairs: _parseContentJson(content),
      isJsonFormatted: _isValidJsonArray(content),
    );
  }

  /// Try to parse content as JSON array of pali/meaning pairs.
  static List<NissayaWordPair> _parseContentJson(String content) {
    if (content.isEmpty) return [];
    try {
      final decoded = jsonDecode(content);
      if (decoded is! List) return [];
      return decoded.map((item) {
        if (item is Map) {
          return NissayaWordPair(
            pali: (item['pali'] as String?) ?? '',
            meaning: (item['meaning'] as String?) ?? '',
          );
        }
        return NissayaWordPair(pali: item.toString(), meaning: '');
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Check if content is a valid JSON array.
  static bool _isValidJsonArray(String content) {
    if (content.isEmpty) return false;
    try {
      final decoded = jsonDecode(content);
      return decoded is List;
    } catch (_) {
      return false;
    }
  }

  /// Close the database.
  Future<void> close() async {
    await _database.close();
  }
}
