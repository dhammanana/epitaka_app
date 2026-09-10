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

  /// Key of the last voice configuration applied, "<lang>|<voiceName>"
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
    // Use 200ms/char + 4s buffer, clamped to [4s, 5min]. The buffer is a
    // safety net for the native completion callback arriving late — it must
    // never be the thing that gates line advancement on its own, or a missed
    // completion handler turns into a multi-second silent gap between
    // sentences (previously 15s+, which is what the macOS logs showed when
    // NSSpeechSynthesizer never reported completion).
    final speechId = _currentSpeechId;
    Duration timeout;
    if (text != null && text.isNotEmpty) {
      final ms = (text.length * 200) + 4000;
      timeout = Duration(milliseconds: ms.clamp(4000, 300000));
    } else {
      timeout = const Duration(seconds: 10);
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
        // Return the state machine to `stopped` so the next line's speak()
        // skips the redundant stop() (which resets _audioSessionConfigured
        // and forces the next line to re-configure the audio session and
        // re-register the becoming-noisy listener — a large chunk of the
        // audible gap between sentences). Without this, one missed
        // completion handler made every following line pay that cost.
        state = TtsPlaybackState.stopped;
        _broadcastToAudioService();
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

      // Pin the Siri/premium voice picked by AppleTtsVoicePolicy. Without
      // an explicit identifier the native side uses its own default —
      // never leave it to chance, or macOS falls back to the compact
      // "robot" voice.
      final voiceId = await NativeSpeechService.pickVoiceId(
        language: effectiveLang,
      );

      final ok = await NativeSpeechService.speak(
        speakText,
        language: effectiveLang,
        voiceIdentifier: voiceId,
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
    // setup. Pāli is spoken in the user's chosen script (Hindi/Devanagari
    // reads Pāli best) with the matching voice. If that voice isn't
    // installed the engine falls back through the probe chain — otherwise
    // it would speak the script with the wrong voice (mangled audio) or
    // complete instantly (a silent skip).
    final ttsLangCode = language ?? _ttsLanguageFromSettings(settings);
    final isPaliLine =
        language == 'si' && paliRoman != null && paliRoman.isNotEmpty;
    String speakText = text;
    String effectiveLang = ttsLangCode;
    if (isPaliLine) {
      final requestedScript = settings.ttsScript;
      final plan = await _paliSpeechForSystem(tts, text, paliRoman);
      speakText = plan.text;
      effectiveLang = plan.language;
      // Notice only when the requested script wasn't available and the
      // engine fell back to something else — not on every intentional
      // Telugu/Kannada/Sinhala choice.
      if (plan.script != requestedScript) _notePaliFallback(plan.script);
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

    // TTS voice resolution runs BEFORE the language is applied.
    // The Pāli voice picker used to be hardcoded to Hindi voices, so a
    // Hindi voice is often selected while the Pāli script is Telugu /
    // Kannada / Sinhala. Calling clearVoice() AFTER setLanguage() resets
    // the engine's language on Android, so those scripts were then spoken
    // with the wrong (default) voice — silent or mangled — while Hindi
    // (voice matches language) kept working. Resolving here lets a
    // mismatched voice be cleared BEFORE setLanguage() so the language
    // sticks, and lets Pāli auto-pick a system voice for its script.
    // Pāli lines use their own dedicated voice setting (ttsPaliVoice)
    // separately from the translation voice.
    final voiceName = isPaliLine ? settings.ttsPaliVoice : settings.ttsVoice;
    final voiceKey = '$effectiveLang|$voiceName';
    Map<String, String>? matchedVoice;
    var voiceMismatch = false;
    if (voiceName.isNotEmpty && voiceName != 'default') {
      try {
        final voices = await getVoices();
        final matches = voices.where((v) => v['name'] == voiceName).toList();
        if (matches.isNotEmpty) {
          final voiceLang = (matches.first['locale'] ?? '')
              .split(RegExp(r'[-_]'))
              .first;
          if (voiceLang.toLowerCase() == effectiveLang.toLowerCase()) {
            matchedVoice = matches.first;
          } else {
            voiceMismatch = true;
          }
        }
      } catch (e) {
        developer.log('[TTS] voice lookup failed: $e', name: 'epitaka.tts');
      }
    }
    if (voiceMismatch) {
      // Clear a stale mismatched voice BEFORE setLanguage — clearing
      // after would undo the language just applied.
      if (_cachedVoiceKey != 'cleared|$effectiveLang') {
        try {
          await tts.clearVoice();
        } catch (e) {
          developer.log('[TTS] clearVoice failed: $e', name: 'epitaka.tts');
        }
        _cachedVoiceKey = 'cleared|$effectiveLang';
        // Force the language to be (re-)applied below — the clear may
        // have reset the engine back to its default locale.
        _cachedLanguage = '';
        developer.log(
          '[TTS] Voice "$voiceName" skipped for $effectiveLang — '
          'cleared before setLanguage',
          name: 'epitaka.tts',
        );
      }
    }

    // TTS language — either the line's own language (e.g. 'te' for
    // Telugu-converted Pāli) or, by default, the first enabled
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

    // Apply the user's chosen voice when it matches the spoken language.
    // When the user left the Pāli voice on 'default' (or it belongs to
    // another language), auto-pick the first system voice for the Pāli
    // script so Telugu/Kannada/Sinhala don't fall back to the engine's
    // default (often English) voice and go silent.
    if (matchedVoice != null) {
      if (voiceKey != _cachedVoiceKey) {
        try {
          await tts.setVoice(matchedVoice);
          developer.log(
            '[TTS] Applied system voice "$voiceName" for $effectiveLang',
            name: 'epitaka.tts',
          );
        } catch (e) {
          developer.log('[TTS] setVoice failed: $e', name: 'epitaka.tts');
        }
        _cachedVoiceKey = voiceKey;
      }
    } else if (!voiceMismatch && isPaliLine) {
      final autoKey = 'auto|$effectiveLang';
      if (_cachedVoiceKey != autoKey && _cachedVoiceKey != voiceKey) {
        try {
          final voices = await getVoices();
          final lc = effectiveLang.toLowerCase();
          Map<String, String>? auto;
          for (final v in voices) {
            final loc = (v['locale'] ?? '').toLowerCase();
            if (loc == lc ||
                loc.startsWith('$lc-') ||
                loc.startsWith('${lc}_')) {
              auto = v;
              break;
            }
          }
          if (auto != null) {
            await tts.setVoice(auto);
            developer.log(
              '[TTS] Auto-picked Pāli voice "${auto['name']}" for '
              '$effectiveLang',
              name: 'epitaka.tts',
            );
            _cachedVoiceKey = autoKey;
          } else {
            _cachedVoiceKey = voiceKey;
          }
        } catch (e) {
          developer.log('[TTS] auto-voice failed: $e', name: 'epitaka.tts');
          _cachedVoiceKey = voiceKey;
        }
      }
    } else if (!isPaliLine) {
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

  /// Decide how to speak a Pāli line with the system engine. Uses the
  /// user's chosen script ([AppSettings.ttsScript]) when that voice is
  /// installed, otherwise falls back to the probe chain (Hindi, Sinhala,
  /// Roman). Resolved once per session ([_paliPlan]) and invalidated when
  /// the setting changes or [stop] runs.
  Future<({String text, String language, String script})> _paliSpeechForSystem(
    FlutterTts tts,
    String sinhalaText,
    String romanText,
  ) async {
    final script = _ref.read(settingsProvider).ttsScript;
    if (_paliPlan == null || _paliPlan!.script != script) {
      if (script == 'roman') {
        _paliPlan = await _resolvePaliScript(tts);
      } else {
        final locale = _ttsLocaleForLanguage(script);
        if (await _applyLanguage(tts, locale)) {
          _cachedLanguage = locale;
          _paliPlan = (script: script, language: script);
        } else {
          _paliPlan = await _resolvePaliScript(tts);
        }
      }
    }
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
  /// no Sinhala. For Hindi uses Devanagari conversion; for other scripts
  /// falls back to Roman (ASCII) since Supertonic has no Kannada/Telugu/Sinhala voices.
  ({String text, String language}) _paliForSupertonic(
    String sinhalaText,
    String romanText,
  ) {
    final script = _ref.read(settingsProvider).ttsScript;
    // Supertonic only has Hindi among the Pāli-script options.
    // For non-Hindi scripts, fall back to Roman (ASCII) for compatibility.
    final useScript = script == 'hi' ? 'hi' : 'roman';
    return paliSpeechText(
      sinhalaText,
      romanText,
      script: useScript,
      language: useScript == 'hi' ? 'hi' : 'en',
    );
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
  static String stripPaliNumbers(String text) {
    var out = text.replaceAll(RegExp(r'\p{Nd}+\s*\.*', unicode: true), ' ');
    out = out.replaceAll(RegExp(r'\s+'), ' ');
    out = out.replaceAllMapped(
      RegExp(r'\s+([,;:.!?।॥])'),
      (m) => '${m.group(1)}',
    );
    return out.trim();
  }

  static ({String text, String language}) paliSpeechText(
    String sinhalaText,
    String romanText, {
    required String script,
    required String language,
  }) {
    sinhalaText = stripPaliNumbers(
      sinhalaText.replaceAll(
        "’’",
        '',
      ), // normalize apostrophes to right single quote
    );
    romanText = stripPaliNumbers(romanText);
    switch (script) {
      case 'si':
        return (text: sinhalaText, language: language);
      case 'hi':
        final devanagari = TextProcessor.convert(
          sinhalaText,
          Script.devanagari,
        );
        return (text: _prepareHindiPaliTts(devanagari), language: language);
      case 'kn':
        final kannada = TextProcessor.convert(sinhalaText, Script.kannada);
        return (text: kannada, language: language);
      case 'te':
        final telugu = TextProcessor.convert(sinhalaText, Script.telugu);
        return (text: telugu, language: language);
      default:
        return (text: asciiRomanPali(romanText), language: language);
    }
  }

  /// Strip IAST diacritics from Roman Pāli so any TTS voice can read it
  /// ("evaṃ me sutaṃ" → "evam me sutam"); English voices mangle ā/ṭ/ṃ.
  static String asciiRomanPali(String text) {
    text = stripPaliNumbers(text);
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
    'kn' => 'Kannada',
    'te' => 'Telugu',
    'si' => 'Sinhala',
    'hi' => 'Hindi (Sanskrit)',
    _ => 'Roman (English)',
  };

  /// Whether the current engine supports look-ahead synthesis.
  ///
  /// Requires supertonic to actually be initialized: on macOS/iOS the
  /// engine is unavailable, and reporting prefetch support there made the
  /// reading loop take the prefetch path, whose synthesize calls throw and
  /// silently skip every line instead of falling back to native speech.
  bool get supportsPrefetch =>
      _engineType == TtsEngineType.supertonic && _supertonicInitialized;

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
    NativeSpeechService.clearVoiceCache();
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
    // NOTE: the audio session configuration and the becoming-noisy listener
    // are intentionally NOT torn down here. They are app-lifetime concerns:
    // _configureAudioSession() is guarded by _audioSessionConfigured, so
    // tearing it down on every stop() made the next line re-run the whole
    // AudioSession setup + listener registration — a large chunk of the
    // audible gap between spoken sentences. The listener only acts while
    // state == playing, so keeping it registered across sessions is safe.
    // (dispose() still tears both down.)

    state = TtsPlaybackState.stopped;
    _broadcastToAudioService();
    _completeSpeech();
  }

  /// Emergency stop for process teardown (`detached` / swipe-kill).
  ///
  /// Fire-and-forget: never throws, never reads settings (providers may
  /// already be torn down). Without this, the native engine (Android
  /// TextToSpeech / AVSpeechSynthesizer) finishes the queued utterance
  /// after the Dart isolate is gone — "kill the app but TTS keeps
  /// speaking".
  void emergencyStop() {
    _currentSpeechId++;
    _completeSpeech();
    try {
      _flutterTts?.stop();
    } catch (_) {}
    try {
      _player?.stop();
    } catch (_) {}
    if (NativeSpeechService.isSupported) {
      try {
        NativeSpeechService.stop();
      } catch (_) {}
    }
    _noisySubscription?.cancel();
    _noisySubscription = null;
    if (!_disposed) {
      state = TtsPlaybackState.stopped;
      _broadcastToAudioService();
    }
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
    // Stop the native engines BEFORE dropping the handles — otherwise a
    // queued utterance outlives the provider ("app killed, TTS keeps
    // speaking"). Unawaited: dispose is synchronous.
    try {
      _flutterTts?.stop();
    } catch (_) {}
    try {
      _player?.stop();
    } catch (_) {}
    if (NativeSpeechService.isSupported) {
      try {
        NativeSpeechService.stop();
      } catch (_) {}
    }
    _completeSpeech();
    _noisySubscription?.cancel();
    _noisySubscription = null;
    _playerSubscription?.cancel();
    _playerSubscription = null;
    try {
      _flutterTts?.setCompletionHandler(() {});
      _flutterTts?.setErrorHandler((_) {});
    } catch (_) {}
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

  /// Map user-facing speed (0.1–8.0) to flutter_tts speech rate (0.0–1.0).
  /// flutter_tts rate ~0.5 is normal speech, 1.0 is max.
  double _mapSpeedToSystemRate(double userSpeed) {
    // Clamp to [0.1, 8.0]
    final clamped = userSpeed.clamp(0.1, 8.0);
    if (clamped >= 0.5) {
      // Map 0.5→0.25, 1.0→0.35, 4.0→0.85, 8.0→1.0
      final ratio = (clamped - 0.5) / (8.0 - 0.5);
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
      'kn': 'kn-IN',
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
