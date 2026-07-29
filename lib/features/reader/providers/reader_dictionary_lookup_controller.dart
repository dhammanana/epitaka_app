import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/responsive_breakpoint.dart';
import '../../../shared/providers/side_panel_provider.dart';
import '../../dictionary/widgets/dictionary_sheet.dart';
import '../utils/reader_word_hit_test.dart' show selectWordAt;

/// Result from [ReaderDictionaryLookupController.handlePointerDown].
///
/// - [word]: the word to look up, or `null` if no double-tap detected.
class DoubleTapResult {
  final String? word;

  const DoubleTapResult({this.word});
}

/// Thin controller for dictionary word lookup from the reader screen.
///
/// Hosts the double-tap detection state, dedup logic, and the actual
/// dictionary sheet / side-panel routing. Not a [StateNotifier] — this is a
/// plain class instantiated via a [Provider] so it can hold mutable state
/// without the overhead of Riverpod state notifications.
class ReaderDictionaryLookupController {
  /// Dedup guard: the last word that was looked up.
  String? _lastLookedUpWord;

  /// Double-tap tracking: previous pointer-down timestamp.
  int? _lastTapDownTime;

  /// Double-tap tracking: previous pointer-down position.
  Offset? _lastTapDownPosition;

  /// Debug counter for pointer-down events.
  int _tapCounter = 0;

  /// The last selection reported by [SelectionArea.onSelectionChanged].
  /// Read by the widget layer for copy operations and auto-scroll detection.
  SelectedContent? lastSelectedContent;

  /// Callback passed to [SelectionArea.onSelectionChanged]. Caches the
  /// selection for copy operations and auto-scroll detection.
  void handleSelectionChanged(SelectedContent? selection) {
    lastSelectedContent = selection;
    developer.log(
      '[DBG] onSelectionChanged plain="${selection?.plainText}" '
      'hasSelection=${selection != null}',
      name: 'epitaka.dict',
    );

    // Dictionary lookup is now driven explicitly by our own double-tap
    // detector (see [handlePointerDown] + [_selectWordAt]), which hit-tests
    // the render tree to find the word under the tap. We no longer infer a
    // double-tap from a single-word selection here, because that heuristic
    // competed with the tab-swipe [GestureDetector] and was flaky from the
    // second tap onward.
    //
    // We still cache the selection for the copy context menu / Ctrl+C
    // (long-press selection, which is a separate gesture from double-tap).
  }

  /// Handle raw pointer-down event for double-tap detection.
  ///
  /// This runs *before* the gesture arena resolves, so it is not subject to
  /// the race between [SelectionArea]'s double-tap recognizer and the
  /// tab-swipe [GestureDetector].
  ///
  /// The widget layer is responsible for recording tab-swipe init state
  /// (`_swipeStartPos`, `_isSwiping`) *before* calling this method.
  ///
  /// Returns a [DoubleTapResult]:
  /// - If a double-tap is detected and a valid word is found, returns
  ///   `word` set to the looked-up word and `lookupTriggered` = false.
  ///   The widget should then call [openDictionary] with the word.
  /// - Otherwise returns `word` = null.
  DoubleTapResult handlePointerDown({
    required Offset localPosition,
    required Offset globalPosition,
    required int timestampMs,
    required GlobalKey contentHitTestKey,
  }) {
    final now = timestampMs;
    final lastTime = _lastTapDownTime;
    final lastPos = _lastTapDownPosition;

    _lastTapDownTime = now;
    _lastTapDownPosition = localPosition;

    developer.log(
      '[DBG] pointerDown #${_tapCounter++} at=$localPosition '
      'dt=${lastTime != null ? now - lastTime : '-'} '
      'dist=${lastPos != null ? (localPosition - lastPos).distance : '-'}',
      name: 'epitaka.dict',
    );

    if (lastTime != null && lastPos != null) {
      final dt = now - lastTime;
      final dist = (localPosition - lastPos).distance;
      const kDoubleTapTime = 400; // ms
      const kDoubleTapSlop = 40.0; // px
      if (dt >= 0 && dt <= kDoubleTapTime && dist <= kDoubleTapSlop) {
        // Double-tap confirmed. Look up the word at this point.
        developer.log('[DBG] DOUBLE-TAP detected', name: 'epitaka.dict');
        _lastTapDownTime = null;
        _lastTapDownPosition = null;
        final word = _selectWordAt(contentHitTestKey, globalPosition);
        return DoubleTapResult(word: word);
      } else {
        developer.log(
          '[DBG] tap too slow/far (dt=$dt dist=$dist) — not a double-tap',
          name: 'epitaka.dict',
        );
      }
    }
    return const DoubleTapResult();
  }

  /// Find the Pāli word rendered at the global [globalPosition] by hit-testing
  /// the render tree under [contentHitTestKey], then validate and dedup it.
  ///
  /// Delegates the actual hit-test and word-boundary logic to [selectWordAt]
  /// from [reader_word_hit_test.dart].
  String? _selectWordAt(GlobalKey contentHitTestKey, Offset globalPosition) {
    final word = selectWordAt(contentHitTestKey, globalPosition);
    if (word != null &&
        word.length >= 2 &&
        word.length <= 50 &&
        !word.contains(' ') &&
        !word.contains('\n') &&
        word != _lastLookedUpWord) {
      developer.log(
        '[DBG] _selectWordAt: LOOKUP word="$word"',
        name: 'epitaka.dict',
      );
      _lastLookedUpWord = word;
      return word;
    }
    return null;
  }

  /// Clear the double-tap detection state.
  ///
  /// Called when a swipe/scroll begins so that the previous pointer-down
  /// (which was the start of the scroll, not a tap) is NOT treated as the
  /// first half of a double-tap when the user taps again after scrolling.
  void clearTapState() {
    _lastTapDownTime = null;
    _lastTapDownPosition = null;
    developer.log('[DBG] clearTapState — swipe started', name: 'epitaka.dict');
  }

  /// Open the dictionary for [word].
  ///
  /// If the dictionary is pinned in the desktop side panel, routes the lookup
  /// there. Otherwise shows the dictionary bottom sheet, managing the
  /// [SelectionContainer.disabled] toggle via [onSelectionDisabled] /
  /// [onSelectionEnabled] callbacks.
  void openDictionary(
    WidgetRef ref,
    BuildContext context,
    String word, {
    required VoidCallback onSelectionDisabled,
    required VoidCallback onSelectionEnabled,
  }) {
    if (word.trim().isEmpty) return;

    developer.log('[DBG] openDictionary word="$word"', name: 'epitaka.dict');
    developer.log(
      '[DICT] reader word lookup tap word="$word"',
      name: 'epitaka.dict',
    );

    final sidePanels = ref.read(sidePanelProvider);
    final isDictionaryPinned =
        sidePanels.right.openPanel == SidePanelType.dictionary &&
        sidePanels.right.isPinned;

    if (ResponsiveBreakpoint.isDesktop(context) && isDictionaryPinned) {
      // The dictionary is docked in the right side panel: route the lookup
      // there instead of opening the bottom sheet.
      ref.read(sidePanelProvider.notifier).updateDictionaryWord(word.trim());
      return;
    }

    // Default: show as a bottom sheet on all platforms. The user can pin it
    // (via the toolbar pin button) to dock it in the right side panel.
    //
    // Disable selection (via SelectionContainer.disabled, NOT by unmounting
    // SelectionArea) before the sheet opens. We commit the disable on its own
    // frame first so every paragraph's selectable unregisters from the root
    // registrar *before* the modal steals focus; only then does the sheet
    // mount on the next frame. By the time focus shifts, the registrar has
    // nothing left to reconcile, so there's no teardown race or O(n) walk.
    // SelectionArea itself stays mounted the whole time.
    onSelectionDisabled();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await showDictionarySheet(context, word.trim());
      } finally {
        // Re-enable selection after the dictionary sheet closes,
        // clearing dedup so the user can look up the same word again.
        _lastLookedUpWord = null;
        onSelectionEnabled();
      }
    });
  }

}

/// Provider for the dictionary lookup controller.
///
/// This is a plain [Provider] (not [StateNotifierProvider]) because the
/// controller holds mutable state but does not need to notify rebuilds —
/// the widget reads its state explicitly via [WidgetRef.read], not [watch].
final readerDictionaryLookupController =
    Provider<ReaderDictionaryLookupController>((ref) {
      return ReaderDictionaryLookupController();
    });
