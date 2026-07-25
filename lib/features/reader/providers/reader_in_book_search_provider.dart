import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/epitaka_database.dart';
import '../../../core/database/translation_database.dart';
import '../../../core/models/app_models.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../utils/reader_in_book_search_utils.dart' show runInBookSearch;

/// In-book search state for a single book tab.
class InBookSearchState {
  final bool isOpen;
  final String query;
  final List<int> matchParaIds;
  final List<int> matchLineIds;
  final int matchIndex;

  const InBookSearchState({
    this.isOpen = false,
    this.query = '',
    this.matchParaIds = const [],
    this.matchLineIds = const [],
    this.matchIndex = -1,
  });

  InBookSearchState copyWith({
    bool? isOpen,
    String? query,
    List<int>? matchParaIds,
    List<int>? matchLineIds,
    int? matchIndex,
  }) {
    return InBookSearchState(
      isOpen: isOpen ?? this.isOpen,
      query: query ?? this.query,
      matchParaIds: matchParaIds ?? this.matchParaIds,
      matchLineIds: matchLineIds ?? this.matchLineIds,
      matchIndex: matchIndex ?? this.matchIndex,
    );
  }

  bool get isMatchEmpty => matchParaIds.isEmpty;
  int get matchCount => matchParaIds.length;
}

/// Notifier that manages in-book search state per bookId.
///
/// Uses [runInBookSearch] from [reader_in_book_search_utils.dart] for the
/// actual SQL queries. The widget layer should listen to state changes
/// and call [jumpToMatch] when a match navigation is needed.
class InBookSearchNotifier extends StateNotifier<InBookSearchState> {
  final Ref _ref;
  final String _bookId;

  /// Callback invoked when the notifier wants to jump to a paragraph.
  /// The widget layer sets this to bridge to the jump controller.
  void Function(String bookId, int paraId, {int? lineId, bool animate})?
      onJumpToParagraph;

  InBookSearchNotifier(this._ref, this._bookId)
    : super(const InBookSearchState());

  /// Debounce timer for search queries.
  Timer? _searchTimer;

  /// Most recent query, used to ignore stale async results.
  String _lastQuery = '';

  /// Text editing controller (managed here for lifecycle).
  final searchController = TextEditingController();

  /// Focus node for the search field.
  final searchFocusNode = FocusNode();

  /// The last search query that was applied for highlighting.
  String? get effectiveSearchQuery {
    if (state.isOpen && state.query.isNotEmpty) return state.query;
    return null;
  }

  /// Toggle the search bar open/closed.
  void toggle() {
    if (state.isOpen) {
      state = const InBookSearchState(isOpen: false);
      searchController.clear();
    } else {
      state = const InBookSearchState(isOpen: true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        searchFocusNode.requestFocus();
      });
    }
  }

  /// Run a search with debounce (200ms).
  void searchDebounced(String query) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 200), () {
      _runSearch(query);
    });
  }

  /// Run a search immediately.
  void searchImmediate(String query) {
    _searchTimer?.cancel();
    _runSearch(query);
  }

  Future<void> _runSearch(String query) async {
    _lastQuery = query;

    if (query.trim().isEmpty) {
      state = InBookSearchState(isOpen: state.isOpen);
      return;
    }

    try {
      final settings = _ref.read(settingsProvider);
      final enabledLangs = settings.enabledTranslations.isNotEmpty
          ? settings.enabledTranslations.toList()
          : (settings.showTranslation
                ? [settings.primaryTranslationLang]
                : <String>[]);

      final epitakaDb = await _ref.read(epitakaDbProvider.future);

      Future<TranslationDatabase?> getTranslationDb(String langCode) async {
        final lang = TranslationLanguage.fromCode(langCode);
        return _ref.read(translationDbProvider(lang).future);
      }

      final result = await runInBookSearch(
        query: query,
        bookId: _bookId,
        epitakaDb: epitakaDb,
        enabledLangs: enabledLangs,
        getTranslationDb: getTranslationDb,
      );

      // Guard: ignore stale async results
      if (_lastQuery != query) return;

      state = InBookSearchState(
        isOpen: true,
        query: query,
        matchParaIds: result.paraIds,
        matchLineIds: result.lineIds,
        matchIndex: result.isEmpty ? -1 : 0,
      );

      if (result.isNotEmpty) {
        jumpToMatch(0);
      }
    } catch (e) {
      developer.log(
        '[IN-BOOK SEARCH] Error: $e',
        name: 'epitaka.reader.search',
      );
      if (_lastQuery == query) {
        state = InBookSearchState(isOpen: state.isOpen);
      }
    }
  }

  /// Jump to the match at [index].
  void jumpToMatch(int index) {
    if (index < 0 || index >= state.matchParaIds.length) return;

    state = state.copyWith(matchIndex: index);

    final lineId = index < state.matchLineIds.length
        ? state.matchLineIds[index]
        : 1;

    onJumpToParagraph?.call(
      _bookId,
      state.matchParaIds[index],
      lineId: lineId,
      animate: true,
    );
  }

  /// Navigate to the next match.
  void nextMatch() {
    if (state.matchParaIds.isEmpty) return;
    final next = (state.matchIndex + 1).clamp(0, state.matchParaIds.length - 1);
    jumpToMatch(next);
  }

  /// Navigate to the previous match.
  void previousMatch() {
    if (state.matchParaIds.isEmpty) return;
    final prev =
        (state.matchIndex - 1).clamp(0, state.matchParaIds.length - 1);
    jumpToMatch(prev);
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }
}

/// Provider for in-book search state, scoped per bookId (family).
/// Uses autoDispose so state is cleaned up when the tab is closed.
final inBookSearchProvider = StateNotifierProvider.family.autoDispose<
    InBookSearchNotifier,
    InBookSearchState,
    String>(
  (ref, bookId) => InBookSearchNotifier(ref, bookId),
);
