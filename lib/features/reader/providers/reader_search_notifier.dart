import 'dart:async';
import 'dart:developer' as developer;
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart' show settingsProvider;
import '../../../core/utils/pali_search_utils.dart';
import '../../../core/utils/pali_script_converter.dart';
import '../../search/services/regex_search.dart';
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

  /// rx mode: the pieces of text the pattern matched, joined by spaces. The
  /// reader highlights these as ordinary words; [query] keeps the pattern.
  final String? highlight;

  /// rx mode: why the pattern does not compile.
  final String? patternError;

  /// rx mode: the pattern ran past its time limit (spec K).
  final bool patternTooSlow;

  const InBookSearchState({
    this.showSearchBar = false,
    this.query = '',
    this.matchParaIds = const [],
    this.matchLineIds = const [],
    this.matchIndex = -1,
    this.highlight,
    this.patternError,
    this.patternTooSlow = false,
  });

  bool get hasMatches => matchParaIds.isNotEmpty;
  int get matchCount => matchParaIds.length;
  int get currentMatchDisplay => matchIndex + 1; // 1-based
  String? get effectiveQuery {
    if (!showSearchBar || query.isEmpty) return null;
    final h = highlight;
    if (h == null) return query;
    return h.isEmpty ? null : h;
  }

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
      highlight: clearMatches ? null : highlight,
      patternError: clearMatches ? null : patternError,
      patternTooSlow: !clearMatches && patternTooSlow,
    );
  }
}

/// The rx button of the reader's Find bar. Not saved, like the Search one.
final findRegexProvider = StateProvider<bool>((ref) => false);

/// The searchable text of every line of one book, in reading order, built
/// once per paragraph list and variant setting, so later queries skip the
/// cleaning (over a second per query in the largest books on a fast phone).
/// Weak, so it never keeps a closed book's paragraphs in memory.
class _LineTextCache<T> {
  _LineTextCache(this._build);

  /// Static: a large book builds in a background isolate, and a closure
  /// there cannot hold the notifier.
  final List<T> Function(List<_LineInput> inputs, bool hide) _build;

  WeakReference<List<ParagraphData>>? _source;
  bool? _hide;
  List<T> lines = const [];
  String? bookId;

  /// The background build while it runs, so a query typed before it ends
  /// waits for it instead of building again.
  Future<List<T>>? _pending;

  void clear() {
    _source = null;
    _hide = null;
    lines = const [];
    bookId = null;
    _pending = null;
  }

  /// The text of every line of [paragraphs]. [onBuild] sees the inputs when
  /// the cache has to build.
  FutureOr<List<T>> linesFor(
    List<ParagraphData> paragraphs,
    bool hide,
    String bookId, {
    void Function(List<_LineInput> inputs)? onBuild,
  }) {
    // A reload or remarks refresh replaces the paragraph list, and the
    // variant toggle changes what a line contains; either one makes the
    // cached strings wrong.
    if (identical(_source?.target, paragraphs) && _hide == hide) {
      return _pending ?? lines;
    }

    final prepareSw = Stopwatch()..start();
    final inputs = <_LineInput>[
      for (final para in paragraphs)
        for (final line in para.lines)
          (line.paliText, line.translations, line.normalizedText),
    ];
    onBuild?.call(inputs);
    _source = WeakReference(paragraphs);
    _hide = hide;
    this.bookId = bookId;

    if (inputs.length < ReaderSearchNotifier.backgroundMinLines) {
      _pending = null;
      return lines = _build(inputs, hide);
    }

    lines = const [];
    final build = _build;
    final pending = Isolate.run(() => build(inputs, hide));
    // What the main isolate still pays to start the build: gathering the
    // lines and handing them to the new isolate.
    debugPrint(
      '[PERF] find prepare main=${prepareSw.elapsedMilliseconds} '
      'lines=${inputs.length}',
    );
    _pending = pending;
    pending.then<void>(
      (built) {
        if (identical(_pending, pending)) {
          lines = built;
          _pending = null;
        }
      },
      onError: (Object _) {
        // The waiting query reports the error; the next one tries again.
        if (identical(_pending, pending)) {
          _pending = null;
          _source = null;
        }
      },
    );
    return pending;
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

  /// The running rx match, cancelled by the next find, closing the bar and
  /// dispose.
  RegexJob<({List<int> hits, List<String> pieces})>? _regexJob;

  /// Folded text of every line (diacritics ignored), for normal finds.
  final _normalized = _LineTextCache<String>(_normalizeAll);

  /// Per line, its Pāli and each translation with diacritics kept, for rx
  /// finds. Built only once rx is used in a book.
  final _exact = _LineTextCache<List<String>>(_exactAll);

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
      for (final cache in [_normalized, _exact]) {
        final bookId = cache.bookId;
        if (bookId != null && !tabs.tabs.any((t) => t.bookId == bookId)) {
          cache.clear();
        }
      }
    });
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _regexJob?.cancel();
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
    final hide = _ref.read(
      settingsProvider.select((s) => s.stripVariantAnnotations),
    );
    if (_ref.read(findRegexProvider)) {
      _exact.linesFor(paragraphs, hide, activeTab.bookId);
    } else {
      _normalizedFor(paragraphs, hide, activeTab.bookId);
    }
  }

  /// The normalized text of every line of [paragraphs], in reading order.
  /// Reuses the cache when it is for the same list and setting. A large
  /// book builds in a background isolate; the returned future completes
  /// when that build does.
  FutureOr<List<String>> _normalizedFor(
    List<ParagraphData> paragraphs,
    bool hideVariants,
    String bookId,
  ) => _normalized.linesFor(
    paragraphs,
    hideVariants,
    bookId,
    // Normalized text is computed on-demand (normalizedText is always
    // empty today — pre-computation during book load was removed as an
    // optimization).
    onBuild: (inputs) =>
        _lastNormalizedCount = inputs.where((i) => i.$3.isEmpty).length,
  );

  static List<String> _normalizeAll(List<_LineInput> inputs, bool hide) => [
    for (final (pali, translations, normalized) in inputs)
      normalized.isEmpty
          ? _normalizeLine(pali, translations, hideVariants: hide)
          : normalized,
  ];

  /// Each line's search copy as the index cleans it, diacritics kept: the
  /// Pāli (variant readings follow the setting, as in a normal find) and
  /// each translation, as separate texts so `^` and `$` mean one of them.
  static List<List<String>> _exactAll(List<_LineInput> inputs, bool hide) => [
    for (final (pali, translations, _) in inputs)
      [
        if (pali != null && pali.trim().isNotEmpty)
          cleanPaliForIndexing(pali.toLowerCase(), stripVariantContent: hide),
        for (final t in translations.values)
          if (t.trim().isNotEmpty) cleanPaliForIndexing(t.toLowerCase()),
      ],
  ];

  /// Switch rx on or off and find the box's text again in the new mode.
  void toggleRegex() {
    final on = !_ref.read(findRegexProvider);
    _ref.read(findRegexProvider.notifier).state = on;
    _searchTimer?.cancel();
    _runSearch(searchController.text);
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
    _searchGen++;
    _regexJob?.cancel();
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
    _regexJob?.cancel();
    if (_ref.read(findRegexProvider)) return _runRegexSearch(query, activeTab);

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
      state = InBookSearchState(
        showSearchBar: state.showSearchBar,
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

  /// rx mode: [pattern] as typed, run over each line's exact search copy. A
  /// line matches when the pattern matches its Pāli or one translation.
  Future<void> _runRegexSearch(String pattern, ReaderTabInfo activeTab) async {
    final gen = ++_searchGen;
    if (pattern.trim().isEmpty) {
      state = state.copyWith(query: '', clearMatches: true);
      return;
    }
    final error = regexError(pattern);
    if (error != null) {
      state = InBookSearchState(
        showSearchBar: state.showSearchBar,
        query: pattern,
        patternError: error,
      );
      return;
    }
    final perfSw = Stopwatch()..start();
    try {
      final readerState = _ref.read(readerDataProvider(activeTab.bookId));
      if (readerState.paragraphs.isEmpty) {
        state = state.copyWith(query: '', clearMatches: true);
        return;
      }
      final hide = _ref.read(
        settingsProvider.select((s) => s.stripVariantAnnotations),
      );
      final built = _exact.linesFor(
        readerState.paragraphs,
        hide,
        activeTab.bookId,
        onBuild: (_) => _exactBuilds++,
      );
      final lines = built is Future<List<List<String>>> ? await built : built;
      if (!mounted || gen != _searchGen) return;

      // The match runs in a regex job (spec K): a runaway pattern ends as
      // too slow, and the next find or closing the bar cancels it.
      final job = _regexJob = startRegexMatch(pattern, lines, maxPieces: 50);
      final matched = await job.result;
      if (!mounted || gen != _searchGen) return;
      final ids = <(int, int)>[
        for (final para in readerState.paragraphs)
          for (final line in para.lines) (para.paraId, line.lineId),
      ];
      state = InBookSearchState(
        showSearchBar: state.showSearchBar,
        query: pattern,
        matchParaIds: [for (final i in matched.hits) ids[i].$1],
        matchLineIds: [for (final i in matched.hits) ids[i].$2],
        matchIndex: matched.hits.isEmpty ? -1 : 0,
        highlight: matched.pieces.join(' '),
      );
      debugPrint(
        '[PERF] find regex ms=${perfSw.elapsedMilliseconds} '
        'lines=${ids.length} matches=${matched.hits.length}',
      );
    } on RegexTooSlow {
      if (mounted && gen == _searchGen) {
        state = InBookSearchState(
          showSearchBar: state.showSearchBar,
          query: pattern,
          patternTooSlow: true,
        );
      }
    } on RegexCancelled {
      // A newer find or closing the bar cancelled it; that one owns the state.
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
  int get cachedLineCount => _normalized.lines.length;

  /// How many lines the rx cache holds.
  @visibleForTesting
  int get cachedExactLineCount => _exact.lines.length;

  int _exactBuilds = 0;

  /// How many times a find built the rx cache.
  @visibleForTesting
  int get exactBuildCount => _exactBuilds;

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
