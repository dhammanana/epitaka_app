import 'package:flutter_tts/flutter_tts.dart';

enum TtsVoiceStatus { ready, needsDownload, notSupported, networkOnly, unknown }

class TtsLanguageCheck {
  const TtsLanguageCheck({
    required this.status,
    required this.hasLocalVoice,
    this.engine,
  });

  final TtsVoiceStatus status;
  final bool hasLocalVoice;
  final String? engine;
}

class SystemTtsAvailability {
  static const googleEngine = 'com.google.android.tts';

  static bool isVoiceUsable(Map<String, String> voice) {
    final features = (voice['features'] ?? '');
    if (features.contains('notInstalled')) return false;
    return true;
  }

  static bool isVoiceLocal(Map<String, String> voice) {
    if (!isVoiceUsable(voice)) return false;
    return (voice['network_required'] ?? '0') != '1';
  }

  /// Short label appended to a voice display name: "network" for voices
  /// that need internet, "local" for on-device voices.
  static String voiceKindLabel(Map<String, String> voice) =>
      isVoiceLocal(voice) ? 'local' : 'network';

  /// Human-readable display name for a system voice. Engines report
  /// opaque IDs like `en-us-x-iob-network`; this turns them into
  /// "Iob (network)" — the trailing `-network`/`-local` kind suffix is
  /// stripped (it becomes the badge), segments are split on `-`/`_`,
  /// multi-letter segments are title-cased, single letters upper-cased,
  /// and embedded language codes like `en-us` are folded into the name.
  /// The raw ID stays available in the picker subtitle.
  static String voiceDisplayName(Map<String, String> voice) {
    final raw = voice['name'] ?? '';
    if (raw.isEmpty) return raw;

    // Fold a leading locale prefix (en-us-…) into nothing; the language
    // is already implied by the picker's grouping.
    var name = raw;
    final localePrefix = RegExp(
      r'^([a-z]{2,3})[-_]([a-z]{2}|[0-9]{3})[-_]?',
      caseSensitive: false,
    );
    final localeMatch = localePrefix.firstMatch(name);
    if (localeMatch != null) name = name.substring(localeMatch.end);

    // The kind suffix moves to the badge, so drop it from the name.
    final kind = voiceKindLabel(voice);
    name = name
        .replaceAll(RegExp(r'-(network|local)$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[-_]+$'), '');

    if (name.isEmpty) name = raw;

    final parts = name
        .split(RegExp(r'[-_]'))
        .where((p) => p.isNotEmpty)
        .map((p) {
          if (p.length == 1) return p.toUpperCase();
          return p[0].toUpperCase() + p.substring(1).toLowerCase();
        })
        .join(' ');

    final label = parts.isEmpty ? raw : parts;
    return '$label ($kind)';
  }

  static bool localeMatches(String voiceLocale, String langCode) {
    final loc = voiceLocale.toLowerCase().replaceAll('_', '-');
    final lc = langCode.toLowerCase();
    return loc == lc || loc.startsWith('$lc-');
  }

  static List<Map<String, String>> usableVoicesFor(
    List<Map<String, String>> voices,
    String langCode,
  ) {
    final list = voices.where((v) {
      return localeMatches(v['locale'] ?? '', langCode) && isVoiceUsable(v);
    }).toList();
    sortVoices(list);
    return list;
  }

  static List<Map<String, String>> localVoicesFor(
    List<Map<String, String>> voices,
    String langCode,
  ) {
    final list = voices.where((v) {
      return localeMatches(v['locale'] ?? '', langCode) && isVoiceLocal(v);
    }).toList();
    sortVoices(list);
    return list;
  }

  /// Sort voices in place, best first: usable before missing, higher
  /// quality first, then local (on-device, works offline) before
  /// network-required, then alphabetical for stability.
  static void sortVoices(List<Map<String, String>> voices) {
    final indexed = voices.indexed.toList();
    indexed.sort((x, y) {
      final a = x.$2;
      final b = y.$2;
      final usableA = isVoiceUsable(a) ? 0 : 1;
      final usableB = isVoiceUsable(b) ? 0 : 1;
      if (usableA != usableB) return usableA - usableB;
      final q = _qualityScore(b) - _qualityScore(a);
      if (q != 0) return q;
      final localA = isVoiceLocal(a) ? 0 : 1;
      final localB = isVoiceLocal(b) ? 0 : 1;
      if (localA != localB) return localA - localB;
      return x.$1 - y.$1;
    });
    for (var i = 0; i < voices.length; i++) {
      voices[i] = indexed[i].$2;
    }
  }

  static int _qualityScore(Map<String, String> voice) {
    final q = (voice['quality'] ?? '').toLowerCase();
    if (q.isNotEmpty) {
      final numeric = int.tryParse(q);
      if (numeric != null) return numeric;
      if (q.contains('very_high') || q.contains('premium')) return 300;
      if (q.contains('high') || q.contains('enhanced')) return 200;
      if (q.contains('normal') || q.contains('default')) return 100;
      if (q.contains('low') || q.contains('compact')) return 50;
    }
    final name = (voice['name'] ?? '').toLowerCase();
    if (name.contains('premium') || name.contains('siri')) return 300;
    if (name.contains('enhanced') || name.contains('high')) return 200;
    if (name.contains('compact') || name.contains('low')) return 50;
    return 100;
  }

  static Future<List<String>> getEngines(FlutterTts tts) async {
    try {
      final result = await tts.getEngines;
      if (result is List) return result.map((e) => e.toString()).toList();
    } catch (_) {}
    return [];
  }

  static Future<String?> getDefaultEngine(FlutterTts tts) async {
    try {
      final result = await tts.getDefaultEngine;
      if (result is String && result.isNotEmpty) return result;
    } catch (_) {}
    return null;
  }

  static Future<TtsLanguageCheck> checkLanguage(
    FlutterTts tts,
    List<Map<String, String>> voices,
    String langCode, {
    String? engine,
  }) async {
    final local = localVoicesFor(voices, langCode);
    if (local.isNotEmpty) {
      return TtsLanguageCheck(
        status: TtsVoiceStatus.ready,
        hasLocalVoice: true,
        engine: engine,
      );
    }
    final usable = usableVoicesFor(voices, langCode);
    if (usable.isNotEmpty) {
      return TtsLanguageCheck(
        status: TtsVoiceStatus.networkOnly,
        hasLocalVoice: false,
        engine: engine,
      );
    }
    final listed = voices.any(
      (v) => localeMatches(v['locale'] ?? '', langCode),
    );
    bool available = false;
    bool installed = false;
    try {
      final a = await tts.isLanguageAvailable(_localeFor(langCode));
      available = a == true || a == 1;
    } catch (_) {}
    if (available) {
      try {
        final i = await tts.isLanguageInstalled(_localeFor(langCode));
        installed = i == true || i == 1;
      } catch (_) {}
    }
    if (listed || (available && !installed)) {
      return TtsLanguageCheck(
        status: TtsVoiceStatus.needsDownload,
        hasLocalVoice: false,
        engine: engine,
      );
    }
    if (!available) {
      return TtsLanguageCheck(
        status: TtsVoiceStatus.notSupported,
        hasLocalVoice: false,
        engine: engine,
      );
    }
    return TtsLanguageCheck(
      status: TtsVoiceStatus.unknown,
      hasLocalVoice: false,
      engine: engine,
    );
  }

  /// Brand name for known TTS engine packages; null → show the last
  /// segment of the package id instead.
  static const _engineBrandNames = <String, String>{
    'com.google.android.tts': 'Google Speech Services',
    'com.google.android.speechtts': 'Google Speech Services',
    'com.samsung.SMT': 'Samsung TTS',
    'com.huawei.tts': 'Huawei TTS',
    'com.iflytek.speechsuite': 'iFlytek TTS',
    'com.baidu.tts': 'Baidu TTS',
    'amazon.tablet.tts': 'Amazon TTS',
  };

  /// Human-readable name for a TTS engine package id. Known packages get
  /// their brand name ("Google Speech Services"); unknown ones fall back
  /// to a cleaned-up last segment of the package ("voxsherpa",
  /// "supertonic").
  static String engineDisplayName(String engineId) {
    final brand = _engineBrandNames[engineId];
    if (brand != null) return brand;
    final last = engineId.split('.').where((s) => s.isNotEmpty).lastOrNull;
    if (last == null || last.isEmpty) return engineId;
    return last;
  }

  /// Short labels for a list of engine ids, de-duplicated: if two engines
  /// share a last segment (e.g. two "…tts" packages), the disambiguating
  /// part of the package is kept ("com.x.tts" → "x tts" vs "com.y.tts" →
  /// "y tts"); single engines keep the short form.
  static List<String> engineDisplayNames(List<String> engineIds) {
    final names = engineIds.map(engineDisplayName).toList();
    final seen = <String, int>{};
    for (final n in names) {
      seen[n] = (seen[n] ?? 0) + 1;
    }
    return engineIds.asMap().entries.map((e) {
      final id = e.value;
      final name = names[e.key];
      if ((seen[name] ?? 0) > 1) {
        // Colliding short name — disambiguate with the package's second
        // level (com.x.tts → "x tts").
        final parts = id.split('.').where((s) => s.isNotEmpty).toList();
        if (parts.length >= 2) return '${parts[parts.length - 2]} ${parts.last}';
      }
      return name;
    }).toList();
  }

  static String _localeFor(String langCode) {
    const map = <String, String>{
      'en': 'en-US',
      'si': 'si-LK',
      'hi': 'hi-IN',
      'my': 'my-MM',
      'th': 'th-TH',
      'te': 'te-IN',
      'kn': 'kn-IN',
    };
    return map[langCode] ?? 'en-US';
  }
}
