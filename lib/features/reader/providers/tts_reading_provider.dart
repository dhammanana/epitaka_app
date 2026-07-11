import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/providers/tts_provider.dart';

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

    _ref.read(ttsProvider.notifier).stop();

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

    await _speakCurrent(sessionId);
  }

  /// Stop reading and reset state.
  void stopReading() {
    _currentSessionId++;
    _pendingSynth = null;
    _pendingSynthIndex = null;
    _ref.read(ttsProvider.notifier).stop();
    if (state.isActive || state.isPaused) {
      state = const TtsReadingState();
    }
  }

  /// Pause reading.
  void pauseReading() {
    _currentSessionId++;
    _ref.read(ttsProvider.notifier).pause();
    state = state.copyWith(isPaused: true);
  }

  /// Resume reading from the current position.
  Future<void> resumeReading() async {
    if (!state.isPaused) return;
    state = state.copyWith(isPaused: false);

    _currentSessionId++;
    final sessionId = _currentSessionId;
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
      // Speak the next line
      _speakCurrent(sessionId);
    }
  }

  void _finishReading() {
    state = const TtsReadingState();
  }

  @override
  void dispose() {
    _currentSessionId++;
    super.dispose();
  }
}

/// Provider for line-by-line TTS reading state and control.
final ttsReadingProvider =
    StateNotifierProvider<TtsReadingNotifier, TtsReadingState>((ref) {
  return TtsReadingNotifier(ref);
});
