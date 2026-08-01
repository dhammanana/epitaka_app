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
  return EpitakaDatabase.open(dbPath);
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
  final dbPath = p.join(dbDir.path, TranslationFilenameParser.build(langCode));
  final file = File(dbPath);
  if (!await file.exists()) {
    return null;
  }
  return TranslationDatabase.open(dbPath);
});

/// Provider for a translation database by version.
/// Returns the appropriate database type (regular or nissaya) based on the
/// version's isNissaya flag.
final versionDbProvider =
    FutureProvider.family<Object?, TranslationVersion>((ref, version) async {
  final dbDir = await getDatabaseDirectory();
  final dbPath = p.join(dbDir.path, version.filename);
  final file = File(dbPath);
  if (!await file.exists()) return null;

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
  final file = File(dbPath);
  if (!await file.exists()) return null;
  return NissayaDatabase.open(dbPath);
});

