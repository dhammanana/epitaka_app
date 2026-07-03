import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/epitaka_database.dart';
import '../database/translation_database.dart';
import '../models/app_models.dart';
import 'settings_provider.dart';

/// Provider for the main Tipitaka database (epitaka.db).
final epitakaDbProvider = FutureProvider<EpitakaDatabase>((ref) async {
  final dbDir = await _getDatabaseDirectory();
  final dbPath = p.join(dbDir.path, 'epitaka.db');
  return EpitakaDatabase.open(dbPath);
});

/// Provider for a specific translation database.
final translationDbProvider =
    FutureProvider.family<TranslationDatabase?, TranslationLanguage>(
        (ref, lang) async {
  final dbDir = await _getDatabaseDirectory();
  final dbPath = p.join(dbDir.path, lang.filename);
  final file = File(dbPath);
  if (!await file.exists()) {
    return null;
  }
  return TranslationDatabase.open(dbPath);
});

/// Get the database directory.
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

/// Provider that watches the settings and returns the active translation language.
final activeTranslationLangProvider = Provider<TranslationLanguage>((ref) {
  final settings = ref.watch(settingsProvider);
  return TranslationLanguage.fromCode(settings.primaryTranslationLang);
});
