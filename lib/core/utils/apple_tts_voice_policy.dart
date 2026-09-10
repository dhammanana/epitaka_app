// lib/core/utils/apple_tts_voice_policy.dart
//
// Single source of truth for Apple (iOS/macOS) TTS voice selection.
//
// REGRESSION GUARD: Apple TTS must speak with a Siri / premium / enhanced
// voice, never the default compact ("robot") voice. `AVSpeechSynthesisVoice
// (language:)` returns the *default* voice for a locale — on macOS that is
// the compact voice, which caused the robot-voice regression (see
// macos/Runner/MainFlutterWindow.swift `resolveVoice`). The native plugins
// (iOS AppDelegate `findBestVoice`, macOS `resolveVoice`) mirror this
// scoring; the ranking itself lives here so `flutter test` can lock it and
// no future AI edit can silently reintroduce the robot voice.
//
// Covered by test/apple_tts_voice_policy_test.dart — do not weaken the
// premium/Siri-first ordering without updating that test.

/// A single Apple TTS voice as reported by the native `listVoices` channel.
class AppleTtsVoice {
  const AppleTtsVoice({
    required this.identifier,
    required this.name,
    required this.language,
    required this.quality,
    this.systemDefault = false,
  });

  final String identifier;
  final String name;
  final String language;
  final String quality;

  /// True when this is the user's chosen System Voice (macOS System
  /// Settings → Accessibility → Spoken Content) — the "Siri voice" the
  /// old NSSpeechSynthesizer path used implicitly.
  final bool systemDefault;

  factory AppleTtsVoice.fromMap(Map<String, String> map) => AppleTtsVoice(
    identifier: map['identifier'] ?? '',
    name: map['name'] ?? '',
    language: map['language'] ?? '',
    quality: map['quality'] ?? '',
    systemDefault: (map['systemDefault'] ?? '').toLowerCase() == 'true',
  );
}

/// Ranks Apple TTS voices so Siri / premium / enhanced voices always win
/// over default compact ones. Pure + static, no platform dependencies.
class AppleTtsVoicePolicy {
  AppleTtsVoicePolicy._();

  /// Score a voice. Higher wins. Mirrors the native scoring exactly:
  /// premium +3000, Siri +2000, enhanced +1000, system-dialect +200,
  /// exact-locale +150, eloquence −1000, super-compact −500,
  /// compact/default −200.
  ///
  /// The user's chosen System Voice (macOS flag) is trusted with
  /// premium-class weight (+3000) plus the +500 choice bonus when it
  /// carries no known-bad markers —
  /// Apple names its neural Siri voices "Voice 1..5" with no
  /// siri/premium/enhanced markers, so heuristics alone can't see them.
  /// A flagged voice WITH bad markers (e.g. explicitly chosen compact
  /// Samantha) only gets the +500 tie-break and can never outrank a real
  /// Siri/premium voice.
  static int score(
    AppleTtsVoice voice, {
    required String targetLocale,
    required String systemLocale,
  }) {
    var score = 0;
    final id = voice.identifier.toLowerCase();
    final name = voice.name.toLowerCase();
    final quality = voice.quality.toLowerCase();
    final markers = '$id $name';
    final hasNegativeMarkers =
        markers.contains('eloquence') ||
        markers.contains('synthesis.voice') ||
        markers.contains('super-compact') ||
        markers.contains('compact');

    if (voice.systemDefault && !hasNegativeMarkers) {
      score += 3000;
    } else {
      if (quality == 'premium' || id.contains('premium')) score += 3000;
      if (id.contains('siri') || name.contains('siri')) score += 2000;
      if (quality == 'enhanced' || id.contains('enhanced')) score += 1000;
    }
    if (voice.systemDefault) score += 500;

    final voiceLang = _normalizeLocale(voice.language);
    final target = _normalizeLocale(targetLocale);
    final system = _normalizeLocale(systemLocale);
    if (voiceLang == system) {
      score += 200;
    } else if (voiceLang == target) {
      score += 150;
    }

    if (id.contains('eloquence') || id.contains('synthesis.voice')) {
      score -= 1000;
    }
    if (id.contains('super-compact')) {
      score -= 500;
    } else if (id.contains('compact') ||
        quality == 'default' ||
        quality == 'compact') {
      score -= 200;
    }
    return score;
  }

  /// Pick the identifier of the best voice for [targetLanguage]
  /// (BCP-47 like 'en-US' or bare like 'en'), or null when no installed
  /// voice matches. Never picks a non-matching language: callers fall back
  /// to the native default in that case.
  static String? pickBestVoiceId(
    List<AppleTtsVoice> voices, {
    String? targetLanguage,
    String? systemLanguage,
  }) {
    final target = _normalizeLocale(targetLanguage ?? '');
    final system = _normalizeLocale(systemLanguage ?? '');
    final targetPrefix = target.split('-').first;
    final systemPrefix = system.split('-').first;

    final matching = voices.where((v) {
      final lang = _normalizeLocale(v.language);
      return lang == target ||
          lang.startsWith('$targetPrefix-') ||
          lang == targetPrefix;
    }).toList();
    if (matching.isEmpty) return null;

    matching.sort(
      (a, b) => score(
        b,
        targetLocale: target,
        systemLocale: system,
      ).compareTo(score(a, targetLocale: target, systemLocale: system)),
    );
    final best = matching.first;

    // When the target language has no exact-locale voice but shares the
    // system language family, the system-locale voice reads most naturally.
    if (targetPrefix == systemPrefix) {
      final systemVoice = matching.firstWhere(
        (v) => _normalizeLocale(v.language) == system,
        orElse: () => best,
      );
      return systemVoice.identifier.isEmpty ? null : systemVoice.identifier;
    }
    return best.identifier.isEmpty ? null : best.identifier;
  }

  static String _normalizeLocale(String locale) =>
      locale.trim().replaceAll('_', '-').toLowerCase();
}
