import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/database/nissaya_database.dart';
import '../../core/database/translation_database.dart';
import '../../core/providers/app_db_provider.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/translation_manifest_provider.dart';
import '../../core/utils/database_initializer.dart';
import '../../core/models/translation_version.dart';
import '../ai_qa/services/mention_service.dart';

// ── Result types used by IndexController ───────────────────────────────

/// Max time for the database-prep step (bundled/legacy file copies) during
/// an index check. Generous on purpose: a first launch copies hundreds of MB.
const Duration _kDbPrepTimeout = Duration(minutes: 2);

/// Max time for opening app_data.db and querying sqlite_master. Normally
/// well under a second — anything longer means a hang (stale SQLite lock,
/// or path_provider's FFI stalling after a Flutter hot restart).
const Duration _kDbOpenTimeout = Duration(seconds: 45);

/// Result of a `checkStatus()` call on the index service.
class IndexCheckStatus {
  final bool healthy;
  final bool isComplete;
  final bool paliBuilt;
  final bool mentionBuilt;

  const IndexCheckStatus({
    required this.healthy,
    required this.isComplete,
    required this.paliBuilt,
    this.mentionBuilt = false,
  });
}

/// Result of a `build()` call on the index service.
class IndexBuildResult {
  final List<String> pendingLanguages;

  const IndexBuildResult({this.pendingLanguages = const []});
}

/// Service responsible for building FTS5 indexes from the source
/// Tipitaka database and translation databases.
class IndexService {
  final Ref _ref;

  IndexService(this._ref);

  /// Build the FTS5 index for the given translation language.
  Future<void> buildIndex({
    required String translationLang,
    void Function(double progress, String status)? onProgress,
  }) async {
    debugPrint('[INDEX_SVC] buildIndex: starting for lang=$translationLang');
    final appDb = await _ref.read(appDbProvider.future);
    final epitakaDb = await _ref.read(epitakaDbProvider.future);
    final transDb = await _ref.read(
      translationDbProvider(translationLang).future,
    );

    if (transDb == null) {
      throw Exception('Translation database not found for $translationLang');
    }

    // Build the Pali index if not already built
    final paliBuilt = await appDb.isSearchIndexBuilt();
    if (!paliBuilt) {
      await appDb.buildSearchIndex(epitakaDb, onProgress: onProgress);
    }

    // Build translation index
    await appDb.buildTranslationSearchIndex(
      translationLang,
      transDb,
      onProgress: onProgress,
    );
    debugPrint('[INDEX_SVC] buildIndex: completed');
  }

  /// Check the current status of the FTS indexes (Pali + translations)
  /// and the mention index.
  ///
  /// Every step has a timeout: without one, a hang deep in the chain (e.g.
  /// path_provider's FFI stalling after a Flutter hot restart, or a stale
  /// SQLite lock) leaves the gate on its "checking" spinner forever.
  /// [TimeoutException] is rethrown (not mapped to "corrupted") so the
  /// controller can offer a plain Retry instead of data-destructive recovery.
  Future<IndexCheckStatus> checkStatus() async {
    debugPrint('[INDEX_SVC] checkStatus: checking index status');
    try {
      debugPrint('[INDEX_SVC] checkStatus: ensuring databases ready…');
      try {
        await ensureDatabasesReady().timeout(_kDbPrepTimeout);
      } on TimeoutException {
        // A stuck prep future never resolves — drop it so a later Retry
        // starts over instead of re-awaiting the same stuck future.
        resetDatabasePrep();
        rethrow;
      }
      debugPrint('[INDEX_SVC] checkStatus: databases ready, opening app db…');
      final appDb = await _ref
          .read(appDbProvider.future)
          .timeout(_kDbOpenTimeout);

      debugPrint('[INDEX_SVC] checkStatus: checking indexes…');
      // Use cached index check to avoid re-checking on startup
      final cachedResults = await appDb
          .checkAllIndexesCached()
          .timeout(_kDbOpenTimeout);
      final paliBuilt = cachedResults['pali_fts'] ?? false;
      final mentionBuilt = cachedResults['mention_index'] ?? false;

      if (paliBuilt) {
        return IndexCheckStatus(
          healthy: true,
          isComplete: true,
          paliBuilt: true,
          mentionBuilt: mentionBuilt,
        );
      }

      return IndexCheckStatus(
        healthy: true,
        isComplete: false,
        paliBuilt: false,
        mentionBuilt: mentionBuilt,
      );
    } on AppDatabaseCorruptedException catch (e) {
      debugPrint('[INDEX_SVC] checkStatus: database corrupted: $e');
      return const IndexCheckStatus(
        healthy: false,
        isComplete: false,
        paliBuilt: false,
      );
    } on TimeoutException catch (e) {
      // Let the controller turn this into a Retry-able error screen.
      // Deliberately NOT mapped to healthy:false — that path suggests the
      // index is damaged and offers destructive recovery.
      debugPrint('[INDEX_SVC] checkStatus: timed out: $e');
      rethrow;
    } catch (e) {
      debugPrint('[INDEX_SVC] checkStatus: unexpected error: $e');
      return const IndexCheckStatus(
        healthy: false,
        isComplete: false,
        paliBuilt: false,
      );
    }
  }

  /// Build FTS indexes for Pāli + all available translation databases,
  /// then build the mention index for @ heading suggestions.
  Future<IndexBuildResult> build(
    IndexCheckStatus status, {
    void Function(double progress, String status)? onProgress,
  }) async {
    debugPrint('[INDEX_SVC] build: starting build');
    final appDb = await _ref.read(appDbProvider.future);
    final epitakaDb = await _ref.read(epitakaDbProvider.future);

    // Build Pali index if not yet built
    if (!status.paliBuilt) {
      onProgress?.call(0.05, 'Building Pāli search index…');
      await appDb.buildSearchIndex(
        epitakaDb,
        onProgress: (p, msg) => onProgress?.call(0.05 + p * 0.7, msg),
      );
    }

    // Build translation indexes for ALL available versions on disk
    final pending = <String>[];
    final merged = await _ref.read(mergedTranslationVersionsProvider.future);
    final availableVersions = merged.where((v) => v.isAvailable).toList();

    // Deduplicate by language code — only build one index per language
    final seenLangCodes = <String>{};
    for (final version in availableVersions) {
      if (version.isNissaya) continue;
      if (seenLangCodes.contains(version.languageCode)) continue;
      seenLangCodes.add(version.languageCode);
      try {
        final transDb = await _ref.read(
          translationDbProvider(version.languageCode).future,
        );
        if (transDb != null) {
          final alreadyBuilt = await appDb.isTranslationIndexBuilt(
            version.languageCode,
          );
          if (!alreadyBuilt) {
            await appDb.buildTranslationSearchIndex(
              version.languageCode,
              transDb,
              onProgress: (p, msg) => onProgress?.call(0.75 + p * 0.15, msg),
            );
          } else {
            debugPrint(
              '[INDEX_SVC] build: ${version.languageCode} index already built, skipping',
            );
          }
        } else {
          pending.add(version.languageCode);
        }
      } catch (e) {
        debugPrint('[INDEX_SVC] build: failed for ${version.languageCode}: $e');
        pending.add(version.languageCode);
      }
    }

    // Build mention index for @ heading suggestions
    if (!status.mentionBuilt) {
      onProgress?.call(0.92, 'Building heading index…');
      final mentionService = _ref.read(mentionServiceProvider);
      final count = await mentionService.buildIndex();
      debugPrint('[INDEX_SVC] Mention index built: $count entries');
    }

    // Ensure all database indexes exist (optimize query performance)
    onProgress?.call(0.95, 'Optimizing database indexes…');
    try {
      final translationDbs = <String, TranslationDatabase>{};
      for (final version in availableVersions) {
        if (version.isNissaya) continue;
        if (seenLangCodes.contains(version.languageCode)) continue;
        final transDb = await _ref.read(
          translationDbProvider(version.languageCode).future,
        );
        if (transDb != null) {
          translationDbs[version.languageCode] = transDb;
        }
      }
      NissayaDatabase? nissayaDb;
      try {
        for (final version in availableVersions) {
          if (version.isNissaya && version.isAvailable) {
            final filename = TranslationFilenameParser.build(version.languageCode);
            nissayaDb = await _ref.read(
              nissayaDbByFilenameProvider(filename).future,
            );
            break;
          }
        }
      } catch (_) {}

      await appDb.ensureAllDatabaseIndexes(
        epitakaDb: epitakaDb,
        translationDbs: translationDbs.isNotEmpty ? translationDbs : null,
        nissayaDb: nissayaDb,
      );
      // Clear the index check cache so next checkStatus() picks up the new indexes
      AppDatabase.clearIndexCheckCache();
    } catch (e) {
      debugPrint('[INDEX_SVC] Failed to ensure database indexes: $e');
    }

    onProgress?.call(1.0, 'Index complete');

    return IndexBuildResult(pendingLanguages: pending);
  }

  /// Clear the FTS index (Pali + translations) without rebuilding.
  Future<void> clearOnly() async {
    debugPrint('[INDEX_SVC] clearOnly: clearing all FTS indexes');
    final appDb = await _ref.read(appDbProvider.future);
    try {
      await appDb.customStatement('DROP TABLE IF EXISTS search_fts');
      await appDb.customStatement('DROP TABLE IF EXISTS search_words');
    } catch (_) {}
  }

  /// Check if the FTS5 index has been built (Pali index).
  Future<bool> isIndexBuilt() async {
    final appDb = await _ref.read(appDbProvider.future);
    return appDb.isSearchIndexBuilt();
  }

  /// Get the total number of indexed rows (Pali index).
  Future<int> getIndexedCount() async {
    final appDb = await _ref.read(appDbProvider.future);
    try {
      final result = await appDb
          .customSelect('SELECT COUNT(*) AS cnt FROM search_fts')
          .get();
      if (result.isNotEmpty) return (result.first.data['cnt'] as num).toInt();
    } catch (_) {}
    return 0;
  }

  /// Get which translation language was indexed.
  Future<String?> getIndexedTranslationLang() async {
    return null;
  }

  /// Clear the FTS index (Pali only).
  Future<void> clearIndex() async {
    debugPrint('[INDEX_SVC] clearIndex: clearing FTS index');
    final appDb = await _ref.read(appDbProvider.future);
    try {
      await appDb.customStatement('DROP TABLE IF EXISTS search_fts');
      await appDb.customStatement('DROP TABLE IF EXISTS search_words');
    } catch (_) {}
  }
}
