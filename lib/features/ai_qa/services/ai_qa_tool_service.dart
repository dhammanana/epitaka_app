/// Service that executes tools for the AI Q&A feature against the local
/// Tipitaka SQLite database.
///
/// **Search strategy (BM25 + LIKE):**
/// 1. Try BM25 search via Gavesana's `chunks_fts` FTS5 index (when available).
/// 2. Fall back to LIKE-based keyword search.
///
/// Each tool corresponds to a Gemini function declaration and is executed
/// when the small model requests it. Results are passed back to the model
/// as function responses.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../../core/providers/database_provider.dart';
import '../../reader/services/jump_service.dart';

/// Result from a tool execution.
class ToolResult {
  final bool success;
  final String data; // JSON-encoded result string
  final String? errorMessage;

  const ToolResult({
    required this.success,
    required this.data,
    this.errorMessage,
  });
}

/// JSON encoder for formatting results.
const _encoder = JsonEncoder.withIndent(null);

/// Encode a JSON value to a string.
String _toJsonString(dynamic value) {
  try {
    return _encoder.convert(value);
  } catch (_) {
    return '[]';
  }
}

/// Encode a Map to JSON string.
String _toJsonJson(Map<String, dynamic> value) {
  try {
    return _encoder.convert(value);
  } catch (_) {
    return '{}';
  }
}

/// Service that provides tool implementations for the AI Q&A feature.
class AiQaToolService {
  final Ref _ref;

  AiQaToolService(this._ref);

  /// Cached sqlite3 connection to the Gavesana vector DB (read-only).
  sqlite.Database? _vecDb;

  /// Lazily open the Gavesana vector DB for BM25 search.
  ///
  /// Returns `null` if the DB does not exist or does not have a `chunks_fts`
  /// FTS5 index (the user must build it via Gavesana first).
  Future<sqlite.Database?> _getVecDb() async {
    if (_vecDb != null) return _vecDb;

    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final vecDbPath = p.join(appDocDir.path, 'gavesana', 'epitaka_vec.db');
      final vecDbFile = File(vecDbPath);

      if (!await vecDbFile.exists()) {
        debugPrint('[AI_QA] Vector DB not found at: $vecDbPath');
        return null;
      }

      final db = sqlite.sqlite3.open(vecDbPath);

      // Verify chunks_fts exists
      final tables = db.select(
        "SELECT name FROM sqlite_master "
        "WHERE type='table' AND name='chunks_fts'",
      );
      if (tables.isEmpty) {
        debugPrint('[AI_QA] chunks_fts not found in vec DB');
        db.close();
        return null;
      }

      debugPrint('[AI_QA] ✅ Vector DB opened with chunks_fts');
      _vecDb = db;
      return _vecDb;
    } catch (e) {
      debugPrint('[AI_QA] Failed to open vec DB: $e');
      return null;
    }
  }

  // ── Tool 1: search_tipitaka ──────────────────────────────────────────

  /// Search the Tipitaka using **BM25 (FTS5) via Gavesana vec DB** when
  /// available, falling back to LIKE-based keyword search.
  ///
  /// BM25 provides:
  /// - IDF-weighted term scoring (rare terms matter more)
  /// - Unicode61 tokenizer with diacritic removal (ā→a, ṃ→m, etc.)
  /// - Whole-word matching (not substring LIKE patterns)
  ///
  /// LIKE fallback provides:
  /// - Substring matching when the BM25 index is not available.
  Future<ToolResult> searchTipitaka(Map<String, dynamic> args) async {
    final query = (args['query'] as String?) ?? '';
    debugPrint('[AI_QA] search_tipitaka: query="$query"');
    if (query.trim().isEmpty) {
      return const ToolResult(
          success: false, data: '[]', errorMessage: 'Empty query');
    }

    // 1. Try BM25 via Gavesana vec DB
    final bm25Result = await _searchBm25(query);
    if (bm25Result.success) {
      final parsed = jsonDecode(bm25Result.data) as List<dynamic>?;
      if (parsed != null && parsed.isNotEmpty) {
        debugPrint('[AI_QA] search_tipitaka: ✅ BM25 => ${parsed.length} results');
        return ToolResult(
          success: true,
          data: _toJsonString(parsed.take(20).toList()),
        );
      }
    }

    debugPrint('[AI_QA] search_tipitaka: BM25 returned no results, falling back to LIKE');

    // 2. Fall back to LIKE-based keyword search
    return _searchLike(query);
  }

  /// BM25 search using the Gavesana vector DB's `chunks_fts` FTS5 table.
  ///
  /// Returns results with `book_id`, `para_id`, `line_id`, `text` and
  /// `book_name`, ordered by BM25 relevance (best first).
  Future<ToolResult> _searchBm25(String query) async {
    try {
      final vecDb = await _getVecDb();
      if (vecDb == null) {
        debugPrint('[AI_QA] _searchBm25: vec DB not available');
        return const ToolResult(
            success: false, data: '[]', errorMessage: 'Vec DB not available');
      }

      // Build FTS5 MATCH query: quote each term, add prefix wildcard,
      // join with spaces (FTS5 default = OR).
      final terms = query
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty && w.length >= 2)
          .map((w) {
            final safe = w.replaceAll('"', '""');
            return '"$safe"*';
          })
          .join(' ');

      debugPrint('[AI_QA] _searchBm25: FTS5 terms="$terms"');

      if (terms.isEmpty) {
        return const ToolResult(
            success: false, data: '[]', errorMessage: 'No valid terms');
      }

      // Search across ALL FTS5 columns (pali_text, english_text) via
      // table-level MATCH (no column prefix). This means an English query
      // like "mindfulness" will match english_text even if pali_text doesn't
      // contain that term.
      final rows = vecDb.select(
        'SELECT c.chunk_id, c.book_id, c.start_para, c.end_para, '
        'c.start_line, c.end_line, '
        'bm25(chunks_fts) AS bm25_score '
        'FROM chunks_fts '
        'JOIN chunks c ON c.chunk_id = chunks_fts.chunk_id '
        'WHERE chunks_fts MATCH ? '
        'ORDER BY bm25_score ASC '
        'LIMIT 50',
        [terms],
      );

      if (rows.isEmpty) {
        return const ToolResult(
            success: false, data: '[]', errorMessage: 'No BM25 matches');
      }

      // Fetch Pāli text from epitaka.db for each result
      final epitakaDb = await _ref.read(epitakaDbProvider.future);
      final results = <Map<String, dynamic>>[];

      debugPrint('[AI_QA] _searchBm25: ${rows.length} chunks matched, fetching texts...');

      for (final row in rows) {
        final bookId = row['book_id'] as String;
        final startPara = row['start_para'] as int;
        final endPara = row['end_para'] as int;
        // Fetch the first line of the chunk for display and book name
        final paliRows = await epitakaDb.customSelect(
          'SELECT s.para_id, s.line_id, s.pali, b.book_name '
          'FROM sentences s '
          'JOIN books b ON b.book_id = s.book_id '
          'WHERE s.book_id = ? AND s.para_id >= ? AND s.para_id <= ? '
          'ORDER BY s.para_id ASC, s.line_id ASC '
          'LIMIT 1',
          variables: [
            Variable.withString(bookId),
            Variable.withInt(startPara),
            Variable.withInt(endPara),
          ],
        ).get();

        if (paliRows.isNotEmpty) {
          final paliRow = paliRows.first;
          results.add({
            'book_id': bookId,
            'book_name': (paliRow.data['book_name'] as String?) ?? bookId,
            'para_id': paliRow.data['para_id'] as int,
            'line_id': paliRow.data['line_id'] as int,
            'text': (paliRow.data['pali'] as String?) ?? '',
            'relevance': 1.0, // BM25 ordering handles ranking
            'search_method': 'bm25',
          });
        }
      }

      debugPrint('[AI_QA] _searchBm25: ✅ ${results.length} book-level results');
      return ToolResult(success: true, data: _toJsonString(results));
    } catch (e) {
      debugPrint('[AI_QA] _searchBm25: ❌ error: $e');
      return ToolResult(
        success: false,
        data: '[]',
        errorMessage: 'BM25 search error: $e',
      );
    }
  }

  /// LIKE-based keyword search (fallback when BM25 is not available).
  Future<ToolResult> _searchLike(String query) async {
    try {
      final epitakaDb = await _ref.read(epitakaDbProvider.future);

      debugPrint('[AI_QA] _searchLike: keywords="$query"');

      // Tokenise the query into keywords (split on whitespace)
      final keywords = query
          .split(RegExp(r'\s+'))
          .map((w) => w.trim())
          .where((w) => w.length >= 3)
          .toSet()
          .toList();

      if (keywords.isEmpty) {
        return const ToolResult(
            success: false, data: '[]', errorMessage: 'No valid keywords');
      }

      // Search Pāli text using LIKE
      final conditions =
          keywords.map((_) => 'LOWER(s.pali) LIKE ?').join(' OR ');
      final likeParams = keywords.map((kw) => '%${kw.toLowerCase()}%').toList();

      final rows = await epitakaDb.customSelect(
        'SELECT s.book_id, s.para_id, s.line_id, s.pali, '
        'b.book_name '
        'FROM sentences s '
        'JOIN books b ON b.book_id = s.book_id '
        'WHERE $conditions '
        'ORDER BY s.book_id, s.para_id, s.line_id '
        'LIMIT 50',
        variables: [
          ...likeParams.map((p) => Variable.withString(p)),
        ],
      ).get();

      // Deduplicate by (book_id, para_id)
      final seen = <String>{};
      final results = <Map<String, dynamic>>[];

      for (final row in rows) {
        final bookId = (row.data['book_id'] as String?) ?? '';
        final paraId = (row.data['para_id'] as int?) ?? 0;
        final key = '$bookId:$paraId';
        if (seen.add(key)) {
          final paliText = (row.data['pali'] as String?) ?? '';
          final matchCount = keywords
              .where((kw) => paliText.toLowerCase().contains(kw.toLowerCase()))
              .length;
          results.add({
            'book_id': bookId,
            'book_name': (row.data['book_name'] as String?) ?? bookId,
            'para_id': paraId,
            'line_id': (row.data['line_id'] as int?) ?? 1,
            'text': paliText,
            'relevance': matchCount / keywords.length,
            'search_method': 'like',
          });
        }
      }

      debugPrint('[AI_QA] _searchLike: ✅ ${results.length} results (taking top 20)');

      // Sort by relevance descending, then para_id ascending
      results.sort((a, b) {
        final relCmp =
            (b['relevance'] as double).compareTo(a['relevance'] as double);
        if (relCmp != 0) return relCmp;
        return (a['para_id'] as int).compareTo(b['para_id'] as int);
      });

      return ToolResult(
        success: true,
        data: _toJsonString(results.take(20).toList()),
      );
    } catch (e) {
      debugPrint('[AI_QA] _searchLike: ❌ error: $e');
      return ToolResult(success: false, data: '[]', errorMessage: e.toString());
    }
  }

  // ── Tool 1c: search_by_category ───────────────────────────────────────

  /// Search the Tipitaka within specific book categories/nikayas.
  /// First resolves which books match the requested categories, then searches
  /// within those books only. Results are deduplicated across queries.
  Future<ToolResult> searchByCategory(Map<String, dynamic> args) async {
    final queries = (args['queries'] as List<dynamic>?)
            ?.map((q) => q.toString())
            .where((q) => q.trim().isNotEmpty)
            .toList() ??
        [];
    final categories = (args['categories'] as List<dynamic>?)
            ?.map((c) => c.toString().trim().toLowerCase())
            .where((c) => c.isNotEmpty)
            .toList() ??
        [];
    final nikayas = (args['nikayas'] as List<dynamic>?)
            ?.map((n) => n.toString().trim().toLowerCase())
            .where((n) => n.isNotEmpty)
            .toList() ??
        [];

    debugPrint('[AI_QA] search_by_category: ${queries.length} queries, '
        'categories=$categories, nikayas=$nikayas');

    if (queries.isEmpty) {
      return const ToolResult(
          success: false, data: '[]', errorMessage: 'No queries provided');
    }
    if (categories.isEmpty && nikayas.isEmpty) {
      return const ToolResult(
          success: false, data: '[]',
          errorMessage: 'At least one category or nikaya required');
    }

    try {
      final epitakaDb = await _ref.read(epitakaDbProvider.future);

      // Build WHERE clause for category/nikaya filtering
      final filterClauses = <String>[];
      final filterParams = <String>[];

      if (categories.isNotEmpty) {
        final placeholders = categories.map((_) => '?').join(',');
        filterClauses.add('b.category IN ($placeholders)');
        filterParams.addAll(categories);
      }
      if (nikayas.isNotEmpty) {
        // nikaya filter uses book_id prefix match
        final nikayaConditions =
            nikayas.map((n) => 'b.book_id LIKE ?').join(' OR ');
        filterClauses.add('($nikayaConditions)');
        filterParams.addAll(nikayas.map((n) => '$n%'));
      }

      final filterSql = filterClauses.isNotEmpty
          ? 'AND ${filterClauses.join(' AND ')}'
          : '';

      // Get matching book IDs
      final bookRows = await epitakaDb.customSelect(
        'SELECT b.book_id, b.book_name, b.category '
        'FROM books b WHERE 1=1 $filterSql '
        'ORDER BY b.category, b.nikaya, b.book_id',
        variables: filterParams.map((p) => Variable.withString(p)).toList(),
      ).get();

      if (bookRows.isEmpty) {
        return const ToolResult(
            success: true, data: '[]',
            errorMessage: 'No books match the requested categories/nikayas');
      }

      final validBookIds = bookRows
          .map((r) => r.data['book_id'] as String)
          .toSet();

      debugPrint('[AI_QA] search_by_category: ${validBookIds.length} matching books');

      // Execute ALL queries in PARALLEL
      final results = await Future.wait(
        queries.map((q) => searchTipitaka({'query': q})),
      );

      // Merge, deduplicate, and FILTER by book category
      final seen = <String>{};
      final merged = <Map<String, dynamic>>[];

      for (final result in results) {
        if (!result.success) continue;
        try {
          final parsed = jsonDecode(result.data) as List<dynamic>;
          for (final item in parsed) {
            final map = item as Map<String, dynamic>;
            final bookId = map['book_id'] as String? ?? '';
            // Only include results from the requested categories
            if (!validBookIds.contains(bookId)) continue;
            final paraId = map['para_id'] as int? ?? 0;
            final key = '$bookId:$paraId';
            if (seen.add(key)) {
              merged.add(map);
            }
          }
        } catch (_) {}
      }

      debugPrint('[AI_QA] search_by_category: ✅ '
          '${merged.length} unique category-filtered results');
      return ToolResult(
        success: true,
        data: _toJsonString(merged.take(30).toList()),
      );
    } catch (e) {
      debugPrint('[AI_QA] search_by_category: ❌ error: $e');
      return ToolResult(success: false, data: '[]', errorMessage: e.toString());
    }
  }

  // ── Tool 1b: search_tipitaka_batch ────────────────────────────────────

  /// Search the Tipitaka using MULTIPLE different search terms in parallel.
  /// Returns deduplicated, merged results from all queries.
  Future<ToolResult> searchTipitakaBatch(Map<String, dynamic> args) async {
    final queries = (args['queries'] as List<dynamic>?)
            ?.map((q) => q.toString())
            .where((q) => q.trim().isNotEmpty)
            .toList() ??
        [];

    debugPrint('[AI_QA] search_tipitaka_batch: ${queries.length} queries: '
        '${queries.join(" | ")}');

    if (queries.isEmpty) {
      return const ToolResult(
          success: false, data: '[]', errorMessage: 'No queries provided');
    }

    // Execute ALL queries in PARALLEL
    final results = await Future.wait(
      queries.map((q) => searchTipitaka({'query': q})),
    );

    // Merge and deduplicate by (book_id, para_id)
    final seen = <String>{};
    final merged = <Map<String, dynamic>>[];

    for (final result in results) {
      if (!result.success) continue;
      try {
        final parsed = jsonDecode(result.data) as List<dynamic>;
        for (final item in parsed) {
          final map = item as Map<String, dynamic>;
          final bookId = map['book_id'] as String? ?? '';
          final paraId = map['para_id'] as int? ?? 0;
          final key = '$bookId:$paraId';
          if (seen.add(key)) {
            merged.add(map);
          }
        }
      } catch (_) {}
    }

    debugPrint('[AI_QA] search_tipitaka_batch: ✅ ${
        merged.length} unique results from ${results.length} queries');
    return ToolResult(
      success: true,
      data: _toJsonString(merged.take(30).toList()),
    );
  }

  // ── Tool 2: get_headings ─────────────────────────────────────────────

  /// Get the table of contents / headings for a specific book.
  Future<ToolResult> getHeadings(Map<String, dynamic> args) async {
    try {
      final bookId = (args['book_id'] as String?) ?? '';
      debugPrint('[AI_QA] get_headings: book_id="$bookId"');
      if (bookId.isEmpty) {
        return const ToolResult(
            success: false, data: '[]', errorMessage: 'Missing book_id');
      }

      final epitakaDb = await _ref.read(epitakaDbProvider.future);

      final rows = await epitakaDb.customSelect(
        'SELECT h.para_id, h.title, h.level, h.parent, h.sc_id, '
        'b.book_name '
        'FROM headings h '
        'JOIN books b ON b.book_id = h.book_id '
        'WHERE h.book_id = ? '
        'ORDER BY h.para_id ASC',
        variables: [Variable.withString(bookId)],
      ).get();

      final results = rows
          .map((r) => {
                'para_id': r.data['para_id'] as int,
                'title': (r.data['title'] as String?) ?? '',
                'level': (r.data['level'] as int?) ?? 0,
                'parent': (r.data['parent'] as int?) ?? 0,
              })
          .toList();

      final bookInfo = rows.isNotEmpty
          ? {
              'book_id': bookId,
              'book_name':
                  (rows.first.data['book_name'] as String?) ?? bookId
            }
          : {'book_id': bookId, 'book_name': bookId};

      debugPrint('[AI_QA] get_headings: ✅ ${results.length} headings');
      return ToolResult(
        success: true,
        data: _toJsonString({'book': bookInfo, 'headings': results}),
      );
    } catch (e) {
      debugPrint('[AI_QA] get_headings: ❌ error: $e');
      return ToolResult(success: false, data: '[]', errorMessage: e.toString());
    }
  }

  // ── Tool 3: get_books ────────────────────────────────────────────────

  /// Get a list of all available books in the Tipitaka.
  Future<ToolResult> getBooks(Map<String, dynamic> args) async {
    try {
      debugPrint('[AI_QA] get_books: listing all books');
      final epitakaDb = await _ref.read(epitakaDbProvider.future);

      final rows = await epitakaDb.customSelect(
        'SELECT book_id, book_name, category, nikaya, sub_nikaya, '
        'description, mula_ref, attha_ref, tika_ref '
        'FROM books '
        'ORDER BY category, nikaya, sub_nikaya, book_id ASC',
      ).get();

      debugPrint('[AI_QA] get_books: ✅ ${rows.length} books found');
      final results = rows
          .map((r) => {
                'book_id': (r.data['book_id'] as String?) ?? '',
                'book_name': (r.data['book_name'] as String?) ?? '',
                'category': (r.data['category'] as String?) ?? '',
                'nikaya': (r.data['nikaya'] as String?) ?? '',
                'sub_nikaya': (r.data['sub_nikaya'] as String?) ?? '',
                'has_mula':
                    (r.data['mula_ref'] as String?)?.isNotEmpty ?? false,
                'has_attha':
                    (r.data['attha_ref'] as String?)?.isNotEmpty ?? false,
                'has_tika':
                    (r.data['tika_ref'] as String?)?.isNotEmpty ?? false,
              })
          .toList();

      return ToolResult(success: true, data: _toJsonString(results));
    } catch (e) {
      return ToolResult(success: false, data: '[]', errorMessage: e.toString());
    }
  }

  // ── Tool 4: get_paragraph_content ────────────────────────────────────

  /// Get the content of a range of paragraphs from a book.
  Future<ToolResult> getParagraphContent(Map<String, dynamic> args) async {
    try {
      final bookId = (args['book_id'] as String?) ?? '';
      final paraStart = (args['para_start'] as num?)?.toInt() ?? 0;
      final paraEnd = (args['para_end'] as num?)?.toInt() ?? paraStart;

      debugPrint('[AI_QA] get_paragraph_content: book_id="$bookId", '
          'para=$paraStart–$paraEnd');

      if (bookId.isEmpty) {
        return const ToolResult(
            success: false, data: '[]', errorMessage: 'Missing book_id');
      }

      final epitakaDb = await _ref.read(epitakaDbProvider.future);

      final rows = await epitakaDb.customSelect(
        'SELECT s.para_id, s.line_id, s.pali, '
        'b.book_name '
        'FROM sentences s '
        'JOIN books b ON b.book_id = s.book_id '
        'WHERE s.book_id = ? AND s.para_id >= ? AND s.para_id <= ? '
        'ORDER BY s.para_id ASC, s.line_id ASC',
        variables: [
          Variable.withString(bookId),
          Variable.withInt(paraStart),
          Variable.withInt(paraEnd),
        ],
      ).get();

      if (rows.isEmpty) {
        return ToolResult(
          success: true,
          data: '[]',
          errorMessage: 'No paragraphs found in range $paraStart\u2013$paraEnd',
        );
      }

      // Group by para_id
      final grouped = <int, List<Map<String, dynamic>>>{};
      for (final row in rows) {
        final pid = row.data['para_id'] as int;
        grouped.putIfAbsent(pid, () => []);
        grouped[pid]!.add({
          'line_id': row.data['line_id'] as int,
          'pali': (row.data['pali'] as String?) ?? '',
        });
      }

      final paragraphs = grouped.entries
          .map((e) => {
                'para_id': e.key,
                'lines': e.value,
                'full_text': e.value.map((l) => l['pali']).join(' '),
              })
          .toList()
        ..sort((a, b) => (a['para_id'] as int).compareTo(b['para_id'] as int));

      final bookName = rows.isNotEmpty
          ? (rows.first.data['book_name'] as String? ?? bookId)
          : bookId;

      debugPrint('[AI_QA] get_paragraph_content: ✅ '
          '${paragraphs.length} paragraphs, ${rows.length} lines');
      return ToolResult(
        success: true,
        data: _toJsonString({
          'book_id': bookId,
          'book_name': bookName,
          'para_start': paraStart,
          'para_end': paraEnd,
          'paragraphs': paragraphs,
        }),
      );
    } catch (e) {
      return ToolResult(success: false, data: '[]', errorMessage: e.toString());
    }
  }

  // ── Tool 4b: get_paragraph_content_batch ──────────────────────────────

  /// Get Pāli content from MULTIPLE book/paragraph ranges in parallel.
  /// Returns a merged result with all ranges.
  Future<ToolResult> getParagraphContentBatch(Map<String, dynamic> args) async {
    final ranges = (args['ranges'] as List<dynamic>?)?.toList() ?? [];

    debugPrint('[AI_QA] get_paragraph_content_batch: ${ranges.length} ranges');

    if (ranges.isEmpty) {
      return const ToolResult(
          success: false, data: '[]', errorMessage: 'No ranges provided');
    }

    // Execute ALL paragraph fetches in PARALLEL
    final results = await Future.wait(
      ranges.map((r) => getParagraphContent({
            'book_id': (r as Map)['book_id'] as String? ?? '',
            'para_start': (r['para_start'] as num?)?.toInt() ?? 0,
            'para_end': (r['para_end'] as num?)?.toInt() ?? 0,
          })),
    );

    // Collect all successful results with their range info
    final contents = <Map<String, dynamic>>[];
    int totalChars = 0;

    for (int i = 0; i < ranges.length; i++) {
      final r = ranges[i] as Map;
      final result = results[i];
      if (!result.success) continue;

      try {
        final parsed = jsonDecode(result.data);
        totalChars += result.data.length;
        contents.add({
          'book_id': r['book_id'],
          'para_start': r['para_start'],
          'para_end': r['para_end'],
          'content': parsed,
        });
      } catch (_) {}
    }

    debugPrint('[AI_QA] get_paragraph_content_batch: ✅ '
        '${contents.length}/${ranges.length} ranges fetched ($totalChars chars)');
    return ToolResult(
      success: true,
      data: _toJsonString(contents),
    );
  }

  // ── Tool 5: get_commentaries ─────────────────────────────────────────

  /// Get related commentary (Aṭṭhakathā) and sub-commentary (Ṭīkā) passages
  /// for a given Mūla (root text) paragraph.
  ///
  /// Strategy:
  /// 1. Get linked books via mula_ref/attha_ref/tika_ref from the books table
  /// 2. Also get vripara for the paragraph for fallback matching
  /// 3. Find matching sections using section numbers
  Future<ToolResult> getCommentaries(Map<String, dynamic> args) async {
    try {
      final mulaBookId = (args['mula_book_id'] as String?) ?? '';
      final mulaParaId = (args['mula_para_id'] as num?)?.toInt() ?? 0;

      debugPrint('[AI_QA] get_commentaries: mula_book_id="$mulaBookId", '
          'mula_para_id=$mulaParaId');

      if (mulaBookId.isEmpty || mulaParaId <= 0) {
        return const ToolResult(
          success: false,
          data: '{}',
          errorMessage: 'Missing or invalid mula_book_id or mula_para_id',
        );
      }

      final epitakaDb = await _ref.read(epitakaDbProvider.future);
      final jumpService = JumpService(epitakaDb);
      final commentaries = <Map<String, dynamic>>[];

      // Get linked books (mula, attha, tika) for this book
      final linkedBooks = await jumpService.getLinkedBooks(mulaBookId);
      debugPrint('[AI_QA] get_commentaries: ${linkedBooks.length} linked books');
      for (final link in linkedBooks) {
        debugPrint('[AI_QA] get_commentaries:   ${link.type} → ${link.bookId}');
      }

      // Get the vripara for this paragraph (used for fallback matching)
      String? vripara;
      final vriparaRows = await epitakaDb.customSelect(
        'SELECT vripara FROM sentences '
        'WHERE book_id = ? AND para_id = ? AND vripara IS NOT NULL '
        'LIMIT 1',
        variables: [
          Variable.withString(mulaBookId),
          Variable.withInt(mulaParaId),
        ],
      ).get();
      if (vriparaRows.isNotEmpty) {
        vripara = vriparaRows.first.data['vripara'] as String?;
        debugPrint('[AI_QA] get_commentaries: vripara="$vripara"');
      } else {
        debugPrint('[AI_QA] get_commentaries: no vripara found for para $mulaParaId');
      }

      // If no linked books, try using vripara to find related texts
      if (linkedBooks.isEmpty) {
        if (vripara != null && vripara.trim().isNotEmpty) {
          final vriparaSearchRows = await epitakaDb.customSelect(
            'SELECT DISTINCT b.book_id, b.book_name FROM books b '
            'WHERE b.book_id != ? AND b.book_id IN ('
            '  SELECT DISTINCT s.book_id FROM sentences s '
            '  WHERE s.vripara = ?'
            ') '
            'LIMIT 20',
            variables: [
              Variable.withString(mulaBookId),
              Variable.withString(vripara.trim()),
            ],
          ).get();

          for (final row in vriparaSearchRows) {
            final bid = row.data['book_id'] as String;
            final bname = row.data['book_name'] as String? ?? bid;
            commentaries.add({
              'type': 'vripara_match',
              'type_label': 'Related',
              'book_id': bid,
              'book_name': bname,
              'vripara_match': vripara,
            });
          }
        }

        return ToolResult(
          success: true,
          data: _toJsonJson({
            'mula_book_id': mulaBookId,
            'mula_para_id': mulaParaId,
            'vripara': vripara,
            'linked_books': [],
            'commentaries': commentaries,
            'note': commentaries.isNotEmpty
                ? 'Found ${commentaries.length} related book(s) via vripara match: $vripara'
                : 'No linked books or vripara matches found.',
          }),
        );
      }

      // We have linked books — get section number to find matching sections
      final sectionNumber =
          await jumpService.getSectionNumber(mulaBookId, mulaParaId);

      debugPrint('[AI_QA] get_commentaries: section_number=$sectionNumber');

      if (sectionNumber == null) {
        debugPrint('[AI_QA] get_commentaries: ⚠ no section number found');
        return ToolResult(
          success: true,
          data: _toJsonJson({
            'mula_book_id': mulaBookId,
            'mula_para_id': mulaParaId,
            'vripara': vripara,
            'linked_books': linkedBooks
                .map((b) => {'type': b.type, 'book_id': b.bookId})
                .toList(),
            'commentaries': [],
            'note': 'Could not determine section number for para $mulaParaId',
          }),
        );
      }

      // Find matching sections in each linked book
      for (final link in linkedBooks) {
        debugPrint('[AI_QA] get_commentaries: searching "${link.bookId}" '
            'for section $sectionNumber...');
        final match = await jumpService.findHeadingInBook(
          link.bookId,
          sectionNumber,
          type: link.type,
        );

        if (match != null) {
          debugPrint('[AI_QA] get_commentaries: ✅ found at para ${match.paraId} '
              '- "${match.title}"');
          final content = await getParagraphContent({
            'book_id': link.bookId,
            'para_start': match.paraId,
            'para_end': match.paraId + 50,
          });

          commentaries.add({
            'type': link.type,
            'type_label': match.typeLabel,
            'book_id': link.bookId,
            'book_name': match.bookName,
            'section_title': match.title,
            'para_id': match.paraId,
            'content': content.success ? content.data : '{}',
          });
        }
      }

      debugPrint('[AI_QA] get_commentaries: ✅ ${commentaries.length} commentaries found');
      return ToolResult(
        success: true,
        data: _toJsonJson({
          'mula_book_id': mulaBookId,
          'mula_para_id': mulaParaId,
          'section_number': sectionNumber,
          'vripara': vripara,
          'linked_books': linkedBooks
              .map((b) => {'type': b.type, 'book_id': b.bookId})
              .toList(),
          'commentaries': commentaries,
        }),
      );
    } catch (e) {
      debugPrint('[AI_QA] get_commentaries: ❌ error: $e');
      return ToolResult(success: false, data: '{}', errorMessage: e.toString());
    }
  }
}

/// Riverpod provider for AiQaToolService.
final aiQaToolServiceProvider = Provider<AiQaToolService>((ref) {
  return AiQaToolService(ref);
});
