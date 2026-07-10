import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/epitaka_database.dart';
import '../../../core/models/app_models.dart';
import '../../../core/providers/app_db_provider.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/translation_registry_provider.dart';
import '../../indexing/index_controller.dart';
import '../../indexing/index_state.dart';

// ── Model types (public, shared) ─────────────────────────────────────────

/// A single search result item (one vripage or para match).
class SearchResultItem {
  final String bookId;
  final String vripage;
  final String snippet;
  final String paliText;
  final String? translation;
  final int? firstParaId;

  const SearchResultItem({
    required this.bookId,
    required this.vripage,
    required this.snippet,
    this.paliText = '',
    this.translation,
    this.firstParaId,
  });
}

/// A group of search results for one book.
class SearchResultGroup {
  final BookInfo book;
  final List<SearchResultItem> items;
  bool isExpanded;

  SearchResultGroup({
    required this.book,
    required this.items,
    this.isExpanded = true,
  });

  int get totalResults => items.length;
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

class SearchResults extends SearchState {
  final String query;
  final List<SearchResultGroup> groups;
  final int totalResults;
  final bool fuzzy;
  final int distance;
  final List<SearchSuggestion> suggestions;
  final List<BookFilterOption> filters;

  const SearchResults({
    required this.query,
    required this.groups,
    required this.totalResults,
    this.fuzzy = false,
    this.distance = 0,
    this.suggestions = const [],
    this.filters = const [],
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

  SearchNotifier(this._ref) : super(const SearchIdle());

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Initialize the search index (Pali + available translations) on first run.
  /// Uses the app-wide overlay for progress display.
  Future<void> ensureIndexBuilt() async {
    debugPrint('[SEARCH] ensureIndexBuilt() called');

    final appDb = await _ref.watch(appDbProvider.future);
    final epitakaDb = await _ref.watch(epitakaDbProvider.future);

    // Check what needs building
    final paliBuilt = await appDb.isSearchIndexBuilt();

    final available = await _ref.watch(translationRegistryProvider.future);
    final toBuild = available.where((t) => t.isAvailable).toList();

    final translationToBuild = <AvailableTranslation>[];
    for (final trans in toBuild) {
      final alreadyBuilt =
          await appDb.isTranslationIndexBuilt(trans.languageCode);
      if (!alreadyBuilt) translationToBuild.add(trans);
    }

    // If everything already built, do nothing
    if (paliBuilt && translationToBuild.isEmpty) return;

    // Index build is now handled by IndexController.
    // If the index isn't built, trigger the retry (which will rebuild).
    debugPrint('[SEARCH] Index needs building, triggering controller…');
    try {
      await _ref.read(indexControllerProvider.notifier).retry();
    } catch (e) {
      debugPrint('[SEARCH] Index build FAILED: $e');
    }
  }

  /// Execute the search across Pāli FTS and available translation FTS.
  Future<void> search({
    required String query,
    bool fuzzy = false,
    int distance = 0,
    List<BookFilterOption>? activeFilters,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      state = const SearchIdle();
      return;
    }

    state = const SearchLoading();

    try {
      final appDb = await _ref.watch(appDbProvider.future);
      final epitakaDb = await _ref.watch(epitakaDbProvider.future);

      // Ensure Pali index is built (with overlay progress)
      final paliBuilt = await appDb.isSearchIndexBuilt();
      if (!paliBuilt) {
        // Use ensureIndexBuilt to show overlay with progress
        await ensureIndexBuilt();
      }

      // Get all books for info and filtering
      final allBooks = await _loadAllBooks(epitakaDb);
      final allowedBookIds = _getAllowedBookIds(allBooks, activeFilters);
      final filters = _buildFilterOptions(allBooks);

      // ── 1. Search Pāli FTS ──────────────────────────────────────────
      final paliRows =
          await appDb.searchFts(query, fuzzy: fuzzy, distance: distance);

      // ── 2. Search translation FTS for each available language ────────
      final allRows = <SearchResultRow>[...paliRows];
      try {
        final available =
            await _ref.watch(translationRegistryProvider.future);
        for (final trans in available) {
          if (!trans.isAvailable) continue;
          final translationRows = await appDb.searchTranslationFts(
            trans.languageCode,
            query,
            fuzzy: fuzzy,
            distance: distance,
          );
          allRows.addAll(translationRows);
        }
      } catch (_) {
        // Translation search is optional; continue with Pali results
      }

      if (allRows.isEmpty) {
        state = SearchResults(
          query: query,
          groups: [],
          totalResults: 0,
          fuzzy: fuzzy,
          distance: distance,
          filters: filters,
        );
        return;
      }

      // Deduplicate by (bookId, firstParaId) — keep first occurrence
      final seen = <String>{};
      final deduped = <SearchResultRow>[];
      for (final row in allRows) {
        final key = row.firstParaId != null
            ? '${row.bookId}-${row.firstParaId}'
            : '${row.bookId}-${row.vripage}';
        if (seen.contains(key)) continue;
        seen.add(key);
        deduped.add(row);
      }

      // ── Enrich Pali results with exact para_id + translation ────────
      // For each Pali vripage result, find the para_id where the searched
      // word actually occurs (pali_definition JOIN sentences), then fetch
      // the translation for that exact para_id.
      final enrichedPaliRows = await _enrichWithTranslations(
        deduped.where((r) => r.firstParaId == null).toList(),
        epitakaDb,
        searchQuery: normalized,
      );
      // Replace the unenriched rows with enriched ones
      var finalRows = deduped
          .where((r) => r.firstParaId != null)
          .toList();
      finalRows.addAll(enrichedPaliRows);

      // Group results by book
      final groups = _groupResults(finalRows, allBooks, allowedBookIds);

      state = SearchResults(
        query: query,
        groups: groups,
        totalResults: deduped.length,
        fuzzy: fuzzy,
        distance: distance,
        filters: filters,
      );
    } catch (e) {
      state = SearchError('Search failed: $e');
    }
  }

  /// For each Pali search result (which has vripage but no paraId), look up
  /// the exact para_id where the searched word occurs (via pali_definition
  /// + sentences JOIN) and then fetch the translation from the active
  /// translation DB.
  Future<List<SearchResultRow>> _enrichWithTranslations(
    List<SearchResultRow> paliRows,
    EpitakaDatabase epitakaDb, {
    String searchQuery = '',
  }) async {
    if (paliRows.isEmpty) return paliRows;

    // Extract the first search term from the user's query
    final searchTerm = searchQuery
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .firstOrNull ??
        '';

    // ── Bulk lookup para_ids via pali_definition (#) ───────────────────
    // Use pali_definition (which records every occurring word) JOINed
    // with sentences (which has the vripage column) to find the exact
    // para_id where the searched word appears on each (book_id, vripage).
    // This replaces the old approach of MIN(para_id) which jumped to the
    // first paragraph of the page instead of the matching location.
    //
    // (#) The pali_definition table is populated by a companion build step
    // that analyses every word in the corpus. It stores the inflected
    // `word` column per (book_id, para_id, line_id).
    final conditions = <String>[];
    final params = <Variable<Object>>[];
    if (searchTerm.isNotEmpty) {
      params.add(Variable.withString('$searchTerm%'));
    }
    for (final row in paliRows) {
      conditions.add('(s.book_id = ? AND s.vripage = ?)');
      params.add(Variable.withString(row.bookId));
      params.add(Variable.withString(row.vripage));
    }

    Map<String, int> pageToParaId = {};
    try {
      if (searchTerm.isNotEmpty) {
        // Query 1: find exact para_id where the word occurs using
        // pali_definition + sentences JOIN
        final matchRows = await epitakaDb.customSelect(
          'SELECT pd.book_id, s.vripage, MIN(pd.para_id) as match_para_id '
          'FROM pali_definition pd '
          'JOIN sentences s ON s.book_id = pd.book_id '
          '  AND s.para_id = pd.para_id '
          '  AND s.line_id = pd.line_id '
          'WHERE pd.word LIKE ?1 '
          '  AND (${conditions.join(' OR ')}) '
          'GROUP BY pd.book_id, s.vripage',
          variables: params,
        ).get();

        pageToParaId = {
          for (final r in matchRows)
            '${r.data['book_id']}-${r.data['vripage']}':
                r.data['match_para_id'] as int,
        };
      }

      // Fallback: for vripages where the word wasn't found in
      // pali_definition (e.g. phrase searches), use MIN(para_id).
      if (pageToParaId.length < paliRows.length) {
        final fallbackConditions = <String>[];
        final fallbackParams = <Variable<Object>>[];
        for (final row in paliRows) {
          final key = '${row.bookId}-${row.vripage}';
          if (pageToParaId.containsKey(key)) continue;
          fallbackConditions.add('(book_id = ? AND vripage = ?)');
          fallbackParams.add(Variable.withString(row.bookId));
          fallbackParams.add(Variable.withString(row.vripage));
        }
        if (fallbackConditions.isNotEmpty) {
          final fallbackRows = await epitakaDb.customSelect(
            'SELECT book_id, vripage, MIN(para_id) as first_para_id '
            'FROM sentences '
            'WHERE ${fallbackConditions.join(' OR ')} '
            'GROUP BY book_id, vripage',
            variables: fallbackParams,
          ).get();

          for (final r in fallbackRows) {
            final key = '${r.data['book_id']}-${r.data['vripage']}';
            if (!pageToParaId.containsKey(key)) {
              pageToParaId[key] = r.data['first_para_id'] as int;
            }
          }
        }
      }
    } catch (_) {
      // If query fails, fall through to MIN(para_id) fallback below
      // rather than leaving para_ids empty
      try {
        final conditions = <String>[];
        final params = <Variable<Object>>[];
        for (final row in paliRows) {
          conditions.add('(book_id = ? AND vripage = ?)');
          params.add(Variable.withString(row.bookId));
          params.add(Variable.withString(row.vripage));
        }
        final fallbackRows = await epitakaDb.customSelect(
          'SELECT book_id, vripage, MIN(para_id) as first_para_id '
          'FROM sentences '
          'WHERE ${conditions.join(' OR ')} '
          'GROUP BY book_id, vripage',
          variables: params,
        ).get();

        pageToParaId = {
          for (final r in fallbackRows)
            '${r.data['book_id']}-${r.data['vripage']}':
                r.data['first_para_id'] as int,
        };
      } catch (_) {}
    }

    // ── Bulk lookup translations ──────────────────────────────────────
    final allParaIds = pageToParaId.values.toSet();
    Map<String, String> paraToTranslation = {};

    try {
      final activeLang =
          _ref.read(activeTranslationLangProvider);
      final translationDb =
          await _ref.read(translationDbProvider(activeLang).future);

      if (translationDb != null && allParaIds.isNotEmpty) {
        final tConditions = <String>[];
        final tParams = <Variable<Object>>[];
        for (final pid in allParaIds) {
          tConditions.add('para_id = ?');
          tParams.add(Variable.withInt(pid));
        }

        final tRows = await translationDb.customSelect(
          "SELECT book_id, para_id, group_concat(translation, ' ') as trans_text "
          'FROM sentences '
          'WHERE ${tConditions.join(' OR ')} '
          'GROUP BY book_id, para_id',
          variables: tParams,
        ).get();

        paraToTranslation = {
          for (final r in tRows)
            '${r.data['book_id']}-${r.data['para_id']}':
                r.data['trans_text'] as String,
        };
      }
    } catch (_) {
      // Translations are optional
    }

    // ── Enrich each row ───────────────────────────────────────────────
    return paliRows.map((row) {
      final key = '${row.bookId}-${row.vripage}';
      final paraId = pageToParaId[key];
      final trans = paraId != null
          ? paraToTranslation['${row.bookId}-$paraId']
          : null;
      return SearchResultRow(
        bookId: row.bookId,
        vripage: row.vripage,
        snippet: row.snippet,
        paliText: row.paliText,
        firstParaId: paraId,
        translation: trans,
      );
    }).toList();
  }

  /// Get autocomplete suggestions for [prefix].
  Future<List<SearchSuggestion>> getSuggestions(String prefix) async {
    if (prefix.trim().isEmpty) return [];
    try {
      final appDb = await _ref.watch(appDbProvider.future);
      return appDb.getSearchSuggestions(prefix, limit: 10);
    } catch (_) {
      return [];
    }
  }

  /// Toggle a filter option and re-run the current query.
  Future<void> toggleFilter(int filterIndex) async {
    if (state is! SearchResults) return;
    final current = state as SearchResults;

    final newFilters = List<BookFilterOption>.generate(
      current.filters.length,
      (i) {
        final f = current.filters[i];
        return BookFilterOption(
          label: f.label,
          category: f.category,
          nikaya: f.nikaya,
          selected: i == filterIndex ? !f.selected : f.selected,
        );
      },
    );

    await search(
      query: current.query,
      fuzzy: current.fuzzy,
      distance: current.distance,
      activeFilters: newFilters,
    );
  }

  /// Toggle expanded state of a result group.
  void toggleGroupExpanded(int groupIndex) {
    if (state is! SearchResults) return;
    final current = state as SearchResults;
    final newGroups = [...current.groups];
    if (groupIndex < newGroups.length) {
      newGroups[groupIndex] = SearchResultGroup(
        book: current.groups[groupIndex].book,
        items: current.groups[groupIndex].items,
        isExpanded: !current.groups[groupIndex].isExpanded,
      );
      state = SearchResults(
        query: current.query,
        groups: newGroups,
        totalResults: current.totalResults,
        fuzzy: current.fuzzy,
        distance: current.distance,
        filters: current.filters,
        suggestions: current.suggestions,
      );
    }
  }

  /// Clear the search state.
  void clear() {
    _debounce?.cancel();
    state = const SearchIdle();
  }

  // ── Private helpers ──────────────────────────────────────────────────

  Future<List<BookInfo>> _loadAllBooks(EpitakaDatabase epitakaDb) async {
    final bookRows = await epitakaDb.select(epitakaDb.books).get();
    return bookRows
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

  Set<String> _getAllowedBookIds(
    List<BookInfo> allBooks,
    List<BookFilterOption>? activeFilters,
  ) {
    if (activeFilters == null || activeFilters.isEmpty) {
      return allBooks.map((b) => b.bookId).toSet();
    }

    final activeCategories = activeFilters
        .where((f) => f.selected && f.category != null)
        .map((f) => f.category!)
        .toSet();
    final activeNikayas = activeFilters
        .where((f) => f.selected && f.nikaya != null)
        .map((f) => f.nikaya!)
        .toSet();

    if (activeCategories.isEmpty && activeNikayas.isEmpty) {
      return allBooks.map((b) => b.bookId).toSet();
    }

    return allBooks
        .where((b) {
          final matchCategory = activeCategories.isEmpty ||
              (b.category != null && activeCategories.contains(b.category));
          final matchNikaya = activeNikayas.isEmpty ||
              (b.nikaya != null && activeNikayas.contains(b.nikaya));
          return matchCategory && matchNikaya;
        })
        .map((b) => b.bookId)
        .toSet();
  }

  List<SearchResultGroup> _groupResults(
    List<SearchResultRow> rows,
    List<BookInfo> allBooks,
    Set<String> allowedBookIds,
  ) {
    final bookMap = <String, BookInfo>{};
    for (final b in allBooks) {
      bookMap[b.bookId] = b;
    }

    final grouped = <String, List<SearchResultRow>>{};
    for (final row in rows) {
      if (!allowedBookIds.contains(row.bookId)) continue;
      grouped.putIfAbsent(row.bookId, () => []).add(row);
    }

    // Sort books by their id order
    final sortedBookIds = grouped.keys.toList()
      ..sort((a, b) {
        final bookA = bookMap[a];
        final bookB = bookMap[b];
        final idA = bookA?.id ?? 0;
        final idB = bookB?.id ?? 0;
        return idA.compareTo(idB);
      });

    final defaultExpanded = _ref.read(expandSearchResultsProvider);

    return sortedBookIds.map((bookId) {
      final book = bookMap[bookId] ??
          BookInfo(id: 0, bookId: bookId, bookName: bookId);
      final items = grouped[bookId]!.map((row) {
        return SearchResultItem(
          bookId: row.bookId,
          vripage: row.vripage,
          snippet: row.snippet,
          paliText: row.paliText,
          translation: row.translation,
          firstParaId: row.firstParaId,
        );
      }).toList();

      return SearchResultGroup(
        book: book,
        items: items,
        isExpanded: defaultExpanded,
      );
    }).toList();
  }

  List<BookFilterOption> _buildFilterOptions(List<BookInfo> allBooks) {
    final categories = allBooks
        .map((b) => b.category)
        .where((c) => c != null && c.isNotEmpty)
        .toSet()
        .map((c) => BookFilterOption(label: c!, category: c, selected: true));

    final nikayas = allBooks
        .map((b) => b.nikaya)
        .where((n) => n != null && n.isNotEmpty)
        .toSet()
        .map((n) => BookFilterOption(label: n!, nikaya: n, selected: true));

    return [...categories, ...nikayas];
  }
}

// ── Providers ────────────────────────────────────────────────────────────

/// Whether to expand search result groups by default.
final expandSearchResultsProvider = StateProvider<bool>((ref) => true);
