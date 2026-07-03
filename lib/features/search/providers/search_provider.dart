import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';

/// A single search result entry.
class SearchResult {
  final String bookId;
  final int paraId;
  final String? snippet;
  final String? bookName;

  const SearchResult({
    required this.bookId,
    required this.paraId,
    this.snippet,
    this.bookName,
  });
}

/// Search state: idle, loading, results, or error.
sealed class SearchState {
  const SearchState();
}

class SearchIdle extends SearchState {
  const SearchIdle();
}

class SearchLoading extends SearchState {
  const SearchLoading();
}

class SearchResults extends SearchState {
  final List<SearchResult> results;
  final String query;
  const SearchResults(this.results, this.query);
}

class SearchError extends SearchState {
  final String message;
  const SearchError(this.message);
}

/// Provider that manages search state.
///
/// Call [search] with a query string to trigger a database search across
/// all Pāli text in the Sentences table. Results include bookId, paraId,
/// and a short text snippet.
final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref);
});

class SearchNotifier extends StateNotifier<SearchState> {
  final Ref _ref;

  SearchNotifier(this._ref) : super(const SearchIdle());

  /// Execute a search across the Pāli text corpus.
  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = const SearchIdle();
      return;
    }

    state = const SearchLoading();

    try {
      final db = await _ref.read(epitakaDbProvider.future);

      // Search for partial matches in the pali column
      final likePattern = '%${query.trim()}%';
      final rows = await (db.select(db.sentences)
            ..where((s) => s.pali.like(likePattern))
            ..limit(100))
          .get();

      if (rows.isEmpty) {
        state = SearchResults([], query);
        return;
      }

      // Get book names for matched bookIds
      final matchedBookIds = rows.map((r) => r.bookId).toSet().toList();
      final bookRows = await (db.select(db.books)
            ..where((b) => b.bookId.isIn(matchedBookIds)))
          .get();
      final bookNames = <String, String>{};
      for (final book in bookRows) {
        bookNames[book.bookId] = book.bookName ?? book.bookId;
      }

      // Group results by bookId + paraId to avoid duplicates
      final seen = <String>{};
      final results = <SearchResult>[];
      for (final row in rows) {
        final key = '${row.bookId}-${row.paraId}';
        if (seen.contains(key)) continue;
        seen.add(key);

        // Build a short snippet from the matching text
        final pali = row.pali ?? '';
        final snippet = pali.length > 120
            ? '${pali.substring(0, 120)}…'
            : pali;

        results.add(SearchResult(
          bookId: row.bookId,
          paraId: row.paraId,
          snippet: snippet,
          bookName: bookNames[row.bookId],
        ));
      }

      state = SearchResults(results, query);
    } catch (e) {
      state = SearchError(e.toString());
    }
  }

  void clear() {
    state = const SearchIdle();
  }
}
