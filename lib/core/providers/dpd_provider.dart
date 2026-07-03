import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/dpd_database.dart';

// ignore: unused_import
// (Drift table types used implicitly via db.select/db.dao)

// ── Database Provider ──────────────────────────────────────────────────────

/// Provider for the DPD mobile dictionary database.
final dpdDbProvider = FutureProvider<DpdDatabase>((ref) async {
  final dbPath = await _resolveDpdDbPath();
  return DpdDatabase.open(dbPath);
});

/// Resolve the path to dpd-mobile.db.
Future<String> _resolveDpdDbPath() async {
  final envDbPath = Platform.environment['EPITAKA_DB_PATH'];
  if (envDbPath != null && envDbPath.isNotEmpty) {
    final dir = Directory(envDbPath);
    if (await dir.exists()) {
      return p.join(dir.path, 'dpd-mobile.db');
    }
  }

  // On mobile, skip the relative-path fallback (Directory.current points to
  // root `/` on Android, making `/data/` appear to exist but inaccessible).
  if (!Platform.isAndroid && !Platform.isIOS) {
    final cwd = Directory.current;
    final dataDir = Directory(p.join(cwd.path, 'data'));
    if (await dataDir.exists()) {
      return p.join(dataDir.path, 'dpd-mobile.db');
    }
  }

  final appDir = await getApplicationDocumentsDirectory();
  return p.join(appDir.path, 'dpd-mobile.db');
}

// ── Models ─────────────────────────────────────────────────────────────────

/// Summary result for a search result card.
class DpdSearchResult {
  final int id;
  final String lemma1;
  final String? lemma2;
  final String? pos;
  final String? grammar;
  final String? meaning1;
  final String? meaningLit;
  final String? meaning2;
  final String? construction;

  const DpdSearchResult({
    required this.id,
    required this.lemma1,
    this.lemma2,
    this.pos,
    this.grammar,
    this.meaning1,
    this.meaningLit,
    this.meaning2,
    this.construction,
  });

  factory DpdSearchResult.fromHeadword(DpdHeadword hw) {
    return DpdSearchResult(
      id: hw.id,
      lemma1: hw.lemma1,
      lemma2: hw.lemma2,
      pos: hw.pos,
      grammar: hw.grammar,
      meaning1: hw.meaning1,
      meaningLit: hw.meaningLit,
      meaning2: hw.meaning2,
      construction: hw.construction,
    );
  }

  /// Short summary line for display in search results.
  /// Covers all 3 meaning values (meaning1, meaningLit, meaning2).
  String get summaryLine {
    final parts = <String>[];
    if (pos != null && pos!.isNotEmpty) parts.add(pos!);
    if (grammar != null && grammar!.isNotEmpty) parts.add('($grammar)');
    if (meaning1 != null && meaning1!.isNotEmpty) parts.add(meaning1!);
    if (meaningLit != null && meaningLit!.isNotEmpty) parts.add('lit. $meaningLit');
    if (meaning2 != null && meaning2!.isNotEmpty) parts.add(meaning2!);
    return parts.join(' · ');
  }
}

/// Full entry data for rendering the detail view.
class DpdEntryData {
  final DpdHeadword headword;
  final LookupData? lookup;
  final DpdRoot? root;
  final List<String> deconstructions;

  const DpdEntryData({
    required this.headword,
    this.lookup,
    this.root,
    this.deconstructions = const [],
  });

  /// Format the headword into a readable plain-text summary.
  String get formattedSummary {
    final parts = <String>[];

    if (headword.pos != null && headword.pos!.isNotEmpty) {
      parts.add(headword.pos!);
      if (headword.grammar != null && headword.grammar!.isNotEmpty) {
        parts.add('(${headword.grammar})');
      }
    }

    if (headword.meaning1 != null && headword.meaning1!.isNotEmpty) {
      parts.add(headword.meaning1!);
    }

    if (headword.meaningLit != null && headword.meaningLit!.isNotEmpty) {
      parts.add('lit. ${headword.meaningLit}');
    }

    if (headword.meaning2 != null && headword.meaning2!.isNotEmpty) {
      parts.add(headword.meaning2!);
    }

    if (headword.construction != null && headword.construction!.isNotEmpty) {
      parts.add('[${headword.construction}]');
    }

    return parts.join(' · ');
  }

  /// Parse headwords JSON from lookup into a list of headword IDs.
  List<int> get linkedHeadwordIds {
    final hwJson = lookup?.headwords;
    if (hwJson == null || hwJson.isEmpty) return [];
    try {
      final parsed = jsonDecode(hwJson);
      return (parsed as List).cast<int>();
    } catch (_) {
      return [];
    }
  }

  /// Parse root family string from the headword into individual keys.
  List<String> get rootFamilyKeys {
    final raw = headword.familyRoot;
    if (raw == null || raw.isEmpty) return [];
    return raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Parse word family string.
  List<String> get wordFamilyItems {
    final raw = headword.familyWord;
    if (raw == null || raw.isEmpty) return [];
    return raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Parse compound family string.
  List<String> get compoundFamilyItems {
    final raw = headword.familyCompound;
    if (raw == null || raw.isEmpty) return [];
    return raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// True if any families exist.
  bool get hasFamilies =>
      rootFamilyKeys.isNotEmpty ||
      wordFamilyItems.isNotEmpty ||
      compoundFamilyItems.isNotEmpty ||
      (headword.antonym != null && headword.antonym!.isNotEmpty) ||
      (headword.synonym != null && headword.synonym!.isNotEmpty) ||
      (headword.variant != null && headword.variant!.isNotEmpty);

  /// True if there are grammar details beyond pos/grammar fields.
  bool get hasGrammarDetails =>
      (headword.derivedFrom != null && headword.derivedFrom!.isNotEmpty) ||
      (headword.neg != null && headword.neg!.isNotEmpty) ||
      (headword.verb != null && headword.verb!.isNotEmpty) ||
      (headword.trans != null && headword.trans!.isNotEmpty) ||
      (headword.plusCase != null && headword.plusCase!.isNotEmpty) ||
      (headword.stem != null && headword.stem!.isNotEmpty) ||
      (headword.pattern != null && headword.pattern!.isNotEmpty) ||
      (headword.suffix != null && headword.suffix!.isNotEmpty) ||
      (headword.compoundType != null && headword.compoundType!.isNotEmpty) ||
      (headword.rootKey != null && headword.rootKey!.isNotEmpty) ||
      (headword.rootSign != null && headword.rootSign!.isNotEmpty) ||
      (headword.rootBase != null && headword.rootBase!.isNotEmpty);
}

/// A parsed deconstruction candidate with its component tokens.
class DpdDeconstructionCandidate {
  final String raw;
  final List<String> tokens;

  const DpdDeconstructionCandidate({
    required this.raw,
    required this.tokens,
  });

  factory DpdDeconstructionCandidate.parse(String line) {
    return DpdDeconstructionCandidate(
      raw: line,
      tokens: line
          .split('+')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
    );
  }
}

/// Parsed deconstruction data for a compound word.
class DpdDeconstructionData {
  final String word;
  final List<DpdDeconstructionCandidate> candidates;

  const DpdDeconstructionData({
    required this.word,
    required this.candidates,
  });

  bool get isEmpty => candidates.isEmpty;
}

// ── Prefix Search Provider ─────────────────────────────────────────────────

/// Search DPD by prefix on the lookup table.
///
/// Returns headword results matching the prefix.
/// Queries shorter than 2 characters are ignored (too many results, slow).
final dpdSearchProvider =
    FutureProvider.autoDispose.family<List<DpdSearchResult>, String>(
        (ref, query) async {
  final trimmed = query.trim();
  if (trimmed.length < 2) return [];

  final db = await ref.watch(dpdDbProvider.future);
  final dao = db.dao;

  // 1. Prefix search on lookup table
  final lookups = await dao.searchLookup(trimmed, limit: 25);

  // 2. Collect all headword IDs from lookup results
  final allIds = <int>{};
  for (final lr in lookups) {
    final hwJson = lr.headwords;
    if (hwJson == null || hwJson.isEmpty) continue;
    try {
      final ids = (jsonDecode(hwJson) as List).cast<int>();
      allIds.addAll(ids);
    } catch (_) {}
  }

  if (allIds.isEmpty) return [];

  // 3. Fetch headwords
  final headwords = await dao.getHeadwordsByIds(allIds.toList());

  // 4. Sort by ASCII (placeholder for proper Pāḷi sort)
  headwords.sort((a, b) => a.lemma1.compareTo(b.lemma1));

  return headwords.map(DpdSearchResult.fromHeadword).toList();
});

// ── Entry Data Provider ────────────────────────────────────────────────────

/// Full entry data for a headword by its ID.
///
/// Fetches headword, root, and deconstructor data in a single lookup by ID
/// — bypasses the lookup table entirely (ID is already known from search).
final dpdEntryProvider =
    FutureProvider.autoDispose.family<DpdEntryData?, int>(
        (ref, headwordId) async {
  final db = await ref.watch(dpdDbProvider.future);
  final dao = db.dao;

  // 1. Fetch headword by ID directly
  final hw = await dao.getHeadword(headwordId);
  if (hw == null) return null;

  // 2. Get root if available
  DpdRoot? root;
  if (hw.rootKey != null && hw.rootKey!.isNotEmpty) {
    root = await dao.getRoot(hw.rootKey!);
  }

  // 3. Get deconstruction data from lookup table
  final lookup = await dao.getLookup(hw.lemma1.toLowerCase());
  final deconList = dao.parseDeconstructor(lookup?.deconstructor);

  return DpdEntryData(
    headword: hw,
    lookup: lookup,
    root: root,
    deconstructions: deconList,
  );
});

// ── Deconstruction Provider ────────────────────────────────────────────────

/// Get deconstruction candidates for a compound word.
final dpdDeconstructionProvider =
    FutureProvider.autoDispose.family<DpdDeconstructionData?, String>(
        (ref, word) async {
  if (word.trim().isEmpty) return null;

  final db = await ref.watch(dpdDbProvider.future);
  final dao = db.dao;

  final rawCandidates = await dao.getDeconstructions(word.trim().toLowerCase());

  if (rawCandidates.isEmpty) return null;

  final candidates =
      rawCandidates.map(DpdDeconstructionCandidate.parse).toList();

  return DpdDeconstructionData(
    word: word.trim().toLowerCase(),
    candidates: candidates,
  );
});

// ── Legacy Provider (kept for backward compatibility) ──────────────────────

/// A single dictionary lookup result (legacy format).
class DpdLookupResult {
  final String word;
  final String? definitionHtml;
  final String? definitionPlain;
  final String? dictId;

  const DpdLookupResult({
    required this.word,
    this.definitionHtml,
    this.definitionPlain,
    this.dictId,
  });
}

/// Legacy exact search provider (kept for backward compatibility).
final dpdExactSearchProvider =
    FutureProvider.autoDispose.family<List<DpdLookupResult>, String>(
        (ref, word) async {
  if (word.trim().isEmpty) return [];

  final db = await ref.watch(dpdDbProvider.future);
  final normalized = word.trim().toLowerCase();

  final rows = await (db.select(db.dictEntries)
        ..where((t) => t.word.equals(normalized))
        ..orderBy([(t) => OrderingTerm(expression: t.dictId)]))
      .get();

  return rows.map((row) {
    return DpdLookupResult(
      word: row.word,
      definitionHtml: row.definitionHtml,
      definitionPlain: row.definitionPlain,
      dictId: row.dictId,
    );
  }).toList();
});

/// Legacy exact lookup provider (kept for backward compatibility).
final dpdExactLookupProvider =
    FutureProvider.autoDispose.family<List<DpdLookupResult>, String>(
        (ref, word) async {
  if (word.trim().isEmpty) return [];

  final db = await ref.watch(dpdDbProvider.future);
  final normalized = word.trim().toLowerCase();

  // First, check dict_entries for external dictionaries
  final dictRows = await (db.select(db.dictEntries)
        ..where((t) => t.word.equals(normalized))
        ..orderBy([(t) => OrderingTerm(expression: t.dictId)]))
      .get();

  final results = dictRows.map((row) {
    return DpdLookupResult(
      word: row.word,
      definitionHtml: row.definitionHtml,
      definitionPlain: row.definitionPlain,
      dictId: row.dictId,
    );
  }).toList();

  // Then, look up in the DPD headwords via lookup table
  final lookupRows = await (db.select(db.lookup)
        ..where((t) => t.lookupKey.equals(normalized)))
      .get();

  for (final lr in lookupRows) {
    final hwJson = lr.headwords;
    if (hwJson == null || hwJson.isEmpty) continue;
    try {
      final ids = (jsonDecode(hwJson) as List).cast<int>();
      for (final id in ids) {
        final hwRows = await (db.select(db.dpdHeadwords)
              ..where((t) => t.id.equals(id)))
            .get();
        for (final hw in hwRows) {
          results.add(DpdLookupResult(
            word: hw.lemma1,
            definitionPlain: _legacyFormatDpdHeadword(hw),
            dictId: 'dpd_headwords',
          ));
        }
      }
    } catch (_) {
      // Ignore JSON parse errors in lookup
    }
  }

  return results;
});

/// Legacy format: plain text summary of a headword.
String _legacyFormatDpdHeadword(DpdHeadword hw) {
  final parts = <String>[];

  final pos = hw.pos;
  final grammar = hw.grammar;
  if (pos != null && pos.isNotEmpty) {
    parts.add(pos);
    if (grammar != null && grammar.isNotEmpty) {
      parts.add('($grammar)');
    }
  }

  final meaning1 = hw.meaning1;
  if (meaning1 != null && meaning1.isNotEmpty) {
    parts.add(meaning1);
  }

  final meaningLit = hw.meaningLit;
  if (meaningLit != null && meaningLit.isNotEmpty) {
    parts.add('lit. $meaningLit');
  }

  final meaning2 = hw.meaning2;
  if (meaning2 != null && meaning2.isNotEmpty) {
    parts.add(meaning2);
  }

  final construction = hw.construction;
  if (construction != null && construction.isNotEmpty) {
    parts.add('[$construction]');
  }

  return parts.join(' · ');
}
