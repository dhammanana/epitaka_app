/// Service that executes tools for the AI Q&A feature against the local
/// Tipitaka SQLite database.
///
/// **Search strategy (BM25 + LIKE):**
/// 1. Try BM25 search via the `vec_chunks_fts` FTS5 index in `epitaka.db`
///    when it happens to be present (legacy databases may carry it).
/// 2. Fall back to LIKE-based keyword search (always available).
///
/// Each tool corresponds to a Gemini function declaration and is executed
/// when the small model requests it. Results are passed back to the model
/// as function responses.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_db_provider.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/pali_definition_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/pali_search_utils.dart' show normalizePaliFuzzy;
import '../../dpd/database/dpd_headword_extensions.dart';
import '../../dpd/providers/dpd_database_provider.dart';
import '../../reader/services/jump_service.dart';
import 'section_index_service.dart';

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

/// Maximum canon occurrences (`pali_definition` hits) returned per term.
const int kDictMaxCanonOccurrences = 15;

/// Maximum length of a DPD meaning sent to the model (plain text).
const int kDictMaxMeaningLength = 300;

/// Default/max result counts for the search tools. MCP clients SHOULD pass
/// a smaller `limit` (e.g. 10) — fewer hits means fewer heading-enrichment
/// queries and a response in seconds instead of tens of seconds.
const int kSearchDefaultLimit = 50;
const int kSearchMaxLimit = 50;

/// Max paragraph span per get_paragraph_content call (payload guard).
const int kParagraphMaxSpan = 100;

/// Parse an optional `limit`/`top_k` tool arg, clamped to [1, max].
int _parseLimit(dynamic raw, {int defaultValue = kSearchDefaultLimit}) {
  final v = raw is num
      ? raw.toInt()
      : int.tryParse('${raw ?? ''}') ?? defaultValue;
  if (v <= 0) return defaultValue;
  return v > kSearchMaxLimit ? kSearchMaxLimit : v;
}

/// Strip HTML tags from a DPD meaning and collapse whitespace so the
/// payload stays small (the DPD dictionary is a secondary source).
String _plainMeaning(String html) {
  if (html.isEmpty) return '';
  final text = html
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return text.length <= kDictMaxMeaningLength
      ? text
      : '${text.substring(0, kDictMaxMeaningLength)}…';
}

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
    final limit = _parseLimit(args['limit'] ?? args['top_k']);
    debugPrint('[AI_QA] search_tipitaka: query="$query" limit=$limit');
    if (query.trim().isEmpty) {
      return const ToolResult(
        success: false,
        data: '[]',
        errorMessage: 'Empty query',
      );
    }

    // 1. Try BM25 via Gavesana vec DB
    final bm25Result = await _searchBm25(query, limit: limit);
    if (bm25Result.success) {
      final parsed = jsonDecode(bm25Result.data) as List<dynamic>?;
      if (parsed != null && parsed.isNotEmpty) {
        debugPrint(
          '[AI_QA] search_tipitaka: ✅ BM25 => ${parsed.length} results',
        );
        final enriched = await _enrichWithHeadingChain(
          parsed.cast<Map<String, dynamic>>(),
        );
        return ToolResult(
          success: true,
          data: _toJsonString(enriched.take(limit).toList()),
        );
      }
    }

    debugPrint(
      '[AI_QA] search_tipitaka: BM25 returned no results, falling back to FTS/LIKE',
    );

    // 2. FTS fast path, then LIKE-based keyword search as last resort
    return _searchLike(query, limit: limit);
  }

  /// BM25 search using epitaka.db's `vec_chunks_fts` FTS5 table.
  ///
  /// Returns results with `book_id`, `para_id`, `line_id`, `text` and
  /// `book_name`, ordered by BM25 relevance (best first).
  ///
  /// Runs through the drift connection (background isolate), so the query
  /// never blocks the UI thread — the previous raw `sqlite3` connection
  /// executed synchronously on the main isolate and froze the app during
  /// AI searches.
  Future<ToolResult> _searchBm25(String query, {int limit = 50}) async {
    try {
      final epitakaDb = await _ref.read(epitakaDbProvider.future);

      // Verify vec_chunks_fts exists (legacy databases may lack it).
      final hasIndex = await epitakaDb
          .customSelect(
            "SELECT name FROM sqlite_master "
            "WHERE type='table' AND name='vec_chunks_fts'",
          )
          .get();
      if (hasIndex.isEmpty) {
        debugPrint('[AI_QA] _searchBm25: vec_chunks_fts not available');
        return const ToolResult(
          success: false,
          data: '[]',
          errorMessage:
              'BM25 index not available — falling back to LIKE search.',
        );
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
          success: false,
          data: '[]',
          errorMessage: 'No valid terms',
        );
      }

      // Search across ALL FTS5 columns (pali_text, english_text) via
      // table-level MATCH joined with vec_chunks for metadata.
      final rows = await epitakaDb
          .customSelect(
            'SELECT vc.chunk_id, vc.book_id, vc.start_para, vc.end_para, '
            'vc.start_line, vc.end_line, '
            'bm25(vec_chunks_fts) AS bm25_score '
            'FROM vec_chunks_fts '
            'JOIN vec_chunks vc ON vc.chunk_id = vec_chunks_fts.chunk_id '
            'WHERE vec_chunks_fts MATCH ? '
            'ORDER BY bm25_score ASC '
            'LIMIT ?',
            variables: [Variable.withString(terms), Variable.withInt(limit)],
          )
          .get();

      if (rows.isEmpty) {
        return const ToolResult(
          success: false,
          data: '[]',
          errorMessage: 'No BM25 matches',
        );
      }

      debugPrint(
        '[AI_QA] _searchBm25: ${rows.length} chunks matched, fetching texts...',
      );

      // ONE batched detail query for all chunks (the old per-chunk loop did
      // N sequential round-trips and dominated latency on slow devices).
      final chunkConds = <String>[];
      final chunkVars = <Variable>[];
      for (final row in rows) {
        chunkConds.add('(s.book_id = ? AND s.para_id >= ? AND s.para_id <= ?)');
        chunkVars.addAll([
          Variable.withString(row.data['book_id'] as String),
          Variable.withInt(row.data['start_para'] as int),
          Variable.withInt(row.data['end_para'] as int),
        ]);
      }
      final paliRows = await epitakaDb
          .customSelect(
            'SELECT s.book_id, s.para_id, s.line_id, s.pali, b.book_name '
            'FROM sentences s '
            'JOIN books b ON b.book_id = s.book_id '
            'WHERE ${chunkConds.join(' OR ')} '
            'ORDER BY s.book_id ASC, s.para_id ASC, s.line_id ASC',
            variables: chunkVars,
          )
          .get();

      // Index detail rows by book for O(1) chunk matching in rank order.
      final byBook = <String, List<QueryRow>>{};
      for (final pr in paliRows) {
        final bid = pr.data['book_id'] as String? ?? '';
        (byBook[bid] ??= []).add(pr);
      }

      final results = <Map<String, dynamic>>[];
      for (final row in rows) {
        final bookId = row.data['book_id'] as String;
        final startPara = row.data['start_para'] as int;
        final endPara = row.data['end_para'] as int;
        QueryRow? first;
        for (final pr in byBook[bookId] ?? const <QueryRow>[]) {
          final pid = pr.data['para_id'] as int? ?? 0;
          if (pid >= startPara && pid <= endPara) {
            first = pr;
            break;
          }
        }
        if (first != null) {
          results.add({
            'book_id': bookId,
            'book_name': (first.data['book_name'] as String?) ?? bookId,
            'para_id': first.data['para_id'] as int,
            'line_id': first.data['line_id'] as int,
            'text': (first.data['pali'] as String?) ?? '',
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

  /// FTS5 term list for the app_data.db `search_fts` indexes (same
  /// convention as the main search: quoted prefix terms). Callers join with
  /// AND (precise) and retry with OR (any term) on zero hits.
  List<String> _ftsTermList(String query) {
    return query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((w) => w.replaceAll('"', '').trim())
        .where((w) => w.length >= 2)
        .map((w) => '"$w"*')
        .toList();
  }

  /// Fast search via the app_data.db FTS5 indexes (`search_fts` for Pāli,
  /// `search_fts_<lang>` for translations) — the same indexes the main
  /// search UI uses, at BM25 speed instead of full-table LIKE scans.
  ///
  /// Returns null when the index is missing/unusable so the caller falls
  /// back to [_searchLikeInColumn]. A Pāli-only hit set that already fills
  /// [limit] skips the translation indexes entirely.
  Future<ToolResult?> _searchFts(
    String query, {
    Set<String>? bookIds,
    required int limit,
  }) async {
    try {
      final appDb = await _ref.read(appDbProvider.future);
      final hasPali = await appDb
          .customSelect(
            "SELECT name FROM sqlite_master "
            "WHERE type='table' AND name='search_fts'",
          )
          .get();
      if (hasPali.isEmpty) return null;
      final termList = _ftsTermList(query);
      if (termList.isEmpty) return null;
      final andTerms = termList.join(' AND ');
      final orTerms = termList.length > 1 ? termList.join(' OR ') : null;

      final scopeVars = <Variable>[];
      var scopeClause = '';
      if (bookIds != null && bookIds.isNotEmpty) {
        scopeClause = 'AND book_id IN (${bookIds.map((_) => '?').join(',')}) ';
        scopeVars.addAll(bookIds.map((b) => Variable.withString(b)));
      }

      Future<List<QueryRow>> runFts(String table, String column, String match) {
        return appDb
            .customSelect(
              'SELECT book_id, para_id, bm25($table) AS s '
              'FROM $table '
              'WHERE $column MATCH ? $scopeClause'
              'ORDER BY s LIMIT ?',
              variables: [
                Variable.withString(match),
                ...scopeVars,
                Variable.withInt(limit * 2),
              ],
            )
            .get();
      }

      // AND first (precise); on zero hits retry with OR (any term). A
      // multi-word query whose terms never co-occur in one paragraph would
      // otherwise miss FTS entirely and fall into the 20s+ LIKE full-scan.
      Future<({List<QueryRow> rows, bool relaxed})> runFtsSmart(
        String table,
        String column,
      ) async {
        final andRows = await runFts(table, column, andTerms);
        if (andRows.isNotEmpty || orTerms == null) {
          return (rows: andRows, relaxed: false);
        }
        try {
          final orRows = await runFts(table, column, orTerms);
          return (rows: orRows, relaxed: true);
        } catch (_) {
          return (rows: andRows, relaxed: false);
        }
      }

      final paliHit = await runFtsSmart('search_fts', 'pali_text');
      final paliRows = paliHit.rows;
      var relaxed = paliHit.relaxed;
      var rows = paliRows;
      var method = 'fts';
      if (paliRows.length < limit) {
        // Pāli didn't fill the page — scan translation indexes in parallel.
        final transFutures = <Future<({List<QueryRow> rows, bool relaxed})>>[];
        for (final lang in _activeTranslationLangs()) {
          transFutures.add(() async {
            final table = 'search_fts_$lang';
            try {
              final exists = await appDb
                  .customSelect(
                    "SELECT name FROM sqlite_master "
                    "WHERE type='table' AND name=?",
                    variables: [Variable.withString(table)],
                  )
                  .get();
              if (exists.isEmpty) {
                return (rows: const <QueryRow>[], relaxed: false);
              }
              return await runFtsSmart(table, 'translation_text');
            } catch (_) {
              return (rows: const <QueryRow>[], relaxed: false);
            }
          }());
        }
        final transHits = await Future.wait(transFutures);
        final seen = {
          for (final r in paliRows) '${r.data['book_id']}:${r.data['para_id']}',
        };
        final merged = [...paliRows];
        var usedTranslation = false;
        for (final hit in transHits) {
          if (hit.relaxed) relaxed = true;
          if (hit.rows.isNotEmpty) usedTranslation = true;
          for (final r in hit.rows) {
            if (seen.add('${r.data['book_id']}:${r.data['para_id']}')) {
              merged.add(r);
            }
          }
        }
        merged.sort(
          (a, b) => ((a.data['s'] as num?) ?? 0).compareTo(
            (b.data['s'] as num?) ?? 0,
          ),
        );
        rows = merged;
        if (usedTranslation) method = 'fts+translation';
        if (relaxed) method = '$method-or';
      } else if (relaxed) {
        method = 'fts-or';
      }

      if (rows.isEmpty) return null;

      // Resolve display text + book names in TWO batched queries.
      final top = rows.take(limit).toList();
      final conds = <String>[];
      final vars = <Variable>[];
      for (final r in top) {
        conds.add('(s.book_id = ? AND s.para_id = ?)');
        vars.addAll([
          Variable.withString(r.data['book_id'] as String),
          Variable.withInt(r.data['para_id'] as int),
        ]);
      }
      final epitakaDb = await _ref.read(epitakaDbProvider.future);
      final textRows = await epitakaDb
          .customSelect(
            'SELECT s.book_id, s.para_id, MIN(s.line_id) AS first_line_id, '
            'group_concat(s.pali, \' \') AS para_text, b.book_name '
            'FROM sentences s '
            'JOIN books b ON b.book_id = s.book_id '
            'WHERE ${conds.join(' OR ')} '
            'GROUP BY s.book_id, s.para_id',
            variables: vars,
          )
          .get();
      final byKey = {
        for (final r in textRows)
          '${r.data['book_id']}:${r.data['para_id']}': r,
      };

      final results = <Map<String, dynamic>>[];
      for (final r in top) {
        final bid = r.data['book_id'] as String? ?? '';
        final pid = r.data['para_id'] as int? ?? 0;
        final detail = byKey['$bid:$pid'];
        if (detail == null) continue;
        final text = (detail.data['para_text'] as String?) ?? '';
        results.add({
          'book_id': bid,
          'book_name': (detail.data['book_name'] as String?) ?? bid,
          'para_id': pid,
          'line_id': (detail.data['first_line_id'] as int?) ?? 1,
          'text': text.length <= 300 ? text : '${text.substring(0, 300)}…',
          'relevance': 1.0,
          'coverage': 1.0,
          'search_method': method,
        });
      }
      if (results.isEmpty) return null;

      debugPrint('[AI_QA] _searchFts: ✅ ${results.length} results ($method)');
      final enriched = await _enrichWithHeadingChain(results);
      return ToolResult(success: true, data: _toJsonString(enriched));
    } catch (e) {
      debugPrint('[AI_QA] _searchFts unavailable, LIKE fallback: $e');
      return null;
    }
  }

  /// LIKE-based keyword search (last resort when no FTS index is available).
  ///
  /// Searches the Pāli text AND the available translation text (so English
  /// or other-language terms match translations, not just the Pāli), with
  /// diacritic-insensitive matching (ā=a, ṃ=m …) in both the SQL pool and
  /// the final scoring.
  ///
  /// When [bookIds] is given (e.g. from search_by_category's resolved book
  /// filter), the search is SCOPED to those books inside SQL — a global
  /// book-ordered pool starves later books (S-*/D-*/M-*/Dhp sort after
  /// A-*/Abh-*), so post-filtering never reaches them.
  Future<ToolResult> _searchLike(
    String query, {
    Set<String>? bookIds,
    int limit = 50,
  }) async {
    try {
      // Fast path first: app_data.db `search_fts` FTS5 (para-level BM25,
      // milliseconds). Only the slow LIKE scan runs when the index is
      // missing — previously every MCP search paid the full-table scan.
      final ftsHit = await _searchFts(query, bookIds: bookIds, limit: limit);
      if (ftsHit != null) return ftsHit;

      final epitakaDb = await _ref.read(epitakaDbProvider.future);
      debugPrint(
        '[AI_QA] _searchLike: keywords="$query" '
        'scoped=${bookIds?.length ?? 0} books limit=$limit',
      );

      // 1. Pāli text (with the books join for book names).
      final results = await _searchLikeInColumn(
        epitakaDb,
        column: 'pali',
        query: query,
        bookIds: bookIds,
        joinBooks: true,
      );

      // 2. Translation text, so a term like "giving" that never appears in
      //    the Pāli can still find the passages that translate it. Same
      //    para_ids across DBs, so hits merge cleanly below.
      //    Skipped when Pāli alone already fills the page; translation DBs
      //    are scanned IN PARALLEL (separate connections) instead of one by
      //    one — previously each added a full sequential table scan.
      if (results.length < limit) {
        final langFutures = _activeTranslationLangs().map((lang) async {
          final transDb = await _ref.read(translationDbProvider(lang).future);
          if (transDb == null) return const <Map<String, dynamic>>[];
          return _searchLikeInColumn(
            transDb,
            column: 'translation',
            query: query,
            bookIds: bookIds,
            joinBooks: false,
          );
        }).toList();
        for (final hits in await Future.wait(langFutures)) {
          results.addAll(hits);
        }
      }

      // Deduplicate by (book_id, para_id) — a Pāli match wins over a
      // translation-only match of the same paragraph.
      final seen = <String>{};
      final merged = <Map<String, dynamic>>[];
      for (final r in results) {
        final bookId = r['book_id'] as String? ?? '';
        final paraId = r['para_id'] as int? ?? 0;
        if (bookId.isEmpty || paraId <= 0) continue;
        if (seen.add('$bookId:$paraId')) merged.add(r);
      }

      // Backfill book names for translation-only hits (no books join).
      final missingIds = merged
          .where((r) => (r['book_name'] as String? ?? '').isEmpty)
          .map((r) => r['book_id'] as String? ?? '')
          .where((b) => b.isNotEmpty)
          .toSet()
          .toList();
      if (missingIds.isNotEmpty) {
        final placeholders = missingIds.map((_) => '?').join(',');
        final bookRows = await epitakaDb
            .customSelect(
              'SELECT book_id, book_name FROM books '
              'WHERE book_id IN ($placeholders)',
              variables: missingIds.map((b) => Variable.withString(b)).toList(),
            )
            .get();
        final names = {
          for (final br in bookRows)
            br.data['book_id'] as String:
                (br.data['book_name'] as String?) ?? '',
        };
        for (final r in merged) {
          if ((r['book_name'] as String? ?? '').isEmpty) {
            r['book_name'] = names[r['book_id']] ?? r['book_id'];
          }
        }
      }

      // Rank: full keyword coverage first (a passage naming all requested
      // terms beats one naming a single term), then density, then para id.
      merged.sort((a, b) {
        final covCmp = ((b['coverage'] as num?) ?? 0).compareTo(
          (a['coverage'] as num?) ?? 0,
        );
        if (covCmp != 0) return covCmp;
        final relCmp = ((b['relevance'] as num?) ?? 0).compareTo(
          (a['relevance'] as num?) ?? 0,
        );
        if (relCmp != 0) return relCmp;
        return ((a['para_id'] as num?) ?? 0).compareTo(
          (b['para_id'] as num?) ?? 0,
        );
      });

      debugPrint('[AI_QA] _searchLike: ✅ ${merged.length} results');
      final enriched = await _enrichWithHeadingChain(
        merged.take(limit).toList(),
      );
      return ToolResult(success: true, data: _toJsonString(enriched));
    } catch (e) {
      debugPrint('[AI_QA] _searchLike: ❌ error: $e');
      return ToolResult(success: false, data: '[]', errorMessage: e.toString());
    }
  }

  /// Diacritic letters (→ base) that a [normalizePaliFuzzy]-style match
  /// treats as equal to their base letter.
  static const Set<String> _diacriticChars = {
    'ā',
    'ī',
    'ū',
    'ō',
    'ṅ',
    'ñ',
    'ṭ',
    'ḍ',
    'ṇ',
    'ḷ',
    'ṃ',
    'ṁ',
  };

  /// The base letters that can carry a Pāli diacritic (a→ā, n→ṅ/ñ/ṇ, …).
  static const Set<String> _diacriticBaseLetters = {
    'a',
    'i',
    'u',
    'o',
    'n',
    't',
    'd',
    'm',
    'l',
  };

  /// Escape a string for use inside a SQLite LIKE pattern.
  String _escapeLike(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');

  /// `%keyword%` LIKE pattern from a raw keyword.
  String _exactLikePattern(String keyword) =>
      '%${_escapeLike(keyword.toLowerCase())}%';

  /// Diacritic-loose variant of [keyword]: every diacritic letter AND every
  /// base letter that could carry a diacritic becomes a `_` wildcard, so
  /// "saṅkhāra" pools "sankhara" and vice versa (the exact pattern cannot
  /// cross that gap). Returns null when the pattern would be too generic
  /// (fewer than two literal letters) or the keyword had nothing to loosen.
  String? _looseLikePattern(String keyword) {
    final lower = keyword.toLowerCase();
    final buf = StringBuffer();
    var changed = false;
    for (final ch in lower.split('')) {
      if (_diacriticChars.contains(ch) || _diacriticBaseLetters.contains(ch)) {
        buf.write('_');
        changed = true;
      } else {
        buf.write(_escapeLike(ch));
      }
    }
    if (!changed) return null;
    final pattern = '%${buf.toString()}%';
    final literalLength = pattern
        .replaceAll('%', '')
        .replaceAll('_', '')
        .length;
    if (literalLength < 2) return null;
    return pattern;
  }

  /// Run the LIKE keyword search against ONE text source.
  ///
  /// [db] is the Pāli ([column]=`pali`, with the books join) or a
  /// translation database ([column]=`translation`, no books table).
  /// Paragraphs matching ANY keyword pattern are pooled (with a per-book
  /// cap so common terms cannot starve books whose IDs sort late) and then
  /// scored in Dart on diacritic-normalized text, so "sankhara" and
  /// "saṅkhāra" rank identically.
  Future<List<Map<String, dynamic>>> _searchLikeInColumn(
    GeneratedDatabase db, {
    required String column,
    required String query,
    Set<String>? bookIds,
    required bool joinBooks,
  }) async {
    // Tokenise the query into keywords (split on whitespace).
    final keywords = query
        .split(RegExp(r'\s+'))
        .map((w) => w.trim())
        .where((w) => w.length >= 3)
        .toSet()
        .toList();
    if (keywords.isEmpty) return const [];

    // Per keyword: exact pattern + diacritic-loose pattern, OR-joined. The
    // WHERE conditions are PARENTHESISED so an optional book scope applies
    // to EVERY keyword, not just the last one.
    final patternGroups = <List<String>>[];
    for (final kw in keywords) {
      final group = <String>[_exactLikePattern(kw)];
      final loose = _looseLikePattern(kw);
      if (loose != null && !group.contains(loose)) group.add(loose);
      patternGroups.add(group);
    }
    final conditions = patternGroups
        .map((g) => '(${g.map((_) => 'LOWER(s.$column) LIKE ?').join(' OR ')})')
        .join(' OR ');
    final likeParams = patternGroups.expand(
      (g) => g.map((p) => Variable.withString(p)),
    );

    final bookClause = (bookIds != null && bookIds.isNotEmpty)
        ? 'AND s.book_id IN (${bookIds.map((_) => '?').join(',')}) '
        : '';

    // Pool at PARAGRAPH level: group lines into whole paragraphs, then cap
    // at 150 paragraphs per book. A paragraph whose answer spans several
    // lines is scored as a whole, and no single paragraph is starved
    // because its book had 150+ matching LINES before it.
    final rows = await db
        .customSelect(
          '''
      SELECT * FROM (
        SELECT s.book_id, s.para_id,
               MIN(s.line_id) AS first_line_id,
               group_concat(s.$column, ' ') AS para_text
               ${joinBooks ? ', b.book_name' : ''},
               ROW_NUMBER() OVER (
                 PARTITION BY s.book_id
                 ORDER BY s.para_id
               ) AS rn
        FROM sentences s
        ${joinBooks ? 'JOIN books b ON b.book_id = s.book_id' : ''}
        WHERE ($conditions) $bookClause
        GROUP BY s.book_id, s.para_id
      ) WHERE rn <= 150
      ''',
          variables: [
            ...likeParams,
            ...(bookIds ?? const <String>{}).map((b) => Variable.withString(b)),
          ],
        )
        .get();

    final results = <Map<String, dynamic>>[];
    for (final row in rows) {
      final paraText = (row.data['para_text'] as String?) ?? '';
      if (paraText.isEmpty) continue;
      // Diacritic-normalized scoring: "sankhara" and "saṅkhāra" match.
      final normalizedText = normalizePaliFuzzy(paraText);
      if (normalizedText.isEmpty) continue;
      double score = 0;
      final matched = <String>{};
      for (final kw in keywords) {
        final needle = normalizePaliFuzzy(kw);
        if (needle.isEmpty) continue;
        var idx = 0;
        while (idx != -1) {
          idx = normalizedText.indexOf(needle, idx);
          if (idx != -1) {
            score += needle.length;
            matched.add(kw);
            idx += needle.length;
          }
        }
      }
      // A loose-pattern pool hit with no normalized match isn't relevant.
      if (score == 0) continue;
      final density = (score / normalizedText.length).clamp(0.0, 1.0);
      final coverage = matched.length / keywords.length;
      results.add({
        'book_id': (row.data['book_id'] as String?) ?? '',
        'book_name':
            (row.data['book_name'] as String?) ??
            ((row.data['book_id'] as String?) ?? ''),
        'para_id': (row.data['para_id'] as int?) ?? 0,
        'line_id': (row.data['first_line_id'] as int?) ?? 1,
        'text': paraText.length <= 300
            ? paraText
            : '${paraText.substring(0, 300)}…',
        'relevance': density,
        'coverage': coverage,
        'search_method': column == 'translation' ? 'translation' : 'like',
      });
    }
    return results;
  }

  /// Translation language codes to search alongside the Pāli text: the
  /// user's enabled translations, else the primary translation language.
  List<String> _activeTranslationLangs() {
    final settings = _ref.read(settingsProvider);
    if (settings.enabledTranslations.isNotEmpty) {
      return settings.enabledTranslations.toList();
    }
    return [settings.primaryTranslationLang];
  }

  // ── Tool 1c: search_by_category ───────────────────────────────────────

  /// Search the Tipitaka within specific book categories/nikayas.
  /// First resolves which books match the requested categories, then searches
  /// within those books only. Results are deduplicated across queries.
  Future<ToolResult> searchByCategory(Map<String, dynamic> args) async {
    final queries =
        (args['queries'] as List<dynamic>?)
            ?.map((q) => q.toString())
            .where((q) => q.trim().isNotEmpty)
            .toList() ??
        [];
    final categories =
        (args['categories'] as List<dynamic>?)
            ?.map((c) => c.toString().trim().toLowerCase())
            .where((c) => c.isNotEmpty)
            .toList() ??
        [];
    final nikayas =
        (args['nikayas'] as List<dynamic>?)
            ?.map((n) => n.toString().trim().toLowerCase())
            .where((n) => n.isNotEmpty)
            .toList() ??
        [];

    final limit = _parseLimit(args['limit'] ?? args['top_k']);

    debugPrint(
      '[AI_QA] search_by_category: ${queries.length} queries, '
      'categories=$categories, nikayas=$nikayas limit=$limit',
    );

    if (queries.isEmpty) {
      return const ToolResult(
        success: false,
        data: '[]',
        errorMessage: 'No queries provided',
      );
    }
    if (categories.isEmpty && nikayas.isEmpty) {
      return const ToolResult(
        success: false,
        data: '[]',
        errorMessage: 'At least one category or nikaya required',
      );
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
        final nikayaConditions = nikayas
            .map((n) => 'b.book_id LIKE ?')
            .join(' OR ');
        filterClauses.add('($nikayaConditions)');
        filterParams.addAll(nikayas.map((n) => '$n%'));
      }

      final filterSql = filterClauses.isNotEmpty
          ? 'AND ${filterClauses.join(' AND ')}'
          : '';

      // Get matching book IDs
      final bookRows = await epitakaDb
          .customSelect(
            'SELECT b.book_id, b.book_name, b.category '
            'FROM books b WHERE 1=1 $filterSql '
            'ORDER BY b.category, b.nikaya, b.book_id',
            variables: filterParams.map((p) => Variable.withString(p)).toList(),
          )
          .get();

      if (bookRows.isEmpty) {
        return const ToolResult(
          success: true,
          data: '[]',
          errorMessage: 'No books match the requested categories/nikayas',
        );
      }

      final validBookIds = bookRows
          .map((r) => r.data['book_id'] as String)
          .toSet();

      debugPrint(
        '[AI_QA] search_by_category: ${validBookIds.length} matching books',
      );

      // Execute ALL queries in PARALLEL — SCOPED to the resolved books.
      // (A global pool + post-filter starves books whose IDs sort late; a
      // scoped LIKE deterministically covers every requested book.)
      final results = await Future.wait(
        queries.map((q) => _searchLike(q, bookIds: validBookIds, limit: limit)),
      );

      // Merge and deduplicate (already scoped to the requested books).
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

      debugPrint(
        '[AI_QA] search_by_category: ✅ '
        '${merged.length} unique category-filtered results',
      );
      return ToolResult(
        success: true,
        data: _toJsonString(merged.take(limit).toList()),
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
    final queries =
        (args['queries'] as List<dynamic>?)
            ?.map((q) => q.toString())
            .where((q) => q.trim().isNotEmpty)
            .toList() ??
        [];
    final limit = _parseLimit(args['limit'] ?? args['top_k']);

    debugPrint(
      '[AI_QA] search_tipitaka_batch: ${queries.length} queries: '
      '${queries.join(" | ")} limit=$limit',
    );

    if (queries.isEmpty) {
      return const ToolResult(
        success: false,
        data: '[]',
        errorMessage: 'No queries provided',
      );
    }

    // Execute ALL queries in PARALLEL
    final results = await Future.wait(
      queries.map((q) => searchTipitaka({'query': q, 'limit': limit})),
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

    debugPrint(
      '[AI_QA] search_tipitaka_batch: ✅ ${merged.length} unique results from ${results.length} queries',
    );
    return ToolResult(
      success: true,
      data: _toJsonString(merged.take(limit).toList()),
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
          success: false,
          data: '[]',
          errorMessage: 'Missing book_id',
        );
      }

      final epitakaDb = await _ref.read(epitakaDbProvider.future);

      final rows = await epitakaDb
          .customSelect(
            'SELECT h.para_id, h.title, h.level, h.parent, h.sc_id, '
            'b.book_name '
            'FROM headings h '
            'JOIN books b ON b.book_id = h.book_id '
            'WHERE h.book_id = ? '
            'ORDER BY h.para_id ASC',
            variables: [Variable.withString(bookId)],
          )
          .get();

      final results = rows
          .map(
            (r) => {
              'para_id': r.data['para_id'] as int,
              'title': (r.data['title'] as String?) ?? '',
              'level': (r.data['level'] as int?) ?? 0,
              'parent': (r.data['parent'] as int?) ?? 0,
            },
          )
          .toList();

      final bookInfo = rows.isNotEmpty
          ? {
              'book_id': bookId,
              'book_name': (rows.first.data['book_name'] as String?) ?? bookId,
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
  ///
  /// Optional pagination (for MCP clients that truncate large payloads):
  /// `limit` (1–200, default = all), `offset`, plus `category` / `nikaya`
  /// filters. Paginated calls return
  /// `{books, total, limit, offset, has_more}`; unpaginated calls keep the
  /// legacy bare-list shape Vīmaṃsā expects.
  Future<ToolResult> getBooks(Map<String, dynamic> args) async {
    try {
      final paginated =
          args['limit'] != null ||
          args['offset'] != null ||
          args['category'] != null ||
          args['nikaya'] != null;
      final rawLimit = args['limit'];
      final limit = rawLimit == null
          ? 200
          : ((rawLimit is num
                    ? rawLimit.toInt()
                    : int.tryParse('$rawLimit') ?? 200))
                .clamp(1, 200);
      final rawOffset = args['offset'];
      final offset = rawOffset == null
          ? 0
          : (rawOffset is num
                ? rawOffset.toInt()
                : int.tryParse('$rawOffset') ?? 0);
      final category = (args['category'] as String?)?.trim().toLowerCase();
      final nikaya = (args['nikaya'] as String?)?.trim().toLowerCase();
      debugPrint(
        '[AI_QA] get_books: paginated=$paginated limit=$limit offset=$offset',
      );
      final epitakaDb = await _ref.read(epitakaDbProvider.future);

      final clauses = <String>[];
      final filterVars = <Variable>[];
      if (category != null && category.isNotEmpty) {
        clauses.add('category = ?');
        filterVars.add(Variable.withString(category));
      }
      if (nikaya != null && nikaya.isNotEmpty) {
        clauses.add('(nikaya = ? OR book_id LIKE ?)');
        filterVars.addAll([
          Variable.withString(nikaya),
          Variable.withString('$nikaya%'),
        ]);
      }
      final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')} ';

      final totalRows = await epitakaDb
          .customSelect(
            'SELECT COUNT(*) AS cnt FROM books $where',
            variables: filterVars,
          )
          .get();
      final total = (totalRows.first.data['cnt'] as int?) ?? 0;

      final rows = await epitakaDb
          .customSelect(
            'SELECT book_id, book_name, category, nikaya, sub_nikaya, '
            'mula_ref, attha_ref, tika_ref '
            'FROM books '
            '$where'
            'ORDER BY category, nikaya, sub_nikaya, book_id ASC '
            'LIMIT ? OFFSET ?',
            variables: [
              ...filterVars,
              Variable.withInt(paginated ? limit : total + 1),
              Variable.withInt(paginated ? (offset < 0 ? 0 : offset) : 0),
            ],
          )
          .get();

      debugPrint('[AI_QA] get_books: ✅ ${rows.length}/$total books');
      final results = rows
          .map(
            (r) => {
              'book_id': (r.data['book_id'] as String?) ?? '',
              'book_name': (r.data['book_name'] as String?) ?? '',
              'category': (r.data['category'] as String?) ?? '',
              'nikaya': (r.data['nikaya'] as String?) ?? '',
              'sub_nikaya': (r.data['sub_nikaya'] as String?) ?? '',
              'has_mula': (r.data['mula_ref'] as String?)?.isNotEmpty ?? false,
              'has_attha':
                  (r.data['attha_ref'] as String?)?.isNotEmpty ?? false,
              'has_tika': (r.data['tika_ref'] as String?)?.isNotEmpty ?? false,
            },
          )
          .toList();

      if (!paginated) {
        return ToolResult(success: true, data: _toJsonString(results));
      }
      return ToolResult(
        success: true,
        data: _toJsonJson({
          'books': results,
          'total': total,
          'limit': limit,
          'offset': offset < 0 ? 0 : offset,
          'has_more': offset + results.length < total,
        }),
      );
    } catch (e) {
      return ToolResult(success: false, data: '[]', errorMessage: e.toString());
    }
  }

  // ── Tool 4: get_paragraph_content ────────────────────────────────────

  /// Get the content of a range of paragraphs from a book.
  ///
  /// The span is clamped to [kParagraphMaxSpan] paras so one oversized call
  /// cannot produce a multi-MB payload that stalls the MCP transport.
  Future<ToolResult> getParagraphContent(Map<String, dynamic> args) async {
    try {
      final bookId = (args['book_id'] as String?) ?? '';
      final paraStart = (args['para_start'] as num?)?.toInt() ?? 0;
      var paraEnd = (args['para_end'] as num?)?.toInt() ?? paraStart;
      if (paraEnd - paraStart >= kParagraphMaxSpan) {
        paraEnd = paraStart + kParagraphMaxSpan - 1;
        debugPrint(
          '[AI_QA] get_paragraph_content: span clamped to $kParagraphMaxSpan',
        );
      }

      debugPrint(
        '[AI_QA] get_paragraph_content: book_id="$bookId", '
        'para=$paraStart–$paraEnd',
      );

      if (bookId.isEmpty) {
        return const ToolResult(
          success: false,
          data: '[]',
          errorMessage: 'Missing book_id',
        );
      }

      final epitakaDb = await _ref.read(epitakaDbProvider.future);

      final rows = await epitakaDb
          .customSelect(
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
          )
          .get();

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

      final paragraphs =
          grouped.entries
              .map(
                (e) => {
                  'para_id': e.key,
                  'lines': e.value,
                  'full_text': e.value.map((l) => l['pali']).join(' '),
                },
              )
              .toList()
            ..sort(
              (a, b) => (a['para_id'] as int).compareTo(b['para_id'] as int),
            );

      final bookName = rows.isNotEmpty
          ? (rows.first.data['book_name'] as String? ?? bookId)
          : bookId;

      debugPrint(
        '[AI_QA] get_paragraph_content: ✅ '
        '${paragraphs.length} paragraphs, ${rows.length} lines',
      );
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
        success: false,
        data: '[]',
        errorMessage: 'No ranges provided',
      );
    }

    // Execute ALL paragraph fetches in PARALLEL
    final results = await Future.wait(
      ranges.map(
        (r) => getParagraphContent({
          'book_id': (r as Map)['book_id'] as String? ?? '',
          'para_start': (r['para_start'] as num?)?.toInt() ?? 0,
          'para_end': (r['para_end'] as num?)?.toInt() ?? 0,
        }),
      ),
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

    debugPrint(
      '[AI_QA] get_paragraph_content_batch: ✅ '
      '${contents.length}/${ranges.length} ranges fetched ($totalChars chars)',
    );
    return ToolResult(success: true, data: _toJsonString(contents));
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

      debugPrint(
        '[AI_QA] get_commentaries: mula_book_id="$mulaBookId", '
        'mula_para_id=$mulaParaId',
      );

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
      debugPrint(
        '[AI_QA] get_commentaries: ${linkedBooks.length} linked books',
      );
      for (final link in linkedBooks) {
        debugPrint('[AI_QA] get_commentaries:   ${link.type} → ${link.bookId}');
      }

      // Get the vripara for this paragraph (used for fallback matching)
      String? vripara;
      final vriparaRows = await epitakaDb
          .customSelect(
            'SELECT vripara FROM sentences '
            'WHERE book_id = ? AND para_id = ? AND vripara IS NOT NULL '
            'LIMIT 1',
            variables: [
              Variable.withString(mulaBookId),
              Variable.withInt(mulaParaId),
            ],
          )
          .get();
      if (vriparaRows.isNotEmpty) {
        vripara = vriparaRows.first.data['vripara'] as String?;
        debugPrint('[AI_QA] get_commentaries: vripara="$vripara"');
      } else {
        debugPrint(
          '[AI_QA] get_commentaries: no vripara found for para $mulaParaId',
        );
      }

      // If no linked books, try using vripara to find related texts
      if (linkedBooks.isEmpty) {
        if (vripara != null && vripara.trim().isNotEmpty) {
          final vriparaSearchRows = await epitakaDb
              .customSelect(
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
              )
              .get();

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
      final sectionNumber = await jumpService.getSectionNumber(
        mulaBookId,
        mulaParaId,
      );

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
        debugPrint(
          '[AI_QA] get_commentaries: searching "${link.bookId}" '
          'for section $sectionNumber...',
        );
        final match = await jumpService.findHeadingInBook(
          link.bookId,
          sectionNumber,
          type: link.type,
        );

        if (match != null) {
          debugPrint(
            '[AI_QA] get_commentaries: ✅ found at para ${match.paraId} '
            '- "${match.title}"',
          );
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

      debugPrint(
        '[AI_QA] get_commentaries: ✅ ${commentaries.length} commentaries found',
      );
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

  // ── Heading-chain enrichment (Layer 0, §4.2) ──────────────────────────

  /// Per-book headings cache (para_id/title/parent, ordered). Headings are
  /// static at runtime, so one `SELECT ... WHERE book_id=?` per book per
  /// session replaces the old per-hit recursive CTE (up to 60 sequential
  /// round-trips per search — the #2 latency driver after LIKE scans).
  final Map<String, List<Map<String, dynamic>>> _headingsCache = {};

  Future<List<Map<String, dynamic>>> _headingsForBook(
    GeneratedDatabase db,
    String bookId,
  ) async {
    final cached = _headingsCache[bookId];
    if (cached != null) return cached;
    try {
      final rows = await db
          .customSelect(
            'SELECT para_id, title, parent FROM headings '
            'WHERE book_id = ? ORDER BY para_id ASC',
            variables: [Variable.withString(bookId)],
          )
          .get();
      final list = rows
          .map(
            (r) => {
              'para_id': r.data['para_id'] as int? ?? 0,
              'title': (r.data['title'] as String?) ?? '',
              'parent': r.data['parent'] as int? ?? 0,
            },
          )
          .toList();
      _headingsCache[bookId] = list;
      return list;
    } catch (_) {
      return const [];
    }
  }

  /// Walk a cached heading list: nearest heading at/before [paraId], then
  /// up the parent chain. Returns (display titles, heading para_ids).
  (List<String>, List<int>) _chainFor(
    List<Map<String, dynamic>> headings,
    int paraId,
  ) {
    var idx = -1;
    for (var i = 0; i < headings.length; i++) {
      if ((headings[i]['para_id'] as int) <= paraId) {
        idx = i;
      } else {
        break;
      }
    }
    if (idx < 0) return (const [], const []);
    final byId = <int, Map<String, dynamic>>{
      for (final h in headings) h['para_id'] as int: h,
    };
    final chain = <String>[];
    final ids = <int>[];
    var cur = headings[idx];
    final seen = <int>{};
    while (true) {
      final pid = cur['para_id'] as int;
      if (!seen.add(pid)) break;
      final title = (cur['title'] as String).trim();
      if (title.isNotEmpty) {
        chain.insert(0, title);
        ids.insert(0, pid);
      }
      final parent = cur['parent'] as int;
      final next = byId[parent];
      if (parent <= 0 || next == null) break;
      cur = next;
    }
    return (chain, ids);
  }

  /// Add `heading_chain` (Pāli titles) and `heading_chain_en` (English
  /// titles) to every search hit so the model sees *where* each hit lives
  /// in the canon hierarchy without an extra `get_headings` call.
  ///
  /// One cached headings fetch per book (parallel) + one batched English
  /// lookup per book — no per-hit queries.
  Future<List<Map<String, dynamic>>> _enrichWithHeadingChain(
    List<Map<String, dynamic>> results,
  ) async {
    if (results.isEmpty) return results;
    try {
      final epitakaDb = await _ref.read(epitakaDbProvider.future);
      final enDb = await _ref.read(translationDbProvider('en').future);

      // Collect heading para ids per book for batched English lookup.
      final enLookupIds = <String, Set<int>>{};
      final resultBookIds = <int, String>{};
      final resultHeadingIds = <int, List<int>>{};

      // Fetch each distinct book's headings ONCE, in parallel.
      final bookIds = <String>{
        for (final r in results) (r['book_id'] as String?) ?? '',
      }..remove('');
      final headingLists = await Future.wait(
        bookIds.map((b) => _headingsForBook(epitakaDb, b)),
      );
      final byBook = Map<String, List<Map<String, dynamic>>>.fromIterables(
        bookIds,
        headingLists,
      );

      for (int i = 0; i < results.length; i++) {
        final r = results[i];
        final bookId = r['book_id'] as String? ?? '';
        final paraId = r['para_id'] as int? ?? 0;
        if (bookId.isEmpty || paraId <= 0) continue;

        try {
          final headings = byBook[bookId] ?? const [];
          if (headings.isEmpty) continue;
          final (chain, headingIds) = _chainFor(headings, paraId);
          if (chain.isNotEmpty) r['heading_chain'] = chain;

          if (enDb != null && headingIds.isNotEmpty) {
            resultBookIds[i] = bookId;
            resultHeadingIds[i] = headingIds;
            enLookupIds.putIfAbsent(bookId, () => <int>{}).addAll(headingIds);
          }
        } catch (_) {
          // Best-effort: keep the hit even if its chain cannot be resolved.
        }
      }

      // Batched English title lookup per book.
      if (enDb != null && enLookupIds.isNotEmpty) {
        final enTitles = <String, String>{}; // 'bookId:paraId' -> title
        for (final entry in enLookupIds.entries) {
          final ids = entry.value.toList();
          if (ids.isEmpty) continue;
          try {
            final placeholders = ids.map((_) => '?').join(',');
            final rows = await enDb
                .customSelect(
                  'SELECT para_id, translation FROM sentences '
                  'WHERE book_id = ? AND para_id IN ($placeholders) '
                  'ORDER BY para_id ASC, line_id ASC',
                  variables: [
                    Variable.withString(entry.key),
                    ...ids.map((i) => Variable.withInt(i)),
                  ],
                )
                .get();
            for (final row in rows) {
              final t = (row.data['translation'] as String? ?? '').trim();
              if (t.isNotEmpty) {
                enTitles['${entry.key}:${row.data['para_id']}'] = t;
              }
            }
          } catch (_) {}
        }

        for (int i = 0; i < results.length; i++) {
          final bookId = resultBookIds[i];
          if (bookId == null) continue;
          final headingIds = resultHeadingIds[i];
          if (headingIds == null) continue;
          final enChain = <String>[];
          for (final hid in headingIds) {
            final t = enTitles['$bookId:$hid'];
            if (t != null && t.isNotEmpty) enChain.add(t);
          }
          if (enChain.isNotEmpty) results[i]['heading_chain_en'] = enChain;
        }
      }
    } catch (e) {
      debugPrint('[AI_QA] _enrichWithHeadingChain: error $e');
    }
    return results;
  }

  // ── Tool 6b: search_sections (Layer 1 — section summary index) ───────

  /// Search section/sutta TITLES (plus extractive summaries) across the
  /// whole canon, backed by `section_summaries_fts` (built lazily by
  /// [SectionIndexService]). This is the AI-navigable "map" of the canon:
  /// use it FIRST for concept questions to discover WHICH suttas discuss a
  /// topic, then open them with get_paragraph_content.
  Future<ToolResult> searchSections(Map<String, dynamic> args) async {
    final query = (args['query'] as String?) ?? '';
    final limit = _parseLimit(args['limit'] ?? args['top_k'], defaultValue: 20);
    debugPrint('[AI_QA] search_sections: query="$query" limit=$limit');
    if (query.trim().isEmpty) {
      return const ToolResult(
        success: false,
        data: '{}',
        errorMessage: 'Empty query',
      );
    }

    try {
      final appDb = await _ref.read(appDbProvider.future);
      final sectionService = _ref.read(sectionIndexServiceProvider);
      // Lazy-build the section index on first use (~seconds for the canon).
      await sectionService.ensureIndex();

      // FTS5 prefix MATCH query (mirrors _searchBm25 term-builder):
      // lowercase, quote/escape each term, add prefix `*`, OR-joined.
      final terms = query
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty && w.length >= 2)
          .map((w) {
            final safe = w.replaceAll('"', '""');
            return '"$safe"*';
          })
          .join(' ');

      if (terms.isEmpty) {
        return const ToolResult(
          success: false,
          data: '{}',
          errorMessage: 'No valid terms',
        );
      }

      final rows = await appDb
          .customSelect(
            'SELECT s.book_id, s.para_start, s.para_end, s.title, s.title_en, '
            '       s.path, s.summary, s.summary_en, '
            '       bm25(section_summaries_fts, 0.0, 0.0, 10.0, 5.0, 1.0, '
            '            1.0, 1.0) AS score '
            'FROM section_summaries_fts '
            'JOIN section_summaries s '
            '  ON s.book_id = section_summaries_fts.book_id '
            ' AND s.para_start = section_summaries_fts.para_start '
            'WHERE section_summaries_fts MATCH ? '
            'ORDER BY score ASC '
            'LIMIT ?',
            variables: [Variable.withString(terms), Variable.withInt(limit)],
          )
          .get();

      if (rows.isEmpty) {
        return ToolResult(
          success: true,
          data: _toJsonJson({'query': query, 'results': []}),
        );
      }

      // Resolve book names in ONE batch query.
      final bookIds = rows
          .map((r) => r.data['book_id'] as String)
          .toSet()
          .toList();
      final bookNames = <String, String>{};
      if (bookIds.isNotEmpty) {
        try {
          final epitakaDb = await _ref.read(epitakaDbProvider.future);
          final placeholders = bookIds.map((_) => '?').join(',');
          final bookRows = await epitakaDb
              .customSelect(
                'SELECT book_id, book_name FROM books '
                'WHERE book_id IN ($placeholders)',
                variables: bookIds.map((b) => Variable.withString(b)).toList(),
              )
              .get();
          for (final br in bookRows) {
            bookNames[br.data['book_id'] as String] =
                (br.data['book_name'] as String?) ?? '';
          }
        } catch (_) {}
      }

      final results = rows.map((r) {
        final bid = r.data['book_id'] as String;
        final paraStart = r.data['para_start'] as int;
        return {
          'book_id': bid,
          // para_id kept for backward compatibility with the model's
          // habit of passing it to get_paragraph_content.
          'para_id': paraStart,
          'para_start': paraStart,
          'para_end': r.data['para_end'] as int,
          'title': (r.data['title'] as String?) ?? '',
          'title_en': (r.data['title_en'] as String?) ?? '',
          'path': (r.data['path'] as String?) ?? '',
          'book_name': bookNames[bid] ?? bid,
          'summary': (r.data['summary'] as String?) ?? '',
          'summary_en': (r.data['summary_en'] as String?) ?? '',
        };
      }).toList();

      debugPrint('[AI_QA] search_sections: ✅ ${results.length} sections');
      return ToolResult(
        success: true,
        data: _toJsonJson({'query': query, 'results': results}),
      );
    } catch (e) {
      debugPrint('[AI_QA] search_sections: ❌ error: $e');
      return ToolResult(
        success: false,
        data: '{}',
        errorMessage: 'search_sections error: $e',
      );
    }
  }

  // ── Tool 6c: get_section (Layer 1 — browse the map) ───────────────────

  /// Read one section's summary plus its direct child sections and its
  /// parent section, letting the model BROWSE the canon hierarchy
  /// (vagga → sutta) without dumping a whole book's headings.
  Future<ToolResult> getSection(Map<String, dynamic> args) async {
    final bookId = (args['book_id'] as String?) ?? '';
    final paraStart = (args['para_start'] as num?)?.toInt() ?? 0;
    debugPrint('[AI_QA] get_section: book_id="$bookId", para_start=$paraStart');

    if (bookId.isEmpty || paraStart <= 0) {
      return const ToolResult(
        success: false,
        data: '{}',
        errorMessage: 'Missing book_id/para_start',
      );
    }

    try {
      final sectionService = _ref.read(sectionIndexServiceProvider);
      await sectionService.ensureIndex();
      final data = await sectionService.getSection(bookId, paraStart);

      if (data == null) {
        return ToolResult(
          success: true,
          data: _toJsonJson({
            'book_id': bookId,
            'para_start': paraStart,
            'error': 'Section not found. Try search_sections first.',
          }),
        );
      }

      debugPrint(
        '[AI_QA] get_section: ✅ '
        '${(data['children'] as List).length} children',
      );
      return ToolResult(success: true, data: _toJsonJson(data));
    } catch (e) {
      debugPrint('[AI_QA] get_section: ❌ error: $e');
      return ToolResult(
        success: false,
        data: '{}',
        errorMessage: 'get_section error: $e',
      );
    }
  }

  // ── Tool 7b: get_dictionary ───────────────────────────────────────────

  /// Definition (DPD dictionary) plus canon occurrences (`pali_definition`
  /// table) for a Pāli term.
  ///
  /// The canon occurrences reuse the app dictionary's own search
  /// ([paliDefinitionProvider]): the term is stemmed, its trailing vowel is
  /// dropped when long, then `word LIKE prefix%` — so variant spellings
  /// (sandhi forms etc.) are found. Each occurrence carries the source Pāli
  /// sentence plus up to 3 lines of context (one before + one after) with
  /// the translation when available.
  ///
  /// Both lookups are best-effort: the DPD database may not be installed,
  /// and `pali_definition` may be empty — partial results are returned
  /// instead of failing the whole tool.
  Future<ToolResult> getDictionary(Map<String, dynamic> args) async {
    final term = (args['term'] as String?)?.trim() ?? '';
    debugPrint('[AI_QA] get_dictionary: term="$term"');
    if (term.isEmpty) {
      return const ToolResult(
        success: false,
        data: '{}',
        errorMessage: 'Empty term',
      );
    }

    final result = <String, dynamic>{
      'term': term,
      'lookups': <Map<String, dynamic>>[],
      'canon_occurrences': <Map<String, dynamic>>[],
    };

    // 1. DPD dictionary: exact lookup first, then prefix fallback.
    try {
      final dao = await _ref.read(dpdDaoProvider.future);

      // An exact row wins; otherwise up to five keys that start with the term.
      final row = await dao.getLookupRow(term);
      final keys = row != null
          ? [row.lookupKey]
          : await dao.searchLookupKeysPrefix(term, limit: 5);

      final lookupResults = <Map<String, dynamic>>[];
      for (final key in keys) {
        final headwords = await dao.searchExact(key);
        lookupResults.add({
          'lookup_key': key,
          'headwords': headwords.map((hw) {
            final h = hw.headword;
            final meaning = h.meaning1?.isNotEmpty == true
                ? h.meaning1!
                : (h.meaning2 ?? '');
            final construction = h.constructionSummary;
            return {
              'id': h.id,
              'lemma': h.lemmaClean,
              'meaning': _plainMeaning(
                construction.isEmpty ? meaning : '$meaning [$construction]',
              ),
            };
          }).toList(),
        });
      }
      result['lookups'] = lookupResults;
    } catch (e) {
      debugPrint('[AI_QA] get_dictionary: DPD lookup unavailable: $e');
      // Empty lookups alone read as "the word is unknown". The note goes to
      // the model and to MCP clients, so it names no file path.
      result['dpd_error'] = e is DpdUnavailable
          ? switch (e.state.status) {
              DpdDatabaseStatus.notInstalled => 'DPD database not installed',
              DpdDatabaseStatus.unsupportedSchema =>
                'DPD database not supported by this version of ePitaka',
              DpdDatabaseStatus.ready => 'DPD database unavailable',
            }
          : 'DPD lookup failed (${e.runtimeType})';
    }

    // 2. Canon occurrences from pali_definition — the SAME search the app
    //    dictionary uses (see [paliDefinitionProvider]): stem the term,
    //    drop the trailing vowel when the stem is long, then prefix-match
    //    `word LIKE prefix%`. Each hit is linked to its source sentence and
    //    up to 3 lines of surrounding context.
    try {
      final defs = await _ref.read(paliDefinitionProvider(term).future);
      result['canon_occurrences'] = defs.take(kDictMaxCanonOccurrences).map((
        d,
      ) {
        final context = <String>[
          ...d.beforeLines,
          d.pali,
          ...d.afterLines,
        ].where((l) => l.trim().isNotEmpty).toList();
        return {
          'word': d.entry.word,
          'plain': d.entry.plain,
          'ending': d.entry.ending,
          'book_id': d.entry.bookId,
          'para_id': d.entry.paraId,
          'line_id': d.entry.lineId,
          'pali': d.pali,
          'translation': d.translation,
          'context': context,
        };
      }).toList();
    } catch (e) {
      debugPrint('[AI_QA] get_dictionary: pali_definition query failed: $e');
    }

    debugPrint(
      '[AI_QA] get_dictionary: ✅ ${(result['lookups'] as List).length} '
      'lookups, ${(result['canon_occurrences'] as List).length} occurrences',
    );
    return ToolResult(success: true, data: _toJsonJson(result));
  }

  // ── Tool 7c: get_dictionary_batch ─────────────────────────────────────

  /// Look up MULTIPLE Pāli terms in ONE call (parallel), returning the
  /// merged per-term results.
  ///
  /// Every `get_dictionary` call costs a full tool-model API round-trip, so
  /// when several terms must be explained (e.g. the key words of a sutta)
  /// the model should batch them here instead of looping one-by-one.
  Future<ToolResult> getDictionaryBatch(Map<String, dynamic> args) async {
    final terms =
        (args['terms'] as List<dynamic>?)
            ?.map((t) => t.toString().trim())
            .where((t) => t.isNotEmpty)
            .toList() ??
        [];

    debugPrint(
      '[AI_QA] get_dictionary_batch: ${terms.length} terms: '
      '${terms.join(" | ")}',
    );

    if (terms.isEmpty) {
      return const ToolResult(
        success: false,
        data: '[]',
        errorMessage: 'No terms provided',
      );
    }

    // Execute ALL lookups in PARALLEL.
    final results = await Future.wait(
      terms.map((t) => getDictionary({'term': t})),
    );

    final entries = <Map<String, dynamic>>[];
    for (int i = 0; i < terms.length; i++) {
      final r = results[i];
      if (!r.success) continue;
      try {
        final parsed = jsonDecode(r.data) as Map<String, dynamic>;
        parsed['term'] = terms[i];
        entries.add(parsed);
      } catch (_) {}
    }

    debugPrint(
      '[AI_QA] get_dictionary_batch: ✅ '
      '${entries.length}/${terms.length} terms resolved',
    );
    return ToolResult(success: true, data: _toJsonString(entries));
  }
}

/// Riverpod provider for AiQaToolService.
final aiQaToolServiceProvider = Provider<AiQaToolService>((ref) {
  return AiQaToolService(ref);
});
