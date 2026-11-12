// lib/features/settings/services/genai_tts_service.dart
//
// Wraps the native method channel (`epitaka/genai_tts`) that drives Google's
// on-device GenAI Text-to-Speech SDK (com.google.mlkit:genai-text-to-speech).
//
// Availability is deliberately conservative: the SDK only works on a short
// list of high-end Pixel/Galaxy devices, needs the latest "Speech
// Recognition & Synthesis" app installed and currently speaks 21 locales.
// Every method therefore reports failure rather than throwing, so callers can
// fall back to the system TTS engine silently.

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Why the GenAI voice can (not) be used for a language.
enum GenAiVoiceStatus {
  /// Downloaded and ready to speak.
  available,

  /// This phone supports the voice; the model still has to be downloaded.
  downloadable,

  /// That download is running.
  downloading,

  /// The SDK speaks 21 locales only (no Sinhala, Myanmar, Thai, …).
  languageUnsupported,

  /// The phone model is not one of the supported Pixel/Galaxy devices.
  deviceUnsupported,

  /// The check itself failed (SDK error, missing Speech Services app).
  unknown;

  static GenAiVoiceStatus _parse(String? raw) {
    switch (raw) {
      case 'available':
        return available;
      case 'downloadable':
        return downloadable;
      case 'downloading':
        return downloading;
      case 'languageUnsupported':
        return languageUnsupported;
      case 'deviceUnsupported':
        return deviceUnsupported;
      default:
        return unknown;
    }
  }
}

/// Result of [GenAiTtsService.speak].
enum GenAiSpeakResult {
  /// Synthesis started; the native side will report completion.
  started,

  /// The voice model is still downloading. Nothing was played; the caller
  /// should fall back to the system engine for now.
  downloading,

  /// This device/locale has no usable GenAI voice.
  unavailable,

  /// Synthesis was attempted but could not start.
  failed,
}

class GenAiTtsService {
  GenAiTtsService._();

  static const MethodChannel _channel = MethodChannel('epitaka/genai_tts');
  static bool _initialized = false;

  static VoidCallback? _onStarted;
  static VoidCallback? _onCompletion;

  /// Per-language availability cache. The native check binds to the Google
  /// TTS service (hundreds of ms the first time), and the reading loop asks
  /// once per unit, so the answer is cached for the session.
  static final Map<String, bool> _availability = {};

  /// ML Kit GenAI TTS is Android-only.
  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  static void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onStart':
          _onStarted?.call();
          break;
        case 'onDone':
          _handleCompletion();
          break;
        case 'onError':
          developer.log(
            '[TTS] GenAI synthesis error: ${call.arguments}',
            name: 'epitaka.tts',
          );
          _handleCompletion();
          break;
      }
    });
  }

  /// Whether a ready-to-use GenAI voice exists for [language] (a BCP-47 tag
  /// such as `en-US`). False on non-Android platforms, unsupported devices,
  /// unsupported languages and while the voice model is still downloading.
  static Future<bool> isAvailable(String language) async {
    if (!isSupported || language.isEmpty) return false;
    final cached = _availability[language];
    if (cached != null) return cached;
    return await statusFor(language) == GenAiVoiceStatus.available;
  }

  /// The precise reason a voice can or cannot be used, for the settings tile.
  static Future<GenAiVoiceStatus> statusFor(String language) async {
    if (!isSupported || language.isEmpty) {
      return GenAiVoiceStatus.deviceUnsupported;
    }
    if (_availability.containsKey(language)) return GenAiVoiceStatus.available;
    _ensureInitialized();
    try {
      final raw = await _channel.invokeMethod<String>('isAvailable', {
        'language': language,
      });
      final status = GenAiVoiceStatus._parse(raw);
      // Only cache a positive answer: a negative one may be transient (the
      // user installing/updating the Speech Services app mid-session).
      if (status == GenAiVoiceStatus.available) {
        _availability[language] = true;
      } else {
        _availability.remove(language);
      }
      return status;
    } catch (e) {
      developer.log('[TTS] GenAI isAvailable failed: $e', name: 'epitaka.tts');
      return GenAiVoiceStatus.unknown;
    }
  }

  /// Asks the native side to download the voice for [language]. Returns the
  /// status after the request (normally [GenAiVoiceStatus.downloading]).
  static Future<GenAiVoiceStatus> download(String language) async {
    if (!isSupported || language.isEmpty) {
      return GenAiVoiceStatus.deviceUnsupported;
    }
    _ensureInitialized();
    try {
      final raw = await _channel.invokeMethod<String>('download', {
        'language': language,
      });
      final status = GenAiVoiceStatus._parse(raw);
      if (status == GenAiVoiceStatus.available) _availability[language] = true;
      return status;
    } catch (e) {
      developer.log('[TTS] GenAI download failed: $e', name: 'epitaka.tts');
      return GenAiVoiceStatus.unknown;
    }
  }

  /// Speak [text] with the GenAI voice for [language].
  ///
  /// [onCompletion] fires when playback finishes (or fails); it is never
  /// called when the method returns anything other than
  /// [GenAiSpeakResult.started].
  static Future<GenAiSpeakResult> speak(
    String text, {
    required String language,
    VoidCallback? onStarted,
    VoidCallback? onCompletion,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty || !isSupported) return GenAiSpeakResult.unavailable;
    _ensureInitialized();
    _onStarted = onStarted;
    _onCompletion = onCompletion;
    try {
      final status = await _channel.invokeMethod<String>('speak', {
        'text': clean,
        'language': language,
      });
      switch (status) {
        case 'started':
          return GenAiSpeakResult.started;
        case 'downloading':
          _onStarted = null;
          _onCompletion = null;
          return GenAiSpeakResult.downloading;
        default:
          _onStarted = null;
          _onCompletion = null;
          return GenAiSpeakResult.unavailable;
      }
    } catch (e) {
      developer.log('[TTS] GenAI speak failed: $e', name: 'epitaka.tts');
      _onStarted = null;
      _onCompletion = null;
      return GenAiSpeakResult.failed;
    }
  }

  /// Stops any active GenAI speech.
  static Future<void> stop() async {
    if (!isSupported) return;
    _onStarted = null;
    _onCompletion = null;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {}
  }

  /// Forgets cached availability so a newly downloaded voice is picked up
  /// next session.
  static void clearCache() => _availability.clear();

  static void _handleCompletion() {
    final callback = _onCompletion;
    _onStarted = null;
    _onCompletion = null;
    callback?.call();
  }
}
