import 'dart:async';
import 'dart:developer' as developer;

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_db_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/native_speech_service.dart';
import '../../../core/utils/notification_permission.dart';
import '../../settings/providers/tts_provider.dart';
import '../../settings/services/tts_audio_handler.dart';
import 'tts_speak_unit.dart';

/// A single line item to be spoken by TTS.
class TtsLineItem {
  final int paraId;
  final int lineId;
  final String text;

  /// TTS language code for this item — e.g. 'si' for Sinhala-converted
  /// Pāli, or the translation's language code. When null, the engine
  /// derives the language from the first enabled translation.
  final String? language;

  /// When non-null, this item is a Pāli line and [paliRoman] is its
  /// cleaned Roman (IAST) source. The engine prefers to speak the
  /// Sinhala-converted [text], but can re-encode from this source when
  /// the active TTS engine has no Sinhala voice (falling back to
  /// Devanagari/Hindi, then plain ASCII Roman) instead of skipping the
  /// line.
  final String? paliRoman;

  const TtsLineItem({
    required this.paraId,
    required this.lineId,
    required this.text,
    this.language,
    this.paliRoman,
  });

  bool get isPali => paliRoman != null && paliRoman!.trim().isNotEmpty;
}

/// State for line-by-line TTS reading.
///
/// Speaking is batched: [units] groups [lines] into single utterances (one
/// paragraph per utterance in single-voice modes). [currentUnitIndex] drives
/// the speak loop; [currentIndex] stays synced to the line being highlighted
/// (advanced by progress callbacks inside a unit), so every existing
/// consumer (highlight, auto-scroll, history) keeps working unchanged.
class TtsReadingState {
  final String? bookId;
  final List<TtsLineItem> lines;
  final int currentIndex;
  final List<TtsSpeakUnit> units;
  final int currentUnitIndex;
  final bool isActive;
  final bool isPaused;

  const TtsReadingState({
    this.bookId,
    this.lines = const [],
    this.currentIndex = 0,
    this.units = const [],
    this.currentUnitIndex = 0,
    this.isActive = false,
    this.isPaused = false,
  });

  bool get isEmpty => lines.isEmpty;
  bool get isNotEmpty => lines.isNotEmpty;

  /// The paragraph ID of the line currently being spoken.
  int? get currentParaId =>
      currentIndex < lines.length ? lines[currentIndex].paraId : null;

  /// The line ID of the line currently being spoken.
  int? get currentLineId =>
      currentIndex < lines.length ? lines[currentIndex].lineId : null;

  TtsLineItem? get currentLine =>
      currentIndex < lines.length ? lines[currentIndex] : null;

  bool get currentIsPali => currentLine?.isPali ?? false;

  /// Progress: 0.0 to 1.0 (unit-granular when batched).
  double get progress => units.isNotEmpty
      ? (currentUnitIndex + 1) / units.length
      : (lines.isEmpty ? 0.0 : (currentIndex + 1) / lines.length);

  TtsReadingState copyWith({
    String? bookId,
    List<TtsLineItem>? lines,
    int? currentIndex,
    List<TtsSpeakUnit>? units,
    int? currentUnitIndex,
    bool? isActive,
    bool? isPaused,
  }) {
    return TtsReadingState(
      bookId: bookId ?? this.bookId,
      lines: lines ?? this.lines,
      currentIndex: currentIndex ?? this.currentIndex,
      units: units ?? this.units,
      currentUnitIndex: currentUnitIndex ?? this.currentUnitIndex,
      isActive: isActive ?? this.isActive,
      isPaused: isPaused ?? this.isPaused,
    );
  }
}

/// Notifier for line-by-line TTS reading.
///
/// Takes a list of [TtsLineItem]s and speaks them sequentially using
/// the [ttsProvider]. Tracks which line is currently being spoken
/// for UI highlighting and auto-scrolling.
class TtsReadingNotifier extends StateNotifier<TtsReadingState> {
  final Ref _ref;
  int _currentSessionId = 0;

  /// Subscription to Android's ACTION_AUDIO_BECOMING_NOISY broadcast
  /// (triggered when Bluetooth disconnects or the headphone jack is
  /// removed). Initialised when reading starts, cancelled on stop/finish.
  StreamSubscription<void>? _noisySubscription;

  /// Subscription to audio interruptions (phone calls, notifications,
  /// other apps taking focus). On begin we pause the reading loop; on
  /// end of a transient (pause/duck) interruption we resume, mirroring
  /// anx-reader's TtsHandler. Without this, the loop keeps advancing
  /// silently through lines while the user hears nothing.
  StreamSubscription<AudioInterruptionEvent>? _interruptionSubscription;

  /// Debounce timer for position updates while listening.
  Timer? _listeningSaveTimer;

  /// Last saved paraId for the current listening session (dedupes saves).
  int? _lastSavedListeningParaId;

  TtsReadingNotifier(this._ref) : super(const TtsReadingState());

  /// Start reading from [lines] starting at [startIndex].
  Future<void> startReading(
    String bookId,
    List<TtsLineItem> lines, {
    int startIndex = 0,
  }) async {
    // Invalidate and cancel any running speak loops by incrementing the session ID
    _currentSessionId++;
    final sessionId = _currentSessionId;

    developer.log(
      '[TTS_LIFECYCLE] startReading() called: bookId=$bookId '
      'lines=${lines.length} startIndex=$startIndex sessionId=$sessionId',
      name: 'epitaka.tts',
    );

    await _ref.read(ttsProvider.notifier).stop();

    if (lines.isEmpty) {
      developer.log(
        '[TTS_LIFECYCLE] startReading(): lines empty, no-op',
        name: 'epitaka.tts',
      );
      state = const TtsReadingState();
      return;
    }

    final speakLines = _stripPaliNumbers(lines);
    final units = _buildUnits(speakLines);
    if (units.isEmpty) {
      developer.log(
        '[TTS_LIFECYCLE] startReading(): no speakable content, no-op',
        name: 'epitaka.tts',
      );
      state = const TtsReadingState();
      return;
    }
    // Map the requested line [startIndex] onto its unit (line indices ascend
    // across units; empty lines were skipped during batching).
    var unitIndex = 0;
    for (var i = 0; i < units.length; i++) {
      if (units[i].lineIndices.first <= startIndex) {
        unitIndex = i;
      } else {
        break;
      }
    }
    _clearUnitSpeechState();

    state = TtsReadingState(
      bookId: bookId,
      lines: speakLines,
      currentIndex: units[unitIndex].lineIndices.first,
      units: units,
      currentUnitIndex: unitIndex,
      isActive: true,
    );

    // Record the book in the listening history right away, so opening the
    // Listening history tab always shows what was played.
    _saveListeningHistoryNow();

    // ── AudioService integration ───────────────────────────────────
    // NOTE: AudioService.init() is intentionally NOT called here directly.
    // It runs once at app startup (main() before runApp, the audio_service
    // README pattern); initAudioServiceOnce() below is a no-op when that
    // succeeded and a foreground retry when it failed (some OEMs refuse
    // the foreground service at cold start, which used to leave TTS with
    // no notification — and a process the OS kills in background — for the
    // whole session). Calling init() again directly would hit the
    // '_cacheManager == null' assertion. The ttsAudioHandler singleton
    // registered during that init stays active, so setMediaItem(),
    // setPlaybackState(), and notification controls all work without
    // re-initializing.
    final audioReady = await initAudioServiceOnce();
    if (!audioReady) {
      developer.log(
        '[TTS_LIFECYCLE] startReading(): audio service unavailable, '
        'reading without notification',
        name: 'epitaka.tts',
      );
    }
    // Best-effort Android 13+ POST_NOTIFICATIONS grant BEFORE the first
    // playback-state broadcast, so the media player can appear in the
    // notification shade (several OEM skins hide it otherwise). Never
    // blocks reading: when denied, the foreground-service notification is
    // still posted (exempt on stock Android).
    await ensureNotificationPermission();

    // Register notification-button callbacks so the lock screen /
    // notification controls work throughout this reading session.
    ttsAudioHandler.onPlayPressed = () => resumeReading();
    ttsAudioHandler.onPausePressed = () => pauseReading();
    ttsAudioHandler.onStopPressed = () => stopReading();
    ttsAudioHandler.onSkipNextPressed = () => skipForward();
    ttsAudioHandler.onSkipPreviousPressed = () => skipBackward();
    ttsAudioHandler.getIsPaused = () => state.isPaused;

    // Show the book title in the notification.
    ttsAudioHandler.setMediaItem(
      id: bookId,
      title: _bookNameCache[bookId] ?? bookId,
      artist: 'ePitaka',
    );

    // Start foregrounding the notification.
    ttsAudioHandler.setPlaybackState(
      playing: true,
      paused: false,
      hasPrev: startIndex > 0,
      hasNext: startIndex < lines.length - 1,
    );
    // ───────────────────────────────────────────────────────────────

    // ── Force media button routing ─────────────────────────────────
    // TTS doesn't go through Android's standard audio focus pipeline,
    // so the system won't route headset/Bluetooth media buttons to
    // our MediaSession. Calling androidForceEnableMediaButtons() plays
    // a brief silent audio clip to convince Android that we're a media
    // app and to route media buttons to our session. Without this call,
    // earphone buttons, Bluetooth headset buttons, and lock-screen
    // controls will NOT deliver events to our handler.
    try {
      await AudioService.androidForceEnableMediaButtons();
      developer.log(
        '[TTS_MEDIA_BTN] androidForceEnableMediaButtons() succeeded',
        name: 'epitaka.tts',
      );
    } catch (e) {
      developer.log(
        '[TTS_MEDIA_BTN] androidForceEnableMediaButtons() failed: $e',
        name: 'epitaka.tts',
      );
    }
    // ───────────────────────────────────────────────────────────────

    // ── Audio Becoming Noisy (Bluetooth disconnect / jack removal) ──
    // Listen for ACTION_AUDIO_BECOMING_NOISY so we auto-pause TTS when
    // the user unplugs headphones or disconnects Bluetooth earbuds.
    // The TtsNotifier also listens for this event for standalone TTS
    // (e.g. settings preview), but we keep this reading-level listener
    // too so it can update the TtsReadingState (isPaused flag) and
    // notification state.
    try {
      final session = await AudioSession.instance;
      _noisySubscription?.cancel();
      _noisySubscription = session.becomingNoisyEventStream.listen((_) {
        developer.log(
          '[TTS_BECOMING_NOISY] Audio route disconnected → pausing reading',
          name: 'epitaka.tts',
        );
        pauseReading();
      });
    } catch (e) {
      developer.log(
        '[TTS_BECOMING_NOISY] Failed to initialise AudioSession: $e',
        name: 'epitaka.tts',
      );
    }
    // ── Audio interruptions (calls, notifications, other apps) ────
    // Pause the reading loop when interrupted; resume when a transient
    // interruption ends. Guarded by state so stale events after stop are
    // no-ops (pauseReading/resumeReading already no-op when inactive).
    try {
      final session = await AudioSession.instance;
      _interruptionSubscription?.cancel();
      _interruptionSubscription = session.interruptionEventStream.listen((
        event,
      ) {
        if (event.begin) {
          // Duck requests are ignored: with transient-may-duck focus the
          // system TTS engine ducks us for every utterance it speaks (its
          // audio runs in its own process). Pausing here would kill each
          // just-started line after a few words and either stall the
          // session or race through lines. Real preemptions (calls,
          // alarms, notifications) arrive as pause/unknown and still pause.
          if (event.type == AudioInterruptionType.duck) {
            developer.log(
              '[TTS_INTERRUPTION] begin duck → ignored (engine duck)',
              name: 'epitaka.tts',
            );
            return;
          }
          developer.log(
            '[TTS_INTERRUPTION] begin type=${event.type} → pausing reading',
            name: 'epitaka.tts',
          );
          pauseReading();
        } else {
          switch (event.type) {
            case AudioInterruptionType.pause:
            case AudioInterruptionType.duck:
              developer.log(
                '[TTS_INTERRUPTION] end type=${event.type} → resuming reading',
                name: 'epitaka.tts',
              );
              resumeReading();
              break;
            case AudioInterruptionType.unknown:
              break;
          }
        }
      });
    } catch (e) {
      developer.log(
        '[TTS_INTERRUPTION] Failed to initialise: $e',
        name: 'epitaka.tts',
      );
    }
    // ───────────────────────────────────────────────────────────────

    await _speakCurrent(sessionId);
  }

  /// Simple cache keyed by bookId to avoid re-querying the book name
  /// every time reading starts. Populated from the UI layer when the
  /// reader screen loads the book.
  static final Map<String, String> _bookNameCache = {};

  /// Set the display name for [bookId] so the notification shows a
  /// meaningful title (e.g., "Dhammasaṅgaṇī-aṭṭhakathā") instead of
  /// the raw book ID.
  static void cacheBookName(String bookId, String name) {
    _bookNameCache[bookId] = name;
  }

  /// Stop reading and reset state.
  ///
  /// Completely stops the Android foreground service and removes the
  /// notification. If the user wants to keep the notification available
  /// for quick resume they should use [pauseReading] instead.
  Future<void> stopReading() async {
    developer.log(
      '[TTS_LIFECYCLE] stopReading() called: '
      'isActive=${state.isActive} isPaused=${state.isPaused} '
      'currentIndex=${state.currentIndex}/${state.lines.length} '
      'sessionId=$_currentSessionId',
      name: 'epitaka.tts',
    );
    _currentSessionId++;
    // Save the final position before the state is reset below.
    _listeningSaveTimer?.cancel();
    _listeningSaveTimer = null;
    await _saveListeningHistoryNow();
    await _ref.read(ttsProvider.notifier).stop();
    _clearUnitSpeechState();
    state = const TtsReadingState();
    // Keep notification callbacks registered: the audio service lives for
    // the whole process (init-once), so the next startReading() reuses it.
    // Clearing them here + broadcasting `idle` killed restart ("after stop,
    // cannot start again" — the service never came back).
    ttsAudioHandler.dismiss();
  }

  /// Process teardown (`detached` / swipe-kill). Stops the engines
  /// synchronously-ish and dismisses the notification. Safe to call when
  /// idle; never throws.
  Future<void> handleAppDetached() async {
    _currentSessionId++;
    _listeningSaveTimer?.cancel();
    _listeningSaveTimer = null;
    _interruptionSubscription?.cancel();
    _interruptionSubscription = null;
    _clearUnitSpeechState();
    try {
      _ref.read(ttsProvider.notifier).emergencyStop();
    } catch (_) {}
    try {
      ttsAudioHandler.dismiss();
    } catch (_) {}
    if (state.isActive) state = const TtsReadingState();
  }

  /// Pause reading.
  Future<void> pauseReading() async {
    // Guard: no-op if reading is not active (prevents stale callbacks
    // from causing spurious pauses after reading has finished).
    if (!state.isActive && !state.isPaused) return;
    _currentSessionId++;
    await _ref.read(ttsProvider.notifier).pause();
    _clearUnitSpeechState();
    state = state.copyWith(isPaused: true);
    // Notification shows Play button + paused state.
    ttsAudioHandler.setPlaybackState(
      playing: false,
      paused: true,
      hasPrev: state.currentIndex > 0,
      hasNext: state.currentIndex < state.lines.length - 1,
    );
  }

  /// Resume reading from the current position.
  Future<void> resumeReading() async {
    if (!state.isPaused) return;
    state = state.copyWith(isPaused: false);

    _currentSessionId++;
    final sessionId = _currentSessionId;
    // Update notification to show playing state.
    ttsAudioHandler.setPlaybackState(
      playing: true,
      paused: false,
      hasPrev: state.currentIndex > 0,
      hasNext: state.currentIndex < state.lines.length - 1,
    );
    await _speakCurrent(sessionId, isResume: true);
  }

  /// Strip Pāli numbers up front so unit text matches what the engine
  /// actually speaks (its own stripping then no-ops) and word counts align
  /// for progress mapping. Translation numbers are spoken aloud, so those
  /// lines are untouched. Line order/ids are unchanged, so every consumer
  /// of `lines` keeps working.
  List<TtsLineItem> _stripPaliNumbers(List<TtsLineItem> lines) => [
    for (final l in lines)
      if (l.isPali)
        TtsLineItem(
          paraId: l.paraId,
          lineId: l.lineId,
          text: TtsNotifier.stripPaliNumbers(l.text),
          language: l.language,
          paliRoman: TtsNotifier.stripPaliNumbers(l.paliRoman ?? ''),
        )
      else
        l,
  ];

  /// Group [lines] into speakable units.
  ///
  /// Batching (one paragraph per utterance) needs progress callbacks to keep
  /// the line highlight moving inside a unit. The Apple native channel has
  /// no progress API, so there single-line units preserve today's per-line
  /// highlight instead of freezing it on the paragraph's first line.
  List<TtsSpeakUnit> _buildUnits(List<TtsLineItem> lines) {
    String textOf(TtsLineItem l) => l.text;
    int paraIdOf(TtsLineItem l) => l.paraId;
    int lineIdOf(TtsLineItem l) => l.lineId;
    String? languageOf(TtsLineItem l) => l.language;
    String? paliRomanOf(TtsLineItem l) => l.paliRoman;
    if (NativeSpeechService.isSupported) {
      return [
        for (var i = 0; i < lines.length; i++)
          if (lines[i].text.trim().isNotEmpty)
            singleLineUnit(
              line: lines[i],
              globalIndex: i,
              textOf: textOf,
              paraIdOf: paraIdOf,
              lineIdOf: lineIdOf,
              languageOf: languageOf,
              paliRomanOf: paliRomanOf,
            ),
      ];
    }
    return buildSpeakUnits(
      lines: lines,
      textOf: textOf,
      paraIdOf: paraIdOf,
      lineIdOf: lineIdOf,
      languageOf: languageOf,
      paliRomanOf: paliRomanOf,
    );
  }

  /// Progress inside the current unit: advance the line cursor when the
  /// offset crosses a line boundary (existing highlight/auto-scroll
  /// machinery follows `currentIndex`), and publish the line-local word
  /// index. Offsets arrive in unit-text space (the engine layer translates
  /// spoken-script offsets back); the word INDEX transfers across scripts.
  void _handleUnitProgress(
    int sessionId,
    int unitIndex,
    TtsSpeakUnit unit,
    int start,
    int end,
    String word,
  ) {
    if (!kTtsWordHighlightEnabled) return;
    if (sessionId != _currentSessionId) return;
    if (!state.isActive || state.isPaused) return;
    if (unitIndex != state.currentUnitIndex) return;
    if (word.trim().isEmpty) return;

    // Coarse progress events (one callback covering a large part of the
    // utterance — typical of streamed/network voices) carry no usable word
    // position: trusting their offsets pins the pill to the last word for
    // the whole utterance. Drop the word pill and keep the line underline.
    if (_isCoarseProgress(unit, start, end)) {
      final disp = word.length > 20 ? '${word.substring(0, 20)}…' : word;
      developer.log(
        '[TTS_WORD] unit=$unitIndex DROP coarse s=$start e=$end '
        'unitLen=${unit.text.length} word="$disp" (line-only highlight)',
        name: 'epitaka.tts',
      );
      final wordNotifier = _ref.read(ttsWordHighlightProvider.notifier);
      if (wordNotifier.state != null) wordNotifier.state = null;
      return;
    }

    final slot = findLineSlotAtOffset(unit, start);
    final range = unit.lineRanges[slot];
    final global = unit.lineIndices[slot];
    if (global != state.currentIndex) {
      state = state.copyWith(currentIndex: global);
      _scheduleListeningHistorySave();
      // No explicit scroll call: the reader_screen TTS listener follows
      // para/line changes (same-paragraph fine-scroll included).
    }
    final lineSub = unit.text.substring(range.start, range.end);
    final highlight = TtsWordHighlight(
      paraId: unit.paraId,
      lineId: range.lineId,
      isPali: unit.isPali,
      // Offset-based guess, then self-healing re-anchor on the reported
      // word text (some Indic voices segment words differently than
      // whitespace splitting — without this one odd callback desyncs the
      // rest of the unit).
      wordIndex: ttsReconcileWordIndex(
        lineText: lineSub,
        expectedIndex: ttsWordIndexAtOffset(lineSub, toLocal(range, start)),
        reportedWord: word,
        isPali: unit.isPali,
      ),
      lineText: lineSub,
    );
    final disp = word.length > 20 ? '${word.substring(0, 20)}…' : word;
    developer.log(
      '[TTS_WORD] unit=$unitIndex line=${range.lineId} s=$start e=$end '
      'wordIdx=${highlight.wordIndex} word="$disp"',
      name: 'epitaka.tts',
    );
    final wordNotifier = _ref.read(ttsWordHighlightProvider.notifier);
    if (wordNotifier.state != highlight) wordNotifier.state = highlight;
  }

  /// Whether a progress range is too coarse to locate a word: it spans a
  /// large fraction of the utterance, so the offset only says "somewhere
  /// in here" and trusting it would stick the pill on the trailing word.
  /// Only applies to long utterances: on a short line a single spoken
  /// word legitimately covers most of the text, and treating that as
  /// coarse would drop the pill exactly where it works best.
  bool _isCoarseProgress(TtsSpeakUnit unit, int start, int end) {
    final len = unit.text.length;
    if (len <= 60) return false;
    return (end - start) * 5 >= len * 2;
  }

  /// Completion futures per unit index. A unit already spoken or queued
  /// ahead has an entry; the loop awaits (never re-speaks) it. Pruned on
  /// advance, cleared on stop/pause/skip/finish.
  final Map<int, Future<void>> _unitFutures = {};

  /// End timestamp of the last completed unit — GAP telemetry (idle time
  /// before the next speak; near zero with prefetch on supported engines).
  DateTime? _lastUnitDoneAt;

  /// Consecutive units whose utterance never audibly played (engine error
  /// or implausibly fast completion). Reset on every session transition
  /// via [_clearUnitSpeechState]. At [_kMaxConsecutiveBadUnits] the loop
  /// aborts with an actionable notice instead of fast-skipping silently
  /// through the rest of the book.
  int _consecutiveBadUnits = 0;

  /// How many failed units in a row abort the session (see above).
  static const int _kMaxConsecutiveBadUnits = 4;

  /// A completion faster than this (for non-trivial text at normal speeds)
  /// means the utterance never played — killed or errored without audio.
  static const int _kInstantCompletionMs = 250;

  /// Drop all unit futures and word state. Called on every session
  /// transition (stop/pause/skip/finish/start): a completed future left in
  /// the map would make a later visit to that unit return instantly
  /// without speaking.
  void _clearUnitSpeechState() {
    _unitFutures.clear();
    _lastUnitDoneAt = null;
    _consecutiveBadUnits = 0;
    try {
      _ref.read(ttsWordHighlightProvider.notifier).state = null;
    } catch (_) {}
  }

  /// Speak the current unit and schedule the next.
  Future<void> _speakCurrent(int sessionId, {bool isResume = false}) async {
    if (sessionId != _currentSessionId ||
        state.currentUnitIndex >= state.units.length) {
      if (sessionId == _currentSessionId) {
        _finishReading();
      }
      return;
    }

    final unitIndex = state.currentUnitIndex;
    final unit = state.units[unitIndex];
    final ttsNotifier = _ref.read(ttsProvider.notifier);

    // Sync the line cursor to the unit's first line; progress callbacks
    // advance it from there. Stale word state is cleared per unit.
    if (state.currentIndex != unit.lineIndices.first) {
      state = state.copyWith(currentIndex: unit.lineIndices.first);
    }
    _ref.read(ttsWordHighlightProvider.notifier).state = null;

    developer.log(
      '[TTS_PIPE] _speakCurrent unit=$unitIndex/${state.units.length} '
      'paraId=${unit.paraId} lines=${unit.lineRanges.length} '
      'chars=${unit.text.length} isResume=$isResume',
      name: 'epitaka.tts',
    );

    if (unit.isEmpty) {
      _advanceToNext(sessionId);
      return;
    }

    final lastDone = _lastUnitDoneAt;
    if (lastDone != null) {
      developer.log(
        '[TTS_PIPE] GAP ${DateTime.now().difference(lastDone).inMilliseconds}ms '
        'before unit=$unitIndex',
        name: 'epitaka.tts',
      );
    }
    final speakStart = DateTime.now();
    // Pause used stop(); resume restarts the unit from its beginning —
    // identical to the old line-restart behavior — so both paths speak.
    // The wait is bounded per unit; a timeout aborts the engine (flush +
    // drain) and the loop skips ahead, so one stuck utterance can never
    // wedge the session.
    try {
      await _speakUnit(
        sessionId,
        unitIndex,
        unit,
      ).timeout(TtsNotifier.timeoutFor(unit.text));
    } on TimeoutException {
      developer.log(
        '[TTS_PIPE] unit=$unitIndex TIMEOUT after '
        '${TtsNotifier.timeoutFor(unit.text).inMilliseconds}ms — aborting',
        name: 'epitaka.tts',
      );
      await ttsNotifier.stop();
      _unitFutures.clear();
    } catch (_) {
      // Error speaking — continue to next unit
    }
    _lastUnitDoneAt = DateTime.now();
    final speakElapsed = DateTime.now().difference(speakStart).inMilliseconds;
    developer.log(
      '[TTS_PIPE] _speakCurrent unit=$unitIndex completed in ${speakElapsed}ms',
      name: 'epitaka.tts',
    );

    if (sessionId == _currentSessionId) {
      // Backstop against silent fast-skipping: when the engine keeps
      // failing utterances (error callbacks or completions so fast nothing
      // could have played), stop with an actionable notice instead of
      // racing through the rest of the book unheard.
      if (_noteUnitOutcomeAndShouldAbort(unit)) {
        await _abortFailedSession(sessionId, unit);
        return;
      }
      _advanceToNext(sessionId);
    }
  }

  /// Fold the just-finished [unit]'s engine outcome into the failure
  /// streak. Returns true when the streak reached
  /// [_kMaxConsecutiveBadUnits] and the session must abort.
  bool _noteUnitOutcomeAndShouldAbort(TtsSpeakUnit unit) {
    final outcome = _ref.read(ttsProvider.notifier).lastOutcome;
    final bad = _isFailedUnit(unit, outcome);
    _consecutiveBadUnits = bad ? _consecutiveBadUnits + 1 : 0;
    if (bad) {
      developer.log(
        '[TTS_PIPE] failed unit (streak=$_consecutiveBadUnits): '
        'errored=${outcome?.errored} elapsedMs=${outcome?.elapsedMs} '
        'chars=${unit.text.trim().length} isPali=${unit.isPali}',
        name: 'epitaka.tts',
      );
    }
    return _consecutiveBadUnits >= _kMaxConsecutiveBadUnits;
  }

  /// Whether [unit]'s utterance never audibly played: the engine reported
  /// an error, or it completed implausibly fast for non-trivial text at
  /// normal speeds (killed/stalled without audio). Very high user speeds
  /// are excluded — short utterances legitimately finish in milliseconds
  /// there.
  bool _isFailedUnit(
    TtsSpeakUnit unit,
    ({bool errored, int elapsedMs})? outcome,
  ) {
    if (outcome == null) return false;
    if (outcome.errored) return true;
    if (unit.text.trim().length > 20 &&
        outcome.elapsedMs < _kInstantCompletionMs) {
      final settings = _ref.read(settingsProvider);
      final speed = unit.isPali ? settings.ttsPaliSpeed : settings.ttsSpeed;
      if (speed <= 2.0) return true;
    }
    return false;
  }

  /// Abort a session whose engine keeps failing: tear down like
  /// [stopReading], then attach an actionable notice (set AFTER the stop,
  /// which clears notices) so the TTS controls dialog can tell the user
  /// what broke instead of leaving a dead session behind.
  Future<void> _abortFailedSession(int sessionId, TtsSpeakUnit unit) async {
    if (sessionId != _currentSessionId) return;
    developer.log(
      '[TTS_PIPE] aborting session after $_consecutiveBadUnits consecutive '
      'failed units at unit=${state.currentUnitIndex}',
      name: 'epitaka.tts',
    );
    await stopReading();
    final tts = _ref.read(ttsProvider.notifier);
    const msg = 'Read-aloud stopped: the system voice failed several lines '
        'in a row. Install the voice in System TTS settings (or pick '
        'another voice), then play again.';
    if (unit.isPali) {
      tts.paliFallbackNotice ??= msg;
    } else {
      tts.translationIssueNotice ??= msg;
    }
  }

  /// Completion future for [unitIndex]: speaks it now unless already spoken
  /// or queued ahead (prefetch), in which case the existing future is
  /// awaited instead of re-speaking.
  Future<void> _speakUnit(int sessionId, int unitIndex, TtsSpeakUnit unit) {
    final existing = _unitFutures[unitIndex];
    if (existing != null) return existing;
    final ttsNotifier = _ref.read(ttsProvider.notifier);
    final prefetch = kTtsPrefetchEnabled && ttsNotifier.supportsPrefetch;
    final future = ttsNotifier.speak(
      unit.text,
      language: unit.language,
      paliRoman: unit.paliRoman,
      watchdog: false,
      onProgress: kTtsWordHighlightEnabled
          ? (s, e, w) => _handleUnitProgress(sessionId, unitIndex, unit, s, e, w)
          : null,
      onStarted: prefetch ? () => _prefetchNext(sessionId, unitIndex) : null,
    );
    _unitFutures[unitIndex] = future;
    return future;
  }

  /// Queue the unit after [unitIndex] while it plays (fire-and-forget, never
  /// awaited here — the loop awaits it when it advances). The engine
  /// pre-loads the next voice during current speech, which is what removes
  /// the Pāli→translation switch delay. Only runs on queue-capable engines;
  /// elsewhere each unit speaks strictly sequentially as before.
  void _prefetchNext(int sessionId, int unitIndex) {
    if (!kTtsPrefetchEnabled) return;
    if (sessionId != _currentSessionId) return;
    if (!state.isActive || state.isPaused) return;
    final next = unitIndex + 1;
    if (next >= state.units.length) return;
    if (_unitFutures.containsKey(next)) return;
    final ttsNotifier = _ref.read(ttsProvider.notifier);
    if (!ttsNotifier.supportsPrefetch) return;
    final u = state.units[next];
    if (u.isEmpty) return;
    _unitFutures[next] = ttsNotifier.speak(
      u.text,
      language: u.language,
      paliRoman: u.paliRoman,
      flush: false,
      watchdog: false,
      onProgress: kTtsWordHighlightEnabled
          ? (s, e, w) => _handleUnitProgress(sessionId, next, u, s, e, w)
          : null,
      onStarted: () => _prefetchNext(sessionId, next),
    );
    // Drop references older than the playing unit (active awaits hold
    // their own references; the map just stops retaining them).
    _unitFutures.removeWhere((k, _) => k < unitIndex);
  }

  /// Skip forward one unit (next/forward button on lock screen). In batched
  /// modes a unit is a paragraph; in alternating voice mode it is one line.
  Future<void> skipForward() async {
    if (!state.isActive && !state.isPaused) return;
    if (state.units.isEmpty) return;
    _currentSessionId++;
    final sessionId = _currentSessionId;
    await _ref.read(ttsProvider.notifier).stop();
    final nextUnit = state.currentUnitIndex + 1;
    if (nextUnit < state.units.length) {
      _clearUnitSpeechState();
      state = state.copyWith(
        currentUnitIndex: nextUnit,
        currentIndex: state.units[nextUnit].lineIndices.first,
      );
      _scheduleListeningHistorySave();
      ttsAudioHandler.setPlaybackState(
        playing: true,
        paused: false,
        hasPrev: true,
        hasNext: nextUnit < state.units.length - 1,
      );
      _speakCurrent(sessionId);
    } else {
      _finishReading();
    }
  }

  /// Skip forward to the next paragraph.
  Future<void> skipForwardParagraph() async {
    if (!state.isActive && !state.isPaused) return;
    if (state.units.isEmpty) return;
    final currentUnit = state.units[state.currentUnitIndex];
    var nextUnit = state.currentUnitIndex + 1;
    while (nextUnit < state.units.length &&
        state.units[nextUnit].paraId == currentUnit.paraId) {
      nextUnit++;
    }
    if (nextUnit < state.units.length) {
      _currentSessionId++;
      final sessionId = _currentSessionId;
      await _ref.read(ttsProvider.notifier).stop();
      _clearUnitSpeechState();
      state = state.copyWith(
        currentUnitIndex: nextUnit,
        currentIndex: state.units[nextUnit].lineIndices.first,
      );
      _scheduleListeningHistorySave();
      ttsAudioHandler.setPlaybackState(
        playing: true,
        paused: false,
        hasPrev: true,
        hasNext: nextUnit < state.units.length - 1,
      );
      _speakCurrent(sessionId);
    } else {
      _finishReading();
    }
  }

  /// Skip backward one unit (previous/rewind button on lock screen).
  Future<void> skipBackward() async {
    if (!state.isActive && !state.isPaused) return;
    if (state.units.isEmpty) return;
    if (state.currentUnitIndex <= 0) return;
    _currentSessionId++;
    final sessionId = _currentSessionId;
    await _ref.read(ttsProvider.notifier).stop();
    final prevUnit = state.currentUnitIndex - 1;
    _clearUnitSpeechState();
    state = state.copyWith(
      currentUnitIndex: prevUnit,
      currentIndex: state.units[prevUnit].lineIndices.first,
    );
    _scheduleListeningHistorySave();
    ttsAudioHandler.setPlaybackState(
      playing: true,
      paused: false,
      hasPrev: prevUnit > 0,
      hasNext: prevUnit < state.units.length - 1,
    );
    _speakCurrent(sessionId);
  }

  void _advanceToNext(int sessionId) {
    if (sessionId != _currentSessionId) {
      developer.log(
        '[TTS_PIPE] _advanceToNext SKIP: sessionId=$sessionId != currentSessionId=$_currentSessionId',
        name: 'epitaka.tts',
      );
      return;
    }
    final nextUnit = state.currentUnitIndex + 1;
    developer.log(
      '[TTS_PIPE] _advanceToNext: $nextUnit/${state.units.length} (finished=$nextUnit >= ${state.units.length}) sessionId=$sessionId',
      name: 'epitaka.tts',
    );
    if (nextUnit >= state.units.length) {
      _finishReading();
    } else {
      // Drop futures older than the next unit (completed; the map must not
      // retain them, and the next unit's prefetched future — if any — stays
      // so the loop awaits it instead of re-speaking).
      _unitFutures.removeWhere((k, _) => k < nextUnit);
      state = state.copyWith(
        currentUnitIndex: nextUnit,
        currentIndex: state.units[nextUnit].lineIndices.first,
      );
      // Update notification prev/next buttons availability.
      ttsAudioHandler.setPlaybackState(
        playing: true,
        paused: false,
        hasPrev: true,
        hasNext: nextUnit < state.units.length - 1,
      );
      // Debounced listening-history position update.
      _scheduleListeningHistorySave();
      // Speak the next unit
      _speakCurrent(sessionId);
    }
  }

  /// Debounce a listening-history save for the current position.
  void _scheduleListeningHistorySave() {
    final s = state;
    final bookId = s.bookId;
    if (bookId == null || s.isEmpty) return;
    final paraId = s.currentParaId;
    if (paraId == null) return;
    if (_lastSavedListeningParaId == paraId) return;
    _lastSavedListeningParaId = paraId;

    _listeningSaveTimer?.cancel();
    _listeningSaveTimer = Timer(const Duration(seconds: 3), () {
      _saveListeningHistoryNow();
    });
  }

  /// Persist the current listening position to the app database.
  Future<void> _saveListeningHistoryNow() async {
    final s = state;
    final bookId = s.bookId;
    if (bookId == null || s.isEmpty) return;
    try {
      final db = await _ref.read(appDbProvider.future);
      await db.recordListening(
        bookId: bookId,
        bookName: _bookNameCache[bookId],
        paraId: s.currentParaId,
        lineId: s.currentLineId,
      );
      // Refresh the Listening-history UI (mirrors the reading-history flow).
      _ref.invalidate(listeningHistoryProvider);
    } catch (_) {
      // Silently fail — history is non-critical
    }
  }

  void _finishReading() {
    developer.log(
      '[TTS_LIFECYCLE] _finishReading() called: '
      'state was isActive=${state.isActive} '
      'lastIndex=${state.currentIndex}/${state.lines.length}',
      name: 'epitaka.tts',
    );
    // Save the final position before the state is reset below.
    _listeningSaveTimer?.cancel();
    _listeningSaveTimer = null;
    _saveListeningHistoryNow();
    _clearUnitSpeechState();
    state = const TtsReadingState();
    // Keep callbacks + service alive for the next session (see stopReading).
    ttsAudioHandler.dismiss();
  }

  /// Cancel the audio-becoming-noisy listener subscription and clear all
  /// handler callbacks so no stale callbacks fire after reading stops.
  void _cleanupHandlerCallbacks() {
    _noisySubscription?.cancel();
    _noisySubscription = null;
    _interruptionSubscription?.cancel();
    _interruptionSubscription = null;
    ttsAudioHandler.onPlayPressed = null;
    ttsAudioHandler.onPausePressed = null;
    ttsAudioHandler.onStopPressed = null;
    ttsAudioHandler.onSkipNextPressed = null;
    ttsAudioHandler.onSkipPreviousPressed = null;
    ttsAudioHandler.getIsPaused = null;
  }

  @override
  void dispose() {
    developer.log(
      '[TTS_LIFECYCLE] TtsReadingNotifier.dispose() called '
      'isActive=${state.isActive} isPaused=${state.isPaused} '
      'hasNoisySubscription=${_noisySubscription != null} '
      'hasBookNameCache=${_bookNameCache.isNotEmpty}',
      name: 'epitaka.tts',
    );
    _currentSessionId++;
    _noisySubscription?.cancel();
    _noisySubscription = null;
    _interruptionSubscription?.cancel();
    _interruptionSubscription = null;
    // Save the final listening position (best-effort, not awaited in dispose).
    _listeningSaveTimer?.cancel();
    _listeningSaveTimer = null;
    _saveListeningHistoryNow();
    // Stop the TTS engine and kill the AudioService background isolate so
    // the process can be terminated by the system.
    try {
      _ref.read(ttsProvider.notifier).stop();
    } catch (_) {}
    _clearUnitSpeechState();
    _cleanupHandlerCallbacks();
    try {
      ttsAudioHandler.dismiss();
    } catch (_) {}
    developer.log(
      '[TTS_LIFECYCLE] TtsReadingNotifier.dispose() completed',
      name: 'epitaka.tts',
    );
    super.dispose();
  }
}

/// Provider for line-by-line TTS reading state and control.
final ttsReadingProvider =
    StateNotifierProvider<TtsReadingNotifier, TtsReadingState>((ref) {
      return TtsReadingNotifier(ref);
    });
