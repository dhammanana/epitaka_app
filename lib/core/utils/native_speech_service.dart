// lib/core/utils/native_speech_service.dart
//
// Wraps the native method channel (`epitaka/native_speech`) that triggers
// system text-to-speech on iOS and macOS (AVSpeechSynthesizer).

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeSpeechService {
  NativeSpeechService._();

  static const MethodChannel _channel = MethodChannel('epitaka/native_speech');

  /// Native speech synthesis is supported on iOS and macOS.
  static bool get isSupported =>
      !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  /// Speaks [text] using the device's native system speech synthesizer.
  ///
  /// On iOS and macOS, delegates to [AVSpeechSynthesizer].
  /// An optional [language] tag (e.g. 'en-US', 'th-TH', 'si-LK') can be passed
  /// to select the voice locale.
  ///
  /// Returns `true` if speech was initiated, or `false` if unsupported / failed.
  static Future<bool> speak(String text, {String? language}) async {
    final clean = text.trim();
    if (clean.isEmpty || !isSupported) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('speak', {
        'text': clean,
        if (language != null && language.isNotEmpty) 'language': language,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Stops any currently active native speech.
  static Future<bool> stop() async {
    if (!isSupported) return false;
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
}
