import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/translation_version.dart';

/// Default URL for the translation manifest JSON.
///
/// This should point to a JSON file hosted on GitHub Releases or Gist.
const String defaultManifestUrl =
    'https://raw.githubusercontent.com/dhammanana/epitaka_release/main/translations.json';

/// The download base URL prefix.
/// Individual download URLs will be constructed as `$baseUrl/$filename.zip`
const String defaultDownloadBaseUrl =
    'https://github.com/dhammanana/epitaka_release/releases/download/v1.0.1';

/// Provider that fetches and caches the translation manifest.
final translationManifestProvider =
    FutureProvider<TranslationManifest>((ref) async {
  try {
    final response = await http
        .get(Uri.parse(defaultManifestUrl))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return TranslationManifest.fromJson(json);
    }
  } catch (_) {
    // Network error — return empty manifest
  }

  return const TranslationManifest();
});

/// Provider that returns downloadable versions from the manifest,
/// merged with locally available versions.
final mergedTranslationVersionsProvider =
    FutureProvider<List<TranslationVersion>>((ref) async {
  // Get locally available versions
  final localVersions = await ref.watch(localTranslationVersionsProvider.future);
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
      final idx = merged.indexWhere((m) =>
          m.languageCode == v.languageCode && m.suffix == v.suffix);
      if (idx >= 0 && v.downloadUrl != null) {
        merged[idx] = merged[idx].copyWith(
          downloadUrl: v.downloadUrl,
          fileSize: v.fileSize,
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
  final dir = await _getDatabaseDirectory();
  return TranslationFilenameParser.scanDirectory(dir);
});

/// Get database directory (same as in database_initializer.dart).
Future<Directory> _getDatabaseDirectory() async {
  final envDbPath = Platform.environment['EPITAKA_DB_PATH'];
  if (envDbPath != null && envDbPath.isNotEmpty) {
    final dir = Directory(envDbPath);
    if (await dir.exists()) {
      return dir;
    }
  }

  if (!Platform.isAndroid && !Platform.isIOS) {
    final cwd = Directory.current;
    final dataDir = Directory(p.join(cwd.path, 'data'));
    if (await dataDir.exists()) {
      return dataDir;
    }
  }

  final appDir = await getApplicationDocumentsDirectory();
  return appDir;
}
