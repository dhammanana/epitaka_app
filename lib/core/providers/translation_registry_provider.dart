import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/translation_version.dart';
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
}

/// Legacy provider that reports which translations are available on disk.
///
/// Scans the database directory (rather than a hardcoded language list) so
/// ANY language offered by the manifest — including vi, lo, ta … — is
/// detected. Only the default (non-nissaya) version of each language is
/// listed; nissaya variants are managed through their own version providers.
/// Kept for backward compatibility with existing code (index building,
/// typography settings, etc.).
final translationRegistryProvider =
    FutureProvider<List<AvailableTranslation>>((ref) async {
  final dbDir = await getDatabaseDirectory();
  final versions = TranslationFilenameParser.scanDirectory(dbDir);

  final seen = <String>{};
  final result = <AvailableTranslation>[];
  for (final v in versions) {
    if (v.isNissaya) continue;
    if (!seen.add(v.languageCode)) continue;
    final info = TranslationLanguageRegistry.getName(v.languageCode);
    result.add(
      AvailableTranslation(
        languageCode: v.languageCode,
        englishName: info?.englishName ?? v.languageCode.toUpperCase(),
        nativeName: info?.nativeName ?? v.languageCode.toUpperCase(),
        isAvailable: true,
      ),
    );
  }
  return result;
});
