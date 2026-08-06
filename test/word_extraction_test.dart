/// Regression tests for double-tap word extraction.
///
/// [RenderParagraph.getWordBoundary] splits words in several scripts (e.g.
/// Myanmar "ဘဂဝတော" → "ဘ","ဂ","ဝ","တော", Thai "ภควโต" → "ภคว","โต" and
/// Tamil "த⁴ம்ம" → "த","⁴","ம்ம"), which made the dictionary lookup search
/// only part of a word. [wordRangeAt] expands to the nearest word boundary
/// instead, so the full word is always looked up.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/core/utils/pali_script_converter.dart';
import '../lib/core/utils/pali_text_utils.dart';
import '../lib/features/reader/utils/reader_word_hit_test.dart'
    show cleanPali, wordRangeAt;

void main() {
  group('wordRangeAt (pure)', () {
    test('returns the full word for taps anywhere inside a Tamil word with '
        'superscripts', () {
      const text = 'த⁴ம்ம';
      for (int i = 0; i < text.length; i++) {
        expect(wordRangeAt(text, i), const TextRange(start: 0, end: 5),
            reason: 'offset $i');
      }
    });

    test('returns full words in a Myanmar sentence', () {
      const text = 'နမော တဿ ဘဂဝတော';
      // နမော (4) space တဿ (2) space ဘဂဝတော (6)
      expect(wordRangeAt(text, 0), const TextRange(start: 0, end: 4));
      expect(wordRangeAt(text, 5), const TextRange(start: 5, end: 7));
      expect(wordRangeAt(text, 8), const TextRange(start: 8, end: 14));
    });

    test('returns full words in a Thai sentence', () {
      const text = 'นโม ตสฺส ภควโต';
      // นโม (3) space ตสฺส (4) space ภควโต (5)
      expect(wordRangeAt(text, 1), const TextRange(start: 0, end: 3));
      expect(wordRangeAt(text, 5), const TextRange(start: 4, end: 8));
      expect(wordRangeAt(text, 9), const TextRange(start: 9, end: 14));
    });

    test('returns full words in Roman with punctuation', () {
      const text = 'dhammaṃ khetta.';
      expect(wordRangeAt(text, 0), const TextRange(start: 0, end: 7));
      expect(wordRangeAt(text, 9), const TextRange(start: 8, end: 14)); // khetta
      expect(wordRangeAt(text, 14), TextRange.empty); // '.' → no word
    });

    test('words at the very start and end of the text', () {
      const text = 'namo dhamma';
      expect(wordRangeAt(text, 0), const TextRange(start: 0, end: 4));
      expect(wordRangeAt(text, 11), const TextRange(start: 5, end: 11));
    });

    test('taps on whitespace return an empty range', () {
      expect(wordRangeAt('namo dhamma', 4), TextRange.empty);
      expect(wordRangeAt(' ', 0), TextRange.empty);
    });

    test('empty text and out-of-range offsets are safe', () {
      expect(wordRangeAt('', 0), TextRange.empty);
      expect(wordRangeAt('dhamma', 99), const TextRange(start: 0, end: 6));
    });

    test('single-letter raw word is still captured (validation happens later)', () {
      expect(wordRangeAt('a b', 0), const TextRange(start: 0, end: 1));
    });

    test('newlines and em/en dashes terminate words', () {
      expect(wordRangeAt('dhamma\ntassa', 7), const TextRange(start: 7, end: 12));
      expect(wordRangeAt('dhamma—tassa', 3), const TextRange(start: 0, end: 6));
      // 'dhamma' (0-5), '–' (6), 'tassa' (7-11); tap on the 'a' (8).
      expect(wordRangeAt('dhamma–tassa', 8), const TextRange(start: 7, end: 12));
      // A space at the tap position still means "no word".
      expect(wordRangeAt('dhamma tassa', 6), TextRange.empty);
    });

    test("straight apostrophes terminate words", () {
      // 'dhamma' (0-7 incl. quotes), 'khetta' (9-15), 'tassa' (17-22).
      expect(wordRangeAt("'dhamma' khetta", 2), const TextRange(start: 1, end: 7));
      expect(wordRangeAt("'dhamma' khetta", 12), const TextRange(start: 9, end: 15));
    });

    test('script-specific punctuation terminates words', () {
      // Tibetan tsheg (་ at offset 4) splits 'དྷམྨ་ཏསྶ' into two words
      // (0-4 and 5-8); the tap is inside the first word.
      expect(wordRangeAt('དྷམྨ་ཏསྶ', 1), const TextRange(start: 0, end: 4));
      expect(wordRangeAt('དྷམྨ་ཏསྶ', 5), const TextRange(start: 5, end: 8));
      expect(wordRangeAt('དྷམྨ་ཏསྶ', 4), TextRange.empty); // on the tsheg
      // 'dhamma' (0-5), '།' (6), 'tassa' (7-11).
      expect(wordRangeAt('dhamma།tassa', 3), const TextRange(start: 0, end: 6));
      expect(wordRangeAt('dhamma།tassa', 7), const TextRange(start: 7, end: 12));
      // 'dhamma' (0-5), '෴' (6), 'tassa' (7-11).
      expect(wordRangeAt('dhamma෴tassa', 8), const TextRange(start: 7, end: 12));
    });

    test('astral (surrogate-pair) characters stay inside the word', () {
      // Brahmi 𑀓𑀫𑁆𑀫 — each glyph is a 2-unit surrogate pair: the first
      // word is 4 glyphs = 8 units, the second (𑀤𑁆𑀳𑀫𑁆𑀫) is 6 glyphs =
      // 12 units, so the second word spans 9-21.
      const text = '𑀓𑀫𑁆𑀫 𑀤𑁆𑀳𑀫𑁆𑀫';
      expect(wordRangeAt(text, 1), const TextRange(start: 0, end: 8));
      expect(wordRangeAt(text, 9), const TextRange(start: 9, end: 21));
      expect(wordRangeAt(text, 8), TextRange.empty); // on the space
    });
  });

  group('extraction through the real render path', () {
    // Renders a converted Pali sentence and simulates taps across the line,
    // exactly like the reader does: getPositionForOffset → wordRangeAt →
    // convertToRomanPali → cleanPali. Every extracted word must be one of
    // the expected Roman words — never a partial word.
    const romanWords = {'namo', 'tassa', 'bhagavato', 'arahato'};

    Future<Set<String>> extractWords(
      WidgetTester tester,
      Script script,
    ) async {
      const roman = 'namo tassa bhagavato arahato';
      final display = convertPaliToScript(roman, script);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              display,
              key: key,
              style: TextStyle(fontFamily: scriptFontFamily(script)),
            ),
          ),
        ),
      );
      final render =
          key.currentContext!.findRenderObject()! as RenderParagraph;
      final plain = render.text.toPlainText();
      final width = render.size.width;

      final words = <String>{};
      // Sweep taps across the whole rendered area — x across the width and
      // y down the paragraph (long lines wrap onto several lines) — exactly
      // mimicking the reader's getPositionForOffset → wordRangeAt flow.
      final height = render.size.height;
      for (double y = 2; y < height - 1; y += 4) {
        for (double x = 1; x < width - 1; x += 4) {
          final pos = render.getPositionForOffset(Offset(x, y));
          final range = wordRangeAt(plain, pos.offset);
          if (range.isCollapsed) continue;
          final raw = plain.substring(range.start, range.end);
          final cleaned = cleanPali(convertToRomanPali(raw));
          if (cleaned.isNotEmpty) words.add(cleaned);
        }
      }
      return words;
    }

    for (final script in [
      Script.myanmar,
      Script.thai,
      Script.tamil,
      Script.sinhala,
      Script.roman,
    ]) {
      testWidgets('${script.name}: every extracted word is a complete '
          'dictionary word (no partials)', (WidgetTester tester) async {
        final words = await extractWords(tester, script);
        // Every extracted word must be a full Roman word from the sentence.
        expect(
          words.difference(romanWords),
          isEmpty,
          reason: '${script.name}: extracted partial/garbage words: '
              '${words.difference(romanWords)}',
        );
        // And all words must actually be reachable by tapping.
        expect(words, romanWords,
            reason: '${script.name}: some words were not extracted');
      });
    }
  });
}
