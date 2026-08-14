import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/features/reader/providers/tts_reading_provider.dart';

TtsLineItem _line(int index, {String text = 'text'}) =>
    TtsLineItem(paraId: index, lineId: index, text: text);

void main() {
  group('PreparedAudioQueue', () {
    test('ensures exactly `ahead` upcoming lines are prepared', () {
      final queue = PreparedAudioQueue(ahead: 3);
      final lines = List.generate(10, _line);

      queue.ensure(1, 0, lines, (l) async => 'audio-${l.lineId}');

      expect(queue.length, 3);
      // Lines 1, 2, 3 are prepared; 0 is current.
      for (var i = 1; i <= 3; i++) {
        expect(queue.contains(1, i), isTrue);
      }
      expect(queue.contains(1, 4), isFalse);
    });

    test('skips empty lines when filling the buffer', () {
      final queue = PreparedAudioQueue(ahead: 3);
      final lines = [
        _line(0),
        _line(1, text: '   '), // empty → skipped
        _line(2),
        _line(3, text: ''), // empty → skipped
        _line(4),
      ];

      queue.ensure(1, 0, lines, (l) async => 'audio-${l.lineId}');

      // Walks `ahead` positions (1..3) and skips empties, so only line 2
      // gets buffered from this window.
      expect(queue.contains(1, 1), isFalse);
      expect(queue.contains(1, 2), isTrue);
      expect(queue.contains(1, 3), isFalse);
      expect(queue.length, 1);
    });

    test('take() returns and removes the matching prepared future', () async {
      final queue = PreparedAudioQueue(ahead: 3);
      final lines = List.generate(10, _line);
      queue.ensure(1, 0, lines, (l) async => 'audio-${l.lineId}');

      final future = queue.take(1, 2);
      expect(future, isNotNull);
      expect(await future, 'audio-2');
      // Taken → no longer buffered.
      expect(queue.take(1, 2), isNull);
      expect(queue.length, 2);
    });

    test('take() returns null for unknown index or foreign session', () {
      final queue = PreparedAudioQueue(ahead: 3);
      final lines = List.generate(10, _line);
      queue.ensure(1, 0, lines, (l) async => 'audio-${l.lineId}');

      expect(queue.take(1, 99), isNull);
      expect(queue.take(2, 1), isNull); // different session
      // Still intact for the original session.
      expect(queue.contains(1, 1), isTrue);
    });

    test('consumed and foreign-session entries are dropped on ensure', () {
      final queue = PreparedAudioQueue(ahead: 3);
      final lines = List.generate(10, _line);
      queue.ensure(1, 0, lines, (l) async => 'audio-${l.lineId}');
      queue.ensure(2, 0, lines, (l) async => 'audio-${l.lineId}');

      // Session 1's entries were dropped (foreign session).
      expect(queue.contains(1, 1), isFalse);
      // Session 2 filled the buffer.
      for (var i = 1; i <= 3; i++) {
        expect(queue.contains(2, i), isTrue);
      }

      // Advance: entries at or before the current index are consumed.
      queue.ensure(2, 3, lines, (l) async => 'audio-${l.lineId}');
      expect(queue.contains(2, 1), isFalse);
      expect(queue.contains(2, 3), isFalse);
      // Buffer re-filled ahead of the new position.
      expect(queue.contains(2, 6), isTrue);
      expect(queue.length, 3);
    });

    test('a failed prefetch resolves to the failed sentinel', () async {
      final queue = PreparedAudioQueue(ahead: 1);
      final lines = List.generate(5, _line);
      // Synchronous throw from the synthesizer.
      queue.ensure(1, 0, lines, (l) => throw StateError('engine unavailable'));

      var future = queue.take(1, 1);
      expect(future, isNotNull);
      expect(await future, PreparedAudioQueue.failed);

      // Failed (async) future from the synthesizer.
      queue.ensure(1, 0, lines, (l) async => throw StateError('engine down'));
      future = queue.take(1, 1);
      expect(future, isNotNull);
      expect(await future, PreparedAudioQueue.failed);
    });

    test('does not re-enqueue an index that is already buffered', () {
      final queue = PreparedAudioQueue(ahead: 3);
      final lines = List.generate(10, _line);
      var calls = 0;
      queue.ensure(1, 0, lines, (l) {
        calls++;
        return Future.value('audio');
      });
      queue.ensure(1, 0, lines, (l) {
        calls++;
        return Future.value('audio');
      });

      expect(calls, 3); // second ensure() enqueued nothing new
      expect(queue.length, 3);
    });

    test('clear() empties the buffer', () {
      final queue = PreparedAudioQueue(ahead: 3);
      final lines = List.generate(10, _line);
      queue.ensure(1, 0, lines, (l) async => 'audio');
      expect(queue.length, 3);
      queue.clear();
      expect(queue.length, 0);
      expect(queue.take(1, 1), isNull);
    });

    test('does not overrun the end of the line list', () {
      final queue = PreparedAudioQueue(ahead: 5);
      final lines = List.generate(2, _line); // only 2 lines total
      queue.ensure(1, 0, lines, (l) async => 'audio');
      expect(queue.length, 1); // only line 1 available
    });
  });
}
