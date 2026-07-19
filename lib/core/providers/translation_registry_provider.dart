import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_models.dart';
import '../utils/database_initializer.dart';

/// Metadata for an available translation (legacy model).
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

/// Legacy provider that checks only default filenames for known languages.
/// Kept for backward compatibility with existing code (index building, etc.).
final translationRegistryProvider =
    FutureProvider<List<AvailableTranslation>>((ref) async {
  final dbDir = await getDatabaseDirectory();
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

