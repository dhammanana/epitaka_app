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
import '../../indexing/index_controller.dart';

// ── Constants ───────────────────────────────────────────────────────────

/// Items per page when paginating within a book.
const int kSearchPageSize = 30;

/// If total results across all books exceeds this, collapse all books.
const int kCollapseThreshold = 30;

// ── Model types ─────────────────────────────────────────────────────────

/// A single search result item with both Pāli and translation text.
class SearchResultItem {
  final String bookId;
  final int paraId;
  final String paliText;
  final String? translation;

  /// FTS5 snippet for Pāli matches (<mark> tags already embedded).
  final String? paliSnippet;

  /// FTS5 snippet for translation matches (<mark> tags already embedded).
  final String? translationSnippet;

  const SearchResultItem({
    required this.bookId,
    required this.paraId,
    required this.paliText,
    this.translation,
    this.paliSnippet,
    this.translationSnippet,
  });
}

/// Book-level summary from the initial count-only phase.
class BookResultSummary {
  final BookInfo book;
  final int totalCount;
  bool isExpanded;

  /// Pages of loaded results (each page is `kSearchPageSize` items max).
  final List<List<SearchResultItem>> loadedPages;

  /// Whether we've loaded all available results for this book.
  bool get fullyLoaded =>
      loadedPages.length * kSearchPageSize >= totalCount;

  int get loadedCount =>
      loadedPages.fold(0, (sum, page) => sum + page.length);

  BookResultSummary({
    required this.book,
    required this.totalCount,
    this.isExpanded = false,
    List<List<SearchResultItem>>? loadedPages,
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

/// Results from the initial count-only pass. If [totalResults] <=
/// [kCollapseThreshold], results are already loaded and displayed.
/// Otherwise only [bookSummaries] are available, each collapsed.
class SearchResults extends SearchState {
  final String query;
  final int totalResults;
  final bool fuzzy;
  final int distance;

  /// Per-book summaries. Books with loaded results have `isExpanded == true`
  /// and their `loadedPages` populated.
  final List<BookResultSummary> bookSummaries;

  const SearchResults({
    required this.query,
    required this.totalResults,
    required this.bookSummaries,
    this.fuzzy = false,
    this.distance = 0,
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

  SearchNotifier(this._ref) : super(const SearchIdle());

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // ── Lazy caches ────────────────────────────────────────────────────────

  Future<EpitakaDatabase> _epitakaDb() async {
    if (_cachedEpitakaDb == null) {
      _cachedEpitakaDb = await _ref.read(epitakaDbProvider.future);
    }
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
  Future<void> search({
    required String query,
    bool fuzzy = false,
    int distance = 0,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
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

      Map<String, int> combinedCounts = {};

      // Run both count queries in parallel
      final activeLang = _activeTranslationLang();
      final countFutures = <Future<Map<String, int>>>[
        (() async {
          try {
            return await appDb.countPaliResultsByBook(
              normalized,
              fuzzy: fuzzy,
              distance: distance,
            );
          } catch (_) {
            return <String, int>{};
          }
        })(),
      ];
      if (activeLang != null) {
        countFutures.add(() async {
          try {
            return await appDb.countTranslationResultsByBook(
              activeLang,
              normalized,
              fuzzy: fuzzy,
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

      if (combinedCounts.isEmpty) {
        state = SearchResults(
          query: normalized,
          totalResults: 0,
          bookSummaries: [],
          fuzzy: fuzzy,
          distance: distance,
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

      final totalResults = combinedCounts.values.fold(0, (a, b) => a + b);
      final autoExpand = totalResults <= kCollapseThreshold;

      final summaries = <BookResultSummary>[];
      for (final bookId in sortedBookIds) {
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
        fuzzy: fuzzy,
        distance: distance,
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
  /// If [fetchAll] is true, keep loading pages until all results are fetched.
  Future<void> _loadBookPage(int summaryIndex, {bool fetchAll = false}) async {
    final current = state;
    if (current is! SearchResults) return;

    if (summaryIndex < 0 || summaryIndex >= current.bookSummaries.length) return;

    final appDb = await _ref.read(appDbProvider.future);
    final activeLang = _activeTranslationLang();
    final query = current.query;

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

      // Run both FTS queries in parallel
      final detailFutures = <Future<List<SearchResultRow>>>[
        appDb.searchPaliFtsByBook(
          summary.book.bookId,
          query,
          fuzzy: current.fuzzy,
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
          fuzzy: current.fuzzy,
          distance: current.distance,
          limit: pageSize,
          offset: offset,
        ));
      } else {
        detailFutures.add(Future.value(<SearchResultRow>[]));
      }
      final detailResults = await Future.wait(detailFutures);
      final paliResults = detailResults[0];
      final transResults = detailResults.length > 1
          ? detailResults[1]
          : <SearchResultRow>[];

      // Merge and deduplicate by paraId
      final seenParaIds = <int>{};
      final merged = <SearchResultItem>[];

      for (final row in paliResults) {
        if (row.firstParaId == null) continue;
        if (seenParaIds.contains(row.firstParaId)) continue;
        seenParaIds.add(row.firstParaId!);

        // Look up translation for this paraId from trans results
        String? translation;
        final transMatch = transResults
            .where((t) => t.firstParaId == row.firstParaId)
            .firstOrNull;
        if (transMatch != null &&
            transMatch.translation != null &&
            transMatch.translation!.isNotEmpty) {
          translation = transMatch.translation;
        } else {
          translation = await _fetchTranslationForPara(
            summary.book.bookId,
            row.firstParaId!,
            activeLang,
          );
        }

        merged.add(SearchResultItem(
          bookId: row.bookId,
          paraId: row.firstParaId!,
          paliText: row.paliText.isNotEmpty
              ? row.paliText
              : (row.snippet
                  .replaceAll('<mark>', '')
                  .replaceAll('</mark>', '')),
          translation: translation,
          paliSnippet: row.snippet.isNotEmpty ? row.snippet : null,
          translationSnippet:
              transMatch?.snippet.isNotEmpty == true
                  ? transMatch!.snippet
                  : null,
        ));
      }

      // Add translation-only results not already covered
      for (final row in transResults) {
        if (row.firstParaId == null) continue;
        if (seenParaIds.contains(row.firstParaId)) continue;
        seenParaIds.add(row.firstParaId!);

        final paliText = await _fetchPaliTextForPara(
          summary.book.bookId,
          row.firstParaId!,
        );

        merged.add(SearchResultItem(
          bookId: row.bookId,
          paraId: row.firstParaId!,
          paliText: paliText,
          translation: row.translation,
          paliSnippet: null,
          translationSnippet:
              row.snippet.isNotEmpty ? row.snippet : null,
        ));
      }

      // Build updated summary with new page appended
      final newLoadedPages = [...summary.loadedPages, merged];
      final newSummary = BookResultSummary(
        book: summary.book,
        totalCount: summary.totalCount,
        isExpanded: true,
        loadedPages: newLoadedPages,
      );

      summaries[summaryIndex] = newSummary;
      // Re-read the local reference so subsequent loop iterations see the
      // updated loadedPages count.
      summary = newSummary;

      state = SearchResults(
        query: current.query,
        totalResults: current.totalResults,
        bookSummaries: summaries,
        fuzzy: current.fuzzy,
        distance: current.distance,
      );

      if (!fetchAll) break;
      hasMore = !summary.fullyLoaded && merged.length >= pageSize;
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
    );
    state = SearchResults(
      query: current.query,
      totalResults: current.totalResults,
      bookSummaries: summaries,
      fuzzy: current.fuzzy,
      distance: current.distance,
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
    );
    state = SearchResults(
      query: current.query,
      totalResults: current.totalResults,
      bookSummaries: summaries,
      fuzzy: current.fuzzy,
      distance: current.distance,
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
    state = const SearchIdle();
  }

  // ── Private helpers ──────────────────────────────────────────────────

  /// Fetch the translation text for a specific para_id from the active
  /// translation database.
  Future<String?> _fetchTranslationForPara(
    String bookId,
    int paraId,
    String? langCode,
  ) async {
    if (langCode == null) return null;
    try {
      final lang = TranslationLanguage.fromCode(langCode);
      final transDb = await _ref.read(translationDbProvider(lang).future);
      if (transDb == null) return null;

      final rows = await transDb.customSelect(
        "SELECT group_concat(translation, ' ') as trans_text "
        'FROM sentences '
        'WHERE book_id = ? AND para_id = ?',
        variables: [
          Variable.withString(bookId),
          Variable.withInt(paraId),
        ],
      ).get();

      if (rows.isNotEmpty) {
        return rows.first.data['trans_text'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Fetch the Pali text for a specific para_id from the epitaka database.
  Future<String> _fetchPaliTextForPara(
    String bookId,
    int paraId,
  ) async {
    try {
      final db = await _epitakaDb();
      final rows = await db.customSelect(
        "SELECT group_concat(pali, ' ') as pali_text "
        'FROM sentences '
        'WHERE book_id = ? AND para_id = ?',
        variables: [
          Variable.withString(bookId),
          Variable.withInt(paraId),
        ],
      ).get();

      if (rows.isNotEmpty) {
        final text = rows.first.data['pali_text'] as String?;
        if (text != null && text.isNotEmpty) return text;
      }
    } catch (_) {}
    return '';
  }
}

// ── Utility providers ────────────────────────────────────────────────────

final expandSearchResultsProvider = StateProvider<bool>((ref) => true);
