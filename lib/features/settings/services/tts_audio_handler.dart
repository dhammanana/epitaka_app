import 'dart:developer' as developer;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

/// Global singleton that bridges Android MediaSession notification/lock-screen
/// controls with the app's TTS system.
///
/// [TtsNotifier] and [TtsReadingNotifier] reference this singleton directly
/// to broadcast playback state to the OS notification. The handler delegates
/// control actions (play/pause/stop/skip) back to the notifiers via callbacks.
///
/// Without this handler, Android apps lose their process priority when the
/// screen is off and are killed after ~60 seconds, stopping TTS. With it,
/// the Android foreground service keeps the process alive and the
/// notification gives the user persistent play/pause/stop controls.
///
/// ## Lifecycle
///
/// ```mermaid
/// sequenceDiagram
///   participant R as TtsReadingNotifier
///   participant H as TtsAudioHandler
///   participant N as Android notification
///   participant T as TtsNotifier
///   R->>H: setMediaItem(bookId, title)
///   R->>R: startReading()
///   R->>T: speak(text)
///   T->>H: setPlaybackState(playing=true)
///   H->>N: show notification → [⏮ ❚❚ ⏹ ⏭]
///   Note over N: User presses ❚❚
///   N->>H: pause()
///   H->>R: onPausePressed()
///   R->>T: pause()
///   T->>H: setPlaybackState(playing=false, paused=true)
///   Note over N: User presses ▶
///   N->>H: play()
///   H->>R: onPlayPressed()
///   R->>T: resume()
///   T->>H: setPlaybackState(playing=true)
///   Note over N: Reading finishes
///   R->>H: setPlaybackState(playing=false, processingState=completed)
///   H->>N: dismiss notification
/// ```
final TtsAudioHandler ttsAudioHandler = TtsAudioHandler();

/// Custom [BaseAudioHandler] that bridges Android MediaSession controls
/// to the app's TTS system without owning the TTS engine itself.
class TtsAudioHandler extends BaseAudioHandler {
  // ── Callbacks (registered by TtsReadingNotifier) ────────────────

  /// Called when the user taps Play in the notification or on lock screen.
  VoidCallback? onPlayPressed;

  /// Called when the user taps Pause.
  VoidCallback? onPausePressed;

  /// Called when the user taps Stop.
  VoidCallback? onStopPressed;

  /// Called when the user taps Skip-to-next (or double-taps headset button).
  VoidCallback? onSkipNextPressed;

  /// Called when the user taps Skip-to-previous (or triple-taps headset).
  VoidCallback? onSkipPreviousPressed;

  /// Returns `true` when TTS is currently paused, so that [play] can
  /// toggle between play and pause. Set by [TtsReadingNotifier] when a
  /// reading session starts.
  bool Function()? getIsPaused;

  // ── MediaSession method overrides ───────────────────────────────

  @override
  Future<void> play() async {
    developer.log(
      '[TTS_CTRL] play() called (getIsPaused=${getIsPaused?.call()})',
      name: 'epitaka.tts',
    );
    // Media button (wired headset / Bluetooth) sends a play/pause
    // toggle. Check the current state to decide the action:
    // - If paused → resume
    // - If playing → pause
    // - If stopped → no-op
    if (getIsPaused?.call() == true) {
      onPlayPressed?.call();
    } else {
      onPausePressed?.call();
    }
  }

  @override
  Future<void> pause() async {
    developer.log('[TTS_CTRL] pause() called', name: 'epitaka.tts');
    onPausePressed?.call();
  }

  @override
  Future<void> stop() async {
    developer.log('[TTS_CTRL] stop() called', name: 'epitaka.tts');
    onStopPressed?.call();
  }

  @override
  Future<void> skipToNext() async {
    developer.log('[TTS_CTRL] skipToNext() called', name: 'epitaka.tts');
    onSkipNextPressed?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    developer.log('[TTS_CTRL] skipToPrevious() called', name: 'epitaka.tts');
    onSkipPreviousPressed?.call();
  }

  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    final state = playbackState.hasValue ? playbackState.value : null;
    developer.log(
      '[TTS_CTRL] click() called button=$button '
      'playing=${state?.playing}',
      name: 'epitaka.tts',
    );
    // Call through to BaseAudioHandler which already implements the
    // correct toggle: if playing → pause, if paused → play.
    return super.click(button);
  }

  // ── State broadcasting helpers ──────────────────────────────────

  /// Sets the media-item metadata displayed in the notification (title,
  /// artist, artwork).
  void setMediaItem({
    required String id,
    required String title,
    String? artist,
    String? artUri,
  }) {
    mediaItem.add(MediaItem(
      id: id,
      title: title,
      artist: artist ?? 'ePitaka',
      artUri: artUri != null ? Uri.tryParse(artUri) : null,
    ));
  }

  /// Updates the playback-state shown in the notification (play/pause
  /// icon, which buttons are visible, whether the notification persists).
  ///
  /// When [playing] is `false` and [paused] is `false`, the processing
  /// state is set to `completed`, which causes the notification to fade
  /// away after a short delay. When [paused] is `true` the notification
  /// stays visible with a Play button.
  void setPlaybackState({
    required bool playing,
    required bool paused,
    bool hasPrev = false,
    bool hasNext = false,
    AudioProcessingState? processingState,
  }) {
    final procState = processingState ??
        (playing
            ? AudioProcessingState.ready
            : (paused ? AudioProcessingState.ready : AudioProcessingState.completed));
    developer.log(
      '[TTS_LIFECYCLE] setPlaybackState: '
      'playing=$playing paused=$paused procState=$procState '
      'hasPrev=$hasPrev hasNext=$hasNext',
      name: 'epitaka.tts',
    );
    playbackState.add(PlaybackState(
      playing: playing,
      processingState: procState,
      controls: [
        if (hasPrev) MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        if (hasNext) MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.play,
        MediaAction.pause,
        MediaAction.stop,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
    ));
  }

}
