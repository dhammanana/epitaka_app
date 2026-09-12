import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../database/epitaka_database.dart';
import '../database/nissaya_database.dart';
import '../database/translation_database.dart';
import '../models/translation_version.dart';
import '../utils/database_initializer.dart';

/// Provider for the main Tipitaka database (epitaka.db).
final epitakaDbProvider = FutureProvider<EpitakaDatabase>((ref) async {
  final dbDir = await getDatabaseDirectory();
  final dbPath = p.join(dbDir.path, 'epitaka.db');
  Object? lastError;
  for (var attempt = 0; attempt < 4; attempt++) {
    try {
      return await EpitakaDatabase.open(dbPath);
    } catch (e) {
      lastError = e;
      final msg = e.toString().toLowerCase();
      if (!msg.contains('locked') && !msg.contains('busy')) rethrow;
      await Future.delayed(Duration(milliseconds: 250 * (attempt + 1)));
    }
  }
  throw lastError ?? Exception('Database not found at $dbPath');
});

/// Provider for a specific translation database (regular schema).
///
/// Keyed by the language CODE string (e.g. 'en', 'th', 'vi') rather than
/// the `TranslationLanguage` enum. The enum only knows th/si/my/en and
/// `fromCode()` silently maps unknown codes (vi, lo, ta …) to English,
/// which made e.g. a downloaded `epitaka_vi.db` never get opened. Using the
/// raw code here means any language offered by the manifest works.
final translationDbProvider =
    FutureProvider.family<TranslationDatabase?, String>((ref, langCode) async {
      final dbDir = await getDatabaseDirectory();
      final dbPath = p.join(
        dbDir.path,
        TranslationFilenameParser.build(langCode),
      );
      if (!await _isUsableDbFile(dbPath)) {
        return null;
      }
      return TranslationDatabase.open(dbPath);
    });

/// Provider for a translation database by version.
/// Returns the appropriate database type (regular or nissaya) based on the
/// version's isNissaya flag.
final versionDbProvider = FutureProvider.family<Object?, TranslationVersion>((
  ref,
  version,
) async {
  final dbDir = await getDatabaseDirectory();
  final dbPath = p.join(dbDir.path, version.filename);
  if (!await _isUsableDbFile(dbPath)) return null;

  if (version.isNissaya) {
    return NissayaDatabase.open(dbPath);
  }
  return TranslationDatabase.open(dbPath);
});

/// Provider for a nissaya database by filename.
final nissayaDbByFilenameProvider =
    FutureProvider.family<NissayaDatabase?, String>((ref, filename) async {
      final dbDir = await getDatabaseDirectory();
      final dbPath = p.join(dbDir.path, filename);
      if (!await _isUsableDbFile(dbPath)) return null;
      return NissayaDatabase.open(dbPath);
    });

Future<bool> _isUsableDbFile(String dbPath) async {
  try {
    final file = File(dbPath);
    return await file.exists() && await file.length() > 0;
  } catch (_) {
    return false;
  }
}
