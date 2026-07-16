import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite_vector/sqlite_vector.dart';

/// A single search result from vector similarity search.
class VectorSearchResult {
  final int chunkId;

  /// Textual book ID (e.g. "dn1", "A-i").
  final String bookId;
  final int startPara;
  final int endPara;
  final int startLine;
  final int endLine;
  final int tokenCount;
  final int lineCount;
  final double similarity;

  const VectorSearchResult({
    required this.chunkId,
    required this.bookId,
    required this.startPara,
    required this.endPara,
    required this.startLine,
    required this.endLine,
    required this.tokenCount,
    required this.lineCount,
    required this.similarity,
  });
}

/// Service for vector similarity search using the sqlite_vector package
/// (sqlite.ai), which bundles sqlite-vec-compatible extension functions.
///
/// The database uses a regular table `chunks` with a BLOB `embedding`
/// column, queried through `vector_full_scan()`.
class GavesanaVectorSearchService {
  Database? _db;
  static bool _extensionLoaded = false;

  /// The 16-byte SQLite header magic: "SQLite format 3\0".
  static const List<int> _sqliteHeaderMagic = <int>[
    0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66,
    0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00,
  ];

  /// Verify that a file is a valid SQLite database by checking its
  /// 16-byte header magic.
  static bool _isValidSqliteFile(String path) {
    try {
      final file = File(path);
      if (!file.existsSync()) {
        print('[VEC] ❌ Vector DB file does not exist at: $path');
        return false;
      }

      final raf = file.openSync(mode: FileMode.read);
      try {
        final header = raf.readSync(16);
        if (header.length < 16) {
          print('[VEC] ❌ Vector DB file is too small (${header.length} bytes)');
          return false;
        }
        for (int i = 0; i < 16; i++) {
          if (header[i] != _sqliteHeaderMagic[i]) {
            print('[VEC] ❌ Vector DB has invalid SQLite header at byte $i: '
                'expected ${_sqliteHeaderMagic[i]}, got ${header[i]}');
            return false;
          }
        }
        print('[VEC] ✅ SQLite header OK');
        return true;
      } finally {
        raf.closeSync();
      }
    } catch (e, stack) {
      print('[VEC] ❌ Error checking SQLite header: $e');
      print('[VEC] ❌ Stack: $stack');
      return false;
    }
  }

  /// Open the vector database.
  Future<bool> open(String vecDbPath) async {
    try {
      print('[VEC] ====== OPEN VECTOR DB ======');
      print('[VEC] Path: $vecDbPath');

      final vecFile = File(vecDbPath);
      print('[VEC] File exists: ${vecFile.existsSync()}');
      if (vecFile.existsSync()) {
        print('[VEC] File size: ${vecFile.lengthSync()} bytes');
      }

      if (!_isValidSqliteFile(vecDbPath)) {
        print('[VEC] ❌ Aborting open — not a valid SQLite database');
        return false;
      }

      // ── Load sqlite_vector extension ──────────────────────────
      if (!_extensionLoaded) {
        print('[VEC] Loading sqlite_vector extension (first call)…');
        try {
          sqlite3.loadSqliteVectorExtension();
          _extensionLoaded = true;
          print('[VEC] ✅ sqlite_vector extension loaded');
        } catch (e, stack) {
          print('[VEC] ❌ sqlite3.loadSqliteVectorExtension() FAILED!');
          print('[VEC] ❌ Error: $e');
          print('[VEC] ❌ Stack: $stack');
          return false;
        }
      } else {
        print('[VEC] sqlite_vector extension already loaded (reusing)');
      }

      // ── Open the database ─────────────────────────────────────
      print('[VEC] Calling sqlite3.open("$vecDbPath")…');
      try {
        _db = sqlite3.open(vecDbPath);
        print('[VEC] ✅ sqlite3.open() succeeded');
      } catch (e, stack) {
        print('[VEC] ❌ sqlite3.open() FAILED!');
        print('[VEC] ❌ Error: $e');
        print('[VEC] ❌ Stack: $stack');
        return false;
      }

      // ── Verify extension works ────────────────────────────────
      print('[VEC] Running SELECT vector_version()…');
      try {
        final rows = _db!.select('SELECT vector_version()');
        final version = rows.first.values.first;
        print('[VEC] ✅ sqlite_vector version: $version');
      } catch (e, stack) {
        print('[VEC] ❌ vector_version() query FAILED!');
        print('[VEC] ❌ Error: $e');
        print('[VEC] ❌ Stack: $stack');
        _db?.close();
        _db = null;
        return false;
      }

      // ── Verify chunks table exists ────────────────────────────
      print('[VEC] Verifying chunks table…');
      try {
        final tableRows = _db!.select(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='chunks'",
        );
        if (tableRows.isEmpty) {
          print('[VEC] ❌ chunks table not found!');
          _db?.close();
          _db = null;
          return false;
        }

        final countRows = _db!.select('SELECT COUNT(*) FROM chunks');
        print('[VEC]   chunks: ${countRows.first.values.first} rows');
        print('[VEC] ✅ chunks table found');
      } catch (e, stack) {
        print('[VEC] ❌ Table verification FAILED: $e');
        print('[VEC] ❌ Stack: $stack');
        _db?.close();
        _db = null;
        return false;
      }

      // ── Initialize vector index ───────────────────────────────
      print('[VEC] Initializing vector index on chunks.embedding…');
      try {
        _db!.execute(
          "SELECT vector_init('chunks', 'embedding', "
          "'type=INT8,dimension=640,distance=COSINE')",
        );
        print('[VEC] ✅ vector_init() succeeded');
      } catch (e, stack) {
        print('[VEC] ❌ vector_init() FAILED!');
        print('[VEC] ❌ Error: $e');
        print('[VEC] ❌ Stack: $stack');
        _db?.close();
        _db = null;
        return false;
      }

      print('[VEC] ====== OPEN SUCCESS ✅ ======');
      return true;
    } catch (e, stack) {
      print('[VEC] ❌ Unexpected error in open(): $e');
      print('[VEC] ❌ Stack: $stack');
      _db?.close();
      _db = null;
      return false;
    }
  }

  /// Quantize a float64 embedding vector to INT8.
  static List<int> _quantizeToInt8(List<double> embedding) {
    double maxAbs = 0;
    for (final v in embedding) {
      final abs = v.abs();
      if (abs > maxAbs) maxAbs = abs;
    }
    if (maxAbs == 0) return List.filled(embedding.length, 0);

    return embedding.map((v) {
      if (v.isNaN || v.isInfinite) return 0;
      return (v / maxAbs * 127).round().clamp(-128, 127);
    }).toList();
  }

  /// Search for the top-K chunks most similar to the query embedding.
  ///
  /// Uses the sqlite_vector API: vector_full_scan() table-valued function
  /// with vector_as_i8() to convert the query to INT8 BLOB format.
  Future<List<VectorSearchResult>> search(
    List<double> queryEmbedding, {
    int topK = 10,
  }) async {
    if (_db == null) {
      throw StateError('Vector database not opened');
    }

    // Quantize float64 → INT8 and serialize as JSON array of ints.
    final quantized = _quantizeToInt8(queryEmbedding);
    final vecStr = '[${quantized.join(',')}]';

    // Use the sqlite_vector API: vector_full_scan() is a table-valued
    // function returning (rowid, distance) for top-K nearest neighbors.
    // vector_as_i8() converts a JSON array string to an INT8 BLOB.
    // JOIN chunks on rowid to get metadata.
    final rows = _db!.select(
      'SELECT c.chunk_id, c.book_id, c.start_para, c.end_para, '
      'c.start_line, c.end_line, c.token_count, c.line_count, v.distance '
      'FROM chunks AS c '
      "JOIN vector_full_scan('chunks', 'embedding', "
      "vector_as_i8('$vecStr'), $topK) AS v "
      'ON c.rowid = v.rowid '
      'ORDER BY v.distance ASC',
    );

    return rows.map((row) {
      return VectorSearchResult(
        chunkId: row['chunk_id'] as int,
        bookId: row['book_id'] as String,
        startPara: row['start_para'] as int,
        endPara: row['end_para'] as int,
        startLine: row['start_line'] as int,
        endLine: row['end_line'] as int,
        tokenCount: row['token_count'] as int,
        lineCount: row['line_count'] as int,
        similarity: 1.0 - (row['distance'] as double),
      );
    }).toList();
  }

  /// Close the database connection.
  void dispose() {
    print('[VEC] dispose() called — closing database');
    _db?.close();
    _db = null;
  }
}
