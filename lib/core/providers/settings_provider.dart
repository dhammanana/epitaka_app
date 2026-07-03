import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/utils/copy_types.dart';
import '../theme/app_colors.dart';

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
enum ThemePreference {
  system,
  light,
  dark,
}

/// Display mode for translations in the reader.
enum TranslationDisplayMode {
  hideJoinLines,
  lineByLine,
  sideBySide,
}

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
          (json['fontFamily'] as String?) ?? 'serif'),
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

  /// Set of language codes whose translations are enabled for display.
  /// An empty set means no translations are explicitly enabled (show none).
  final Set<String> enabledTranslations;

  final TranslationDisplayMode translationDisplayMode;
  final TypographySettings typography;
  final Color accentColor;

  /// Default Pali color (used when no color override in typography).
  final Color paliColor;

  /// Default translation color (used when no color override in per-lang typography).
  final Color translationColor;

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

  /// Default copy scope (Pāli, translation, or both).
  final CopyScope copyDefaultScope;

  static const Color defaultPaliColor = Color(0xFF7A2E1D);
  static const Color defaultTranslationColor = Color(0xFF33312E);

  const AppSettings({
    this.appLanguage = AppLanguage.english,
    this.themePreference = ThemePreference.system,
    this.primaryTranslationLang = 'en',
    this.secondaryTranslationLang = 'th',
    this.showPali = true,
    this.showTranslation = true,
    this.enabledTranslations = const {},
    this.translationDisplayMode = TranslationDisplayMode.lineByLine,
    this.typography = const TypographySettings(),
    this.accentColor = AppColors.accentSaffron,
    this.paliColor = defaultPaliColor,
    this.translationColor = defaultTranslationColor,
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
  });

  AppSettings copyWith({
    AppLanguage? appLanguage,
    ThemePreference? themePreference,
    String? primaryTranslationLang,
    String? secondaryTranslationLang,
    bool? showPali,
    bool? showTranslation,
    Set<String>? enabledTranslations,
    TranslationDisplayMode? translationDisplayMode,
    TypographySettings? typography,
    Color? accentColor,
    Color? paliColor,
    Color? translationColor,
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
      paliColor: paliColor ?? this.paliColor,
      translationColor: translationColor ?? this.translationColor,
      pageNumberingSystem: pageNumberingSystem ?? this.pageNumberingSystem,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      autoScrollSpeed: autoScrollSpeed ?? this.autoScrollSpeed,
      ttsEngine: ttsEngine ?? this.ttsEngine,
      ttsVoice: ttsVoice ?? this.ttsVoice,
      ttsSpeed: ttsSpeed ?? this.ttsSpeed,
      ttsPitch: ttsPitch ?? this.ttsPitch,
      ttsSupertonicVoice: ttsSupertonicVoice ?? this.ttsSupertonicVoice,
      ttsSupertonicLanguage: ttsSupertonicLanguage ?? this.ttsSupertonicLanguage,
      ttsSupertonicDownloaded: ttsSupertonicDownloaded ?? this.ttsSupertonicDownloaded,
      copyQuoteFormat: copyQuoteFormat ?? this.copyQuoteFormat,
      copyDefaultScope: copyDefaultScope ?? this.copyDefaultScope,
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
    return jsonEncode(overrides.map(
      (key, value) => MapEntry(key, value.toJson()),
    ));
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

  Set<String> _loadEnabledTranslations() {
    final prefs = _prefs;
    if (prefs == null) return const {};
    final raw = prefs.getStringList('enabled_translations');
    if (raw == null) return const {};
    return raw.toSet();
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
      themePreference: ThemePreference.values[
          prefs.getInt('theme_preference') ?? ThemePreference.system.index],
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
      paliColor: readColor('pali_color', AppSettings.defaultPaliColor),
      translationColor:
          readColor('translation_color', AppSettings.defaultTranslationColor),
      pageNumberingSystem: prefs.getString('page_numbering') ?? 'vri',
      keepScreenOn: prefs.getBool('keep_screen_on') ?? false,
      autoScrollSpeed: prefs.getDouble('auto_scroll_speed') ?? 60.0,
      ttsEngine: prefs.getString('tts_engine') ?? 'system',
      ttsVoice: prefs.getString('tts_voice') ?? 'default',
      ttsSpeed: prefs.getDouble('tts_speed') ?? 1.0,
      ttsPitch: prefs.getDouble('tts_pitch') ?? 1.0,
      ttsSupertonicVoice: prefs.getString('tts_supertonic_voice') ?? 'M1',
      ttsSupertonicLanguage: prefs.getString('tts_supertonic_language') ?? 'en',
      ttsSupertonicDownloaded: prefs.getBool('tts_supertonic_downloaded') ?? false,
      copyQuoteFormat: _parseCopyQuoteFormat(prefs.getString('copy_quote_format') ?? 'none'),
      copyDefaultScope: _parseCopyScope(prefs.getString('copy_default_scope') ?? 'both'),
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
            : TranslationDisplayMode.lineByLine);
    await _prefs?.setString(
        'translation_display_mode', state.translationDisplayMode.name);
  }

  Future<void> setTranslationDisplayMode(TranslationDisplayMode mode) async {
    state = state.copyWith(translationDisplayMode: mode);
    await _prefs?.setString('translation_display_mode', mode.name);
  }

  /// Toggle a translation language on/off in the enabled set.
  Future<void> setTranslationEnabled(String langCode, bool enabled) async {
    final current = Set<String>.from(state.enabledTranslations);
    if (enabled) {
      current.add(langCode);
    } else {
      current.remove(langCode);
    }
    state = state.copyWith(enabledTranslations: current);
    await _prefs?.setStringList('enabled_translations', current.toList());
  }

  Future<void> setLanguageTypography(
      String langCode, LanguageTypography typography) async {
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
    await _prefs?.setString(
      'pali_typography',
      jsonEncode(typography.toJson()),
    );
  }

  Future<void> setTypography(TypographySettings settings) async {
    state = state.copyWith(typography: settings);
  }

  Future<void> setAccentColor(Color color) async {
    state = state.copyWith(accentColor: color);
    await _prefs?.setString('accent_color', color.toARGB32().toRadixString(16));
  }

  Future<void> setPaliColor(Color color) async {
    state = state.copyWith(paliColor: color);
    await _prefs?.setString('pali_color', color.toARGB32().toRadixString(16));
  }

  Future<void> setTranslationColor(Color color) async {
    state = state.copyWith(translationColor: color);
    await _prefs?.setString(
        'translation_color', color.toARGB32().toRadixString(16));
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
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(null);
});
