import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/features/reader/providers/tts_reading_provider.dart'
    show TtsLineItem;
import 'package:epitaka/features/reader/providers/tts_speak_unit.dart';

TtsLineItem _line(
  int paraId,
  int lineId,
  String text, {
  String? language,
  String? paliRoman,
}) =>
    TtsLineItem(
      paraId: paraId,
      lineId: lineId,
      text: text,
      language: language,
      paliRoman: paliRoman,
    );

List<TtsSpeakUnit> _build(List<TtsLineItem> lines) => buildSpeakUnits(
      lines: lines,
      textOf: (l) => l.text,
      paraIdOf: (l) => l.paraId,
      lineIdOf: (l) => l.lineId,
      languageOf: (l) => l.language,
      paliRomanOf: (l) => l.paliRoman,
    );

void main() {
  group('buildSpeakUnits', () {
    test('merges consecutive same-paragraph translation lines', () {
      final units = _build([
        _line(1, 0, 'First sentence.', language: 'en'),
        _line(1, 1, 'Second sentence.', language: 'en'),
      ]);
      expect(units, hasLength(1));
      expect(units.first.text, 'First sentence. Second sentence.');
      expect(units.first.lineRanges, hasLength(2));
      expect(units.first.lineRanges[0].lineId, 0);
      expect(units.first.lineRanges[0].start, 0);
      expect(units.first.lineRanges[1].start,
          'First sentence.'.length + 1);
      expect(units.first.lineIndices, [0, 1]);
    });

    test('splits on paragraph change', () {
      final units = _build([
        _line(1, 0, 'Para one.', language: 'en'),
        _line(2, 0, 'Para two.', language: 'en'),
      ]);
      expect(units, hasLength(2));
      expect(units[0].paraId, 1);
      expect(units[1].paraId, 2);
    });

    test('alternating Pali/translation stays line-by-line', () {
      final units = _build([
        _line(1, 0, 'dhammo', language: 'si', paliRoman: 'dhammo'),
        _line(1, 0, 'The teaching.', language: 'en'),
        _line(1, 1, 'suttaṃ', language: 'si', paliRoman: 'suttam'),
        _line(1, 1, 'The discourse.', language: 'en'),
      ]);
      // One utterance carries one voice: no merging across the switch.
      expect(units, hasLength(4));
      expect(units[0].isPali, isTrue);
      expect(units[1].isPali, isFalse);
    });

    test('Pali-only lines merge and join roman sources', () {
      final units = _build([
        _line(1, 0, 'aaa', language: 'si', paliRoman: 'aaa-r'),
        _line(1, 1, 'bbb', language: 'si', paliRoman: 'bbb-r'),
      ]);
      expect(units, hasLength(1));
      expect(units.first.text, 'aaa bbb');
      expect(units.first.paliRoman, 'aaa-r bbb-r');
    });

    test('skips empty lines', () {
      final units = _build([
        _line(1, 0, 'Hello.', language: 'en'),
        _line(1, 1, '   ', language: 'en'),
        _line(1, 2, 'World.', language: 'en'),
      ]);
      expect(units, hasLength(1));
      expect(units.first.lineIndices, [0, 2]);
    });

    test('splits oversized units on line boundaries only', () {
      final big = 'x' * 1498;
      final units = _build([
        _line(1, 0, big, language: 'en'),
        _line(1, 1, 'tail', language: 'en'),
      ]);
      expect(units, hasLength(2));
      expect(units[1].text, 'tail');
    });
  });

  group('offset mapping', () {
    test('findLineSlotAtOffset resolves lines and clamps', () {
      final units = _build([
        _line(1, 0, 'First sentence.', language: 'en'),
        _line(1, 1, 'Second sentence.', language: 'en'),
      ]);
      final unit = units.first;
      expect(findLineSlotAtOffset(unit, 0), 0);
      expect(findLineSlotAtOffset(unit, unit.lineRanges[0].end - 1), 0);
      expect(findLineSlotAtOffset(unit, unit.lineRanges[1].start), 1);
      // Past the end clamps to the last line, never throws.
      expect(findLineSlotAtOffset(unit, 9999), 1);
    });

    test('toLocal converts unit offsets to line-local offsets', () {
      final units = _build([
        _line(1, 0, 'First sentence.', language: 'en'),
        _line(1, 1, 'Second sentence.', language: 'en'),
      ]);
      final unit = units.first;
      final range = unit.lineRanges[1];
      expect(toLocal(range, range.start), 0);
      expect(toLocal(range, range.start + 3), 3);
      expect(toLocal(range, 9999), range.end - range.start);
    });
  });

  group('word index mapping', () {
    test('ttsWordIndexAtOffset counts whitespace-separated words', () {
      expect(ttsWordIndexAtOffset('First Second Third', 0), 0);
      expect(ttsWordIndexAtOffset('First Second Third', 7), 1);
      expect(ttsWordIndexAtOffset('First Second Third', 999), 2);
      expect(ttsWordIndexAtOffset('', 0), 0);
    });

    test('mapSpokenOffsetToSource passes translation through', () {
      const text = 'The teaching is profound.';
      expect(
        mapSpokenOffsetToSource(
          source: text,
          spoken: text,
          spokenOffset: 10,
        ),
        10,
      );
    });

    test('mapSpokenOffsetToSource maps across scripts by word', () {
      // Same words, different char lengths (Sinhala vs Roman): the second
      // word's offset maps to the second word in the source.
      const source = 'aaa bbb ccc';
      const spoken = 'ආආආ බිබිබි සසස';
      final mapped = mapSpokenOffsetToSource(
        source: source,
        spoken: spoken,
        spokenOffset: spoken.indexOf('බ'),
      );
      final spans = ttsWordSpansOf(source);
      expect(mapped, inInclusiveRange(spans[1].start, spans[1].end));
    });

    test('mapSpokenOffsetToSource degrades proportionally on mismatch', () {
      final mapped = mapSpokenOffsetToSource(
        source: 'aaa',
        spoken: 'aaa bbb ccc',
        spokenOffset: 11,
      );
      expect(mapped, inInclusiveRange(0, 3));
    });
  });

  group('ttsReconcileWordIndex', () {
    test('keeps the offset guess when the word matches', () {
      expect(
        ttsReconcileWordIndex(
          lineText: 'The teaching is profound',
          expectedIndex: 1,
          reportedWord: 'teaching',
          isPali: false,
        ),
        1,
      );
    });

    test('snaps to a nearby match when the offset drifted', () {
      expect(
        ttsReconcileWordIndex(
          lineText: 'The teaching is profound',
          expectedIndex: 0,
          reportedWord: 'profound',
          isPali: false,
        ),
        3,
      );
    });

    test('matches Pāli across scripts by pivoting to source', () {
      // Sinhala line, Kannada engine report for the 2nd word, offset
      // guess pointing at the 1st — re-anchors to the 2nd.
      expect(
        ttsReconcileWordIndex(
          lineText: 'එවං මෙ සුතං',
          expectedIndex: 0,
          reportedWord: 'ಮೇ',
          isPali: true,
        ),
        1,
      );
    });

    test('prefix match handles merged/split engine ranges', () {
      expect(
        ttsReconcileWordIndex(
          lineText: 'එවං මෙ සුතං',
          expectedIndex: 2,
          reportedWord: 'සුත',
          isPali: true,
        ),
        2,
      );
    });

    test('falls back to expected when nothing matches', () {
      expect(
        ttsReconcileWordIndex(
          lineText: 'The teaching is profound',
          expectedIndex: 1,
          reportedWord: 'xyzzy',
          isPali: false,
        ),
        1,
      );
    });
  });

  group('word spans', () {
    test('highlights the indexed word and keeps surrounding text', () {
      const style = TextStyle(fontSize: 14);
      const colors = ColorScheme.light();
      final spans = buildTtsWordIndexSpans(
        plainText: 'First Second Third',
        baseStyle: style,
        colors: colors,
        wordIndex: 1,
      );
      expect(spans, hasLength(3));
      final pill = spans[1] as WidgetSpan;
      final box = pill.child as Container;
      expect((box.child as Text).data, 'Second');
      expect((spans.first as TextSpan).text, 'First ');
      expect((spans.last as TextSpan).text, ' Third');
    });

    test('out-of-range index degrades to plain text', () {
      const style = TextStyle(fontSize: 14);
      const colors = ColorScheme.light();
      final spans = buildTtsWordIndexSpans(
        plainText: 'Hello',
        baseStyle: style,
        colors: colors,
        wordIndex: 5,
      );
      expect(spans, hasLength(1));
      expect((spans.first as TextSpan).text, 'Hello');
    });
  });

  group('TtsUtteranceQueue', () {
    test('start/done route to the head in order', () {
      final q = TtsUtteranceQueue();
      q.enqueue('first');
      q.enqueue('second');
      expect(q.markStarted()?.speakText, 'first');
      expect(q.markStarted()?.speakText, 'second');
      expect(q.markStarted(), isNull);
      expect(q.popHead()?.speakText, 'first');
      expect(q.popHead()?.speakText, 'second');
      expect(q.popHead(), isNull);
    });

    test('progress routes by text, older duplicate first', () {
      final q = TtsUtteranceQueue();
      q.enqueue('same');
      q.enqueue('same');
      q.enqueue('other');
      expect(q.matchByText('other')?.speakText, 'other');
      // Identical adjacent texts resolve to the older entry: its events
      // precede its completion, which pops it.
      expect(q.matchByText('same'), same(q.matchByText('same')));
      q.popHead();
      expect(q.matchByText('same')?.speakText, 'same');
      expect(q.length, 2);
    });

    test('resolveAll completes outstanding futures', () async {
      final q = TtsUtteranceQueue();
      final a = q.enqueue('a');
      final b = q.enqueue('b');
      var done = 0;
      unawaited(a.completer.future.then((_) => done++));
      unawaited(b.completer.future.then((_) => done++));
      q.resolveAll();
      await Future<void>.delayed(Duration.zero);
      expect(done, 2);
      expect(q.isEmpty, isTrue);
    });

    test('removeEntry drops a rejected speak without touching others', () {
      final q = TtsUtteranceQueue();
      final doomed = q.enqueue('bad');
      q.enqueue('good');
      expect(q.removeEntry(doomed), isTrue);
      doomed.resolve();
      expect(q.length, 1);
      expect(q.popHead()?.speakText, 'good');
    });
  });

  group('ttsPlainTextForSpeech', () {
    test('strips tags for offset alignment with the engine', () {
      expect(ttsPlainTextForSpeech('Hello <b>world</b>'), 'Hello world');
    });
  });
}
