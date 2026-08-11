import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart'
    show WordLookupGesture;
import '../../dictionary/widgets/dictionary_open.dart';
import '../utils/reader_word_hit_test.dart' show selectWordAt;

/// Result from [ReaderDictionaryLookupController]'s tap processing.
///
/// - [word]: the word to look up, or `null` when no lookup should happen.
class TapLookupResult {
  final String? word;

  const TapLookupResult({this.word});

  /// Whether this result carries a word the reader should look up.
  bool get shouldLookup => word != null;
}

/// Gesture + word-lookup controller for the reader screen.
///
/// Owns ALL of the tap-detection state and logic that used to live inside
/// `_ReaderScreenState`:
///
///  * double-tap detection (time/slop window, invalidated on movement),
///  * single-tap detection (pointer-down → up with no significant movement),
///  * word extraction at the tap point (via [selectWordAt]),
///  * dedup of repeated lookups,
///  * routing the word into the dictionary panel/sheet.
///
/// The widget layer only forwards raw pointer events here and reacts to the
/// returned [TapLookupResult]; it holds no tap state of its own. The class
/// is deliberately pure (no BuildContext/provider reads) so the gesture
/// logic is unit-testable in isolation.
class ReaderDictionaryLookupController {
  ReaderDictionaryLookupController({
    String? Function(GlobalKey, Offset)? wordFinder,
  }) : _wordFinder = wordFinder ?? selectWordAt;

  /// Injectable word finder — defaults to the render-tree hit-test in
  /// [reader_word_hit_test.dart]; tests substitute a stub.
  final String? Function(GlobalKey contentHitTestKey, Offset globalPosition)
      _wordFinder;

  /// The active lookup gesture, driven by the user's setting.
  WordLookupGesture gesture = WordLookupGesture.doubleTap;

  /// Dedup guard: the last word that was looked up.
  String? _lastLookedUpWord;

  /// Double-tap tracking: previous pointer-down timestamp.
  int? _lastTapDownTime;

  /// Double-tap tracking: previous pointer-down position.
  Offset? _lastTapDownPosition;

  /// Pointer ID of the pointer whose gesture is currently being tracked
  /// (-1 = none). Events from other pointers are ignored so a second finger
  /// can never be misread as a tap.
  int _activePointer = -1;

  /// True between pointer-down and pointer-up/cancel of the tracked pointer.
  bool _isPointerDown = false;

  /// Whether an additional pointer landed while one was already down (a
  /// two-finger tap/pinch). Such a gesture must never trigger a lookup.
  bool _sawAdditionalPointer = false;

  /// Whether the tracked pointer moved beyond the tap slop since its
  /// pointer-down (a drag/scroll must never count as a tap).
  bool _movedSinceDown = false;

  /// Debug counter for pointer-down events.
  int _tapCounter = 0;

  static const int _kDoubleTapTimeMs = 400;
  static const double _kDoubleTapSlopPx = 40.0;

  /// A pointer-up within this many ms of its pointer-down counts as a tap;
  /// anything longer is a press/hold, which is text-selection territory.
  static const int _kSingleTapMaxDurationMs = 500;

  /// Movement beyond this distance invalidates tap detection (and, in
  /// double-tap mode, the pending first half of the double-tap).
  static const double _kTapMovementSlopPx = 10.0;

  /// Switch the active gesture, clearing any half-detected tap state so a
  /// stale first tap from the previous mode can't be misread.
  void setGesture(WordLookupGesture value) {
    if (value == gesture) return;
    gesture = value;
    clearTapState();
  }

  /// Handle a raw pointer-down.
  ///
  /// In double-tap mode this is where a double-tap is confirmed (second
  /// pointer-down within the time/slop window). Returns a [TapLookupResult]
  /// carrying the word when a lookup should happen.
  TapLookupResult handlePointerDown({
    required int pointer,
    required Offset localPosition,
    required Offset globalPosition,
    required int timestampMs,
    required GlobalKey contentHitTestKey,
  }) {
    // A second finger landing while the first is still down (two-finger
    // tap, pinch, palm touch) must not start a new gesture.
    if (_isPointerDown && pointer != _activePointer) {
      _sawAdditionalPointer = true;
      return const TapLookupResult();
    }
    _activePointer = pointer;
    _isPointerDown = true;
    _movedSinceDown = false;
    _sawAdditionalPointer = false;

    final now = timestampMs;
    final lastTime = _lastTapDownTime;
    final lastPos = _lastTapDownPosition;
    _lastTapDownTime = now;
    _lastTapDownPosition = localPosition;

    developer.log(
      '[DBG] pointerDown #${_tapCounter++} pointer=$pointer at=$localPosition '
      'dt=${lastTime != null ? now - lastTime : '-'} '
      'dist=${lastPos != null ? (localPosition - lastPos).distance : '-'} '
      'gesture=$gesture',
      name: 'epitaka.dict',
    );

    if (gesture == WordLookupGesture.doubleTap &&
        lastTime != null &&
        lastPos != null) {
      final dt = now - lastTime;
      final dist = (localPosition - lastPos).distance;
      if (dt >= 0 && dt <= _kDoubleTapTimeMs && dist <= _kDoubleTapSlopPx) {
        // Double-tap confirmed. Look up the word at this point.
        developer.log('[DBG] DOUBLE-TAP detected', name: 'epitaka.dict');
        _lastTapDownTime = null;
        _lastTapDownPosition = null;
        return TapLookupResult(
          word: _selectWordAt(contentHitTestKey, globalPosition),
        );
      }
      developer.log(
        '[DBG] tap too slow/far (dt=$dt dist=$dist) — not a double-tap',
        name: 'epitaka.dict',
      );
    }
    return const TapLookupResult();
  }

  /// Handle a raw pointer-move: marks the tracked pointer as moved (so the
  /// gesture can never be a tap) and, in double-tap mode, invalidates the
  /// pending first half of a double-tap. A scroll must never be misread as
  /// a tap.
  ///
  /// The widget layer MUST call this even on desktop and even while a
  /// selection lingers — otherwise a scroll never invalidates the cached
  /// tap-down and the next pointer-down can be misread as a double-tap.
  void handlePointerMove(int pointer, Offset localPosition) {
    if (pointer != _activePointer) return;
    final downPos = _lastTapDownPosition;
    if (downPos == null) return;
    if ((localPosition - downPos).distance > _kTapMovementSlopPx) {
      _movedSinceDown = true;
      if (gesture == WordLookupGesture.doubleTap) {
        _lastTapDownTime = null;
        _lastTapDownPosition = null;
      }
    }
  }

  /// Handle a raw pointer-up.
  ///
  /// In single-tap mode a clean tap (down → up with no significant movement,
  /// within the tap-duration window, and no text selection active) triggers
  /// a word lookup. Double-tap mode already fired on the second pointer-down,
  /// so nothing happens here.
  TapLookupResult handlePointerUp({
    required int pointer,
    required Offset globalPosition,
    required int timestampMs,
    required GlobalKey contentHitTestKey,
    required bool hasSelection,
  }) {
    if (pointer != _activePointer) {
      return const TapLookupResult();
    }
    final wasDown = _isPointerDown;
    _isPointerDown = false;
    _activePointer = -1;

    if (gesture != WordLookupGesture.singleTap || !wasDown) {
      return const TapLookupResult();
    }

    final downMs = _lastTapDownTime;
    final moved = _movedSinceDown;
    _movedSinceDown = false;
    if (moved ||
        _sawAdditionalPointer ||
        hasSelection ||
        downMs == null) {
      return const TapLookupResult();
    }
    final dt = timestampMs - downMs;
    if (dt < 0 || dt > _kSingleTapMaxDurationMs) {
      return const TapLookupResult();
    }

    developer.log(
      '[DBG] SINGLE-TAP detected (dt=$dt)',
      name: 'epitaka.dict',
    );
    _lastTapDownTime = null;
    _lastTapDownPosition = null;
    return TapLookupResult(
      word: _selectWordAt(contentHitTestKey, globalPosition),
    );
  }

  /// Handle a raw pointer-cancel: the gesture is aborted, so any pending
  /// tap/double-tap state for this pointer is discarded.
  void handlePointerCancel(int pointer) {
    if (pointer != _activePointer) return;
    _isPointerDown = false;
    _movedSinceDown = false;
    _sawAdditionalPointer = false;
    _activePointer = -1;
  }

  /// Clear all tap-detection state.
  ///
  /// Called when a swipe/scroll begins so that the previous pointer-down
  /// (which was the start of the scroll, not a tap) is NOT treated as the
  /// first half of a double-tap when the user taps again after scrolling.
  void clearTapState() {
    _lastTapDownTime = null;
    _lastTapDownPosition = null;
    _isPointerDown = false;
    _movedSinceDown = false;
    _sawAdditionalPointer = false;
    _activePointer = -1;
    developer.log('[DBG] clearTapState — swipe started', name: 'epitaka.dict');
  }

  /// Find the Pāli word rendered at the global [globalPosition] by hit-testing
  /// the render tree under [contentHitTestKey], then validate and dedup it.
  ///
  /// Delegates the actual hit-test and word-boundary logic to [selectWordAt]
  /// from [reader_word_hit_test.dart].
  String? _selectWordAt(GlobalKey contentHitTestKey, Offset globalPosition) {
    final word = _wordFinder(contentHitTestKey, globalPosition);
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

  /// Open the dictionary for [word], routing the lookup into the dictionary
  /// dock/panel (desktop sidebar dock or right column, mobile bottom dock).
  ///
  /// The dock/panel stays mounted, so there is no need to disable selection
  /// while it is open.
  void openDictionary(WidgetRef ref, BuildContext context, String word) {
    if (word.trim().isEmpty) return;

    developer.log(
      '[DICT] reader word lookup tap word="$word"',
      name: 'epitaka.dict',
    );

    openDictionaryInPanel(context, ref, word);
    _lastLookedUpWord = null;
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
