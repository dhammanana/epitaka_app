/// Unit tests for Pāli → Tamil script conversion.
///
/// The expected Tamil strings are taken from the actual converted output of
/// the VipassanaTech/tipitaka-xml project (Deva2Taml.cs, taml/ directory),
/// so the conversion follows the same conventions:
///   * aspirated/voiced consonants marked with superscripts ² ³ ⁴
///   * superscripts moved after the vowel sign / virama (கா², க்³)
///   * short எ/ஒ/ெ/ொ before a doubled consonant, long ஏ/ஓ/ே/ோ elsewhere
///   * dental ந → alveolar ன within a word, except before dental stops
///   * anusvara written as ங், and "a" (no inherent vowel in Tamil) unwritten
library;

import 'package:flutter_test/flutter_test.dart';

import '../lib/core/utils/pali_script_converter.dart';
import '../lib/core/utils/pali_text_utils.dart';

void main() {
  group('convertPaliToScript → Tamil', () {
    test('namo tassa bhagavato... matches the tipitaka-xml Tamil file', () {
      // Compare against the real first line of taml/e0101n.mul.xml.
      const roman = 'namo tassa bhagavato arahato sammāsambuddhassa';
      const tamil = 'நமோ தஸ்ஸ ப⁴க³வதோ அரஹதோ ஸம்மாஸம்பு³த்³த⁴ஸ்ஸ';
      expect(convertPaliToScript(roman, Script.tamil), tamil);
    });

    test('words from the Visuddhimagga opening match the tipitaka-xml file',
        () {
      // <p rend="book">விஸுத்³தி⁴மக்³கோ³</p>
      expect(
        convertPaliToScript('visuddhimaggo', Script.tamil),
        'விஸுத்³தி⁴மக்³கோ³',
      );
      // <p rend="subhead">(பட²மோ பா⁴கோ³)</p>
      expect(
        convertPaliToScript('(paṭhamo bhāgo)', Script.tamil),
        '(பட²மோ பா⁴கோ³)',
      );
    });

    test('uses short e/o before doubled consonants, long elsewhere', () {
      // heṭṭhu → ஹெட்டு² (short ெ before ட்ட)
      expect(convertPaliToScript('heṭṭhu', Script.tamil), 'ஹெட்டு²');
      // etaṃ → ஏதங் (long ஏ before single த)
      expect(convertPaliToScript('etaṃ', Script.tamil), 'ஏதங்');
      // khetta → கெ²த்த (short ெ + superscript after the sign)
      expect(convertPaliToScript('khetta', Script.tamil), 'கெ²த்த');
      // ekka → எக்க (independent short எ before க்க)
      expect(convertPaliToScript('ekka', Script.tamil), 'எக்க');
      // eka → ஏக (independent long ஏ before single க)
      expect(convertPaliToScript('eka', Script.tamil), 'ஏக');
    });

    test('moves superscripts after vowel signs and virama', () {
      expect(convertPaliToScript('yathā', Script.tamil), 'யதா²');
      expect(convertPaliToScript('sabbā', Script.tamil), 'ஸப்³பா³');
      expect(convertPaliToScript('pucchāmi', Script.tamil), 'புச்சா²மி');
    });

    test('uses alveolar ன medially and dental ந before dental stops', () {
      expect(convertPaliToScript('attano', Script.tamil), 'அத்தனோ');
      expect(convertPaliToScript('vantaṃ', Script.tamil), 'வந்தங்');
      expect(convertPaliToScript('na', Script.tamil), 'ந');
    });

    test('writes anusvara as ங் and drops the inherent a', () {
      expect(convertPaliToScript('sammā', Script.tamil), 'ஸம்மா');
      expect(convertPaliToScript('dhammaṃ', Script.tamil), 'த⁴ம்மங்');
    });

    test('tamil text is recognized as a non-Latin script', () {
      expect(isNonLatinScript('த⁴ம்ம'), isTrue);
      expect(isNonLatinScript('அத்தனோ'), isTrue);
    });
  });

  group('Tamil → Sinhala round trip', () {
    test('converts the tipitaka-xml namo tassa line back to Sinhala', () {
      expect(
        TextProcessor.convertFrom(
          'நமோ தஸ்ஸ ப⁴க³வதோ அரஹதோ ஸம்மாஸம்பு³த்³த⁴ஸ்ஸ',
          Script.tamil,
        ),
        'නමො තස්ස භගවතො අරහතො සම්මාසම්බුද්ධස්ස',
      );
    });

    test('round-trips superscripts, short e/o and the ன/ந rule', () {
      expect(TextProcessor.convertFrom('ஹெட்டு²', Script.tamil), 'හෙට්ඨු');
      expect(TextProcessor.convertFrom('கெ²த்த', Script.tamil), 'ඛෙත්ත');
      expect(TextProcessor.convertFrom('வந்தங்', Script.tamil), 'වන්තං');
      expect(TextProcessor.convertFrom('யதா²', Script.tamil), 'යථා');
    });
  });
}
