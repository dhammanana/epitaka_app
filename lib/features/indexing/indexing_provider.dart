import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/models/translation_version.dart';
import '../../core/providers/translation_manifest_provider.dart';
import '../../core/utils/database_initializer.dart';
import '../../features/settings/providers/translation_download_provider.dart';
import 'index_controller.dart';/// Provider that returns true if the FTS index is built and ready.
final isIndexReadyProvider = Provider<bool>((ref) {
  return ref.watch(indexControllerProvider.select((s) => s.isBuilt));
});

/// Provider that returns true if the index is currently building.
final isIndexBuildingProvider = Provider<bool>((ref) {
  return ref.watch(indexControllerProvider.select((s) => s.isBuilding));
});

/// Provider that returns translation versions available on disk.
/// Based on the merged manifest + local versions.
final ftsAvailableVersionsProvider =
    FutureProvider<List<TranslationVersion>>((ref) async {
  final merged = await ref.watch(mergedTranslationVersionsProvider.future);
  final available = merged.where((v) => v.isAvailable).toList();
  // Sort: English first, then alphabetically by language name
  available.sort((a, b) {
    if (a.languageCode == 'en') return -1;
    if (b.languageCode == 'en') return 1;
    return a.englishName.compareTo(b.englishName);
  });
  return available;
});

/// Provider that returns translation versions available for download
/// (have a download URL from the manifest) but not yet installed on disk.
final ftsDownloadableVersionsProvider =
    FutureProvider<List<TranslationVersion>>((ref) async {
  final merged = await ref.watch(mergedTranslationVersionsProvider.future);
  return merged
      .where((v) => !v.isAvailable && v.hasDownloadUrl)
      .toList()
    ..sort((a, b) {
      if (a.languageCode == 'en') return -1;
      if (b.languageCode == 'en') return 1;
      return a.englishName.compareTo(b.englishName);
    });
});

/// Provider for the download state of a specific version key.
/// The key is `langCode[_suffix]` (e.g. 'en', 'my_nissaya').
final ftsDownloadStateProvider =
    Provider.family<TranslationDownloadState, String>((ref, versionKey) {
  final downloadStates = ref.watch(translationDownloadProvider);
  return downloadStates[versionKey] ?? const TranslationDownloadState();
});

/// Helper to check if a core database file exists on disk.
Future<bool> coreAssetExists(String filename) async {
  final dir = await getDatabaseDirectory();
  return File(p.join(dir.path, filename)).exists();
}

/// Provider that returns a list of core assets (epitaka, dpd_dictionary,
/// embeddings) that are compulsory but not yet installed on disk.
///
/// This is used by the startup wizard to require downloading these before
/// the index can be built.
final ftsRequiredCoreAssetsProvider =
    FutureProvider<List<CoreAsset>>((ref) async {
  final manifest = await ref.watch(translationManifestProvider.future);
  final required = <CoreAsset>[];

  for (final entry in manifest.core.entries) {
    final asset = entry.value;
    if (!asset.compulsory) continue;
    final filename = asset.filename ?? '${entry.key}.db';
    final exists = await coreAssetExists(filename);
    if (!exists) {
      required.add(asset);
    }
  }

  return required;
});

/// Provider that returns translations that are compulsory (marked
/// `compulsory: true` in the manifest) but not yet installed on disk.
/// Uses the merged provider so already-installed versions are correctly
/// excluded even though the manifest version object has isAvailable=false.
final ftsRequiredTranslationsProvider =
    FutureProvider<List<TranslationVersion>>((ref) async {
  final merged = await ref.watch(mergedTranslationVersionsProvider.future);
  final required = <TranslationVersion>[];

  for (final v in merged) {
    if (v.isAvailable || !v.compulsory) continue;
    if (v.hasDownloadUrl) required.add(v);
  }

  return required;
});

/// Combined provider: true if all compulsory items are installed (core +
/// translations needed for the FTS index).
final ftsAllRequiredReadyProvider = FutureProvider<bool>((ref) async {
  final coreRequired = await ref.watch(ftsRequiredCoreAssetsProvider.future);
  if (coreRequired.isNotEmpty) return false;

  final transRequired =
      await ref.watch(ftsRequiredTranslationsProvider.future);
  if (transRequired.isNotEmpty) return false;

  return true;
});
