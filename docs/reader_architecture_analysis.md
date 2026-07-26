# Reader Architecture Analysis (epitaka-app)

> **⚠️ CAUTION (2026-07-26): `reader_screen.dart` has known structural issues.**  
> The file (~2400 lines) was damaged by a past refactoring where `_copySelectedContent`'s closing `}` was accidentally removed, nesting everything after it inside that method scope. This was later repaired but the file remains fragile.  
> **Before editing `reader_screen.dart`, check for:**
> - Forward-reference errors (local functions used before their declaration within the same scope). These are Dart's most common silent breakage in this file.
> - Nested scopes: `@override` annotations inside local functions (they become `invalid_annotation_target` warnings).
> - The class-level `build()` at the end of the file — if it throws `UnimplementedError`, the real build logic was trapped inside a wrong scope.
> - TTS state duplication between `_ReaderScreenState` fields and `ttsSyncProvider`. **Always let the provider be the single source of truth.**
> - `ReaderCopyService` is a static utility — prefer moving logic there rather than adding more fields to `_ReaderScreenState`.

## Overview

The reader is a multi-tab Pāli text reader with translations, TTS, search, bookmarking, word lookup, text copying/sharing, and navigation features. It's built with `ScrollablePositionedList` for paragraph-level scrolling, `SelectionArea` for text selection, and raw `Listener` for pointer events (to avoid gesture arena conflicts).

---

## 1. High-Level File Structure

```
features/reader/
├── screens/
│   └── reader_screen.dart              ← MAIN (~2400 lines) — all logic lives here
├── providers/
│   ├── reader_provider.dart             ← ReaderDataNotifier (loads book data)
│   ├── reader_tabs_provider.dart        ← ReaderTabsNotifier (manages open tabs)
│   ├── tts_reading_provider.dart        ← TtsReadingNotifier (TTS playback)
│   ├── reader_tts_sync_provider.dart    ← TtsSyncNotifier (auto-scroll sync)
│   └── reader_jump_controller.dart     ← ReaderJumpController (jump service)
├── services/
│   ├── reader_copy_service.dart         ← Copy/share logic (extracted from screen)
│   ├── jump_service.dart                ← Connected book / page jump logic
│   └── book_link_service.dart           ← Book links (mula/attha/tika cross-refs)
├── widgets/
│   ├── reader_content_list.dart         ← ScrollablePositionedList builder
│   ├── reader_content_with_selection.dart ← Listener + SelectionArea wrapper
│   ├── reader_in_book_search_bar.dart   ← In-book search bar UI
│   ├── reader_app_bar.dart              ← Collapsible app bar
│   ├── reader_bottom_toolbar.dart       ← Floating action toolbar
│   ├── reader_tts_widgets.dart          ← TTS floating chip & controls card
│   ├── reader_drag_thumb.dart           ← Draggable scroll thumb
│   ├── tab_strip.dart                   ← Tab strip with reorder
│   ├── jump_sheet.dart                  ← Jump-to-connected-book / page sheet
│   ├── bookmark_dialog.dart             ← Bookmark save dialog
│   ├── reader_context_menu.dart         ← Context menu buttons
│   └── book_link_chip.dart              ← Inline book-link chips
├── utils/
│   └── reader_quote_utils.dart          ← Citation template builder
└── data/
    ├── book_link_data.dart              ← Book link data types
    └── book_link_section_sheet.dart     ← Book link section display sheet

shared/widgets/
    └── reading_paragraph.dart           ← Individual paragraph rendering

core/utils/
    ├── pali_script_converter.dart       ← Script conversion (Roman↔Sinhala↔Thai etc.)
    ├── pali_text_utils.dart             ← convertPaliToScript, search query conversion, caching
    ├── pali_search_utils.dart           ← cleanPaliForIndexing, normalizePaliFuzzy
    └── platform_info.dart               ← Platform detection
```

---

## 2. Data Flow: Book Loading

### 2.1 Entry Point
1. User opens a book from Search, Library, History, or Deep Link
2. `deep_link_service.dart` or `library_screen.dart` calls `readerTabsProvider.notifier.openTab(ReaderTabInfo(bookId, bookName, initialParaId?))`
3. Router navigates to `/reader` which builds `ReaderScreen`

### 2.2 Tab Creation (`reader_tabs_provider.dart`)
- `ReaderTabsNotifier` maintains a list of `ReaderTabInfo` tabs + active index
- `openTab()` checks if book is already open → switches to it, otherwise adds new tab
- Each tab stores: `bookId`, `bookName`, `initialParaId`/`initialLineId` (for jump from search), `searchQuery`, `scrollOffset` (fractional), `currentParaId`/`currentLineId`

### 2.3 Book Data Loading (`reader_provider.dart` — `ReaderDataNotifier`)
When `ReaderDataNotifier` is created (per bookId via `.family` provider):

1. **Load headings** — queries `headings` table for bookId, level < 10
2. **Load book info** — `books` table (name, description)
3. **Load paragraph IDs** — `SELECT DISTINCT para_id FROM sentences WHERE book_id = ?`
4. **Load ALL sentences** — `SELECT * FROM sentences WHERE book_id = ? ORDER BY para_id, line_id`
5. **Group into paraId→lines** with page numbers (vri, pts, thai, my)
6. **Load translations in parallel** — for each enabled language:
   - If nissaya: loads from nissaya database
   - Otherwise: loads from standard translation DB (`SELECT * FROM translationSentences WHERE book_id = ?`)
7. **Build ParagraphData objects** — merge Pāli lines with translations, assign headings, page numbers
8. **Load book links** — `book_links` table (mula/attha/tika cross-references)

**Key characteristics:**
- Loads EVERYTHING upfront (no pagination) — entire book in RAM
- Listens to settings changes (translation version, enabled languages) → full reload
- Uses generation counter to discard stale async results
- Headings are cached and re-used across reloads (until changed)

**Performance concern:** For large books (e.g., whole Vinaya Pitaka), loading all paragraphs + all translations can take several seconds and use significant memory.

---

## 3. Data Flow: Reader Display (`reader_screen.dart`)

### 3.1 Build Method (Simplified)
```
ReaderScreen.build()
  ├── Column
  │   ├── Padding(top safe area)
  │   ├── ReaderAppBar (collapsible, AnimatedSize)
  │   ├── TabStrip (scrollable tab chips)
  │   ├── ReaderInBookSearchBar (if _showInBookSearch)
  │   ├── Expanded
  │   │   └── Stack
  │   │       ├── ReaderContentWithSelection (for active tab)
  │   │       │   ├── Listener (raw pointer events)
  │   │       │   │   └── AnimatedBuilder (Transform.translate for swipe)
  │   │       │   │       └── KeyedSubtree
  │   │       │   │           └── ReaderContentList
  │   │       │   │               └── ScrollablePositionedList.builder
  │   │       │   │                   └── ReadingParagraph (per item)
  │   │       │   └── SelectionArea
    │   │       ├── ReaderDragThumb (right-edge scroll thumb)
  │   │       └── TTS widgets (floating chip, controls card)
  │   ├── ReaderBottomToolbar (floating, bottom-center)
  │   └── KeyboardShortcuts (desktop)
```

### 3.2 Paragraph Rendering (`reading_paragraph.dart`)

Each `ReadingParagraph` renders:
1. **Book title** (only first paragraph) — `PaliTextStatic`
2. **Heading** (if paragraph.heading != null) — styled by level
3. **Page badge** (isPageStart) — e.g., "VRI p. 123"
4. **Content** with three display modes:
   - **lineByLine** (default): Each Pāli line + its translations stacked vertically
   - **sideBySide**: Pāli left column, translations right column (divider between)
   - **hideJoinLines** (Pāli only): All lines joined into one block
5. **Book link chips** (inter-paragraph cross-references)

**Search highlighting** in Pāli text:
- Converts query to target script via `convertSearchQueryForScript()`
- Finds all matching intervals using diacritic-normalized matching (`_normChar`)
- Wraps matches in highlighted `TextSpan` with background color + bold

**HTML parsing**: Translation text may contain `<b>`, `<i>`, `<u>`, `<h1-6>`, `<br>` tags — parsed into `InlineSpan`s with a 500-entry LRU cache.

---

## 4. Tab Swipe System (Gesture Handling)

### 4.1 Architecture
The reader uses a **raw `Listener`** (not a `GestureDetector`) to avoid competing with `SelectionArea`'s gesture recognizers.

**Flow:**
1. `_handlePointerDown`: Records tap position & time for double-tap detection + swipe start
2. `_handlePointerMoveForTabSwipe`:
   - Detects horizontal drag (primary direction horizontal, past 10px threshold)
   - Updates `_dragDxNotifier` → `Transform.translate` moves content
   - Also handles selection auto-scroll when text is selected
3. `_handlePointerUpForTabSwipe` / `_handlePointerCancelForTabSwipe`: Completes swipe
4. `_onDragEnd`: Commits or cancels based on threshold (30% width or 600px/s velocity)
5. `_animateSettle`: Two-phase animation — current tab slides out, target tab slides in

### 4.2 Double-Tap Word Lookup
- `_handlePointerDown` detects double-tap (400ms window, 40px slop)
- `_selectWordAt` does hit-test against `_contentHitTestKey` render object
- Walks the `BoxHitTestResult` path to find `RenderParagraph`
- Extracts word boundary via `RenderParagraph.getWordBoundary()`
- Converts non-Roman script back to Roman via `_convertToRomanIfNeeded()`
- Cleans Pāli diacritics via `_cleanPali()` (strips all non-Pali chars)
- Opens dictionary sheet or routes to side panel

---

## 5. Text Selection & Copy

### 5.1 Framework Selection
Uses Flutter's native `SelectionArea` wrapping the reader content. On selection change:
- `_handleSelectionChanged` caches `SelectedContent` in `_lastSelectedContent`
- Context menu (long-press) uses `ReaderCopyService.buildContextMenu()`

### 5.2 Context Menu Actions (via `reader_copy_service.dart`)
1. **Copy Plain Text** — just the selected plain text
2. **Copy with Style** — formatted HTML with Pāli + translations + colors
3. **Pāli Only** — only Pāli text
4. **Translation Only** — only translation text
5. **Copy with Quote** — formatted + citation (from template)
6. **Share** — system share sheet
7. **Share Link** — deep link to current position
8. **Select All** — `selectableRegionState.selectAll()`


### 5.3 Visible Content Copy (Fallback)
When there's no selected text (or when the selection is empty), the copy/context-menu actions fall back to copying the **visible range** of paragraphs (`visibleStartIndex` → `visibleEndIndex`). This is handled by `_copyVisibleContent()` in `reader_copy_service.dart`, which:
- Extracts the sublist of visible `ParagraphData` objects
- Passes them to `ReadingClipboard.copyWithTemplate()` for formatted output (HTML with colors, per-scope filtering)
- Supports citation templates via `buildCitationFromTemplate`

**Note:** The old `_findSelectedParagraphs()` (concat ALL paragraphs → find selected text → map back) was **removed** (2026-07-26). Copy now always uses the visible range as fallback. If you need paragraph-level copy, `SelectionArea`'s framework handles it natively.

---

## 6. In-Book Search

### 6.1 Flow
1. User taps Search on bottom toolbar → `_toggleInBookSearch()` shows search bar
2. User types query → `_runInBookSearch()` called after debounce
3. Searches **Pāli text** in `epitaka.db.sentences` using `LIKE '%word%'` for each term (AND)
4. Additionally searches **each enabled translation DB** with the same pattern
5. Returns `(para_id, line_id)` pairs → jumps to first match
6. Navigation buttons cycle through `_inBookMatchIndex`

### 6.2 Issues
- **No diacritic-insensitive search at DB level**: `LIKE '%dhamma%'` won't match "dhammaṃ" or "dhammā"
- **Only substring matching**: Uses `%` wildcard — no fuzzy/diacritic normalization in SQL
- **Highlighting uses diacritic normalization** (`_normChar` in `ReadingParagraph`) but search results come from DB which is case-sensitive exact match
- **Multiple DB queries** (one per language) — serialized, not parallel
- **`LIKE '%...%'` is costly**: No index can be used for leading-wildcard LIKE. With LIMIT 500 this is bounded but still does full table scans

### 6.3 Optimization Idea
The user mentioned: "when a text is highlighted, it has already removed the pali signs and compare." 
- The `_normChar` mechanism in `ReadingParagraph._highlightInText()` normalizes diacritics at render time
- But the DB search uses raw `LIKE` which doesn't normalize
- **Solution**: Cache a normalized version of the text (or use FTS5 with a custom tokenizer) for in-book search. The query could normalize input terms before searching.

---

## 7. TTS (Text-to-Speech)

### 7.1 Architecture
- **`tts_reading_provider.dart`**: `TtsReadingNotifier` — manages reading state (bookId, lines list, current index, active/paused)
- **`tts_provider.dart`** (settings): Low-level TTS engine wrapper (flutter_tts)
- **`reader_tts_sync_provider.dart`**: TTS auto-scroll sync per book tab
- **`reader_tts_widgets.dart`**: TTS floating chip + controls card UI
- **`settings/services/tts_audio_handler.dart`**: `AudioHandler` for lock-screen/media notifications

### 7.2 Flow
1. User taps Listen → `_handleListenTap` builds `TtsLineItem[]` from visible paragraphs or selected range
2. `ttsReadingProvider.notifier.startReading(bookId, lines)` called
3. Speaking loop: `_speakCurrent()` → speak line → `_advanceToNext()` → next line
4. Prefetching: `_prefetchNext()` synthesizes next line while current plays
5. Auto-scroll: `_onPositionsChanged` checks if TTS line is visible → if not, `_ttsAutoScroll = false`
6. `ttsReadingProvider` listener in `ReaderScreen` triggers `_jumpToParagraph` for auto-scroll

### 7.3 TTS Auto-Scroll Sync
- `TtsSyncNotifier` manages per-book: `ttsAutoScroll`, `ttsJumpInProgress`, `ttsTargetParaId`
- When TTS advances, `_jumpToParagraph()` → creates `GlobalKey` for target line → `Scrollable.ensureVisible()`
- **Complex state machine**: `_ttsJumpInProgress`, `_ttsAutoScroll`, `_ttsJumpTimer`, `_suppressAppBarScroll` all coordinate to prevent conflicts
- **Issue**: This is duplicated in both `reader_screen.dart` (`_ttsJumpInProgress`, `_ttsAutoScroll`, etc.) AND `reader_tts_sync_provider.dart` (`TtsSyncState`)
- Both systems track similar state but don't communicate → potential for inconsistency

---

## 8. Bookmarking & History

### 8.1 Bookmark
- `_onBookmarkTap()` → `showBookmarkDialog()`
- Finds nearby heading to suggest bookmark name
- Saves to `appDb.bookmarks` via `app_db_provider`

### 8.2 Reading History
- `_onPositionsChanged()` → `_scheduleSaveHistory()` → after 3s debounce → `_saveReadingHistory()`
- Saves to `appDb.readingHistory` via `recordReading()`
- Throttled: only saves when paraId changes (per book)

---

## 9. Jumping & Navigation

### 9.1 Unified Jump System (`_jumpToParagraph`)
Called from many places with the same core logic:
- TTS auto-scroll
- In-book search result
- Tab position restoration
- Jump-to-connected-book (from `jump_sheet.dart`)
- TOC/contents jump
- Deep link from search result

**Flow:**
1. Set `_suppressAppBarScroll = true`
2. Look up paragraph index in loaded `paragraphs` list
3. If data not loaded, wait via `waitUntilLoaded()`
4. Retry if `ItemScrollController` not attached (up to 30 frames)
5. Create `GlobalKey` for target line (for `Scrollable.ensureVisible`)
6. `controller.scrollTo()` or `controller.jumpTo()` with alignment
7. Optional fine-scroll to specific line via `_scrollToLine()` → `Scrollable.ensureVisible()`
8. Clear `initialParaId`, `_isInitialJumpPending`, `_suppressAppBarScroll`

### 9.2 Connected Book Jump (`jump_sheet.dart` + `jump_service.dart`)
- Shows two tabs: Connected Books + Page Jump
- Connected Books: Finds mula/attha/tika references via `book_links` table
- Matches by section number (level=10 headings) between books
- Page Jump: Finds paraId by page number string (VRI, PTS, Thai, Myanmar)

### 9.3 Drag Thumb (`reader_drag_thumb.dart`)
- Quick scroll via dragging a narrow pill on the right edge
- Converts drag position → scroll ratio → paragraph index
- `ItemScrollController.jumpTo()` for real-time following

---

## 10. Scroll Tracking & Collapsible App Bar

### 10.1 Position Tracking
- `_onPositionsChanged()` (via `ItemPositionsListener`): Fires on every layout change
- Tracks fractional offset: `topmostVisibleIndex + itemLeadingEdge`
- Updates `readerTabsProvider` scrollOffset (gated on paraId change)
- Maintains `_preciseScrollOffset` (every frame, for restoration)

### 10.2 App Bar Collapse
- Pixel-accurate scroll direction tracking via `ScrollOffsetListener.changes`
- Accumulates scroll delta in one direction; after 20px threshold, collapses/expands
- Suppressed during programmatic jumps (`_suppressAppBarScroll`, `_isInitialJumpPending`)
- Force-expands when at top of document

### 10.3 Tab Position Restoration
When switching tabs, the incoming tab's reader content gets:
- `initialParaId` from tab state
- But also checks `scrollOffset` for precise fractional position
- The build method converts fractional offset → alignment for `_jumpToParagraph`

---

## 11. Selection Auto-Scroll

When dragging selection handles:
1. `_handlePointerMoveForTabSwipe` detects active selection (`_lastSelectedContent != null`)
2. `_checkAutoScrollEdge` checks pointer proximity to viewport edges (50px threshold)
3. Speed increases as pointer approaches edge (0.5x to 1.0x of 3px/16ms)
4. Uses persistent `Timer.periodic` (not recreated on every move) to avoid flicker
5. Drives `ScrollOffsetController.animateScroll()` (not available via ItemScrollController)

**Why custom**: Flutter's built-in `SelectionArea` auto-scroll can't drive `ScrollablePositionedList` because the `SelectableRegion` is outside the list's internal `Scrollable`.

---

## 12. Script Conversion System

### 12.1 Architecture (`pali_script_converter.dart`)
- 17 scripts supported (Sinhala, Devanagari, Roman, Thai, Laos, Myanmar, Khmer, etc.)
- Three character tables: `specials` (vowels, signs, digits), `consos` (consonants), `vowels` (dependent vowel signs)
- Sinhala is the **internal intermediate format**: Roman → Sinhala → Target Script
- Conversion uses hash maps prepared from character tables, cached per (from, to, useVowels) triple

### 12.2 Caching (`pali_text_utils.dart`)
- `_convertCache`: 8000-entry LRU cache for `convertPaliToScript()` results
- Also caches intermediate Sinhala conversion (Roman → Sinhala) independently of target
- `_htmlParseCache`: 500-entry LRU for HTML tag parsing in translation text
- `_hashMapCache`: Static cache for script conversion hash maps

### 12.3 Where Conversion Happens
- **Per paragraph in reader**: `ReadingParagraph._buildPaliLine()` → `convertPaliToScriptPreservingHtml()`
- **Per search query**: `convertSearchQueryForScript()` → converts query terms to match displayed script
- **Per word lookup**: `_convertToRomanIfNeeded()` → converts non-Roman Pāli back to Roman for dictionary
- **Per search result**: In search screen widgets

---

## 13. Identified Redundancies & Issues

### 13.1 TTS State Duplication
- `_readerScreenState` has its own `_ttsAutoScroll`, `_ttsJumpInProgress`, `_ttsTargetLineKeys`, `_ttsTargetParaId`, `_ttsJumpTimer`
- `ttsSyncProvider` has the same concepts: `ttsAutoScroll`, `ttsJumpInProgress`, `ttsTargetParaId` with a timer
- These two state systems don't communicate and can get out of sync

### 13.2 Selection — Resolved (2026-07-26)
- ~~`ReaderSelectionOverlay`~~ was **removed** — `SelectionArea` is now the sole selection mechanism
- The custom paragraph-level selection system (`reader_selection_overlay.dart`, `ReaderSelectionToolbar`, `_SelectionHighlightPainter`) was deleted
- `_findSelectedParagraphs()` was also removed — copy fallback now uses the visible range instead of re-processing the entire book

### 13.3 In-Book Search Inefficiency
- DB query uses `LIKE '%term%'` — no index usage, full table scan per term
- No diacritic normalization at query time (but has it at highlight time via `_normChar`)
- Query runs against **each enabled translation DB** sequentially (not parallel).
- Results may miss matches that differ only in diacritics (e.g., searching "dhamma" won't find "dhammā")

### 13.4 Copy Service — Resolved (2026-07-26)
- ~~`_findSelectedParagraphs()`~~ was **removed** — no more O(n) full-book text reprocessing on copy
- Copy now uses the visible paragraph range (`visibleStartIndex`–`visibleEndIndex`) as fallback
- The `_copyVisibleContent()` method handles this via `ReadingClipboard.copyWithTemplate()`

### 13.5 Jump Controller Duplication
- `reader_jump_controller.dart` has its own `ReaderJumpController` class
- But `_ReaderScreenState` has the SAME logic in `_jumpToParagraph()`, `_scrollToLine()`
- Both manage `lastJumpedParaId`, `_pendingJumpParaId`, retry with `_maxRetries`
- They overlap in functionality but the screen's methods seem more complete (used in practice)

### 13.6 Heavy `_ReaderScreenState`
- ~70+ instance variables tracking state
- Mixes concerns: scroll tracking, app bar collapse, TTS sync, in-book search, word lookup, copy, bookmark, tab management, swipe animation, auto-scroll
- Extremely hard to refactor because so many fields interact

### 13.7 Repeated Visible Item Sorting
```
final visible = positions.where((p) => p.itemTrailingEdge > 0).toList()
  ..sort((a, b) => a.itemLeadingEdge.compareTo(b.itemLeadingEdge));
```
This pattern appears in at least 5 places (`_onPositionsChanged`, `_onScrollOffsetChanged`, `_getCurrentParaId`, `_updateScrollRatio`, etc.)

### 13.8 Book Data Loads Everything
- ALL paragraphs + ALL translations loaded upfront into memory
- For large books, this can be hundreds of thousands of lines
- No pagination, no lazy loading
- Full reload on every settings change (translation version, enabled languages)

---

## 14. Optimization Suggestions

### 14.1 Extract TTS State to Provider Exclusively
- Remove `_ttsAutoScroll`, `_ttsJumpInProgress`, `_ttsJumpTimer`, `_ttsTargetLineKeys`, `_ttsTargetParaId` from `_ReaderScreenState`
- Let `ttsSyncProvider` be the single source of truth for TTS sync state
- The screen should react to provider changes, not duplicate them

### 14.2 Unify Jump Logic
- Remove `reader_jump_controller.dart` (or make it the sole implementation)
- Delegate all jumps from `_ReaderScreenState` to a single service
- Extract the complex jump/scroll coordination into a dedicated service

### 14.3 Selection — Done (2026-07-26)
- `ReaderSelectionOverlay` was removed. `SelectionArea` is the sole selection mechanism.
- `_findSelectedParagraphs()` was removed — copy fallback uses visible range.

### 14.4 Cache Diacritic-Normalized Text for In-Book Search
- Pre-compute a normalized version of all paragraph text at load time
- The normalized text can be stored in a `Map<int, String>` (paraId → normalized)
- Search queries are also normalized → simple substring match in the cache
- Avoids re-normalizing on every keystroke and avoids SQL `LIKE` limitations

### 14.5 Parallelize In-Book Search Queries
- Use `Future.wait` to query Pāli DB + all translation DBs simultaneously

### 14.6 Split `_ReaderScreenState` Into Smaller Units
- Create focused controllers/services for:
  - `ScrollStateController` — scroll tracking, app bar collapse, position persistence
  - `SwipeController` — tab swipe animation
  - `PointerEventHandler` — double-tap, swipe gesture, auto-scroll
  - `TtsSyncController` — TTS auto-scroll coordination
  - `InBookSearchController` — search state and query execution
- Each controller manages its own state, reducing the monolithic state class

### 14.7 Use FTS5 for In-Book Search
- The `sentences` table could have an FTS5 virtual table for diacritic-insensitive full-text search
- This would be much faster than `LIKE '%term%'` and could use FTS5's prefix matching

### 14.8 Lazy Load Paragraphs (Virtual Scroll)
- Instead of loading all paragraphs, load pages of ~200 paragraphs
- `ScrollablePositionedList` supports dynamic item count
- But: this conflicts with the drag thumb (needs total count) and jump-to-paragraph (needs full index)
- A hybrid approach: load metadata (paraIds, headings) upfront, lazy-load line-by-line text

---

## 15. Flow Diagrams

### 15.1 Opening a Book
```
DeepLink / Search / Library / History
  │
  ▼
readerTabsProvider.notifier.openTab(bookId, initialParaId?)
  │
  ▼
Router → /reader → ReaderScreen.build()
  │
  ├── Creates ReaderDataNotifier(bookId)
  │     ├── loadHeadings()
  │     ├── loadAllParagraphs() ← all sentences + translations in parallel
  │     └── loadBookLinks()
  │
  ├── Creates ItemScrollController, ItemPositionsListener
  │
  ├── Renders ScrollablePositionedList
  │     └── ReadingParagraph per item
  │
  └── If initialParaId ≠ null → _jumpToParagraph() after first frame
```

### 15.2 In-Book Search
```
User types query
  │
  ▼
_onQueryChanged() → debounce (Timer 300ms)
  │
  ▼
_runInBookSearch(query)
  │
  ├── 1. Search epitaka.db.sentences: SELECT para_id, line_id WHERE book_id=? AND pali LIKE '%term1%' AND pali LIKE '%term2%' ... LIMIT 500
  │
  ├── [guard: _lastInBookSearchQuery still == query?]
  │
  ├── 2. For each enabled translation language:
  │     └── Search translation.db.sentences: LIKE on translation column
  │
  ├── [guard: _lastInBookSearchQuery still == query?]
  │
  ├── setState with match results
  │
  └── _jumpToInBookMatch(0) → _jumpToParagraph() → scrollTo + fine-scroll
```

### 15.3 TTS Reading
```
User taps Listen on toolbar
  │
  ▼
_handleListenTap(bookId, readerState)
  │
  ├── Build TtsLineItem[] from paragraphs
  │
  ├── ttsReadingProvider.notifier.startReading(bookId, lines)
  │     ├── Stop any current TTS
  │     ├── Set up AudioHandler + notification
  │     ├── Android: force enable media buttons
  │     ├── Listen for becoming-noisy (Bluetooth disconnect)
  │     └── _speakCurrent(sessionId)
  │           ├── Prefetch next line
  │           ├── Speak current line (or play prepared audio)
  │           └── _advanceToNext(sessionId)
  │
  └── ref.listen(ttsReadingProvider) → detects paraId change
        │
        ▼
        _jumpToParagraph(bookId, TTS paraId, lineId: TTS lineId)
          │
          ├── Create GlobalKey for target line
          ├── scrollTo(alignment: 0.0) → paragraph at top
          └── _scrollToLine() → Scrollable.ensureVisible(alignment: 0.3)
```

### 15.4 Tab Swipe
```
User drags left/right on reader content
  │
  ▼
_handlePointerDown → records swipeStartPos
  │
  ▼
_handlePointerMoveForTabSwipe
  │
  ├── If primarily horizontal + past threshold
  │     → _onDragStart → _isDragging = true
  │     → _onDragUpdate → _dragDxNotifier.value = offset
  │     → Transform.translate moves content in real-time
  │
  ▼
_handlePointerUpForTabSwipe
  │
  ▼
_finishTabSwipe → _onDragEnd
  │
  ├── If committed (offset > 30% width OR velocity > 600px/s)
  │     → Phase 1: animate current tab fully off-screen
  │     → Switch tab in provider
  │     → Phase 2: new tab slides in from opposite edge
  │
  └── If cancelled
        → _animateSettle to offset = 0 (snap back)
```
