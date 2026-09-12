import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart';

import '../utils/pali_search_utils.dart';

/// Row from dpd_lookup table.
class DpdLookupRow {
  final String lookupKey;
  final List<int> headwords; // parsed JSON array of ints
  final List<String> deconstructor; // parsed JSON array of strings
  final String?
  epd; // pre-rendered HTML from converter, null if column missing/empty

  const DpdLookupRow({
    required this.lookupKey,
    required this.headwords,
    required this.deconstructor,
    this.epd,
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

  const DeconstructionCandidate({required this.raw, required this.tokens});

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
/// - `dpd_lookup` (lookup_key TEXT, headwords TEXT JSON, deconstructor TEXT JSON, epd TEXT HTML, optional)
/// - `dpd_headwords` (id INTEGER PK, lemma_1 TEXT, meaning_html TEXT, ...)
class DpdDictionaryDatabase {
  final Database _db;
  final String? _dbPath;

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

  DpdDictionaryDatabase(this._db, [this._dbPath]);

  static const int _normTableVersion = 1;
  static String get _normTable => 'dpd_lookup_norm_v$_normTableVersion';
  static const int _normChunkRows = 100000;
  static const int _normPageRows = 5000;

  bool _normEnsureStarted = false;
  bool _isNormReady = false;
  double? _normBuildProgress;

  bool get isNormReady => _isNormReady;
  double? get normBuildProgress => _normBuildProgress;
  void Function(double progress)? onNormProgress;

  void _reportNormProgress(double progress) {
    _normBuildProgress = progress;
    try {
      onNormProgress?.call(progress);
    } catch (_) {}
  }

  bool? _hasEpdColumn;

  /// Whether dpd_lookup has the optional `epd` column (old DBs don't).
  /// Checked once per DB instance via PRAGMA.
  bool get hasEpdColumn {
    final cached = _hasEpdColumn;
    if (cached != null) return cached;
    try {
      final info = _db.select('PRAGMA table_info(dpd_lookup)');
      final has = info.any((r) => r['name'] == 'epd');
      _hasEpdColumn = has;
      return has;
    } catch (_) {
      _hasEpdColumn = false;
      return false;
    }
  }

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
    db.execute('PRAGMA busy_timeout=10000');
    db.execute('PRAGMA foreign_keys=ON');
    final instance = DpdDictionaryDatabase(db, dbPath);
    instance._ensureIndexesAndNorm();
    return instance;
  }

  void _ensureIndexesAndNorm() {
    if (_normEnsureStarted) return;
    _normEnsureStarted = true;
    final dbPath = _dbPath;
    if (dbPath == null) return;
    _ensureIndexesAndNormAsync(dbPath).catchError((_) {
      _reportNormProgress(1.0);
    });
  }

  Future<void> _ensureIndexesAndNormAsync(String dbPath) async {
    final counts = await Isolate.run(() => _normCountEntry(dbPath));
    final lookupCount = counts[0];
    var normCount = counts[1];
    if (lookupCount <= 0) return;
    if (normCount != lookupCount) {
      await Isolate.run(() => _normRebuildPrepareEntry(dbPath));
      var afterRowId = 0;
      var built = 0;
      while (true) {
        final chunk = await Isolate.run(
          () => _normChunkEntry([dbPath, afterRowId]),
        );
        built += chunk[1];
        afterRowId = chunk[0];
        _reportNormProgress((built / lookupCount).clamp(0.0, 0.99));
        if (chunk[2] == 1) break;
      }
      final verify = await Isolate.run(() => _normCountEntry(dbPath));
      normCount = verify[1];
      if (normCount != verify[0] || normCount <= 0) {
        _reportNormProgress(0.0);
        _normBuildProgress = null;
        return;
      }
    }
    await Isolate.run(() => _normIndexEntry(dbPath));
    _prefixCache.clear();
    _isNormReady = true;
    _reportNormProgress(1.0);
  }

  static List<int> _normCountEntry(String dbPath) {
    final db = sqlite3.open(dbPath);
    try {
      db.execute('PRAGMA busy_timeout=10000');
      int lookupCount = 0;
      int normCount = 0;
      try {
        lookupCount =
            db.select('SELECT COUNT(*) c FROM dpd_lookup').first['c'] as int;
      } catch (_) {}
      try {
        normCount =
            db.select('SELECT COUNT(*) c FROM $_normTable').first['c'] as int;
      } catch (_) {}
      return [lookupCount, normCount];
    } finally {
      db.dispose();
    }
  }

  static void _normRebuildPrepareEntry(String dbPath) {
    final db = sqlite3.open(dbPath);
    try {
      db.execute('PRAGMA journal_mode=WAL');
      db.execute('PRAGMA busy_timeout=10000');
      db.execute('DROP TABLE IF EXISTS $_normTable');
      db.execute(
        'CREATE TABLE $_normTable('
        'norm TEXT NOT NULL, lookup_key TEXT NOT NULL)',
      );
    } finally {
      db.dispose();
    }
  }

  static List<int> _normChunkEntry(List<Object?> args) {
    final db = sqlite3.open(args[0] as String);
    try {
      db.execute('PRAGMA journal_mode=WAL');
      db.execute('PRAGMA busy_timeout=10000');
      var lastRowid = args[1] as int;
      var inserted = 0;
      var done = false;
      db.execute('BEGIN IMMEDIATE');
      try {
        while (inserted < _normChunkRows) {
          final rows = db.select(
            'SELECT rowid, lookup_key FROM dpd_lookup '
            'WHERE rowid > ? ORDER BY rowid LIMIT ?',
            [lastRowid, _normPageRows],
          );
          if (rows.isEmpty) {
            done = true;
            break;
          }
          for (var i = 0; i < rows.length; i += 500) {
            final page = rows.skip(i).take(500).toList();
            final placeholders = page.map((_) => '(?, ?)').join(', ');
            final values = <Object?>[];
            for (final row in page) {
              final key = row['lookup_key'] as String;
              values.add(foldPaliDiacritics(key));
              values.add(key);
            }
            db.execute(
              'INSERT INTO $_normTable(norm, lookup_key) VALUES $placeholders',
              values,
            );
          }
          inserted += rows.length;
          lastRowid = rows.last['rowid'] as int;
        }
        db.execute('COMMIT');
      } catch (_) {
        try {
          db.execute('ROLLBACK');
        } catch (_) {}
        rethrow;
      }
      return [lastRowid, inserted, done ? 1 : 0];
    } finally {
      db.dispose();
    }
  }

  static void _normIndexEntry(String dbPath) {
    final db = sqlite3.open(dbPath);
    try {
      db.execute('PRAGMA journal_mode=WAL');
      db.execute('PRAGMA busy_timeout=10000');
      db.execute(
        'CREATE INDEX IF NOT EXISTS idx_dpd_lookup_lookup_key '
        'ON dpd_lookup(lookup_key)',
      );
      db.execute(
        'CREATE INDEX IF NOT EXISTS ${_normTable}_idx ON $_normTable(norm)',
      );
    } finally {
      db.dispose();
    }
  }

  // ── Lookup queries ────────────────────────────────────────────────

  /// Exact lookup by key. Returns null if not found. Memoized per key.
  DpdLookupRow? getLookup(String key) {
    final normalized = key.trim().toLowerCase();
    final cached = _lookupCache[normalized];
    if (cached != null || _lookupCache.containsKey(normalized)) {
      return cached;
    }
    final row = _getLookupExact(normalized) ?? _getLookupFolded(normalized);
    _trim(_lookupCache);
    _lookupCache[normalized] = row;
    return row;
  }

  DpdLookupRow? _getLookupExact(String normalized) {
    final epdSelect = hasEpdColumn ? ', epd' : '';
    final result = _db.select(
      'SELECT lookup_key, headwords, deconstructor$epdSelect FROM dpd_lookup WHERE lookup_key = ?',
      [normalized],
    );
    return result.isEmpty ? null : _parseLookupRow(result.first);
  }

  DpdLookupRow? _getLookupFolded(String normalized) {
    if (!_isNormReady) return null;
    try {
      final rows = _db.select(
        'SELECT lookup_key FROM $_normTable WHERE norm = ? LIMIT 1',
        [foldPaliDiacritics(normalized)],
      );
      if (rows.isEmpty) return null;
      return _getLookupExact(rows.first['lookup_key'] as String);
    } catch (_) {
      return null;
    }
  }

  /// Prefix search on the lookup table. Returns rows matching the prefix.
  /// Memoized per (prefix, limit) pair.
  List<DpdLookupRow> searchLookup(String prefix, {int limit = 25}) {
    final normalized = prefix.trim().toLowerCase();
    if (normalized.isEmpty) return [];
    final cacheKey = '$normalized\u0000$limit';
    final cached = _prefixCache[cacheKey];
    if (cached != null) return cached;

    final folded = _isNormReady ? _searchLookupFolded(normalized, limit) : null;
    if (folded != null) {
      _trim(_prefixCache);
      _prefixCache[cacheKey] = folded;
      return folded;
    }

    final upper = _prefixUpperBound(normalized);
    final results = upper == null
        ? _db.select(
            'SELECT lookup_key, headwords FROM dpd_lookup '
            'WHERE lookup_key >= ? ORDER BY lookup_key LIMIT ?',
            [normalized, limit],
          )
        : _db.select(
            'SELECT lookup_key, headwords FROM dpd_lookup '
            'WHERE lookup_key >= ? AND lookup_key < ? '
            'ORDER BY lookup_key LIMIT ?',
            [normalized, upper, limit],
          );
    final rows = results
        .map(
          (row) => DpdLookupRow(
            lookupKey: row['lookup_key'] as String,
            headwords: _parseJsonIntArray(row['headwords'] as String?),
            deconstructor: const [],
          ),
        )
        .toList();
    _trim(_prefixCache);
    _prefixCache[cacheKey] = rows;
    return rows;
  }

  List<DpdLookupRow>? _searchLookupFolded(String normalized, int limit) {
    try {
      final folded = foldPaliDiacritics(normalized);
      final upper = _prefixUpperBound(folded);
      final results = upper == null
          ? _db.select(
              'SELECT n.lookup_key AS lookup_key, l.headwords AS headwords '
              'FROM $_normTable n '
              'JOIN dpd_lookup l ON l.lookup_key = n.lookup_key '
              'WHERE n.norm >= ? ORDER BY n.norm, n.lookup_key LIMIT ?',
              [folded, limit],
            )
          : _db.select(
              'SELECT n.lookup_key AS lookup_key, l.headwords AS headwords '
              'FROM $_normTable n '
              'JOIN dpd_lookup l ON l.lookup_key = n.lookup_key '
              'WHERE n.norm >= ? AND n.norm < ? '
              'ORDER BY n.norm, n.lookup_key LIMIT ?',
              [folded, upper, limit],
            );
      return results
          .map(
            (row) => DpdLookupRow(
              lookupKey: row['lookup_key'] as String,
              headwords: _parseJsonIntArray(row['headwords'] as String?),
              deconstructor: const [],
            ),
          )
          .toList();
    } catch (_) {
      return null;
    }
  }

  static String? _prefixUpperBound(String prefix) {
    final runes = prefix.runes.toList();
    if (runes.isEmpty) return null;
    final last = runes.last;
    if (last >= 0x10FFFF) return null;
    runes[runes.length - 1] = last + 1;
    return String.fromCharCodes(runes);
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
    String? epd;
    if (hasEpdColumn) {
      try {
        final v = row['epd'] as String?;
        if (v != null && v.trim().isNotEmpty) epd = v;
      } catch (_) {
        epd = null;
      }
    }
    return DpdLookupRow(
      lookupKey: row['lookup_key'] as String,
      headwords: _parseJsonIntArray(row['headwords'] as String?),
      deconstructor: _parseJsonStringArray(row['deconstructor'] as String?),
      epd: epd,
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
