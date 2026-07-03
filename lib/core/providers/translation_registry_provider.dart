import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/app_models.dart';

/// Metadata for an available translation.
class AvailableTranslation {
  final String languageCode;
  final String englishName;
  final String nativeName;
  final bool isAvailable;

  const AvailableTranslation({
    required this.languageCode,
    required this.englishName,
    required this.nativeName,
    this.isAvailable = true,
  });

  TranslationLanguage get language => TranslationLanguage.fromCode(languageCode);
}

/// Provider that scans the database directory and returns a list of available
/// translations (i.e. DB files like `epitaka_th.db` that exist on disk).
final translationRegistryProvider =
    FutureProvider<List<AvailableTranslation>>((ref) async {
  final dbDir = await _getDatabaseDirectory();
  final fileNames =
      dbDir.listSync().whereType<File>().map((f) => f.path.split('/').last).toList();

  return TranslationLanguage.values.map((lang) {
    final exists = fileNames.contains(lang.filename);
    return AvailableTranslation(
      languageCode: lang.code,
      englishName: lang.englishName,
      nativeName: lang.nativeName,
      isAvailable: exists,
    );
  }).toList();
});

/// Get the database directory path.
Future<Directory> _getDatabaseDirectory() async {
  // Try a configurable path first
  final envDbPath = Platform.environment['EPITAKA_DB_PATH'];
  if (envDbPath != null && envDbPath.isNotEmpty) {
    final dir = Directory(envDbPath);
    if (await dir.exists()) {
      return dir;
    }
  }

  // On mobile, skip the relative-path fallback (Directory.current points to
  // root `/` on Android, making `/data/` appear to exist but inaccessible).
  if (!Platform.isAndroid && !Platform.isIOS) {
    final cwd = Directory.current;
    final dataDir = Directory(p.join(cwd.path, 'data'));
    if (await dataDir.exists()) {
      return dataDir;
    }
  }

  // Use the app documents directory
  final appDir = await getApplicationDocumentsDirectory();
  return appDir;
}
