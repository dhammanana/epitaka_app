import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite_vector/sqlite_vector.dart';

import '../../../core/utils/pali_search_utils.dart';

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

/// A single BM25 (full-text) search result from the chunk-level FTS index.
class Bm25SearchResult {
  final int chunkId;

  /// Textual book ID (e.g. "dn1", "A-i").
  final String bookId;

  /// Raw FTS5 bm25() score. FTS5 returns *negative* values where more
  /// negative == more relevant, so callers must sort ASCENDING.
  final double bm25Score;

  const Bm25SearchResult({
    required this.chunkId,
    required this.bookId,
    required this.bm25Score,
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
    0x53,
    0x51,
    0x4c,
    0x69,
    0x74,
    0x65,
    0x20,
    0x66,
    0x6f,
    0x72,
    0x6d,
    0x61,
    0x74,
    0x20,
    0x33,
    0x00,
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
            print(
              '[VEC] ❌ Vector DB has invalid SQLite header at byte $i: '
              'expected ${_sqliteHeaderMagic[i]}, got ${header[i]}',
            );
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

  /// Returns true if the chunk-level BM25 FTS index (`chunks_fts`) exists
  /// and has at least one row.
  bool isChunkFtsBuilt() {
    if (_db == null) return false;
    try {
      final existing = _db!.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='chunks_fts'",
      );
      if (existing.isEmpty) return false;
      final countRow = _db!.select('SELECT COUNT(*) AS c FROM chunks_fts');
      return (countRow.first['c'] as int) > 0;
    } catch (_) {
      return false;
    }
  }

  /// Drop the chunk-level BM25 FTS index (`chunks_fts`) if it exists.
  /// Used before a rebuild so a half-built/corrupt index from an interrupted
  /// build is discarded rather than trusted.
  void dropChunkFts() {
    if (_db == null) return;
    try {
      _db!.execute('DROP TABLE IF EXISTS chunks_fts');
    } catch (_) {}
  }

  /// Build a chunk-level FTS5 index (`chunks_fts`) inside the vector database
  /// so BM25 lexical search can be fused with the vector search.
  ///
  /// The index is built **once** and persisted in the vec DB file. It is
  /// keyed by `chunk_id` so BM25 and vector results share the exact same
  /// granularity — no paragraph→chunk remapping needed at fusion time.
  ///
  /// Diacritics are stripped by SQLite's `unicode61 remove_diacritics 1`
  /// tokenizer (NOT in app code), so a query for "dhamma" matches indexed
  /// "dhammā". Pāli text is cleaned with the shared [cleanPaliForIndexing]
  /// (bracket/punctuation stripping) to match the main `search_fts` index.
  ///
  /// Returns true if the index is present (built now or already existed).
  Future<bool> buildChunkFts(
    String epitakaDbPath, {
    void Function(double progress, String status)? onProgress,
  }) async {
    if (_db == null) return false;
    try {
      final existing = _db!.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='chunks_fts'",
      );
      if (existing.isNotEmpty) {
        final countRow = _db!.select('SELECT COUNT(*) AS c FROM chunks_fts');
        final count = countRow.first['c'] as int;
        if (count > 0) {
          print('[VEC] chunks_fts already built ($count rows) — skipping');
          onProgress?.call(1.0, 'BM25 index ready');
          return true;
        }
        // Exists but empty (interrupted build) → drop and rebuild.
        _db!.execute('DROP TABLE IF EXISTS chunks_fts');
      }

      final epiFile = File(epitakaDbPath);
      if (!epiFile.existsSync()) {
        print(
          '[VEC] ❌ epitaka.db not found at $epitakaDbPath '
          '— cannot build chunks_fts',
        );
        return false;
      }

      final epi = sqlite3.open(epitakaDbPath, mode: OpenMode.readOnly);
      try {
        _db!.execute('''
          CREATE VIRTUAL TABLE chunks_fts USING fts5(
            chunk_id UNINDEXED,
            book_id   UNINDEXED,
            pali_text,
            tokenize='unicode61 remove_diacritics 1'
          )
        ''');

        final chunks = _db!.select(
          'SELECT chunk_id, book_id, start_para, start_line, '
          'end_para, end_line FROM chunks ORDER BY chunk_id',
        );
        print('[VEC] Building chunks_fts from ${chunks.length} chunks…');
        final total = chunks.length;
        onProgress?.call(0.02, 'Indexing ${total} chunks…');

        _db!.execute('BEGIN TRANSACTION');
        int inserted = 0;
        int processed = 0;
        for (final c in chunks) {
          final raw = _fetchChunkPali(epi, c);
          if (raw.isNotEmpty) {
            final cleaned = cleanPaliForIndexing(raw);
            if (cleaned.isNotEmpty) {
              _db!.execute(
                'INSERT INTO chunks_fts(chunk_id, book_id, pali_text) '
                'VALUES (?, ?, ?)',
                [c['chunk_id'], c['book_id'], cleaned],
              );
              inserted++;
            }
          }
          processed++;
          // Yield to the event loop every 200 chunks so Flutter can repaint
          // the progress dialog. Without this the synchronous loop blocks the
          // UI isolate and Android's ANR watchdog kills the app.
          if (processed % 200 == 0) {
            onProgress?.call(
              (0.02 + (processed / total) * 0.98).clamp(0.02, 1.0),
              'Indexing chunks… $processed / $total',
            );
            await Future.delayed(Duration.zero);
          }
        }
        _db!.execute('COMMIT');
        print('[VEC] ✅ chunks_fts built: $inserted rows');
        onProgress?.call(1.0, 'BM25 index ready');
        return true;
      } catch (e, stack) {
        print('[VEC] ❌ chunks_fts build failed: $e');
        print('[VEC] $stack');
        try {
          _db!.execute('ROLLBACK');
        } catch (_) {}
        try {
          _db!.execute('DROP TABLE IF EXISTS chunks_fts');
        } catch (_) {}
        return false;
      } finally {
        epi.close();
      }
    } catch (e, stack) {
      print('[VEC] ❌ buildChunkFts error: $e');
      print('[VEC] $stack');
      return false;
    }
  }

  /// Fetch the concatenated Pāli text for a chunk's paragraph/line range
  /// directly from `epitaka.db` (used while building the chunk FTS index).
  String _fetchChunkPali(Database epi, Map<String, Object?> c) {
    final bookId = c['book_id'] as String;
    final startPara = c['start_para'] as int;
    final startLine = c['start_line'] as int;
    final endPara = c['end_para'] as int;
    final endLine = c['end_line'] as int;
    try {
      final rows = epi.select(
        '''
        SELECT group_concat(pali, ' ') as text FROM sentences
        WHERE book_id = ? AND
          ((para_id = ? AND line_id >= ?) OR
           (para_id > ? AND para_id < ?) OR
           (para_id = ? AND line_id <= ?))
      ''',
        [bookId, startPara, startLine, startPara, endPara, endPara, endLine],
      );
      if (rows.isEmpty) return '';
      return (rows.first['text'] as String?) ?? '';
    } catch (_) {
      return '';
    }
  }

  /// BM25 lexical search over the chunk-level FTS index.
  ///
  /// Uses FTS5's default **OR** between terms (space-joined) with prefix
  /// matching (`"term"*`), letting BM25 weight term importance by IDF.
  /// Diacritic handling is delegated to the `remove_diacritics 1` tokenizer.
  ///
  /// Returns results ordered best-first (bm25() is negative; we sort ASC).
  Future<List<Bm25SearchResult>> searchBm25(
    String query, {
    int limit = 100,
  }) async {
    if (_db == null) return [];
    final exists = _db!.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='chunks_fts'",
    );
    if (exists.isEmpty) return [];

    final ftsQuery = _buildBm25Query(query);
    if (ftsQuery.isEmpty) return [];

    try {
      final rows = _db!.select(
        'SELECT chunk_id, book_id, bm25(chunks_fts) AS bm25_score '
        'FROM chunks_fts '
        'WHERE pali_text MATCH ? '
        'ORDER BY bm25_score ASC '
        'LIMIT ?',
        [ftsQuery, limit],
      );
      return rows
          .map(
            (r) => Bm25SearchResult(
              chunkId: r['chunk_id'] as int,
              bookId: r['book_id'] as String,
              bm25Score: r['bm25_score'] as double,
            ),
          )
          .toList();
    } catch (e, stack) {
      print('[VEC] ❌ BM25 search failed: $e');
      print('[VEC] $stack');
      return [];
    }
  }

  /// Build an FTS5 MATCH query: lowercase, quote/escape each term, add a
  /// prefix `*` and join with spaces (FTS5 default = OR).
  static String _buildBm25Query(String query) {
    return query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) {
          final safe = w.replaceAll('"', '""');
          return '"$safe"*';
        })
        .join(' ');
  }

  /// Look up a single chunk's metadata by `chunk_id` (used for BM25-only
  /// hits that did not appear in the vector candidate set).
  Future<VectorSearchResult?> getChunk(int chunkId) async {
    if (_db == null) return null;
    try {
      final rows = _db!.select(
        'SELECT chunk_id, book_id, start_para, end_para, start_line, '
        'end_line, token_count, line_count '
        'FROM chunks WHERE chunk_id = ?',
        [chunkId],
      );
      if (rows.isEmpty) return null;
      final r = rows.first;
      return VectorSearchResult(
        chunkId: r['chunk_id'] as int,
        bookId: r['book_id'] as String,
        startPara: r['start_para'] as int,
        endPara: r['end_para'] as int,
        startLine: r['start_line'] as int,
        endLine: r['end_line'] as int,
        tokenCount: r['token_count'] as int,
        lineCount: r['line_count'] as int,
        similarity: 0.0,
      );
    } catch (_) {
      return null;
    }
  }

  /// Close the database connection.
  void dispose() {
    print('[VEC] dispose() called — closing database');
    _db?.close();
    _db = null;
  }
}
