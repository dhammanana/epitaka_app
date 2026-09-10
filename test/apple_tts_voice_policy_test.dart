import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/core/utils/native_speech_service.dart';

// REGRESSION GUARD — Apple TTS must use a Siri / premium / enhanced voice,
// never the default compact ("robot") voice.
//
// Background: macOS switched from NSSpeechSynthesizer (which uses the system
// Siri voice) to AVSpeechSynthesizer for completion callbacks, but picked the
// voice with `AVSpeechSynthesisVoice(language:)` — the default compact voice.
// If any future edit weakens the premium/Siri-first ordering below, these
// tests fail. The native scorers (iOS `findBestVoice`, macOS `resolveVoice`)
// mirror `AppleTtsVoicePolicy.score` — keep them in sync.

const _siriPremiumEnUs = AppleTtsVoice(
  identifier: 'com.apple.voice.premium.en-US.Ava',
  name: 'Ava (Premium)',
  language: 'en-US',
  quality: 'premium',
);

const _siriByName = AppleTtsVoice(
  identifier: 'com.apple.voice.custom.en-US.Siri',
  name: 'Siri Voice 1',
  language: 'en-US',
  quality: 'default',
);

const _enhancedEnUs = AppleTtsVoice(
  identifier: 'com.apple.ttsbundle.Samantha-enhanced',
  name: 'Samantha (Enhanced)',
  language: 'en-US',
  quality: 'enhanced',
);

const _compactEnUs = AppleTtsVoice(
  identifier: 'com.apple.ttsbundle.Samantha-compact',
  name: 'Samantha (Compact)',
  language: 'en-US',
  quality: 'default',
);

const _premiumEnGb = AppleTtsVoice(
  identifier: 'com.apple.voice.premium.en-GB.Malcolm',
  name: 'Malcolm (Premium)',
  language: 'en-GB',
  quality: 'premium',
);

const _eloquence = AppleTtsVoice(
  identifier: 'com.apple.eloquence.en-US',
  name: 'Eloquence',
  language: 'en-US',
  quality: 'default',
);

const _samanthaSystemDefault = AppleTtsVoice(
  identifier: 'com.apple.voice.compact.en-US.Samantha',
  name: 'Samantha',
  language: 'en-US',
  quality: 'default',
  systemDefault: true,
);

const _avaPremiumSystemDefault = AppleTtsVoice(
  identifier: 'com.apple.voice.premium.en-US.Ava',
  name: 'Ava',
  language: 'en-US',
  quality: 'premium',
  systemDefault: true,
);

const _zoePremium = AppleTtsVoice(
  identifier: 'com.apple.voice.premium.en-US.Zoe',
  name: 'Zoe',
  language: 'en-US',
  quality: 'premium',
);

/// Apple's neural Siri voices ("Voice 1..5" in Settings) expose no
/// siri/premium/enhanced markers — only the system-default flag and the
/// absence of known-bad markers identify them.
const _siriVoice1Unmarked = AppleTtsVoice(
  identifier: 'com.apple.ttsbundle.voice1_en-US',
  name: 'Voice 1',
  language: 'en-US',
  quality: 'default',
  systemDefault: true,
);

const _catherineCompactSiri = AppleTtsVoice(
  identifier: 'com.apple.ttsbundle.siri_catherine_en-AU_compact',
  name: 'Catherine',
  language: 'en-AU',
  quality: 'default',
);

const _allEn = [
  _compactEnUs,
  _eloquence,
  _enhancedEnUs,
  _siriByName,
  _siriPremiumEnUs,
  _premiumEnGb,
];

void main() {
  group('AppleTtsVoicePolicy.score', () {
    test('premium Siri voice outranks compact and enhanced', () {
      const target = 'en-US';
      const system = 'en-US';
      final premium = AppleTtsVoicePolicy.score(
        _siriPremiumEnUs,
        targetLocale: target,
        systemLocale: system,
      );
      final enhanced = AppleTtsVoicePolicy.score(
        _enhancedEnUs,
        targetLocale: target,
        systemLocale: system,
      );
      final compact = AppleTtsVoicePolicy.score(
        _compactEnUs,
        targetLocale: target,
        systemLocale: system,
      );
      expect(premium, greaterThan(enhanced));
      expect(enhanced, greaterThan(compact));
    });

    test('compact/default voices score at/below zero, premium far above', () {
      const target = 'en-US';
      const system = 'en-US';
      expect(
        AppleTtsVoicePolicy.score(
          _compactEnUs,
          targetLocale: target,
          systemLocale: system,
        ),
        lessThanOrEqualTo(0),
      );
      expect(
        AppleTtsVoicePolicy.score(
          _siriPremiumEnUs,
          targetLocale: target,
          systemLocale: system,
        ),
        greaterThan(3000),
      );
    });

    test('Siri in the name alone beats enhanced', () {
      const target = 'en-US';
      const system = 'en-US';
      expect(
        AppleTtsVoicePolicy.score(
          _siriByName,
          targetLocale: target,
          systemLocale: system,
        ),
        greaterThan(
          AppleTtsVoicePolicy.score(
            _enhancedEnUs,
            targetLocale: target,
            systemLocale: system,
          ),
        ),
      );
    });

    test('eloquence novelty voices are heavily penalized', () {
      const target = 'en-US';
      const system = 'en-US';
      expect(
        AppleTtsVoicePolicy.score(
          _eloquence,
          targetLocale: target,
          systemLocale: system,
        ),
        lessThan(
          AppleTtsVoicePolicy.score(
            _compactEnUs,
            targetLocale: target,
            systemLocale: system,
          ),
        ),
      );
    });

    test('system dialect is preferred over other dialects', () {
      expect(
        AppleTtsVoicePolicy.score(
          _siriPremiumEnUs,
          targetLocale: 'en',
          systemLocale: 'en-US',
        ),
        greaterThan(
          AppleTtsVoicePolicy.score(
            _premiumEnGb,
            targetLocale: 'en',
            systemLocale: 'en-US',
          ),
        ),
      );
    });

    test('system-default flag breaks ties but never promotes compact', () {
      const target = 'en-US';
      const system = 'en-US';

      // Same premium voice, flagged one wins → the user's chosen System
      // Voice is honored among equals.
      expect(
        AppleTtsVoicePolicy.pickBestVoiceId(
          [_zoePremium, _avaPremiumSystemDefault],
          targetLanguage: target,
          systemLanguage: system,
        ),
        _avaPremiumSystemDefault.identifier,
      );

      // Flagged compact still loses to a real Siri voice → the flag can
      // never reintroduce the robot voice.
      expect(
        AppleTtsVoicePolicy.score(
          _samanthaSystemDefault,
          targetLocale: target,
          systemLocale: system,
        ),
        lessThan(
          AppleTtsVoicePolicy.score(
            _siriByName,
            targetLocale: target,
            systemLocale: system,
          ),
        ),
      );
      expect(
        AppleTtsVoicePolicy.pickBestVoiceId(
          [_samanthaSystemDefault, _siriByName],
          targetLanguage: target,
          systemLanguage: system,
        ),
        _siriByName.identifier,
      );
    });

    test('unmarked system-default Siri voice beats marked compact Siri', () {
      // Regression: "Siri Voice 1" (Settings) exposes no siri/premium
      // markers in its native record, yet must beat the compact fallback.
      expect(
        AppleTtsVoicePolicy.pickBestVoiceId(
          [_catherineCompactSiri, _siriVoice1Unmarked],
          targetLanguage: 'en',
          systemLanguage: 'en-US',
        ),
        _siriVoice1Unmarked.identifier,
      );
    });
  });

  group('AppleTtsVoicePolicy.pickBestVoiceId', () {
    test('picks the premium Siri voice for en-US', () {
      expect(
        AppleTtsVoicePolicy.pickBestVoiceId(
          _allEn,
          targetLanguage: 'en-US',
          systemLanguage: 'en-US',
        ),
        _siriPremiumEnUs.identifier,
      );
    });

    test('bare language code matches regional voices', () {
      expect(
        AppleTtsVoicePolicy.pickBestVoiceId(
          _allEn,
          targetLanguage: 'en',
          systemLanguage: 'en-US',
        ),
        _siriPremiumEnUs.identifier,
      );
    });

    test('never returns a voice for an uninstalled language', () {
      expect(
        AppleTtsVoicePolicy.pickBestVoiceId(
          _allEn,
          targetLanguage: 'ja-JP',
          systemLanguage: 'en-US',
        ),
        isNull,
      );
    });

    test('falls back to the only installed voice instead of null', () {
      expect(
        AppleTtsVoicePolicy.pickBestVoiceId(
          [_compactEnUs],
          targetLanguage: 'en-US',
          systemLanguage: 'en-US',
        ),
        _compactEnUs.identifier,
      );
    });

    test('parses native listVoices maps', () {
      final voice = AppleTtsVoice.fromMap({
        'identifier': 'com.apple.voice.premium.en-US.Ava',
        'name': 'Ava',
        'language': 'en-US',
        'quality': 'premium',
        'systemDefault': 'true',
      });
      expect(voice.identifier, _siriPremiumEnUs.identifier);
      expect(voice.quality, 'premium');
      expect(voice.systemDefault, isTrue);
      expect(
        AppleTtsVoice.fromMap(const {'identifier': 'x'}).systemDefault,
        isFalse,
      );
    });
  });

  group('NativeSpeechService voice plumbing', () {
    const channel = MethodChannel('epitaka/native_speech');
    final calls = <String>[];
    Map<String, dynamic>? lastSpeakArgs;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      calls.clear();
      lastSpeakArgs = null;
      NativeSpeechService.clearVoiceCache();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            switch (call.method) {
              case 'listVoices':
                return [
                  {
                    'identifier': _compactEnUs.identifier,
                    'name': _compactEnUs.name,
                    'language': _compactEnUs.language,
                    'quality': _compactEnUs.quality,
                  },
                  {
                    'identifier': _siriPremiumEnUs.identifier,
                    'name': _siriPremiumEnUs.name,
                    'language': _siriPremiumEnUs.language,
                    'quality': _siriPremiumEnUs.quality,
                  },
                ];
              case 'speak':
                lastSpeakArgs = Map<String, dynamic>.from(
                  call.arguments as Map,
                );
                return true;
              default:
                return null;
            }
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      NativeSpeechService.clearVoiceCache();
    });

    test('speak forwards the Siri voiceIdentifier (Apple platforms)', () async {
      if (!NativeSpeechService.isSupported) return;
      final id = await NativeSpeechService.pickVoiceId(
        language: 'en-US',
        systemLanguage: 'en-US',
      );
      expect(id, _siriPremiumEnUs.identifier);

      final ok = await NativeSpeechService.speak(
        'hello',
        language: 'en-US',
        voiceIdentifier: id,
      );
      expect(ok, isTrue);
      expect(lastSpeakArgs?['voiceIdentifier'], _siriPremiumEnUs.identifier);
      expect(lastSpeakArgs?['language'], 'en-US');
    });

    test('voice list is fetched once per session, not per line', () async {
      if (!NativeSpeechService.isSupported) return;
      await NativeSpeechService.pickVoiceId(
        language: 'en-US',
        systemLanguage: 'en-US',
      );
      await NativeSpeechService.pickVoiceId(
        language: 'en-US',
        systemLanguage: 'en-US',
      );
      expect(calls.where((c) => c == 'listVoices').length, 1);
    });

    test('omits voiceIdentifier when no voice matches', () async {
      if (!NativeSpeechService.isSupported) return;
      final id = await NativeSpeechService.pickVoiceId(
        language: 'ja-JP',
        systemLanguage: 'en-US',
      );
      expect(id, isNull);

      final ok = await NativeSpeechService.speak('hello', language: 'ja-JP');
      expect(ok, isTrue);
      expect(lastSpeakArgs?.containsKey('voiceIdentifier'), isFalse);
    });
  });
}
