/// Riverpod providers for the @ mention heading attachment system.
///
/// Two main state objects:
///   [mentionSearchProvider] — Tracks the active @ search state (isActive,
///     query, results, selectedIndex) and handles debounced DB queries.
///   [attachmentsProvider] — Simple list of [HeadingAttachment] items the
///     user has attached to the current message.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/heading_attachment.dart';
import '../services/mention_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  ATTACHMENTS
// ═══════════════════════════════════════════════════════════════════════════

/// Simple StateNotifier for managing the list of heading attachments.
class AttachmentsNotifier extends StateNotifier<List<HeadingAttachment>> {
  AttachmentsNotifier() : super([]);

  /// Add a heading attachment.
  void add(HeadingAttachment attachment) {
    state = [...state, attachment];
  }

  /// Remove a heading attachment by its id.
  void remove(String id) {
    state = state.where((a) => a.id != id).toList();
  }

  /// Clear all attachments.
  void clear() {
    state = [];
  }
}

/// Provider for the list of attached headings in the current message.
final attachmentsProvider =
    StateNotifierProvider<AttachmentsNotifier, List<HeadingAttachment>>((ref) {
  return AttachmentsNotifier();
});

// ═══════════════════════════════════════════════════════════════════════════
//  MENTION SEARCH
// ═══════════════════════════════════════════════════════════════════════════

/// State of the @ mention search.
class MentionSearchState {
  /// Whether the @ mention mode is currently active.
  final bool isActive;

  /// The query string (text after @, without the @ symbol).
  final String query;

  /// Search results from the mention index.
  final List<MentionSearchResult> results;

  /// Whether a search is in progress.
  final bool isLoading;

  /// Index of the currently highlighted item (for keyboard navigation).
  final int selectedIndex;

  /// Error message, if any.
  final String? error;

  const MentionSearchState({
    this.isActive = false,
    this.query = '',
    this.results = const [],
    this.isLoading = false,
    this.selectedIndex = 0,
    this.error,
  });

  MentionSearchState copyWith({
    bool? isActive,
    String? query,
    List<MentionSearchResult>? results,
    bool? isLoading,
    int? selectedIndex,
    String? error,
    bool clearError = false,
  }) {
    return MentionSearchState(
      isActive: isActive ?? this.isActive,
      query: query ?? this.query,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier managing the @ mention search state with debounced DB queries.
class MentionSearchNotifier extends StateNotifier<MentionSearchState> {
  final Ref _ref;
  Timer? _debounceTimer;

  MentionSearchNotifier(this._ref) : super(const MentionSearchState());

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Activate mention mode (user typed @).
  void activate() {
    state = const MentionSearchState(isActive: true, isLoading: true);
    _performSearch('');
  }

  /// Deactivate mention mode (user dismissed or selected).
  void deactivate() {
    _debounceTimer?.cancel();
    state = const MentionSearchState();
  }

  /// Update the search query as the user types after @.
  void updateQuery(String query) {
    if (!state.isActive) {
      // Auto-activate if user types @
      if (query.startsWith('@')) {
        state = MentionSearchState(
          isActive: true,
          query: query.substring(1),
          isLoading: true,
        );
        _debounceSearch(query.substring(1));
        return;
      }
      return;
    }

    // Check if @ is still present
    if (!query.contains('@')) {
      deactivate();
      return;
    }

    // Extract text after @
    final atIndex = query.lastIndexOf('@');
    final queryText = query.substring(atIndex + 1);

    state = state.copyWith(query: queryText, isLoading: true);
    _debounceSearch(queryText);
  }

  /// Handle text input to detect @ activation or deactivation.
  /// Called from the text controller's listener.
  void onTextChanged(String text) {
    final atIndex = text.lastIndexOf('@');
    if (atIndex >= 0) {
      // Check if @ is at the start of a word (preceded by space or at beginning)
      final charBefore = atIndex > 0 ? text[atIndex - 1] : ' ';
      if (charBefore == ' ' || charBefore == '\n') {
        if (!state.isActive) {
          activate();
        } else {
          updateQuery(text);
        }
        return;
      }
    }

    // No @ found or not at word start
    if (state.isActive) {
      deactivate();
    }
  }

  /// Navigate selection up/down.
  void moveSelection(int delta) {
    if (!state.isActive || state.results.isEmpty) return;
    final newIndex = (state.selectedIndex + delta).clamp(0, state.results.length - 1);
    state = state.copyWith(selectedIndex: newIndex);
  }

  /// Get the currently selected result, or null.
  MentionSearchResult? get selectedResult {
    if (!state.isActive || state.results.isEmpty) return null;
    if (state.selectedIndex >= state.results.length) return null;
    return state.results[state.selectedIndex];
  }

  /// Debounced search.
  void _debounceSearch(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    try {
      final service = _ref.read(mentionServiceProvider);
      final results = await service.search(query, limit: 20);
      // Guard: if user dismissed the overlay during the async gap, ignore.
      if (!state.isActive) return;
      state = state.copyWith(
        results: results,
        isLoading: false,
        selectedIndex: 0,
      );
    } catch (e) {
      if (state.isActive) {
        state = state.copyWith(
          isLoading: false,
          error: 'Search error: $e',
        );
      }
    }
  }
}

/// Provider for the @ mention search state.
final mentionSearchProvider = StateNotifierProvider<MentionSearchNotifier, MentionSearchState>((ref) {
  return MentionSearchNotifier(ref);
});

/// Provider that checks whether the heading @ mention index has been built.
/// Used by the chat screen to show a "build index" prompt if needed.
final isMentionIndexReadyProvider = FutureProvider<bool>((ref) async {
  final mentionService = ref.read(mentionServiceProvider);
  return mentionService.isIndexBuilt();
});
