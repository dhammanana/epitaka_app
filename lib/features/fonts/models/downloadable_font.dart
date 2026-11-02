import '../../../core/utils/pali_script_converter.dart' show Script;

/// One downloadable font from the Google Fonts catalog
/// (`assets/font_catalog.json`).
///
/// A font declares which Pāli scripts it can render: the library only offers
/// it for those scripts, and choosing it never replaces a script font it has
/// no glyphs for.
class DownloadableFont {
  /// Stable id, also used for the stored file name and the Flutter family
  /// name (`FontLibraryService.familyFor`).
  final String id;

  /// Display name, e.g. "EB Garamond".
  final String name;

  /// `serif`, `sans` or `mono` — grouping and the chip in the library list.
  final String category;

  /// License as published by Google Fonts (`OFL`, `Apache 2.0`).
  final String license;

  /// Direct TTF URL (raw google/fonts repository, no API key).
  final String url;

  /// Pāli scripts this font renders.
  final List<Script> scripts;

  const DownloadableFont({
    required this.id,
    required this.name,
    required this.category,
    required this.license,
    required this.url,
    required this.scripts,
  });

  /// Whether this font can render [script].
  bool covers(Script script) => scripts.contains(script);

  /// BCP-ish short label used in the UI, e.g. "Latin, Sinhala".
  String get scriptLabels => scripts.map(scriptLabel).join(', ');

  static String scriptLabel(Script script) {
    switch (script) {
      case Script.roman:
        return 'Latin';
      case Script.cyrillic:
        return 'Cyrillic';
      case Script.sinhala:
        return 'Sinhala';
      case Script.devanagari:
        return 'Devanagari';
      case Script.thai:
        return 'Thai';
      case Script.laos:
        return 'Lao';
      case Script.myanmar:
        return 'Myanmar';
      case Script.khmer:
        return 'Khmer';
      case Script.bengali:
        return 'Bengali';
      case Script.gurmukhi:
        return 'Gurmukhi';
      case Script.gujarati:
        return 'Gujarati';
      case Script.telugu:
        return 'Telugu';
      case Script.kannada:
        return 'Kannada';
      case Script.malayalam:
        return 'Malayalam';
      case Script.brahmi:
        return 'Brahmi';
      case Script.taitham:
        return 'Tai Tham';
      case Script.tibetan:
        return 'Tibetan';
      case Script.tamil:
        return 'Tamil';
      case Script.korean:
        return 'Korean';
    }
  }

  /// Parse one catalog entry. Unknown script names are ignored, so a newer
  /// catalog can list a script this build does not know yet.
  factory DownloadableFont.fromJson(Map<String, dynamic> json) {
    final known = Script.values.asNameMap();
    final scripts = <Script>[];
    for (final raw in (json['scripts'] as List<dynamic>? ?? const [])) {
      final script = known['$raw'];
      if (script != null && !scripts.contains(script)) scripts.add(script);
    }
    return DownloadableFont(
      id: '${json['id']}',
      name: '${json['name']}',
      category: '${json['category'] ?? 'serif'}',
      license: '${json['license'] ?? 'OFL'}',
      url: '${json['url']}',
      scripts: scripts,
    );
  }

  /// Parse the whole catalog document (`{"fonts": [...]}`).
  static List<DownloadableFont> listFromJson(Map<String, dynamic> json) {
    final raw = json['fonts'] as List<dynamic>? ?? const [];
    return [
      for (final entry in raw)
        if (entry is Map<String, dynamic>) DownloadableFont.fromJson(entry),
    ];
  }
}
