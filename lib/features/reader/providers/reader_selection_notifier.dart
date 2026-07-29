import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Selection and copy state for the reader screen.
///
/// Tracks the current [SelectionArea] selection content and visible
/// paragraph range (for fallback copy).
class ReaderSelectionState {
  /// Cached selection content from [SelectionArea.onSelectionChanged].
  final SelectedContent? lastSelectedContent;

  /// Visible paragraph start index (for copy fallback when no selection).
  final int visibleStartIndex;

  /// Visible paragraph end index (for copy fallback when no selection).
  final int visibleEndIndex;

  const ReaderSelectionState({
    this.lastSelectedContent,
    this.visibleStartIndex = 0,
    this.visibleEndIndex = 0,
  });

  bool get hasSelection =>
      lastSelectedContent != null &&
      lastSelectedContent!.plainText.trim().isNotEmpty;

  ReaderSelectionState copyWith({
    SelectedContent? lastSelectedContent,
    bool clearSelection = false,
    int? visibleStartIndex,
    int? visibleEndIndex,
  }) {
    return ReaderSelectionState(
      lastSelectedContent:
          clearSelection ? null : (lastSelectedContent ?? this.lastSelectedContent),
      visibleStartIndex: visibleStartIndex ?? this.visibleStartIndex,
      visibleEndIndex: visibleEndIndex ?? this.visibleEndIndex,
    );
  }
}

/// Notifier managing reader selection state.
class ReaderSelectionNotifier extends StateNotifier<ReaderSelectionState> {
  ReaderSelectionNotifier() : super(const ReaderSelectionState());

  /// Update the selection content from [SelectionArea.onSelectionChanged].
  void onSelectionChanged(SelectedContent? selection) {
    state = state.copyWith(lastSelectedContent: selection);
  }

  /// Clear the cached selection.
  void clearSelection() {
    state = state.copyWith(clearSelection: true);
  }

  /// Update visible paragraph range (from scroll position tracking).
  void updateVisibleRange(int startIndex, int endIndex) {
    state = state.copyWith(
      visibleStartIndex: startIndex,
      visibleEndIndex: endIndex,
    );
  }
}

/// Provider for reader selection state.
/// Provider for reader selection state.
///
/// NOT autoDispose: the selection state must persist across builds of the
/// context menu overlay. When a user long-presses text, the context menu
/// builder ([_buildCopyContextMenu]) reads this provider with [ref.read]
/// and captures [lastSelectedContent] in button closures. If the provider
/// were auto-disposed between reads, the captured value would be null and
/// the Copy/Excerpt buttons would silently do nothing.
final readerSelectionProvider =
    StateNotifierProvider<ReaderSelectionNotifier, ReaderSelectionState>(
      (ref) => ReaderSelectionNotifier(),
    );
