# ePitaka — Complete Flutter Build Plan

Cross-platform (Android, iOS, Web, macOS, Windows, Linux).
Stack: Flutter · Drift · Riverpod · go_router · warm manuscript UI.

---

## Conventions used in this document

- `[EXISTS]` — file already in the project; notes describe what to add/complete.
- `[NEW]` — file to create.
- `[GENERATE]` — run `dart run build_runner build` after editing.
- Code snippets are illustrative skeletons, not copy-paste complete implementations.

---

## Phase 0 — Project Config & Constants

Everything that might change in production goes in one place. No magic strings scattered in widgets.

### `lib/core/config/app_config.dart` `[NEW]`

```dart
/// Central place for all environment-level constants.
/// Change here; the rest of the app follows.
class AppConfig {
  // ---------- Database ----------
  static const String epitakaDatabaseFilename  = 'epitaka.db';
  static const String translationDbPrefix      = 'epitaka_';   // + langCode + '.db'
  static const String glossaryDbPrefix         = 'glossary_';
  static const String translationDbExtension   = '.db';

  // ---------- Downloads ----------
  static const String downloadBaseUrl =
      'https://files.paauksociety.org/epitaka/';  // replace with real URL
  static const int    downloadTimeoutSeconds   = 120;
  static const bool   wifiOnlyDefault          = true;

  // ---------- Reader ----------
  static const int    pageSize                 = 30;  // paragraphs per page load
  static const int    pagePreloadBuffer        = 10;  // load N more before edge
  static const double autoScrollDefaultSpeed   = 60.0; // px/s

  // ---------- TTS ----------
  static const double ttsSpeedMin              = 0.5;
  static const double ttsSpeedMax              = 2.0;
  static const double ttsSpeedDefault          = 1.0;

  // ---------- UI ----------
  static const int    maxOpenTabs              = 10;
  static const double splitPaneDividerWidth    = 1.0;
  static const double bottomSheetMinHeight     = 0.4;  // fraction of screen
  static const double bottomSheetMaxHeight     = 0.92;
  static const double desktopBreakpoint        = 800.0;
  static const double tabletBreakpoint         = 600.0;
}
```

### `lib/core/config/supported_languages.dart` `[NEW]`

```dart
/// Every UI / translation language the app can handle.
/// Add a row here to introduce a new language everywhere.
class LangMeta {
  final String code;       // BCP-47, e.g. 'en', 'zh', 'th', 'si'
  final String nativeName; // shown in language-select list
  final String dbFilename; // translation DB filename, '' if none yet
  final double dbSizeMb;   // approximate, for display only
  final bool   isUiLang;   // available as app UI language
  const LangMeta({
    required this.code,
    required this.nativeName,
    required this.dbFilename,
    required this.dbSizeMb,
    this.isUiLang = true,
  });
}

const List<LangMeta> kSupportedLanguages = [
  LangMeta(code: 'en', nativeName: 'English',       dbFilename: 'epitaka_en.db', dbSizeMb: 220),
  LangMeta(code: 'zh', nativeName: '中文',            dbFilename: 'epitaka_zh.db', dbSizeMb: 180),
  LangMeta(code: 'th', nativeName: 'ภาษาไทย',        dbFilename: 'epitaka_th.db', dbSizeMb: 250),
  LangMeta(code: 'si', nativeName: 'සිංහල',          dbFilename: 'epitaka_si.db', dbSizeMb: 240),
  LangMeta(code: 'my', nativeName: 'မြန်မာ',          dbFilename: 'epitaka_my.db', dbSizeMb: 210),
  LangMeta(code: 'vi', nativeName: 'Tiếng Việt',     dbFilename: 'epitaka_vi.db', dbSizeMb: 200),
  LangMeta(code: 'hi', nativeName: 'हिन्दी',          dbFilename: 'epitaka_hi.db', dbSizeMb: 195),
  LangMeta(code: 'id', nativeName: 'Bahasa Indonesia',dbFilename: 'epitaka_id.db', dbSizeMb: 190),
  LangMeta(code: 'ja', nativeName: '日本語',           dbFilename: 'epitaka_ja.db', dbSizeMb: 185),
  LangMeta(code: 'ko', nativeName: '한국어',           dbFilename: 'epitaka_ko.db', dbSizeMb: 175),
  LangMeta(code: 'es', nativeName: 'Español',        dbFilename: 'epitaka_es.db', dbSizeMb: 190),
  LangMeta(code: 'fr', nativeName: 'Français',       dbFilename: 'epitaka_fr.db', dbSizeMb: 195),
  LangMeta(code: 'de', nativeName: 'Deutsch',        dbFilename: 'epitaka_de.db', dbSizeMb: 200),
];
```

### `lib/core/config/pali_scripts.dart` `[NEW]`

```dart
enum PaliScript {
  roman('Roman', 'Abc'),
  devanagari('Devanāgarī', 'अ'),
  thai('Thai', 'ก'),
  myanmar('Myanmar', 'က'),
  sinhala('Sinhala', 'අ'),
  tibetan('Tibetan', 'ཀ'),
}

extension PaliScriptLabel on PaliScript {
  String get displayName => switch (this) {
    PaliScript.roman     => 'Roman',
    PaliScript.devanagari=> 'Devanāgarī',
    PaliScript.thai      => 'Thai',
    PaliScript.myanmar   => 'Myanmar',
    PaliScript.sinhala   => 'Sinhala',
    PaliScript.tibetan   => 'Tibetan',
  };
  String get sample => switch (this) {
    PaliScript.roman     => 'Abc',
    PaliScript.devanagari=> 'अ',
    PaliScript.thai      => 'ก',
    PaliScript.myanmar   => 'က',
    PaliScript.sinhala   => 'අ',
    PaliScript.tibetan   => 'ཀ',
  };
}
```

---

## Phase 1 — Theme & Design Tokens

### `lib/core/theme/app_colors.dart` `[EXISTS — complete]`

```dart
import 'package:flutter/material.dart';

class AppColors {
  // --- Light (manuscript / paper) ---
  static const Color lightBackground  = Color(0xFFFBF7F0);
  static const Color lightSurface     = Color(0xFFFFFFFF);
  static const Color lightText        = Color(0xFF2B2622);
  static const Color lightTextSecond  = Color(0xFF6B635A);
  static const Color lightDivider     = Color(0xFFE8E0D4);
  static const Color lightPali        = Color(0xFF7A2E1D);   // deep terracotta
  static const Color lightTranslation = Color(0xFF33312E);   // warm charcoal

  // --- Dark ---
  static const Color darkBackground   = Color(0xFF15130F);
  static const Color darkSurface      = Color(0xFF1F1C17);
  static const Color darkText         = Color(0xFFEDE7DC);
  static const Color darkTextSecond   = Color(0xFF9E9488);
  static const Color darkDivider      = Color(0xFF332E26);
  static const Color darkPali         = Color(0xFFE0A45C);   // warm gold
  static const Color darkTranslation  = Color(0xFFD6D1C4);

  // --- Accent presets (swatch picker in Appearance settings) ---
  static const Color accentSaffron    = Color(0xFFB5651D);   // default
  static const Color accentMaroon     = Color(0xFF8B1A1A);
  static const Color accentGreen      = Color(0xFF3C6E47);
  static const Color accentIndigo     = Color(0xFF3D3D8F);
  static const Color accentSlateBlue  = Color(0xFF4A6FA5);
  static const Color accentRose       = Color(0xFF8E3A59);
  static const Color accentTeal       = Color(0xFF2A6B6B);
  static const Color accentGold       = Color(0xFF9A7B2E);

  static const List<Color> accentPresets = [
    accentSaffron, accentMaroon, accentGreen, accentIndigo,
    accentSlateBlue, accentRose, accentTeal, accentGold,
  ];
}
```

### `lib/core/theme/app_dimensions.dart` `[EXISTS — complete]`

```dart
class AppDimensions {
  // Spacing
  static const double xs   = 4.0;
  static const double sm   = 8.0;
  static const double md   = 16.0;
  static const double lg   = 24.0;
  static const double xl   = 32.0;
  static const double xxl  = 48.0;

  // Radius
  static const double radiusCard   = 16.0;
  static const double radiusSheet  = 20.0;
  static const double radiusChip   = 8.0;
  static const double radiusButton = 12.0;

  // Bar heights
  static const double bottomBarHeight   = 64.0;
  static const double tabStripHeight    = 44.0;
  static const double topAppBarHeight   = 56.0;
  static const double ttsMiniBatHeight  = 52.0;
  static const double dragHandleWidth   = 40.0;
  static const double dragHandleHeight  = 4.0;

  // Reader
  static const double paragraphVerticalPad  = 12.0;
  static const double paragraphHorizontalPad= 20.0;
  static const double marginLabelWidth      = 36.0;
}
```

### `lib/core/theme/app_typography.dart` `[EXISTS — complete]`

```dart
import 'package:flutter/material.dart';

class AppTypography {
  // Pāli text — rendered with NotoSerif for diacritic support
  static const String paliFontFamily        = 'NotoSerif';
  // UI & translation — humanist sans with broad Unicode coverage
  static const String uiFontFamily          = 'NotoSans';

  static TextStyle paliBody({
    double size = 16,
    Color? color,
    FontWeight weight = FontWeight.normal,
  }) => TextStyle(
    fontFamily: paliFontFamily,
    fontSize: size,
    color: color,
    fontWeight: weight,
    height: 1.75,
    letterSpacing: 0.1,
  );

  static TextStyle translationBody({
    double size = 15,
    Color? color,
    FontWeight weight = FontWeight.normal,
  }) => TextStyle(
    fontFamily: uiFontFamily,
    fontSize: size,
    color: color,
    fontWeight: weight,
    height: 1.7,
  );

  static TextStyle uiLabel({double size = 14, Color? color}) =>
      TextStyle(fontFamily: uiFontFamily, fontSize: size, color: color);

  static TextStyle sectionHeader({Color? color}) =>
      TextStyle(
        fontFamily: uiFontFamily,
        fontSize: 11,
        color: color,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
      );
}
```

### `lib/core/theme/app_theme.dart` `[EXISTS — complete]`

```dart
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_dimensions.dart';

class AppTheme {
  static ThemeData light(Color accent) {
    final cs = ColorScheme.light(
      primary:    accent,
      surface:    AppColors.lightSurface,
      onSurface:  AppColors.lightText,
      surfaceContainerHighest: AppColors.lightBackground,
    );
    return _build(cs, Brightness.light);
  }

  static ThemeData dark(Color accent) {
    // Lighten the accent for dark-mode contrast
    final darkAccent = HSLColor.fromColor(accent)
        .withLightness(0.65).toColor();
    final cs = ColorScheme.dark(
      primary:   darkAccent,
      surface:   AppColors.darkSurface,
      onSurface: AppColors.darkText,
      surfaceContainerHighest: AppColors.darkBackground,
    );
    return _build(cs, Brightness.dark);
  }

  static ThemeData _build(ColorScheme cs, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme:  cs,
      scaffoldBackgroundColor: isDark
          ? AppColors.darkBackground : AppColors.lightBackground,
      dividerColor: isDark ? AppColors.darkDivider : AppColors.lightDivider,
      fontFamily: AppTypography.uiFontFamily,
      cardTheme: CardThemeData(
        color: cs.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          side: BorderSide(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusSheet),
          ),
        ),
        showDragHandle: true,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark
            ? AppColors.darkBackground : AppColors.lightBackground,
        foregroundColor: cs.primary,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: AppTypography.paliFontFamily,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: cs.primary,
        ),
      ),
    );
  }
}
```

---

## Phase 2 — Models & Settings

### `lib/core/models/app_models.dart` `[EXISTS — extend]`

```dart
// Keep existing models and add:

// Reading position persisted per-book
class ReadingPosition {
  final String bookId;
  final int    paraId;
  final int    lineId;
  final DateTime lastRead;
  const ReadingPosition({
    required this.bookId, required this.paraId,
    required this.lineId, required this.lastRead,
  });
}

// A single open reader tab
class ReaderTab {
  final String   id;       // uuid
  final String   bookId;
  final String   bookName;
  final int      paraId;   // current scroll position
  ReaderTab({required this.id, required this.bookId,
             required this.bookName, required this.paraId});
  ReaderTab copyWith({int? paraId}) =>
      ReaderTab(id: id, bookId: bookId, bookName: bookName,
                paraId: paraId ?? this.paraId);
}

// A paragraph as it arrives from the DB join
class ParagraphRow {
  final String   bookId;
  final int      paraId;
  final int      lineId;
  final String?  pali;
  final String?  vripara;
  final String?  thaipage;
  final String?  vripage;
  final String?  ptspage;
  // translation fields (null if no translation DB loaded)
  final String?  translation;
  final String?  translationLang;
  const ParagraphRow({
    required this.bookId, required this.paraId, required this.lineId,
    this.pali, this.vripara, this.thaipage, this.vripage, this.ptspage,
    this.translation, this.translationLang,
  });
}
```

### `lib/core/models/settings_model.dart` `[NEW]`

```dart
import 'package:flutter/material.dart';
import '../config/pali_scripts.dart';

/// All persisted user preferences.
/// Serialised to SharedPreferences as JSON.
class AppSettings {
  final ThemeMode   themeMode;
  final Color       accentColor;
  final Color       paliColor;
  final Color       translationColor;
  final PaliScript  paliScript;
  final String      uiLanguage;       // BCP-47 code
  final List<String> activeTranslationLangs; // ordered list
  final double      paliFontSize;
  final double      translationFontSize;
  final bool        paliFontSerif;
  final bool        translationFontSerif;
  final double      lineHeightScale;
  final double      autoScrollSpeed;
  final String      pageNumberingSystem; // 'vri' | 'pts' | 'thai' | 'my'
  final bool        wifiOnlyDownload;
  final double      ttsSpeed;
  final String?     ttsVoiceId;

  const AppSettings({
    this.themeMode          = ThemeMode.system,
    this.accentColor        = const Color(0xFFB5651D),
    this.paliColor          = const Color(0xFF7A2E1D),
    this.translationColor   = const Color(0xFF33312E),
    this.paliScript         = PaliScript.roman,
    this.uiLanguage         = 'en',
    this.activeTranslationLangs = const ['en'],
    this.paliFontSize       = 16.0,
    this.translationFontSize= 15.0,
    this.paliFontSerif      = true,
    this.translationFontSerif= false,
    this.lineHeightScale    = 1.0,
    this.autoScrollSpeed    = 60.0,
    this.pageNumberingSystem= 'vri',
    this.wifiOnlyDownload   = true,
    this.ttsSpeed           = 1.0,
    this.ttsVoiceId,
  });

  AppSettings copyWith({
    ThemeMode?   themeMode,
    Color?       accentColor,
    Color?       paliColor,
    Color?       translationColor,
    PaliScript?  paliScript,
    String?      uiLanguage,
    List<String>? activeTranslationLangs,
    double?      paliFontSize,
    double?      translationFontSize,
    bool?        paliFontSerif,
    bool?        translationFontSerif,
    double?      lineHeightScale,
    double?      autoScrollSpeed,
    String?      pageNumberingSystem,
    bool?        wifiOnlyDownload,
    double?      ttsSpeed,
    String?      ttsVoiceId,
  }) => AppSettings(
    themeMode:    themeMode ?? this.themeMode,
    accentColor:  accentColor ?? this.accentColor,
    paliColor:    paliColor ?? this.paliColor,
    translationColor: translationColor ?? this.translationColor,
    paliScript:   paliScript ?? this.paliScript,
    uiLanguage:   uiLanguage ?? this.uiLanguage,
    activeTranslationLangs: activeTranslationLangs ?? this.activeTranslationLangs,
    paliFontSize: paliFontSize ?? this.paliFontSize,
    translationFontSize: translationFontSize ?? this.translationFontSize,
    paliFontSerif: paliFontSerif ?? this.paliFontSerif,
    translationFontSerif: translationFontSerif ?? this.translationFontSerif,
    lineHeightScale: lineHeightScale ?? this.lineHeightScale,
    autoScrollSpeed: autoScrollSpeed ?? this.autoScrollSpeed,
    pageNumberingSystem: pageNumberingSystem ?? this.pageNumberingSystem,
    wifiOnlyDownload: wifiOnlyDownload ?? this.wifiOnlyDownload,
    ttsSpeed:     ttsSpeed ?? this.ttsSpeed,
    ttsVoiceId:   ttsVoiceId ?? this.ttsVoiceId,
  );

  // toJson / fromJson omitted for brevity — use json_serializable or manual
}
```

---

## Phase 3 — Database & Repository Layer

### `lib/core/database/epitaka_database.dart` `[EXISTS — keep]`

No change needed. Tables: `Books`, `Headings`, `Sentences`.

### `lib/core/database/translation_database.dart` `[EXISTS — keep]`

No change needed. Table: `TranslationSentences`.

### `lib/core/database/repositories/book_repository.dart` `[NEW]`

```dart
import '../epitaka_database.dart';
import 'package:drift/drift.dart';

class BookRepository {
  final EpitakaDatabase _db;
  BookRepository(this._db);

  /// All top-level Piṭaka categories (Vinaya / Sutta / Abhidhamma)
  Future<List<Book>> getCategories() =>
      (_db.select(_db.books)
        ..where((b) => b.category.isNotNull())
        ..orderBy([(b) => OrderingTerm.asc(b.id)])
      ).get();

  /// Books within a nikāya
  Future<List<Book>> getBooksForNikaya(String nikaya) =>
      (_db.select(_db.books)
        ..where((b) => b.nikaya.equals(nikaya))
      ).get();

  /// Single book by bookId
  Future<Book?> getBook(String bookId) =>
      (_db.select(_db.books)
        ..where((b) => b.bookId.equals(bookId))
      ).getSingleOrNull();

  /// Headings (TOC) for a book
  Future<List<Heading>> getHeadings(String bookId) =>
      (_db.select(_db.headings)
        ..where((h) => h.bookId.equals(bookId))
        ..orderBy([(h) => OrderingTerm.asc(h.paraId)])
      ).get();

  /// A page of sentences for the reader (used by paginated loader)
  /// Returns [pageSize] sentences starting from [fromParaId].
  Future<List<Sentence>> getSentencePage({
    required String bookId,
    required int fromParaId,
    required int pageSize,
  }) =>
      (_db.select(_db.sentences)
        ..where((s) => s.bookId.equals(bookId) & s.paraId.isBiggerOrEqualValue(fromParaId))
        ..orderBy([(s) => OrderingTerm.asc(s.paraId), (s) => OrderingTerm.asc(s.lineId)])
        ..limit(pageSize)
      ).get();

  Stream<List<Book>> watchAllBooks() => _db.select(_db.books).watch();
}
```

### `lib/core/database/repositories/translation_repository.dart` `[NEW]`

```dart
import '../translation_database.dart';
import 'package:drift/drift.dart';

class TranslationRepository {
  final TranslationDatabase _db;
  final String langCode;
  TranslationRepository(this._db, this.langCode);

  Future<List<TranslationSentence>> getTranslationsForPage({
    required String bookId,
    required int fromParaId,
    required int pageSize,
  }) =>
      (_db.select(_db.translationSentences)
        ..where((t) =>
            t.bookId.equals(bookId) &
            t.paraId.isBiggerOrEqualValue(fromParaId))
        ..orderBy([(t) => OrderingTerm.asc(t.paraId), (t) => OrderingTerm.asc(t.lineId)])
        ..limit(pageSize)
      ).get();

  /// Fetch translations for a specific set of (paraId, lineId) pairs.
  /// Used when merging with Pāli sentences already loaded.
  Future<Map<(int, int), String>> getTranslationsMap({
    required String bookId,
    required List<int> paraIds,
  }) async {
    final rows = await (_db.select(_db.translationSentences)
      ..where((t) =>
          t.bookId.equals(bookId) &
          t.paraId.isIn(paraIds))
    ).get();
    return { for (final r in rows) (r.paraId, r.lineId) : r.translation ?? '' };
  }

  /// Full-text search in this translation DB.
  Future<List<TranslationSentence>> search(String query, {String? bookId}) async {
    final stmt = _db.select(_db.translationSentences)
      ..where((t) => t.translation.like('%$query%'));
    if (bookId != null) stmt.where((t) => t.bookId.equals(bookId));
    return stmt.get();
  }
}
```

### `lib/core/database/repositories/download_repository.dart` `[NEW]`

```dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../config/app_config.dart';
import '../../config/supported_languages.dart';

enum DownloadStatus { notDownloaded, downloading, downloaded, updateAvailable }

class DownloadRepository {
  /// Returns the local path for a language DB.
  static Future<String> dbPath(String langCode) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/${AppConfig.translationDbPrefix}$langCode${AppConfig.translationDbExtension}';
  }

  static Future<bool> isDownloaded(String langCode) async {
    final path = await dbPath(langCode);
    return File(path).exists();
  }

  /// Download a language DB with progress callback.
  /// Real implementation: use dio or http + write stream.
  static Stream<double> download(LangMeta lang) async* {
    final url  = '${AppConfig.downloadBaseUrl}${lang.dbFilename}';
    final path = await dbPath(lang.code);
    // TODO: implement with dio:
    //   final dio = Dio(); await dio.download(url, path, onReceiveProgress: ...)
    yield 0.0;
    // ... yield progress 0..1
    yield 1.0;
  }

  static Future<void> delete(String langCode) async {
    final file = File(await dbPath(langCode));
    if (await file.exists()) await file.delete();
  }

  static Future<double> storageMb(String langCode) async {
    final file = File(await dbPath(langCode));
    if (!await file.exists()) return 0;
    return (await file.length()) / (1024 * 1024);
  }
}
```

---

## Phase 4 — Providers (Riverpod)

### `lib/core/providers/database_provider.dart` `[EXISTS — extend]`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../database/epitaka_database.dart';
import '../database/translation_database.dart';
import '../config/app_config.dart';

/// The single EpitakaDatabase instance
final epitakaDatabaseProvider = Provider<EpitakaDatabase>((ref) {
  throw UnimplementedError('Override in ProviderScope');
  // Actual construction happens in main.dart via override:
  //   epitakaDatabaseProvider.overrideWithValue(await EpitakaDatabase.open(path))
});

/// Map of langCode → open TranslationDatabase (lazily opened on download/enable)
final translationDatabasesProvider =
    StateProvider<Map<String, TranslationDatabase>>((ref) => {});

/// Open (or return cached) translation DB for a given langCode
final translationDatabaseProvider =
    FutureProvider.family<TranslationDatabase?, String>((ref, langCode) async {
  final existing = ref.watch(translationDatabasesProvider)[langCode];
  if (existing != null) return existing;
  final dir  = await getApplicationDocumentsDirectory();
  final path = '${dir.path}/${AppConfig.translationDbPrefix}$langCode'
               '${AppConfig.translationDbExtension}';
  try {
    final db = await TranslationDatabase.open(path);
    ref.read(translationDatabasesProvider.notifier)
        .update((m) => {...m, langCode: db});
    return db;
  } catch (_) {
    return null; // not downloaded yet
  }
});
```

### `lib/core/providers/settings_provider.dart` `[EXISTS — rewrite]`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings_model.dart';

class SettingsNotifier extends Notifier<AppSettings> {
  static const _key = 'app_settings_v1';

  @override
  AppSettings build() {
    _load(); // async — state starts with defaults
    return const AppSettings();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final json  = prefs.getString(_key);
    if (json != null) {
      // TODO: state = AppSettings.fromJson(jsonDecode(json));
    }
  }

  Future<void> update(AppSettings Function(AppSettings) updater) async {
    state = updater(state);
    final prefs = await SharedPreferences.getInstance();
    // TODO: await prefs.setString(_key, jsonEncode(state.toJson()));
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
```

### `lib/core/providers/books_provider.dart` `[EXISTS — extend]`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/repositories/book_repository.dart';
import '../database/epitaka_database.dart';
import 'database_provider.dart';

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  final db = ref.watch(epitakaDatabaseProvider);
  return BookRepository(db);
});

/// All top-level Piṭaka categories for the library tree
final categoriesProvider = FutureProvider<List<Book>>((ref) =>
    ref.watch(bookRepositoryProvider).getCategories());

/// Books for a given nikāya (family used for per-nikāya nodes in the tree)
final nikayaBooksProvider = FutureProvider.family<List<Book>, String>(
    (ref, nikaya) => ref.watch(bookRepositoryProvider).getBooksForNikaya(nikaya));

/// Headings / TOC for a book
final headingsProvider = FutureProvider.family<List<Heading>, String>(
    (ref, bookId) => ref.watch(bookRepositoryProvider).getHeadings(bookId));
```

### `lib/features/reader/providers/reader_provider.dart` `[EXISTS — rewrite]`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/app_models.dart';
import '../../../core/config/app_config.dart';

// ── Tab management ──────────────────────────────────────────────────────────

class TabsNotifier extends Notifier<List<ReaderTab>> {
  @override
  List<ReaderTab> build() => [];

  String openBook(String bookId, String bookName, {int paraId = 0}) {
    // If already open, switch to it
    final existing = state.where((t) => t.bookId == bookId).firstOrNull;
    if (existing != null) {
      setActiveTab(existing.id);
      return existing.id;
    }
    if (state.length >= AppConfig.maxOpenTabs) {
      // Remove oldest tab
      state = state.sublist(1);
    }
    final tab = ReaderTab(
      id: const Uuid().v4(), bookId: bookId,
      bookName: bookName, paraId: paraId,
    );
    state = [...state, tab];
    setActiveTab(tab.id);
    return tab.id;
  }

  void closeTab(String id) {
    state = state.where((t) => t.id != id).toList();
    if (_activeTabId == id) {
      _activeTabId = state.isNotEmpty ? state.last.id : null;
    }
  }

  void updatePosition(String tabId, int paraId) {
    state = [for (final t in state) t.id == tabId ? t.copyWith(paraId: paraId) : t];
  }

  String? _activeTabId;
  void setActiveTab(String id) { _activeTabId = id; }
  String? get activeTabId => _activeTabId;
}

final tabsProvider = NotifierProvider<TabsNotifier, List<ReaderTab>>(
  TabsNotifier.new,
);

final activeTabIdProvider = Provider<String?>((ref) =>
    ref.watch(tabsProvider.notifier).activeTabId);

// ── Paginated paragraph loading ──────────────────────────────────────────────

class ParagraphPageNotifier
    extends FamilyAsyncNotifier<List<ParagraphRow>, String> {
  int _loadedUpTo = 0;
  bool _hasMore   = true;

  @override
  Future<List<ParagraphRow>> build(String bookId) async {
    _loadedUpTo = 0;
    return _loadNextPage(bookId);
  }

  Future<List<ParagraphRow>> _loadNextPage(String bookId) async {
    // fetch from BookRepository + merge translations
    // set _loadedUpTo, _hasMore
    return [];
  }

  Future<void> loadMore(String bookId) async {
    if (!_hasMore) return;
    final next = await _loadNextPage(bookId);
    state = AsyncData([...state.value ?? [], ...next]);
  }
}

final paragraphsProvider =
    AsyncNotifierProviderFamily<ParagraphPageNotifier, List<ParagraphRow>, String>(
  ParagraphPageNotifier.new,
);
```

### `lib/features/search/providers/search_provider.dart` `[NEW]`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_models.dart';

enum SearchScope { thisBook, allBooks }

class SearchState {
  final String      query;
  final SearchScope scope;
  final String?     bookId;
  final bool        searchPali;
  final bool        searchTranslation;
  final bool        isLoading;
  final List<ParagraphRow> results;
  const SearchState({
    this.query = '',
    this.scope = SearchScope.thisBook,
    this.bookId,
    this.searchPali = true,
    this.searchTranslation = true,
    this.isLoading = false,
    this.results = const [],
  });
  SearchState copyWith({/* ... */}) => SearchState(/* ... */);
}

class SearchNotifier extends Notifier<SearchState> {
  @override
  SearchState build() => const SearchState();

  Future<void> search(String query) async {
    state = state.copyWith(query: query, isLoading: true);
    // TODO: call BookRepository.search + TranslationRepository.search
    state = state.copyWith(isLoading: false, results: []);
  }

  void setScope(SearchScope scope) =>
      state = state.copyWith(scope: scope);
}

final searchProvider = NotifierProvider<SearchNotifier, SearchState>(
    SearchNotifier.new);
```

### `lib/features/reader/providers/tts_provider.dart` `[NEW]`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsStatus { stopped, playing, paused }

class TtsState {
  final TtsStatus status;
  final String?   currentBookId;
  final int?      currentParaId;
  final double    speed;
  const TtsState({
    this.status      = TtsStatus.stopped,
    this.currentBookId,
    this.currentParaId,
    this.speed       = 1.0,
  });
  TtsState copyWith({TtsStatus? status, String? currentBookId,
                     int? currentParaId, double? speed}) =>
      TtsState(
        status:        status        ?? this.status,
        currentBookId: currentBookId ?? this.currentBookId,
        currentParaId: currentParaId ?? this.currentParaId,
        speed:         speed         ?? this.speed,
      );
}

class TtsNotifier extends Notifier<TtsState> {
  late final FlutterTts _tts;

  @override
  TtsState build() {
    _tts = FlutterTts();
    _tts.setCompletionHandler(() {
      state = state.copyWith(status: TtsStatus.stopped);
    });
    return const TtsState();
  }

  Future<void> speak(String text, {required String bookId, required int paraId}) async {
    await _tts.setRate(state.speed);
    await _tts.speak(text);
    state = state.copyWith(
      status: TtsStatus.playing,
      currentBookId: bookId,
      currentParaId: paraId,
    );
  }

  Future<void> pause()  async { await _tts.pause();  state = state.copyWith(status: TtsStatus.paused); }
  Future<void> stop()   async { await _tts.stop();   state = state.copyWith(status: TtsStatus.stopped); }
  Future<void> setSpeed(double s) async {
    await _tts.setRate(s);
    state = state.copyWith(speed: s);
  }
}

final ttsProvider = NotifierProvider<TtsNotifier, TtsState>(TtsNotifier.new);
```

### `lib/features/downloads/providers/download_provider.dart` `[NEW]`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/repositories/download_repository.dart';
import '../../../core/config/supported_languages.dart';

class LangDownloadState {
  final String      langCode;
  final DownloadStatus status;
  final double      progress; // 0..1
  const LangDownloadState({
    required this.langCode,
    this.status   = DownloadStatus.notDownloaded,
    this.progress = 0,
  });
  LangDownloadState copyWith({DownloadStatus? status, double? progress}) =>
      LangDownloadState(
        langCode: langCode,
        status:   status   ?? this.status,
        progress: progress ?? this.progress,
      );
}

class DownloadNotifier
    extends Notifier<Map<String, LangDownloadState>> {
  @override
  Map<String, LangDownloadState> build() {
    _checkDownloaded();
    return { for (final l in kSupportedLanguages)
      l.code: LangDownloadState(langCode: l.code) };
  }

  Future<void> _checkDownloaded() async {
    for (final l in kSupportedLanguages) {
      if (await DownloadRepository.isDownloaded(l.code)) {
        _update(l.code, status: DownloadStatus.downloaded);
      }
    }
  }

  void _update(String code, {DownloadStatus? status, double? progress}) {
    final cur = state[code]!;
    state = {...state, code: cur.copyWith(status: status, progress: progress)};
  }

  Future<void> download(LangMeta lang) async {
    _update(lang.code, status: DownloadStatus.downloading, progress: 0);
    await for (final p in DownloadRepository.download(lang)) {
      _update(lang.code, progress: p);
    }
    _update(lang.code, status: DownloadStatus.downloaded, progress: 1);
  }

  Future<void> delete(String langCode) async {
    await DownloadRepository.delete(langCode);
    _update(langCode, status: DownloadStatus.notDownloaded, progress: 0);
  }
}

final downloadProvider =
    NotifierProvider<DownloadNotifier, Map<String, LangDownloadState>>(
  DownloadNotifier.new,
);
```

---

## Phase 5 — Navigation & Shell

### `lib/router/app_router.dart` `[EXISTS — complete]`

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../shared/widgets/app_shell.dart';
import '../features/library/screens/library_screen.dart';
import '../features/reader/screens/reader_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/settings/screens/typography_settings_screen.dart';
import '../features/settings/screens/appearance_settings_screen.dart';
import '../features/settings/screens/reading_colors_screen.dart';
import '../features/settings/screens/reading_options_screen.dart';
import '../features/settings/screens/tts_settings_screen.dart';
import '../features/downloads/screens/downloads_screen.dart';
import '../features/onboarding/screens/onboarding_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/library',
  routes: [
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),

    ShellRoute(
      builder: (ctx, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/library', builder: (_, __) => const LibraryScreen()),
        GoRoute(
          path: '/reader/:bookId',
          builder: (ctx, state) => ReaderScreen(
            bookId: state.pathParameters['bookId']!,
          ),
        ),
      ],
    ),

    // Settings sub-routes (no shell — full screen)
    GoRoute(path: '/settings',             builder: (_, __) => const SettingsScreen()),
    GoRoute(path: '/settings/typography',  builder: (_, __) => const TypographySettingsScreen()),
    GoRoute(path: '/settings/appearance',  builder: (_, __) => const AppearanceSettingsScreen()),
    GoRoute(path: '/settings/colors',      builder: (_, __) => const ReadingColorsScreen()),
    GoRoute(path: '/settings/reading',     builder: (_, __) => const ReadingOptionsScreen()),
    GoRoute(path: '/settings/tts',         builder: (_, __) => const TtsSettingsScreen()),
    GoRoute(path: '/settings/downloads',   builder: (_, __) => const DownloadsScreen()),
  ],
);
```

### `lib/shared/widgets/app_shell.dart` `[EXISTS — extend]`

The shell wraps Library + Reader. On desktop (width > 800px) it shows a persistent left navigation rail. On mobile it uses bottom navigation only inside specific screens (not a global bottom nav, since the reader has its own bottom toolbar).

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({required this.child, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= AppConfig.desktopBreakpoint;
    if (wide) {
      return Row(children: [
        _DesktopNavRail(),
        const VerticalDivider(width: 1),
        Expanded(child: child),
      ]);
    }
    return child; // mobile: each screen manages its own nav
  }
}
```

---

## Phase 6 — Library Screen

### `lib/features/library/screens/library_screen.dart` `[EXISTS — complete]`

Sections:
1. Top app bar with wordmark + search icon + settings gear + profile avatar.
2. Tab row: **Browse | Continue Reading | Bookmarks**.
3. Browse tab → `_TipitakaTree` widget (expandable ListView).
4. Continue Reading tab → horizontal scroll of `_RecentBookCard`.
5. Bookmarks tab → grouped list.
6. FAB bottom-right: open new book.

```dart
// Tipitaka tree item
class _TreeNode extends StatelessWidget {
  final Book book;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onOpen;  // opens the book in reader

  Widget build(BuildContext context) {
    return Column(children: [
      ListTile(
        leading: Icon(isExpanded ? Icons.expand_less : Icons.chevron_right),
        title: Text(book.bookName ?? book.bookId,
            style: AppTypography.paliBody(size: 15, color: Theme.of(context).colorScheme.onSurface)),
        trailing: _DownloadBadge(bookId: book.bookId),  // shows which langs downloaded
        onTap: onTap,
      ),
      if (isExpanded) _BookChildren(parentBookId: book.bookId, onOpen: onOpen),
    ]);
  }
}
```

---

## Phase 7 — Reader Screen

### `lib/features/reader/screens/reader_screen.dart` `[EXISTS — complete]`

Key structure:

```
Scaffold
  body: Column(
    children:
      _TabStrip          ← horizontally scrollable tab chips
      Expanded(
        child: _ReadingPane(bookId)
      )
  )
  bottomNavigationBar: _ReaderBottomBar
  floatingActionButton: _TtsMinBar (when TTS active)
```

### `lib/features/reader/widgets/tab_strip.dart` `[NEW]`

```dart
class TabStrip extends ConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = ref.watch(tabsProvider);
    final activeId = ref.watch(activeTabIdProvider);
    return SizedBox(
      height: AppDimensions.tabStripHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        itemCount: tabs.length,
        itemBuilder: (_, i) => _TabChip(tab: tabs[i], isActive: tabs[i].id == activeId),
      ),
    );
  }
}

class _TabChip extends ConsumerWidget {
  // Shows book name, active accent underline, × close button
}
```

### `lib/features/reader/widgets/reading_pane.dart` `[NEW]`

Uses `CustomScrollView` + `SliverList` for virtualization. Loads more paragraphs when near the bottom via `NotificationListener<ScrollNotification>`.

```dart
class ReadingPane extends ConsumerWidget {
  final String bookId;

  Widget build(BuildContext context, WidgetRef ref) {
    final paragraphsAsync = ref.watch(paragraphsProvider(bookId));
    return paragraphsAsync.when(
      loading: () => const _SkeletonLoader(),
      error:   (e, _) => _ErrorView(error: e),
      data:    (rows) => NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 400) {
            ref.read(paragraphsProvider(bookId).notifier).loadMore(bookId);
          }
          return false;
        },
        child: CustomScrollView(
          slivers: [
            SliverList.builder(
              itemCount: rows.length,
              itemBuilder: (_, i) => ReadingParagraph(row: rows[i]),
            ),
          ],
        ),
      ),
    );
  }
}
```

### `lib/shared/widgets/reading_paragraph.dart` `[EXISTS — extend]`

```dart
class ReadingParagraph extends ConsumerWidget {
  final ParagraphRow row;

  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final paliColor = isDark ? settings.paliColor.lighten() : settings.paliColor;
    final transColor= isDark ? settings.translationColor.lighten() : settings.translationColor;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paragraphHorizontalPad,
          vertical:   AppDimensions.paragraphVerticalPad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Margin: paragraph number / page reference
          SizedBox(
            width: AppDimensions.marginLabelWidth,
            child: Text(
              _pageLabel(row, settings.pageNumberingSystem),
              style: AppTypography.uiLabel(size: 10, color: Theme.of(context).dividerColor),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pāli text — GestureDetector for word-tap → dictionary
              if (row.pali != null)
                GestureDetector(
                  onLongPress: () => _showWordMenu(context, ref, row.pali!),
                  child: SelectableText(
                    _applyScript(row.pali!, settings.paliScript),
                    style: AppTypography.paliBody(
                      size:  settings.paliFontSize,
                      color: paliColor,
                    ).copyWith(
                      height: 1.75 * settings.lineHeightScale,
                      fontFamily: settings.paliFontSerif
                          ? AppTypography.paliFontFamily : AppTypography.uiFontFamily,
                    ),
                  ),
                ),
              // Translation text
              if (row.translation != null) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onDoubleTap: () => _openProofread(context, row),
                  child: Text(
                    row.translation!,
                    style: AppTypography.translationBody(
                      size:  settings.translationFontSize,
                      color: transColor,
                    ).copyWith(
                      height: 1.7 * settings.lineHeightScale,
                    ),
                  ),
                ),
              ],
            ],
          )),
        ],
      ),
    );
  }

  String _pageLabel(ParagraphRow row, String system) => switch (system) {
    'vri'  => row.vripara ?? '',
    'pts'  => row.ptspage ?? '',
    'thai' => row.thaipage ?? '',
    'my'   => row.mypage ?? '',
    _      => row.vripara ?? '',
  };
}
```

### `lib/features/reader/widgets/reader_bottom_bar.dart` `[NEW]`

```dart
// Floating pill-style toolbar at the bottom of the reader.
// 5 icons: Contents, Search, Dictionary, Listen, Bookmark.
// Tapping each calls showModalBottomSheet with the appropriate sheet.
class ReaderBottomBar extends ConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 24, right: 24, bottom: 12),
        child: Material(
          elevation: 0,
          borderRadius: BorderRadius.circular(32),
          color: Theme.of(context).colorScheme.surface,
          child: Container(
            height: AppDimensions.bottomBarHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _BarButton(icon: Icons.menu_book, label: 'Contents',
                    onTap: () => _showSheet(context, const ContentsSheet())),
                _BarButton(icon: Icons.search,    label: 'Search',
                    onTap: () => _showSheet(context, const SearchSheet())),
                _BarButton(icon: Icons.book,      label: 'Dictionary',
                    onTap: () => _showSheet(context, const DictionarySheet())),
                _BarButton(icon: Icons.volume_up, label: 'Listen',
                    onTap: () => _showSheet(context, const TtsSheet())),
                _BarButton(icon: Icons.bookmark_border, label: 'Bookmark',
                    onTap: () => _bookmarkCurrent(ref)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

---

## Phase 8 — Bottom Sheets

All sheets share a common `_SheetShell` wrapper (drag handle + title + optional segmented switcher + close button).

### `lib/shared/widgets/sheet_shell.dart` `[NEW]`

```dart
class SheetShell extends StatelessWidget {
  final String   title;
  final Widget   child;
  final List<String>? tabs;    // if provided, shows segmented control
  final int?          activeTab;
  final ValueChanged<int>? onTabChanged;

  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: AppConfig.bottomSheetMinHeight,
      maxChildSize:     AppConfig.bottomSheetMaxHeight,
      expand: false,
      builder: (ctx, scrollController) => Column(children: [
        _DragHandle(),
        _SheetHeader(title: title, tabs: tabs,
            activeTab: activeTab, onTabChanged: onTabChanged),
        Expanded(child: SingleChildScrollView(
          controller: scrollController, child: child)),
      ]),
    );
  }
}
```

### `lib/features/contents/screens/contents_screen.dart` → split into sheet `[EXISTS — adapt]`

```
lib/features/contents/widgets/
  contents_sheet.dart      ← tab: Tipitaka Tree
  in_book_toc_sheet.dart   ← tab: In-Book Contents
  open_tabs_sheet.dart     ← tab: Open Tabs
```

The `ContentsSheet` wraps all three in a `SheetShell` with a 3-tab segmented switcher.

### `lib/features/search/widgets/search_sheet.dart` `[NEW]`

```dart
// Shows:
// - Search field with scope chips (This Book / All Books)
// - Filter chips: Pāli / Translation / Both + language picker
// - Results SliverList
// - Recent searches when query is empty
```

### `lib/features/dictionary/widgets/dictionary_sheet.dart` `[NEW]`

```dart
// Shows:
// - Search field + fuzzy toggle
// - Entry display: headword, POS, gloss, example, source
// - Script selector chips (Roman / Devanāgarī / Thai / Myanmar / Sinhala / Tibetan)
// - Recent lookups list
```

### `lib/features/reader/widgets/tts_sheet.dart` `[NEW]`

```dart
// Mini-bar version (docked above bottom bar when TTS active)
// Expanded sheet: playback controls, speed slider, voice picker, paragraph list
class TtsMiniBar extends ConsumerWidget { /* ... */ }
class TtsSheet   extends ConsumerWidget { /* ... */ }
```

---

## Phase 9 — Settings Screens

### `lib/features/settings/screens/settings_screen.dart` `[EXISTS — matches design]`

The Settings root already matches the screenshots. Groups:
- GENERAL: Language, Script
- APPEARANCE: Theme, Typography & Font Size, Reading Colors
- DATA & CONTENT: Translations & Downloads
- READING PREFERENCES: Reading Options, Text-to-Speech
- ACCOUNT: Profile
- SYSTEM: About ePitaka

Each row navigates via `context.push('/settings/...')`.

### `lib/features/settings/screens/appearance_settings_screen.dart` `[NEW]`

```
Sections:
  Theme       → 3-way segmented (Light / Dark / System)
  Accent color→ horizontal swatches from AppColors.accentPresets + custom picker
  Live preview card at TOP (updates as settings change — watch settingsProvider)
```

### `lib/features/settings/screens/reading_colors_screen.dart` `[NEW]`

```
Live preview card (Pāli + translation sample, updates live)
Pāli text color     → swatches + custom picker
Translation color   → swatches + custom picker
```

### `lib/features/settings/screens/typography_settings_screen.dart` `[EXISTS — complete]`

```
Live preview card
Pāli font:          Serif / Sans toggle
Translation font:   Serif / Sans toggle
Pāli size:          A– / A / A+ stepper  (range 12–24)
Translation size:   A– / A / A+ stepper  (range 11–22)
Line height:        slider 0.8×–1.5×
```

### `lib/features/downloads/screens/downloads_screen.dart` `[NEW]`

```
Storage bar at top: "X MB used"
Wifi-only toggle
"Download all" button
ListView of kSupportedLanguages, each row:
  - Language name + native name
  - File size
  - Status chip: Not downloaded / Downloading [CircularProgress] / Downloaded
  - Button: Download / Update / Delete
```

### `lib/features/settings/screens/reading_options_screen.dart` `[NEW]`

```
Page numbering system: dropdown (VRI / PTS / Thai / Myanmar)
Default layout: Stacked / Side-by-side
Auto-scroll speed: slider
Keep screen on: toggle
```

### `lib/features/settings/screens/tts_settings_screen.dart` `[NEW]`

```
Voice: dropdown of available system voices filtered by active translation lang
Speed: slider (0.5× – 2.0×, step 0.25)
Language: follows active translation language, can override
```

---

## Phase 10 — Onboarding

### `lib/features/onboarding/screens/onboarding_screen.dart` `[NEW]`

Three-page PageView:
1. Language select (grid of LangMeta items with native names, single select).
2. Welcome carousel (3 cards: Parallel reading / Dictionary / Offline).
3. Download starter DB (list of kSupportedLanguages + download buttons).

On completion: save `uiLanguage` to settings, push `'/library'`.

---

## Phase 11 — Platform Adaptations

### Mobile (< 600px)

- Reader: single pane, bottom toolbar pill bar.
- Library: bottom nav implicit (just push/pop with go_router).
- Sheets: full-width draggable bottom sheets.

### Tablet (600–800px)

- Reader: optional split-screen (two panes side by side), toggled via overflow menu.
- Sheets: still bottom sheets, wider.

### Desktop / Web (> 800px)

- `AppShell` renders `NavigationRail` on the left (Library / Bookmarks / Settings icons).
- Reader: split-screen on by default (two panes with draggable divider).
- Bottom toolbar becomes a **horizontal toolbar pinned at the bottom of the reading pane** rather than a floating pill (more natural for large screens).
- Sheets become **side drawers** or **inline panels** instead of bottom sheets.

```dart
// In AppShell — adaptive switch:
Widget build(BuildContext context, WidgetRef ref) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= AppConfig.desktopBreakpoint) return _DesktopLayout(child: child);
  if (width >= AppConfig.tabletBreakpoint)  return _TabletLayout(child: child);
  return child; // mobile: no shell chrome
}
```

---

## Phase 12 — Localisation

### `lib/core/localization/` `[NEW]`

Use `flutter_localizations` + ARB files.

```
lib/core/localization/
  l10n.dart          ← AppLocalizations convenience accessor
  arb/
    app_en.arb
    app_zh.arb
    app_th.arb
    app_si.arb
    ... (one per kSupportedLanguages where isUiLang == true)
```

In `pubspec.yaml`:
```yaml
flutter:
  generate: true
  assets:
    - assets/fonts/
    - assets/databases/

flutter_localizations:
  sdk: flutter
```

In `app.dart`:
```dart
MaterialApp.router(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: Locale(ref.watch(settingsProvider).uiLanguage),
  ...
)
```

---

## Phase 13 — `main.dart` Wiring

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Open Epitaka database
  final dir  = await getApplicationDocumentsDirectory();
  final path = '${dir.path}/${AppConfig.epitakaDatabaseFilename}';
  // Copy bundled DB from assets on first launch if not present
  await _ensureBundledDb(path);
  final epitakaDb = await EpitakaDatabase.open(path);

  runApp(
    ProviderScope(
      overrides: [
        epitakaDatabaseProvider.overrideWithValue(epitakaDb),
      ],
      child: const EpitakaApp(),
    ),
  );
}
```

---

## Summary: File Checklist

### Phase 0 — Config (new)
- `lib/core/config/app_config.dart`
- `lib/core/config/supported_languages.dart`
- `lib/core/config/pali_scripts.dart`

### Phase 1 — Theme (extend existing)
- `lib/core/theme/app_colors.dart`
- `lib/core/theme/app_dimensions.dart`
- `lib/core/theme/app_typography.dart`
- `lib/core/theme/app_theme.dart`

### Phase 2 — Models (extend existing)
- `lib/core/models/app_models.dart`
- `lib/core/models/settings_model.dart` ← new

### Phase 3 — Repositories (new)
- `lib/core/database/repositories/book_repository.dart`
- `lib/core/database/repositories/translation_repository.dart`
- `lib/core/database/repositories/download_repository.dart`

### Phase 4 — Providers (extend/rewrite)
- `lib/core/providers/database_provider.dart`
- `lib/core/providers/settings_provider.dart`
- `lib/core/providers/books_provider.dart`
- `lib/features/reader/providers/reader_provider.dart`
- `lib/features/search/providers/search_provider.dart` ← new
- `lib/features/reader/providers/tts_provider.dart` ← new
- `lib/features/downloads/providers/download_provider.dart` ← new

### Phase 5 — Navigation
- `lib/router/app_router.dart`
- `lib/shared/widgets/app_shell.dart`

### Phase 6 — Library
- `lib/features/library/screens/library_screen.dart`
- `lib/features/library/widgets/tipitaka_tree.dart` ← new
- `lib/features/library/widgets/recent_book_card.dart` ← new

### Phase 7 — Reader
- `lib/features/reader/screens/reader_screen.dart`
- `lib/features/reader/widgets/tab_strip.dart` ← new
- `lib/features/reader/widgets/reading_pane.dart` ← new
- `lib/features/reader/widgets/reader_bottom_bar.dart` ← new
- `lib/shared/widgets/reading_paragraph.dart`

### Phase 8 — Sheets
- `lib/shared/widgets/sheet_shell.dart` ← new
- `lib/features/contents/widgets/contents_sheet.dart` ← new
- `lib/features/search/widgets/search_sheet.dart` ← new
- `lib/features/dictionary/widgets/dictionary_sheet.dart` ← new
- `lib/features/reader/widgets/tts_sheet.dart` ← new

### Phase 9 — Settings
- `lib/features/settings/screens/settings_screen.dart` ← matches design
- `lib/features/settings/screens/appearance_settings_screen.dart` ← new
- `lib/features/settings/screens/reading_colors_screen.dart` ← new
- `lib/features/settings/screens/typography_settings_screen.dart` ← exists
- `lib/features/settings/screens/reading_options_screen.dart` ← new
- `lib/features/settings/screens/tts_settings_screen.dart` ← new
- `lib/features/downloads/screens/downloads_screen.dart` ← new

### Phase 10 — Onboarding
- `lib/features/onboarding/screens/onboarding_screen.dart` ← new

### Phase 11 — Platform adaptations
- `lib/shared/widgets/adaptive_layout.dart` ← new (desktop nav rail, tablet split)

### Phase 12 — Localisation
- `lib/core/localization/l10n.dart` ← new
- `lib/core/localization/arb/*.arb` ← new