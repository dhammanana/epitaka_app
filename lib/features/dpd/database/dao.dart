import 'dart:convert';

import 'package:drift/drift.dart';

import 'dpd_database.dart';
import 'tables.dart';
import '../utils/diacritics.dart';
import '../utils/fuzzy_rank.dart';
import '../utils/search_timing.dart';

part 'dao.g.dart';

class DpdHeadwordWithRoot {
  final DpdHeadword headword;
  final DpdRoot? root;
  int? rootCount;

  DpdHeadwordWithRoot(this.headword, this.root);
}

class RootWithFamilies {
  final DpdRoot root;
  final List<FamilyRootData> families;
  final int count;

  RootWithFamilies({
    required this.root,
    required this.families,
    required this.count,
  });
}

@DriftAccessor(
  tables: [
    DpdHeadwords,
    Lookup,
    DpdRoots,
    DbInfo,
    InflectionTemplates,
    FamilyRoot,
    FamilyWord,
    FamilyCompound,
    FamilyIdiom,
    FamilySet,
    SuttaInfo,
    DictMeta,
    DictEntries,
  ],
)
class DpdDao extends DatabaseAccessor<DpdDatabase> with _$DpdDaoMixin {
  DpdDao(super.db);

  // ── Search ────────────────────────────────────────────────────────────────

  Future<List<DpdHeadwordWithRoot>> searchExact(String query) async {
    if (query.isEmpty) return [];
    final normalized = _normalizeQuery(query);

    final timing = enableSearchTiming ? SearchTimingData(query: query) : null;
    final sw = Stopwatch()..start();

    final isSuttaCode = normalized.contains(RegExp(r'\d'));
    final lookupRows = await (select(lookup)
          ..where(
            (t) => isSuttaCode
                ? t.lookupKey.equals(normalized) |
                    t.lookupKey.equals(normalized.toUpperCase())
                : t.lookupKey.equals(normalized),
          ))
        .get();

    final idSet = _extractIds(lookupRows);
    final results = await _fetchHeadwords(idSet);

    sw.stop();
    timing?.recordQueryTime('searchExact_total', sw.elapsed);
    if (timing != null) recordTiming(timing);

    return results;
  }

  Future<List<DpdHeadwordWithRoot>> searchPartial(
    String query, {
    int limit = 30,
  }) async {
    if (query.isEmpty) return [];
    final normalized = _normalizeQuery(query);

    final sw = Stopwatch()..start();
    // Use range query instead of LIKE — allows SQLite to use the index.
    // If query contains a digit it's a sutta code — also search uppercase range.
    final isSuttaCode = normalized.contains(RegExp(r'\d'));
    final upper = isSuttaCode ? normalized.toUpperCase() : null;
    final nextKey = _nextString(normalized);
    final lookupRows =
        await (select(lookup)
              ..where(
                (t) {
                  final lowerRange =
                      t.lookupKey.isBiggerOrEqualValue(normalized) &
                          t.lookupKey.isSmallerThanValue(nextKey) &
                          t.lookupKey.equals(normalized).not();
                  if (upper == null) return lowerRange;
                  final upperNextKey = _nextString(upper);
                  return lowerRange |
                      (t.lookupKey.isBiggerOrEqualValue(upper) &
                          t.lookupKey.isSmallerThanValue(upperNextKey) &
                          t.lookupKey.equals(upper).not());
                },
              )
              ..limit(limit))
            .get();

    final idSet = _extractIds(lookupRows);
    final results = await _fetchHeadwords(idSet);
    sw.stop();

    if (enableSearchTiming) {
      final timing = SearchTimingData(query: query);
      timing.recordQueryTime('searchPartial_total', sw.elapsed);
      recordTiming(timing);
    }

    return results;
  }

  Future<List<DpdHeadwordWithRoot>> searchFuzzy(
    String query, {
    int limit = 50,
  }) async {
    if (query.isEmpty) return [];
    final normalizedQuery = _normalizeQuery(query);
    final queryFuzzyKey = stripDiacritics(normalizedQuery);
    if (queryFuzzyKey.isEmpty) return [];

    final sw = Stopwatch()..start();
    // Use range query instead of LIKE — allows SQLite to use the index
    final nextKey = _nextString(queryFuzzyKey);
    final lookupRows =
        await (select(lookup)
              ..where(
                (t) =>
                    t.fuzzyKey.isBiggerOrEqualValue(queryFuzzyKey) &
                    t.fuzzyKey.isSmallerThanValue(nextKey),
              )
              ..limit(limit))
            .get();

    final results = await _rankedHeadwordsByCloseness(
      lookupRows,
      normalizedQuery,
      queryFuzzyKey,
    );
    sw.stop();

    if (enableSearchTiming) {
      final timing = SearchTimingData(query: query);
      timing.recordQueryTime('searchFuzzy_total', sw.elapsed);
      recordTiming(timing);
    }

    return results;
  }

  /// Resolves lookup rows to headwords ranked by [fuzzyCloseness] to
  /// `normalizedQuery`/`queryFuzzyKey`, keeping each headword's best score
  /// when several lookup rows reach the same id (e.g. multiple inflected
  /// forms of one word). Shared by `searchFuzzy` and `searchFuzzyExact` so
  /// their ranking can never drift apart.
  Future<List<DpdHeadwordWithRoot>> _rankedHeadwordsByCloseness(
    List<LookupData> lookupRows,
    String normalizedQuery,
    String queryFuzzyKey,
  ) async {
    final bestScoreById = <int, int>{};
    for (final row in lookupRows) {
      final score = fuzzyCloseness(
        query: normalizedQuery,
        queryFuzzyKey: queryFuzzyKey,
        candidate: row.lookupKey,
        candidateFuzzyKey: row.fuzzyKey ?? '',
      );
      for (final id in _extractIds([row])) {
        final current = bestScoreById[id];
        if (current == null || score < current) {
          bestScoreById[id] = score;
        }
      }
    }

    final results = await _fetchHeadwords(bestScoreById.keys.toSet());
    results.sort((a, b) {
      final scoreCompare = (bestScoreById[a.headword.id] ?? 0).compareTo(
        bestScoreById[b.headword.id] ?? 0,
      );
      if (scoreCompare != 0) return scoreCompare;
      return paliSortKey(
        a.headword.lemma1,
      ).compareTo(paliSortKey(b.headword.lemma1));
    });
    return results;
  }

  /// Headwords reachable only via a genuine exact `fuzzy_key` match — the
  /// same tier-0 signal `searchFuzzy` already ranks first, resolved directly
  /// to headwords for promotion into the exact tier. `searchPartial` can
  /// otherwise turn up a real but coincidental literal-prefix hit (e.g.
  /// `kammam` literally prefixes the unrelated headword `kammamakāsi` via
  /// Pāḷi sandhi liaison) that would visually outrank this far stronger
  /// match, since Partial renders above Fuzzy. Deliberately narrower than
  /// `searchFuzzy`: equality, not a prefix range.
  ///
  /// Multiple genuinely equidistant words can share one folded key (folding
  /// `kammam` matches `kamaṃ`, `kammaṃ`, `kāmaṃ`, `khamaṃ` and `kkamaṃ`
  /// alike) — plain alphabetical order would bury `kammaṃ` under `kamaṃ`
  /// exactly as `_fetchHeadwords` buried `rūpa` under `ruppa` before this
  /// thread's fix, so results are still ranked by `fuzzyCloseness` (here,
  /// purely by length delta, since every candidate is already tier 0).
  Future<List<DpdHeadwordWithRoot>> searchFuzzyExact(String query) async {
    if (query.isEmpty) return [];
    final normalizedQuery = _normalizeQuery(query);
    final queryFuzzyKey = stripDiacritics(normalizedQuery);
    if (queryFuzzyKey.isEmpty) return [];

    final rows = await (select(
      lookup,
    )..where((t) => t.fuzzyKey.equals(queryFuzzyKey))).get();

    return _rankedHeadwordsByCloseness(rows, normalizedQuery, queryFuzzyKey);
  }

  /// Exact `fuzzy_key` equality rescue for the autocomplete dropdown.
  ///
  /// `searchFuzzy`'s prefix range scan finds every candidate that *starts
  /// with* the query's key; this instead finds only rows whose key **equals**
  /// it — a real word differing from the query solely by a folded diacritic,
  /// aspirate, or doubled consonant. The dropdown's own headword index
  /// (`searchIndexProvider`) can miss this entirely: it's built from bare
  /// lemmas, and a lemma's own collapsed key can be *shorter* than an
  /// inflected query's, so it can never even be a prefix match. The inflected
  /// `lookup_key` row that does carry the identical key (e.g. `kammaṃ` for a
  /// mistyped `kammam`) rescues it here instead.
  Future<List<String>> searchFuzzyExactKeyMatches(
    String query, {
    int limit = 20,
  }) async {
    if (query.isEmpty) return [];
    final normalizedQuery = _normalizeQuery(query);
    final queryFuzzyKey = stripDiacritics(normalizedQuery);
    if (queryFuzzyKey.isEmpty) return [];

    // No SQL-level limit: this is an equality match, so every row is already
    // tier 0 and the closeness ranking below must see all of them before
    // truncating — limiting first could silently drop the actual closest
    // match on a key ambiguous enough to have more than `limit` real words.
    final rows = await (select(
      lookup,
    )..where((t) => t.fuzzyKey.equals(queryFuzzyKey))).get();

    final sorted = rows.toList()
      ..sort((a, b) {
        final scoreCompare = fuzzyCloseness(
          query: normalizedQuery,
          queryFuzzyKey: queryFuzzyKey,
          candidate: a.lookupKey,
          candidateFuzzyKey: a.fuzzyKey ?? '',
        ).compareTo(
          fuzzyCloseness(
            query: normalizedQuery,
            queryFuzzyKey: queryFuzzyKey,
            candidate: b.lookupKey,
            candidateFuzzyKey: b.fuzzyKey ?? '',
          ),
        );
        if (scoreCompare != 0) return scoreCompare;
        return paliSortKey(a.lookupKey).compareTo(paliSortKey(b.lookupKey));
      });

    return sorted.take(limit).map((row) => row.lookupKey).toList();
  }

  Set<int> _extractIds(List<LookupData> lookupRows) {
    final idSet = <int>{};
    for (final row in lookupRows) {
      final hw = row.headwords;
      if (hw != null && hw.isNotEmpty) {
        final ids = (jsonDecode(hw) as List).cast<int>();
        idSet.addAll(ids);
      }
    }
    return idSet;
  }

  Future<List<DpdHeadwordWithRoot>> _fetchHeadwords(Set<int> idSet) async {
    if (idSet.isEmpty) return [];

    final rows = await (select(dpdHeadwords).join([
      leftOuterJoin(dpdRoots, dpdRoots.root.equalsExp(dpdHeadwords.rootKey)),
    ])..where(dpdHeadwords.id.isIn(idSet))).get();

    final uniqueRoots = rows
        .map((row) => row.readTableOrNull(dpdRoots)?.root)
        .whereType<String>()
        .toSet();

    final rootCounts = <String, int>{};
    if (uniqueRoots.isNotEmpty) {
      final countQuery =
          await (selectOnly(dpdHeadwords)
                ..addColumns([dpdHeadwords.rootKey, dpdHeadwords.id.count()])
                ..where(dpdHeadwords.rootKey.isIn(uniqueRoots))
                ..groupBy([dpdHeadwords.rootKey]))
              .get();
      for (final row in countQuery) {
        final root = row.read(dpdHeadwords.rootKey);
        final count = row.read(dpdHeadwords.id.count());
        if (root != null) rootCounts[root] = count ?? 0;
      }
    }

    final results = rows.map((row) {
      final hw = DpdHeadwordWithRoot(
        row.readTable(dpdHeadwords),
        row.readTableOrNull(dpdRoots),
      );
      final rootKey = hw.root?.root;
      if (rootKey != null) {
        hw.rootCount = rootCounts[rootKey];
      }
      return hw;
    }).toList();

    results.sort(
      (a, b) => paliSortKey(
        a.headword.lemma1,
      ).compareTo(paliSortKey(b.headword.lemma1)),
    );
    return results;
  }

  // ── Single entry ──────────────────────────────────────────────────────────

  Future<DpdHeadwordWithRoot?> getById(int id) async {
    final row = await (select(dpdHeadwords).join([
      leftOuterJoin(dpdRoots, dpdRoots.root.equalsExp(dpdHeadwords.rootKey)),
    ])..where(dpdHeadwords.id.equals(id))).getSingleOrNull();

    if (row == null) return null;

    final hw = DpdHeadwordWithRoot(
      row.readTable(dpdHeadwords),
      row.readTableOrNull(dpdRoots),
    );

    // Calculate rootCount
    final rootKey = hw.root?.root;
    if (rootKey != null) {
      final countQuery =
          await (selectOnly(dpdHeadwords)
                ..addColumns([dpdHeadwords.id.count()])
                ..where(dpdHeadwords.rootKey.equals(rootKey)))
              .getSingle();
      hw.rootCount = countQuery.read(dpdHeadwords.id.count()) ?? 0;
    }

    return hw;
  }

  Future<List<String>> searchClosestMatches(
    String query, {
    int maxResults = 10,
  }) async {
    if (query.isEmpty) return [];
    final normalized = _normalizeQuery(query);
    if (normalized.length < 2) return [];

    final candidates = <String>{};

    // Strategy 1: progressively shorter prefixes on lookup_key.
    // If query contains a digit it's a sutta code — also search uppercase range.
    final isSuttaCode = normalized.contains(RegExp(r'\d'));
    for (
      var len = normalized.length - 1;
      len >= 2 && candidates.length < 50;
      len--
    ) {
      final prefix = normalized.substring(0, len);
      final nextKey = _nextString(prefix);
      final lowerRange =
          lookup.lookupKey.isBiggerOrEqualValue(prefix) &
              lookup.lookupKey.isSmallerThanValue(nextKey);
      Expression<bool> whereExpr = lowerRange;
      if (isSuttaCode) {
        final upperPrefix = prefix.toUpperCase();
        final upperNextKey = _nextString(upperPrefix);
        whereExpr = lowerRange |
            (lookup.lookupKey.isBiggerOrEqualValue(upperPrefix) &
                lookup.lookupKey.isSmallerThanValue(upperNextKey));
      }
      final rows =
          await (selectOnly(lookup)
                ..addColumns([lookup.lookupKey])
                ..where(whereExpr)
                ..limit(20))
              .get();
      for (final row in rows) {
        final key = row.read(lookup.lookupKey);
        if (key != null && key != normalized) candidates.add(key);
      }
    }

    // Strategy 2: fuzzy_key prefix trimming (diacritics-insensitive)
    final fuzzyNorm = stripDiacritics(normalized);
    if (fuzzyNorm.length >= 2) {
      for (
        var len = fuzzyNorm.length;
        len >= 2 && candidates.length < 50;
        len--
      ) {
        final prefix = fuzzyNorm.substring(0, len);
        final nextKey = _nextString(prefix);
        final rows =
            await (selectOnly(lookup)
                  ..addColumns([lookup.lookupKey])
                  ..where(
                    lookup.fuzzyKey.isBiggerOrEqualValue(prefix) &
                        lookup.fuzzyKey.isSmallerThanValue(nextKey),
                  )
                  ..limit(20))
                .get();
        for (final row in rows) {
          final key = row.read(lookup.lookupKey);
          if (key != null && key != normalized) candidates.add(key);
        }
      }
    }

    if (candidates.isEmpty) return [];

    final sorted = candidates.toList()
      ..sort((a, b) => paliSortKey(a).compareTo(paliSortKey(b)));
    return sorted.take(maxResults).toList();
  }

  /// Exact-prefix suggestions from the lookup table, for the autocomplete
  /// dropdown's fallback tier. Deliberately not fuzzy: matches on `lookup_key`
  /// (the primary key), not `fuzzy_key`, so it does not fold diacritics,
  /// aspirates, or double consonants.
  Future<List<String>> searchLookupKeysPrefix(
    String query, {
    int limit = 200,
  }) async {
    final normalized = _normalizeQuery(query);
    if (normalized.length < 2) return [];

    // Sutta codes are stored uppercase (e.g. "DN1.1"); a digit in the query
    // means it might be one, so widen the range to also cover the uppercase
    // form — same rule as searchExact/searchPartial/searchClosestMatches.
    final isSuttaCode = normalized.contains(RegExp(r'\d'));
    final nextKey = _nextString(normalized);
    var whereExpr =
        lookup.lookupKey.isBiggerOrEqualValue(normalized) &
            lookup.lookupKey.isSmallerThanValue(nextKey);
    if (isSuttaCode) {
      final upper = normalized.toUpperCase();
      final upperNextKey = _nextString(upper);
      whereExpr = whereExpr |
          (lookup.lookupKey.isBiggerOrEqualValue(upper) &
              lookup.lookupKey.isSmallerThanValue(upperNextKey));
    }
    final rows =
        await (selectOnly(lookup)
              ..addColumns([lookup.lookupKey])
              ..where(whereExpr)
              ..limit(limit))
            .get();

    return rows.map((r) => r.read(lookup.lookupKey)!).toList();
  }

  Future<Set<String>> checkWordsInLookup(Set<String> words) async {
    if (words.isEmpty) return {};
    final allKeys = {
      ...words,
      ...words
          .where((w) => w.contains(RegExp(r'\d')))
          .map((w) => w.toUpperCase()),
    };
    final rows = await (select(
      lookup,
    )..where((t) => t.lookupKey.isIn(allKeys))).get();
    return rows.map((r) => r.lookupKey).toSet();
  }

  Future<LookupData?> getLookupRow(String key) async {
    // Abbreviation keys are stored capitalised (e.g. "VVa", "DN", "NIDD1a"),
    // so try the lower-cased query first (normal words), then the query as
    // typed, then upper-cased. Each is a primary-key lookup, so the extra
    // attempts only run when the previous one misses.
    final cased = _normalizePunctuation(key);
    for (final candidate in <String>{
      cased.toLowerCase(),
      cased,
      cased.toUpperCase(),
    }) {
      final row = await (select(
        lookup,
      )..where((t) => t.lookupKey.equals(candidate))).getSingleOrNull();
      if (row != null) return row;
    }
    return null;
  }

  // ── DB metadata ───────────────────────────────────────────────────────────

  // ── Inflection templates ──────────────────────────────────────────────────

  Future<InflectionTemplate?> getInflectionTemplate(String pattern) {
    return (select(
      inflectionTemplates,
    )..where((t) => t.pattern.equals(pattern))).getSingleOrNull();
  }

  Future<List<InflectionTemplate>> getAllInflectionTemplates() {
    return select(inflectionTemplates).get();
  }

  // ── DB metadata ───────────────────────────────────────────────────────────

  // ── Family tables ─────────────────────────────────────────────────────────

  Future<FamilyRootData?> getRootFamily(String rootKey, String familyRootVal) {
    return (select(familyRoot)..where(
          (t) => t.rootKey.equals(rootKey) & t.rootFamily.equals(familyRootVal),
        ))
        .getSingleOrNull();
  }

  Future<FamilyWordData?> getWordFamily(String wordFamilyKey) {
    return (select(
      familyWord,
    )..where((t) => t.wordFamily.equals(wordFamilyKey))).getSingleOrNull();
  }

  Future<List<FamilyCompoundData>> getCompoundFamilies(
    List<String> compoundFamilies,
  ) {
    if (compoundFamilies.isEmpty) return Future.value([]);
    return (select(
      familyCompound,
    )..where((t) => t.compoundFamily.isIn(compoundFamilies))).get();
  }

  Future<List<FamilyIdiomData>> getIdioms(List<String> idioms) {
    if (idioms.isEmpty) return Future.value([]);
    return (select(familyIdiom)..where((t) => t.idiom.isIn(idioms))).get();
  }

  Future<Set<String>> getAllIdiomKeys() async {
    final rows = await (selectOnly(
      familyIdiom,
      distinct: true,
    )..addColumns([familyIdiom.idiom])).get();
    return rows.map((r) => r.read(familyIdiom.idiom)!).toSet();
  }

  Future<List<FamilySetData>> getSets(List<String> sets) {
    if (sets.isEmpty) return Future.value([]);
    return (select(familySet)..where((t) => t.set_.isIn(sets))).get();
  }

  Future<Set<String>> getAllCompoundFamilyKeys() async {
    final rows = await (selectOnly(
      familyCompound,
      distinct: true,
    )..addColumns([familyCompound.compoundFamily])).get();
    return rows.map((r) => r.read(familyCompound.compoundFamily)!).toSet();
  }

  // ── Sutta info ──────────────────────────────────────────────────────────

  Future<SuttaInfoData?> getSuttaInfo(String lemma1) async {
    final results = await (select(suttaInfo)
          ..where(
            (t) =>
                t.dpdSutta.equals(lemma1) |
                t.dpdSuttaVar.equals(lemma1) |
                t.dpdSuttaVar.like('$lemma1;%') |
                t.dpdSuttaVar.like('%; $lemma1') |
                t.dpdSuttaVar.like('%; $lemma1;%'),
          ))
        .get();
    return results.firstOrNull;
  }

  // ── DB metadata ───────────────────────────────────────────────────────────

  Future<String?> getDbValue(String key) async {
    final row = await (select(
      dbInfo,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  // ── Root search ─────────────────────────────────────────────────────────

  Future<List<({String lemma1, String pos, String rootBase, String grammar})>>
  getHeadwordsForRootMatrix(String rootKey) async {
    final rows =
        await (selectOnly(dpdHeadwords)
              ..addColumns([
                dpdHeadwords.lemma1,
                dpdHeadwords.pos,
                dpdHeadwords.rootBase,
                dpdHeadwords.grammar,
              ])
              ..where(
                dpdHeadwords.rootKey.equals(rootKey) &
                    dpdHeadwords.rootKey.equals('').not(),
              ))
            .get();

    return rows
        .map(
          (r) => (
            lemma1: r.read(dpdHeadwords.lemma1)!,
            pos: r.read(dpdHeadwords.pos) ?? '',
            rootBase: r.read(dpdHeadwords.rootBase) ?? '',
            grammar: r.read(dpdHeadwords.grammar) ?? '',
          ),
        )
        .toList();
  }

  Future<List<String>> getBasesForRoot(String rootKey) async {
    final rows =
        await (selectOnly(dpdHeadwords, distinct: true)
              ..addColumns([dpdHeadwords.rootBase])
              ..where(dpdHeadwords.rootKey.equals(rootKey)))
            .get();

    final bases = <String>{};
    for (final row in rows) {
      final raw = row.read(dpdHeadwords.rootBase);
      if (raw == null || raw.isEmpty) continue;
      final parts = raw.split(' > ');
      final base = parts.last.trim();
      if (base.isNotEmpty) bases.add(base);
    }
    final sorted = bases.toList()..sort((a, b) => a.length.compareTo(b.length));
    return sorted;
  }

  Future<RootWithFamilies?> getRootWithFamilies(String rootKey) async {
    final rootRow = await (select(
      dpdRoots,
    )..where((t) => t.root.equals(rootKey))).getSingleOrNull();
    if (rootRow == null) return null;

    final families = await (select(
      familyRoot,
    )..where((t) => t.rootKey.equals(rootKey))).get();
    families.sort(
      (a, b) => paliSortKey(a.rootFamily).compareTo(paliSortKey(b.rootFamily)),
    );

    final countQuery =
        await (selectOnly(dpdHeadwords)
              ..addColumns([dpdHeadwords.id.count()])
              ..where(dpdHeadwords.rootKey.equals(rootKey)))
            .getSingle();
    final count = countQuery.read(dpdHeadwords.id.count()) ?? 0;

    return RootWithFamilies(root: rootRow, families: families, count: count);
  }

  List<String> _extractRootKeys(List<LookupData> lookupRows) {
    final keys = <String>{};
    for (final row in lookupRows) {
      final r = row.roots;
      if (r != null && r.isNotEmpty) {
        final decoded = jsonDecode(r) as List;
        for (final key in decoded) {
          if (key is String && key.isNotEmpty) keys.add(key);
        }
      }
    }
    return keys.toList();
  }

  Future<List<RootWithFamilies>> searchRoots(String query) async {
    if (query.isEmpty) return [];
    final normalized = _normalizeQuery(query);

    final isSuttaCode = normalized.contains(RegExp(r'\d'));
    final lookupRows = await (select(lookup)
          ..where(
            (t) => isSuttaCode
                ? t.lookupKey.equals(normalized) |
                    t.lookupKey.equals(normalized.toUpperCase())
                : t.lookupKey.equals(normalized),
          ))
        .get();

    final rootKeys = _extractRootKeys(lookupRows);
    if (rootKeys.isEmpty) return [];

    final results = <RootWithFamilies>[];
    for (final key in rootKeys) {
      final rwf = await getRootWithFamilies(key);
      if (rwf != null) results.add(rwf);
    }
    results.sort(
      (a, b) => paliSortKey(a.root.root).compareTo(paliSortKey(b.root.root)),
    );
    return results;
  }

  // ── External dictionaries ────────────────────────────────────────────────

  /// Case-insensitive exact match across the given dictionaries.
  ///
  /// SQLite's `=`, `LIKE` and `lower()` all fold ASCII only, so none of them can
  /// match `Ānanda` against `ānanda`. Instead this seeks the indexed, already
  /// case-folded `word_fuzzy` column for a small candidate superset, then does
  /// the real comparison in Dart, whose `toLowerCase` is Unicode-aware.
  ///
  /// `dictIds` must be supplied: `idx_dict_entries_fuzzy` leads on `dict_id`,
  /// so without it SQLite falls back to a full table scan.
  Future<List<DictEntry>> searchDictExact(
    List<String> dictIds,
    String query,
  ) async {
    if (dictIds.isEmpty || query.isEmpty) return [];

    final normalized = _foldNiggahita(query.toLowerCase());
    final fuzzyKey = stripDiacritics(normalized);
    final rows =
        await (select(dictEntries)..where(
              (t) => t.dictId.isIn(dictIds) & t.wordFuzzy.equals(fuzzyKey),
            ))
            .get();

    return rows.where((row) => row.word.toLowerCase() == normalized).toList();
  }

  /// Exact-prefix suggestions from the enabled external dictionaries, for the
  /// autocomplete dropdown's second fallback tier. One range query per dict id
  /// so each can seek the composite `(dict_id, word)` index — a single
  /// unfiltered query across all dicts cannot. Matches on `word`, not
  /// `word_fuzzy`: deliberately not fuzzy, same reasoning as
  /// [searchLookupKeysPrefix].
  Future<List<String>> searchDictWordsPrefix(
    List<String> dictIds,
    String query, {
    int limit = 50,
  }) async {
    if (dictIds.isEmpty) return [];
    final normalized = _normalizeQuery(query);
    if (normalized.length < 2) return [];

    final nextKey = _nextString(normalized);
    final words = <String>{};

    for (final dictId in dictIds) {
      final rows =
          await (selectOnly(dictEntries)
                ..addColumns([dictEntries.word])
                ..where(
                  dictEntries.dictId.equals(dictId) &
                      dictEntries.word.isBiggerOrEqualValue(normalized) &
                      dictEntries.word.isSmallerThanValue(nextKey),
                )
                ..limit(limit))
              .get();
      for (final row in rows) {
        words.add(row.read(dictEntries.word)!);
      }
    }

    return words.toList();
  }

  Future<List<DictMetaData>> getAllDictMeta() {
    return select(dictMeta).get();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _normalizeQuery(String input) => _normalizePunctuation(input).toLowerCase();

  String _normalizePunctuation(String input) {
    return _foldNiggahita(
      input
          .trim()
          .replaceAll("'", '')
          .replaceAll('-', '')
          .replaceAll('?', '')
          .replaceAll('!', ''),
    );
  }

  /// Folds the display and legacy niggahīta forms onto the canonical ṃ the
  /// database stores. Every query path must apply this — the user may be
  /// looking at ṁ, and external callers may send either form.
  String _foldNiggahita(String input) =>
      input.replaceAll('ṁ', 'ṃ').replaceAll('ŋ', 'ṃ');

  /// Get the next string lexicographically (for range queries).
  /// Increments the last character by 1, enabling prefix matching via
  /// `>= prefix AND < nextString(prefix)` instead of `LIKE 'prefix%'`.
  String _nextString(String s) {
    if (s.isEmpty) return '{'; // '{' is after 'z' in ASCII
    return s.substring(0, s.length - 1) +
        String.fromCharCode(s.codeUnitAt(s.length - 1) + 1);
  }
}

// Pāḷi alphabet sort order — digraphs checked before single chars.
const Map<String, String> _paliOrder = {
  '√': '00',
  'a': '01',
  'ā': '02',
  'i': '03',
  'ī': '04',
  'u': '05',
  'ū': '06',
  'e': '07',
  'o': '08',
  'k': '09',
  'kh': '10',
  'g': '11',
  'gh': '12',
  'ṅ': '13',
  'c': '14',
  'ch': '15',
  'j': '16',
  'jh': '17',
  'ñ': '18',
  'ṭ': '19',
  'ṭh': '20',
  'ḍ': '21',
  'ḍh': '22',
  'ṇ': '23',
  't': '24',
  'th': '25',
  'd': '26',
  'dh': '27',
  'n': '28',
  'p': '29',
  'ph': '30',
  'b': '31',
  'bh': '32',
  'm': '33',
  'y': '34',
  'r': '35',
  'l': '36',
  'v': '37',
  's': '38',
  'h': '39',
  'ḷ': '40',
  'ṃ': '41',
};

const _paliDigraphs = {
  'kh',
  'gh',
  'ch',
  'jh',
  'ṭh',
  'ḍh',
  'th',
  'dh',
  'ph',
  'bh',
};

String paliSortKey(String lemma) {
  final lower = lemma.toLowerCase();
  final spaceIdx = lower.indexOf(' ');
  final base = spaceIdx == -1 ? lower : lower.substring(0, spaceIdx);
  final suffix = spaceIdx == -1 ? '' : lower.substring(spaceIdx);

  final buffer = StringBuffer();
  int i = 0;
  while (i < base.length) {
    if (i + 1 < base.length) {
      final digraph = base.substring(i, i + 2);
      if (_paliDigraphs.contains(digraph)) {
        buffer.write(_paliOrder[digraph]);
        i += 2;
        continue;
      }
    }
    final ch = base[i];
    final order = _paliOrder[ch];
    if (order != null) {
      buffer.write(order);
    }
    i++;
  }

  buffer.write(suffix);
  return buffer.toString();
}

extension DpdHeadwordGetters on DpdHeadwordWithRoot {
  int get id => headword.id;
  String get lemma1 => headword.lemma1;
  String? get lemma2 => headword.lemma2;
  String? get pos => headword.pos;
  String? get grammar => headword.grammar;
  String? get derivedFrom => headword.derivedFrom;
  String? get neg => headword.neg;
  String? get verb => headword.verb;
  String? get trans => headword.trans;
  String? get plusCase => headword.plusCase;
  String? get meaning1 => headword.meaning1;
  String? get meaningLit => headword.meaningLit;
  String? get meaning2 => headword.meaning2;
  String? get rootKey => headword.rootKey;
  int? get rootCount => this.rootCount;
  String? get rootSign => headword.rootSign;
  String? get rootBase => headword.rootBase;
  String? get familyRoot => headword.familyRoot;
  String? get familyWord => headword.familyWord;
  String? get familyCompound => headword.familyCompound;
  String? get familyIdioms => headword.familyIdioms;
  String? get familySet => headword.familySet;
  String? get construction => headword.construction;
  String? get compoundType => headword.compoundType;
  String? get compoundConstruction => headword.compoundConstruction;
  String? get source1 => headword.source1;
  String? get sutta1 => headword.sutta1;
  String? get example1 => headword.example1;
  String? get source2 => headword.source2;
  String? get sutta2 => headword.sutta2;
  String? get example2 => headword.example2;
  String? get antonym => headword.antonym;
  String? get synonym => headword.synonym;
  String? get variant => headword.variant;
  String? get stem => headword.stem;
  String? get pattern => headword.pattern;
  String? get derivative => headword.derivative;
  String? get suffix => headword.suffix;
  String? get freqData => headword.freqData;
  int? get ebtCount => headword.ebtCount;
  String? get nonIa => headword.nonIa;
  String? get sanskrit => headword.sanskrit;
  String? get cognate => headword.cognate;
  String? get link => headword.link;
  String? get phonetic => headword.phonetic;
  String? get varPhonetic => headword.varPhonetic;
  String? get varText => headword.varText;
  String? get origin => headword.origin;
  String? get notes => headword.notes;
  String? get commentary => headword.commentary;
}
