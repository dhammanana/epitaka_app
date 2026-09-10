// lib/core/utils/native_speech_service.dart
//
// Wraps the native method channel (`epitaka/native_speech`) that triggers
// system text-to-speech on iOS and macOS (AVSpeechSynthesizer).

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'apple_tts_voice_policy.dart';

export 'apple_tts_voice_policy.dart' show AppleTtsVoice, AppleTtsVoicePolicy;

class NativeSpeechService {
  NativeSpeechService._();

  static const MethodChannel _channel = MethodChannel('epitaka/native_speech');
  static bool _channelInitialized = false;

  static VoidCallback? _onCompletion;

  /// Cached native voice list (see [listVoices]). Cleared by
  /// [clearVoiceCache] so a newly-installed Siri voice is picked up.
  static List<AppleTtsVoice>? _voicesCache;

  /// Voice id picked per normalized target language (see [pickVoiceId]).
  static final Map<String, String?> _voiceIdCache = {};

  /// Native speech synthesis is supported on iOS and macOS.
  static bool get isSupported =>
      !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  /// Initialize the method channel listener for callbacks.
  static void _ensureChannelInitialized() {
    if (_channelInitialized) return;
    _channelInitialized = true;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onCompletion':
          _handleCompletion();
          break;
      }
    });
  }

  /// Speaks [text] using the device's native system speech synthesizer.
  ///
  /// iOS delegates to AVSpeechSynthesizer; macOS to NSSpeechSynthesizer
  /// (the only engine that sees the neural "Siri Voice 1..5" family —
  /// AVSpeech lists merely compact fallbacks there).
  /// An optional [language] tag (e.g. 'en-US', 'th-TH', 'si-LK') can be passed
  /// to select the voice locale.
  /// [voiceIdentifier] optionally pins an exact native voice (see
  /// [pickVoiceId]); without it the native side uses its own default
  /// (macOS: system default voice; iOS: Siri-first scoring).
  ///
  /// Returns `true` if speech was initiated, or `false` if unsupported / failed.
  static Future<bool> speak(
    String text, {
    String? language,
    String? voiceIdentifier,
    VoidCallback? onCompletion,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty || !isSupported) return false;

    _ensureChannelInitialized();
    _onCompletion = onCompletion;

    try {
      final ok = await _channel.invokeMethod<bool>('speak', {
        'text': clean,
        if (language != null && language.isNotEmpty) 'language': language,
        if (voiceIdentifier != null && voiceIdentifier.isNotEmpty)
          'voiceIdentifier': voiceIdentifier,
        // When a completion callback is expected, the native side must use
        // a path that can report it (AVSpeechSynthesizer), not the
        // fire-and-forget system accessibility "Speak Selection" engine.
        'needsCompletion': onCompletion != null,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Lists the installed native voices (`identifier`, `name`,
  /// `language`, `quality`). Result is cached; see [clearVoiceCache].
  static Future<List<AppleTtsVoice>> listVoices({bool cached = true}) async {
    if (!isSupported) return [];
    if (cached && _voicesCache != null) return _voicesCache!;
    try {
      final result = await _channel.invokeMethod<List>('listVoices');
      final voices = (result ?? [])
          .whereType<Map>()
          .map(
            (v) => AppleTtsVoice.fromMap(
              Map<String, String>.from(
                v.map((k, val) => MapEntry(k.toString(), val.toString())),
              ),
            ),
          )
          .where((v) => v.identifier.isNotEmpty)
          .toList();
      _voicesCache = voices;
      return voices;
    } catch (_) {
      return [];
    }
  }

  /// Returns the identifier of the best installed Siri/premium voice for
  /// [language] (see [AppleTtsVoicePolicy]), cached per language. Null
  /// means no matching voice — callers then omit `voiceIdentifier` and the
  /// native side applies its own Siri-first fallback.
  static Future<String?> pickVoiceId({
    String? language,
    String? systemLanguage,
  }) async {
    if (!isSupported) return null;
    final key = (language ?? '').trim().toLowerCase();
    if (_voiceIdCache.containsKey(key)) return _voiceIdCache[key];
    // Never let voice discovery wedge TTS: on timeout/stale native
    // binaries the caller falls back to speaking without an identifier.
    List<AppleTtsVoice> voices;
    try {
      voices = await listVoices().timeout(
        const Duration(seconds: 3),
        onTimeout: () => <AppleTtsVoice>[],
      );
    } catch (_) {
      voices = <AppleTtsVoice>[];
    }
    if (voices.isEmpty) {
      developer.log(
        '[TTS] NativeSpeechService: 0 native voices for "$key" — '
        'speaking without a pinned voice (rebuild the app if this persists)',
        name: 'epitaka.tts',
      );
      _voiceIdCache[key] = null;
      return null;
    }
    final id = AppleTtsVoicePolicy.pickBestVoiceId(
      voices,
      targetLanguage: language,
      systemLanguage: systemLanguage ?? Platform.localeName,
    );
    developer.log(
      '[TTS] NativeSpeechService: picked "$id" for "$key" '
      '(${voices.length} voices). Top: ${_topCandidates(voices, language: language, systemLanguage: systemLanguage)}',
      name: 'epitaka.tts',
    );
    _voiceIdCache[key] = id;
    return id;
  }

  /// One-line score breakdown of the best 3 candidates for [language],
  /// so a wrong pick can be diagnosed from a single log line.
  static String _topCandidates(
    List<AppleTtsVoice> voices, {
    String? language,
    String? systemLanguage,
  }) {
    final target = (language ?? '').trim().toLowerCase();
    final system = (systemLanguage ?? '').trim().toLowerCase();
    final prefix = target.split('-').first;
    final ranked = voices.where((v) {
      final lang = v.language.trim().toLowerCase();
      return lang == target || lang.startsWith('$prefix-') || lang == prefix;
    }).toList();
    ranked.sort(
      (a, b) =>
          AppleTtsVoicePolicy.score(
            b,
            targetLocale: target,
            systemLocale: system,
          ).compareTo(
            AppleTtsVoicePolicy.score(
              a,
              targetLocale: target,
              systemLocale: system,
            ),
          ),
    );
    return ranked
        .take(3)
        .map(
          (v) =>
              '${v.identifier}(${AppleTtsVoicePolicy.score(v, targetLocale: target, systemLocale: system)}'
              '${v.systemDefault ? ',sys' : ''},q=${v.language}/${v.quality})',
        )
        .join(' | ');
  }

  /// Forgets cached voices / picks so a newly-installed Siri voice is used
  /// next session. Call when TTS stops.
  static void clearVoiceCache() {
    _voicesCache = null;
    _voiceIdCache.clear();
  }

  /// Stops any currently active native speech.
  static Future<bool> stop() async {
    if (!isSupported) return false;
    _onCompletion = null;
    try {
      final ok = await _channel.invokeMethod<bool>('stop');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Returns whether the native speech synthesizer is currently speaking.
  static Future<bool> isSpeaking() async {
    if (!isSupported) return false;
    try {
      final speaking = await _channel.invokeMethod<bool>('isSpeaking');
      return speaking ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Called from native side when speech finishes (if supported).
  static void _handleCompletion() {
    final callback = _onCompletion;
    _onCompletion = null;
    callback?.call();
  }
}
