import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// Row from dpd_lookup table.
class DpdLookupRow {
  final String lookupKey;
  final List<int> headwords; // parsed JSON array of ints
  final List<String> deconstructor; // parsed JSON array of strings

  const DpdLookupRow({
    required this.lookupKey,
    required this.headwords,
    required this.deconstructor,
  });
}

/// Row from dpd_headwords table.
class DpdHeadwordRow {
  final int id;
  final String lemma1;
  final String? meaningHtml;
  final String? antonym;
  final String? synonym;
  final String? stem;
  final String? pattern;

  const DpdHeadwordRow({
    required this.id,
    required this.lemma1,
    this.meaningHtml,
    this.antonym,
    this.synonym,
    this.stem,
    this.pattern,
  });

  /// Clean lemma_1 by removing trailing id suffix like " 1.1", " 2.1" etc.
  String get cleanLemma1 {
    return lemma1.replaceAll(RegExp(r'\s+[\d\.]+$'), '').trim();
  }
}

/// A parsed deconstruction candidate with its component tokens.
class DeconstructionCandidate {
  final String raw;
  final List<String> tokens;

  const DeconstructionCandidate({
    required this.raw,
    required this.tokens,
  });

  factory DeconstructionCandidate.parse(String line) {
    return DeconstructionCandidate(
      raw: line,
      tokens: line
          .split('+')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
    );
  }
}

/// Raw SQL database for the DPD dictionary (dpd-dictionary.db).
///
/// This database has two tables:
/// - `dpd_lookup` (lookup_key TEXT, headwords TEXT JSON, deconstructor TEXT JSON)
/// - `dpd_headwords` (id INTEGER PK, lemma_1 TEXT, meaning_html TEXT, ...)
class DpdDictionaryDatabase {
  final Database _db;

  // ── Query memoization ─────────────────────────────────────────────
  //
  // The dictionary sheet re-queries the same word repeatedly while the user
  // edits the search box (each debounced keystroke rebuilds the lookup), and
  // the deconstructor sub-lookups hit the same headword rows over and over.
  // The DB is effectively read-only during a session, so memoizing query
  // results — keyed by the normalized query — makes repeat lookups instant
  // instead of re-parsing the same SQLite rows on the main thread.
  final Map<String, DpdLookupRow?> _lookupCache = {};
  final Map<String, List<DpdLookupRow>> _prefixCache = {};
  final Map<String, List<DpdHeadwordRow>> _headwordsCache = {};
  static const int _cacheCap = 500;

  DpdDictionaryDatabase(this._db);

  /// Drop all memoized query results. Call after the underlying DB file has
  /// been replaced (e.g. a core-asset re-download) so stale rows are never
  /// served from the caches.
  void clearCaches() {
    _lookupCache.clear();
    _prefixCache.clear();
    _headwordsCache.clear();
  }

  /// Clean up resources.
  void dispose() {
    _db.dispose();
  }

  /// Bounded FIFO eviction for [cache].
  static void _trim<T>(Map<String, T> cache) {
    while (cache.length >= _cacheCap) {
      cache.remove(cache.keys.first);
    }
  }

  // ── Open ──────────────────────────────────────────────────────────

  /// Open dpd-dictionary.db from the given [dbPath].
  static Future<DpdDictionaryDatabase> open(String dbPath) async {
    final file = File(dbPath);
    if (!await file.exists()) {
      throw Exception('DPD dictionary database not found at $dbPath');
    }
    final db = sqlite3.open(dbPath);
    db.execute('PRAGMA journal_mode=WAL');
    db.execute('PRAGMA foreign_keys=ON');
    return DpdDictionaryDatabase(db);
  }

  // ── Lookup queries ────────────────────────────────────────────────

  /// Exact lookup by key. Returns null if not found. Memoized per key.
  DpdLookupRow? getLookup(String key) {
    final normalized = key.trim().toLowerCase();
    final cached = _lookupCache[normalized];
    if (cached != null || _lookupCache.containsKey(normalized)) {
      return cached;
    }
    final result = _db.select(
      'SELECT lookup_key, headwords, deconstructor FROM dpd_lookup WHERE lookup_key = ?',
      [normalized],
    );
    final row = result.isEmpty ? null : _parseLookupRow(result.first);
    _trim(_lookupCache);
    _lookupCache[normalized] = row;
    return row;
  }

  /// Prefix search on the lookup table. Returns rows matching the prefix.
  /// Memoized per (prefix, limit) pair.
  List<DpdLookupRow> searchLookup(String prefix, {int limit = 25}) {
    final normalized = prefix.trim().toLowerCase();
    final cacheKey = '$normalized\u0000$limit';
    final cached = _prefixCache[cacheKey];
    if (cached != null) return cached;

    final pattern = '$normalized%';
    final results = _db.select(
      'SELECT lookup_key, headwords, deconstructor FROM dpd_lookup WHERE lookup_key LIKE ? LIMIT ?',
      [pattern, limit],
    );
    final rows = results.map(_parseLookupRow).toList();
    _trim(_prefixCache);
    _prefixCache[cacheKey] = rows;
    return rows;
  }

  // ── Headwords queries ─────────────────────────────────────────────

  /// Get a single headword by ID. Memoized per id.
  DpdHeadwordRow? getHeadword(int id) {
    final rows = getHeadwordsByIds([id]);
    return rows.isEmpty ? null : rows.first;
  }

  /// Get multiple headwords by IDs. Memoized per sorted-id key.
  List<DpdHeadwordRow> getHeadwordsByIds(List<int> ids) {
    if (ids.isEmpty) return [];
    final sorted = [...ids]..sort();
    final cacheKey = sorted.join(',');
    final cached = _headwordsCache[cacheKey];
    if (cached != null) return cached;

    // SQLite supports up to ~999 parameters; ids length is typically small
    final placeholders = ids.map((_) => '?').join(',');
    final results = _db.select(
      'SELECT id, lemma_1, meaning_html, antonym, synonym, stem, pattern '
      'FROM dpd_headwords WHERE id IN ($placeholders)',
      ids,
    );
    final rows = results.map(_parseHeadwordRow).toList();
    _trim(_headwordsCache);
    _headwordsCache[cacheKey] = rows;
    return rows;
  }

  // ── Parsing helpers ───────────────────────────────────────────────

  DpdLookupRow _parseLookupRow(Row row) {
    return DpdLookupRow(
      lookupKey: row['lookup_key'] as String,
      headwords: _parseJsonIntArray(row['headwords'] as String?),
      deconstructor: _parseJsonStringArray(row['deconstructor'] as String?),
    );
  }

  DpdHeadwordRow _parseHeadwordRow(Row row) {
    return DpdHeadwordRow(
      id: row['id'] as int,
      lemma1: row['lemma_1'] as String,
      meaningHtml: row['meaning_html'] as String?,
      antonym: row['antonym'] as String?,
      synonym: row['synonym'] as String?,
      stem: row['stem'] as String?,
      pattern: row['pattern'] as String?,
    );
  }

  List<int> _parseJsonIntArray(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      final parsed = jsonDecode(json);
      return (parsed as List).cast<int>();
    } catch (_) {
      return [];
    }
  }

  List<String> _parseJsonStringArray(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      final parsed = jsonDecode(json);
      return (parsed as List).cast<String>();
    } catch (_) {
      return [];
    }
  }
}
