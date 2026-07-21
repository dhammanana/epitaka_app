import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/utils/copy_types.dart';
import '../theme/app_colors.dart';
import '../theme/color_pair.dart';
import '../utils/pali_script_converter.dart';

/// UI language for the app interface.
enum AppLanguage {
  english('en', 'English'),
  thai('th', 'ไทย'),
  burmese('my', 'မြန်မာ'),
  sinhala('si', 'සිංහල'),
  vietnamese('vi', 'Tiếng Việt');

  final String code;
  final String nativeName;

  const AppLanguage(this.code, this.nativeName);
}

/// Theme mode preference.
enum ThemePreference { system, light, dark }

/// Library expand level for the book browser.
enum LibraryExpandLevel {
  /// All book groups and nikayas are collapsed by default.
  collapsed,

  /// Category tabs are expanded, but groups inside (sub-nikayas) are collapsed.
  category,

  /// All books and groups are fully expanded.
  expand,
}

/// Display mode for translations in the reader.
enum TranslationDisplayMode { hideJoinLines, lineByLine, sideBySide }

/// Font family choices for reading.
enum ReadingFontFamily {
  serif('serif', 'Serif'),
  sansSerif('sans', 'Sans-Serif'),
  mono('mono', 'Monospace');

  final String code;
  final String label;

  const ReadingFontFamily(this.code, this.label);

  /// Returns the Flutter fontFamily string.
  String get fontFamily {
    switch (this) {
      case ReadingFontFamily.serif:
        return 'Georgia';
      case ReadingFontFamily.sansSerif:
        return 'Roboto'; // system default (sans-serif)
      case ReadingFontFamily.mono:
        return 'monospace';
    }
  }

  static ReadingFontFamily fromCode(String code) {
    return ReadingFontFamily.values.firstWhere(
      (f) => f.code == code,
      orElse: () => ReadingFontFamily.serif,
    );
  }
}

/// Per-language typography settings (applies to both Pali and translations).
class LanguageTypography {
  final double fontSize;
  final double lineHeight;
  final ReadingFontFamily fontFamily;
  final bool bold;
  final bool italic;
  final bool underline;
  final Color? color;

  const LanguageTypography({
    this.fontSize = 17,
    this.lineHeight = 28 / 17,
    this.fontFamily = ReadingFontFamily.serif,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.color,
  });

  LanguageTypography copyWith({
    double? fontSize,
    double? lineHeight,
    ReadingFontFamily? fontFamily,
    bool? bold,
    bool? italic,
    bool? underline,
    Color? color,
    bool clearColor = false,
  }) {
    return LanguageTypography(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      fontFamily: fontFamily ?? this.fontFamily,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      color: clearColor ? null : (color ?? this.color),
    );
  }

  Map<String, dynamic> toJson() => {
    'fontSize': fontSize,
    'lineHeight': lineHeight,
    'fontFamily': fontFamily.code,
    'bold': bold,
    'italic': italic,
    'underline': underline,
    if (color != null) 'color': color!.toARGB32().toRadixString(16),
  };

  factory LanguageTypography.fromJson(Map<String, dynamic> json) {
    Color? color;
    final colorHex = json['color'] as String?;
    if (colorHex != null && colorHex.isNotEmpty) {
      final val = int.tryParse(colorHex, radix: 16);
      if (val != null) color = Color(val);
    }
    return LanguageTypography(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 17,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 28 / 17,
      fontFamily: ReadingFontFamily.fromCode(
        (json['fontFamily'] as String?) ?? 'serif',
      ),
      bold: (json['bold'] as bool?) ?? false,
      italic: (json['italic'] as bool?) ?? false,
      underline: (json['underline'] as bool?) ?? false,
      color: color,
    );
  }

  /// Resolve the effective text color given a fallback.
  Color effectiveColor(Color fallback) => color ?? fallback;

  /// Build the [TextStyle] for this typography.
  TextStyle toTextStyle({required Color fallbackColor}) {
    return TextStyle(
      fontFamily: fontFamily.fontFamily,
      fontSize: fontSize,
      height: lineHeight,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      decoration: underline ? TextDecoration.underline : TextDecoration.none,
      color: effectiveColor(fallbackColor),
    );
  }
}

/// Default Pali typography.
const _defaultPaliTypography = LanguageTypography(
  fontSize: 19,
  lineHeight: 32 / 19,
  fontFamily: ReadingFontFamily.serif,
  bold: false,
  italic: false,
  underline: false,
);

/// Default translation typography.
const _defaultTranslationTypography = LanguageTypography(
  fontSize: 17,
  lineHeight: 28 / 17,
  fontFamily: ReadingFontFamily.serif,
  bold: false,
  italic: false,
  underline: false,
);

/// Granular typography settings per language type.
class TypographySettings {
  /// Typography for Pali text (key: 'pali').
  final LanguageTypography pali;

  /// Per-language translation typography overrides (key: language code).
  final Map<String, LanguageTypography> languageOverrides;

  const TypographySettings({
    this.pali = _defaultPaliTypography,
    this.languageOverrides = const {},
  });

  /// Get the font size for a specific translation language.
  /// Falls back to the default translation font size if no override exists.
  double fontSizeFor(String langCode) {
    return languageOverrides[langCode]?.fontSize ??
        _defaultTranslationTypography.fontSize;
  }

  /// Supports: `<b>`, `<i>`, `<u>`, `<h1-6>`, `<br>` for a specific translation language.
  double lineHeightFor(String langCode) {
    return languageOverrides[langCode]?.lineHeight ??
        _defaultTranslationTypography.lineHeight;
  }

  /// Get the full typography for a specific translation language.
  LanguageTypography typographyFor(String langCode) {
    return languageOverrides[langCode] ?? _defaultTranslationTypography;
  }

  TypographySettings copyWith({
    LanguageTypography? pali,
    Map<String, LanguageTypography>? languageOverrides,
  }) {
    return TypographySettings(
      pali: pali ?? this.pali,
      languageOverrides: languageOverrides ?? this.languageOverrides,
    );
  }
}

/// Parse a display mode string to enum.
TranslationDisplayMode _parseDisplayMode(String s) {
  switch (s) {
    case 'lineByLine':
      return TranslationDisplayMode.lineByLine;
    case 'sideBySide':
      return TranslationDisplayMode.sideBySide;
    case 'hideJoinLines':
      return TranslationDisplayMode.hideJoinLines;
    default:
      return TranslationDisplayMode.lineByLine;
  }
}

CopyQuoteFormat _parseCopyQuoteFormat(String s) {
  switch (s) {
    case 'bookId':
      return CopyQuoteFormat.bookId;
    case 'bookName':
      return CopyQuoteFormat.bookName;
    case 'full':
      return CopyQuoteFormat.full;
    default:
      return CopyQuoteFormat.none;
  }
}

CopyScope _parseCopyScope(String s) {
  switch (s) {
    case 'pali':
      return CopyScope.pali;
    case 'translation':
      return CopyScope.translation;
    default:
      return CopyScope.both;
  }
}

/// Application settings persisted via SharedPreferences.
class AppSettings {
  final AppLanguage appLanguage;
  final ThemePreference themePreference;
  final String primaryTranslationLang;
  final String secondaryTranslationLang;
  final bool showPali;
  final bool showTranslation;

  /// Ordered list of language codes whose translations are enabled for display.
  /// The order determines which translation is spoken by TTS (first one wins)
  /// and the display priority in the reader.
  final List<String> enabledTranslations;

  final TranslationDisplayMode translationDisplayMode;
  final TypographySettings typography;
  final Color accentColor;

  /// Pāli text color pair (light + dark mode).
  final ColorPair paliColorPair;

  /// Translation text color pair (light + dark mode).
  final ColorPair translationColorPair;

  /// Convenience: resolve Pāli color for the current brightness.
  Color paliColorFor(Brightness brightness) =>
      paliColorPair.resolve(brightness);

  /// Convenience: resolve translation color for the current brightness.
  Color translationColorFor(Brightness brightness) =>
      translationColorPair.resolve(brightness);

  /// The Pāli color for light mode (legacy access).
  Color get paliColor => paliColorPair.light;

  /// The translation color for light mode (legacy access).
  Color get translationColor => translationColorPair.light;

  final String pageNumberingSystem;
  final bool keepScreenOn;
  final double autoScrollSpeed;
  final String ttsEngine;
  final String ttsVoice;
  final double ttsSpeed;
  final double ttsPitch;
  final String ttsSupertonicVoice;
  final String ttsSupertonicLanguage;
  final bool ttsSupertonicDownloaded;

  /// Quote/citation format when copying text.
  final CopyQuoteFormat copyQuoteFormat;

  /// Custom quote format template with placeholders.
  /// Placeholders: {book_id}, {book_name}, {heading}, {vri_page}, {pts_page}, {thai_page}, {myanmar_page}
  /// Default: "- {book_name} > {heading} VRI p.{vri_page}"
  final String quoteTemplate;

  /// Whether to use full book name (true) or book ID (false) in quotes.
  final bool useBookName;

  /// Whether to include section heading in quotes.
  final bool includeHeading;

  /// Page numbering system to use in quotes: vri, pts, thai, myanmar.
  final String quotePageNumberSystem;

  /// Default copy scope (Pāli, translation, or both).
  final CopyScope copyDefaultScope;

  /// Pāli script conversion target (e.g. Roman, Sinhala, Thai, Myanmar).
  final Script paliScript;

  /// Whether Pāli variant annotations wrapped in square brackets
  /// (e.g. "[variant reading]") are stripped from displayed Pāli text.
  /// Defaults to true (hidden) for a cleaner reading/search display.
  final bool stripVariantAnnotations;

  /// How deeply the library browser tree expands by default.
  final LibraryExpandLevel libraryExpandLevel;

  /// Per-language selected translation version suffix (null/empty = default).
  final Map<String, String> translationVersionMap;

  static const Color defaultPaliColor = Color(0xFF7A2E1D);
  static const Color defaultTranslationColor = Color(0xFF33312E);

  const AppSettings({
    this.appLanguage = AppLanguage.english,
    this.themePreference = ThemePreference.system,
    this.primaryTranslationLang = 'en',
    this.secondaryTranslationLang = 'th',
    this.showPali = true,
    this.showTranslation = true,
    this.enabledTranslations = const [],
    this.translationDisplayMode = TranslationDisplayMode.lineByLine,
    this.typography = const TypographySettings(),
    this.accentColor = AppColors.accentSaffron,
    this.paliColorPair = ColorPair.pali,
    this.translationColorPair = ColorPair.translation,
    this.pageNumberingSystem = 'vri',
    this.keepScreenOn = false,
    this.autoScrollSpeed = 60.0,
    this.ttsEngine = 'system',
    this.ttsVoice = 'default',
    this.ttsSpeed = 1.0,
    this.ttsPitch = 1.0,
    this.ttsSupertonicVoice = 'M1',
    this.ttsSupertonicLanguage = 'en',
    this.ttsSupertonicDownloaded = false,
    this.copyQuoteFormat = CopyQuoteFormat.none,
    this.copyDefaultScope = CopyScope.both,
    this.paliScript = Script.roman,
    this.stripVariantAnnotations = true,
    this.libraryExpandLevel = LibraryExpandLevel.category,
    this.translationVersionMap = const {},
    this.quoteTemplate = '- {book_name} > {heading} VRI p.{vri_page}',
    this.useBookName = true,
    this.includeHeading = true,
    this.quotePageNumberSystem = 'vri',
  });

  AppSettings copyWith({
    AppLanguage? appLanguage,
    ThemePreference? themePreference,
    String? primaryTranslationLang,
    String? secondaryTranslationLang,
    bool? showPali,
    bool? showTranslation,
    List<String>? enabledTranslations,
    TranslationDisplayMode? translationDisplayMode,
    TypographySettings? typography,
    Color? accentColor,
    ColorPair? paliColorPair,
    ColorPair? translationColorPair,
    String? pageNumberingSystem,
    bool? keepScreenOn,
    double? autoScrollSpeed,
    String? ttsEngine,
    String? ttsVoice,
    double? ttsSpeed,
    double? ttsPitch,
    String? ttsSupertonicVoice,
    String? ttsSupertonicLanguage,
    bool? ttsSupertonicDownloaded,
    CopyQuoteFormat? copyQuoteFormat,
    CopyScope? copyDefaultScope,
    Script? paliScript,
    LibraryExpandLevel? libraryExpandLevel,
    bool? stripVariantAnnotations,
    Map<String, String>? translationVersionMap,
    String? quoteTemplate,
    bool? useBookName,
    bool? includeHeading,
    String? quotePageNumberSystem,
  }) {
    return AppSettings(
      appLanguage: appLanguage ?? this.appLanguage,
      themePreference: themePreference ?? this.themePreference,
      primaryTranslationLang:
          primaryTranslationLang ?? this.primaryTranslationLang,
      secondaryTranslationLang:
          secondaryTranslationLang ?? this.secondaryTranslationLang,
      showPali: showPali ?? this.showPali,
      showTranslation: showTranslation ?? this.showTranslation,
      enabledTranslations: enabledTranslations ?? this.enabledTranslations,
      translationDisplayMode:
          translationDisplayMode ?? this.translationDisplayMode,
      typography: typography ?? this.typography,
      accentColor: accentColor ?? this.accentColor,
      paliColorPair: paliColorPair ?? this.paliColorPair,
      translationColorPair: translationColorPair ?? this.translationColorPair,
      pageNumberingSystem: pageNumberingSystem ?? this.pageNumberingSystem,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      autoScrollSpeed: autoScrollSpeed ?? this.autoScrollSpeed,
      ttsEngine: ttsEngine ?? this.ttsEngine,
      ttsVoice: ttsVoice ?? this.ttsVoice,
      ttsSpeed: ttsSpeed ?? this.ttsSpeed,
      ttsPitch: ttsPitch ?? this.ttsPitch,
      ttsSupertonicVoice: ttsSupertonicVoice ?? this.ttsSupertonicVoice,
      ttsSupertonicLanguage:
          ttsSupertonicLanguage ?? this.ttsSupertonicLanguage,
      ttsSupertonicDownloaded:
          ttsSupertonicDownloaded ?? this.ttsSupertonicDownloaded,
      copyQuoteFormat: copyQuoteFormat ?? this.copyQuoteFormat,
      copyDefaultScope: copyDefaultScope ?? this.copyDefaultScope,
      paliScript: paliScript ?? this.paliScript,
      libraryExpandLevel: libraryExpandLevel ?? this.libraryExpandLevel,
      stripVariantAnnotations:
          stripVariantAnnotations ?? this.stripVariantAnnotations,
      translationVersionMap:
          translationVersionMap ?? this.translationVersionMap,
      quoteTemplate: quoteTemplate ?? this.quoteTemplate,
      useBookName: useBookName ?? this.useBookName,
      includeHeading: includeHeading ?? this.includeHeading,
      quotePageNumberSystem:
          quotePageNumberSystem ?? this.quotePageNumberSystem,
    );
  }

  /// Resolve whether dark mode should be active based on preference and platform brightness.
  bool resolveDarkMode(Brightness platformBrightness) {
    switch (themePreference) {
      case ThemePreference.light:
        return false;
      case ThemePreference.dark:
        return true;
      case ThemePreference.system:
        return platformBrightness == Brightness.dark;
    }
  }
}

/// Provider for [AppSettings] backed by SharedPreferences.
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._prefs) : super(const AppSettings());

  SharedPreferences? _prefs;

  void init(SharedPreferences prefs) {
    _prefs = prefs;
    _load();
  }

  bool isDarkMode(Brightness platformBrightness) {
    return state.resolveDarkMode(platformBrightness);
  }

  /// Load a [ColorPair] from [key].  Falls back to reading the legacy
  /// single-color keys (`pali_color` / `translation_color`) for migration:
  /// if the new JSON key doesn't exist but the old hex key does, we
  /// construct a [ColorPair] and immediately persist the new format so
  /// the old key is never read again.
  ColorPair _loadColorPair(
    String key,
    ColorPair fallback, {
    String? legacyHexKey,
  }) {
    final prefs = _prefs;
    if (prefs == null) return fallback;

    // Try new JSON format first
    final raw = prefs.getString(key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return ColorPair.fromJson(decoded);
      } catch (_) {
        // Fall through to legacy
      }
    }

    // Migrate from legacy single hex-color key
    if (legacyHexKey != null) {
      final hex = prefs.getString(legacyHexKey);
      if (hex != null && hex.isNotEmpty) {
        final val = int.tryParse(hex, radix: 16);
        if (val != null) {
          final pair = ColorPair.fromLight(Color(val));
          // Persist new format and remove old key
          prefs.setString(key, jsonEncode(pair.toJson()));
          prefs.remove(legacyHexKey);
          return pair;
        }
      }
    }

    return fallback;
  }

  Map<String, LanguageTypography> _loadLanguageOverrides() {
    final prefs = _prefs;
    if (prefs == null) return const {};

    final raw = prefs.getString('lang_typography_overrides');
    if (raw == null || raw.isEmpty) return const {};

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(
          key,
          LanguageTypography.fromJson(value as Map<String, dynamic>),
        ),
      );
    } catch (_) {
      return const {};
    }
  }

  String _saveLanguageOverrides(Map<String, LanguageTypography> overrides) {
    return jsonEncode(
      overrides.map((key, value) => MapEntry(key, value.toJson())),
    );
  }

  LanguageTypography _loadPaliTypography() {
    final prefs = _prefs;
    if (prefs == null) return _defaultPaliTypography;

    final raw = prefs.getString('pali_typography');
    if (raw == null || raw.isEmpty) return _defaultPaliTypography;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return LanguageTypography.fromJson(decoded);
    } catch (_) {
      return _defaultPaliTypography;
    }
  }

  List<String> _loadEnabledTranslations() {
    final prefs = _prefs;
    if (prefs == null) return const [];
    final raw = prefs.getStringList('enabled_translations');
    if (raw == null) return const [];
    return raw;
  }

  Map<String, String> _loadTranslationVersionMap() {
    final prefs = _prefs;
    if (prefs == null) return const {};
    final raw = prefs.getString('translation_version_map');
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      return const {};
    }
  }

  void _load() {
    final prefs = _prefs;
    if (prefs == null) return;

    Color readColor(String key, Color fallback) {
      final hex = prefs.getString(key);
      if (hex == null || hex.isEmpty) return fallback;
      final val = int.tryParse(hex, radix: 16);
      return val != null ? Color(val) : fallback;
    }

    final displayModeStr =
        prefs.getString('translation_display_mode') ?? 'lineByLine';

    final appLangCode = prefs.getString('app_language') ?? 'en';

    state = AppSettings(
      appLanguage: AppLanguage.values.firstWhere(
        (l) => l.code == appLangCode,
        orElse: () => AppLanguage.english,
      ),
      themePreference:
          ThemePreference.values[prefs.getInt('theme_preference') ??
              ThemePreference.system.index],
      primaryTranslationLang: prefs.getString('primary_lang') ?? 'en',
      secondaryTranslationLang: prefs.getString('secondary_lang') ?? 'th',
      showPali: prefs.getBool('show_pali') ?? true,
      showTranslation: prefs.getBool('show_translation') ?? true,
      enabledTranslations: _loadEnabledTranslations(),
      translationDisplayMode: _parseDisplayMode(displayModeStr),
      typography: TypographySettings(
        pali: _loadPaliTypography(),
        languageOverrides: _loadLanguageOverrides(),
      ),
      accentColor: readColor('accent_color', AppColors.accentSaffron),
      paliColorPair: _loadColorPair(
        'pali_color_pair',
        ColorPair.pali,
        legacyHexKey: 'pali_color',
      ),
      translationColorPair: _loadColorPair(
        'translation_color_pair',
        ColorPair.translation,
        legacyHexKey: 'translation_color',
      ),
      pageNumberingSystem: prefs.getString('page_numbering') ?? 'vri',
      keepScreenOn: prefs.getBool('keep_screen_on') ?? false,
      autoScrollSpeed: prefs.getDouble('auto_scroll_speed') ?? 60.0,
      ttsEngine: prefs.getString('tts_engine') ?? 'system',
      ttsVoice: prefs.getString('tts_voice') ?? 'default',
      ttsSpeed: prefs.getDouble('tts_speed') ?? 1.0,
      ttsPitch: prefs.getDouble('tts_pitch') ?? 1.0,
      ttsSupertonicVoice: prefs.getString('tts_supertonic_voice') ?? 'M1',
      ttsSupertonicLanguage: prefs.getString('tts_supertonic_language') ?? 'en',
      ttsSupertonicDownloaded:
          prefs.getBool('tts_supertonic_downloaded') ?? false,
      copyQuoteFormat: _parseCopyQuoteFormat(
        prefs.getString('copy_quote_format') ?? 'none',
      ),
      copyDefaultScope: _parseCopyScope(
        prefs.getString('copy_default_scope') ?? 'both',
      ),
      paliScript: _parseScript(prefs.getString('pali_script')),
      libraryExpandLevel:
          LibraryExpandLevel.values[prefs.getInt('library_expand_level') ??
              LibraryExpandLevel.category.index],
      stripVariantAnnotations:
          prefs.getBool('strip_variant_annotations') ?? true,
      translationVersionMap: _loadTranslationVersionMap(),
      quoteTemplate:
          prefs.getString('quote_template') ??
          '- {book_name} > {heading} VRI p.{vri_page}',
      useBookName: prefs.getBool('use_book_name') ?? true,
      includeHeading: prefs.getBool('include_heading') ?? true,
      quotePageNumberSystem: prefs.getString('quote_page_system') ?? 'vri',
    );
  }

  Future<void> setAppLanguage(AppLanguage lang) async {
    state = state.copyWith(appLanguage: lang);
    await _prefs?.setString('app_language', lang.code);
  }

  Future<void> setThemePreference(ThemePreference pref) async {
    state = state.copyWith(themePreference: pref);
    await _prefs?.setInt('theme_preference', pref.index);
  }

  Future<void> setPrimaryTranslationLang(String lang) async {
    state = state.copyWith(primaryTranslationLang: lang);
    await _prefs?.setString('primary_lang', lang);
  }

  Future<void> setSecondaryTranslationLang(String lang) async {
    state = state.copyWith(secondaryTranslationLang: lang);
    await _prefs?.setString('secondary_lang', lang);
  }

  Future<void> setShowPali(bool value) async {
    state = state.copyWith(showPali: value);
    await _prefs?.setBool('show_pali', value);
  }

  Future<void> setShowTranslation(bool value) async {
    state = state.copyWith(showTranslation: value);
    await _prefs?.setBool('show_translation', value);
  }

  Future<void> setSideBySide(bool value) async {
    state = state.copyWith(
      translationDisplayMode: value
          ? TranslationDisplayMode.sideBySide
          : TranslationDisplayMode.lineByLine,
    );
    await _prefs?.setString(
      'translation_display_mode',
      state.translationDisplayMode.name,
    );
  }

  Future<void> setTranslationDisplayMode(TranslationDisplayMode mode) async {
    state = state.copyWith(translationDisplayMode: mode);
    await _prefs?.setString('translation_display_mode', mode.name);
  }

  /// Toggle a translation language on/off in the enabled ordered list.
  Future<void> setTranslationEnabled(String langCode, bool enabled) async {
    final current = List<String>.from(state.enabledTranslations);
    if (enabled) {
      if (!current.contains(langCode)) {
        current.add(langCode);
      }
    } else {
      current.remove(langCode);
    }
    state = state.copyWith(enabledTranslations: current);
    await _prefs?.setStringList('enabled_translations', current);
  }

  /// Set the full ordered list of enabled translations (for drag-to-reorder).
  Future<void> setTranslationsOrder(List<String> orderedCodes) async {
    state = state.copyWith(enabledTranslations: orderedCodes);
    await _prefs?.setStringList('enabled_translations', orderedCodes);
  }

  Future<void> setLanguageTypography(
    String langCode,
    LanguageTypography typography,
  ) async {
    final overrides = Map<String, LanguageTypography>.from(
      state.typography.languageOverrides,
    );
    overrides[langCode] = typography;
    final newTypo = state.typography.copyWith(languageOverrides: overrides);
    state = state.copyWith(typography: newTypo);
    await _prefs?.setString(
      'lang_typography_overrides',
      _saveLanguageOverrides(overrides),
    );
  }

  Future<void> setPaliTypography(LanguageTypography typography) async {
    final newTypo = state.typography.copyWith(pali: typography);
    state = state.copyWith(typography: newTypo);
    await _prefs?.setString('pali_typography', jsonEncode(typography.toJson()));
  }

  /// Increase the font size for Pāli and every enabled translation by
  /// [delta] (clamped to the 12–40px range). Used by the keyboard
  /// shortcuts (Ctrl/Cmd + / -).
  Future<void> increaseFontSize([double delta = 1]) async {
    await _adjustFontSize(delta);
  }

  /// Decrease the font size for Pāli and every enabled translation by
  /// [delta] (clamped to the 12–40px range).
  Future<void> decreaseFontSize([double delta = 1]) async {
    await _adjustFontSize(-delta);
  }

  Future<void> _adjustFontSize(double delta) async {
    final typography = state.typography;
    final newPali = typography.pali.copyWith(
      fontSize: (typography.pali.fontSize + delta).clamp(12.0, 40.0),
    );
    final newOverrides = <String, LanguageTypography>{};
    typography.languageOverrides.forEach((lang, t) {
      newOverrides[lang] = t.copyWith(
        fontSize: (t.fontSize + delta).clamp(12.0, 40.0),
      );
    });
    final newTypo = typography.copyWith(
      pali: newPali,
      languageOverrides: newOverrides,
    );
    state = state.copyWith(typography: newTypo);
    await _prefs?.setString('pali_typography', jsonEncode(newPali.toJson()));
    await _prefs?.setString(
      'lang_typography_overrides',
      _saveLanguageOverrides(newOverrides),
    );
  }

  Future<void> setTypography(TypographySettings settings) async {
    state = state.copyWith(typography: settings);
  }

  Future<void> setAccentColor(Color color) async {
    state = state.copyWith(accentColor: color);
    await _prefs?.setString('accent_color', color.toARGB32().toRadixString(16));
  }

  Future<void> setPaliColor(Color lightColor) async {
    final pair = ColorPair.fromLight(lightColor);
    state = state.copyWith(paliColorPair: pair);
    await _prefs?.setString('pali_color_pair', jsonEncode(pair.toJson()));
  }

  Future<void> setPaliColorPair(ColorPair pair) async {
    state = state.copyWith(paliColorPair: pair);
    await _prefs?.setString('pali_color_pair', jsonEncode(pair.toJson()));
  }

  Future<void> setTranslationColor(Color lightColor) async {
    final pair = ColorPair.fromLight(lightColor);
    state = state.copyWith(translationColorPair: pair);
    await _prefs?.setString(
      'translation_color_pair',
      jsonEncode(pair.toJson()),
    );
  }

  Future<void> setTranslationColorPair(ColorPair pair) async {
    state = state.copyWith(translationColorPair: pair);
    await _prefs?.setString(
      'translation_color_pair',
      jsonEncode(pair.toJson()),
    );
  }

  Future<void> setPageNumberingSystem(String system) async {
    state = state.copyWith(pageNumberingSystem: system);
    await _prefs?.setString('page_numbering', system);
  }

  Future<void> setKeepScreenOn(bool value) async {
    state = state.copyWith(keepScreenOn: value);
    await _prefs?.setBool('keep_screen_on', value);
  }

  Future<void> setAutoScrollSpeed(double speed) async {
    state = state.copyWith(autoScrollSpeed: speed);
    await _prefs?.setDouble('auto_scroll_speed', speed);
  }

  Future<void> setTtsEngine(String engine) async {
    state = state.copyWith(ttsEngine: engine);
    await _prefs?.setString('tts_engine', engine);
  }

  Future<void> setTtsVoice(String voice) async {
    state = state.copyWith(ttsVoice: voice);
    await _prefs?.setString('tts_voice', voice);
  }

  Future<void> setTtsSpeed(double speed) async {
    state = state.copyWith(ttsSpeed: speed);
    await _prefs?.setDouble('tts_speed', speed);
  }

  Future<void> setTtsPitch(double pitch) async {
    state = state.copyWith(ttsPitch: pitch);
    await _prefs?.setDouble('tts_pitch', pitch);
  }

  Future<void> setTtsSupertonicVoice(String voice) async {
    state = state.copyWith(ttsSupertonicVoice: voice);
    await _prefs?.setString('tts_supertonic_voice', voice);
  }

  Future<void> setTtsSupertonicLanguage(String language) async {
    state = state.copyWith(ttsSupertonicLanguage: language);
    await _prefs?.setString('tts_supertonic_language', language);
  }

  Future<void> setTtsSupertonicDownloaded(bool downloaded) async {
    state = state.copyWith(ttsSupertonicDownloaded: downloaded);
    await _prefs?.setBool('tts_supertonic_downloaded', downloaded);
  }

  Future<void> setCopyQuoteFormat(CopyQuoteFormat format) async {
    state = state.copyWith(copyQuoteFormat: format);
    await _prefs?.setString('copy_quote_format', format.name);
  }

  Future<void> setCopyDefaultScope(CopyScope scope) async {
    state = state.copyWith(copyDefaultScope: scope);
    await _prefs?.setString('copy_default_scope', scope.name);
  }

  Future<void> setPaliScript(Script script) async {
    state = state.copyWith(paliScript: script);
    await _prefs?.setString('pali_script', script.name);
  }

  Future<void> setStripVariantAnnotations(bool value) async {
    state = state.copyWith(stripVariantAnnotations: value);
    await _prefs?.setBool('strip_variant_annotations', value);
  }

  Future<void> setLibraryExpandLevel(LibraryExpandLevel level) async {
    state = state.copyWith(libraryExpandLevel: level);
    await _prefs?.setInt('library_expand_level', level.index);
  }

  Future<void> setQuoteTemplate(String template) async {
    state = state.copyWith(quoteTemplate: template);
    await _prefs?.setString('quote_template', template);
  }

  Future<void> setUseBookName(bool value) async {
    state = state.copyWith(useBookName: value);
    await _prefs?.setBool('use_book_name', value);
  }

  Future<void> setIncludeHeading(bool value) async {
    state = state.copyWith(includeHeading: value);
    await _prefs?.setBool('include_heading', value);
  }

  Future<void> setQuotePageNumberSystem(String system) async {
    state = state.copyWith(quotePageNumberSystem: system);
    await _prefs?.setString('quote_page_system', system);
  }

  /// Set the translation version (suffix) to use for a language code.
  /// Pass `null` or empty string to use the default version.
  Future<void> setTranslationVersion(String langCode, String? suffix) async {
    final current = Map<String, String>.from(state.translationVersionMap);
    if (suffix == null || suffix.isEmpty) {
      current.remove(langCode);
    } else {
      current[langCode] = suffix;
    }
    state = state.copyWith(translationVersionMap: current);
    await _prefs?.setString('translation_version_map', jsonEncode(current));
  }

  /// Returns the display name for a script in the current app language.
  String scriptDisplayName(Script script) {
    for (final info in listOfScripts) {
      if (info.script == script) return info.nameInLocale;
    }
    return script.name;
  }
}

Script _parseScript(String? value) {
  if (value == null || value.isEmpty) return Script.roman;
  return Script.values.firstWhere(
    (s) => s.name == value,
    orElse: () => Script.roman,
  );
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((
  ref,
) {
  return SettingsNotifier(null);
});
