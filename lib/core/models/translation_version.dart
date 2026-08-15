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

  /// File size in bytes (from manifest). This is the size of the
  /// *zip* the server publishes (`size`), not the extracted database.
  final int? fileSize;

  /// Size of the extracted .db file in bytes (from manifest `dbSize`).
  final int? dbSize;

  /// Last updated date string (from manifest).
  final String? updatedAt;

  /// Checksum (SHA-256 hex) for integrity verification. The server
  /// computes this over the .db file inside the zip, so the app hashes
  /// the extracted database content and compares.
  final String? checksum;

  /// Whether this version is required for the app to function.
  final bool compulsory;

  const TranslationVersion({
    required this.languageCode,
    this.suffix,
    required this.filename,
    this.isNissaya = false,
    this.isAvailable = false,
    this.displayName = '',
    this.downloadUrl,
    this.fileSize,
    this.dbSize,
    this.updatedAt,
    this.checksum,
    this.compulsory = false,
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
    int? dbSize,
    String? updatedAt,
    String? checksum,
    bool? compulsory,
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
      dbSize: dbSize ?? this.dbSize,
      updatedAt: updatedAt ?? this.updatedAt,
      checksum: checksum ?? this.checksum,
      compulsory: compulsory ?? this.compulsory,
    );
  }

  Map<String, dynamic> toJson() => {
    'displayName': displayName,
    if (suffix != null && suffix!.isNotEmpty) 'suffix': suffix,
    if (downloadUrl != null) 'url': downloadUrl,
    if (fileSize != null) 'size': fileSize,
    if (dbSize != null) 'dbSize': dbSize,
    if (updatedAt != null) 'updated': updatedAt,
    if (checksum != null) 'checksum': checksum,
    if (isNissaya) 'type': 'nissaya',
    if (compulsory) 'compulsory': true,
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
      displayName:
          json['displayName'] as String? ??
          (suffix.isNotEmpty ? suffix : 'Default'),
      downloadUrl: json['url'] as String?,
      fileSize: json['size'] as int?,
      dbSize: json['dbSize'] as int?,
      updatedAt: json['updated'] as String?,
      checksum: json['checksum'] as String?,
      compulsory: json['compulsory'] as bool? ?? false,
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
/// This is now populated from the web manifest (the source of truth for
/// which translations exist) rather than a hardcoded list, so adding a
/// language server-side automatically makes its display name available.
/// Call [registerFromManifest] once the manifest has loaded.
class TranslationLanguageRegistry {
  static final Map<String, LangInfo> _languages = {};

  /// Populate (or refresh) the registry from the web manifest. This is the
  /// only way language names enter the registry — there is no hardcoded
  /// fallback list, so the displayed languages always match what the server
  /// actually offers.
  static void registerFromManifest(TranslationManifest manifest) {
    for (final entry in manifest.languageNames.entries) {
      _languages[entry.key] = entry.value;
    }
  }

  static LangInfo? getName(String code) => _languages[code];

  static String englishName(String code) =>
      getName(code)?.englishName ?? code.toUpperCase();
  static String nativeName(String code) =>
      getName(code)?.nativeName ?? code.toUpperCase();
}

/// Info about a translation language.
class LangInfo {
  final String code;
  final String nativeName;
  final String englishName;
  const LangInfo(this.code, this.nativeName, this.englishName);
}

/// A core asset (epitaka, dpd_dictionary, embeddings) from the manifest.
class CoreAsset {
  final String slug;
  final String displayName;
  final String? description;
  final String url;
  final int? size;
  final String? filename;
  final bool compulsory;

  const CoreAsset({
    required this.slug,
    required this.displayName,
    this.description,
    required this.url,
    this.size,
    this.filename,
    this.compulsory = false,
  });

  factory CoreAsset.fromJson(String slug, Map<String, dynamic> json) {
    return CoreAsset(
      slug: slug,
      displayName: json['displayName'] as String? ?? slug,
      description: json['description'] as String?,
      url: json['url'] as String,
      size: json['size'] as int?,
      filename: json['filename'] as String?,
      compulsory: json['compulsory'] as bool? ?? false,
    );
  }
}

/// The manifest JSON structure hosted on GitHub.
///
/// Example:
/// ```json
/// {
///   "version": 1,
///   "core": {
///     "embeddings": { "url": "...", "displayName": "..." }
///   },
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

  /// Core assets (epitaka, dpd_dictionary, embeddings).
  final Map<String, CoreAsset> core;

  /// Per-language display metadata (english + native names) parsed from the
  /// manifest. This is the source of truth for language names — there is no
  /// separate hardcoded list.
  final Map<String, LangInfo> languageNames;

  const TranslationManifest({
    this.version = 1,
    this.languages = const {},
    this.core = const {},
    this.languageNames = const {},
  });

  /// Get all versions across all languages.
  List<TranslationVersion> get allVersions =>
      languages.values.expand((v) => v).toList();

  /// Get versions for a specific language code.
  List<TranslationVersion> versionsFor(String languageCode) =>
      languages[languageCode] ?? [];

  /// Convenience getter for the embeddings core asset URL.
  String? get embeddingsUrl =>
      core['embeddings']?.url;

  factory TranslationManifest.fromJson(Map<String, dynamic> json) {
    final version = json['version'] as int? ?? 1;
    final langData = json['languages'] as Map<String, dynamic>? ?? {};
    final languages = <String, List<TranslationVersion>>{};
    final languageNames = <String, LangInfo>{};

    for (final entry in langData.entries) {
      final code = entry.key;
      final data = entry.value as Map<String, dynamic>;
      final versionsData = data['versions'] as Map<String, dynamic>? ?? {};

      // Capture the language's display names (server-provided).
      languageNames[code] = LangInfo(
        code,
        (data['nativeName'] as String?) ?? code,
        (data['englishName'] as String?) ?? code,
      );

      final versions = <TranslationVersion>[];
      for (final vEntry in versionsData.entries) {
        final vData = vEntry.value as Map<String, dynamic>;
        versions.add(TranslationVersion.fromJson(code, vData));
      }

      if (versions.isNotEmpty) {
        languages[code] = versions;
      }
    }

    // Parse core assets
    final coreData = json['core'] as Map<String, dynamic>? ?? {};
    final core = <String, CoreAsset>{};
    for (final entry in coreData.entries) {
      final slug = entry.key;
      final data = entry.value as Map<String, dynamic>;
      core[slug] = CoreAsset.fromJson(slug, data);
    }

    return TranslationManifest(
      version: version,
      languages: languages,
      core: core,
      languageNames: languageNames,
    );
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
  static bool matches(String filename) => RegExp(_pattern).hasMatch(filename);

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
      final files = dir.listSync().whereType<File>().map(
        (f) => f.path.split('/').last,
      );
      for (final filename in files) {
        if (!matches(filename)) continue;
        final (code, suffix) = parse(filename);
        if (code.isEmpty) continue;
        result.add(
          TranslationVersion(
            languageCode: code,
            suffix: suffix,
            filename: filename,
            isNissaya: isNissaya(suffix),
            isAvailable: true,
            displayName: suffix ?? 'Default',
          ),
        );
      }
    } catch (_) {}
    return result;
  }
}
