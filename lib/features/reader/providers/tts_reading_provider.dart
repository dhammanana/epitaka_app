import 'dart:async';
import 'dart:developer' as developer;

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/providers/tts_provider.dart';
import '../../settings/services/tts_audio_handler.dart';

/// A single line item to be spoken by TTS.
class TtsLineItem {
  final int paraId;
  final int lineId;
  final String text;

  const TtsLineItem({
    required this.paraId,
    required this.lineId,
    required this.text,
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
  Future<dynamic>? _pendingSynth;
  int? _pendingSynthIndex;

  /// Subscription to Android's ACTION_AUDIO_BECOMING_NOISY broadcast
  /// (triggered when Bluetooth disconnects or the headphone jack is
  /// removed). Initialised when reading starts, cancelled on stop/finish.
  StreamSubscription<void>? _noisySubscription;

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
    _pendingSynth = null;
    _pendingSynthIndex = null;

    await _ref.read(ttsProvider.notifier).stop();

    if (lines.isEmpty) {
      state = const TtsReadingState();
      return;
    }

    state = TtsReadingState(
      bookId: bookId,
      lines: lines,
      currentIndex: startIndex,
      isActive: true,
    );

    // ── AudioService integration ───────────────────────────────────
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
    try {
      final session = await AudioSession.instance;
      _noisySubscription?.cancel();
      _noisySubscription = session.becomingNoisyEventStream.listen((_) {
        developer.log(
          '[TTS_BECOMING_NOISY] Audio route disconnected → pausing',
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
  Future<void> stopReading() async {
    _currentSessionId++;
    _pendingSynth = null;
    _pendingSynthIndex = null;
    await _ref.read(ttsProvider.notifier).stop();
    if (state.isActive || state.isPaused) {
      state = const TtsReadingState();
    }
    // Hide notification when reading stops.
    ttsAudioHandler.reset();
    _cleanupHandlerCallbacks();
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
        if (_pendingSynthIndex == index && _pendingSynth != null) {
          audio = await _pendingSynth;
        } else {
          audio = await ttsNotifier.synthesizePrepared(line.text);
        }
        _pendingSynth = null;
        _pendingSynthIndex = null;

        if (sessionId != _currentSessionId) return;

        // Start synthesizing the NEXT line now, while this one plays.
        _prefetchNext(sessionId, index);

        await ttsNotifier.playPrepared(audio);
      } else {
        await ttsNotifier.speak(line.text);
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

  /// Kick off synthesis of the next line in the background.
  void _prefetchNext(int sessionId, int currentIndex) {
    final nextIndex = currentIndex + 1;
    if (nextIndex >= state.lines.length) return;
    final nextLine = state.lines[nextIndex];
    if (nextLine.text.trim().isEmpty) return;

    final ttsNotifier = _ref.read(ttsProvider.notifier);
    _pendingSynthIndex = nextIndex;
    _pendingSynth = ttsNotifier.synthesizePrepared(nextLine.text).catchError((e) {
      if (sessionId == _currentSessionId) {
        _pendingSynthIndex = null;
        _pendingSynth = null;
      }
      throw e;
    });
  }

  /// Skip forward one line (next/forward button on lock screen).
  Future<void> skipForward() async {
    if (!state.isActive && !state.isPaused) return;
    _currentSessionId++;
    final sessionId = _currentSessionId;
    await _ref.read(ttsProvider.notifier).stop();
    final nextIndex = state.currentIndex + 1;
    if (nextIndex < state.lines.length) {
      state = state.copyWith(currentIndex: nextIndex);
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
    await _ref.read(ttsProvider.notifier).stop();
    state = state.copyWith(currentIndex: state.currentIndex - 1);
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
      // Speak the next line
      _speakCurrent(sessionId);
    }
  }

  void _finishReading() {
    state = const TtsReadingState();
    ttsAudioHandler.reset();
    _cleanupHandlerCallbacks();
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
    _currentSessionId++;
    _cleanupHandlerCallbacks();
    super.dispose();
  }
}

/// Provider for line-by-line TTS reading state and control.
final ttsReadingProvider =
    StateNotifierProvider<TtsReadingNotifier, TtsReadingState>((ref) {
  return TtsReadingNotifier(ref);
});
