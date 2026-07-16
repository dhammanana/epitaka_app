import 'dart:convert';
import 'dart:io';

/// Represents a single version of a translation database.
///
/// A language can have multiple versions:
/// - Default: `epitaka_<code>.db` (suffix is empty/null)
/// - Versioned: `epitaka_<code>_<suffix>.db` (e.g. `epitaka_my_nissaya.db`)
class TranslationVersion {
  /// The language code (e.g. 'en', 'my', 'th').
  final String languageCode;

  /// The version suffix (null or '' for the default version).
  final String? suffix;

  /// The full filename in the database directory.
  final String filename;

  /// Whether this is a nissaya-type database.
  final bool isNissaya;

  /// Whether the database file exists locally on disk.
  final bool isAvailable;

  /// Human-readable display name for this version (e.g. "Default", "Nissaya").
  final String displayName;

  /// Download URL for this version (from manifest).
  final String? downloadUrl;

  /// File size in bytes (from manifest).
  final int? fileSize;

  /// Last updated date string (from manifest).
  final String? updatedAt;

  /// Checksum (SHA-256 hex) for integrity verification.
  final String? checksum;

  const TranslationVersion({
    required this.languageCode,
    this.suffix,
    required this.filename,
    this.isNissaya = false,
    this.isAvailable = false,
    this.displayName = '',
    this.downloadUrl,
    this.fileSize,
    this.updatedAt,
    this.checksum,
  });

  /// The language's English name.
  String get englishName {
    final lang = TranslationLanguageRegistry.getName(languageCode);
    return lang?.englishName ?? languageCode.toUpperCase();
  }

  /// The language's native name.
  String get nativeName {
    final lang = TranslationLanguageRegistry.getName(languageCode);
    return lang?.nativeName ?? languageCode.toUpperCase();
  }

  /// Whether the download URL is available for this version.
  bool get hasDownloadUrl => downloadUrl != null && downloadUrl!.isNotEmpty;

  TranslationVersion copyWith({
    String? languageCode,
    String? suffix,
    String? filename,
    bool? isNissaya,
    bool? isAvailable,
    String? displayName,
    String? downloadUrl,
    int? fileSize,
    String? updatedAt,
    String? checksum,
    bool clearDownloadUrl = false,
  }) {
    return TranslationVersion(
      languageCode: languageCode ?? this.languageCode,
      suffix: suffix ?? this.suffix,
      filename: filename ?? this.filename,
      isNissaya: isNissaya ?? this.isNissaya,
      isAvailable: isAvailable ?? this.isAvailable,
      displayName: displayName ?? this.displayName,
      downloadUrl: clearDownloadUrl ? null : (downloadUrl ?? this.downloadUrl),
      fileSize: fileSize ?? this.fileSize,
      updatedAt: updatedAt ?? this.updatedAt,
      checksum: checksum ?? this.checksum,
    );
  }

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        if (suffix != null && suffix!.isNotEmpty) 'suffix': suffix,
        if (downloadUrl != null) 'url': downloadUrl,
        if (fileSize != null) 'size': fileSize,
        if (updatedAt != null) 'updated': updatedAt,
        if (checksum != null) 'checksum': checksum,
        if (isNissaya) 'type': 'nissaya',
      };

  factory TranslationVersion.fromJson(
    String languageCode,
    Map<String, dynamic> json,
  ) {
    final suffix = json['suffix'] as String? ?? '';
    final isNissaya = json['type'] == 'nissaya';
    final filename = suffix.isNotEmpty
        ? 'epitaka_${languageCode}_$suffix.db'
        : 'epitaka_$languageCode.db';

    return TranslationVersion(
      languageCode: languageCode,
      suffix: suffix.isNotEmpty ? suffix : null,
      filename: filename,
      isNissaya: isNissaya,
      displayName: json['displayName'] as String? ??
          (suffix.isNotEmpty ? suffix : 'Default'),
      downloadUrl: json['url'] as String?,
      fileSize: json['size'] as int?,
      updatedAt: json['updated'] as String?,
      checksum: json['checksum'] as String?,
    );
  }

  @override
  String toString() =>
      'TranslationVersion($languageCode${suffix != null ? '_$suffix' : ''})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TranslationVersion &&
          other.languageCode == languageCode &&
          other.suffix == suffix &&
          other.filename == filename);

  @override
  int get hashCode => Object.hash(languageCode, suffix, filename);
}

/// Central registry of known translation languages.
///
/// Mirrors the [TranslationLanguage] enum but allows dynamic lookup.
class TranslationLanguageRegistry {
  static final List<LangInfo> _languages = [
    LangInfo('en', 'English', 'English'),
    LangInfo('th', 'ไทย', 'Thai'),
    LangInfo('si', 'සිංහල', 'Sinhala'),
    LangInfo('my', 'မြန်မာ', 'Myanmar'),
  ];

  static LangInfo? getName(String code) {
    try {
      return _languages.firstWhere((l) => l.code == code);
    } catch (_) {
      return null;
    }
  }

  static String englishName(String code) => getName(code)?.englishName ?? code;
  static String nativeName(String code) => getName(code)?.nativeName ?? code;
}

/// Info about a translation language.
class LangInfo {
  final String code;
  final String nativeName;
  final String englishName;
  const LangInfo(this.code, this.nativeName, this.englishName);
}

/// The manifest JSON structure hosted on GitHub.
///
/// Example:
/// ```json
/// {
///   "version": 1,
///   "languages": {
///     "my": {
///       "englishName": "Myanmar",
///       "nativeName": "မြန်မာ",
///       "versions": {
///         "default": {
///           "displayName": "Default",
///           "url": "https://github.com/.../epitaka_my.db.zip",
///           "size": 123456789,
///           "updated": "2026-07-16"
///         },
///         "nissaya": {
///           "displayName": "Nissaya",
///           "suffix": "nissaya",
///           "url": "https://github.com/.../epitaka_my_nissaya.db.zip",
///           "size": 649498624,
///           "updated": "2026-07-16",
///           "type": "nissaya"
///         }
///       }
///     }
///   }
/// }
/// ```
class TranslationManifest {
  final int version;
  final Map<String, List<TranslationVersion>> languages;

  const TranslationManifest({
    this.version = 1,
    this.languages = const {},
  });

  /// Get all versions across all languages.
  List<TranslationVersion> get allVersions =>
      languages.values.expand((v) => v).toList();

  /// Get versions for a specific language code.
  List<TranslationVersion> versionsFor(String languageCode) =>
      languages[languageCode] ?? [];

  factory TranslationManifest.fromJson(Map<String, dynamic> json) {
    final version = json['version'] as int? ?? 1;
    final langData = json['languages'] as Map<String, dynamic>? ?? {};
    final languages = <String, List<TranslationVersion>>{};

    for (final entry in langData.entries) {
      final code = entry.key;
      final data = entry.value as Map<String, dynamic>;
      final versionsData = data['versions'] as Map<String, dynamic>? ?? {};

      final versions = <TranslationVersion>[];
      for (final vEntry in versionsData.entries) {
        final vData = vEntry.value as Map<String, dynamic>;
        versions.add(TranslationVersion.fromJson(code, vData));
      }

      if (versions.isNotEmpty) {
        languages[code] = versions;
      }
    }

    return TranslationManifest(version: version, languages: languages);
  }

  factory TranslationManifest.fromString(String raw) {
    return TranslationManifest.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }
}

/// Parses a DB filename to extract language code and suffix.
///
/// Format: `epitaka_<code>[_<suffix>].db`
class TranslationFilenameParser {
  static const _pattern = r'^epitaka_([a-z]{2})(?:_(.+))?\.db$';

  /// Parse a filename and return (languageCode, suffixOrNull).
  static (String, String?) parse(String filename) {
    final regex = RegExp(_pattern);
    final match = regex.firstMatch(filename);
    if (match == null) return ('', null);
    final code = match.group(1)!;
    final suffix = match.group(2);
    return (code, suffix);
  }

  /// Check if a filename matches the epitaka DB pattern.
  static bool matches(String filename) =>
      RegExp(_pattern).hasMatch(filename);

  /// Check if a suffix indicates a nissaya database.
  static bool isNissaya(String? suffix) =>
      suffix != null && suffix.contains('nissaya');

  /// Build filename from language code and optional suffix.
  static String build(String code, {String? suffix}) =>
      suffix != null && suffix.isNotEmpty
          ? 'epitaka_${code}_$suffix.db'
          : 'epitaka_$code.db';

  /// Get the default filename for a language code.
  static String defaultFilename(String code) => 'epitaka_$code.db';

  /// Scan a directory and return all detected translation versions.
  static List<TranslationVersion> scanDirectory(Directory dir) {
    final result = <TranslationVersion>[];
    try {
      final files =
          dir.listSync().whereType<File>().map((f) => f.path.split('/').last);
      for (final filename in files) {
        if (!matches(filename)) continue;
        final (code, suffix) = parse(filename);
        if (code.isEmpty) continue;
        result.add(TranslationVersion(
          languageCode: code,
          suffix: suffix,
          filename: filename,
          isNissaya: isNissaya(suffix),
          isAvailable: true,
          displayName: suffix ?? 'Default',
        ));
      }
    } catch (_) {}
    return result;
  }
}
