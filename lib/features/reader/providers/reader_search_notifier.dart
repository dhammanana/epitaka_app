import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart' show settingsProvider;
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
  String? get effectiveQuery =>
      showSearchBar && query.isNotEmpty ? query : null;

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
      matchParaIds: clearMatches
          ? const []
          : (matchParaIds ?? this.matchParaIds),
      matchLineIds: clearMatches
          ? const []
          : (matchLineIds ?? this.matchLineIds),
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

  /// Normalized text of every line of the last searched book, in reading
  /// order, so later queries skip the normalization (over a second per
  /// query in the largest books on a fast phone). Weak, so the cache never
  /// keeps a closed book's paragraphs in memory.
  WeakReference<List<ParagraphData>>? _normalizedSource;
  bool? _normalizedHideVariants;
  List<String> _normalizedLines = const [];
  String? _normalizedBookId;

  /// Text editing controller for the search field.
  final TextEditingController searchController = TextEditingController();

  /// Focus node for the search field.
  final FocusNode searchFocusNode = FocusNode();

  ReaderSearchNotifier(this._ref) : super(const InBookSearchState()) {
    // A book leaves memory when its last tab closes (readerDataProvider);
    // its normalized text, about the size of the book, goes with it.
    _ref.listen(readerTabsProvider, (_, tabs) {
      final bookId = _normalizedBookId;
      if (bookId != null && !tabs.tabs.any((t) => t.bookId == bookId)) {
        _normalizedSource = null;
        _normalizedHideVariants = null;
        _normalizedLines = const [];
        _normalizedBookId = null;
      }
    });
  }

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

  /// Drop a search that is still waiting on the debounce.
  void cancelPendingSearch() => _searchTimer?.cancel();

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
      state = state.copyWith(query: '', clearMatches: true);
      return;
    }

    final perfSw = Stopwatch()..start();
    int linesSeen = 0;
    _lastNormalizedCount = 0;
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

      // Normalize query terms (normalizePaliFuzzy cleans internally).
      final normalizedTerms = words
          .map(normalizePaliFuzzy)
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

      // Search using on-demand normalized text — no DB queries. The
      // variant toggle is read ONCE per search so every line is judged
      // against the same setting.
      final hideVariants = _ref.read(
        settingsProvider.select((s) => s.stripVariantAnnotations),
      );
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

      // A reload or remarks refresh replaces the paragraph list, and the
      // variant toggle changes what a line contains; either one makes the
      // cached strings wrong.
      if (!identical(_normalizedSource?.target, readerState.paragraphs) ||
          _normalizedHideVariants != hideVariants) {
        final normalizedLines = <String>[];
        for (final para in readerState.paragraphs) {
          for (final line in para.lines) {
            // Normalized text is computed on-demand (normalizedText is
            // always empty today — pre-computation during book load was
            // removed as an optimization).
            if (line.normalizedText.isEmpty) _lastNormalizedCount++;
            normalizedLines.add(
              line.normalizedText.isEmpty
                  ? _normalizeLine(
                      line.paliText,
                      line.translations,
                      hideVariants: hideVariants,
                    )
                  : line.normalizedText,
            );
          }
        }
        _normalizedLines = normalizedLines;
        _normalizedSource = WeakReference(readerState.paragraphs);
        _normalizedHideVariants = hideVariants;
        _normalizedBookId = activeTab.bookId;
      }

      for (final para in readerState.paragraphs) {
        for (final line in para.lines) {
          final normalized = _normalizedLines[linesSeen++];
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
      debugPrint(
        '[PERF] find ms=${perfSw.elapsedMilliseconds} lines=$linesSeen '
        'normalized=$_lastNormalizedCount matches=${matchParas.length}',
      );
    } catch (e) {
      developer.log('[SEARCH] Error: $e', name: 'epitaka.reader.search');
      if (_lastSearchQuery == romanQuery) {
        state = state.copyWith(query: '', clearMatches: true);
      }
    }
  }

  /// Compute normalized (diacritic-insensitive) text for a single line
  /// on-demand (normalizedText is always empty today; pre-computation at
  /// book load was removed as an optimization).
  ///
  /// In-book search follows the "Show variant readings" toggle for the
  /// PALI text: when the user hides variants (strip == true), only the
  /// main reading is searched; when variants are shown, their words are
  /// searchable too. TRANSLATION brackets are translator additions
  /// ("[monks]"), not variant readings — they are always searchable,
  /// whatever the toggle says.
  String _normalizeLine(
    String? pali,
    Map<String, String> translations, {
    bool? hideVariants,
  }) {
    final bool hide = hideVariants ??
        _ref.read(
          settingsProvider.select((s) => s.stripVariantAnnotations),
        );
    final parts = <String>[];
    if (pali != null && pali.trim().isNotEmpty) {
      parts.add(
        normalizePaliFuzzy(
          cleanPaliForIndexing(pali, stripVariantContent: hide),
        ),
      );
    }
    for (final t in translations.values) {
      if (t.trim().isNotEmpty) {
        parts.add(normalizePaliFuzzy(cleanPaliForIndexing(t)));
      }
    }
    if (parts.isEmpty) return '';
    return parts.join(' ');
  }

  int _lastNormalizedCount = 0;

  /// How many lines the last query had to normalize; the cache test asserts
  /// that a repeat query needs none.
  @visibleForTesting
  int get lastNormalizedCount => _lastNormalizedCount;

  /// How many normalized lines the cache holds.
  @visibleForTesting
  int get cachedLineCount => _normalizedLines.length;

  /// Test seam for [_normalizeLine] (private): lets tests assert that the
  /// variant-content mode follows the settings toggle.
  @visibleForTesting
  String normalizeLineForTesting(
    String? pali,
    Map<String, String> translations,
  ) => _normalizeLine(pali, translations);
}

/// Provider for the in-book search state and controls.
final inBookSearchProvider =
    StateNotifierProvider.autoDispose<ReaderSearchNotifier, InBookSearchState>(
      (ref) => ReaderSearchNotifier(ref),
    );
