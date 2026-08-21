import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/core/utils/pali_script_converter.dart';
import 'package:epitaka/features/reader/utils/reader_word_hit_test.dart';

void main() {
  test('probe: convertToRomanPali on Myanmar text', () {
    // ဘဂဝတော = bhagavato
    const myanmar = 'ဘဂဝတော';
    final roman = convertToRomanPali(myanmar);
    // ignore: avoid_print
    print('PROBE convertToRomanPali("$myanmar") -> "$roman"');
    // ignore: avoid_print
    print('PROBE isNonLatinScript -> ${isNonLatinScript(myanmar)}');
    // ignore: avoid_print
    print('PROBE cleanPali("$roman") -> "${cleanPali(roman)}"');
  });

  test('probe: wordRangeAt on Myanmar text', () {
    // "Namo tassa ဘဂဝတော arahato" — word boundaries around Myanmar word
    const text = 'Namo tassa ဘဂဝတော arahato';
    const offset = 12; // inside ဘဂဝတော (index of 'ဂ')
    final range = wordRangeAt(text, offset);
    // ignore: avoid_print
    print(
      'PROBE wordRangeAt text="$text" offset=$offset -> '
      'start=${range.start} end=${range.end} word="${text.substring(range.start, range.end)}"',
    );
  });

  test('probe: wordRangeAt on Myanmar text only', () {
    const text = 'ဘဂဝတော';
    for (var i = 0; i < text.length; i++) {
      final range = wordRangeAt(text, i);
      // ignore: avoid_print
      print(
        'PROBE offset=$i (U+${text.codeUnitAt(i).toRadixString(16)}) -> '
        'start=${range.start} end=${range.end}',
      );
    }
  });
}
