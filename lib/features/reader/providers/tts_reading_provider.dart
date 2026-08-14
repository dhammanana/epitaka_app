import 'dart:async';
import 'dart:developer' as developer;

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_db_provider.dart';
import '../../settings/providers/tts_provider.dart';
import '../../settings/services/tts_audio_handler.dart';

/// Bounded FIFO of pre-synthesized audio for upcoming TTS lines.
///
/// Neural synthesis (Supertonic) can be slower than real-time playback at
/// high speeds: prefetching only the single next line leaves an audible gap
/// whenever the current line finishes before the next one is ready. This
/// queue keeps several upcoming lines synthesized ahead of time so playback
/// never has to wait on synthesis.
///
/// Entries are tagged with the reading-session id that created them, so a
/// stale entry can never be reused after skip/stop/start (which bump the
/// session id). A failed prefetch resolves to [failed]; callers fall back to
/// on-demand synthesis instead of skipping the line.
class PreparedAudioQueue {
  PreparedAudioQueue({this.ahead = 3});

  /// How many upcoming lines to keep synthesized ahead of the current one.
  final int ahead;

  /// Sentinel result of a prefetch that failed. Compare with `identical` or
  /// `==` against awaited audio to detect a failed prefetch.
  static const Object failed = _PrefetchFailure();

  final List<_PreparedLine> _entries = [];

  /// Whether [index] (for [sessionId]) is already prepared or in flight.
  bool contains(int sessionId, int index) => _entries.any(
    (e) => e.sessionId == sessionId && e.index == index,
  );

  /// Take the prepared future for [index] (for [sessionId]) if present,
  /// removing it from the queue. Returns null when not prepared.
  Future<dynamic>? take(int sessionId, int index) {
    final i = _entries.indexWhere(
      (e) => e.sessionId == sessionId && e.index == index,
    );
    if (i == -1) return null;
    return _entries.removeAt(i).future;
  }

  /// Drop entries that were consumed (index <= [currentIndex]) or belong to
  /// another session, then enqueue synthesis for the next [ahead] non-empty
  /// lines via [synthesize].
  void ensure(
    int sessionId,
    int currentIndex,
    List<TtsLineItem> lines,
    Future<dynamic> Function(TtsLineItem line) synthesize,
  ) {
    _entries.removeWhere(
      (e) => e.sessionId != sessionId || e.index <= currentIndex,
    );
    for (var i = 1; i <= ahead; i++) {
      final idx = currentIndex + i;
      if (idx >= lines.length) break;
      if (contains(sessionId, idx)) continue;
      final line = lines[idx];
      if (line.text.trim().isEmpty) continue;
      _entries.add(
        _PreparedLine(sessionId, idx, _prepare(idx, line, synthesize)),
      );
    }
  }

  /// Drop every entry (session change / stop).
  void clear() => _entries.clear();

  /// Number of entries currently buffered.
  int get length => _entries.length;

  /// Synthesize [line] guarding both synchronous throws and failed
  /// futures, resolving to [failed] on error so the caller falls back to
  /// on-demand synthesis instead of skipping the line.
  ///
  /// Implemented as a real `async` function (not Future.sync + catchError)
  /// so the returned future is always typed `Future<dynamic>` — catchError
  /// on a passthrough `Future<Never>` rejects the [failed] sentinel at
  /// runtime.
  static Future<dynamic> _prepare(
    int idx,
    TtsLineItem line,
    Future<dynamic> Function(TtsLineItem line) synthesize,
  ) async {
    try {
      return await synthesize(line);
    } catch (e) {
      developer.log(
        '[TTS_PIPE] prefetch line $idx failed: $e',
        name: 'epitaka.tts',
      );
      return failed;
    }
  }
}

class _PreparedLine {
  _PreparedLine(this.sessionId, this.index, this.future);

  final int sessionId;
  final int index;
  final Future<dynamic> future;
}

class _PrefetchFailure {
  const _PrefetchFailure();
}

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
}

/// State for line-by-line TTS reading.
class TtsReadingState {
  final String? bookId;
  final List<TtsLineItem> lines;
  final int currentIndex;
  final bool isActive;
  final bool isPaused;

  const TtsReadingState({
    this.bookId,
    this.lines = const [],
    this.currentIndex = 0,
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

  /// Progress: 0.0 to 1.0
  double get progress =>
      lines.isEmpty ? 0.0 : (currentIndex + 1) / lines.length;

  TtsReadingState copyWith({
    String? bookId,
    List<TtsLineItem>? lines,
    int? currentIndex,
    bool? isActive,
    bool? isPaused,
  }) {
    return TtsReadingState(
      bookId: bookId ?? this.bookId,
      lines: lines ?? this.lines,
      currentIndex: currentIndex ?? this.currentIndex,
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

  /// Buffer of pre-synthesized audio for upcoming lines (engines that
  /// support look-ahead, i.e. Supertonic). Kept ahead of the current line
  /// so high-speed playback never waits on synthesis.
  final PreparedAudioQueue _prepared = PreparedAudioQueue();

  /// Subscription to Android's ACTION_AUDIO_BECOMING_NOISY broadcast
  /// (triggered when Bluetooth disconnects or the headphone jack is
  /// removed). Initialised when reading starts, cancelled on stop/finish.
  StreamSubscription<void>? _noisySubscription;

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
    _prepared.clear();

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

    state = TtsReadingState(
      bookId: bookId,
      lines: lines,
      currentIndex: startIndex,
      isActive: true,
    );

    // Record the book in the listening history right away, so opening the
    // Listening history tab always shows what was played.
    _saveListeningHistoryNow();

    // ── AudioService integration ───────────────────────────────────
    // NOTE: AudioService.init() is intentionally NOT called here.
    // It was already initialized at app startup by [AudioServiceInitializer]
    // in app.dart. Calling init() again causes an assertion error:
    //   '_cacheManager == null': is not true.
    // The ttsAudioHandler singleton registered during that init is still
    // active, so setMediaItem(), setPlaybackState(), and notification
    // controls all work without re-initializing.

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
    _prepared.clear();
    // Save the final position before the state is reset below.
    _listeningSaveTimer?.cancel();
    _listeningSaveTimer = null;
    await _saveListeningHistoryNow();
    await _ref.read(ttsProvider.notifier).stop();
    state = const TtsReadingState();
    _cleanupHandlerCallbacks();
    // Stop the AudioService foreground service by transitioning to 'idle'
    // state. When processingState becomes 'idle', audio_service internally
    // calls AudioService._stop() which shuts down the Android background
    // service, allowing the process to be killed.
    //
    // NOTE: AudioService.stop() (deprecated) does NOT actually stop
    // the service — it only calls through the handler chain to
    // onStopPressed which we already nulled above.
    //
    // Trade-off: Once the service is stopped ('idle'), showing the
    // notification again requires restarting the service. If the platform
    // can auto-restart it via the method channel, subsequent TTS sessions
    // will still show a notification. Otherwise they won't (TTS audio
    // works independently via flutter_tts either way).
    developer.log(
      '[TTS_LIFECYCLE] stopReading: setting state to idle to trigger service stop...',
      name: 'epitaka.tts',
    );
    ttsAudioHandler.setPlaybackState(
      playing: false,
      paused: false,
      hasPrev: false,
      hasNext: false,
      processingState: AudioProcessingState.idle,
    );
  }

  /// Pause reading.
  Future<void> pauseReading() async {
    // Guard: no-op if reading is not active (prevents stale callbacks
    // from causing spurious pauses after reading has finished).
    if (!state.isActive && !state.isPaused) return;
    _currentSessionId++;
    await _ref.read(ttsProvider.notifier).pause();
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

  /// Speak the current line and schedule the next.
  Future<void> _speakCurrent(int sessionId, {bool isResume = false}) async {
    if (sessionId != _currentSessionId || state.currentIndex >= state.lines.length) {
      if (sessionId == _currentSessionId) {
        _finishReading();
      }
      return;
    }

    final index = state.currentIndex;
    final line = state.lines[index];
    final ttsNotifier = _ref.read(ttsProvider.notifier);

    developer.log(
      '[TTS_PIPE] _speakCurrent line=$index/${state.lines.length} '
      'paraId=${line.paraId} lineId=${line.lineId} isResume=$isResume',
      name: 'epitaka.tts',
    );

    if (line.text.trim().isEmpty) {
      developer.log('[TTS_PIPE] line $index is empty, skipping', name: 'epitaka.tts');
      _advanceToNext(sessionId);
      return;
    }

    final speakStart = DateTime.now();
    // Speak or resume the current line and await completion
    try {
      if (isResume) {
        await ttsNotifier.resume();
      } else if (ttsNotifier.supportsPrefetch) {
        dynamic audio;
        final prepared = _prepared.take(sessionId, index);
        if (prepared != null) {
          audio = await prepared;
          if (audio == PreparedAudioQueue.failed) {
            // The look-ahead synthesis failed earlier — synthesize now
            // instead of skipping the line.
            audio = await ttsNotifier.synthesizePrepared(
              line.text,
              language: line.language,
              paliRoman: line.paliRoman,
            );
          }
        } else {
          audio = await ttsNotifier.synthesizePrepared(
            line.text,
            language: line.language,
            paliRoman: line.paliRoman,
          );
        }

        if (sessionId != _currentSessionId) return;

        // Keep the buffer full: synthesize the next several lines while
        // this one plays (replaces the old single-line look-ahead).
        _prepared.ensure(
          sessionId,
          index,
          state.lines,
          (nextLine) => ttsNotifier.synthesizePrepared(
            nextLine.text,
            language: nextLine.language,
            paliRoman: nextLine.paliRoman,
          ),
        );

        await ttsNotifier.playPrepared(audio);
      } else {
        await ttsNotifier.speak(
          line.text,
          language: line.language,
          paliRoman: line.paliRoman,
        );
      }
    } catch (_) {
      // Error speaking — continue to next line
    }
    final speakElapsed = DateTime.now().difference(speakStart).inMilliseconds;
    developer.log(
      '[TTS_PIPE] _speakCurrent line=$index completed in ${speakElapsed}ms',
      name: 'epitaka.tts',
    );

    if (sessionId == _currentSessionId) {
      _advanceToNext(sessionId);
    }
  }

  /// Skip forward one line (next/forward button on lock screen).
  Future<void> skipForward() async {
    if (!state.isActive && !state.isPaused) return;
    _currentSessionId++;
    final sessionId = _currentSessionId;
    _prepared.clear();
    await _ref.read(ttsProvider.notifier).stop();
    final nextIndex = state.currentIndex + 1;
    if (nextIndex < state.lines.length) {
      state = state.copyWith(currentIndex: nextIndex);
      _scheduleListeningHistorySave();
      ttsAudioHandler.setPlaybackState(
        playing: true,
        paused: false,
        hasPrev: true,
        hasNext: nextIndex < state.lines.length - 1,
      );
      _speakCurrent(sessionId);
    } else {
      _finishReading();
    }
  }

  /// Skip backward one line (previous/rewind button on lock screen).
  Future<void> skipBackward() async {
    if (!state.isActive && !state.isPaused) return;
    if (state.currentIndex <= 0) return;
    _currentSessionId++;
    final sessionId = _currentSessionId;
    _prepared.clear();
    await _ref.read(ttsProvider.notifier).stop();
    state = state.copyWith(currentIndex: state.currentIndex - 1);
    _scheduleListeningHistorySave();
    ttsAudioHandler.setPlaybackState(
      playing: true,
      paused: false,
      hasPrev: state.currentIndex > 0,
      hasNext: state.currentIndex < state.lines.length - 1,
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
    final nextIndex = state.currentIndex + 1;
    developer.log(
      '[TTS_PIPE] _advanceToNext: $nextIndex/${state.lines.length} (finished=$nextIndex >= ${state.lines.length}) sessionId=$sessionId',
      name: 'epitaka.tts',
    );
    if (nextIndex >= state.lines.length) {
      _finishReading();
    } else {
      state = state.copyWith(currentIndex: nextIndex);
      // Update notification prev/next buttons availability.
      ttsAudioHandler.setPlaybackState(
        playing: true,
        paused: false,
        hasPrev: true,
        hasNext: nextIndex < state.lines.length - 1,
      );
      // Debounced listening-history position update.
      _scheduleListeningHistorySave();
      // Speak the next line
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
    state = const TtsReadingState();
    _cleanupHandlerCallbacks();
    // Same as stopReading(): use 'idle' state to trigger internal service stop.
    developer.log(
      '[TTS_LIFECYCLE] _finishReading: setting state to idle to trigger service stop...',
      name: 'epitaka.tts',
    );
    ttsAudioHandler.setPlaybackState(
      playing: false,
      paused: false,
      hasPrev: false,
      hasNext: false,
      processingState: AudioProcessingState.idle,
    );
  }

  /// Cancel the audio-becoming-noisy listener subscription and clear all
  /// handler callbacks so no stale callbacks fire after reading stops.
  void _cleanupHandlerCallbacks() {
    _noisySubscription?.cancel();
    _noisySubscription = null;
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
      'preparedLines=${_prepared.length} '
      'hasBookNameCache=${_bookNameCache.isNotEmpty}',
      name: 'epitaka.tts',
    );
    _currentSessionId++;
    _prepared.clear();
    _noisySubscription?.cancel();
    _noisySubscription = null;
    // Save the final listening position (best-effort, not awaited in dispose).
    _listeningSaveTimer?.cancel();
    _listeningSaveTimer = null;
    _saveListeningHistoryNow();
    // Stop the TTS engine and kill the AudioService background isolate so
    // the process can be terminated by the system.
    try {
      _ref.read(ttsProvider.notifier).stop();
    } catch (_) {}
    _cleanupHandlerCallbacks();
    // Same as stopReading / _finishReading: trigger internal service stop via idle.
    developer.log(
      '[TTS_LIFECYCLE] dispose: setting state to idle to trigger service stop...',
      name: 'epitaka.tts',
    );
    ttsAudioHandler.setPlaybackState(
      playing: false,
      paused: false,
      hasPrev: false,
      hasNext: false,
      processingState: AudioProcessingState.idle,
    );
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
