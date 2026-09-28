/// Regression tests for the Vīmaṃsā "best text model" auto-pick.
///
/// Gemini GA'd `gemini-3.8-flash-tts` / `gemini-3.8-flash-lite-tts` (Sept 2026)
/// broke the old "newest flash model wins" heuristic: the TTS ids sort above
/// the text models and also support `generateContent`. These tests pin the
/// general rule — modality markers in the id exclude a model from text roles.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/features/ai_qa/services/answer_fallbacks.dart';
import 'package:epitaka/features/shared/services/gemini_text_models.dart';

/// Model list as returned by [AiModelService] for Gemini: newest-first,
/// TTS variants included (as the real API now returns them).
List<String> _fetchedModels() => const [
  'gemini-3.8-flash-tts',
  'gemini-3.8-flash-lite-tts',
  'gemini-3.6-flash',
  'gemini-3.5-flash-lite',
  'gemini-2.5-flash',
  'gemini-2.5-flash-lite',
];

void main() {
  group('isGeminiTextModel', () {
    test('keeps text/chat models', () {
      expect(isGeminiTextModel('gemini-3.6-flash'), isTrue);
      expect(isGeminiTextModel('gemini-2.5-flash'), isTrue);
      expect(isGeminiTextModel('gemini-3.5-flash-lite'), isTrue);
      expect(isGeminiTextModel('gemini-2.5-flash-lite'), isTrue);
      expect(isGeminiTextModel('gemini-2.5-pro'), isTrue);
    });

    test('excludes the new TTS models and other modalities generally', () {
      expect(isGeminiTextModel('gemini-3.8-flash-tts'), isFalse);
      expect(isGeminiTextModel('gemini-3.8-flash-lite-tts'), isFalse);
      expect(isGeminiTextModel('gemini-2.5-flash-preview-tts'), isFalse);
      expect(isGeminiTextModel('gemini-3.1-flash-live'), isFalse);
      expect(isGeminiTextModel('gemini-3.5-live-translate'), isFalse);
      expect(isGeminiTextModel('gemini-3.1-flash-image-preview'), isFalse);
      expect(
        isGeminiTextModel('gemini-2.5-flash-native-audio-preview'),
        isFalse,
      );
      expect(
        isGeminiTextModel('veo-3.1-generate-preview'),
        isTrue,
        reason: 'non-gemini- ids are left alone',
      );
    });
  });

  group('best-model pickers', () {
    test('answer model skips newer TTS variants', () {
      expect(pickBestGeminiAnswerModel(_fetchedModels()), 'gemini-3.6-flash');
    });

    test('tool model skips newer TTS-lite variants', () {
      expect(
        pickBestGeminiToolModel(_fetchedModels()),
        'gemini-3.5-flash-lite',
      );
    });

    test('answer picker prefers stable over preview at same version', () {
      expect(
        pickBestGeminiAnswerModel(const [
          'gemini-3.6-flash-preview',
          'gemini-3.6-flash',
        ]),
        'gemini-3.6-flash',
      );
    });

    test('answer picker prefers newer version over stable older', () {
      expect(
        pickBestGeminiAnswerModel(const [
          'gemini-2.5-flash',
          'gemini-3.6-flash-preview',
        ]),
        'gemini-3.6-flash-preview',
      );
    });
  });

  group('resolveAnswerFallbacks', () {
    test('never falls back to a TTS model', () {
      final fallbacks = resolveAnswerFallbacks(
        answerModel: 'gemini-3.6-flash',
        toolModel: 'gemini-3.5-flash-lite',
        availableModels: _fetchedModels(),
      );
      expect(fallbacks.any((m) => m.toLowerCase().contains('tts')), isFalse);
      expect(fallbacks, contains('gemini-2.5-flash'));
    });
  });
}
