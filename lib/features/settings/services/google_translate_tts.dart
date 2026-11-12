// lib/features/settings/services/google_translate_tts.dart
//
// Online TTS through Google Translate's speak endpoint. Useful for languages
// that have no installable device voice (Sinhala, Myanmar, …): Translate
// speaks them, the audio is fetched as MP3 and played with `audioplayers`.
//
// This is an unofficial endpoint, so every failure is reported (never thrown)
// and the caller falls back to the system engine.
//
// Limitations (by design): no word progress and no pitch control.

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GoogleTranslateTts {
  /// Chunks are capped well below Translate's ~200 character limit so a
  /// request never trips the endpoint's length check.
  static const int _maxChars = 180;

  static const Duration _requestTimeout = Duration(seconds: 12);

  final AudioPlayer _player = AudioPlayer();
  bool _cancelled = false;

  /// Audio playback is available on Android/iOS/macOS/Windows via
  /// audioplayers. Linux has no TTS support in the app at all; the web build
  /// does not ship the native player.
  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isWindows);

  /// Fetches and plays [text] in [language] (Google Translate's `tl` code).
  ///
  /// Returns true when playback was started and finished normally. When it
  /// returns false nothing is speaking and the caller should fall back.
  /// [onCompletion] is only called for a started playback.
  Future<bool> speak(
    String text, {
    required String language,
    required double speed,
    VoidCallback? onStarted,
    VoidCallback? onCompletion,
  }) async {
    if (!isSupported) return false;
    final chunks = _chunk(text);
    if (chunks.isEmpty) return false;
    _cancelled = false;
    var completed = false;
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.stop);
      var started = false;
      for (var i = 0; i < chunks.length; i++) {
        if (_cancelled) return false;
        final bytes = await _fetch(chunks[i], language, index: i, total: chunks.length);
        if (bytes == null) return false;
        if (_cancelled) return false;
        final done = Completer<void>();
        final sub = _player.onPlayerComplete.listen((_) {
          if (!done.isCompleted) done.complete();
        });
        try {
          await _player.setPlaybackRate(speed.clamp(0.5, 2.0));
          await _player.play(BytesSource(bytes));
          if (!started) {
            started = true;
            onStarted?.call();
          }
          await done.future.timeout(
            Duration(
              milliseconds: 8000 + (chunks[i].length * 220).clamp(4000, 120000),
            ),
            onTimeout: () {},
          );
        } finally {
          await sub.cancel();
        }
      }
      completed = true;
      return !_cancelled;
    } catch (e) {
      developer.log('[TTS] Google Translate TTS failed: $e', name: 'epitaka.tts');
      return false;
    } finally {
      if (completed && !_cancelled) onCompletion?.call();
    }
  }

  /// Stops playback and aborts any in-flight chunk requests.
  Future<void> stop() async {
    _cancelled = true;
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<Uint8List?> _fetch(
    String chunk,
    String language, {
    required int index,
    required int total,
  }) async {
    final query = {
      'ie': 'UTF-8',
      'client': 'tw-ob',
      'tl': language,
      'q': chunk,
      'idx': '$index',
      'total': '$total',
      'textlen': '${chunk.length}',
    };
    final uri = Uri.https('translate.google.com', '/translate_tts', query);
    try {
      final response = await http
          .get(
            uri,
            headers: const {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/120.0 Safari/537.36',
              'Referer': 'https://translate.google.com/',
            },
          )
          .timeout(_requestTimeout);
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        developer.log(
          '[TTS] Google Translate TTS HTTP ${response.statusCode}',
          name: 'epitaka.tts',
        );
        return null;
      }
      return response.bodyBytes;
    } catch (e) {
      developer.log('[TTS] Google Translate TTS request failed: $e', name: 'epitaka.tts');
      return null;
    }
  }

  /// Split [text] into ≤[_maxChars] pieces, preferably on sentence then word
  /// boundaries so the voice pauses naturally between pieces.
  static List<String> _chunk(String text) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return const [];
    final chunks = <String>[];
    var rest = clean;
    while (rest.length > _maxChars) {
      final window = rest.substring(0, _maxChars);
      var cut = window.lastIndexOf(RegExp(r'[.!?;:।॥]'));
      if (cut < _maxChars ~/ 2) cut = window.lastIndexOf(' ');
      if (cut <= 0) cut = _maxChars - 1;
      chunks.add(rest.substring(0, cut + 1).trim());
      rest = rest.substring(cut + 1).trim();
    }
    if (rest.isNotEmpty) chunks.add(rest);
    return chunks.where((c) => c.isNotEmpty).toList();
  }

  /// Release the native player (call when the notifier is disposed).
  Future<void> dispose() async {
    await stop();
    try {
      await _player.dispose();
    } catch (_) {}
  }
}
