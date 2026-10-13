import 'package:sqlite3/sqlite3.dart';

/// A tiny read-only handle that answers one question synchronously: does DPD
/// have anything for this word? The reader's quote-join check needs the answer
/// before the selection clears, which an async query cannot give.
class DpdQuickLookup {
  DpdQuickLookup._(this._db, this._statement);

  factory DpdQuickLookup.open(String path) {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      // The columns that hold content. The export uses empty strings, never
      // NULL, for "nothing here".
      final statement = db.prepare(
        'SELECT headwords, roots, deconstructor, grammar, epd, variant, '
        'spelling, see FROM lookup WHERE lookup_key = ?',
      );
      return DpdQuickLookup._(db, statement);
    } catch (_) {
      db.dispose();
      rethrow;
    }
  }

  final Database _db;
  final PreparedStatement _statement;

  /// Whether [word] has a `lookup` row with any non-empty content column.
  bool hasContent(String word) {
    final key = word.trim().toLowerCase().replaceAll('ṁ', 'ṃ');
    if (key.isEmpty) return false;
    final rows = _statement.select([key]);
    if (rows.isEmpty) return false;
    return rows.first.values.any((v) => v is String && v.isNotEmpty);
  }

  void dispose() {
    _statement.dispose();
    _db.dispose();
  }
}
