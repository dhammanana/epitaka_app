import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/pali_script_converter.dart' show Script;
import 'package:epitaka/core/utils/pali_text_utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// A reading font may now come from the Google Fonts catalog. Its choice is
/// persisted as `gf:<family name>` and resolved to that family, with the
/// bundled font left behind it for the glyphs it does not have.
void main() {
  group('ReadingFontFamily', () {
    test('bundled families keep their codes and fonts', () {
      expect(ReadingFontFamily.serif.code, 'serif');
      expect(ReadingFontFamily.serif.fontFamily, 'NotoSerif');
      expect(ReadingFontFamily.sansSerif.fontFamily, 'DejaVuSans');
      expect(ReadingFontFamily.mono.fontFamily, 'DejaVuSansMono');
      expect(ReadingFontFamily.values, hasLength(3));
      expect(ReadingFontFamily.serif.isGoogleFont, isFalse);
    });

    test('a Google font round-trips through its code', () {
      final lora = ReadingFontFamily.google('Lora');
      expect(lora.code, 'gf:Lora');
      expect(lora.label, 'Lora');
      expect(lora.isGoogleFont, isTrue);
      expect(ReadingFontFamily.fromCode('gf:Lora'), lora);
    });

    test('unknown codes fall back to the serif default', () {
      expect(ReadingFontFamily.fromCode('nope'), ReadingFontFamily.serif);
      expect(ReadingFontFamily.fromCode('gf:'), ReadingFontFamily.serif);
    });

    test('translations serialize the Google choice', () {
      final typography = const LanguageTypography().copyWith(
        fontFamily: ReadingFontFamily.google('EB Garamond'),
      );
      final restored = LanguageTypography.fromJson(typography.toJson());
      expect(restored.fontFamily, typography.fontFamily);
      expect(restored.fontFamily.label, 'EB Garamond');
      expect(restored, typography);
    });

    test('Devanagari languages keep a bundled family behind the choice', () {
      expect(
        ReadingFontFamily.serif.bundledFamilyForLanguage('hi'),
        'NotoSerifDevanagari',
      );
      expect(
        ReadingFontFamily.mono.bundledFamilyForLanguage('ne'),
        'NotoSansDevanagari',
      );
      expect(ReadingFontFamily.serif.bundledFamilyForLanguage('en'), 'NotoSerif');
    });
  });

  group('paliFontFallback', () {
    test('is empty for the bundled choices', () {
      for (final family in ReadingFontFamily.values) {
        expect(paliFontFallback(Script.roman, family), isEmpty);
      }
    });

    test('keeps the bundled script font behind a Google choice', () {
      expect(
        paliFontFallback(Script.sinhala, ReadingFontFamily.google('Lora')),
        ['NotoSansSinhala'],
      );
      // Roman falls back to the bundled serif, which carries the diacritics.
      expect(
        paliFontFallback(Script.roman, ReadingFontFamily.google('Lora')),
        ['NotoSerif'],
      );
    });

    test('a Google choice is the reading family for every script', () {
      final lora = ReadingFontFamily.google('Lora');
      for (final script in Script.values) {
        expect(paliReadingFontFamily(script, lora), isNotNull);
      }
    });
  });
}
