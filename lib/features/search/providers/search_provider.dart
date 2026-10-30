import 'dart:async';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/epitaka_database.dart';
import '../../../core/database/nissaya_database.dart';
import '../../../core/models/app_models.dart';
import '../../../core/models/translation_version.dart';
import '../../../core/providers/app_db_provider.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/pali_search_utils.dart';
import '../../indexing/index_controller.dart';
import '../../reader/providers/reader_tabs_provider.dart';
import '../services/regex_search.dart';
import 'search_history_provider.dart';

// ── Constants ───────────────────────────────────────────────────────────

/// Items per page when paginating within a book.
const int kSearchPageSize = 30;

/// Minimum prefix length before autocomplete suggestions are shown.
/// Shorter queries are too ambiguous — don't suggest from the beginning.
const int kSearchSuggestionMinLength = 3;

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

  /// Regex mode: the pieces of text the pattern matched in this paragraph.
  /// Rows and the reader highlight these as ordinary words, so no highlight
  /// code has to run the pattern itself.
  final List<String>? highlightTerms;

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
    this.highlightTerms,
  });
}

/// Book-level summary from the initial count-only phase.
class BookResultSummary {
  final BookInfo book;
  final int totalCount;
  bool isExpanded;

  /// Pages of loaded results, one per window of hits (see [fullyLoaded]).
  final List<List<SearchResultItem>> loadedPages;

  /// When true (AI-found results), treat the book as fully loaded so no
  /// "load more" button appears — the AI already selected every passage.
  final bool forceFullyLoaded;

  /// Whether we've loaded all available results for this book.
  ///
  /// A page can hold up to a window of Pāli hits plus a window of
  /// translation-only hits, so every hit can be loaded before the pages
  /// reach [totalCount] at 30 each.
  bool get fullyLoaded =>
      forceFullyLoaded ||
      loadedPages.length * kSearchPageSize >= totalCount ||
      loadedCount >= totalCount;

  int get loadedCount => loadedPages.fold(0, (sum, page) => sum + page.length);

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
  /// Snapshot of the current filter selections, mirroring the fields on
  /// [SearchResults]. The idle state carries them so that toggling a
  /// filter chip before the first search still changes the state object
  /// (and thus rebuilds the UI) — a plain field-less const state is
  /// always identical, so the chips would never update until a search
  /// ran.
  final Set<String> enabledCategories;
  final Set<String> enabledNikayas;

  const SearchIdle({
    this.enabledCategories = kAllCategories,
    this.enabledNikayas = kAllNikayas,
  });
}

class SearchIndexing extends SearchState {
  final double progress;
  final String status;
  const SearchIndexing({
    this.progress = 0,
    this.status = 'Building search index…',
  });
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

  /// [query] is a regular expression (the rx button was on).
  final bool regex;

  const SearchResults({
    required this.query,
    required this.totalResults,
    required this.bookSummaries,
    this.headings = const [],
    this.distance = 0,
    this.enabledCategories = kAllCategories,
    this.enabledNikayas = kAllNikayas,
    this.regex = false,
  });
}

class SearchError extends SearchState {
  final String message;

  /// Set when a regex did not compile: why. The screen shows it as
  /// "Invalid pattern: …" in the user's language.
  final String? patternError;

  /// The query the error belongs to; the field's error text hides once the
  /// box text moves on.
  final String? query;

  /// The regex scan ran past its time limit (spec K).
  final bool patternTooSlow;

  const SearchError(
    this.message, {
    this.patternError,
    this.query,
    this.patternTooSlow = false,
  });

  /// "Invalid pattern: …" or "Pattern too slow", or null for other errors.
  String? patternMessage(AppLocalizations loc) => patternTooSlow
      ? loc.patternTooSlow
      : patternError == null
      ? null
      : loc.invalidPattern(patternError!);
}

// ── Provider ─────────────────────────────────────────────────────────────

/// A search sent from outside the app (share sheet, text-selection menu,
/// search link) to a search screen that is already open.
///
/// No `==` override: every request is a new object, so the same word sent
/// twice still notifies the screen.
class IncomingSearch {
  IncomingSearch(this.query);

  final String query;
}

final incomingSearchProvider = StateProvider<IncomingSearch?>((ref) => null);

/// The rx button of the Search screen and the Search sidebar. Not saved: a
/// regex mode left on from an earlier day would make plain searches look
/// broken.
final searchRegexProvider = StateProvider<bool>((ref) => false);

/// Starts a regex scan of the Pāli search copy. Tests replace it to scan a
/// fixture file and to count the scans.
final regexScanProvider =
    Provider<Future<RegexJob<List<RegexHit>>> Function(String pattern)>(
      (ref) =>
          (pattern) async =>
              scanPaliRegex(await AppDatabase.defaultPath(), pattern),
    );

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((
  ref,
) {
  return SearchNotifier(ref);
});

typedef _LoadPoint = ({
  String query,
  int distance,
  bool regex,
  int pageCount,
  int totalCount,
  Set<int> seen,
});

typedef RawHeading = ({
  String bookId,
  int paraId,
  int? level,
  String title,
  String key,
});

class SearchNotifier extends StateNotifier<SearchState> {
  final Ref _ref;
  Timer? _debounce;
  EpitakaDatabase? _cachedEpitakaDb;
  List<BookInfo>? _cachedAllBooks;
  int _searchGen = 0;

  /// Filter state: which categories (layers) are enabled.
  Set<String> _enabledCategories = {...kAllCategories};

  /// Filter state: which nikayas (pitakas) are enabled.
  Set<String> _enabledNikayas = {...kAllNikayas};

  SearchNotifier(this._ref) : super(const SearchIdle());

  @override
  void dispose() {
    _debounce?.cancel();
    _cancelRegexJobs();
    super.dispose();
  }

  /// The regex jobs of the running search: the scan, the headings, the
  /// result pages. A new search, Clear and dispose cancel them (spec K).
  final Set<RegexJob<Object?>> _regexJobs = {};

  void _cancelRegexJobs() {
    for (final job in _regexJobs) {
      job.cancel();
    }
    _regexJobs.clear();
  }

  /// Await [job] as one of the running search's jobs.
  Future<T> _awaitRegexJob<T>(RegexJob<T> job) async {
    _regexJobs.add(job);
    try {
      return await job.result;
    } finally {
      _regexJobs.remove(job);
    }
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
          .map(
            (b) => BookInfo(
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
            ),
          )
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
      // AI results are rebuilt from the passages already found: their query
      // is the question the user asked, which a full-text search would treat
      // as search words and replace the passages with unrelated hits.
      if (_aiPassages != null) {
        await _renderAiResults(query: current.query);
        return;
      }
      await search(
        query: current.query,
        distance: current.distance,
        regex: current.regex,
      );
    } else if (current is SearchIdle) {
      // No search active yet — still emit a fresh idle state so the
      // filter chips (which read from this provider) rebuild with the
      // new selection. SearchLoading/SearchIndexing/SearchError are left
      // untouched.
      state = SearchIdle(
        enabledCategories: _enabledCategories,
        enabledNikayas: _enabledNikayas,
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
    _warmHeadingsCache().ignore();
  }

  Future<void> _warmHeadingsCache() async {
    try {
      await _allHeadings(await _epitakaDb());
    } catch (_) {}
  }

  // ── Main search entry point ───────────────────────────────────────────

  /// Execute a search. First stage: count results per book.
  /// If total is small enough, also load the actual results.
  ///
  /// Search is always diacritic-insensitive (fuzzy): the FTS index is
  /// built with `remove_diacritics 1`, so the database layer normalizes
  /// the query the same way the index text was cleaned.
  ///
  /// With [regex], [query] is a pattern run over the Pāli search copy of
  /// every paragraph, with exact diacritics (see [scanPaliRegex]). It is
  /// kept as typed, spaces included, and stays out of the search history:
  /// re-run from there in normal mode it would mean something else.
  Future<void> search({
    required String query,
    int distance = 0,
    bool regex = false,
  }) async {
    final gen = ++_searchGen;
    _cancelRegexJobs();
    // A typed search replaces any AI-found passages shown before it.
    _aiPassages = null;
    _aiHighlightTerms = const [];
    final normalized = regex ? query : query.trim();
    if (regex) distance = 0;
    // A query made only of punctuation (",", "…") has no searchable words
    // after cleaning — treat it like an empty query instead of running a
    // pointless search.
    if (normalized.trim().isEmpty ||
        (!regex && cleanPaliForIndexing(normalized).isEmpty)) {
      state = const SearchIdle();
      return;
    }

    if (regex) {
      final error = regexError(normalized);
      if (error != null) {
        state = SearchError(
          'Invalid pattern: $error',
          patternError: error,
          query: normalized,
        );
        return;
      }
    } else {
      try {
        _ref.read(searchHistoryProvider.notifier).add(normalized);
      } catch (_) {}
    }
    state = const SearchLoading();

    try {
      final appDb = await _ref.read(appDbProvider.future);
      if (gen != _searchGen) return;

      // Ensure Pali index is built
      final paliBuilt = await appDb.isSearchIndexBuilt();
      if (!paliBuilt) {
        await ensureIndexBuilt();
      }
      if (gen != _searchGen) return;

      // ── Count results by book ──────────────────────────────────────
      // Books, the headings bulk load, and the count query run
      // concurrently so a cold headings cache overlaps the FTS count
      // instead of stalling behind it.
      final countSw = Stopwatch()..start();
      final epitakaDbFuture = _epitakaDb();
      final headingsFuture = epitakaDbFuture.then<List<RawHeading>>(
        (db) => _allHeadings(db),
        onError: (_) => <RawHeading>[],
      );
      final countFuture = regex
          // A failed scan reaches the catch below and shows as an error,
          // not as "no results".
          ? _regexCounts(gen, normalized)
          : () async {
              try {
                return await appDb.countResultsByBook(
                  normalized,
                  langCode: _activeTranslationLang(),
                  distance: distance,
                );
              } catch (_) {
                return <String, int>{};
              }
            }();
      final waited = await Future.wait([
        _allBooks(),
        headingsFuture,
        countFuture,
      ]);
      if (gen != _searchGen) return;

      final allBooks = waited[0] as List<BookInfo>;
      final rawHeadings = waited[1] as List<RawHeading>;
      final bookMap = <String, BookInfo>{for (final b in allBooks) b.bookId: b};
      final combinedCounts = waited[2] as Map<String, int>;

      debugPrint(
        '[PERF] search count ms=${countSw.elapsedMilliseconds} '
        'books=${combinedCounts.length} '
        'hits=${combinedCounts.values.fold<int>(0, (a, b) => a + b)}',
      );

      // ── Search headings ───────────────────────────────────────────
      final List<HeadingResult> headingResults;
      if (regex) {
        final matched = await _awaitRegexJob(
          startRegexMatch(normalized, [
            for (final h in rawHeadings) [h.title],
          ]),
        );
        if (gen != _searchGen) return;
        headingResults = _collectHeadings(
          [for (final i in matched.hits) rawHeadings[i]],
          bookMap,
          (_) => true,
        );
      } else {
        headingResults = _filterHeadings(rawHeadings, normalized, bookMap);
      }

      // The currently opened book (if any) is pinned to the front of both
      // headings and book groups, so hits in the book being read come first.
      final activeBookId = _ref.read(readerTabsProvider).activeTab?.bookId;
      if (activeBookId != null) {
        headingResults.sort((a, b) {
          final aActive = a.bookId == activeBookId ? 0 : 1;
          final bActive = b.bookId == activeBookId ? 0 : 1;
          return aActive.compareTo(bActive);
        });
      }

      if (combinedCounts.isEmpty && headingResults.isEmpty) {
        state = SearchResults(
          query: normalized,
          totalResults: 0,
          bookSummaries: [],
          headings: headingResults,
          distance: distance,
          enabledCategories: _enabledCategories,
          enabledNikayas: _enabledNikayas,
          regex: regex,
        );
        return;
      }

      // Build summaries sorted by book id, with the currently opened
      // book (if any, read above) pinned to the front so the reader sees
      // hits in the book they are already reading before every other book.
      final sortedBookIds = combinedCounts.keys.toList()
        ..sort((a, b) {
          if (a == activeBookId) return -1;
          if (b == activeBookId) return 1;
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
        final book =
            bookMap[bookId] ??
            BookInfo(id: 0, bookId: bookId, bookName: bookId);
        summaries.add(
          BookResultSummary(
            book: book,
            totalCount: combinedCounts[bookId]!,
            // The open book is always expanded so its hits are visible
            // immediately, even when the overall result set is large.
            isExpanded: autoExpand || bookId == activeBookId,
          ),
        );
      }

      state = SearchResults(
        query: normalized,
        totalResults: totalResults,
        bookSummaries: summaries,
        headings: headingResults,
        distance: distance,
        enabledCategories: _enabledCategories,
        enabledNikayas: _enabledNikayas,
        regex: regex,
      );

      // If auto-expanded, load every book concurrently instead of one
      // book at a time — latency is the slowest book, not the sum.
      // Otherwise still load the open book (pinned first and expanded)
      // so its hits are visible without an extra tap.
      if (autoExpand) {
        await Future.wait([
          for (final s in summaries)
            _loadBookPages(s.book.bookId, fetchAll: true),
        ]);
      } else if (activeBookId != null &&
          summaries.any((s) => s.book.bookId == activeBookId)) {
        await _loadBookPages(activeBookId, fetchAll: true);
      }
    } on RegexTooSlow {
      if (gen != _searchGen) return;
      state = SearchError(
        'Pattern too slow',
        query: normalized,
        patternTooSlow: true,
      );
    } on RegexCancelled {
      // Only a newer search or Clear cancels; that one owns the state.
    } catch (e) {
      if (gen != _searchGen) return;
      state = SearchError('Search failed: $e');
    }
  }

  /// The regex hits of search [_regexHitsGen], per book, paragraphs in text
  /// order. One scan serves the counts and every page: the scan reads the
  /// whole canon, a book's page only slices this list.
  Map<String, List<int>> _regexHits = const {};
  int _regexHitsGen = -1;

  /// The pattern [_regexHits] answer. The hits do not depend on the
  /// category or piṭaka filters, so a filter change reuses them instead of
  /// scanning the canon again (about 1 s).
  String? _regexHitsPattern;

  Future<Map<String, int>> _regexCounts(int gen, String pattern) async {
    if (pattern != _regexHitsPattern) {
      final sw = Stopwatch()..start();
      final job = await _ref.read(regexScanProvider)(pattern);
      if (gen != _searchGen) {
        job.cancel();
        throw const RegexCancelled();
      }
      final hits = await _awaitRegexJob(job);
      debugPrint(
        '[PERF] search regex ms=${sw.elapsedMilliseconds} hits=${hits.length}',
      );
      final byBook = <String, List<int>>{};
      for (final h in hits) {
        byBook.putIfAbsent(h.bookId, () => []).add(h.paraId);
      }
      for (final ids in byBook.values) {
        ids.sort();
      }
      _regexHits = byBook;
      _regexHitsPattern = pattern;
    }
    if (gen == _searchGen) _regexHitsGen = gen;
    return {for (final e in _regexHits.entries) e.key: e.value.length};
  }

  // ── Load results for a specific book ──────────────────────────────────

  /// Load the next page(s) of results for the book at [summaryIndex].
  /// Fetches individual lines with translations for each matching paragraph.
  Future<void> _loadBookPage(int summaryIndex, {bool fetchAll = false}) async {
    final current = state;
    if (current is! SearchResults) return;
    if (summaryIndex < 0 || summaryIndex >= current.bookSummaries.length) {
      return;
    }
    await _loadBookPages(
      current.bookSummaries[summaryIndex].book.bookId,
      fetchAll: fetchAll,
    );
  }

  Future<void> _loadBookPages(String bookId, {bool fetchAll = false}) async {
    final sw = Stopwatch()..start();
    final loaded = await _loadBookPagesLoop(bookId, fetchAll: fetchAll);
    if (fetchAll && loaded.pages > 0) {
      debugPrint(
        '[PERF] search open-book book=$bookId ms=${sw.elapsedMilliseconds} '
        'hits=${loaded.hits} pages=${loaded.pages} commits=${loaded.commits}',
      );
    }
  }

  /// Loads the next page of [bookId]'s hits and, with [fetchAll], every
  /// page after it.
  ///
  /// A page is a 30-row window of the Pāli hits plus the same window of the
  /// translation hits, in rank order. The first page is fetched and
  /// published on its own so the first hits show at once. The rest come
  /// from one query per index, cut in memory into the same windows, and are
  /// published together: re-running both queries per page took minutes for
  /// a common word on a phone, and each publish redrew the whole list.
  Future<({int pages, int hits, int commits})> _loadBookPagesLoop(
    String bookId, {
    bool fetchAll = false,
  }) async {
    final gen = _searchGen;
    var pages = 0;
    var hits = 0;
    var commits = 0;
    ({int pages, int hits, int commits}) done() =>
        (pages: pages, hits: hits, commits: commits);

    // A window whose paragraphs were all shown on earlier pages adds an
    // empty page and moves on, so "Show more" always shows something new.
    _LoadPoint? point;
    while (true) {
      point = _bookLoadPoint(bookId);
      if (point == null) return done();
      final first = _bookWindows(point.pageCount, point.totalCount).first;
      final firstRows = await _fetchBookRows(
        bookId: bookId,
        query: point.query,
        distance: point.distance,
        regex: point.regex,
        offset: first.offset,
        limit: first.pageSize,
      );
      if (gen != _searchGen) return done();
      final firstItems = (await _buildWindowItems(
        bookId,
        point.query,
        [firstRows],
        seen: point.seen,
        regex: point.regex,
      )).single;
      if (gen != _searchGen) return done();
      if (!_commitBookPages(bookId, [
        firstItems,
      ], expectedPageCount: point.pageCount)) {
        return done();
      }
      pages++;
      hits += firstItems.length;
      commits++;
      if (_rowsEnd(firstRows, first.pageSize)) return done();
      if (firstItems.isNotEmpty) break;
    }
    if (!fetchAll) return done();

    point = _bookLoadPoint(bookId);
    if (point == null) return done();
    final windows = _bookWindows(point.pageCount, point.totalCount);
    final start = windows.first.offset;
    // A negative LIMIT means no limit in SQLite.
    final restRows = await _fetchBookRows(
      bookId: bookId,
      query: point.query,
      distance: point.distance,
      regex: point.regex,
      offset: start,
      limit: -1,
    );
    if (gen != _searchGen) return done();
    List<SearchResultRow> cut(List<SearchResultRow> rows, int offset, int n) {
      final from = (offset - start).clamp(0, rows.length);
      return rows.sublist(from, (from + n).clamp(0, rows.length));
    }

    final windowRows = [
      for (final w in windows)
        (
          pali: cut(restRows.pali, w.offset, w.pageSize),
          trans: cut(restRows.trans, w.offset, w.pageSize),
        ),
    ];
    final built = await _buildWindowItems(
      bookId,
      point.query,
      windowRows,
      seen: point.seen,
      regex: point.regex,
    );
    if (gen != _searchGen) return done();

    // The same stop rule as one fetch per page: a window that runs out of
    // rows ends the book.
    final accepted = <List<SearchResultItem>>[];
    for (var i = 0; i < windows.length; i++) {
      accepted.add(built[i]);
      if (_rowsEnd(windowRows[i], windows[i].pageSize)) break;
    }
    if (!_commitBookPages(
      bookId,
      accepted,
      expectedPageCount: point.pageCount,
    )) {
      return done();
    }
    pages += accepted.length;
    hits += accepted.fold<int>(0, (n, p) => n + p.length);
    commits++;
    return done();
  }

  /// Where [bookId]'s next page starts, or `null` when the book is gone
  /// from the results or fully loaded. [seen] holds the paragraphs already
  /// on its pages.
  _LoadPoint? _bookLoadPoint(String bookId) {
    final current = state;
    if (current is! SearchResults) return null;
    final idx = current.bookSummaries.indexWhere(
      (s) => s.book.bookId == bookId,
    );
    if (idx < 0) return null;
    final summary = current.bookSummaries[idx];
    if (summary.fullyLoaded) return null;
    return (
      query: current.query,
      distance: current.distance,
      regex: current.regex,
      pageCount: summary.loadedPages.length,
      totalCount: summary.totalCount,
      seen: {
        for (final page in summary.loadedPages)
          for (final item in page) item.paraId,
      },
    );
  }

  /// Whether a window's rows ran out: the hits end inside it.
  static bool _rowsEnd(
    ({List<SearchResultRow> pali, List<SearchResultRow> trans}) rows,
    int pageSize,
  ) => rows.pali.length < pageSize && rows.trans.length < pageSize;

  /// The page windows after the first [pageCount] pages: each starts at
  /// `page * kSearchPageSize`, and the last is cut to the hits that remain.
  /// Not empty when [_bookLoadPoint] returned a point.
  List<({int offset, int pageSize})> _bookWindows(
    int pageCount,
    int totalCount,
  ) {
    return [
      for (
        var offset = pageCount * kSearchPageSize;
        offset < totalCount;
        offset += kSearchPageSize
      )
        (
          offset: offset,
          pageSize: totalCount - offset < kSearchPageSize
              ? totalCount - offset
              : kSearchPageSize,
        ),
    ];
  }

  /// Appends [pages] to the book's loaded pages, but only when the book still
  /// holds [expectedPageCount] pages, the count the windows were cut from. A
  /// collapse or a "Load more" during the fetch changes that count, and the
  /// late pages would then re-open the book or repeat a page.
  bool _commitBookPages(
    String bookId,
    List<List<SearchResultItem>> pages, {
    required int expectedPageCount,
  }) {
    final current = state;
    if (current is! SearchResults) return false;
    final idx = current.bookSummaries.indexWhere(
      (s) => s.book.bookId == bookId,
    );
    if (idx < 0) return false;
    final summaries = [...current.bookSummaries];
    final summary = summaries[idx];
    if (summary.loadedPages.length != expectedPageCount) return false;
    summaries[idx] = BookResultSummary(
      book: summary.book,
      totalCount: summary.totalCount,
      isExpanded: true,
      loadedPages: [...summary.loadedPages, ...pages],
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
      regex: current.regex,
    );
    return true;
  }

  /// The Pāli and translation FTS rows of [bookId] in rank order, [limit]
  /// rows of each from [offset]. With [regex], the cached regex hits in text
  /// order, and no translation rows.
  Future<({List<SearchResultRow> pali, List<SearchResultRow> trans})>
  _fetchBookRows({
    required String bookId,
    required String query,
    required int distance,
    required bool regex,
    required int offset,
    required int limit,
  }) async {
    if (regex) {
      final ids = _regexHitsGen == _searchGen
          ? (_regexHits[bookId] ?? const <int>[])
          : const <int>[];
      final from = offset.clamp(0, ids.length);
      final to = limit < 0 ? ids.length : (from + limit).clamp(0, ids.length);
      return (
        pali: [
          for (final id in ids.sublist(from, to))
            SearchResultRow(
              bookId: bookId,
              vripage: '',
              snippet: '',
              firstParaId: id,
            ),
        ],
        trans: const <SearchResultRow>[],
      );
    }
    final appDb = await _ref.read(appDbProvider.future);
    final activeLang = _activeTranslationLang();

    // Get matching para_ids from BOTH Pali and translation FTS
    final detailFutures = <Future<List<SearchResultRow>>>[
      appDb.searchPaliFtsByBook(
        bookId,
        query,
        distance: distance,
        limit: limit,
        offset: offset,
      ),
    ];
    if (activeLang != null) {
      detailFutures.add(
        appDb.searchTranslationFtsByBook(
          activeLang,
          bookId,
          query,
          distance: distance,
          limit: limit,
          offset: offset,
        ),
      );
    } else {
      detailFutures.add(Future.value(<SearchResultRow>[]));
    }

    final detailResults = await Future.wait(detailFutures);
    return (pali: detailResults[0], trans: detailResults[1]);
  }

  /// Builds one page of [SearchResultItem]s per window of FTS rows. Each
  /// page lists its Pāli paragraphs, then its translation-only ones, as a
  /// page always has; the lines of every page are fetched together. A
  /// paragraph in [seen] or on an earlier window is left out, so one that
  /// matched in the Pāli on one page and in the translation on another is
  /// listed once.
  Future<List<List<SearchResultItem>>> _buildWindowItems(
    String bookId,
    String query,
    List<({List<SearchResultRow> pali, List<SearchResultRow> trans})> windows, {
    Set<int> seen = const {},
    bool regex = false,
  }) async {
    final activeLang = _activeTranslationLang();
    final searchWords = regex
        ? const <String>[]
        : normalizePaliFuzzy(
            query,
          ).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final listed = {...seen};
    final windowParaIds = <List<int>>[];
    final windowSnippets = <Map<int, SearchResultRow>>[];
    for (final (:pali, :trans) in windows) {
      // Merge para_ids from both Pali and translation results
      final paraIds = <int>[];
      final allSnippets = <int, SearchResultRow>{};

      for (final row in pali) {
        if (row.firstParaId == null) continue;
        if (listed.add(row.firstParaId!)) {
          paraIds.add(row.firstParaId!);
          allSnippets[row.firstParaId!] = row;
        }
      }
      for (final row in trans) {
        if (row.firstParaId == null) continue;
        if (listed.add(row.firstParaId!)) {
          // Translation-only match — store snippet
          paraIds.add(row.firstParaId!);
          allSnippets[row.firstParaId!] = row;
        }
      }
      windowParaIds.add(paraIds);
      windowSnippets.add(allSnippets);
    }

    final allParaIds = {for (final ids in windowParaIds) ...ids}.toList();
    if (allParaIds.isEmpty) return [for (final _ in windows) []];

    // Fetch individual lines from epitaka_db.sentences for matching para_ids,
    // a bounded number of ids per query.
    const chunkSize = 500;
    final chunks = [
      for (var i = 0; i < allParaIds.length; i += chunkSize)
        allParaIds.sublist(i, (i + chunkSize).clamp(0, allParaIds.length)),
    ];
    final epitakaDb = await _epitakaDb();
    final lineRows = <QueryRow>[];
    for (final ids in chunks) {
      final placeholders = ids.map((_) => '?').join(',');
      lineRows.addAll(
        await epitakaDb
            .customSelect(
              'SELECT para_id, line_id, pali '
              'FROM sentences '
              'WHERE book_id = ? AND para_id IN ($placeholders) '
              'ORDER BY para_id, line_id',
              variables: [
                Variable.withString(bookId),
                ...ids.map((id) => Variable.withInt(id)),
              ],
            )
            .get(),
      );
    }

    // Fetch translations for those para_ids
    final transLineMap = <int, Map<int, String>>{};
    if (activeLang != null) {
      try {
        if (TranslationFilenameParser.isNissaya(activeLang)) {
          final filename = TranslationFilenameParser.build(activeLang);
          final nissayaDb = await _ref.read(
            nissayaDbByFilenameProvider(filename).future,
          );
          if (nissayaDb != null) {
            // At most one page's worth of lookups at a time, as when each
            // page was fetched on its own.
            final perPara = <List<NissayaSentenceLine>>[];
            for (var i = 0; i < allParaIds.length; i += 60) {
              perPara.addAll(
                await Future.wait(
                  allParaIds
                      .sublist(i, (i + 60).clamp(0, allParaIds.length))
                      .map((pid) => nissayaDb.getSentences(bookId, pid)),
                ),
              );
            }
            for (var i = 0; i < allParaIds.length; i++) {
              final pid = allParaIds[i];
              for (final s in perPara[i]) {
                final t = s.formattedText;
                if (t.isNotEmpty) {
                  transLineMap.putIfAbsent(pid, () => {})[s.lineId] = t;
                }
              }
            }
          }
        } else {
          final transDb = await _ref.read(
            translationDbProvider(activeLang).future,
          );
          if (transDb != null) {
            for (final ids in chunks) {
              final placeholders = ids.map((_) => '?').join(',');
              final tRows = await transDb
                  .customSelect(
                    'SELECT para_id, line_id, translation '
                    'FROM sentences '
                    'WHERE book_id = ? AND para_id IN ($placeholders) '
                    'ORDER BY para_id, line_id',
                    variables: [
                      Variable.withString(bookId),
                      ...ids.map((id) => Variable.withInt(id)),
                    ],
                  )
                  .get();
              for (final row in tRows) {
                final pid = row.data['para_id'] as int;
                final lid = row.data['line_id'] as int;
                final t = row.data['translation'] as String?;
                if (t != null && t.isNotEmpty) {
                  transLineMap.putIfAbsent(pid, () => {})[lid] = t;
                }
              }
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
      // Regex mode marks its lines below, in a regex job.
      final bool isMatch;
      if (regex) {
        isMatch = false;
      } else {
        final paliNormalized = normalizePaliFuzzy(pali);
        var matched = searchWords.any((w) => paliNormalized.contains(w));
        if (!matched && lineTrans != null) {
          final transNormalized = normalizePaliFuzzy(lineTrans);
          matched = searchWords.any((w) => transNormalized.contains(w));
        }
        isMatch = matched;
      }

      paraLines
          .putIfAbsent(pid, () => [])
          .add(
            SearchResultLine(
              lineId: lid,
              pali: pali,
              translation: lineTrans,
              isMatch: isMatch,
            ),
          );
    }

    // A regex can match across a line break, so the paragraph matches but
    // no single line does: then every line is shown. A mark job that is too
    // slow or cancelled leaves every line shown and nothing highlighted.
    final highlightTerms = <int, List<String>>{};
    if (regex) {
      final pids = paraLines.keys.toList();
      List<({List<bool> lines, List<String> pieces})>? marks;
      try {
        marks = await _awaitRegexJob(
          _startRegexMarks(query, [
            for (final pid in pids) [for (final l in paraLines[pid]!) l.pali],
          ]),
        );
      } on RegexTooSlow {
        marks = null;
      } on RegexCancelled {
        marks = null;
      }
      for (var i = 0; i < pids.length; i++) {
        final pid = pids[i];
        final lines = paraLines[pid]!;
        final mark = marks?[i];
        final anyLine = mark != null && mark.lines.any((m) => m);
        if (mark != null) highlightTerms[pid] = mark.pieces;
        paraLines[pid] = [
          for (var j = 0; j < lines.length; j++)
            SearchResultLine(
              lineId: lines[j].lineId,
              pali: lines[j].pali,
              translation: lines[j].translation,
              isMatch: !anyLine || mark.lines[j],
            ),
        ];
      }
    }

    // Build SearchResultItems — only include paras that had lines
    return [
      for (var w = 0; w < windows.length; w++)
        [
          for (final pid in windowParaIds[w])
            if (paraLines[pid]?.isNotEmpty ?? false)
              SearchResultItem(
                bookId: bookId,
                paraId: pid,
                lines: paraLines[pid]!,
                paliSnippet: windowSnippets[w][pid]?.snippet.isNotEmpty == true
                    ? windowSnippets[w][pid]!.snippet
                    : null,
                highlightTerms: highlightTerms[pid],
              ),
        ],
    ];
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
      regex: current.regex,
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
      regex: current.regex,
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

  /// The passages of the last AI search, kept so a filter toggle re-renders
  /// the same passages instead of running a fresh full-text search.
  List<AiPassageRef>? _aiPassages;

  /// The search terms the AI actually queried (e.g. "kim idam"), used to
  /// highlight results — the user's question is not what was searched.
  List<String> _aiHighlightTerms = const [];

  /// Display AI-found passages in the normal search results format.
  ///
  /// [passages] may contain duplicates and out-of-order entries; they are
  /// deduplicated, grouped by book and presented as fully-expanded book
  /// summaries (like an auto-expanded FTS search). [highlightTerms] are the
  /// terms the AI searched for; they (not [query], the user's question) are
  /// what gets highlighted. AI results show every line (showAllLines).
  Future<void> showAiResults({
    required String query,
    required List<AiPassageRef> passages,
    List<String> highlightTerms = const [],
  }) async {
    final q = query.trim();
    if (q.isNotEmpty) {
      try {
        _ref.read(searchHistoryProvider.notifier).add(q);
      } catch (_) {}
    }
    _aiPassages = passages;
    _aiHighlightTerms = highlightTerms;
    await _renderAiResults(query: query);
  }

  /// Build the results view for the passages of the last AI search,
  /// honouring the current category/nikaya filters.
  Future<void> _renderAiResults({required String query}) async {
    final passages = _aiPassages;
    if (passages == null) return;
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
          enabledCategories: _enabledCategories,
          enabledNikayas: _enabledNikayas,
        );
        return;
      }

      final allBooks = await _allBooks();
      final bookMap = <String, BookInfo>{for (final b in allBooks) b.bookId: b};
      final activeLang = _activeTranslationLang();
      // Split the AI's terms into words; fall back to the question when the
      // AI used no search tool.
      final searchWords =
          (_aiHighlightTerms.isEmpty ? [query] : _aiHighlightTerms)
              .map(normalizePaliFuzzy)
              .expand((t) => t.split(RegExp(r'\s+')))
              .where((w) => w.isNotEmpty)
              .toList();

      // Sort books by id (stable, matches normal search ordering), with
      // the currently opened book pinned first. Books the filters exclude
      // drop their passages entirely.
      final activeBookId = _ref.read(readerTabsProvider).activeTab?.bookId;
      final bookIds =
          grouped.keys.where((id) {
            final book = bookMap[id];
            return book == null || _bookPassesFilters(book);
          }).toList()..sort((a, b) {
            if (a == activeBookId) return -1;
            if (b == activeBookId) return 1;
            return (bookMap[a]?.id ?? 0).compareTo(bookMap[b]?.id ?? 0);
          });

      final summaries = <BookResultSummary>[];
      for (final bookId in bookIds) {
        final refs = grouped[bookId]!;
        final book =
            bookMap[bookId] ??
            BookInfo(id: 0, bookId: bookId, bookName: bookId);
        final built = await Future.wait([
          for (final ref in refs)
            _buildAiResultItem(
              ref: ref,
              activeLang: activeLang,
              searchWords: searchWords,
            ),
        ]);
        final items = built.whereType<SearchResultItem>().toList();
        if (items.isEmpty) continue;
        summaries.add(
          BookResultSummary(
            book: book,
            totalCount: items.length,
            isExpanded: true,
            loadedPages: [items],
            forceFullyLoaded: true,
          ),
        );
      }

      state = SearchResults(
        query: query,
        totalResults: summaries.fold(0, (s, b) => s + b.totalCount),
        bookSummaries: summaries,
        enabledCategories: _enabledCategories,
        enabledNikayas: _enabledNikayas,
      );
    } catch (e) {
      debugPrint('[SEARCH] renderAiResults failed: $e');
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
      final lineRows = await epitakaDb
          .customSelect(
            'SELECT para_id, line_id, pali '
            'FROM sentences '
            'WHERE book_id = ? AND para_id = ? '
            'ORDER BY line_id',
            variables: [
              Variable.withString(ref.bookId),
              Variable.withInt(ref.paraId),
            ],
          )
          .get();
      if (lineRows.isEmpty) return null;

      // Translations for the same paragraph (best-effort).
      final transLineMap = <int, String>{};
      if (activeLang != null) {
        try {
          if (TranslationFilenameParser.isNissaya(activeLang)) {
            final filename = TranslationFilenameParser.build(activeLang);
            final nissayaDb = await _ref.read(
              nissayaDbByFilenameProvider(filename).future,
            );
            if (nissayaDb != null) {
              final sentences = await nissayaDb.getSentences(
                ref.bookId,
                ref.paraId,
              );
              for (final s in sentences) {
                final t = s.formattedText;
                if (t.isNotEmpty) {
                  transLineMap[s.lineId] = t;
                }
              }
            }
          } else {
            final transDb = await _ref.read(
              translationDbProvider(activeLang).future,
            );
            if (transDb != null) {
              final tRows = await transDb
                  .customSelect(
                    'SELECT line_id, translation '
                    'FROM sentences '
                    'WHERE book_id = ? AND para_id = ? '
                    'ORDER BY line_id',
                    variables: [
                      Variable.withString(ref.bookId),
                      Variable.withInt(ref.paraId),
                    ],
                  )
                  .get();
              for (final row in tRows) {
                final t = row.data['translation'] as String?;
                if (t != null && t.isNotEmpty) {
                  transLineMap[row.data['line_id'] as int] = t;
                }
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
          isMatch = searchWords.any(
            (w) => normalizePaliFuzzy(lineTrans).contains(w),
          );
        }
        lines.add(
          SearchResultLine(
            lineId: row.data['line_id'] as int,
            pali: pali,
            translation: lineTrans,
            isMatch: isMatch,
          ),
        );
      }

      if (lines.isEmpty) return null;
      return SearchResultItem(
        bookId: ref.bookId,
        paraId: ref.paraId,
        lines: lines,
        showAllLines: true,
        highlightTerms: searchWords.isEmpty ? null : searchWords,
      );
    } catch (e) {
      debugPrint('[SEARCH] _buildAiResultItem failed: $e');
      return null;
    }
  }

  /// A cached heading row with its [normalizePaliFuzzy]-normalised title
  /// precomputed, so heading search scans the full list in memory without
  /// re-normalising on every keystroke. The headings table is static per
  /// database file, so the cache is safe for a whole session.
  List<RawHeading>? _cachedHeadings;

  /// Diacritic-insensitive heading search.
  ///
  /// The headings table stores Pāḷi titles with diacritics (e.g.
  /// "Sammādiṭṭhisuttaṃ"), and SQLite's `LIKE` compares them byte-for-byte,
  /// so a plain "sammaditthi" query could never match a title that carries
  /// diacritics — unlike the FTS5 content search, whose `remove_diacritics 1`
  /// tokenizer makes diacritics irrelevant. Matching is therefore done here:
  /// every heading title is normalised with the same [normalizePaliFuzzy]
  /// pipeline used for search terms, and a heading matches when every query
  /// word (also normalised) occurs inside it.
  List<HeadingResult> _filterHeadings(
    List<RawHeading> headings,
    String normalized,
    Map<String, BookInfo> bookMap,
  ) {
    // Clean punctuation the same way the FTS query is cleaned, then split
    // into words — each word must occur somewhere in the heading title.
    final cleaned = cleanPaliForIndexing(normalized);
    if (cleaned.isEmpty) return [];
    final words = normalizePaliFuzzy(
      cleaned,
    ).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return [];
    return _collectHeadings(
      headings,
      bookMap,
      (h) => h.key.isNotEmpty && words.every(h.key.contains),
    );
  }

  /// The first 10 [headings] that pass [matches], one per book and title.
  List<HeadingResult> _collectHeadings(
    List<RawHeading> headings,
    Map<String, BookInfo> bookMap,
    bool Function(RawHeading) matches,
  ) {
    final results = <HeadingResult>[];
    final seen = <String>{};
    for (final h in headings) {
      if (!matches(h)) continue;

      // Deduplicate by book_id + title to avoid showing the same
      // heading multiple times (e.g. when multiple para_ids match).
      final key = '${h.bookId}:${h.title}';
      if (seen.contains(key)) continue;
      seen.add(key);

      final book = bookMap[h.bookId];
      results.add(
        HeadingResult(
          bookId: h.bookId,
          paraId: h.paraId,
          title: h.title,
          level: h.level,
          bookName: book?.bookName,
        ),
      );
      if (results.length >= 10) break;
    }
    return results;
  }

  /// Load every row of the `headings` table once, caching it in memory so
  /// repeated searches don't re-query the database.
  Future<List<RawHeading>> _allHeadings(EpitakaDatabase epitakaDb) async {
    final cached = _cachedHeadings;
    if (cached != null) return cached;
    // The warm-up and the first search usually ask at the same time; on a
    // Pixel 8 Pro they built the list twice, 300 ms apart.
    return _headingsBuild ??= _buildHeadings(
      epitakaDb,
    ).whenComplete(() => _headingsBuild = null);
  }

  Future<List<RawHeading>>? _headingsBuild;

  Future<List<RawHeading>> _buildHeadings(EpitakaDatabase epitakaDb) async {
    _headingsBuildCount++;
    final headingsSw = Stopwatch()..start();
    // Skip `level = 10` rows: those are pure numeric section markers
    // (122k of them in the real corpus — "1", "2", …), not titles a user
    // would search for, and they'd flood the results. The app's section
    // logic (`level < 10`) uses the same rule to identify real titles.
    final rows = await epitakaDb
        .customSelect(
          'SELECT book_id, para_id, title, level '
          'FROM headings '
          'WHERE level IS NULL OR level < 10 '
          'ORDER BY book_id, para_id',
        )
        .get();
    final sqlMs = headingsSw.elapsedMilliseconds;

    // The main-isolate share of the build after the query: what is left
    // to freeze a frame once the cleaning runs elsewhere.
    final mainSw = Stopwatch()..start();
    final titles = [
      for (final row in rows) (row.data['title'] as String?) ?? '',
    ];
    final keysFuture = _headingKeysInBackground(titles);
    mainSw.stop();
    final keys = await keysFuture;
    mainSw.start();
    final headings = <RawHeading>[
      for (var i = 0; i < rows.length; i++)
        (
          bookId: rows[i].data['book_id'] as String,
          paraId: rows[i].data['para_id'] as int,
          title: titles[i],
          level: rows[i].data['level'] as int?,
          key: keys[i],
        ),
    ];
    mainSw.stop();
    // Don't cache an empty result — a concurrent database swap may have
    // raced this query; an empty cache would poison every later search.
    if (headings.isNotEmpty) {
      _cachedHeadings = headings;
    }
    debugPrint(
      '[PERF] search headings ms=${headingsSw.elapsedMilliseconds} '
      'rows=${headings.length} sql=$sqlMs main=${mainSw.elapsedMilliseconds}',
    );
    return headings;
  }

  // Static, so the job's closure cannot capture the notifier, which cannot
  // be sent to another isolate.
  static RegexJob<List<({List<bool> lines, List<String> pieces})>>
  _startRegexMarks(String pattern, List<List<String>> paragraphs) =>
      startRegexJob(() => _regexMarks(pattern, paragraphs));

  /// For each paragraph's Pāli lines: which lines [pattern] matches in
  /// their own search copy, and up to 20 distinct pieces it matches in the
  /// paragraph's copy, cleaned as the index cleaned it.
  static List<({List<bool> lines, List<String> pieces})> _regexMarks(
    String pattern,
    List<List<String>> paragraphs,
  ) {
    final regex = compileSearchRegex(pattern);
    String copy(String text) => cleanPaliForIndexing(text.toLowerCase());
    return [
      for (final lines in paragraphs)
        (
          lines: [for (final l in lines) regex.hasMatch(copy(l))],
          pieces: {
            for (final m in regex.allMatches(copy(lines.join(' '))))
              if (m.end > m.start) m[0]!,
          }.take(20).toList(),
        ),
    ];
  }

  // Static, so the isolate's closure cannot capture the notifier, which
  // cannot be sent to another isolate. Cleaning 38,069 titles is too long
  // for one frame on a phone.
  static Future<List<String>> _headingKeysInBackground(List<String> titles) =>
      titles.isEmpty
      ? Future.value(const <String>[])
      : Isolate.run(() => [for (final t in titles) normalizePaliFuzzy(t)]);

  int _headingsBuildCount = 0;

  /// How many times the heading list was read and cleaned.
  @visibleForTesting
  int get headingsBuildCount => _headingsBuildCount;

  @visibleForTesting
  Future<List<RawHeading>> headingsForTesting() async =>
      _allHeadings(await _epitakaDb());

  /// Get suggestions for autocomplete.
  ///
  /// Only returns suggestions once the prefix is at least
  /// [kSearchSuggestionMinLength] characters — short prefixes are too
  /// ambiguous to suggest from.
  final Map<String, List<SearchSuggestion>> _suggestionCache = {};

  Future<List<SearchSuggestion>> getSuggestions(String prefix) async {
    if (prefix.trim().length < kSearchSuggestionMinLength) return [];
    final key = prefix.trim().toLowerCase();
    final cached = _suggestionCache[key];
    if (cached != null) return cached;
    try {
      final appDb = await _ref.read(appDbProvider.future);
      final result = await appDb.getSearchSuggestions(prefix, limit: 10);
      while (_suggestionCache.length >= 100) {
        _suggestionCache.remove(_suggestionCache.keys.first);
      }
      _suggestionCache[key] = result;
      return result;
    } catch (_) {
      return [];
    }
  }

  /// Clear the search state.
  void clear() {
    _searchGen++;
    _cancelRegexJobs();
    _debounce?.cancel();
    _aiPassages = null;
    _aiHighlightTerms = const [];
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

  const AiPassageRef({required this.bookId, required this.paraId, this.text});
}

final expandSearchResultsProvider = StateProvider<bool>((ref) => true);
