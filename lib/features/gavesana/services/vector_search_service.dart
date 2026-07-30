import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite_vector/sqlite_vector.dart';

import 'package:path/path.dart' as p;

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
/// The vector database (`epitaka_vec.db`) stores only chunk vectors
/// (a `chunk_vectors` table with just chunk_id + embedding BLOB) to
/// minimise RAM usage. Chunk metadata (book_id, para range, etc.) is
/// read from the main `epitaka.db` `vec_chunks` table. BM25 FTS search
/// operates on `vec_chunks_fts` inside `epitaka.db`.
class GavesanaVectorSearchService {
  /// Connection to the slim vector DB (chunk_vectors table).
  Database? _vecDb;

  /// Connection to the main epitaka.db (for metadata + BM25).
  Database? _epiDb;

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
    0x69,
    0x6f,
    0x6e,
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
        print('[VEC] ❌ DB file does not exist at: $path');
        return false;
      }

      final raf = file.openSync(mode: FileMode.read);
      try {
        final header = raf.readSync(16);
        if (header.length < 16) {
          print('[VEC] ❌ DB file is too small (${header.length} bytes)');
          return false;
        }
        for (int i = 0; i < 16; i++) {
          if (header[i] != _sqliteHeaderMagic[i]) {
            print(
              '[VEC] ❌ DB has invalid SQLite header at byte $i: '
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

  /// Open only epitaka.db for BM25 operations (no vector search needed).
  ///
  /// Used when the vector DB is not available but BM25 should still work.
  Future<bool> openBm25Only(String epitakaDbPath) async {
    if (_epiDb != null) return true;
    try {
      if (!_isValidSqliteFile(epitakaDbPath)) {
        print('[VEC] ❌ epitaka.db not valid at: $epitakaDbPath');
        return false;
      }
      _epiDb = sqlite3.open(epitakaDbPath);
      print('[VEC] ✅ openBm25Only: epitaka.db opened');
      return true;
    } catch (e) {
      print('[VEC] ❌ openBm25Only failed: $e');
      return false;
    }
  }

  /// Open the slim vector database and the main epitaka.db.
  ///
  /// [vecDbPath] points to `epitaka_vec.db` (chunk_vectors table).
  /// [epitakaDbPath] points to `epitaka.db` (vec_chunks table).
  Future<bool> open(String vecDbPath, {String? epitakaDbPath}) async {
    try {
      print('[VEC] ====== OPEN VECTOR SERVICE ======');
      print('[VEC] Vec DB Path: $vecDbPath');

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

      // ── Open the slim vector DB ──────────────────────────────
      print('[VEC] Opening slim vec DB…');
      try {
        _vecDb = sqlite3.open(vecDbPath);
        print('[VEC] ✅ sqlite3.open(vec db) succeeded');
      } catch (e, stack) {
        print('[VEC] ❌ sqlite3.open(vec db) FAILED!');
        print('[VEC] ❌ Error: $e');
        print('[VEC] ❌ Stack: $stack');
        return false;
      }

      // ── Verify extension works ────────────────────────────────
      print('[VEC] Running SELECT vector_version()…');
      try {
        final rows = _vecDb!.select('SELECT vector_version()');
        final version = rows.first.values.first;
        print('[VEC] ✅ sqlite_vector version: $version');
      } catch (e, stack) {
        print('[VEC] ❌ vector_version() query FAILED!');
        print('[VEC] ❌ Error: $e');
        print('[VEC] ❌ Stack: $stack');
        _vecDb?.close();
        _vecDb = null;
        return false;
      }

      // ── Verify chunk_vectors table exists in slim vec DB ──────
      print('[VEC] Verifying chunk_vectors table…');
      try {
        final tableRows = _vecDb!.select(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='chunk_vectors'",
        );
        if (tableRows.isEmpty) {
          print('[VEC] ❌ chunk_vectors table not found!');
          _vecDb?.close();
          _vecDb = null;
          return false;
        }

        final countRows = _vecDb!.select('SELECT COUNT(*) FROM chunk_vectors');
        print('[VEC]   chunk_vectors: ${countRows.first.values.first} rows');
        print('[VEC] ✅ chunk_vectors table found');
      } catch (e, stack) {
        print('[VEC] ❌ Table verification FAILED: $e');
        print('[VEC] ❌ Stack: $stack');
        _vecDb?.close();
        _vecDb = null;
        return false;
      }

      // ── Initialize vector index on chunk_vectors.embedding ────
      print('[VEC] Initializing vector index on chunk_vectors.embedding…');
      try {
        _vecDb!.execute(
          "SELECT vector_init('chunk_vectors', 'embedding', "
          "'type=INT8,dimension=640,distance=COSINE')",
        );
        print('[VEC] ✅ vector_init() succeeded');
      } catch (e, stack) {
        print('[VEC] ❌ vector_init() FAILED!');
        print('[VEC] ❌ Error: $e');
        print('[VEC] ❌ Stack: $stack');
        _vecDb?.close();
        _vecDb = null;
        return false;
      }

      // ── Open epitaka.db for metadata lookup ───────────────────
      if (epitakaDbPath != null) {
        print('[VEC] Opening epitaka.db for metadata…');
        try {
          if (_isValidSqliteFile(epitakaDbPath)) {
            _epiDb = sqlite3.open(epitakaDbPath);
            final hasVecChunks = _epiDb!.select(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='vec_chunks'",
            ).isNotEmpty;
            if (hasVecChunks) {
              print('[VEC] ✅ epitaka.db opened with vec_chunks table');
            } else {
              print('[VEC] ⚠ epitaka.db opened but no vec_chunks table');
            }
          } else {
            print('[VEC] ⚠ epitaka.db not valid, metadata lookups will be limited');
          }
        } catch (e) {
          print('[VEC] ⚠ Failed to open epitaka.db: $e');
          _epiDb = null;
        }
      }

      print('[VEC] ====== OPEN SUCCESS ✅ ======');
      return true;
    } catch (e, stack) {
      print('[VEC] ❌ Unexpected error in open(): $e');
      print('[VEC] ❌ Stack: $stack');
      _vecDb?.close();
      _vecDb = null;
      _epiDb?.close();
      _epiDb = null;
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
  /// Chunk metadata is looked up in ONE batch query from epitaka.db's
  /// vec_chunks table to avoid N+1 queries.
  Future<List<VectorSearchResult>> search(
    List<double> queryEmbedding, {
    int topK = 10,
  }) async {
    if (_vecDb == null) {
      throw StateError('Vector database not opened');
    }
    if (_epiDb == null) {
      print('[VEC] ⚠ epitaka.db not available — cannot resolve chunk metadata');
      return [];
    }

    // Quantize float64 → INT8 and serialize as JSON array of ints.
    final quantized = _quantizeToInt8(queryEmbedding);
    final vecStr = '[${quantized.join(',')}]';

    // Query the slim chunk_vectors table for chunk_id + distance.
    final rows = _vecDb!.select(
      'SELECT cv.chunk_id, v.distance '
      'FROM chunk_vectors AS cv '
      "JOIN vector_full_scan('chunk_vectors', 'embedding', "
      "vector_as_i8('$vecStr'), $topK) AS v "
      'ON cv.rowid = v.rowid '
      'ORDER BY v.distance ASC',
    );

    // Batch look up metadata from epitaka.db's vec_chunks.
    final chunkIds = rows.map((r) => r['chunk_id'] as int).toList();
    final metaMap = _lookupChunkMetaBatch(chunkIds);

    final results = <VectorSearchResult>[];
    for (final row in rows) {
      final chunkId = row['chunk_id'] as int;
      final distance = row['distance'] as double;
      final meta = metaMap[chunkId];
      if (meta == null) {
        // Chunk exists in vector DB but not in vec_chunks — skip.
        print('[VEC] ⚠ chunk_id=$chunkId not found in vec_chunks (orphaned)');
        continue;
      }
      results.add(VectorSearchResult(
        chunkId: chunkId,
        bookId: meta['book_id'] as String,
        startPara: meta['start_para'] as int,
        endPara: meta['end_para'] as int,
        startLine: meta['start_line'] as int,
        endLine: meta['end_line'] as int,
        tokenCount: meta['token_count'] as int,
        lineCount: meta['line_count'] as int,
        similarity: 1.0 - distance,
      ));
    }
    return results;
  }

  /// Batch look up chunk metadata for multiple chunk_ids from epitaka.db's
  /// vec_chunks table.
  Map<int, Map<String, Object?>> _lookupChunkMetaBatch(List<int> chunkIds) {
    if (_epiDb == null || chunkIds.isEmpty) return {};
    try {
      // Build parameterised IN clause.
      final placeholders = chunkIds.map((_) => '?').join(',');
      final rows = _epiDb!.select(
        'SELECT chunk_id, book_id, start_para, end_para, start_line, '
        'end_line, token_count, line_count '
        'FROM vec_chunks WHERE chunk_id IN ($placeholders)',
        chunkIds,
      );
      final result = <int, Map<String, Object?>>{};
      for (final r in rows) {
        final id = r['chunk_id'] as int;
        result[id] = Map<String, Object?>.from(r);
      }
      return result;
    } catch (e) {
      print('[VEC] Batch metadata lookup failed: $e');
      return {};
    }
  }

  // ── BM25 FTS methods ─────────────────────────────────────────────

  /// Returns true if the chunk-level BM25 FTS index (`vec_chunks_fts`)
  /// exists inside epitaka.db and has at least one row.
  bool isChunkFtsBuilt() {
    if (_epiDb == null) return false;
    try {
      final existing = _epiDb!.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='vec_chunks_fts'",
      );
      if (existing.isEmpty) return false;
      final countRow = _epiDb!.select('SELECT COUNT(*) AS c FROM vec_chunks_fts');
      return (countRow.first['c'] as int) > 0;
    } catch (_) {
      return false;
    }
  }

  /// Drop the chunk-level BM25 FTS index (`vec_chunks_fts`) inside
  /// epitaka.db if it exists.
  void dropChunkFts() {
    if (_epiDb == null) return;
    try {
      _epiDb!.execute('DROP TABLE IF EXISTS vec_chunks_fts');
    } catch (_) {}
  }

  /// Build a chunk-level FTS5 index (`vec_chunks_fts`) inside epitaka.db
  /// so BM25 lexical search can be fused with the vector search.
  ///
  /// The index is keyed by `chunk_id` so BM25 and vector results share
  /// the exact same granularity. Chunk metadata comes from the
  /// `vec_chunks` table in epitaka.db itself, so no separate DB is needed.
  ///
  /// Diacritics are stripped by SQLite's `unicode61 remove_diacritics 1`
  /// tokenizer (NOT in app code), so a query for "dhamma" matches indexed
  /// "dhammā". Pāli text is cleaned with the shared [cleanPaliForIndexing].
  ///
  /// [epitakaDbPath] is the path to epitaka.db. Returns true if the
  /// index is present (built now or already existed).
  Future<bool> buildChunkFts(
    String epitakaDbPath, {
    void Function(double progress, String status)? onProgress,
  }) async {
    // We need _epiDb to already be open (or open it now).
    if (_epiDb == null && epitakaDbPath.isNotEmpty) {
      try {
        _epiDb = sqlite3.open(epitakaDbPath);
      } catch (e) {
        print('[VEC] ❌ Failed to open epitaka.db for FTS build: $e');
        return false;
      }
    }
    if (_epiDb == null) return false;

    try {
      final existing = _epiDb!.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='vec_chunks_fts'",
      );
      if (existing.isNotEmpty) {
        final countRow = _epiDb!.select('SELECT COUNT(*) AS c FROM vec_chunks_fts');
        final count = countRow.first['c'] as int;
        if (count > 0) {
          print('[VEC] vec_chunks_fts already built ($count rows) — skipping');
          onProgress?.call(1.0, 'BM25 index ready');
          return true;
        }
        _epiDb!.execute('DROP TABLE IF EXISTS vec_chunks_fts');
      }

      final epiFile = File(epitakaDbPath);
      if (!epiFile.existsSync()) {
        print('[VEC] ❌ epitaka.db not found at $epitakaDbPath');
        return false;
      }

      // Open a separate connection for text fetching (read-only).
      final epi = sqlite3.open(epitakaDbPath, mode: OpenMode.readOnly);
      try {
        _epiDb!.execute('''
          CREATE VIRTUAL TABLE vec_chunks_fts USING fts5(
            chunk_id UNINDEXED,
            book_id   UNINDEXED,
            pali_text,
            english_text,
            tokenize='unicode61 remove_diacritics 1'
          )
        ''');

        // Open English DB for enriched indexing
        final epiDbDir = p.dirname(epitakaDbPath);
        final enDbPath = p.join(epiDbDir, 'epitaka_en.db');
        final enDbFile = File(enDbPath);
        final hasEnDb = await enDbFile.exists();
        Database? enDb;
        if (hasEnDb) {
          enDb = sqlite3.open(enDbPath, mode: OpenMode.readOnly);
          print('[VEC] ✅ epitaka_en.db opened for enriched index');
        } else {
          print('[VEC] ⚠ epitaka_en.db not found — indexing Pāli only');
        }

        // Read chunks from epitaka.db's vec_chunks table.
        final chunks = _epiDb!.select(
          'SELECT chunk_id, book_id, start_para, start_line, '
          'end_para, end_line FROM vec_chunks ORDER BY chunk_id',
        );
        print('[VEC] Building vec_chunks_fts from ${chunks.length} chunks…');
        final total = chunks.length;
        onProgress?.call(0.02, 'Indexing ${total} chunks…');

        _epiDb!.execute('BEGIN TRANSACTION');
        int inserted = 0;
        int processed = 0;
        for (final c in chunks) {
          final texts = _fetchChunkTexts(epi, enDb, c);

          if (texts['pali']!.isEmpty && texts['english']!.isEmpty) {
            processed++;
            continue;
          }

          final paliCleaned = cleanPaliForIndexing(texts['pali']!);
          final englishCleaned = cleanPaliForIndexing(texts['english']!);

          if (paliCleaned.isNotEmpty || englishCleaned.isNotEmpty) {
            _epiDb!.execute(
              'INSERT INTO vec_chunks_fts(chunk_id, book_id, pali_text, english_text) '
              'VALUES (?, ?, ?, ?)',
              [c['chunk_id'], c['book_id'], paliCleaned, englishCleaned],
            );
            inserted++;
          }

          processed++;
          if (processed % 200 == 0) {
            onProgress?.call(
              (0.02 + (processed / total) * 0.98).clamp(0.02, 1.0),
              'Indexing chunks… $processed / $total',
            );
            await Future.delayed(Duration.zero);
          }
        }

        enDb?.close();
        _epiDb!.execute('COMMIT');
        print('[VEC] ✅ vec_chunks_fts built: $inserted rows');
        onProgress?.call(1.0, 'BM25 index ready');
        return true;
      } catch (e, stack) {
        print('[VEC] ❌ vec_chunks_fts build failed: $e');
        print('[VEC] $stack');
        try {
          _epiDb!.execute('ROLLBACK');
        } catch (_) {}
        try {
          _epiDb!.execute('DROP TABLE IF EXISTS vec_chunks_fts');
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

  /// Fetch the concatenated Pāli and English texts for a chunk's
  /// paragraph/line range, enriched with book hierarchy, full heading
  /// chain, and heading English translations.
  Map<String, String> _fetchChunkTexts(
    Database epi,
    Database? enDb,
    Map<String, Object?> c,
  ) {
    final bookId = c['book_id'] as String;
    final startPara = c['start_para'] as int;
    final startLine = c['start_line'] as int;
    final endPara = c['end_para'] as int;
    final endLine = c['end_line'] as int;

    try {
      // ── 1. Pāli body text ──────────────────────────────────────
      final paliBody = _fetchBodyText(
        'pali', epi, null,
        bookId, startPara, startLine, endPara, endLine,
      );

      // ── 2. English body text (if enDb available) ──────────────
      final enBody = _fetchBodyText(
        'translation', null, enDb,
        bookId, startPara, startLine, endPara, endLine,
      );

      // ── 3. Book hierarchy ───────────────────────────────────────
      String bookHeader = '';
      try {
        final rows = epi.select(
          'SELECT book_name, category, nikaya, sub_nikaya '
          'FROM books WHERE book_id = ?',
          [bookId],
        );
        if (rows.isNotEmpty) {
          final r = rows.first;
          final parts = [
            r['category'] as String?,
            r['nikaya'] as String?,
            r['sub_nikaya'] as String?,
            r['book_name'] as String?,
          ];
          bookHeader = parts
              .where((p) => p != null && p.trim().isNotEmpty)
              .join(' > ');
        }
      } catch (_) {}

      // ── 4. Full heading chain via recursive CTE ────────────────
      final paliTitles = <String>[];
      final headingParaIds = <int>[];
      try {
        final headRows = epi.select('''
          WITH RECURSIVE hc(para_id, title, parent) AS (
            SELECT para_id, title, parent FROM headings
            WHERE book_id = ? AND para_id <= ?
            ORDER BY para_id DESC LIMIT 1
            UNION ALL
            SELECT h.para_id, h.title, h.parent
            FROM headings h
            INNER JOIN hc ON h.para_id = hc.parent
          )
          SELECT para_id, title FROM hc ORDER BY para_id ASC
        ''', [bookId, startPara]);

        for (final row in headRows) {
          paliTitles.add(row['title'] as String);
          headingParaIds.add(row['para_id'] as int);
        }
      } catch (_) {}

      // ── 5. Heading English translations ─────────────────────────
      final enTitles = <String>[];
      if (enDb != null && headingParaIds.isNotEmpty) {
        for (final hid in headingParaIds) {
          try {
            final transRows = enDb.select(
              'SELECT translation FROM sentences '
              'WHERE book_id = ? AND para_id = ? '
              'ORDER BY line_id ASC LIMIT 1',
              [bookId, hid],
            );
            if (transRows.isNotEmpty) {
              final t = (transRows.first['translation'] as String?) ?? '';
              enTitles.add(t.trim());
            } else {
              enTitles.add('');
            }
          } catch (_) {
            enTitles.add('');
          }
        }
      }

      // ── 6. Assemble pali_text ───────────────────────────────────
      final paliLines = <String>[];
      if (bookHeader.isNotEmpty) paliLines.add(bookHeader);
      paliLines.addAll(paliTitles.where((t) => t.trim().isNotEmpty));
      final paliHeader = paliLines.join('\n');
      final paliText = paliHeader.isNotEmpty
          ? '$paliHeader\n\n$paliBody'
          : paliBody;

      // ── 7. Assemble english_text ────────────────────────────────
      final enLines = <String>[];
      if (bookHeader.isNotEmpty) enLines.add(bookHeader);
      for (int i = 0; i < paliTitles.length; i++) {
        final enTitle = (i < enTitles.length && enTitles[i].isNotEmpty)
            ? enTitles[i]
            : paliTitles[i];
        if (enTitle.trim().isNotEmpty) enLines.add(enTitle);
      }
      final enHeader = enLines.join('\n');
      final englishText = enHeader.isNotEmpty
          ? '$enHeader\n\n$enBody'
          : enBody;

      return {'pali': paliText, 'english': englishText};
    } catch (_) {
      return {'pali': '', 'english': ''};
    }
  }

  /// Fetch concatenated body text for a chunk's para/line range.
  String _fetchBodyText(
    String column,
    Database? epi,
    Database? enDb,
    String bookId,
    int startPara,
    int startLine,
    int endPara,
    int endLine,
  ) {
    final db = (column == 'pali') ? epi : enDb;
    if (db == null) return '';
    try {
      final rows = db.select(
        'SELECT group_concat($column, \' \') as text FROM sentences '
        'WHERE book_id = ? AND '
        '((para_id = ? AND line_id >= ?) OR '
        '(para_id > ? AND para_id < ?) OR '
        '(para_id = ? AND line_id <= ?))',
        [bookId, startPara, startLine, startPara, endPara, endPara, endLine],
      );
      if (rows.isEmpty) return '';
      return (rows.first['text'] as String?) ?? '';
    } catch (_) {
      return '';
    }
  }

  /// BM25 lexical search over the chunk-level FTS index in epitaka.db.
  ///
  /// Uses FTS5's default **OR** between terms (space-joined) with prefix
  /// matching (`"term"*`). Returns results ordered best-first (bm25() is
  /// negative; we sort ASC).
  Future<List<Bm25SearchResult>> searchBm25(
    String query, {
    int limit = 100,
  }) async {
    if (_epiDb == null) return [];
    final exists = _epiDb!.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='vec_chunks_fts'",
    );
    if (exists.isEmpty) return [];

    final ftsQuery = _buildBm25Query(query);
    if (ftsQuery.isEmpty) return [];

    try {
      final rows = _epiDb!.select(
        'SELECT chunk_id, book_id, bm25(vec_chunks_fts) AS bm25_score '
        'FROM vec_chunks_fts '
        'WHERE vec_chunks_fts MATCH ? '
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

  /// Look up a single chunk's metadata by `chunk_id` from epitaka.db's
  /// vec_chunks (used for BM25-only hits not in vector candidate set).
  Future<VectorSearchResult?> getChunk(int chunkId) async {
    if (_epiDb == null) return null;
    try {
      final rows = _epiDb!.select(
        'SELECT chunk_id, book_id, start_para, end_para, start_line, '
        'end_line, token_count, line_count '
        'FROM vec_chunks WHERE chunk_id = ?',
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

  /// Close both database connections.
  void dispose() {
    print('[VEC] dispose() called — closing databases');
    _vecDb?.close();
    _vecDb = null;
    _epiDb?.close();
    _epiDb = null;
  }
}
