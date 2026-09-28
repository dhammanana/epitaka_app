import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart' show VoidCallback, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/native_speech_service.dart';
import '../../../core/utils/pali_script_converter.dart';
import '../../reader/providers/tts_speak_unit.dart'
    show
        TtsProgressCallback,
        TtsQueuedUtterance,
        TtsUtteranceQueue,
        kTtsWordHighlightEnabled,
        mapSpokenOffsetToSource;
import '../services/system_tts_availability.dart';
import '../services/tts_audio_handler.dart';

/// TTS playback state.
enum TtsPlaybackState { stopped, playing, paused, loading }

/// TTS notifier managing playback state for the system TTS engine.
///
/// Uses `flutter_tts` for platform-native TTS (plus `NativeSpeechService`
/// on macOS/iOS).
class TtsNotifier extends StateNotifier<TtsPlaybackState> {
  final Ref _ref;

  // System TTS engine
  FlutterTts? _flutterTts;

  bool _disposed = false;

  // Outstanding utterances awaiting engine completion, FIFO (see
  // TtsUtteranceQueue). Holds the playing utterance plus at most one
  // queued-ahead prefetch. Replaces the old single-completer + speech-ID
  // scheme, which could not overlap utterances:
  //
  // Bug 1 (kept fixed) — Premature timeout: dynamic per-utterance timeout;
  //   a timeout flushes the engine (stop + resolve + drain) so a
  //   still-playing utterance can never resolve a later entry.
  // Bug 2 (kept fixed) — Stale completion: stop()/pause()/timeout flush the
  //   engine and resolve+clear the queue, then drain briefly so late
  //   in-flight callbacks land in an empty queue and are ignored instead of
  //   popping a newer entry.
  final TtsUtteranceQueue _utterances = TtsUtteranceQueue();
  String? _currentText;

  /// Outcome of the most recently finished utterance: whether the engine
  /// reported an error, and wall-clock milliseconds from enqueue to
  /// completion. The reading loop reads it after each unit to detect a
  /// failing engine (error callbacks or implausibly fast completions) and
  /// stop the session with an actionable notice instead of fast-skipping
  /// silently through lines. Null before the first utterance or after
  /// [stop] (which resolves outstanding entries without engine playback).
  ({bool errored, int elapsedMs})? lastOutcome;

  /// Subscription to Android's ACTION_AUDIO_BECOMING_NOISY broadcast
  /// (triggered when Bluetooth disconnects or the headphone jack is
  /// removed). Set up when TTS starts speaking, cancelled on stop.
  StreamSubscription<void>? _noisySubscription;

  /// Whether the AudioSession has been configured for TTS playback.
  bool _audioSessionConfigured = false;

  /// Whether audio focus is currently claimed. Claimed once per speaking
  /// stretch (not per utterance — re-requesting focus on every sentence
  /// adds round trips and can fight transient interruptions); reset on
  /// stop()/pause() so the next stretch re-claims.
  bool _audioFocusClaimed = false;

  /// Whether queue-ahead prefetch is usable (QUEUE_ADD accepted, Android
  /// flutter_tts). Read by the reading loop to decide between overlapping
  /// and strictly sequential speaks.
  bool get supportsPrefetch => _queuePrefetchReady;
  bool _queuePrefetchReady = false;

  /// Cached flutter_tts platform channel values to avoid redundant
  /// MethodChannel calls on every line. Only updated when the user
  /// changes speed/pitch/language via settings.
  double _cachedRate = -1.0; // sentinel — never a valid rate
  double _cachedPitch = -1.0;
  String _cachedLanguage = '';

  /// Engine id this app has explicitly selected via [setEngine] (null =
  /// the engine's default). `getDefaultEngine` on the platform channel
  /// returns the SYSTEM-wide default engine, which is not the same thing —
  /// the UI must show the app-selected one or the subtitle goes stale
  /// after a switch.
  String? currentEngine;

  /// Cached `getVoices()` result. In Translation+Pāli mode the language
  /// alternates every line, which used to re-fetch voices per line pair;
  /// `getVoices()` is a slow channel call (and the first one after a
  /// second engine instance is known to balloon to 500ms+). Refreshed per
  /// session in [stop] so a newly-installed voice shows up.
  List<Map<String, String>>? _voicesCache;

  /// Key of the last voice configuration applied, `<lang>|<voiceName>`
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
  /// speakable on this device (most system engines have no Sinhala voice
  /// installed). Read by the TTS UI to tell the user once per session
  /// instead of silently skipping.
  String? paliFallbackNotice;

  String? translationIssueNotice;

  final Map<String, TtsLanguageCheck> _langChecks = {};

  TtsNotifier(this._ref) : super(TtsPlaybackState.stopped);

  /// Dynamic per-utterance timeout from text length (long lines need longer
  /// budgets, especially at slow speeds). The old fixed 30s timeout cut off
  /// long lines; the reading loop applies this same budget around each
  /// unit's entry future.
  static Duration timeoutFor([String? text]) {
    if (text != null && text.isNotEmpty) {
      final ms = (text.length * 200) + 4000;
      return Duration(milliseconds: ms.clamp(4000, 300000));
    }
    return const Duration(seconds: 10);
  }

  /// Flush the engine and resolve every outstanding entry. Late in-flight
  /// callbacks then land in an empty queue and are ignored. No-op when
  /// idle, so the hot completion→next-speak path pays nothing.
  Future<void> _flushEngine() async {
    if (_utterances.isEmpty) return;
    try {
      await _flutterTts?.stop();
      if (NativeSpeechService.isSupported) {
        await NativeSpeechService.stop();
      }
    } catch (_) {
      // Ignore errors when stopping
    }
    _utterances.resolveAll();
    // Drain: a callback sent just before the flush can still arrive; with
    // an empty queue it is ignored instead of popping a newer entry.
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  /// Route an engine start-event to the oldest unstarted entry (only the
  /// head can start playing) and fire its prefetch trigger.
  void _routeStart() {
    if (_disposed) return;
    try {
      _utterances.markStarted()?.onStarted?.call();
    } catch (_) {}
  }

  /// Route an engine done/cancel/error-event to the head entry. Empty queue
  /// means a late/duplicate callback — ignored. Records the utterance
  /// outcome (error flag + wall time) BEFORE resolving, so a sequential
  /// waiter always observes its own utterance's outcome for failure
  /// detection.
  void _routeDone({bool error = false}) {
    final entry = _utterances.popHead();
    if (entry == null) return;
    if (error) entry.errored = true;
    lastOutcome = (
      errored: entry.errored,
      elapsedMs: DateTime.now().difference(entry.enqueuedAt).inMilliseconds,
    );
    entry.resolve();
    if (_utterances.isEmpty && !_disposed) {
      if (state == TtsPlaybackState.playing) {
        state = TtsPlaybackState.stopped;
        _broadcastToAudioService();
      }
    }
  }

  /// Route an engine progress-event to the entry whose text matches (the
  /// plugin echoes the full utterance text). Translates spoken-script
  /// offsets back to the caller's text space before invoking the callback.
  void _routeProgress(String text, int s, int e, String w) {
    if (_disposed) return;
    final entry = _utterances.matchByText(text);
    final cb = entry?.onProgress;
    final disp = w.length > 20 ? '${w.substring(0, 20)}…' : w;
    developer.log(
      '[TTS_WORD] engine s=$s e=$e word="$disp" textLen=${text.length} '
      'matched=${entry != null} speakLen=${entry?.speakText.length} '
      'sourceLen=${entry?.sourceText.length} hasCb=${cb != null}',
      name: 'epitaka.tts',
    );
    if (cb == null) return;
    try {
      cb(
        mapSpokenOffsetToSource(
          source: entry!.sourceText,
          spoken: entry.speakText,
          spokenOffset: s,
        ),
        mapSpokenOffsetToSource(
          source: entry.sourceText,
          spoken: entry.speakText,
          spokenOffset: e,
        ),
        w,
      );
    } catch (_) {}
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
  /// Android focus is TRANSIENT-MAY-DUCK, not permanent gain: the audible
  /// audio comes from the system TTS engine's own process (not from us),
  /// and that engine requests transient focus for every utterance. Holding
  /// permanent gain makes each of its requests hit our interruption
  /// listener and auto-pause/kill the just-started utterance (a few words
  /// play, then silence, then the loop advances — the release "fast skip").
  /// May-duck still yields to real preemptions (calls/alarms arrive as
  /// lossTransient → pause), while engine duck-requests are ignored by the
  /// reading loop (see its interruption handler).
  Future<void> _configureAudioSession() async {
    if (_audioSessionConfigured) return;

    try {
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.none,
          avAudioSessionMode: AVAudioSessionMode.spokenAudio,
          androidAudioFocusGainType:
              AndroidAudioFocusGainType.gainTransientMayDuck,
          androidWillPauseWhenDucked: false,
        ),
      );
      // Claim audio focus: without setActive(true) the OS never routes
      // media buttons to our MediaSession and may duck/kill TTS when
      // backgrounded (anx-reader calls setActive(true) in play()).
      await session.setActive(true);
      // Latched only on success: a failed attempt must retry on the next
      // speak instead of silently running session-less forever.
      _audioSessionConfigured = true;
      _audioFocusClaimed = true;
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
  /// Engine callbacks are registered ONCE here as permanent routers serving
  /// the FIFO queue positionally (see [TtsUtteranceQueue]). Per-speak
  /// registration would overwrite the previous utterance's routing while it
  /// still plays — exactly what prefetch must not do. Stale safety comes
  /// from [_flushEngine] (resolve + clear + drain) instead of handler IDs.
  Future<FlutterTts> _getFlutterTts() async {
    if (_flutterTts != null) return _flutterTts!;

    final tts = FlutterTts();
    _flutterTts = tts;

    tts.setStartHandler(_routeStart);
    tts.setCompletionHandler(() => _routeDone());
    tts.setCancelHandler(() => _routeDone());
    tts.setErrorHandler((msg) {
      developer.log('[TTS] engine error: $msg', name: 'epitaka.tts');
      _routeDone(error: true);
    });
    tts.setProgressHandler(
      (String text, int s, int e, String w) => _routeProgress(text, s, e, w),
    );

    // QUEUE_ADD lets a second utterance wait behind the playing one so the
    // engine pre-loads the next voice (the Pāli→translation switch) instead
    // of going idle. Android-only per the plugin docs; elsewhere the queue
    // is always depth ≤1 and behaves like FLUSH.
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await tts.setQueueMode(1);
        _queuePrefetchReady = true;
        developer.log('[TTS] QUEUE_ADD enabled', name: 'epitaka.tts');
      } catch (e) {
        _queuePrefetchReady = false;
        developer.log('[TTS] setQueueMode failed: $e', name: 'epitaka.tts');
      }
    }

    return tts;
  }

  /// Speak the given [text] using the system TTS engine and await completion.
  ///
  /// [language] optionally overrides the TTS language (e.g. 'si' for
  /// Sinhala-converted Pāli). When null, the language is derived from the
  /// first enabled translation.
  /// [onProgress] receives per-word progress callbacks (flutter_tts path
  /// only; the Apple native channel has no progress API). Ignored unless
  /// [kTtsWordHighlightEnabled].
  /// [onStarted] fires when the utterance starts playing — the reading
  /// loop uses it to queue the next unit ahead (prefetch).
  /// [flush], when true (default), stops any outstanding utterance first so
  /// a standalone speak (preview, resume) takes over immediately. Prefetch
  /// passes false to queue behind the playing utterance.
  /// [watchdog], when true (default), bounds the wait with [timeoutFor];
  /// the reading loop passes false and applies its own per-unit budget.
  Future<void> speak(
    String text, {
    String? language,
    String? paliRoman,
    TtsProgressCallback? onProgress,
    VoidCallback? onStarted,
    bool flush = true,
    bool watchdog = true,
  }) async {
    if (text.trim().isEmpty) return;
    _currentText = text;
    _currentLanguage = language;
    _currentPaliRoman = paliRoman;
    developer.log(
      '[TTS] speak() called: text.length=${text.length} text="${text.length > 40 ? '${text.substring(0, 40)}...' : text}"',
      name: 'epitaka.tts',
    );

    // Outstanding-utterance safety is handled by the FIFO queue + flush
    // discipline (see [_flushEngine]): stale callbacks land in an empty
    // queue and are ignored, and [_flushEngine] no-ops when idle so the
    // hot completion→next-speak path pays nothing.

    final start = DateTime.now();
    try {
      if (flush) await _flushEngine();
      if (_disposed) return;
      final entry = await _speakSystem(
        text,
        language,
        paliRoman,
        onProgress,
        onStarted,
      );
      if (entry == null) return;
      if (watchdog) {
        try {
          await entry.completer.future.timeout(timeoutFor(text));
        } on TimeoutException {
          developer.log(
            '[TTS] speak() TIMEOUT text.length=${text.length} '
            'timeout=${timeoutFor(text).inMilliseconds}ms',
            name: 'epitaka.tts',
          );
          await _flushEngine();
        }
      } else {
        await entry.completer.future;
      }
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      developer.log(
        '[TTS] speak() completed in ${elapsed}ms',
        name: 'epitaka.tts',
      );
    } catch (e) {
      developer.log(
        '[TTS] speak() error: $e',
        name: 'epitaka.tts',
      );
      state = TtsPlaybackState.stopped;
      _broadcastToAudioService();
    }
  }

  /// Speak using system TTS (flutter_tts) or NativeSpeechService.
  ///
  /// On macOS/iOS, uses NativeSpeechService as a better alternative.
  /// Caches the last set rate/pitch/language and only makes platform
  /// channel calls when the values actually change.
  /// Returns the queued entry the caller awaits (null when the speak was
  /// rejected and nothing will play).
  Future<TtsQueuedUtterance?> _speakSystem(
    String text,
    String? language,
    String? paliRoman,
    TtsProgressCallback? onProgress,
    VoidCallback? onStarted,
  ) async {
    final settings = _ref.read(settingsProvider);
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

      final isPaliLine = paliRoman != null && paliRoman.isNotEmpty;
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

      final userSpeed = isPaliLine ? settings.ttsPaliSpeed : settings.ttsSpeed;
      final entry = _utterances.enqueue(
        speakText,
        sourceText: text,
        onStarted: onStarted,
      );
      final ok = await NativeSpeechService.speak(
        speakText,
        language: effectiveLang,
        voiceIdentifier: voiceId,
        rate: _mapSpeedToNativeRate(userSpeed),
        onCompletion: () {
          developer.log(
            '[TTS] NativeSpeechService completion',
            name: 'epitaka.tts',
          );
          _routeDone();
        },
      );

      if (!ok) {
        _utterances.removeEntry(entry);
        entry.resolve();
        developer.log(
          '[TTS] NativeSpeechService.speak() returned false, falling back to flutter_tts',
          name: 'epitaka.tts',
        );
        state = TtsPlaybackState.stopped;
        // Fall back to flutter_tts. NOTE: the Apple native channel has no
        // progress API, so [onProgress] only fires on the flutter_tts path.
        return _speakFlutterTts(text, language, paliRoman, onProgress, onStarted);
      } else {
        final elapsed = DateTime.now().difference(start).inMilliseconds;
        developer.log(
          '[TTS] NativeSpeechService.speak() initiated in ${elapsed}ms',
          name: 'epitaka.tts',
        );
        return entry;
      }
    }

    // Fall back to flutter_tts for other platforms
    return _speakFlutterTts(text, language, paliRoman, onProgress, onStarted);
  }

  /// Actual flutter_tts implementation (extracted for fallback).
  /// Returns the queued entry the caller awaits (null when rejected).
  Future<TtsQueuedUtterance?> _speakFlutterTts(
    String text,
    String? language,
    String? paliRoman,
    TtsProgressCallback? onProgress,
    VoidCallback? onStarted,
  ) async {
    final tts = await _getFlutterTts();
    final settings = _ref.read(settingsProvider);

    final start = DateTime.now();

    // Resolve the language to actually speak BEFORE the rate/pitch/language
    // setup. Pāli is spoken in the user's chosen script (Hindi/Devanagari
    // reads Pāli best) with the matching voice. If that voice isn't
    // installed the engine falls back through the probe chain — otherwise
    // it would speak the script with the wrong voice (mangled audio) or
    // complete instantly (a silent skip).
    final ttsLangCode = language ?? _ttsLanguageFromSettings(settings);
    final isPaliLine = paliRoman != null && paliRoman.isNotEmpty;
    String speakText = text;
    String effectiveLang = ttsLangCode;
    if (isPaliLine) {
      final plan = await _paliSpeechForSystem(tts, text, paliRoman);
      speakText = plan.text;
      effectiveLang = plan.language;
      // The chosen script is always spoken as-is — no availability
      // probing, no fallback, so no misleading "voice not available"
      // notice (it fired wrongly for working scripts like Kannada).
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
          if (voiceLang.toLowerCase() == effectiveLang.toLowerCase() &&
              SystemTtsAvailability.isVoiceUsable(matches.first)) {
            matchedVoice = matches.first;
          } else {
            voiceMismatch = true;
          }
        }
      } catch (e) {
        developer.log('[TTS] voice lookup failed: $e', name: 'epitaka.tts');
      }
    }
    if (!isPaliLine && !_langChecks.containsKey(effectiveLang)) {
      try {
        final voices = await getVoices();
        final check = await SystemTtsAvailability.checkLanguage(
          tts,
          voices,
          effectiveLang,
        );
        _langChecks[effectiveLang] = check;
        if (check.status == TtsVoiceStatus.needsDownload ||
            check.status == TtsVoiceStatus.notSupported) {
          _noteTranslationIssue(effectiveLang, check.status);
        }
      } catch (e) {
        developer.log('[TTS] language check failed: $e', name: 'epitaka.tts');
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
          final local = SystemTtsAvailability.localVoicesFor(
            voices,
            effectiveLang,
          );
          final usable = SystemTtsAvailability.usableVoicesFor(
            voices,
            effectiveLang,
          );
          Map<String, String>? auto;
          if (local.isNotEmpty) {
            auto = local.first;
          } else if (usable.isNotEmpty) {
            auto = usable.first;
          } else {
            final lc = effectiveLang.toLowerCase();
            for (final v in voices) {
              final loc = (v['locale'] ?? '').toLowerCase();
              if (loc == lc ||
                  loc.startsWith('$lc-') ||
                  loc.startsWith('${lc}_')) {
                auto = v;
                break;
              }
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

    // Engine callbacks are routed permanently (see [_getFlutterTts]): the
    // router serves the FIFO queue positionally, so per-speak registration
    // here would overwrite the previous utterance's routing while it still
    // plays. Just enqueue this utterance ahead of the actual speak call —
    // a start-event arriving during the await below then finds its entry.
    final entry = _utterances.enqueue(
      speakText,
      sourceText: text,
      onProgress: (kTtsWordHighlightEnabled ? onProgress : null),
      onStarted: onStarted,
    );

    await _configureAudioSession();
    // Claim audio focus once per speaking stretch (not per utterance):
    // re-requesting focus on every sentence adds round trips and can fight
    // transient interruptions. Reset on stop()/pause() so the next stretch
    // re-claims (an interruption may have taken focus meanwhile).
    if (!_audioFocusClaimed) {
      try {
        await (await AudioSession.instance).setActive(true);
        _audioFocusClaimed = true;
      } catch (_) {}
    }
    state = TtsPlaybackState.playing;
    _broadcastToAudioService();
    TtsQueuedUtterance? accepted = entry;
    try {
      final speakRes = await tts.speak(speakText);
      final ok = speakRes == true || speakRes == 1;
      if (!ok) {
        developer.log(
          '[TTS] speak() rejected res=$speakRes',
          name: 'epitaka.tts',
        );
        _utterances.removeEntry(entry);
        entry.resolve();
        accepted = null;
        _noteTranslationIssue(effectiveLang, TtsVoiceStatus.unknown);
        if (_utterances.isEmpty) {
          state = TtsPlaybackState.stopped;
          _broadcastToAudioService();
        }
        return accepted;
      }
    } catch (e) {
      // Platform exception: the utterance never queued, so no callbacks
      // will arrive — resolve eagerly instead of hanging the waiter.
      developer.log('[TTS] speak() threw: $e', name: 'epitaka.tts');
      _utterances.removeEntry(entry);
      entry.resolve();
      accepted = null;
      if (_utterances.isEmpty) {
        state = TtsPlaybackState.stopped;
        _broadcastToAudioService();
      }
      return accepted;
    }
    final elapsed = DateTime.now().difference(start).inMilliseconds;
    developer.log(
      '[TTS] _speakFlutterTts() took ${elapsed}ms',
      name: 'epitaka.tts',
    );
    return accepted;
  }

  /// Decide how to speak a Pāli line with the system engine. Always uses
  /// the user's chosen script ([AppSettings.ttsScript]) — no availability
  /// probing: setLanguage() returning false does NOT reliably mean the
  /// voice is missing (a stale voice binding or a network voice can make
  /// it fail even though the voice speaks fine), and treating it as
  /// "unavailable" wrongly demoted working scripts (e.g. Kannada) to the
  /// Roman fallback. 'roman' just uses an English locale. Resolved once
  /// per session ([_paliPlan]) and invalidated when the setting changes
  /// or [stop] runs.
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
        _paliPlan = (script: script, language: script);
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

  /// Resolve the language used for Roman Pāli: an English voice reads
  /// Latin best. The language setting is only used if no English variant
  /// is enabled. Pure decision — no engine probing.
  Future<({String script, String language})> _resolvePaliScript(
    FlutterTts tts,
  ) async {
    final settings = _ref.read(settingsProvider);
    return (script: 'roman', language: _ttsLanguageFromSettings(settings));
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

  void _noteTranslationIssue(String langCode, TtsVoiceStatus status) {
    if (translationIssueNotice != null) return;
    final label = _languageLabel(langCode);
    translationIssueNotice = switch (status) {
      TtsVoiceStatus.needsDownload =>
        '$label voice not installed. Install it in System TTS settings, '
            'then play again.',
      TtsVoiceStatus.notSupported =>
        '$label is not supported by this TTS engine. Switch to Google TTS '
            'in System TTS settings.',
      TtsVoiceStatus.networkOnly =>
        '$label voice needs internet. Connect or download the voice.',
      _ => '$label voice failed to start. Check System TTS settings.',
    };
    developer.log(
      '[TTS] translation issue: $translationIssueNotice',
      name: 'epitaka.tts',
    );
  }

  TtsLanguageCheck? languageCheckFor(String langCode) => _langChecks[langCode];

  Future<TtsLanguageCheck?> refreshLanguageCheck(String langCode) async {
    try {
      final tts = await _getFlutterTts();
      final voices = await getVoices();
      final check = await SystemTtsAvailability.checkLanguage(
        tts,
        voices,
        langCode,
      );
      _langChecks[langCode] = check;
      return check;
    } catch (_) {
      return _langChecks[langCode];
    }
  }

  Future<List<String>> getEngines() async {
    try {
      final tts = await _getFlutterTts();
      return SystemTtsAvailability.getEngines(tts);
    } catch (_) {
      return [];
    }
  }

  Future<String?> getDefaultEngine() async {
    // Prefer the engine this app selected; only fall back to the system
    // default when the user hasn't switched within the app.
    if (currentEngine != null) return currentEngine;
    try {
      final tts = await _getFlutterTts();
      return SystemTtsAvailability.getDefaultEngine(tts);
    } catch (_) {
      return null;
    }
  }

  Future<void> setEngine(String name) async {
    try {
      await _flushEngine();
      final tts = await _getFlutterTts();
      await tts.setEngine(name);
      currentEngine = name;
      _cachedRate = -1.0;
      _cachedPitch = -1.0;
      _cachedLanguage = '';
      _cachedVoiceKey = '';
      _voicesCache = null;
      _langChecks.clear();
    } catch (e) {
      developer.log('[TTS] setEngine failed: $e', name: 'epitaka.tts');
    }
  }

  static String _languageLabel(String langCode) => switch (langCode) {
    'si' => 'Sinhala',
    'hi' => 'Hindi',
    'my' => 'Myanmar',
    'th' => 'Thai',
    'te' => 'Telugu',
    'kn' => 'Kannada',
    'en' => 'English',
    _ => langCode,
  };

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
    // Forget the Pāli script decision + fallback notice + voice cache so
    // the next session re-probes (picks up a newly-installed voice).
    _paliPlan = null;
    paliFallbackNotice = null;
    translationIssueNotice = null;
    _langChecks.clear();
    _voicesCache = null;
    // Outstanding entries are resolved by the flush below without engine
    // playback — drop the previous outcome so the reading loop never
    // mistakes it for the next utterance's result.
    lastOutcome = null;
    NativeSpeechService.clearVoiceCache();
    _audioFocusClaimed = false;
    await _flushEngine();
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
  }

  /// Emergency stop for process teardown (`detached` / swipe-kill).
  ///
  /// Fire-and-forget: never throws, never reads settings (providers may
  /// already be torn down). Without this, the native engine (Android
  /// TextToSpeech / AVSpeechSynthesizer) finishes the queued utterance
  /// after the Dart isolate is gone — "kill the app but TTS keeps
  /// speaking".
  void emergencyStop() {
    _utterances.resolveAll();
    try {
      _flutterTts?.stop();
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
  ///
  /// Uses `stop()` on the system engine rather than flutter_tts `pause()`:
  /// the native pause slices the utterance at the last onRangeStart
  /// progress (often unsupported by OEM engines) and leaves the plugin's
  /// `isPaused` flag set, so the next `speak()` of the same text resumes
  /// mid-line instead of restarting it. [resume] re-speaks the full
  /// current line, so stop-then-respeak is the correct primitive here
  /// (same as anx-reader's SystemTts.pause).
  Future<void> pause() async {
    _audioFocusClaimed = false;
    await _flushEngine();
    state = TtsPlaybackState.paused;
    _broadcastToAudioService();
  }

  /// Resume paused TTS playback and await completion.
  ///
  /// Standalone primitive (settings preview, etc.): no word progress — the
  /// reading flow re-speaks its unit via [speak] so progress keeps flowing.
  /// Never throws (preview buttons don't await error handling).
  Future<void> resume() async {
    if (_currentText == null) {
      state = TtsPlaybackState.stopped;
      return;
    }
    await speak(
      _currentText!,
      language: _currentLanguage,
      paliRoman: _currentPaliRoman,
    );
  }

  @override
  void dispose() {
    developer.log(
      '[TTS_LIFECYCLE] TtsNotifier.dispose() called '
      'state=$state _disposed=$_disposed '
      'hasFlutterTts=${_flutterTts != null} '
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
    if (NativeSpeechService.isSupported) {
      try {
        NativeSpeechService.stop();
      } catch (_) {}
    }
    _utterances.resolveAll();
    _noisySubscription?.cancel();
    _noisySubscription = null;
    _flutterTts = null;
    _audioSessionConfigured = false;
    _audioFocusClaimed = false;
    developer.log(
      '[TTS_LIFECYCLE] TtsNotifier.dispose() completed',
      name: 'epitaka.tts',
    );
    super.dispose();
  }

  /// Map user-facing speed (0.1–8.0, 1.0 = normal) to the flutter_tts
  /// speech rate. 1.0x maps to 0.5 (the engine's normal rate) and scales
  /// linearly, so 2x vs 3x is clearly audible (0.5 apart, not 0.1).
  /// Values above 1.0 are passed through: Android honors >1.0 rates,
  /// iOS clamps to its 1.0 max.
  static double mapSpeedToSystemRate(double userSpeed) =>
      (userSpeed.clamp(0.1, 8.0) * 0.5).clamp(0.05, 4.0);

  double _mapSpeedToSystemRate(double userSpeed) =>
      mapSpeedToSystemRate(userSpeed);

  /// Rate passed over the native channel (macOS/iOS). Same scale as
  /// [mapSpeedToSystemRate]: 1.0 = normal speech.
  static double mapSpeedToNativeRate(double userSpeed) =>
      mapSpeedToSystemRate(userSpeed);

  double _mapSpeedToNativeRate(double userSpeed) =>
      mapSpeedToNativeRate(userSpeed);

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
