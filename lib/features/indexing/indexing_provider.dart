import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/translation_version.dart';
import '../../core/providers/translation_manifest_provider.dart';
import '../../features/settings/providers/translation_download_provider.dart';
import 'index_controller.dart';

/// Provider that returns true if the FTS index is built and ready.
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
