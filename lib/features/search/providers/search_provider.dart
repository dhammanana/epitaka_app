import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/epitaka_database.dart';
import '../../../core/models/app_models.dart';
import '../../../core/providers/app_db_provider.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/pali_search_utils.dart';
import '../../indexing/index_controller.dart';

// ── Constants ───────────────────────────────────────────────────────────

/// Items per page when paginating within a book.
const int kSearchPageSize = 30;

/// If total results across all books exceeds this, collapse all books.
const int kCollapseThreshold = 30;

// ── Filter constants ─────────────────────────────────────────────────────

/// Category (layer) filter keys.
const Set<String> kAllCategories = {'mūla', 'aṭṭha', 'ṭīkā', 'aññā'};

/// Nikaya (pitaka) filter keys.
const Set<String> kAllNikayas = {'sutta', 'vinaya', 'abhidhamma', 'aññā'};

// ── Model types ─────────────────────────────────────────────────────────

/// A heading match from the search.
class HeadingResult {
  final String bookId;
  final int paraId;
  final String title;
  final int? level;
  final String? bookName;

  const HeadingResult({
    required this.bookId,
    required this.paraId,
    required this.title,
    this.level,
    this.bookName,
  });
}

/// A single line within a search result paragraph.
class SearchResultLine {
  final int lineId;
  final String pali;
  final String? translation;
  final bool isMatch;

  const SearchResultLine({
    required this.lineId,
    required this.pali,
    this.translation,
    this.isMatch = false,
  });
}

/// A single search result item representing one matching paragraph,
/// with its individual lines.
class SearchResultItem {
  final String bookId;
  final int paraId;

  /// Individual lines within this paragraph.
  final List<SearchResultLine> lines;

  /// FTS5 snippet for Pāli matches (<mark> tags already embedded).
  final String? paliSnippet;

  /// When true (AI-found results), show every line even if none matches the
  /// original query terms — the whole passage is relevant.
  final bool showAllLines;

  /// Convenience: get the full paragraph Pāli text (joined lines).
  String get paliText => lines.map((l) => l.pali).join(' ');

  /// Convenience: get the full translation text (joined lines).
  String? get translation {
    final nonNull = lines
        .map((l) => l.translation)
        .where((t) => t != null && t.isNotEmpty)
        .toList();
    if (nonNull.isEmpty) return null;
    return nonNull.join(' ');
  }

  const SearchResultItem({
    required this.bookId,
    required this.paraId,
    required this.lines,
    this.paliSnippet,
    this.showAllLines = false,
  });
}

/// Book-level summary from the initial count-only phase.
class BookResultSummary {
  final BookInfo book;
  final int totalCount;
  bool isExpanded;

  /// Pages of loaded results (each page is `kSearchPageSize` items max).
  final List<List<SearchResultItem>> loadedPages;

  /// When true (AI-found results), treat the book as fully loaded so no
  /// "load more" button appears — the AI already selected every passage.
  final bool forceFullyLoaded;

  /// Whether we've loaded all available results for this book.
  bool get fullyLoaded =>
      forceFullyLoaded ||
      loadedPages.length * kSearchPageSize >= totalCount;

  int get loadedCount =>
      loadedPages.fold(0, (sum, page) => sum + page.length);

  BookResultSummary({
    required this.book,
    required this.totalCount,
    this.isExpanded = false,
    List<List<SearchResultItem>>? loadedPages,
    this.forceFullyLoaded = false,
  }) : loadedPages = loadedPages ?? [];
}

// ── Search state ─────────────────────────────────────────────────────────

sealed class SearchState {
  const SearchState();
}

class SearchIdle extends SearchState {
  const SearchIdle();
}

class SearchIndexing extends SearchState {
  final double progress;
  final String status;
  const SearchIndexing({this.progress = 0, this.status = 'Building search index…'});
}

class SearchLoading extends SearchState {
  const SearchLoading();
}

/// Results from the initial count-only pass.
class SearchResults extends SearchState {
  final String query;
  final int totalResults;
  final int distance;

  /// Current filter state.
  final Set<String> enabledCategories;
  final Set<String> enabledNikayas;

  /// Per-book summaries.
  final List<BookResultSummary> bookSummaries;

  /// Heading matches found in the headings table.
  final List<HeadingResult> headings;

  const SearchResults({
    required this.query,
    required this.totalResults,
    required this.bookSummaries,
    this.headings = const [],
    this.distance = 0,
    this.enabledCategories = kAllCategories,
    this.enabledNikayas = kAllNikayas,
  });
}

class SearchError extends SearchState {
  final String message;
  const SearchError(this.message);
}

// ── Provider ─────────────────────────────────────────────────────────────

final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref);
});

class SearchNotifier extends StateNotifier<SearchState> {
  final Ref _ref;
  Timer? _debounce;
  EpitakaDatabase? _cachedEpitakaDb;
  List<BookInfo>? _cachedAllBooks;

  /// Filter state: which categories (layers) are enabled.
  Set<String> _enabledCategories = {...kAllCategories};

  /// Filter state: which nikayas (pitakas) are enabled.
  Set<String> _enabledNikayas = {...kAllNikayas};

  SearchNotifier(this._ref) : super(const SearchIdle());

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Public getters for current filter state.
  Set<String> get enabledCategories => _enabledCategories;
  Set<String> get enabledNikayas => _enabledNikayas;

  // ── Lazy caches ────────────────────────────────────────────────────────

  Future<EpitakaDatabase> _epitakaDb() async {
    _cachedEpitakaDb ??= await _ref.read(epitakaDbProvider.future);
    return _cachedEpitakaDb!;
  }

  Future<List<BookInfo>> _allBooks() async {
    if (_cachedAllBooks == null) {
      final db = await _epitakaDb();
      final rows = await db.select(db.books).get();
      _cachedAllBooks = rows
          .map((b) => BookInfo(
                id: b.id,
                refId: b.refId,
                vriId: b.vriId,
                bookId: b.bookId,
                category: b.category,
                nikaya: b.nikaya,
                subNikaya: b.subNikaya,
                bookName: b.bookName,
                description: b.description,
                mulaRef: b.mulaRef,
                atthaRef: b.atthaRef,
                tikaRef: b.tikaRef,
                paraId: b.paraId,
                chapterLen: b.chapterLen,
              ))
          .toList();
    }
    return _cachedAllBooks!;
  }

  /// Resolve the active translation language code (first enabled).
  String? _activeTranslationLang() {
    final settings = _ref.read(settingsProvider);
    return settings.enabledTranslations.isNotEmpty
        ? settings.enabledTranslations.first
        : (settings.showTranslation ? settings.primaryTranslationLang : null);
  }

  // ── Filter helpers ─────────────────────────────────────────────────────

  /// Map a book's category value to a filter key.
  String? _categoryFilterKey(BookInfo book) {
    switch (book.category) {
      case 'Mūla':
        return 'mūla';
      case 'Aṭṭhakathā':
        return 'aṭṭha';
      case 'Ṭīkā':
        return 'ṭīkā';
      default:
        return 'aññā';
    }
  }

  /// Map a book's nikaya/category to a filter key.
  String? _nikayaFilterKey(BookInfo book) {
    if (book.category == 'Añña') return 'aññā';
    final nikaya = book.nikaya ?? '';
    if (nikaya.contains('Vinaya')) return 'vinaya';
    if (nikaya.contains('Sutta')) return 'sutta';
    if (nikaya.contains('Abhidhamma')) return 'abhidhamma';
    return 'aññā';
  }

  /// Check whether a book passes the current filters.
  bool _bookPassesFilters(BookInfo book) {
    final catKey = _categoryFilterKey(book);
    if (catKey != null && !_enabledCategories.contains(catKey)) return false;

    final nikKey = _nikayaFilterKey(book);
    if (nikKey != null && !_enabledNikayas.contains(nikKey)) return false;

    return true;
  }

  /// Toggle a category filter on/off and re-search.
  Future<void> toggleCategory(String key) async {
    if (_enabledCategories.contains(key)) {
      if (_enabledCategories.length > 1) {
        _enabledCategories = {..._enabledCategories}..remove(key);
      }
    } else {
      _enabledCategories = {..._enabledCategories, key};
    }
    await _reSearch();
  }

  /// Toggle a nikaya filter on/off and re-search.
  Future<void> toggleNikaya(String key) async {
    if (_enabledNikayas.contains(key)) {
      if (_enabledNikayas.length > 1) {
        _enabledNikayas = {..._enabledNikayas}..remove(key);
      }
    } else {
      _enabledNikayas = {..._enabledNikayas, key};
    }
    await _reSearch();
  }

  /// Re-search with the current query (if any) and updated filters.
  Future<void> _reSearch() async {
    final current = state;
    if (current is SearchResults) {
      await search(
        query: current.query,
        distance: current.distance,
      );
    }
  }

  // ── Index initialization ──────────────────────────────────────────────

  /// Initialize the search index if not already built.
  Future<void> ensureIndexBuilt() async {
    final appDb = await _ref.read(appDbProvider.future);
    final paliBuilt = await appDb.isSearchIndexBuilt();
    if (!paliBuilt) {
      try {
        await _ref.read(indexControllerProvider.notifier).retry();
      } catch (e) {
        debugPrint('[SEARCH] Index build FAILED: $e');
      }
    }
  }

  // ── Main search entry point ───────────────────────────────────────────

  /// Execute a search. First stage: count results per book.
  /// If total is small enough, also load the actual results.
  ///
  /// Search is always diacritic-insensitive (fuzzy): the FTS index is
  /// built with `remove_diacritics 1`, so the database layer normalizes
  /// the query the same way the index text was cleaned.
  Future<void> search({
    required String query,
    int distance = 0,
  }) async {
    final normalized = query.trim();
    // A query made only of punctuation (",", "…") has no searchable words
    // after cleaning — treat it like an empty query instead of running a
    // pointless (and, for headings, `LIKE '%%'`-matching) search.
    if (normalized.isEmpty || cleanPaliForIndexing(normalized).isEmpty) {
      state = const SearchIdle();
      return;
    }

    state = const SearchLoading();

    try {
      final appDb = await _ref.read(appDbProvider.future);

      // Ensure Pali index is built
      final paliBuilt = await appDb.isSearchIndexBuilt();
      if (!paliBuilt) {
        await ensureIndexBuilt();
      }

      // ── Count results by book ──────────────────────────────────────
      final allBooks = await _allBooks();
      final bookMap = <String, BookInfo>{
        for (final b in allBooks) b.bookId: b,
      };

      final combinedCounts = <String, int>{};

      // Run both count queries in parallel
      final activeLang = _activeTranslationLang();
      final countFutures = <Future<Map<String, int>>>[
        () async {
          try {
            return await appDb.countPaliResultsByBook(
              normalized,
              distance: distance,
            );
          } catch (_) {
            return <String, int>{};
          }
        }(),
      ];
      if (activeLang != null) {
        countFutures.add(() async {
          try {
            return await appDb.countTranslationResultsByBook(
              activeLang,
              normalized,
              distance: distance,
            );
          } catch (_) {
            return <String, int>{};
          }
        }());
      }
      final countResults = await Future.wait(countFutures);
      for (final result in countResults) {
        for (final entry in result.entries) {
          combinedCounts[entry.key] =
              (combinedCounts[entry.key] ?? 0) + entry.value;
        }
      }

      // ── Search headings ───────────────────────────────────────────
      final epitakaDb = await _epitakaDb();
      final headingResults = await _searchHeadings(
        epitakaDb,
        normalized,
        bookMap,
      );

      if (combinedCounts.isEmpty && headingResults.isEmpty) {
        state = SearchResults(
          query: normalized,
          totalResults: 0,
          bookSummaries: [],
          headings: headingResults,
          distance: distance,
          enabledCategories: _enabledCategories,
          enabledNikayas: _enabledNikayas,
        );
        return;
      }

      // Build summaries sorted by book id
      final sortedBookIds = combinedCounts.keys.toList()
        ..sort((a, b) {
          final ba = bookMap[a];
          final bb = bookMap[b];
          return (ba?.id ?? 0).compareTo(bb?.id ?? 0);
        });

      // Apply filters — only include books that pass filter
      final filteredBookIds = sortedBookIds.where((id) {
        final book = bookMap[id];
        return book != null && _bookPassesFilters(book);
      }).toList();

      final totalResults = filteredBookIds.fold<int>(
        0,
        (sum, id) => sum + (combinedCounts[id] ?? 0),
      );
      final autoExpand = totalResults <= kCollapseThreshold;

      final summaries = <BookResultSummary>[];
      for (final bookId in filteredBookIds) {
        final book = bookMap[bookId] ??
            BookInfo(id: 0, bookId: bookId, bookName: bookId);
        summaries.add(BookResultSummary(
          book: book,
          totalCount: combinedCounts[bookId]!,
          isExpanded: autoExpand,
        ));
      }

      state = SearchResults(
        query: normalized,
        totalResults: totalResults,
        bookSummaries: summaries,
        headings: headingResults,
        distance: distance,
        enabledCategories: _enabledCategories,
        enabledNikayas: _enabledNikayas,
      );

      // If auto-expanded, load first page for every book
      if (autoExpand) {
        for (int i = 0; i < summaries.length; i++) {
          await _loadBookPage(i, fetchAll: true);
        }
      }
    } catch (e) {
      state = SearchError('Search failed: $e');
    }
  }

  // ── Load results for a specific book ──────────────────────────────────

  /// Load the next page(s) of results for the book at [summaryIndex].
  /// Fetches individual lines with translations for each matching paragraph.
  Future<void> _loadBookPage(int summaryIndex, {bool fetchAll = false}) async {
    final current = state;
    if (current is! SearchResults) return;

    if (summaryIndex < 0 || summaryIndex >= current.bookSummaries.length) return;

    final appDb = await _ref.read(appDbProvider.future);
    final activeLang = _activeTranslationLang();
    final query = current.query;
    final searchWords = normalizePaliFuzzy(query)
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    // Work with a mutable copy of the summaries so we can update incrementally.
    var summaries = [...current.bookSummaries];
    var summary = summaries[summaryIndex];

    if (summary.fullyLoaded) return;

    bool hasMore = true;
    while (hasMore) {
      final offset = summary.loadedPages.length * kSearchPageSize;
      final remaining = summary.totalCount - offset;
      if (remaining <= 0) break;

      final pageSize = remaining < kSearchPageSize ? remaining : kSearchPageSize;

      // Get matching para_ids from BOTH Pali and translation FTS
      final detailFutures = <Future<List<SearchResultRow>>>[
        appDb.searchPaliFtsByBook(
          summary.book.bookId,
          query,
          distance: current.distance,
          limit: pageSize,
          offset: offset,
        ),
      ];
      if (activeLang != null) {
        detailFutures.add(appDb.searchTranslationFtsByBook(
          activeLang,
          summary.book.bookId,
          query,
          distance: current.distance,
          limit: pageSize,
          offset: offset,
        ));
      } else {
        detailFutures.add(Future.value(<SearchResultRow>[]));
      }

      final detailResults = await Future.wait(detailFutures);
      final paliRows = detailResults[0];
      final transRows = detailResults.length > 1 ? detailResults[1] : <SearchResultRow>[];

      // Merge para_ids from both Pali and translation results
      final seenParaIds = <int>{};
      final allSnippets = <int, SearchResultRow>{};

      for (final row in paliRows) {
        if (row.firstParaId == null) continue;
        seenParaIds.add(row.firstParaId!);
        allSnippets[row.firstParaId!] = row;
      }
      for (final row in transRows) {
        if (row.firstParaId == null) continue;
        if (seenParaIds.add(row.firstParaId!)) {
          // Translation-only match — store snippet
          allSnippets[row.firstParaId!] = row;
        }
      }

      final matchingParaIds = seenParaIds.toList();
      if (matchingParaIds.isEmpty) break;

      // Fetch individual lines from epitaka_db.sentences for matching para_ids
      final placeholders = matchingParaIds.map((_) => '?').join(',');
      final epitakaDb = await _epitakaDb();
      final lineRows = await epitakaDb.customSelect(
        'SELECT para_id, line_id, pali '
        'FROM sentences '
        'WHERE book_id = ? AND para_id IN ($placeholders) '
        'ORDER BY para_id, line_id',
        variables: [
          Variable.withString(summary.book.bookId),
          ...matchingParaIds.map((id) => Variable.withInt(id)),
        ],
      ).get();

      // Fetch translations for those para_ids
      final transLineMap = <int, Map<int, String>>{};
      if (activeLang != null) {
        try {
          final transDb = await _ref.read(translationDbProvider(activeLang).future);
          if (transDb != null) {
            final tRows = await transDb.customSelect(
              'SELECT para_id, line_id, translation '
              'FROM sentences '
              'WHERE book_id = ? AND para_id IN ($placeholders) '
              'ORDER BY para_id, line_id',
              variables: [
                Variable.withString(summary.book.bookId),
                ...matchingParaIds.map((id) => Variable.withInt(id)),
              ],
            ).get();
            for (final row in tRows) {
              final pid = row.data['para_id'] as int;
              final lid = row.data['line_id'] as int;
              final t = row.data['translation'] as String?;
              if (t != null && t.isNotEmpty) {
                transLineMap.putIfAbsent(pid, () => {})[lid] = t;
              }
            }
          }
        } catch (_) {}
      }

      // Group lines by para_id and build SearchResultItems
      final paraLines = <int, List<SearchResultLine>>{};
      for (final row in lineRows) {
        final pid = row.data['para_id'] as int;
        final lid = row.data['line_id'] as int;
        final pali = (row.data['pali'] as String?) ?? '';
        final lineTranslations = transLineMap[pid] ?? {};
        final lineTrans = lineTranslations[lid];

        // Check if this line matches the search query (in Pali or translation).
        // Both the line text and search words must be normalized through
        // normalizePaliFuzzy so diacritics don't cause a mismatch — the
        // FTS index stores normalized text, but the sentences table stores
        // raw Pali with diacritics (ā, ṭ, ṃ, ḷ, etc.).
        final paliNormalized = normalizePaliFuzzy(pali);
        bool isMatch = searchWords.any((w) => paliNormalized.contains(w));
        if (!isMatch && lineTrans != null) {
          final transNormalized = normalizePaliFuzzy(lineTrans);
          isMatch = searchWords.any((w) => transNormalized.contains(w));
        }

        paraLines.putIfAbsent(pid, () => []).add(SearchResultLine(
          lineId: lid,
          pali: pali,
          translation: lineTrans,
          isMatch: isMatch,
        ));
      }

      // Build SearchResultItems — only include paras that had lines
      final items = <SearchResultItem>[];
      for (final pid in matchingParaIds) {
        final lines = paraLines[pid];
        if (lines == null || lines.isEmpty) continue;

        final snippet = allSnippets[pid];
        items.add(SearchResultItem(
          bookId: summary.book.bookId,
          paraId: pid,
          lines: lines,
          paliSnippet: snippet?.snippet.isNotEmpty == true ? snippet!.snippet : null,
        ));
      }

      // Build updated summary with new page appended
      final newLoadedPages = [...summary.loadedPages, items];
      final newSummary = BookResultSummary(
        book: summary.book,
        totalCount: summary.totalCount,
        isExpanded: true,
        loadedPages: newLoadedPages,
      );

      summaries[summaryIndex] = newSummary;
      summary = newSummary;

      state = SearchResults(
        query: current.query,
        totalResults: current.totalResults,
        bookSummaries: summaries,
        headings: current.headings,
        distance: current.distance,
        enabledCategories: _enabledCategories,
        enabledNikayas: _enabledNikayas,
      );

      if (!fetchAll) break;
      hasMore = !summary.fullyLoaded && items.length >= pageSize;
    }
  }

  /// Expand a book summary and load its first page of results.
  Future<void> expandBook(int summaryIndex) async {
    final current = state;
    if (current is! SearchResults) return;

    final summaries = [...current.bookSummaries];
    if (summaryIndex < 0 || summaryIndex >= summaries.length) return;

    final summary = summaries[summaryIndex];
    if (summary.isExpanded) return;

    summaries[summaryIndex] = BookResultSummary(
      book: summary.book,
      totalCount: summary.totalCount,
      isExpanded: true,
      loadedPages: summary.loadedPages,
      forceFullyLoaded: summary.forceFullyLoaded,
    );
    state = SearchResults(
      query: current.query,
      totalResults: current.totalResults,
      bookSummaries: summaries,
      headings: current.headings,
      distance: current.distance,
      enabledCategories: _enabledCategories,
      enabledNikayas: _enabledNikayas,
    );

    await _loadBookPage(summaryIndex);
  }

  /// Collapse a book summary.
  void collapseBook(int summaryIndex) {
    final current = state;
    if (current is! SearchResults) return;

    final summaries = [...current.bookSummaries];
    if (summaryIndex < 0 || summaryIndex >= summaries.length) return;

    final summary = summaries[summaryIndex];
    summaries[summaryIndex] = BookResultSummary(
      book: summary.book,
      totalCount: summary.totalCount,
      isExpanded: false,
      forceFullyLoaded: summary.forceFullyLoaded,
    );
    state = SearchResults(
      query: current.query,
      totalResults: current.totalResults,
      bookSummaries: summaries,
      headings: current.headings,
      distance: current.distance,
      enabledCategories: _enabledCategories,
      enabledNikayas: _enabledNikayas,
    );
  }

  /// Load the next page of results for an already-expanded book.
  Future<void> loadMoreForBook(int summaryIndex) async {
    await _loadBookPage(summaryIndex);
  }

  /// Load all remaining results for a book.
  Future<void> loadAllForBook(int summaryIndex) async {
    await _loadBookPage(summaryIndex, fetchAll: true);
  }

  // ── AI-found results (Gavesana) ──────────────────────────────────────

  /// Display AI-found passages in the normal search results format.
  ///
  /// [passages] may contain duplicates and out-of-order entries; they are
  /// deduplicated, grouped by book and presented as fully-expanded book
  /// summaries (like an auto-expanded FTS search). The search query is used
  /// only for highlighting, so AI results show every line (showAllLines).
  Future<void> showAiResults({
    required String query,
    required List<AiPassageRef> passages,
  }) async {
    state = const SearchLoading();
    try {
      final seen = <String>{};
      final grouped = <String, List<AiPassageRef>>{};
      for (final p in passages) {
        if (p.bookId.isEmpty || p.paraId <= 0) continue;
        final key = '${p.bookId}:${p.paraId}';
        if (!seen.add(key)) continue;
        grouped.putIfAbsent(p.bookId, () => []).add(p);
      }

      if (grouped.isEmpty) {
        state = SearchResults(
          query: query,
          totalResults: 0,
          bookSummaries: const [],
        );
        return;
      }

      final allBooks = await _allBooks();
      final bookMap = <String, BookInfo>{
        for (final b in allBooks) b.bookId: b,
      };
      final activeLang = _activeTranslationLang();
      final searchWords = normalizePaliFuzzy(query)
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();

      // Sort books by id (stable, matches normal search ordering).
      final bookIds = grouped.keys.toList()
        ..sort((a, b) => (bookMap[a]?.id ?? 0).compareTo(bookMap[b]?.id ?? 0));

      final summaries = <BookResultSummary>[];
      for (final bookId in bookIds) {
        final refs = grouped[bookId]!;
        final book = bookMap[bookId] ??
            BookInfo(id: 0, bookId: bookId, bookName: bookId);
        final items = <SearchResultItem>[];
        for (final ref in refs) {
          final item = await _buildAiResultItem(
            ref: ref,
            activeLang: activeLang,
            searchWords: searchWords,
          );
          if (item != null) items.add(item);
        }
        if (items.isEmpty) continue;
        summaries.add(BookResultSummary(
          book: book,
          totalCount: items.length,
          isExpanded: true,
          loadedPages: [items],
          forceFullyLoaded: true,
        ));
      }

      state = SearchResults(
        query: query,
        totalResults: summaries.fold(0, (s, b) => s + b.totalCount),
        bookSummaries: summaries,
      );
    } catch (e) {
      debugPrint('[SEARCH] showAiResults failed: $e');
      state = SearchError('Failed to load AI results: $e');
    }
  }

  /// Build a full [SearchResultItem] (with lines + translation) for an
  /// AI-found passage, mirroring [_loadBookPage]'s fetch logic.
  Future<SearchResultItem?> _buildAiResultItem({
    required AiPassageRef ref,
    required String? activeLang,
    required List<String> searchWords,
  }) async {
    try {
      final epitakaDb = await _epitakaDb();
      final lineRows = await epitakaDb.customSelect(
        'SELECT para_id, line_id, pali '
        'FROM sentences '
        'WHERE book_id = ? AND para_id = ? '
        'ORDER BY line_id',
        variables: [
          Variable.withString(ref.bookId),
          Variable.withInt(ref.paraId),
        ],
      ).get();
      if (lineRows.isEmpty) return null;

      // Translations for the same paragraph (best-effort).
      final transLineMap = <int, String>{};
      if (activeLang != null) {
        try {
          final transDb =
              await _ref.read(translationDbProvider(activeLang).future);
          if (transDb != null) {
            final tRows = await transDb.customSelect(
              'SELECT line_id, translation '
              'FROM sentences '
              'WHERE book_id = ? AND para_id = ? '
              'ORDER BY line_id',
              variables: [
                Variable.withString(ref.bookId),
                Variable.withInt(ref.paraId),
              ],
            ).get();
            for (final row in tRows) {
              final t = row.data['translation'] as String?;
              if (t != null && t.isNotEmpty) {
                transLineMap[row.data['line_id'] as int] = t;
              }
            }
          }
        } catch (_) {}
      }

      final lines = <SearchResultLine>[];
      for (final row in lineRows) {
        final pali = (row.data['pali'] as String?) ?? '';
        final lineTrans = transLineMap[row.data['line_id'] as int];
        final paliNormalized = normalizePaliFuzzy(pali);
        bool isMatch = searchWords.any((w) => paliNormalized.contains(w));
        if (!isMatch && lineTrans != null) {
          isMatch =
              searchWords.any((w) => normalizePaliFuzzy(lineTrans).contains(w));
        }
        lines.add(SearchResultLine(
          lineId: row.data['line_id'] as int,
          pali: pali,
          translation: lineTrans,
          isMatch: isMatch,
        ));
      }

      if (lines.isEmpty) return null;
      return SearchResultItem(
        bookId: ref.bookId,
        paraId: ref.paraId,
        lines: lines,
        showAllLines: true,
      );
    } catch (e) {
      debugPrint('[SEARCH] _buildAiResultItem failed: $e');
      return null;
    }
  }

  /// Search the headings table for matching titles.
  Future<List<HeadingResult>> _searchHeadings(
    EpitakaDatabase epitakaDb,
    String normalized,
    Map<String, BookInfo> bookMap,
  ) async {
    try {
      // Clean punctuation (commas, quotes, …) out of pasted sentences the
      // same way the FTS query is cleaned, so the LIKE pattern matches
      // heading titles. Diacritics are preserved (LIKE matches them as-is).
      final cleaned = cleanPaliForIndexing(normalized);
      // Never build a `LIKE '%%'` pattern (would match every heading).
      if (cleaned.isEmpty) return [];
      final likePattern = '%$cleaned%';
      final rows = await epitakaDb.customSelect(
        'SELECT book_id, para_id, title, level '
        'FROM headings '
        'WHERE title LIKE ? '
        'ORDER BY book_id, para_id '
        'LIMIT 10',
        variables: [Variable.withString(likePattern)],
      ).get();

      final results = <HeadingResult>[];
      final seen = <String>{};
      for (final row in rows) {
        final bookId = row.data['book_id'] as String;
        final paraId = row.data['para_id'] as int;
        final title = (row.data['title'] as String?) ?? '';
        final level = row.data['level'] as int?;

        // Deduplicate by book_id + title to avoid showing the same
        // heading multiple times (e.g. when multiple para_ids match).
        final key = '$bookId:$title';
        if (seen.contains(key)) continue;
        seen.add(key);

        final book = bookMap[bookId];
        results.add(HeadingResult(
          bookId: bookId,
          paraId: paraId,
          title: title,
          level: level,
          bookName: book?.bookName,
        ));
      }
      return results;
    } catch (e) {
      debugPrint('[SEARCH] Headings search failed: $e');
      return [];
    }
  }

  /// Get suggestions for autocomplete.
  Future<List<SearchSuggestion>> getSuggestions(String prefix) async {
    if (prefix.trim().isEmpty) return [];
    try {
      final appDb = await _ref.read(appDbProvider.future);
      return appDb.getSearchSuggestions(prefix, limit: 10);
    } catch (_) {
      return [];
    }
  }

  /// Clear the search state.
  void clear() {
    _debounce?.cancel();
    _cachedAllBooks = null;
    _enabledCategories = {...kAllCategories};
    _enabledNikayas = {...kAllNikayas};
    state = const SearchIdle();
  }
}

// ── Utility providers ────────────────────────────────────────────────────

/// A passage located by the AI search tool loop.
class AiPassageRef {
  final String bookId;
  final int paraId;

  /// Optional display text (Pāli) captured from the tool result.
  final String? text;

  const AiPassageRef({
    required this.bookId,
    required this.paraId,
    this.text,
  });
}

final expandSearchResultsProvider = StateProvider<bool>((ref) => true);
