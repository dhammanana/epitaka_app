/// Regression: Tibetan Pāli must use the bundled NotoSerifTibetan font.
///
/// Android's platform font stack includes Noto Sans Tibetan, so Tibetan Pāli
/// rendered correctly there even when `scriptFontFamily` returned `null`
/// (platform fallback). iOS ships NO system Tibetan font, so the same text
/// rendered as tofu boxes (□). The fix bundles NotoSerifTibetan and returns
/// it from `scriptFontFamily(Script.tibetan)`.
library;

import 'package:epitaka/core/utils/pali_script_converter.dart';
import 'package:epitaka/core/utils/pali_text_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tibetan resolves to the bundled NotoSerifTibetan font', () {
    expect(scriptFontFamily(Script.tibetan), 'NotoSerifTibetan');
  });

  test('tibetan Pāli conversion still produces Tibetan-block characters', () {
    // Roman → Tibetan goes through the Sinhala pivot.
    final converted = convertPaliToScript('dhammaṃ', Script.tibetan);
    expect(converted, isNotEmpty);
    // No leftover Latin letters — the conversion must be complete.
    expect(converted, isNot(contains(RegExp(r'[a-zA-Z]'))));
    // Every codepoint lives in the Tibetan block (U+0F00–U+0FFF).
    for (final rune in converted.runes) {
      expect(
        rune,
        inInclusiveRange(0x0F00, 0x0FFF),
        reason: 'unexpected non-Tibetan char U+${rune.toRadixString(16)} '
            'in "$converted"',
      );
    }
  });
}
