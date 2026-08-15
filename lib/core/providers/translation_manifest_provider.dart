import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/translation_version.dart';
import '../utils/database_initializer.dart';

/// Default URL for the translation manifest JSON.
const String defaultManifestUrl =
    'https://raw.githubusercontent.com/dhammanana/epitaka_app/refs/heads/main/assets/translations_manifest.json';

/// Provider that fetches and caches the translation manifest.
final translationManifestProvider = FutureProvider<TranslationManifest>((
  ref,
) async {
  TranslationManifest manifest;
  try {
    final response = await http
        .get(Uri.parse(defaultManifestUrl))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      manifest = TranslationManifest.fromJson(json);
    } else {
      manifest = const TranslationManifest();
    }
  } catch (_) {
    // Network error — return empty manifest
    manifest = const TranslationManifest();
  }

  // The manifest is the source of truth for which translations exist and
  // their display names. Register it so language names are resolved from
  // the server rather than a hardcoded list.
  TranslationLanguageRegistry.registerFromManifest(manifest);

  return manifest;
});

/// Provider that returns downloadable versions from the manifest,
/// merged with locally available versions.
final mergedTranslationVersionsProvider =
    FutureProvider<List<TranslationVersion>>((ref) async {
      // Get locally available versions
      final localVersions = await ref.watch(
        localTranslationVersionsProvider.future,
      );
      // Get manifest versions (from network)
      final manifest = await ref.watch(translationManifestProvider.future);

      final merged = <TranslationVersion>[];
      final seen = <String>{};

      // Helper to add version
      void addVersion(TranslationVersion v) {
        final key = '${v.languageCode}_${v.suffix ?? ''}';
        if (seen.contains(key)) return;
        seen.add(key);
        merged.add(v);
      }

      // First, add local versions (they're already available)
      for (final v in localVersions) {
        addVersion(v);
      }

      // Then add manifest versions, marking downloadUrl
      for (final v in manifest.allVersions) {
        final key = '${v.languageCode}_${v.suffix ?? ''}';
        if (seen.contains(key)) {
          // Already have local — merge download URL
          final idx = merged.indexWhere(
            (m) => m.languageCode == v.languageCode && m.suffix == v.suffix,
          );
          if (idx >= 0 && v.downloadUrl != null) {
            merged[idx] = merged[idx].copyWith(
              downloadUrl: v.downloadUrl,
              fileSize: v.fileSize,
              dbSize: v.dbSize,
              updatedAt: v.updatedAt,
              checksum: v.checksum,
            );
          }
        } else {
          addVersion(v);
        }
      }

      return merged;
    });

/// Provider that returns locally available translation versions by scanning
/// the database directory.
final localTranslationVersionsProvider =
    FutureProvider<List<TranslationVersion>>((ref) async {
      final dir = await getDatabaseDirectory();
      return TranslationFilenameParser.scanDirectory(dir);
    });
