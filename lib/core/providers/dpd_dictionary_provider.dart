import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/dpd_dictionary_database.dart';

// ── Helper: run synchronous computation after frame ───────────────────────

/// Runs a synchronous computation AFTER the current frame is fully
/// complete (layout, paint, and semantics flushed).
///
/// This prevents synchronous `sqlite3` database calls from blocking the
/// main thread during frame processing. If a synchronous DB operation
/// runs during a frame where semantics are being updated, it can trigger
/// `!semantics.parentDataDirty` assertion errors in
/// `RenderObject.showOnScreen()`.
///
/// The post-frame callback ensures all pending frame work (including
/// semantics updates) is flushed before the blocking DB call begins.
Future<T> _runAfterFrame<T>(T Function() computation) async {
  final completer = Completer<T>();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    try {
      completer.complete(computation());
    } catch (e, st) {
      completer.completeError(e, st);
    }
  });
  return completer.future;
}

// ── Database Provider ──────────────────────────────────────────────────────

/// Provider for the new DPD dictionary database (dpd-dictionary.db).
///
/// The database is kept alive and disposed when the provider is destroyed.
final dpdDictionaryDbProvider = FutureProvider<DpdDictionaryDatabase>((
  ref,
) async {
  final dbPath = await _resolveDpdDictionaryDbPath();
  final db = await DpdDictionaryDatabase.open(dbPath);
  ref.onDispose(() {
    db.dispose();
  });
  return db;
});

/// Resolve the path to dpd-dictionary.db.
Future<String> _resolveDpdDictionaryDbPath() async {
  final envDbPath = Platform.environment['EPITAKA_DB_PATH'];
  if (envDbPath != null && envDbPath.isNotEmpty) {
    final dir = Directory(envDbPath);
    if (await dir.exists()) {
      return p.join(dir.path, 'dpd-dictionary.db');
    }
  }

  if (!Platform.isAndroid && !Platform.isIOS) {
    final cwd = Directory.current;
    final dataDir = Directory(p.join(cwd.path, 'data'));
    if (await dataDir.exists()) {
      return p.join(dataDir.path, 'dpd-dictionary.db');
    }
  }

  final appDir = await getApplicationDocumentsDirectory();
  return p.join(appDir.path, 'dpd-dictionary.db');
}

// ── Search Provider ─────────────────────────────────────────────────────────

/// Search DPD dictionary by prefix on the lookup table.
/// Returns headword rows matching the lookup key prefix.
final dpdDictionarySearchProvider = FutureProvider.autoDispose
    .family<List<DpdHeadwordRow>, String>((ref, query) async {
      final trimmed = query.trim();
      if (trimmed.isEmpty) return [];

      final db = await ref.watch(dpdDictionaryDbProvider.future);

      // Run synchronous DB calls after the current frame to avoid blocking
      // the main thread during frame processing (prevents semantics corruption).
      return _runAfterFrame(() {
        // 1. Try exact lookup first
        final exact = db.getLookup(trimmed.toLowerCase());
        if (exact != null && exact.headwords.isNotEmpty) {
          return db.getHeadwordsByIds(exact.headwords);
        }

        // 2. Fall back to prefix search
        final lookups = db.searchLookup(trimmed, limit: 25);
        final allIds = <int>{};
        for (final lr in lookups) {
          allIds.addAll(lr.headwords);
        }

        if (allIds.isEmpty) return <DpdHeadwordRow>[];

        final headwords = db.getHeadwordsByIds(allIds.toList());
        headwords.sort((a, b) => a.lemma1.compareTo(b.lemma1));
        return headwords;
      });
    });

// ── Lookup + Deconstructor Provider ─────────────────────────────────────────

/// Full lookup data for a word, including deconstructor candidates and headwords.
class DpdFullLookup {
  final DpdLookupRow? lookup;
  final List<DpdHeadwordRow> headwords;
  final List<DeconstructionCandidate> deconstructionCandidates;
  final String searchedKey;

  const DpdFullLookup({
    this.lookup,
    this.headwords = const [],
    this.deconstructionCandidates = const [],
    required this.searchedKey,
  });

  bool get hasDeconstructor => deconstructionCandidates.isNotEmpty;
  bool get hasHeadwords => headwords.isNotEmpty;
}

/// Full lookup for a word in the DPD dictionary.
final dpdDictionaryLookupProvider = FutureProvider.autoDispose
    .family<DpdFullLookup, String>((ref, word) async {
      if (word.trim().isEmpty) {
        return DpdFullLookup(searchedKey: word);
      }

      final db = await ref.watch(dpdDictionaryDbProvider.future);
      final normalized = word.trim().toLowerCase();

      // Run synchronous DB calls after the current frame to avoid blocking
      // the main thread during frame processing (prevents semantics corruption).
      final sw = Stopwatch()..start();
      developer.log('[DICT] lookup start word="$word"', name: 'epitaka.dict');
      final result = await _runAfterFrame(() {
        final lookup = db.getLookup(normalized);

        List<DpdHeadwordRow> headwords = [];
        List<DeconstructionCandidate> decons = [];

        if (lookup != null) {
          // Parse deconstructor
          for (final raw in lookup.deconstructor) {
            decons.add(DeconstructionCandidate.parse(raw));
          }

          // Get headwords
          if (lookup.headwords.isNotEmpty) {
            headwords = db.getHeadwordsByIds(lookup.headwords);
          }
        }

        return DpdFullLookup(
          lookup: lookup,
          headwords: headwords,
          deconstructionCandidates: decons,
          searchedKey: normalized,
        );
      });
      sw.stop();
      developer.log(
        '[DICT] lookup done word="$word" elapsedMs=${sw.elapsedMilliseconds} '
        'hasHeadwords=${result.hasHeadwords} hasDecon=${result.hasDeconstructor}',
        name: 'epitaka.dict',
      );
      return result;
    });

// ── Headword Sub-lookup Provider ─────────────────────────────────────────────

/// Lookup a word that appears as a token in a deconstruction.
/// Finds its lookup entry and returns headwords.
final dpdSubLookupProvider = FutureProvider.autoDispose
    .family<List<DpdHeadwordRow>, String>((ref, word) async {
      if (word.trim().isEmpty) return [];

      final db = await ref.watch(dpdDictionaryDbProvider.future);
      final normalized = word.trim().toLowerCase();

      // Run synchronous DB calls after the current frame.
      return _runAfterFrame(() {
        final lookup = db.getLookup(normalized);
        if (lookup == null || lookup.headwords.isEmpty)
          return <DpdHeadwordRow>[];
        return db.getHeadwordsByIds(lookup.headwords);
      });
    });
