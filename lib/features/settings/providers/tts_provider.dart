import 'dart:async';
import 'dart:developer' as developer;

import 'package:audio_session/audio_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:supertonic_flutter/supertonic_flutter.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/native_speech_service.dart';
import '../../../core/utils/pali_script_converter.dart';
import '../services/tts_audio_handler.dart';

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

  /// Subscription to Android's ACTION_AUDIO_BECOMING_NOISY broadcast
  /// (triggered when Bluetooth disconnects or the headphone jack is
  /// removed). Set up when TTS starts speaking, cancelled on stop.
  StreamSubscription<void>? _noisySubscription;

  /// Whether the AudioSession has been configured for TTS playback.
  bool _audioSessionConfigured = false;

  /// Monotonically increasing speech session ID. Incremented before
  /// each [speak()]/[stop()]/[pause()] call so that stale completion
  /// handlers (from lines that timed out or were stopped) can be
  /// detected and ignored. Without this guard, a delayed completion
  /// handler from a previous line can resolve the *next* line's
  /// completer prematurely, cutting it off.
  int _currentSpeechId = 0;

  /// Cached flutter_tts platform channel values to avoid redundant
  /// MethodChannel calls on every line. Only updated when the user
  /// changes speed/pitch/language via settings.
  double _cachedRate = -1.0; // sentinel — never a valid rate
  double _cachedPitch = -1.0;
  String _cachedLanguage = '';

  /// Cached `getVoices()` result. In Translation+Pāli mode the language
  /// alternates every line, which used to re-fetch voices per line pair;
  /// `getVoices()` is a slow channel call (and the first one after a
  /// second engine instance is known to balloon to 500ms+). Refreshed per
  /// session in [stop] so a newly-installed voice shows up.
  List<Map<String, String>>? _voicesCache;

  /// Key of the last voice configuration applied, "<lang>|<voiceName>".
  /// Guards [setVoice]/[clearVoice] calls so they only happen when the
  /// language or chosen voice actually changed.
  String _cachedVoiceKey = '';

  /// Language of the text currently being spoken (null = derive from
  /// settings). Used to re-apply the right engine language on resume.
  String? _currentLanguage;

  /// Roman source of the Pāli line currently being spoken (see
  /// `TtsLineItem.paliRoman`). Used on resume to re-apply the fallback
  /// script decision.
  String? _currentPaliRoman;

  /// Pāli speech plan chosen for the current session: which script
  /// ('si' | 'hi' | 'th' | 'my' | 'roman') and which language to speak it
  /// in. Resolved on the first Pāli line by probing what the engine can
  /// actually speak, then reused. Reset in [stop] so a newly-installed
  /// voice is picked up next session.
  ({String script, String language})? _paliPlan;

  /// Set when the engine had to fall back because Sinhala isn't
  /// speakable on this device/engine (supertonic has no Sinhala; most
  /// system engines have no Sinhala voice installed). Read by the TTS UI
  /// to tell the user once per session instead of silently skipping.
  String? paliFallbackNotice;

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

  /// Wait for the current speech to finish playing, with a dynamic timeout.
  ///
  /// [text] is used to calculate a reasonable timeout based on length.
  /// The old fixed 30s timeout was too short for long lines (800+ chars
  /// take ~30s at normal speed, and can exceed 30s at slow speed).
  /// When the timeout fires and we continue to the next line, the old
  /// line's native TTS may still be speaking. Its completion handler
  /// can later resolve the *next* line's completer (see Bug 2 below).
  ///
  /// Bug 1 — Premature timeout:
  ///   A long line takes >30s → timeout fires → completer resolved.
  ///   `speak()` catches the TimeoutException, `stop()` is called,
  ///    the engine moves to the next line. But the completion handler
  ///    from the original line is still registered.
  ///
  /// Bug 2 — Stale completion resolves wrong completer:
  ///   The old line's completion handler fires after `stop()` on the
  ///   new line has already started a new `_speakSystem()`. The handler
  ///   calls `_completeSpeech()` which completes the *new* line's
  ///   completer, cutting the new line short. Over minutes this cascade
  ///   drops more and more spoken text.
  ///
  /// Both bugs are fixed by:
  ///   a) Dynamic timeout based on text length (Bug 1)
  ///   b) Speech ID guard in completion/error handlers (Bug 2)
  Future<void> _waitForCompletion([String? text]) async {
    _completeSpeech();
    _speechCompleter = Completer<void>();

    // Dynamic timeout: at 0.5x speed (slowest) ~6 chars/sec → 167ms/char.
    // Use 200ms/char + 15s buffer, clamped to [15s, 5min].
    final speechId = _currentSpeechId;
    Duration timeout;
    if (text != null && text.isNotEmpty) {
      final ms = (text.length * 200) + 15000;
      timeout = Duration(milliseconds: ms.clamp(15000, 300000));
    } else {
      timeout = const Duration(seconds: 30);
    }

    try {
      await _speechCompleter!.future.timeout(timeout);
    } on TimeoutException {
      developer.log(
        '[TTS] _waitForCompletion TIMEOUT speechId=$speechId '
        'text.length=${text?.length ?? 0} timeout=${timeout.inMilliseconds}ms '
        'currentId=$_currentSpeechId',
        name: 'epitaka.tts',
      );
      // Only complete if this speech is still the active one
      // (guard against stale completer races, Bug 2).
      if (_currentSpeechId == speechId) {
        _completeSpeech();
      } else {
        developer.log(
          '[TTS] _waitForCompletion timeout SUPPRESSED: speech is stale',
          name: 'epitaka.tts',
        );
      }
    }
  }

  /// Notify the Android MediaSession notification of the current TTS state.
  /// Called internally after every state change.
  void _broadcastToAudioService({bool hasPrev = false, bool hasNext = false}) {
    ttsAudioHandler.setPlaybackState(
      playing: state == TtsPlaybackState.playing,
      paused: state == TtsPlaybackState.paused,
      hasPrev: hasPrev,
      hasNext: hasNext,
    );
  }

  /// Configure the [AudioSession] for TTS playback and listen for
  /// audio route changes (Bluetooth disconnect / headphone jack removal).
  ///
  /// When the audio route disconnects while TTS is playing, we auto-pause
  /// so the user doesn't miss any content. Without this, TTS would
  /// continue playing through the device speaker after unplugging
  /// headphones, which is unwanted.
  Future<void> _configureAudioSession() async {
    if (_audioSessionConfigured) return;
    _audioSessionConfigured = true;

    // Configure the audio session for speech playback.
    // Uses the built-in 'speech' recipe which sets:
    //   - Android: speech content type, media usage, gain audio focus
    //   - iOS:     playback category, spokenAudio mode
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
      developer.log(
        '[TTS_AUDIO_SESSION] AudioSession configured (speech recipe)',
        name: 'epitaka.tts',
      );
    } catch (e) {
      developer.log(
        '[TTS_AUDIO_SESSION] Failed to configure: $e',
        name: 'epitaka.tts',
      );
    }

    // Set up becoming-noisy listener for auto-pause on earphone disconnect.
    // When headphones are unplugged or Bluetooth disconnects, we auto-pause
    // so the user doesn't miss content playing through the speaker.
    try {
      final session = await AudioSession.instance;
      _noisySubscription?.cancel();
      _noisySubscription = session.becomingNoisyEventStream.listen((_) {
        developer.log(
          '[TTS_BECOMING_NOISY] Audio route disconnected → pausing',
          name: 'epitaka.tts',
        );
        if (state == TtsPlaybackState.playing) {
          pause();
        }
      });
      developer.log(
        '[TTS_BECOMING_NOISY] Listener registered',
        name: 'epitaka.tts',
      );
    } catch (e) {
      developer.log(
        '[TTS_BECOMING_NOISY] Failed to set up listener: $e',
        name: 'epitaka.tts',
      );
    }
  }

  /// Lazily initialize the system TTS engine.
  ///
  /// Note: completion/error handlers are set per-speech in
  /// [_speakSystem] with a speech-ID guard, not here, because
  /// [_getFlutterTts] is called only once (lazy init) and the
  /// handlers set here would persist for the lifetime of the
  /// engine, making them vulnerable to stale completions (Bug 2).
  Future<FlutterTts> _getFlutterTts() async {
    if (_flutterTts != null) return _flutterTts!;

    final tts = FlutterTts();
    _flutterTts = tts;

    // Initial completion/error handlers are set in _speakSystem
    // with speech-ID guards. These are temporary placeholders.
    tts.setCompletionHandler(() {
      developer.log(
        '[TTS] Stale completion handler fired (no speech ID)',
        name: 'epitaka.tts',
      );
      if (!_disposed) {
        state = TtsPlaybackState.stopped;
        _broadcastToAudioService();
      }
    });

    tts.setErrorHandler((msg) {
      developer.log(
        '[TTS] Stale error handler fired: $msg',
        name: 'epitaka.tts',
      );
      if (!_disposed) {
        state = TtsPlaybackState.stopped;
        _broadcastToAudioService();
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
  ///
  /// [language] optionally overrides the TTS language (e.g. 'si' for
  /// Sinhala-converted Pāli). When null, the language is derived from the
  /// first enabled translation.
  Future<void> speak(String text, {String? language, String? paliRoman}) async {
    if (text.trim().isEmpty) return;
    _currentText = text;
    _currentLanguage = language;
    _currentPaliRoman = paliRoman;
    developer.log(
      '[TTS] speak() called: text.length=${text.length} text="${text.length > 40 ? '${text.substring(0, 40)}...' : text}"',
      name: 'epitaka.tts',
    );

    // Increment speech ID BEFORE stop() so the completion handler
    // that fires from stop() won't match the new speech (Bug 2 fix).
    _currentSpeechId++;
    // Skip the redundant stop() when the engine is already idle. The
    // reading flow awaits each line's completion before speaking the
    // next, so the engine is stopped here; calling stop() anyway costs a
    // platform-channel round trip AND resets _audioSessionConfigured,
    // forcing the next line to reconfigure the audio session and
    // re-register the becoming-noisy listener — a large chunk of the
    // audible gap between sentences.
    if (state != TtsPlaybackState.stopped) {
      await stop();
    }

    final start = DateTime.now();
    try {
      switch (_engineType) {
        case TtsEngineType.system:
          await _speakSystem(text, language, paliRoman);
        case TtsEngineType.supertonic:
          try {
            await _speakSupertonic(text, language, paliRoman);
          } catch (e) {
            if (NativeSpeechService.isSupported) {
              // Supertonic isn't available on this platform — fall back to
              // the native system speech synthesizer instead of skipping
              // the line.
              developer.log(
                '[TTS] Supertonic failed on macOS/iOS ($e) — falling back '
                'to native speech',
                name: 'epitaka.tts',
              );
              await _speakSystem(text, language, paliRoman);
            } else {
              rethrow;
            }
          }
      }
      await _waitForCompletion(text);
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      developer.log(
        '[TTS] speak() completed in ${elapsed}ms speechId=$_currentSpeechId',
        name: 'epitaka.tts',
      );
    } catch (e) {
      developer.log(
        '[TTS] speak() error: $e speechId=$_currentSpeechId',
        name: 'epitaka.tts',
      );
      state = TtsPlaybackState.stopped;
      _completeSpeech();
    }
  }

  /// Speak using system TTS (flutter_tts) or NativeSpeechService.
  ///
  /// On macOS/iOS, uses NativeSpeechService as a better alternative.
  /// Caches the last set rate/pitch/language and only makes platform
  /// channel calls when the values actually change.
  Future<void> _speakSystem(
    String text,
    String? language,
    String? paliRoman,
  ) async {
    final settings = _ref.read(settingsProvider);
    final speechId = _currentSpeechId;
    final start = DateTime.now();

    // Use NativeSpeechService on macOS/iOS for better integration
    if (NativeSpeechService.isSupported) {
      developer.log(
        '[TTS] Using NativeSpeechService for macOS/iOS',
        name: 'epitaka.tts',
      );

      // For Pāli text, we still need to handle the script conversion
      String speakText = text;
      String? effectiveLang = language ?? _ttsLanguageFromSettings(settings);

      final isPaliLine =
          language == 'si' && paliRoman != null && paliRoman.isNotEmpty;
      if (isPaliLine) {
        // On macOS/iOS, use Roman Pāli with English voice for best results
        speakText = asciiRomanPali(paliRoman);
        effectiveLang = 'en-US';
        developer.log(
          '[TTS] Pāli converted to Roman for NativeSpeechService: "$speakText"',
          name: 'epitaka.tts',
        );
      }

      await _configureAudioSession();
      state = TtsPlaybackState.playing;
      _broadcastToAudioService();

      final ok = await NativeSpeechService.speak(
        speakText,
        language: effectiveLang,
        onCompletion: () {
          if (!_disposed && speechId == _currentSpeechId) {
            developer.log(
              '[TTS] NativeSpeechService completion: speechId=$speechId (current)',
              name: 'epitaka.tts',
            );
            state = TtsPlaybackState.stopped;
            _broadcastToAudioService();
            _completeSpeech();
          }
        },
      );

      if (!ok) {
        developer.log(
          '[TTS] NativeSpeechService.speak() returned false, falling back to flutter_tts',
          name: 'epitaka.tts',
        );
        state = TtsPlaybackState.stopped;
        // Fall back to flutter_tts
        await _speakFlutterTts(text, language, paliRoman);
      } else {
        final elapsed = DateTime.now().difference(start).inMilliseconds;
        developer.log(
          '[TTS] NativeSpeechService.speak() initiated in ${elapsed}ms speechId=$speechId',
          name: 'epitaka.tts',
        );
      }
      return;
    }

    // Fall back to flutter_tts for other platforms
    await _speakFlutterTts(text, language, paliRoman);
  }

  /// Actual flutter_tts implementation (extracted for fallback).
  Future<void> _speakFlutterTts(
    String text,
    String? language,
    String? paliRoman,
  ) async {
    final tts = await _getFlutterTts();
    final settings = _ref.read(settingsProvider);
    final speechId = _currentSpeechId;

    final start = DateTime.now();

    // Resolve the language to actually speak BEFORE the rate/pitch/language
    // setup. Pāli is always spoken in Devanagari with a Hindi voice (it
    // reads Pāli best). If no Hindi voice is installed the engine falls
    // back to Sinhala, then ASCII Roman with an English voice — otherwise
    // the engine speaks Devanagari glyphs with the wrong voice (mangled
    // audio) or completes instantly (a silent skip).
    final ttsLangCode = language ?? _ttsLanguageFromSettings(settings);
    final isPaliLine =
        language == 'si' && paliRoman != null && paliRoman.isNotEmpty;
    String speakText = text;
    String effectiveLang = ttsLangCode;
    if (isPaliLine) {
      final plan = await _paliSpeechForSystem(tts, text, paliRoman);
      speakText = plan.text;
      effectiveLang = plan.language;
      // Notice only when Hindi wasn't available and the engine fell back.
      if (plan.script != 'hi') _notePaliFallback(plan.script);
    }

    // Rate — only call platform if changed. Pāli lines have their own
    // speed (ttsPaliSpeed) so Pāli can be read at a different pace than
    // the translation.
    final speed = isPaliLine ? settings.ttsPaliSpeed : settings.ttsSpeed;
    final rate = _mapSpeedToSystemRate(speed);
    if (rate != _cachedRate) {
      await tts.setSpeechRate(rate);
      _cachedRate = rate;
    }

    // Pitch — only call platform if changed
    if (settings.ttsPitch != _cachedPitch) {
      await tts.setPitch(settings.ttsPitch);
      _cachedPitch = settings.ttsPitch;
    }

    // TTS language — either the line's own language (e.g. 'si' for
    // Sinhala-converted Pāli) or, by default, the first enabled
    // translation following the user's translation order in settings.
    // Only cache the locale when it was actually applied: a failed
    // setLanguage (voice not installed) must not be cached, or the
    // engine keeps the wrong voice for the rest of the session.
    final ttsLocale = _ttsLocaleForLanguage(effectiveLang);
    if (ttsLocale != _cachedLanguage) {
      developer.log(
        '[TTS] Setting language to $ttsLocale (from $effectiveLang)',
        name: 'epitaka.tts',
      );
      if (await _applyLanguage(tts, ttsLocale)) {
        _cachedLanguage = ttsLocale;
      }
    }

    // TTS voice — apply the user's chosen voice from the system voice
    // list, if one is set AND it belongs to the language being spoken.
    // Voices come from [getVoices] (name + locale). Skipping the
    // explicit voice for other languages (e.g. an English voice would
    // garble Sinhala-converted Pāli) prevents the saved voice from
    // overriding the language setting. Only re-apply when the
    // (language, voice) pair actually changed to avoid redundant
    // platform calls per line.
    final voiceName = settings.ttsVoice;
    final voiceKey = '$effectiveLang|$voiceName';
    if (voiceName.isNotEmpty &&
        voiceName != 'default' &&
        voiceKey != _cachedVoiceKey) {
      try {
        final voices = await getVoices();
        final matches = voices.where((v) => v['name'] == voiceName).toList();
        if (matches.isNotEmpty) {
          final voiceLang = (matches.first['locale'] ?? '')
              .split(RegExp(r'[-_]'))
              .first;
          if (voiceLang.toLowerCase() == effectiveLang.toLowerCase()) {
            await tts.setVoice(matches.first);
            developer.log(
              '[TTS] Applied system voice "$voiceName" for $effectiveLang',
              name: 'epitaka.tts',
            );
          } else {
            // Voice belongs to a different language — clear it so the
            // language setting drives (critical for Sinhala Pāli).
            await tts.clearVoice();
            developer.log(
              '[TTS] Voice "$voiceName" ($voiceLang) skipped for '
              '$effectiveLang — cleared to default',
              name: 'epitaka.tts',
            );
          }
        } else {
          developer.log(
            '[TTS] Voice "$voiceName" not found in system voices — '
            'keeping default',
            name: 'epitaka.tts',
          );
        }
      } catch (e) {
        developer.log('[TTS] setVoice failed: $e', name: 'epitaka.tts');
      }
      _cachedVoiceKey = voiceKey;
    }

    // Set completion handler with speech-ID guard to prevent stale
    // completions from resolving the wrong line's completer.
    tts.setCompletionHandler(() {
      if (!_disposed && speechId == _currentSpeechId) {
        developer.log(
          '[TTS] Completion handler: speechId=$speechId (current)',
          name: 'epitaka.tts',
        );
        state = TtsPlaybackState.stopped;
        _broadcastToAudioService();
        _completeSpeech();
      } else {
        developer.log(
          '[TTS] Completion handler STALE: speechId=$speechId '
          'currentId=$_currentSpeechId (ignored)',
          name: 'epitaka.tts',
        );
      }
    });

    // Error handler with same speech-ID guard
    tts.setErrorHandler((msg) {
      if (!_disposed && speechId == _currentSpeechId) {
        developer.log(
          '[TTS] Error handler: $msg speechId=$speechId (current)',
          name: 'epitaka.tts',
        );
        state = TtsPlaybackState.stopped;
        _broadcastToAudioService();
        _completeSpeech();
      } else {
        developer.log(
          '[TTS] Error handler STALE: $msg speechId=$speechId '
          'currentId=$_currentSpeechId (ignored)',
          name: 'epitaka.tts',
        );
      }
    });

    await _configureAudioSession();
    state = TtsPlaybackState.playing;
    _broadcastToAudioService();
    await tts.speak(speakText);
    final elapsed = DateTime.now().difference(start).inMilliseconds;
    developer.log(
      '[TTS] _speakFlutterTts() took ${elapsed}ms speechId=$speechId',
      name: 'epitaka.tts',
    );
  }

  /// Decide how to speak a Pāli line with the system engine. Resolves
  /// once per session ([_paliPlan]) which script to use — Hindi
  /// (Devanagari) first, then Sinhala, then ASCII Roman with an English
  /// voice — by probing which voices are actually installed. The probe
  /// applies the chosen language as a side effect, so [_cachedLanguage]
  /// is kept in sync.
  Future<({String text, String language, String script})> _paliSpeechForSystem(
    FlutterTts tts,
    String sinhalaText,
    String romanText,
  ) async {
    _paliPlan ??= await _resolvePaliScript(tts);
    final plan = _paliPlan!;
    final speech = paliSpeechText(
      sinhalaText,
      romanText,
      script: plan.script,
      language: plan.language,
    );
    return (text: speech.text, language: speech.language, script: plan.script);
  }

  /// Probe which Pāli script the system engine can actually speak:
  /// Hindi (preferred), then Sinhala, then Roman. 'roman' always succeeds
  /// — with an English voice, or the reading language as a last resort —
  /// so this never returns null.
  Future<({String script, String language})> _resolvePaliScript(
    FlutterTts tts,
  ) async {
    final settings = _ref.read(settingsProvider);
    const candidates = ['hi', 'si', 'roman'];
    for (final script in candidates) {
      if (script == 'roman') {
        // Latin reads best with an English voice.
        if (await _applyLanguage(tts, 'en-US')) {
          _cachedLanguage = 'en-US';
          return (script: 'roman', language: 'en');
        }
        final fallback = _ttsLanguageFromSettings(settings);
        final fallbackLocale = _ttsLocaleForLanguage(fallback);
        if (await _applyLanguage(tts, fallbackLocale)) {
          _cachedLanguage = fallbackLocale;
        }
        return (script: 'roman', language: fallback);
      }
      final locale = _ttsLocaleForLanguage(script);
      if (await _applyLanguage(tts, locale)) {
        _cachedLanguage = locale;
        return (script: script, language: script);
      }
    }
    // Unreachable — 'roman' always returns. Defensive fallback.
    return (script: 'roman', language: _ttsLanguageFromSettings(settings));
  }

  /// Prepare a Pāli line for the Supertonic engine. Its 31 languages have
  /// no Sinhala, so Pāli is always spoken in Devanagari with a Hindi
  /// voice.
  ({String text, String language}) _paliForSupertonic(
    String sinhalaText,
    String romanText,
  ) {
    return paliSpeechText(sinhalaText, romanText, script: 'hi', language: 'hi');
  }

  /// Adjust Devanagari Pāli specifically for the Hindi TTS engine.
  ///
  /// Hindi TTS tends to pronounce short Pāli /i/ (इ) too close to
  /// Hindi /ɪ/.  These substitutions are intended to improve the
  /// acoustic pronunciation without modifying the actual Pāli text.
  static String _prepareHindiPaliTts(String text) {
    return text
        // Short i: prevent Hindi TTS from shifting इ toward "e".
        // Niggahīta.
        .replaceAll('ं', 'ङ')
        // ḷ
        .replaceAll('ळ', 'ल')
        // ñ
        .replaceAll('ञ', 'न्य')
        // ph = p + h, not f.
        .replaceAll('फ', 'प्ह')
        // Add a small separation before the second consonant
        // of common Pāli geminates/conjuncts.
        .replaceAllMapped(
          RegExp(r'([क-ह])्([क-ह])'),
          (m) => '${m.group(1)}्${m.group(2)}',
        )
        .replaceAll('इ', 'ि');
    // Preserve final Pāli -o.
    // .replaceAllMapped(
    //   RegExp(r'([^\s।,;:!?]+ो)(?=\s|$|।|,|;|:)'),
    //   (m) => '${m.group(1)}ऽ',
    // );
  }

  /// Write [romanText]'s Pāli in [script] for the TTS voice, paired with
  /// the [language] the engine should speak it in. 'roman' strips the
  /// IAST diacritics so any (English) voice can read it. Pure + static.
  static ({String text, String language}) paliSpeechText(
    String sinhalaText,
    String romanText, {
    required String script,
    required String language,
  }) {
    sinhalaText = sinhalaText.replaceAll(
      "’’",
      '',
    ); // normalize apostrophes to right single quote
    switch (script) {
      case 'si':
        return (text: sinhalaText, language: language);
      case 'hi':
        final devanagari = TextProcessor.convert(
          sinhalaText,
          Script.devanagari,
        );
        return (text: _prepareHindiPaliTts(devanagari), language: language);
      default:
        return (text: asciiRomanPali(romanText), language: language);
    }
  }

  /// Strip IAST diacritics from Roman Pāli so any TTS voice can read it
  /// ("evaṃ me sutaṃ" → "evam me sutam"); English voices mangle ā/ṭ/ṃ.
  static String asciiRomanPali(String text) {
    const map = <String, String>{
      'ā': 'a',
      'ī': 'i',
      'ū': 'u',
      'ṅ': 'n',
      'ñ': 'n',
      'ṭ': 't',
      'ḍ': 'd',
      'ṇ': 'n',
      'ḷ': 'l',
      'ṃ': 'm',
      'ṁ': 'm',
      'Ā': 'A',
      'Ī': 'I',
      'Ū': 'U',
      'Ṅ': 'N',
      'Ñ': 'N',
      'Ṭ': 'T',
      'Ḍ': 'D',
      'Ṇ': 'N',
      'Ḷ': 'L',
      'Ṃ': 'M',
      'Ṁ': 'M',
    };
    final sb = StringBuffer();
    for (final ch in text.split('')) {
      sb.write(map[ch] ?? ch);
    }
    return sb.toString();
  }

  /// Set the system engine's language; returns whether it was applied
  /// (flutter_tts returns 1 on success, 0 when the locale/voice isn't
  /// available on this device). Used both as the normal language setter
  /// and as the availability probe for the Pāli fallback chain.
  Future<bool> _applyLanguage(FlutterTts tts, String locale) async {
    try {
      final res = await tts.setLanguage(locale);
      final ok = res == true || res == 1;
      developer.log(
        '[TTS] setLanguage($locale) → ${ok ? 'ok' : 'unavailable'}',
        name: 'epitaka.tts',
      );
      return ok;
    } catch (e) {
      developer.log(
        '[TTS] setLanguage($locale) failed: $e',
        name: 'epitaka.tts',
      );
      return false;
    }
  }

  /// Record (once per session) that the engine fell back from Hindi to
  /// [script] (no Hindi voice installed), so the UI can tell the user
  /// instead of silently skipping Pāli lines.
  void _notePaliFallback(String script) {
    if (paliFallbackNotice != null) return;
    paliFallbackNotice =
        'Reading Pāli in ${_paliScriptLabel(script)} '
        '(Devanagari (Hindi) voice not available).';
    developer.log(
      '[TTS] Pāli fallback: $paliFallbackNotice',
      name: 'epitaka.tts',
    );
  }

  /// Display name of a Pāli TTS script key.
  static String _paliScriptLabel(String script) => switch (script) {
    'si' => 'Sinhala',
    _ => 'Roman (English)',
  };

  /// Whether the current engine supports look-ahead synthesis.
  bool get supportsPrefetch => _engineType == TtsEngineType.supertonic;

  /// Map the quality preset to Supertonic denoising steps.
  /// Lower steps = faster synthesis on slower devices; higher = better
  /// quality but slower. 'low'=2, 'medium'=4, 'high'=8.
  static int _denoisingStepsForQuality(String quality) {
    switch (quality) {
      case 'low':
        return 2;
      case 'high':
        return 8;
      default:
        return 4;
    }
  }

  /// Synthesize [text] via Supertonic WITHOUT playing it.
  ///
  /// [language] optionally overrides the TTS language (e.g. 'si' for
  /// Sinhala-converted Pāli). When null, follows the reading language.
  /// Pāli lines are re-encoded for a script Supertonic can speak (it has
  /// no Sinhala voice).
  Future<dynamic> synthesizePrepared(
    String text, {
    String? language,
    String? paliRoman,
  }) async {
    await _ensureSupertonicInitialized();
    if (_supertonicTts == null) {
      throw Exception('Supertonic TTS not initialized');
    }
    final settings = _ref.read(settingsProvider);
    var speakText = text;
    var effectiveLanguage = language ?? _ttsLanguageFromSettings(settings);
    var isPaliLine = false;
    if (language == 'si' && paliRoman != null && paliRoman.isNotEmpty) {
      final plan = _paliForSupertonic(text, paliRoman);
      speakText = plan.text;
      effectiveLanguage = plan.language;
      isPaliLine = true;
    }
    return _supertonicTts!.synthesize(
      speakText,
      // Follow the reading language (first enabled translation) unless
      // the line carries its own language (e.g. Pāli).
      language: effectiveLanguage,
      voiceStyle: settings.ttsSupertonicVoice,
      config: TTSConfig(
        denoisingSteps: _denoisingStepsForQuality(
          settings.ttsSupertonicQuality,
        ),
        speechSpeed: isPaliLine ? settings.ttsPaliSpeed : settings.ttsSpeed,
      ),
    );
  }

  /// Play an already-synthesized Supertonic result and await completion.
  Future<void> playPrepared(dynamic result) async {
    if (_player == null) {
      throw Exception('Supertonic TTS not initialized');
    }
    await _configureAudioSession();
    _currentText = null;
    _currentSpeechId++;
    state = TtsPlaybackState.playing;
    await _player!.play(result);
    await _waitForCompletion();
  }

  /// Speak using Supertonic TTS.
  Future<void> _speakSupertonic(
    String text,
    String? language,
    String? paliRoman,
  ) async {
    await _ensureSupertonicInitialized();
    if (_supertonicTts == null || _player == null) {
      throw Exception('Supertonic TTS not initialized');
    }

    final settings = _ref.read(settingsProvider);
    final speechId = _currentSpeechId;

    var speakText = text;
    var effectiveLanguage = language ?? _ttsLanguageFromSettings(settings);
    var isPaliLine = false;
    if (language == 'si' && paliRoman != null && paliRoman.isNotEmpty) {
      final plan = _paliForSupertonic(text, paliRoman);
      speakText = plan.text;
      effectiveLanguage = plan.language;
      isPaliLine = true;
    }

    state = TtsPlaybackState.loading;

    final result = await _supertonicTts!.synthesize(
      speakText,
      // Follow the reading language (first enabled translation) unless
      // the line carries its own language (e.g. Pāli).
      language: effectiveLanguage,
      voiceStyle: settings.ttsSupertonicVoice,
      config: TTSConfig(
        denoisingSteps: _denoisingStepsForQuality(
          settings.ttsSupertonicQuality,
        ),
        speechSpeed: isPaliLine ? settings.ttsPaliSpeed : settings.ttsSpeed,
      ),
    );

    await _configureAudioSession();
    state = TtsPlaybackState.playing;
    _broadcastToAudioService();
    await _player!.play(result);
    developer.log(
      '[TTS] _speakSupertonic() speechId=$speechId',
      name: 'epitaka.tts',
    );
  }

  /// Get available system voices reusing the existing flutter_tts instance.
  ///
  /// IMPORTANT: Do NOT create a second FlutterTts() just for getVoices —
  /// on Android this creates a second native TTS engine connection that
  /// corrupts the main engine's state. After that, every platform channel
  /// call (setLanguage, setSpeechRate, setPitch) balloons from 1-4ms to
  /// 500+ms, introducing multi-second gaps between spoken lines.
  Future<List<Map<String, String>>> getVoices() async {
    if (_voicesCache != null) return _voicesCache!;
    final tts = await _getFlutterTts();
    final result = await tts.getVoices;
    if (result is List) {
      _voicesCache = result
          .map((v) => Map<String, String>.from(v as Map))
          .toList();
      return _voicesCache!;
    }
    return [];
  }

  /// Stop current TTS playback.
  Future<void> stop() async {
    _currentSpeechId++; // Invalidate stale completion handlers
    // Forget the Pāli script decision + fallback notice + voice cache so
    // the next session re-probes (picks up a newly-installed voice).
    _paliPlan = null;
    paliFallbackNotice = null;
    _voicesCache = null;
    try {
      if (_flutterTts != null) {
        await _flutterTts!.stop();
        _flutterTts!.setCompletionHandler(() {});
        _flutterTts!.setErrorHandler((_) {});
      }
      if (_player != null) {
        await _player!.stop();
      }
      if (NativeSpeechService.isSupported) {
        await NativeSpeechService.stop();
      }
    } catch (_) {
      // Ignore errors when stopping
    }
    // Cancel the audio session listener when fully stopped
    _noisySubscription?.cancel();
    _noisySubscription = null;
    _audioSessionConfigured = false;

    state = TtsPlaybackState.stopped;
    _broadcastToAudioService();
    _completeSpeech();
  }

  /// Pause current TTS playback.
  Future<void> pause() async {
    _currentSpeechId++; // Invalidate stale completion handlers
    try {
      switch (_engineType) {
        case TtsEngineType.system:
          if (_flutterTts != null) {
            await _flutterTts!.pause();
          }
          // Native speech has no pause — stop it; resume re-speaks the
          // current line from the start.
          if (NativeSpeechService.isSupported) {
            await NativeSpeechService.stop();
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
    _broadcastToAudioService();
    _completeSpeech();
  }

  /// Resume paused TTS playback and await completion.
  Future<void> resume() async {
    try {
      switch (_engineType) {
        case TtsEngineType.system:
          if (_currentText != null) {
            await _speakSystem(
              _currentText!,
              _currentLanguage,
              _currentPaliRoman,
            );
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
    developer.log(
      '[TTS_LIFECYCLE] TtsNotifier.dispose() called '
      'state=$state _disposed=$_disposed '
      'hasFlutterTts=${_flutterTts != null} '
      'hasSupertonic=${_supertonicTts != null} '
      'hasPlayer=${_player != null} '
      '_audioSessionConfigured=$_audioSessionConfigured',
      name: 'epitaka.tts',
    );
    _disposed = true;
    _completeSpeech();
    _noisySubscription?.cancel();
    _noisySubscription = null;
    _playerSubscription?.cancel();
    _playerSubscription = null;
    _flutterTts?.setCompletionHandler(() {});
    _flutterTts?.setErrorHandler((_) {});
    _flutterTts = null;
    _supertonicTts?.dispose();
    _supertonicTts = null;
    _player = null;
    _supertonicInitialized = false;
    _audioSessionConfigured = false;
    developer.log(
      '[TTS_LIFECYCLE] TtsNotifier.dispose() completed',
      name: 'epitaka.tts',
    );
    super.dispose();
  }

  /// Map user-facing speed (0.1–4.0) to flutter_tts speech rate (0.0–1.0).
  /// flutter_tts rate ~0.5 is normal speech, 1.0 is max.
  double _mapSpeedToSystemRate(double userSpeed) {
    // Clamp to [0.1, 4.0]
    final clamped = userSpeed.clamp(0.1, 4.0);
    if (clamped >= 0.5) {
      // Keep the original 0.5–4.0 mapping untouched (0.5→0.25, 1.0→0.35,
      // 2.0→0.5, 4.0→1.0) so existing speed settings keep their sound;
      // only the newly-exposed 0.1–0.5 range is slower than before.
      final ratio = (clamped - 0.5) / (4.0 - 0.5);
      return 0.25 + ratio * 0.75;
    }
    // 0.1–0.5: extend the curve downward (0.1→0.15, 0.5→0.25), continuous
    // with the range above.
    final lowRatio = (clamped - 0.1) / (0.5 - 0.1);
    return 0.15 + lowRatio * (0.25 - 0.15);
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
