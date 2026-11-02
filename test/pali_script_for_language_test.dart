import 'package:epitaka/core/utils/l10n/app_strings.dart';
import 'package:epitaka/core/utils/pali_script_converter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UI language maps to its own Pali script', () {
    expect(scriptForLanguageCode('en'), Script.roman);
    expect(scriptForLanguageCode('hi'), Script.devanagari);
    expect(scriptForLanguageCode('si'), Script.sinhala);
    expect(scriptForLanguageCode('th'), Script.thai);
    expect(scriptForLanguageCode('my'), Script.myanmar);
    expect(scriptForLanguageCode('lo'), Script.laos);
  });

  test('languages without a Pali script fall back to roman', () {
    expect(scriptForLanguageCode('vi'), Script.roman);
    expect(scriptForLanguageCode('zh'), Script.roman);
    expect(scriptForLanguageCode('fr'), Script.roman);
  });

  test('a language added with an existing script resolves without new code', () {
    expect(scriptForLanguageCode('kn'), Script.kannada);
  });

  test('every supported UI language resolves to a script', () {
    for (final code in AppStrings.supportedCodes) {
      expect(scriptForLanguageCode(code), isA<Script>(), reason: code);
    }
  });
}
