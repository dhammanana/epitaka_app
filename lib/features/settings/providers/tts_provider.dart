import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:supertonic_flutter/supertonic_flutter.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../../core/providers/settings_provider.dart';

/// TTS playback state.
enum TtsPlaybackState { stopped, playing, paused, loading }

/// TTS engine type.
enum TtsEngineType { system, supertonic }

/// TTS notifier managing playback state across both engines.
///
/// - System TTS: Uses `flutter_tts` for platform-native TTS.
/// - Supertonic: Uses `supertonic_flutter` for local neural TTS.
class TtsNotifier extends StateNotifier<TtsPlaybackState> {
  final Ref _ref;

  // System TTS engine
  FlutterTts? _flutterTts;

  // Supertonic TTS engine
  SupertonicTTS? _supertonicTts;
  TTSAudioPlayer? _player;
  StreamSubscription<PlayerState>? _playerSubscription;
  bool _supertonicInitialized = false;
  bool _disposed = false;

  // Speech completion tracking
  Completer<void>? _speechCompleter;
  String? _currentText;

  /// Cached flutter_tts platform channel values to avoid redundant
  /// MethodChannel calls on every line. Only updated when the user
  /// changes speed/pitch/language via settings.
  double _cachedRate = -1.0;  // sentinel — never a valid rate
  double _cachedPitch = -1.0;
  String _cachedLanguage = '';

  TtsNotifier(this._ref) : super(TtsPlaybackState.stopped);

  /// Get the currently configured engine type from settings.
  TtsEngineType get _engineType {
    final settings = _ref.read(settingsProvider);
    return settings.ttsEngine == 'supertonic'
        ? TtsEngineType.supertonic
        : TtsEngineType.system;
  }

  /// Complete the current speech completer if it is active.
  void _completeSpeech() {
    if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
      _speechCompleter!.complete();
    }
    _speechCompleter = null;
  }

  /// Wait for the current speech to finish playing, with a timeout fallback.
  Future<void> _waitForCompletion() async {
    _completeSpeech();
    _speechCompleter = Completer<void>();
    try {
      await _speechCompleter!.future.timeout(
        const Duration(seconds: 30),
      );
    } on TimeoutException {
      _completeSpeech();
    }
  }

  /// Lazily initialize the system TTS engine.
  Future<FlutterTts> _getFlutterTts() async {
    if (_flutterTts != null) return _flutterTts!;

    final tts = FlutterTts();
    _flutterTts = tts;

    // Set up completion and error handlers
    tts.setCompletionHandler(() {
      final now = DateTime.now().millisecondsSinceEpoch;
      developer.log('[TTS] Completion handler fired at $now', name: 'epitaka.tts');
      if (!_disposed) {
        state = TtsPlaybackState.stopped;
        _completeSpeech();
      }
    });

    tts.setErrorHandler((msg) {
      developer.log('[TTS] Error handler fired: $msg', name: 'epitaka.tts');
      if (!_disposed) {
        state = TtsPlaybackState.stopped;
        _completeSpeech();
      }
    });

    return tts;
  }

  /// Lazily initialize the Supertonic engine.
  Future<void> _ensureSupertonicInitialized() async {
    if (_supertonicInitialized) return;

    state = TtsPlaybackState.loading;
    try {
      _supertonicTts = SupertonicTTS();
      await _supertonicTts!.initialize();
      _player = TTSAudioPlayer();

      // Subscribe to Supertonic player state changes to detect completion
      _playerSubscription = _player!.playerStateStream.listen((playerState) {
        if (!_disposed && playerState == PlayerState.completed) {
          state = TtsPlaybackState.stopped;
          _completeSpeech();
        }
      });

      _supertonicInitialized = true;
      state = TtsPlaybackState.stopped;
    } catch (e) {
      state = TtsPlaybackState.stopped;
      rethrow;
    }
  }

  /// Speak the given [text] using the configured TTS engine and await completion.
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    _currentText = text;
    developer.log('[TTS] speak() called: text.length=${text.length} text="${text.length > 40 ? '${text.substring(0, 40)}...' : text}"', name: 'epitaka.tts');

    // Stop any current playback
    await stop();

    final start = DateTime.now();
    try {
      switch (_engineType) {
        case TtsEngineType.system:
          await _speakSystem(text);
        case TtsEngineType.supertonic:
          await _speakSupertonic(text);
      }
      await _waitForCompletion();
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      developer.log('[TTS] speak() completed in ${elapsed}ms', name: 'epitaka.tts');
    } catch (e) {
      state = TtsPlaybackState.stopped;
      _completeSpeech();
      rethrow;
    }
  }

  /// Speak using system TTS (flutter_tts).
  ///
  /// Caches the last set rate/pitch/language and only makes platform
  /// channel calls when the values actually change. Since MethodChannel
  /// calls on Android/iOS have significant overhead (~5–15 ms each),
  /// skipping them on every line after the first dramatically reduces
  /// the gap between spoken sentences.
  Future<void> _speakSystem(String text) async {
    final tts = await _getFlutterTts();
    final settings = _ref.read(settingsProvider);

    final start = DateTime.now();

    // Rate — only call platform if changed
    final rate = _mapSpeedToSystemRate(settings.ttsSpeed);
    if (rate != _cachedRate) {
      await tts.setSpeechRate(rate);
      _cachedRate = rate;
    }

    // Pitch — only call platform if changed
    if (settings.ttsPitch != _cachedPitch) {
      await tts.setPitch(settings.ttsPitch);
      _cachedPitch = settings.ttsPitch;
    }

    // TTS language — derive from the first enabled translation.
    // Follows the user's translation order in settings.
    final ttsLangCode = _ttsLanguageFromSettings(settings);
    final ttsLocale = _ttsLocaleForLanguage(ttsLangCode);
    if (ttsLocale != _cachedLanguage) {
      developer.log('[TTS] Setting language to $ttsLocale (from $ttsLangCode)',
          name: 'epitaka.tts');
      await tts.setLanguage(ttsLocale);
      _cachedLanguage = ttsLocale;
    }

    state = TtsPlaybackState.playing;
    await tts.speak(text);
    final elapsed = DateTime.now().difference(start).inMilliseconds;
    developer.log('[TTS] _speakSystem() took ${elapsed}ms', name: 'epitaka.tts');
  }

/// Whether the current engine supports look-ahead synthesis.
  bool get supportsPrefetch => _engineType == TtsEngineType.supertonic;

  /// Synthesize [text] via Supertonic WITHOUT playing it.
  Future<dynamic> synthesizePrepared(String text) async {
    await _ensureSupertonicInitialized();
    if (_supertonicTts == null) {
      throw Exception('Supertonic TTS not initialized');
    }
    final settings = _ref.read(settingsProvider);
    return _supertonicTts!.synthesize(
      text,
      language: settings.ttsSupertonicLanguage,
      voiceStyle: settings.ttsSupertonicVoice,
      config: TTSConfig(
        // denoisingSteps: 4,
        speechSpeed: settings.ttsSpeed,
      ),
    );
  }

  /// Play an already-synthesized Supertonic result and await completion.
  Future<void> playPrepared(dynamic result) async {
    if (_player == null) {
      throw Exception('Supertonic TTS not initialized');
    }
    _currentText = null;
    state = TtsPlaybackState.playing;
    await _player!.play(result);
    await _waitForCompletion();
  }

  /// Speak using Supertonic TTS.
  Future<void> _speakSupertonic(String text) async {
    await _ensureSupertonicInitialized();
    if (_supertonicTts == null || _player == null) {
      throw Exception('Supertonic TTS not initialized');
    }

    final settings = _ref.read(settingsProvider);

    state = TtsPlaybackState.loading;

    final result = await _supertonicTts!.synthesize(
      text,
      language: settings.ttsSupertonicLanguage,
      voiceStyle: settings.ttsSupertonicVoice,
      config: TTSConfig(
        denoisingSteps: 4,
        speechSpeed: settings.ttsSpeed,
      ),
    );

    state = TtsPlaybackState.playing;
    await _player!.play(result);
  }

  /// Get available system voices reusing the existing flutter_tts instance.
  ///
  /// IMPORTANT: Do NOT create a second FlutterTts() just for getVoices —
  /// on Android this creates a second native TTS engine connection that
  /// corrupts the main engine's state. After that, every platform channel
  /// call (setLanguage, setSpeechRate, setPitch) balloons from 1-4ms to
  /// 500+ms, introducing multi-second gaps between spoken lines.
  Future<List<Map<String, String>>> getVoices() async {
    final tts = await _getFlutterTts();
    final result = await tts.getVoices;
    if (result is List) {
      return result
          .map((v) => Map<String, String>.from(v as Map))
          .toList();
    }
    return [];
  }

  /// Stop current TTS playback.
  Future<void> stop() async {
    try {
      if (_flutterTts != null) {
        await _flutterTts!.stop();
      }
      if (_player != null) {
        await _player!.stop();
      }
    } catch (_) {
      // Ignore errors when stopping
    }
    state = TtsPlaybackState.stopped;
    _completeSpeech();
  }

  /// Pause current TTS playback.
  Future<void> pause() async {
    try {
      switch (_engineType) {
        case TtsEngineType.system:
          if (_flutterTts != null) {
            await _flutterTts!.pause();
          }
        case TtsEngineType.supertonic:
          if (_player != null) {
            await _player!.pause();
          }
      }
    } catch (_) {
      // Ignore errors when pausing
    }
    state = TtsPlaybackState.paused;
    _completeSpeech();
  }

  /// Resume paused TTS playback and await completion.
  Future<void> resume() async {
    try {
      switch (_engineType) {
        case TtsEngineType.system:
          if (_currentText != null) {
            await _speakSystem(_currentText!);
          } else {
            state = TtsPlaybackState.stopped;
            return;
          }
        case TtsEngineType.supertonic:
          if (_player != null) {
            state = TtsPlaybackState.playing;
            await _player!.resume();
          } else {
            state = TtsPlaybackState.stopped;
            return;
          }
      }
      await _waitForCompletion();
    } catch (e) {
      state = TtsPlaybackState.stopped;
      _completeSpeech();
      rethrow;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _completeSpeech();
    _playerSubscription?.cancel();
    _playerSubscription = null;
    _flutterTts?.setCompletionHandler(() {});
    _flutterTts?.setErrorHandler((_) {});
    _flutterTts = null;
    _supertonicTts?.dispose();
    _supertonicTts = null;
    _player = null;
    _supertonicInitialized = false;
    super.dispose();
  }

  /// Map user-facing speed (0.5–4.0) to flutter_tts speech rate (0.0–1.0).
  /// flutter_tts rate ~0.5 is normal speech, 1.0 is max.
  double _mapSpeedToSystemRate(double userSpeed) {
    // Clamp to [0.5, 4.0]
    final clamped = userSpeed.clamp(0.5, 4.0);
    // Map: 0.5→0.25, 1.0→0.35, 2.0→0.5, 4.0→1.0
    final ratio = (clamped - 0.5) / (4.0 - 0.5);
    return 0.25 + ratio * 0.75;
  }

  /// Map app two-letter language codes to flutter_tts locale codes.
  static String _ttsLocaleForLanguage(String langCode) {
    const map = <String, String>{
      'en': 'en-US',
      'th': 'th-TH',
      'my': 'my-MM',
      'si': 'si-LK',
      'vi': 'vi-VN',
      'de': 'de-DE',
      'es': 'es-ES',
      'fr': 'fr-FR',
      'hi': 'hi-IN',
      'id': 'id-ID',
      'ja': 'ja-JP',
      'km': 'km-KH',
      'ko': 'ko-KR',
      'lo': 'lo-LA',
      'ml': 'ml-IN',
      'mn': 'mn-MN',
      'ms': 'ms-MY',
      'ne': 'ne-NP',
      'nl': 'nl-NL',
      'pt': 'pt-PT',
      'ru': 'ru-RU',
      'ta': 'ta-IN',
      'te': 'te-IN',
      'tr': 'tr-TR',
      'ur': 'ur-PK',
      'zh': 'zh-CN',
    };
    return map[langCode] ?? 'en-US';
  }

  /// Determine which language the TTS should speak based on the first
  /// enabled translation in the user's settings order.
  String _ttsLanguageFromSettings(AppSettings settings) {
    if (settings.enabledTranslations.isNotEmpty) {
      return settings.enabledTranslations.first;
    }
    return settings.primaryTranslationLang;
  }
}

/// Provider for TTS playback state and control.
final ttsProvider = StateNotifierProvider<TtsNotifier, TtsPlaybackState>(
  (ref) => TtsNotifier(ref),
);
