import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/pali_search_utils.dart';
import '../../../core/utils/velthuis.dart';
import '../providers/reader_provider.dart';
import '../providers/reader_tabs_provider.dart';

/// In-book search state for a single reader session.
class InBookSearchState {
  /// Whether the search bar is visible.
  final bool showSearchBar;

  /// The current search query.
  final String query;

  /// ParaIds that match the current query.
  final List<int> matchParaIds;

  /// Corresponding lineIds for each match.
  final List<int> matchLineIds;

  /// Index into [matchParaIds] / [matchLineIds] for the selected match.
  final int matchIndex;

  const InBookSearchState({
    this.showSearchBar = false,
    this.query = '',
    this.matchParaIds = const [],
    this.matchLineIds = const [],
    this.matchIndex = -1,
  });

  bool get hasMatches => matchParaIds.isNotEmpty;
  int get matchCount => matchParaIds.length;
  int get currentMatchDisplay => matchIndex + 1; // 1-based
  String? get effectiveQuery => showSearchBar && query.isNotEmpty ? query : null;

  InBookSearchState copyWith({
    bool? showSearchBar,
    String? query,
    List<int>? matchParaIds,
    List<int>? matchLineIds,
    int? matchIndex,
    bool clearMatches = false,
  }) {
    return InBookSearchState(
      showSearchBar: showSearchBar ?? this.showSearchBar,
      query: query ?? this.query,
      matchParaIds: clearMatches ? const [] : (matchParaIds ?? this.matchParaIds),
      matchLineIds: clearMatches ? const [] : (matchLineIds ?? this.matchLineIds),
      matchIndex: clearMatches ? -1 : (matchIndex ?? this.matchIndex),
    );
  }
}

/// Notifier managing in-book search state and execution.
class ReaderSearchNotifier extends StateNotifier<InBookSearchState> {
  final Ref _ref;

  /// Debounce timer for search.
  Timer? _searchTimer;

  /// Most recent query sent to [_runSearch], used to ignore stale results.
  String _lastSearchQuery = '';

  /// Text editing controller for the search field.
  final TextEditingController searchController = TextEditingController();

  /// Focus node for the search field.
  final FocusNode searchFocusNode = FocusNode();

  ReaderSearchNotifier(this._ref) : super(const InBookSearchState());

  @override
  void dispose() {
    _searchTimer?.cancel();
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  /// Toggle the search bar on/off. When closing, clears all state.
  void toggleSearchBar() {
    if (state.showSearchBar) {
      _closeSearch();
    } else {
      state = state.copyWith(showSearchBar: true);
      // Focus the search field after the widget appears
      WidgetsBinding.instance.addPostFrameCallback((_) {
        searchFocusNode.requestFocus();
      });
    }
  }

  /// Called when the search query changes (debounced).
  void onQueryChanged(String query) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      _runSearch(query);
    });
  }

  /// Called when the user submits the search (Enter key).
  void onSubmitted(String query) {
    _searchTimer?.cancel();
    _runSearch(query);
  }

  /// Jump to the next match.
  void nextMatch() {
    if (!state.hasMatches) return;
    final next = (state.matchIndex + 1) % state.matchCount;
    state = state.copyWith(matchIndex: next);
  }

  /// Jump to the previous match.
  void previousMatch() {
    if (!state.hasMatches) return;
    final prev = (state.matchIndex - 1 + state.matchCount) % state.matchCount;
    state = state.copyWith(matchIndex: prev);
  }

  /// Close the search bar and reset state.
  void _closeSearch() {
    _searchTimer?.cancel();
    searchController.clear();
    state = const InBookSearchState();
  }

  /// Run the in-book search against the loaded paragraph data.
  /// Computes diacritic-normalized text on-demand for each line (using
  /// the same cleanPaliForIndexing + normalizePaliFuzzy pipeline), so the
  /// expensive normalization does not block book opening (~590ms savings).
  Future<void> _runSearch(String query) async {
    final activeTab = _ref.read(readerTabsProvider).activeTab;
    if (activeTab == null) return;

    // Convert the query from any Pali script (and Velthuis notation) to
    // Roman IAST. The reader always searches against Roman-script text
    // (the database stores Pāli in romanised form regardless of the
    // display script), so a word typed in Myanmar, Thai, Tamil, etc.
    // must be converted to Roman before it can match.
    final romanQuery = velthuis(query);

    _lastSearchQuery = romanQuery;

    if (romanQuery.trim().isEmpty) {
      state = state.copyWith(
        query: '',
        clearMatches: true,
      );
      return;
    }

    try {
      final words = romanQuery
          .trim()
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();

      if (words.isEmpty) {
        state = state.copyWith(query: '', clearMatches: true);
        return;
      }

      // Normalize query terms
      final normalizedTerms = words
          .map((w) => normalizePaliFuzzy(cleanPaliForIndexing(w)))
          .where((n) => n.isNotEmpty)
          .toList();

      if (normalizedTerms.isEmpty) {
        state = state.copyWith(query: '', clearMatches: true);
        return;
      }

      final readerState = _ref.read(readerDataProvider(activeTab.bookId));
      if (readerState.paragraphs.isEmpty) {
        state = state.copyWith(query: '', clearMatches: true);
        return;
      }

      // Search using pre-computed normalized text cache — no DB queries
      final seenKeys = <int>{};
      final matchParas = <int>[];
      final matchLines = <int>[];

      void addMatch(int paraId, int lineId) {
        final key = paraId * 1000000 + lineId;
        if (seenKeys.add(key)) {
          matchParas.add(paraId);
          matchLines.add(lineId);
        }
      }

      for (final para in readerState.paragraphs) {
        for (final line in para.lines) {
          // Compute normalized text on-demand if it wasn't pre-computed
          // during book load (optimization: saves ~590ms on book open).
          final normalized = line.normalizedText.isEmpty
              ? _normalizeLine(line.paliText, line.translations)
              : line.normalizedText;
          if (normalized.isEmpty) continue;

          bool allMatch = true;
          for (final term in normalizedTerms) {
            if (!normalized.contains(term)) {
              allMatch = false;
              break;
            }
          }
          if (allMatch) {
            addMatch(para.paraId, line.lineId);
          }
        }
      }

      // Guard against stale results
      if (_lastSearchQuery != romanQuery) return;

      // Store the Roman query so the paragraph highlight can convert it
      // back to the display script for matching (see
      // convertSearchQueryForScript in reading_paragraph.dart).
      state = state.copyWith(
        query: romanQuery,
        matchParaIds: matchParas,
        matchLineIds: matchLines,
        matchIndex: matchParas.isEmpty ? -1 : 0,
      );
    } catch (e) {
      developer.log('[SEARCH] Error: $e', name: 'epitaka.reader.search');
      if (_lastSearchQuery == romanQuery) {
        state = state.copyWith(query: '', clearMatches: true);
      }
    }
  }

  /// Compute normalized (diacritic-insensitive) text for a single line
  /// on-demand. Mirrors [ReaderDataNotifier._normalizeLineText] without
  /// the cost of pre-computing for every line during book load.
  String _normalizeLine(String? pali, Map<String, String> translations) {
    final buf = StringBuffer();
    if (pali != null && pali.trim().isNotEmpty) {
      buf.write(pali);
    }
    for (final t in translations.values) {
      if (t.trim().isNotEmpty) {
        buf.write(' ');
        buf.write(t);
      }
    }
    final raw = buf.toString();
    if (raw.isEmpty) return raw;
    return normalizePaliFuzzy(cleanPaliForIndexing(raw));
  }
}

/// Provider for the in-book search state and controls.
final inBookSearchProvider =
    StateNotifierProvider.autoDispose<ReaderSearchNotifier, InBookSearchState>(
      (ref) => ReaderSearchNotifier(ref),
    );
