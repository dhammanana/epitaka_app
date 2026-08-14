import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/// Bridges the reader screen's per-book scroll controllers / position
/// listeners to the keyboard-navigation layer.
///
/// The reader screen owns the [ItemScrollController]s (they are tied to its
/// [ScrollablePositionedList]s); it registers them here on every build for
/// the active book. The desktop keyboard navigation (j/k scrolling, chip
/// selection) and the Cmd/Ctrl+J "jump to page" shortcut then drive the
/// active book without reaching into the reader screen's private state.
///
/// Registrations are keyed by bookId and simply overwritten on each build;
/// stale entries are cleaned up when a tab closes (see reader_screen.dart).
class ReaderKeyboardBridge {
  final Map<String, ItemScrollController> _scrollControllers = {};
  final Map<String, ItemPositionsListener> _positionsListeners = {};

  void register(
    String bookId,
    ItemScrollController scrollController,
    ItemPositionsListener positionsListener,
  ) {
    _scrollControllers[bookId] = scrollController;
    _positionsListeners[bookId] = positionsListener;
  }

  void unregister(String bookId) {
    _scrollControllers.remove(bookId);
    _positionsListeners.remove(bookId);
  }

  ItemScrollController? scrollControllerFor(String bookId) =>
      _scrollControllers[bookId];

  ItemPositionsListener? positionsListenerFor(String bookId) =>
      _positionsListeners[bookId];

  /// Paragraph index of the topmost visible item for [bookId], or null when
  /// the list hasn't reported positions yet (no book open / still loading).
  int? firstVisibleIndex(String bookId) {
    final positions = _positionsListeners[bookId]?.itemPositions.value;
    if (positions == null || positions.isEmpty) return null;
    final visible = positions.where((p) => p.itemTrailingEdge > 0).toList()
      ..sort((a, b) => a.itemLeadingEdge.compareTo(b.itemLeadingEdge));
    if (visible.isEmpty) return null;
    return visible.first.index;
  }
}

final readerKeyboardBridgeProvider = Provider<ReaderKeyboardBridge>((ref) {
  return ReaderKeyboardBridge();
});

// ═════════════════════════════════════════════════════════════════════════
//  KEYBOARD READING FOCUS STATE
// ═════════════════════════════════════════════════════════════════════════

/// The keyboard "reading cursor": which line is highlighted as the focused
/// line, and which book-link chip on that line (if any) is selected.
///
/// Consumed by the reader content rendering (to draw the focus-line
/// highlight and the selected chip) and mutated by [ReaderKeyboardNavWidget]
/// as the user presses j/k/h/l / arrows.
class ReaderKeyboardNavState {
  /// Whether keyboard reading is engaged (the focus line is visible).
  final bool engaged;

  /// The book the focus line belongs to.
  final String? bookId;

  /// Focused paragraph id.
  final int? paraId;

  /// Focused line id inside [paraId].
  final int? lineId;

  /// Index of the selected book-link chip on the focused line (-1 = none).
  final int chipIndex;

  const ReaderKeyboardNavState({
    this.engaged = false,
    this.bookId,
    this.paraId,
    this.lineId,
    this.chipIndex = -1,
  });

  bool matches(String bookId, int paraId, int lineId) =>
      engaged &&
      this.bookId == bookId &&
      this.paraId == paraId &&
      this.lineId == lineId;
}

class ReaderKeyboardNavNotifier extends StateNotifier<ReaderKeyboardNavState> {
  ReaderKeyboardNavNotifier() : super(const ReaderKeyboardNavState());

  /// Hide the focus line (Esc, or leaving the reader).
  void disengage() {
    if (!state.engaged) return;
    state = const ReaderKeyboardNavState();
  }

  /// Hide the focus line when it belongs to a different book than [bookId].
  void clearIfDifferentBook(String? bookId) {
    if (state.engaged && state.bookId != null && state.bookId != bookId) {
      state = const ReaderKeyboardNavState();
    }
  }

  /// Move the reading cursor to [paraId]/[lineId] (engaging it if needed).
  void focus(String bookId, int paraId, int lineId) {
    state = ReaderKeyboardNavState(
      engaged: true,
      bookId: bookId,
      paraId: paraId,
      lineId: lineId,
    );
  }

  /// Select the chip at [index] on the current focus line (-1 = none).
  void selectChip(int index) {
    if (!state.engaged) return;
    state = ReaderKeyboardNavState(
      engaged: true,
      bookId: state.bookId,
      paraId: state.paraId,
      lineId: state.lineId,
      chipIndex: index,
    );
  }
}

/// Provider holding the keyboard reading cursor state (one cursor — only the
/// active book can show it).
final readerKeyboardNavProvider =
    StateNotifierProvider<ReaderKeyboardNavNotifier, ReaderKeyboardNavState>(
      (ref) => ReaderKeyboardNavNotifier(),
    );
