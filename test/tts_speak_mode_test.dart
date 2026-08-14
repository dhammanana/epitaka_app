import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/core/database/app_database.dart' show TtsReplacement;
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/features/reader/providers/reader_provider.dart';
import 'package:epitaka/features/reader/providers/reader_tts_controller.dart';
import 'package:epitaka/features/reader/widgets/reader_tts_widgets.dart';
import 'package:epitaka/features/settings/providers/tts_provider.dart';

const _sinhalaRange = (0x0D80, 0x0DFF);

bool _isSinhala(String text) =>
    text.runes.any((r) => r >= _sinhalaRange.$1 && r <= _sinhalaRange.$2);

ParagraphData _para(int paraId, List<LineData> lines) =>
    ParagraphData(paraId: paraId, lines: lines);

LineData _line(
  int lineId, {
  String? pali,
  Map<String, String> translations = const {},
}) =>
    LineData(
      lineId: lineId,
      paliText: pali,
      translations: translations,
      normalizedText: '',
    );

void main() {
  group('paliToSinhalaForTts', () {
    test('converts Roman Pāli with diacritics to Sinhala', () {
      final out = ReaderTtsController.paliToSinhalaForTts('dhammo');
      // Sinhala ක-ෆ block: expect a Sinhala word, not Roman.
      expect(out, isNot('dhammo'));
      expect(out.runes.any((r) => r >= 0x0D80 && r <= 0x0DFF), isTrue);
    });

    test('strips HTML before converting', () {
      final out = ReaderTtsController.paliToSinhalaForTts(
        '<i>evaṃ</i> me sutaṃ',
      );
      expect(out.contains('<i>'), isFalse);
      expect(out.contains('e'), isFalse); // no Roman letters remain
      expect(out.runes.any((r) => r >= 0x0D80 && r <= 0x0DFF), isTrue);
    });

    test('handles already non-Roman Pāli (Myanmar) input', () {
      final out = ReaderTtsController.paliToSinhalaForTts('ဓမ္မ');
      expect(out.runes.any((r) => r >= 0x0D80 && r <= 0x0DFF), isTrue);
    });

    test('empty/whitespace input returns empty string', () {
      expect(ReaderTtsController.paliToSinhalaForTts(''), '');
      expect(ReaderTtsController.paliToSinhalaForTts('   '), '');
    });
  });

  group('buildTtsLines', () {
    final paragraphs = [
      _para(1, [
        _line(1, pali: 'dhammo', translations: {'en': 'the dhamma'}),
        _line(2, pali: 'sabbo', translations: {'en': 'all'}),
      ]),
    ];
    final emptyReplacements = <TtsReplacement>[];

    test('translation mode: only translation items with the lang', () {
      final lines = ReaderTtsController.buildTtsLines(
        paragraphs,
        lang: 'en',
        mode: TtsSpeakMode.translation,
        activeReplacements: emptyReplacements,
      );
      expect(lines.length, 2);
      expect(lines[0].text, 'the dhamma');
      expect(lines[0].language, 'en');
      expect(lines[1].text, 'all');
    });

    test('pali mode: only Sinhala-converted Pāli items with language si',
        () {
      final lines = ReaderTtsController.buildTtsLines(
        paragraphs,
        lang: 'en',
        mode: TtsSpeakMode.pali,
        activeReplacements: emptyReplacements,
      );
      expect(lines.length, 2);
      expect(lines[0].language, 'si');
      expect(lines[0].text, isNot('dhammo'));
      expect(_isSinhala(lines[0].text), isTrue);
      expect(lines[0].text.contains('the dhamma'), isFalse);
    });

    test('pali items carry the Roman source for engine fallback', () {
      final lines = ReaderTtsController.buildTtsLines(
        paragraphs,
        lang: 'en',
        mode: TtsSpeakMode.pali,
        activeReplacements: emptyReplacements,
      );
      expect(lines[0].paliRoman, 'dhammo');
      expect(lines[1].paliRoman, 'sabbo');
      // Translation items carry no Roman source.
      final both = ReaderTtsController.buildTtsLines(
        paragraphs,
        lang: 'en',
        mode: TtsSpeakMode.both,
        activeReplacements: emptyReplacements,
      );
      expect(both[0].paliRoman, isNotNull);
      expect(both[1].paliRoman, isNull); // translation line
    });

    test('both mode: Pāli item first, then translation, same lineId', () {
      final lines = ReaderTtsController.buildTtsLines(
        paragraphs,
        lang: 'en',
        mode: TtsSpeakMode.both,
        activeReplacements: emptyReplacements,
      );
      expect(lines.length, 4);
      expect(lines[0].lineId, 1);
      expect(lines[0].language, 'si');
      expect(lines[1].lineId, 1);
      expect(lines[1].language, 'en');
      expect(lines[1].text, 'the dhamma');
      expect(lines[2].language, 'si');
      expect(lines[3].language, 'en');
      expect(lines[3].text, 'all');
    });

    test('applies TTS replacement rules to translation text', () {
      final rules = [
        TtsReplacement(
          id: 1,
          pattern: 'dhamma',
          replacement: 'damma',
          isRegex: false,
          enabled: true,
          createdAt: DateTime(2026),
        ),
      ];
      final lines = ReaderTtsController.buildTtsLines(
        paragraphs,
        lang: 'en',
        mode: TtsSpeakMode.translation,
        activeReplacements: rules,
      );
      expect(lines[0].text, 'the damma');
    });

    test('skips empty translations and empty Pāli', () {
      final withEmpty = [
        _para(1, [
          _line(1, pali: null, translations: {'en': ''}),
          _line(2, pali: '', translations: {'en': 'ok'}),
        ]),
      ];
      final lines = ReaderTtsController.buildTtsLines(
        withEmpty,
        lang: 'en',
        mode: TtsSpeakMode.both,
        activeReplacements: emptyReplacements,
      );
      // Line 1 has neither Pāli nor translation; line 2's Pāli is empty
      // so only its translation remains.
      expect(lines.length, 1);
      expect(lines[0].lineId, 2);
      expect(lines[0].language, 'en');
      expect(lines[0].text, 'ok');
    });
  });

  group('paliSpeechText', () {
    const sinhala = 'ධම්මො'; // Sinhala conversion of 'dhammo'
    const roman = 'dhammo';

    test('Sinhala script keeps the Sinhala text', () {
      final speech = TtsNotifier.paliSpeechText(
        sinhala,
        roman,
        script: 'si',
        language: 'si',
      );
      expect(speech.language, 'si');
      expect(speech.text, sinhala);
    });

    test('Devanagari script converts to Devanagari + Hindi', () {
      final speech = TtsNotifier.paliSpeechText(
        sinhala,
        roman,
        script: 'hi',
        language: 'hi',
      );
      expect(speech.language, 'hi');
      expect(speech.text.runes.any((r) => r >= 0x0900 && r <= 0x097F), isTrue);
      expect(_isSinhala(speech.text), isFalse);
    });

    test('unsupported scripts fall back to ASCII Roman', () {
      // Only Sinhala and Devanagari (Hindi) are offered now; anything
      // else degrades to readable Roman so a voice always exists.
      final th = TtsNotifier.paliSpeechText(
        sinhala,
        roman,
        script: 'th',
        language: 'th',
      );
      expect(th.language, 'th');
      expect(th.text, roman);

      final my = TtsNotifier.paliSpeechText(
        sinhala,
        roman,
        script: 'my',
        language: 'my',
      );
      expect(my.language, 'my');
      expect(my.text, roman);
    });

    test('Roman script strips diacritics and uses the given language', () {
      final speech = TtsNotifier.paliSpeechText(
        sinhala,
        'evaṃ me sutaṃ',
        script: 'roman',
        language: 'en',
      );
      expect(speech.language, 'en');
      expect(speech.text, 'evam me sutam');
    });
  });

  group('asciiRomanPali', () {
    test('strips IAST diacritics so any voice can read Pāli', () {
      expect(
        TtsNotifier.asciiRomanPali('evaṃ me sutaṃ – ekaṃ samayaṃ'),
        'evam me sutam – ekam samayam',
      );
      expect(TtsNotifier.asciiRomanPali('dhammo'), 'dhammo');
      expect(
        TtsNotifier.asciiRomanPali('vuttañhetaṃ bhagavatā'),
        'vuttanhetam bhagavata',
      );
      expect(TtsNotifier.asciiRomanPali(''), '');
    });
  });

  group('ttsPaliSpeed setting', () {
    test('defaults to 1.0 and persists separately from ttsSpeed', () {
      const settings = AppSettings();
      expect(settings.ttsSpeed, 1.0);
      expect(settings.ttsPaliSpeed, 1.0);

      final updated = settings.copyWith(ttsSpeed: 3.0, ttsPaliSpeed: 0.7);
      expect(updated.ttsSpeed, 3.0);
      expect(updated.ttsPaliSpeed, 0.7);

      // Changing one must not affect the other.
      final onlySpeed = settings.copyWith(ttsSpeed: 2.0);
      expect(onlySpeed.ttsPaliSpeed, 1.0);
    });
  });

  group('filterVoicesForLanguage', () {
    final voices = [
      {'name': 'English US', 'locale': 'en-US'},
      {'name': 'English UK', 'locale': 'en-GB'},
      {'name': 'Sinhala', 'locale': 'si-LK'},
      {'name': 'Deutsch', 'locale': 'de-DE'},
      {'name': 'Thai', 'locale': 'th-TH'},
    ];

    test('keeps only voices matching the language', () {
      final out = filterVoicesForLanguage(voices, 'en',
          selectedVoice: 'default');
      expect(out.map((v) => v['name']), ['English US', 'English UK']);
    });

    test('returns all voices when none match (never empty)', () {
      final out = filterVoicesForLanguage(voices, 'ja',
          selectedVoice: 'default');
      expect(out.length, voices.length);
    });

    test('keeps the selected voice even when it does not match', () {
      final out = filterVoicesForLanguage(voices, 'en',
          selectedVoice: 'Thai');
      expect(out.map((v) => v['name']), contains('Thai'));
    });
  });
}
