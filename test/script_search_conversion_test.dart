/// Regression tests for script → Roman Pāli conversion, which is the
/// foundation of cross-script search and dictionary lookup:
///
///   * in-book search   — the query is converted to Roman via [velthuis]
///   * global search    — the search textbox converts any script to Roman
///   * double-tap dict  — [convertToRomanPali] turns the displayed word
///                        (Myanmar, Tamil, …) into a Roman headword
///
/// These all used to fail because `TextProcessor.convertFromMixed` crashed
/// on the very first character (null-script run), so the conversion was
/// silently skipped and the original script text was kept.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/core/utils/pali_script_converter.dart';
import '../lib/core/utils/pali_search_utils.dart';
import '../lib/core/utils/pali_text_utils.dart';
import '../lib/core/utils/velthuis.dart';
import '../lib/features/reader/utils/reader_word_hit_test.dart' show cleanPali;

void main() {
  group('TextProcessor.convertFromMixed (root cause)', () {
    test('converts a single non-Latin run to the Sinhala pivot', () {
      expect(TextProcessor.convertFromMixed('ဓမ္မ'), 'ධම්ම');
      expect(TextProcessor.convertFromMixed('த⁴ம்ம'), 'ධම්ම');
    });

    test('converts mixed-script text run by run', () {
      expect(TextProcessor.convertFromMixed('namo ဓမ္မ'), 'නමො ධම්ම');
      expect(TextProcessor.convertFromMixed('namo த⁴ம்ம'), 'නමො ධම්ම');
    });

    test('passes through characters with no known script', () {
      // Superscripts ² ³ ⁴ are Tamil markers, not Tamil codepoints. They
      // merge into the surrounding run so pair mappings (த⁴ → ධ) apply,
      // and a lone marker with no script context is passed through.
      expect(TextProcessor.convertFromMixed('⁴த⁴ம்ம'), '⁴ධම්ම');
    });
  });

  group('velthuis — any script to Roman', () {
    test('Myanmar → Roman', () {
      expect(velthuis('ဓမ္မ'), 'dhamma');
      expect(velthuis('နမော'), 'namo');
    });

    test('Tamil (with superscripts) → Roman', () {
      expect(velthuis('த⁴ம்ம'), 'dhamma');
      expect(velthuis('ப⁴க³வதோ'), 'bhagavato');
    });

    test('Thai (virama form used by the app display) → Roman', () {
      // The app renders Pali in the traditional virama spelling (ธมฺม),
      // which round-trips through the character maps.
      expect(velthuis('ธมฺม'), 'dhamma');
    });

    test('Sinhala → Roman', () {
      expect(velthuis('ධම්ම'), 'dhamma');
    });

    test('mixed text → Roman', () {
      expect(velthuis('namo ဓမ္မ'), 'namo dhamma');
      expect(velthuis('namo த⁴ம்ம'), 'namo dhamma');
    });

    test('already-Roman text is unchanged', () {
      expect(velthuis('dhammaṃ'), 'dhammaṃ');
      expect(velthuis('rāga'), 'rāga');
    });
  });

  group('velthuisDiacritics / convertedTextEditingValue (textbox display)', () {
    test('diacritics-only pass keeps the typed script unchanged', () {
      expect(velthuisDiacritics('ဓမ္မ'), 'ဓမ္မ');
      expect(velthuisDiacritics('နမော tassa'), 'နမော tassa');
    });

    test('diacritics-only pass still renders Velthuis notation', () {
      expect(velthuisDiacritics('dhamma.m'), 'dhammaṃ');
      expect(velthuisDiacritics('raaga'), 'rāga');
    });

    test('convertedTextEditingValue keeps the typed script and the cursor', () {
      const value = TextEditingValue(
        text: 'ဓမ္မ',
        selection: TextSelection.collapsed(offset: 3),
      );
      final result = convertedTextEditingValue(value);
      expect(result.text, 'ဓမ္မ');
      expect(result.selection.baseOffset, 3);
    });

    test(
      'convertedTextEditingValue renders Velthuis notation with cursor math',
      () {
        const value = TextEditingValue(
          text: 'dhamma.m',
          selection: TextSelection.collapsed(offset: 8),
        );
        final result = convertedTextEditingValue(value);
        expect(result.text, 'dhammaṃ');
        expect(result.selection.baseOffset, 7);
      },
    );
  });

  group('convertToRomanPali (double-tap dictionary lookup)', () {
    test('converts the displayed word back to a Roman headword', () {
      expect(convertToRomanPali('ဓမ္မ'), 'dhamma');
      expect(convertToRomanPali('த⁴ம்ம'), 'dhamma');
      expect(convertToRomanPali('ธมฺม'), 'dhamma');
      expect(convertToRomanPali('ධම්ම'), 'dhamma');
    });

    test('cleanPali keeps the Roman headword usable for the dictionary', () {
      // reader_word_hit_test.cleanPali must NOT strip the converted word.
      expect(cleanPali(convertToRomanPali('ဓမ္မ')), 'dhamma');
      expect(cleanPali(convertToRomanPali('த⁴ம்ம')), 'dhamma');
    });
  });

  group('round trip: Roman → display script → Roman', () {
    const words = ['dhamma', 'khetta', 'buddha', 'yathā'];
    const scripts = [
      Script.sinhala,
      Script.myanmar,
      Script.thai,
      Script.tamil,
      Script.devanagari,
    ];

    for (final script in scripts) {
      for (final word in words) {
        test('$word via ${script.name}', () {
          final display = convertPaliToScript(word, script);
          expect(display, isNot(word), reason: 'script must change the text');
          expect(
            convertToRomanPali(display),
            word,
            reason: 'display "$display" should convert back to "$word"',
          );
        });
      }
    }
  });

  group('in-book search normalization pipeline', () {
    test('a Myanmar query normalizes to the same key as the Roman text', () {
      // Mirrors reader_search_notifier._runSearch.
      String keyFor(String raw) =>
          normalizePaliFuzzy(cleanPaliForIndexing(velthuis(raw)));

      expect(keyFor('ဓမ္မ'), keyFor('dhamma'));
      expect(keyFor('த⁴ம்ம'), keyFor('dhamma'));
      expect(keyFor('ධම්ම'), keyFor('dhamma'));
      expect(keyFor('namo ဓမ္မ'), keyFor('namo dhamma'));
    });

    test('a converted query is contained in normalized line text', () {
      final line = normalizePaliFuzzy(cleanPaliForIndexing('dhammaṃ khetta'));
      final term = normalizePaliFuzzy(cleanPaliForIndexing(velthuis('ဓမ္မ')));
      expect(line.contains(term), isTrue);
    });
  });

  group('search result highlighting in the display script', () {
    test('query converted to the display script appears in the text', () {
      // Thai uses the virama spelling the app itself renders (ธมฺม).
      for (final script in [
        Script.tamil,
        Script.myanmar,
        Script.sinhala,
        Script.thai,
      ]) {
        final display = convertPaliToScript('dhamma', script);
        final convertedQuery = convertSearchQueryForScript('dhamma', script);
        expect(
          display.contains(convertedQuery),
          isTrue,
          reason: '${script.name}: "$display" should contain "$convertedQuery"',
        );
      }
    });
  });
}
