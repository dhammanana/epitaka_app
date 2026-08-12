// Tests for the Script Converter service:
//   • convertPaliAnyScript — converts between ANY two scripts via the
//     Sinhala pivot (matches reader/search/dictionary behaviour).
//   • detectDominantScript — best-effort script detection for the UI badge.

import 'package:flutter_test/flutter_test.dart';
import 'package:epitaka/core/utils/pali_script_converter.dart' show Script;
import 'package:epitaka/features/script_converter/services/script_conversion.dart';

void main() {
  group('convertPaliAnyScript', () {
    test('Roman → Sinhala', () {
      expect(
        convertPaliAnyScript('dhammaṃ saraṇaṃ gacchāmi', Script.sinhala),
        'ධම්මං සරණං ගච්ඡාමි',
      );
    });

    test('Roman → Devanagari', () {
      expect(
        convertPaliAnyScript('dhammaṃ saraṇaṃ gacchāmi', Script.devanagari),
        'धम्मं सरणं गच्छामि',
      );
    });

    test('Sinhala → Devanagari (non-Roman source)', () {
      expect(
        convertPaliAnyScript('ධම්මං සරණං ගච්ඡාමි', Script.devanagari),
        'धम्मं सरणं गच्छामि',
      );
    });

    test('Devanagari → Myanmar', () {
      expect(
        convertPaliAnyScript('धम्मं सरणं गच्छामि', Script.myanmar),
        'ဓမ္မံ သရဏံ ဂစ္ဆာမိ',
      );
    });

    test('Roman → Roman passes through unchanged (casing preserved)', () {
      // A tool screen shouldn't silently lowercase the user's input.
      final out = convertPaliAnyScript('Dhammaṃ saraṇaṃ gacchāmi', Script.roman);
      expect(out, 'Dhammaṃ saraṇaṃ gacchāmi');
    });

    test('empty input returns empty', () {
      expect(convertPaliAnyScript('', Script.sinhala), '');
      expect(convertPaliAnyScript('   ', Script.sinhala), '');
    });
  });

  group('detectDominantScript', () {
    test('empty text returns null', () {
      expect(detectDominantScript(''), isNull);
      expect(detectDominantScript('   '), isNull);
    });

    test('Roman/IAST text detects roman', () {
      expect(detectDominantScript('dhammaṃ'), Script.roman);
    });

    test('Sinhala text detects sinhala', () {
      expect(detectDominantScript('ධම්මං සරණං ගච්ඡාමි'), Script.sinhala);
    });

    test('Devanagari text detects devanagari', () {
      expect(detectDominantScript('धम्मं सरणं गच्छामि'), Script.devanagari);
    });

    test('Myanmar text detects myanmar', () {
      expect(detectDominantScript('ဓမ္မံ သရဏံ ဂစ္ဆာမိ'), Script.myanmar);
    });

    test('mixed Roman + Sinhala picks the majority (Sinhala)', () {
      // "dhamma" (Roman) + long Sinhala run → Sinhala wins.
      expect(
        detectDominantScript('dhamma ධම්මං සරණං ගච්ඡාමි'),
        Script.sinhala,
      );
    });
  });
}
