import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/core/providers/settings_provider.dart'
    show WordLookupGesture;
import 'package:epitaka/features/reader/providers/reader_dictionary_lookup_controller.dart';

/// Unit tests for [ReaderDictionaryLookupController] — the tap-gesture +
/// word-lookup logic that previously lived inside `_ReaderScreenState`.
///
/// The controller's word finder is injected as a stub so the pure gesture
/// logic (double-tap window, movement invalidation, single-tap conditions,
/// multi-touch suppression) is tested without any rendering.
void main() {
  final key = GlobalKey();

  ReaderDictionaryLookupController makeController({
    WordLookupGesture gesture = WordLookupGesture.doubleTap,
    String? word = 'dhamma',
  }) {
    return ReaderDictionaryLookupController(
      wordFinder: (_, _) => word,
    )..gesture = gesture;
  }

  const p = Offset(200, 300);
  const p2 = Offset(230, 330); // ~42.4px from p (over the 40px slop)

  /// A clean single-tap (down + up) against [c] in single-tap mode.
  TapLookupResult singleTap(ReaderDictionaryLookupController c,
      {Offset at = p, int upMs = 100, bool hasSelection = false}) {
    c.handlePointerDown(
      pointer: 1,
      localPosition: at,
      globalPosition: at,
      timestampMs: 0,
      contentHitTestKey: key,
    );
    return c.handlePointerUp(
      pointer: 1,
      globalPosition: at,
      timestampMs: upMs,
      contentHitTestKey: key,
      hasSelection: hasSelection,
    );
  }

  group('double-tap mode', () {
    test('two quick taps within window → lookup', () {
      final c = makeController();
      expect(
        c
            .handlePointerDown(
              pointer: 1,
              localPosition: p,
              globalPosition: p,
              timestampMs: 0,
              contentHitTestKey: key,
            )
            .shouldLookup,
        isFalse,
        reason: 'first tap is only the first half of the double-tap',
      );
      final result = c.handlePointerDown(
        pointer: 1,
        localPosition: p,
        globalPosition: p,
        timestampMs: 200,
        contentHitTestKey: key,
      );
      expect(result.shouldLookup, isTrue);
      expect(result.word, 'dhamma');
    });

    test('second tap too slow (outside 400ms) → no lookup', () {
      final c = makeController();
      c.handlePointerDown(
        pointer: 1,
        localPosition: p,
        globalPosition: p,
        timestampMs: 0,
        contentHitTestKey: key,
      );
      final result = c.handlePointerDown(
        pointer: 1,
        localPosition: p,
        globalPosition: p,
        timestampMs: 500,
        contentHitTestKey: key,
      );
      expect(result.shouldLookup, isFalse);
    });

    test('second tap too far (outside 40px slop) → no lookup', () {
      final c = makeController();
      c.handlePointerDown(
        pointer: 1,
        localPosition: p,
        globalPosition: p,
        timestampMs: 0,
        contentHitTestKey: key,
      );
      final result = c.handlePointerDown(
        pointer: 1,
        localPosition: p2,
        globalPosition: p2,
        timestampMs: 100,
        contentHitTestKey: key,
      );
      expect(result.shouldLookup, isFalse);
    });

    test('movement between taps invalidates the pending double-tap', () {
      final c = makeController();
      c.handlePointerDown(
        pointer: 1,
        localPosition: p,
        globalPosition: p,
        timestampMs: 0,
        contentHitTestKey: key,
      );
      // Scroll away (30px > 10px slop) then tap again quickly: this used to
      // be misread as the second half of a double-tap, opening the
      // dictionary for a random word.
      c.handlePointerMove(1, p + const Offset(30, 0));
      final result = c.handlePointerDown(
        pointer: 1,
        localPosition: p,
        globalPosition: p,
        timestampMs: 100,
        contentHitTestKey: key,
      );
      expect(result.shouldLookup, isFalse);
    });

    test('single-tap mode ignores pointer-up entirely', () {
      final c = makeController();
      c.handlePointerDown(
        pointer: 1,
        localPosition: p,
        globalPosition: p,
        timestampMs: 0,
        contentHitTestKey: key,
      );
      final result = c.handlePointerUp(
        pointer: 1,
        globalPosition: p,
        timestampMs: 100,
        contentHitTestKey: key,
        hasSelection: false,
      );
      expect(result.shouldLookup, isFalse);
    });

    test('movement that is within slop keeps the double-tap pending', () {
      final c = makeController();
      c.handlePointerDown(
        pointer: 1,
        localPosition: p,
        globalPosition: p,
        timestampMs: 0,
        contentHitTestKey: key,
      );
      // 5px of jitter is not a scroll.
      c.handlePointerMove(1, p + const Offset(5, 0));
      final result = c.handlePointerDown(
        pointer: 1,
        localPosition: p + const Offset(5, 0),
        globalPosition: p + const Offset(5, 0),
        timestampMs: 150,
        contentHitTestKey: key,
      );
      expect(result.shouldLookup, isTrue);
    });

    test('two fingers landing at once are not a double-tap', () {
      final c = makeController();
      c.handlePointerDown(
        pointer: 1,
        localPosition: p,
        globalPosition: p,
        timestampMs: 0,
        contentHitTestKey: key,
      );
      // Second finger lands 100ms later, 10px away — within the double-tap
      // window, but it must NOT count as the second tap.
      final result = c.handlePointerDown(
        pointer: 2,
        localPosition: p + const Offset(10, 0),
        globalPosition: p + const Offset(10, 0),
        timestampMs: 100,
        contentHitTestKey: key,
      );
      expect(result.shouldLookup, isFalse);
    });
  });

  group('single-tap mode', () {
    test('clean tap (down → up, no movement) → lookup', () {
      final c = makeController(gesture: WordLookupGesture.singleTap);
      final result = singleTap(c);
      expect(result.shouldLookup, isTrue);
      expect(result.word, 'dhamma');
    });

    test('movement (scroll/drag) → no lookup', () {
      final c = makeController(gesture: WordLookupGesture.singleTap);
      c.handlePointerDown(
        pointer: 1,
        localPosition: p,
        globalPosition: p,
        timestampMs: 0,
        contentHitTestKey: key,
      );
      c.handlePointerMove(1, p + const Offset(30, 0));
      final result = c.handlePointerUp(
        pointer: 1,
        globalPosition: p + const Offset(30, 0),
        timestampMs: 100,
        contentHitTestKey: key,
        hasSelection: false,
      );
      expect(result.shouldLookup, isFalse);
    });

    test('active text selection (long-press) → no lookup', () {
      final c = makeController(gesture: WordLookupGesture.singleTap);
      final result = singleTap(c, hasSelection: true);
      expect(result.shouldLookup, isFalse);
    });

    test('press held too long (> 500ms) → no lookup', () {
      final c = makeController(gesture: WordLookupGesture.singleTap);
      final result = singleTap(c, upMs: 600);
      expect(result.shouldLookup, isFalse);
    });

    test('pointer-cancel aborts the pending tap', () {
      final c = makeController(gesture: WordLookupGesture.singleTap);
      c.handlePointerDown(
        pointer: 1,
        localPosition: p,
        globalPosition: p,
        timestampMs: 0,
        contentHitTestKey: key,
      );
      c.handlePointerCancel(1);
      final result = c.handlePointerUp(
        pointer: 1,
        globalPosition: p,
        timestampMs: 100,
        contentHitTestKey: key,
        hasSelection: false,
      );
      expect(result.shouldLookup, isFalse);
    });

    test('two-finger tap → no lookup on the first finger-up', () {
      final c = makeController(gesture: WordLookupGesture.singleTap);
      c.handlePointerDown(
        pointer: 1,
        localPosition: p,
        globalPosition: p,
        timestampMs: 0,
        contentHitTestKey: key,
      );
      c.handlePointerDown(
        pointer: 2,
        localPosition: p + const Offset(20, 0),
        globalPosition: p + const Offset(20, 0),
        timestampMs: 50,
        contentHitTestKey: key,
      );
      final result = c.handlePointerUp(
        pointer: 1,
        globalPosition: p,
        timestampMs: 100,
        contentHitTestKey: key,
        hasSelection: false,
      );
      expect(result.shouldLookup, isFalse,
          reason: 'a two-finger gesture must never open the dictionary');
    });

    test('a double-tap gesture looks up once (dedup blocks the second)', () {
      final c = makeController(gesture: WordLookupGesture.singleTap);
      // First tap.
      final first = singleTap(c);
      expect(first.shouldLookup, isTrue);
      // Second tap of the double-tap, same word — dedup suppresses it until
      // openDictionary resets the guard (as the widget layer does).
      final second = singleTap(c);
      expect(second.shouldLookup, isFalse);
    });
  });

  group('gesture switching & dedup', () {
    test('setGesture clears stale tap state from the previous mode', () {
      final c = makeController();
      c.handlePointerDown(
        pointer: 1,
        localPosition: p,
        globalPosition: p,
        timestampMs: 0,
        contentHitTestKey: key,
      );
      // Switch to single-tap mid-gesture — the stale first tap must not
      // count toward anything.
      c.setGesture(WordLookupGesture.singleTap);
      final result = c.handlePointerDown(
        pointer: 1,
        localPosition: p,
        globalPosition: p,
        timestampMs: 100,
        contentHitTestKey: key,
      );
      expect(result.shouldLookup, isFalse);
    });

    test('word finder returning a short word yields no lookup', () {
      final c = makeController(word: 'x'); // single char → invalid
      final result = singleTap(c);
      expect(result.shouldLookup, isFalse);
    });
  });
}
