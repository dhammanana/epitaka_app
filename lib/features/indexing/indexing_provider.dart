import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/translation_registry_provider.dart';
import '../../features/settings/providers/translation_download_provider.dart';
import 'index_controller.dart';
import 'index_state.dart';

/// Provider that returns true if the FTS index is built and ready.
final isIndexReadyProvider = Provider<bool>((ref) {
  return ref.watch(indexControllerProvider.select((s) => s.isBuilt));
});

/// Provider that returns true if the index is currently building.
final isIndexBuildingProvider = Provider<bool>((ref) {
  return ref.watch(indexControllerProvider.select((s) => s.isBuilding));
});

/// Provider that returns an ordered list of available translation languages
/// suitable for FTS indexing (sorted by english name, English first).
final ftsAvailableTranslationsProvider = Provider<List<AvailableTranslation>>((ref) {
  final availableAsync = ref.watch(translationRegistryProvider);
  return availableAsync.when(
    data: (translations) {
      final available = translations.where((t) => t.isAvailable).toList();
      // Sort: English first, then alphabetically
      available.sort((a, b) {
        if (a.languageCode == 'en') return -1;
        if (b.languageCode == 'en') return 1;
        return a.englishName.compareTo(b.englishName);
      });
      return available;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Provider that returns translations available for download (have a download URL
/// configured) but not yet installed on disk.
final ftsDownloadableTranslationsProvider = Provider<List<AvailableTranslation>>((ref) {
  final availableAsync = ref.watch(translationRegistryProvider);
  return availableAsync.when(
    data: (translations) {
      return translations
          .where((t) =>
              !t.isAvailable && TranslationDownloadNotifier.hasDownloadUrl(t.languageCode))
          .toList()
        ..sort((a, b) {
          if (a.languageCode == 'en') return -1;
          if (b.languageCode == 'en') return 1;
          return a.englishName.compareTo(b.englishName);
        });
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Provider for the download state of a specific translation.
final ftsDownloadStateProvider =
    Provider.family<TranslationDownloadState, String>((ref, langCode) {
  final downloadStates = ref.watch(translationDownloadProvider);
  return downloadStates[langCode] ?? const TranslationDownloadState();
});
