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

  static bool localeMatches(String voiceLocale, String langCode) {
    final loc = voiceLocale.toLowerCase().replaceAll('_', '-');
    final lc = langCode.toLowerCase();
    return loc == lc || loc.startsWith('$lc-');
  }

  static List<Map<String, String>> usableVoicesFor(
    List<Map<String, String>> voices,
    String langCode,
  ) {
    return voices.where((v) {
      return localeMatches(v['locale'] ?? '', langCode) && isVoiceUsable(v);
    }).toList();
  }

  static List<Map<String, String>> localVoicesFor(
    List<Map<String, String>> voices,
    String langCode,
  ) {
    return voices.where((v) {
      return localeMatches(v['locale'] ?? '', langCode) && isVoiceLocal(v);
    }).toList();
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
