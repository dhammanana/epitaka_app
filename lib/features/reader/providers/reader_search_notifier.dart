import 'dart:async';
import 'dart:developer' as developer;
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart' show settingsProvider;
import '../../../core/utils/pali_search_utils.dart';
import '../../../core/utils/pali_script_converter.dart';
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

  /// Bumped by every search and every close. A search that waited for a
  /// background build writes nothing once the bar has closed (a tab switch
  /// closes it too), even when the same word is typed again.
  int _searchGen = 0;

  /// Normalized text of every line of the last searched book, in reading
  /// order, so later queries skip the normalization (over a second per
  /// query in the largest books on a fast phone). Weak, so the cache never
  /// keeps a closed book's paragraphs in memory.
  WeakReference<List<ParagraphData>>? _normalizedSource;
  bool? _normalizedHideVariants;
  List<String> _normalizedLines = const [];
  String? _normalizedBookId;

  /// The background build of [_normalizedLines] while it runs, so a query
  /// typed before it finishes waits for it instead of building again.
  Future<List<String>>? _pendingLines;

  /// Books with fewer lines than this normalize on the main isolate. A line
  /// costs about 68 µs on a Pixel 8 Pro (Pācity-y with English: 1.28 s for
  /// 18,716 lines), so 1,000 lines stay under a quarter of the 300 ms find
  /// budget, and a small book's matches arrive with no isolate round trip.
  @visibleForTesting
  static int backgroundMinLines = 1000;

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
        _pendingLines = null;
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
      _prepareActiveBook();
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

  /// Start normalizing the open book while the user is still typing, so the
  /// first query of a large book does not freeze the screen. A book still
  /// loading is left to the first query.
  void _prepareActiveBook() {
    final activeTab = _ref.read(readerTabsProvider).activeTab;
    if (activeTab == null) return;
    final paragraphs = _ref
        .read(readerDataProvider(activeTab.bookId))
        .paragraphs;
    if (paragraphs.isEmpty) return;
    _normalizedFor(
      paragraphs,
      _ref.read(settingsProvider.select((s) => s.stripVariantAnnotations)),
      activeTab.bookId,
    );
  }

  /// The normalized text of every line of [paragraphs], in reading order.
  /// Reuses the cache when it is for the same list and setting. A large
  /// book builds in a background isolate; the returned future completes
  /// when that build does.
  FutureOr<List<String>> _normalizedFor(
    List<ParagraphData> paragraphs,
    bool hideVariants,
    String bookId,
  ) {
    // A reload or remarks refresh replaces the paragraph list, and the
    // variant toggle changes what a line contains; either one makes the
    // cached strings wrong.
    if (identical(_normalizedSource?.target, paragraphs) &&
        _normalizedHideVariants == hideVariants) {
      return _pendingLines ?? _normalizedLines;
    }

    final prepareSw = Stopwatch()..start();
    final inputs = <_LineInput>[];
    var toNormalize = 0;
    for (final para in paragraphs) {
      for (final line in para.lines) {
        // Normalized text is computed on-demand (normalizedText is
        // always empty today — pre-computation during book load was
        // removed as an optimization).
        if (line.normalizedText.isEmpty) toNormalize++;
        inputs.add((line.paliText, line.translations, line.normalizedText));
      }
    }
    _lastNormalizedCount = toNormalize;
    _normalizedSource = WeakReference(paragraphs);
    _normalizedHideVariants = hideVariants;
    _normalizedBookId = bookId;

    if (inputs.length < backgroundMinLines) {
      _pendingLines = null;
      return _normalizedLines = _normalizeAll(inputs, hideVariants);
    }

    _normalizedLines = const [];
    final pending = _normalizeInBackground(inputs, hideVariants);
    // What the main isolate still pays to start the build: gathering the
    // lines and handing them to the new isolate.
    debugPrint(
      '[PERF] find prepare main=${prepareSw.elapsedMilliseconds} '
      'lines=${inputs.length}',
    );
    _pendingLines = pending;
    pending.then<void>(
      (lines) {
        if (identical(_pendingLines, pending)) {
          _normalizedLines = lines;
          _pendingLines = null;
        }
      },
      onError: (Object _) {
        // The waiting query reports the error; the next one tries again.
        if (identical(_pendingLines, pending)) {
          _pendingLines = null;
          _normalizedSource = null;
        }
      },
    );
    return pending;
  }

  // Static, so the isolate's closure cannot capture the notifier, whose
  // controllers and ref cannot be sent to another isolate.
  static Future<List<String>> _normalizeInBackground(
    List<_LineInput> inputs,
    bool hideVariants,
  ) => Isolate.run(() => _normalizeAll(inputs, hideVariants));

  static List<String> _normalizeAll(List<_LineInput> inputs, bool hide) => [
    for (final (pali, translations, normalized) in inputs)
      normalized.isEmpty
          ? _normalizeLine(pali, translations, hideVariants: hide)
          : normalized,
  ];

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
    _searchGen++;
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

    // Convert the query from any Pali script to Roman IAST (the find box
    // converts Velthuis itself, as it is typed). The reader always searches
    // against Roman-script text (the database stores Pāli in romanised form
    // regardless of the display script), so a word typed in Myanmar, Thai,
    // Tamil, etc. must be converted to Roman before it can match.
    final romanQuery = convertToRomanPali(query);

    final gen = ++_searchGen;

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

      final built = _normalizedFor(
        readerState.paragraphs,
        hideVariants,
        activeTab.bookId,
      );
      // Only a background build is awaited: a small book's matches stay
      // synchronous, with no extra event-loop turn.
      final normalizedLines = built is Future<List<String>>
          ? await built
          : built;
      if (!mounted || gen != _searchGen) return;

      for (final para in readerState.paragraphs) {
        for (final line in para.lines) {
          final normalized = normalizedLines[linesSeen++];
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
      if (mounted && gen == _searchGen) {
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
  static String _normalizeLine(
    String? pali,
    Map<String, String> translations, {
    required bool hideVariants,
  }) {
    final bool hide = hideVariants;
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
  ) => _normalizeLine(
    pali,
    translations,
    hideVariants: _ref.read(
      settingsProvider.select((s) => s.stripVariantAnnotations),
    ),
  );
}

/// One line's Pāli, its translations and any stored normalized text.
typedef _LineInput = (String?, Map<String, String>, String);

/// Provider for the in-book search state and controls.
final inBookSearchProvider =
    StateNotifierProvider.autoDispose<ReaderSearchNotifier, InBookSearchState>(
      (ref) => ReaderSearchNotifier(ref),
    );
