import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/models/app_models.dart';
import '../../core/providers/app_db_provider.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/translation_manifest_provider.dart';

// ── Result types used by IndexController ───────────────────────────────

/// Result of a `checkStatus()` call on the index service.
class IndexCheckStatus {
  final bool healthy;
  final bool isComplete;
  final bool paliBuilt;

  const IndexCheckStatus({
    required this.healthy,
    required this.isComplete,
    required this.paliBuilt,
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
  ///
  /// [translationLang] is the language code (e.g. 'en', 'si', 'th').
  /// [onProgress] receives progress updates (0.0-1.0) with status message.
  Future<void> buildIndex({
    required String translationLang,
    void Function(double progress, String status)? onProgress,
  }) async {
    debugPrint('[INDEX_SVC] buildIndex: starting for lang=$translationLang');
    final appDb = await _ref.read(appDbProvider.future);
    final epitakaDb = await _ref.read(epitakaDbProvider.future);
    final translationLangEnum = TranslationLanguage.values.firstWhere(
      (l) => l.code == translationLang,
      orElse: () => TranslationLanguage.english,
    );
    final transDb = await _ref.read(
      translationDbProvider(translationLangEnum).future,
    );

    if (transDb == null) {
      throw Exception('Translation database not found for $translationLang');
    }

    debugPrint('[INDEX_SVC] buildIndex: databases loaded, starting FTS build');

    // Build the Pali index if not already built
    final paliBuilt = await appDb.isSearchIndexBuilt();
    if (!paliBuilt) {
      await appDb.buildSearchIndex(
        epitakaDb,
        onProgress: onProgress,
      );
    }

    // Build translation index
    await appDb.buildTranslationSearchIndex(
      translationLang,
      transDb,
      onProgress: onProgress,
    );
    debugPrint('[INDEX_SVC] buildIndex: completed');
  }

  /// Check the current status of the FTS indexes (Pali + translations).
  Future<IndexCheckStatus> checkStatus() async {
    debugPrint('[INDEX_SVC] checkStatus: checking index status');
    try {
      final appDb = await _ref.read(appDbProvider.future);
      final paliBuilt = await appDb.isSearchIndexBuilt();

      if (paliBuilt) {
        return const IndexCheckStatus(
          healthy: true,
          isComplete: true,
          paliBuilt: true,
        );
      }

      return const IndexCheckStatus(
        healthy: true,
        isComplete: false,
        paliBuilt: false,
      );
    } on AppDatabaseCorruptedException catch (e) {
      debugPrint('[INDEX_SVC] checkStatus: database corrupted: $e');
      return IndexCheckStatus(
        healthy: false,
        isComplete: false,
        paliBuilt: false,
      );
    } catch (e) {
      debugPrint('[INDEX_SVC] checkStatus: unexpected error: $e');
      return IndexCheckStatus(
        healthy: false,
        isComplete: false,
        paliBuilt: false,
      );
    }
  }

  /// Build FTS indexes for Pāli + all available translation databases.
  /// Returns a result indicating any languages that could not be indexed.
  Future<IndexBuildResult> build(
    IndexCheckStatus status, {
    void Function(double progress, String status)? onProgress,
  }) async {
    debugPrint('[INDEX_SVC] build: starting build');
    final appDb = await _ref.read(appDbProvider.future);
    final epitakaDb = await _ref.read(epitakaDbProvider.future);

    // Build Pali index if not yet built
    if (!status.paliBuilt) {
      await appDb.buildSearchIndex(
        epitakaDb,
        onProgress: onProgress,
      );
    }

    // Build translation indexes for ALL available versions on disk
    final pending = <String>[];
    final merged = await _ref.read(mergedTranslationVersionsProvider.future);
    final availableVersions = merged.where((v) => v.isAvailable).toList();

    // Deduplicate by language code — only build one index per language
    final seenLangCodes = <String>{};
    for (final version in availableVersions) {
      if (seenLangCodes.contains(version.languageCode)) continue;
      seenLangCodes.add(version.languageCode);
      try {
        final langEnum = TranslationLanguage.fromCode(version.languageCode);
        final transDb = await _ref.read(
          translationDbProvider(langEnum).future,
        );
        if (transDb != null) {
          final alreadyBuilt = await appDb.isTranslationIndexBuilt(
              version.languageCode);
          if (!alreadyBuilt) {
            await appDb.buildTranslationSearchIndex(
              version.languageCode,
              transDb,
              onProgress: onProgress,
            );
          } else {
            debugPrint(
                '[INDEX_SVC] build: ${version.languageCode} index already built, skipping');
          }
        } else {
          pending.add(version.languageCode);
        }
      } catch (e) {
        debugPrint(
            '[INDEX_SVC] build: failed for ${version.languageCode}: $e');
        pending.add(version.languageCode);
      }
    }

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
      final result = await appDb.customSelect(
        'SELECT COUNT(*) AS cnt FROM search_fts',
      ).get();
      if (result.isNotEmpty) return (result.first.data['cnt'] as num).toInt();
    } catch (_) {}
    return 0;
  }

  /// Get which translation language was indexed.
  Future<String?> getIndexedTranslationLang() async {
    return null; // No longer tracked in a single config
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
