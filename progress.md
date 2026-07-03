# ePitaka — Implementation Progress

> Last updated: July 1, 2026
> Design plan: `Design.md`

---

## Phase 0 — Project Config & Constants

| File | Status | Notes |
|------|--------|-------|
| `lib/core/config/app_config.dart` | ❌ Not created | — |
| `lib/core/config/supported_languages.dart` | ❌ Not created | — |
| `lib/core/config/pali_scripts.dart` | ❌ Not created | — |

---

## Phase 1 — Theme & Design Tokens

| File | Status | Notes |
|------|--------|-------|
| `lib/core/theme/app_colors.dart` | ✅ Exists | Complete |
| `lib/core/theme/app_dimensions.dart` | ✅ Exists | Complete (has tabHeight, bottomToolbarHeight, margins) |
| `lib/core/theme/app_typography.dart` | ✅ Exists | Complete (has bodyPali, bodyTranslation, labelMedium/Small) |
| `lib/core/theme/app_theme.dart` | ✅ Exists | Complete (light/dark theme with Material3) |

---

## Phase 2 — Models & Settings

| File | Status | Notes |
|------|--------|-------|
| `lib/core/models/app_models.dart` | ✅ Exists | Has BookInfo, HeadingInfo, SentenceInfo, TranslationInfo, TranslationLanguage |
| `lib/core/models/settings_model.dart` | ⚠️ Partial | Settings live inside `lib/core/providers/settings_provider.dart` as AppSettings class, not a separate model file |

---

## Phase 3 — Database & Repository Layer

| File | Status | Notes |
|------|--------|-------|
| `lib/core/database/epitaka_database.dart` | ✅ Exists | Tables: Books, Headings, Sentences |
| `lib/core/database/translation_database.dart` | ✅ Exists | Table: TranslationSentences |
| `lib/core/database/repositories/book_repository.dart` | ❌ Not created | — |
| `lib/core/database/repositories/translation_repository.dart` | ❌ Not created | — |
| `lib/core/database/repositories/download_repository.dart` | ❌ Not created | — |

---

## Phase 4 — Providers (Riverpod)

| File | Status | Notes |
|------|--------|-------|
| `lib/core/providers/database_provider.dart` | ✅ Exists | Provides epitakaDbProvider and translationDbProvider |
| `lib/core/providers/settings_provider.dart` | ✅ Exists | AppSettings with typography, theme, showPali/showTranslation |
| `lib/core/providers/books_provider.dart` | ✅ Exists | Books tree with BookCategory/BookNikaya/BookItem hierarchy |
| `lib/features/reader/providers/reader_provider.dart` | ✅ Exists | Loads paragraphs with Pāli + translation per bookId |
| `lib/features/reader/providers/reader_tabs_provider.dart` | ✅ **NEW** | Tab management: open, close, switch tabs with ReaderTabInfo |
| `lib/features/search/providers/search_provider.dart` | ❌ Not created | — |
| `lib/features/reader/providers/tts_provider.dart` | ❌ Not created | — |
| `lib/features/downloads/providers/download_provider.dart` | ❌ Not created | — |

---

## Phase 5 — Navigation & Shell

| File | Status | Notes |
|------|--------|-------|
| `lib/router/app_router.dart` | ⚠️ Modified | Reader route changed from `/reader/:bookId` to `/reader` (tabs managed via provider). Contains routes: library, reader, settings, typography, contents. **No ShellRoute** — uses flat routes. |
| `lib/shared/widgets/app_shell.dart` | ✅ Exists | Scaffold with optional AppBar and floating bottom toolbar. No desktop NavigationRail yet. |

---

## Phase 6 — Library Screen

| File | Status | Notes |
|------|--------|-------|
| `lib/features/library/screens/library_screen.dart` | ⚠️ Modified | Updated to open reader tabs instead of direct navigation. Books now add a ReaderTab via provider and navigate to `/reader`. |
| `lib/features/library/widgets/tipitaka_tree.dart` | ❌ Not created | Tree is inline in library_screen.dart |
| `lib/features/library/widgets/recent_book_card.dart` | ❌ Not created | — |

---

## Phase 7 — Reader Screen ✅ **MOST ACTIVE**

| File | Status | Notes |
|------|--------|-------|
| `lib/features/reader/screens/reader_screen.dart` | ⚠️ Modified | Restructured as tab host (ConsumerStatefulWidget). Shows TabStrip → reading pane. Swipe gesture (horizontal drag) for tab switching. Populates/last-tab-closed navigates back. |
| `lib/features/reader/widgets/tab_strip.dart` | ✅ **NEW** | Scrollable horizontal tab chips with active/inactive states, close buttons, Material ripple. Responsive margins (mobile/desktop). Shows bookId short codes (e.g., "M-i"). |
| `lib/features/reader/widgets/reading_pane.dart` | ❌ Not created | Reading content is inline inside reader_screen.dart |
| `lib/features/reader/widgets/reader_bottom_bar.dart` | ❌ Not created | Bottom toolbar is inline (_ReaderBottomToolbar inside reader_screen.dart) |
| `lib/shared/widgets/reading_paragraph.dart` | ✅ Exists | Pāli + translation paragraph block with line numbers |

### What was done for tabs (June 2026 commit):

- **`reader_tabs_provider.dart`** — Riverpod StateNotifier managing `List<ReaderTabInfo>` + active index. Methods: `openTab`, `closeTab`, `switchTo`. `openTab` checks for duplicate bookId and switches to existing tab instead of creating a new one.
- **`tab_strip.dart`** — Horizontal scrollable tab strip. Active tab: white surface + primary bottom border (2px). Inactive: surfaceContainerHigh + transparent border. Close button (×) on each tab. Uses `InkWell` + `Material` for ripple effect. Responsive padding (20px mobile, 40px desktop at >768px breakpoint).
- **`reader_screen.dart`** — Changed from `ConsumerWidget` to `ConsumerStatefulWidget`. Uses `readerTabsProvider` to determine active tab. Preserves scroll position per tab via `Map<String, ScrollController>`. Scrolls to `initialParaId` on newly opened tabs (retries on each build until ListView is laid out). `GestureDetector` with `onHorizontalDragEnd` for swipe tab switching (300 px/s velocity threshold).
- **`library_screen.dart`** — Book taps now add a tab via `readerTabsProvider.notifier.openTab()` and navigate to `/reader` (no bookId in URL).
- **`contents_screen.dart`** — Heading taps add a tab with `initialParaId` and pop back to reader.
- **`app_router.dart`** — Reader route simplified from `/reader/:bookId` to `/reader`. Removed unused `readerPara` constant.

### Known limitations:
- `initialParaId` scroll uses a rough estimate (`paraIndex * 80.0px`) — not pixel-perfect
- Keyboard shortcuts (`Focus` + `CallbackShortcuts`) were **removed** — they caused global input freeze (all clicks/scrolling stopped working) by hijacking keyboard/pointer focus
- No animation when switching tabs
- Tabs are not persisted across app restarts

---

## Phase 8 — Bottom Sheets

| File | Status | Notes |
|------|--------|-------|
| `lib/shared/widgets/sheet_shell.dart` | ❌ Not created | — |
| `lib/features/contents/widgets/contents_sheet.dart` | ❌ Not created | Contents is a full-screen route (`/contents/:bookId`), not a sheet |
| `lib/features/search/widgets/search_sheet.dart` | ❌ Not created | — |
| `lib/features/dictionary/widgets/dictionary_sheet.dart` | ❌ Not created | — |
| `lib/features/reader/widgets/tts_sheet.dart` | ❌ Not created | — |

---

## Phase 9 — Settings Screens

| File | Status | Notes |
|------|--------|-------|
| `lib/features/settings/screens/settings_screen.dart` | ✅ Exists | Groups: General, Appearance, Data & Content, Reading Preferences, Account, System |
| `lib/features/settings/screens/typography_settings_screen.dart` | ✅ Exists | Font size sliders for Pāli & Translation, line spacing, style toggles |
| `lib/features/settings/screens/appearance_settings_screen.dart` | ❌ Not created | — |
| `lib/features/settings/screens/reading_colors_screen.dart` | ❌ Not created | — |
| `lib/features/settings/screens/reading_options_screen.dart` | ❌ Not created | — |
| `lib/features/settings/screens/tts_settings_screen.dart` | ❌ Not created | — |
| `lib/features/downloads/screens/downloads_screen.dart` | ❌ Not created | — |

---

## Phase 10 — Onboarding

| File | Status | Notes |
|------|--------|-------|
| `lib/features/onboarding/screens/onboarding_screen.dart` | ❌ Not created | — |

---

## Phase 11 — Platform Adaptations

| File | Status | Notes |
|------|--------|-------|
| `lib/shared/widgets/adaptive_layout.dart` | ❌ Not created | — |

### Current responsive features:
- Tab strip uses responsive margins (mobile: 20px, desktop >768px: 40px)
- `AppDimensions` has `marginMobile` (20px) and `marginDesktop` (40px) constants
- Reading content uses `AppDimensions.readingWidthMax` (680px max width)
- **No** NavigationRail for desktop yet
- **No** split-screen/tablet layout yet

---

## Phase 12 — Localisation

| File | Status | Notes |
|------|--------|-------|
| `lib/core/localization/l10n.dart` | ❌ Not created | — |
| `lib/core/localization/arb/*.arb` | ❌ Not created | — |

---

## Summary

### ✅ Fully Implemented
- Theme & design tokens (colors, dimensions, typography, theme)
- Database layer (EpitakaDatabase, TranslationDatabase with Drift)
- Library screen with book tree (expandable categories)
- Reader screen with Pāli + translation paragraphs
- Settings screen with typography settings
- Contents screen (table of contents)

### ✅ Recently Completed (June 2026)
- Multi-tab reader with tab strip (scrollable chips, close buttons, active/inactive states)
- Tab state management via Riverpod (open, close, switch, duplicate prevention)
- Swipe gesture on reading pane to switch tabs (horizontal drag with velocity threshold)
- Library & contents navigation updated to use tabs (add tab → navigate to reader)
- Responsive tab strip margins

### ❌ Still to Build
- Repository layer (BookRepository, TranslationRepository, DownloadRepository)
- Config files (AppConfig, supported languages, Pali scripts)
- Settings models (separate settings_model.dart)
- Search provider & search sheet
- TTS provider & TTS sheet
- Downloads provider & downloads screen
- Bottom sheets (contents, search, dictionary, TTS)
- Appearance settings screen (accent color, theme picker)
- Reading colors settings screen
- Reading options settings screen
- TTS settings screen
- Onboarding flow
- Desktop navigation rail & adaptive layout
- Localisation (flutter_localizations + ARB files)
- Tab persistence across app restarts
- Tab switch animation
- Pixel-accurate scroll-to-para on contents heading tap
