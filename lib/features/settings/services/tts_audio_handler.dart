import 'dart:developer' as developer;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

import '../../../core/utils/platform_info.dart';

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

/// Whether [initAudioServiceOnce] has already succeeded.
bool _audioServiceInitialized = false;

/// In-flight init shared by concurrent callers so two overlapping calls
/// (e.g. cold-start init in `main()` + a TTS start a moment later) don't
/// run `AudioService.init()` twice — a second init re-registers the handler
/// and can make the plugin spin up its own FlutterEngine (a second Dart
/// isolate sharing one sqflite database).
Future<bool>? _audioServiceInitFuture;

/// Initialise `audio_service` exactly once per process; returns whether it is
/// ready to use.
///
/// `AudioService.init()` must only run once. Calling it a second time
/// re-registers the handler, and an init that runs before the main engine
/// exists makes the plugin create its own `FlutterEngine` — a second engine is
/// a second Dart isolate in the same process, and two isolates sharing one
/// sqflite database is the classic source of
/// `DatabaseException(database is locked (code 5 SQLITE_BUSY)) sql
/// 'BEGIN EXCLUSIVE'` (the shape of the crash we saw reported from
/// flutter_cache_manager's on-demand cache database).
///
/// `main()` calls this before `runApp()` (the pattern from the
/// `audio_service` README) so the notification exists before any reading
/// session calls `setMediaItem()`. The post-frame call in
/// `AudioServiceInitializer` and the call at the top of
/// `TtsReadingNotifier.startReading()` are fallbacks for a first attempt
/// that failed (some OEMs refuse the foreground service at cold start), and
/// they become no-ops once an attempt has succeeded. Concurrent callers
/// share one in-flight init instead of racing a second one.
Future<bool> initAudioServiceOnce() {
  if (!PlatformInfo.isTtsSupported) return Future.value(false);
  if (_audioServiceInitialized) return Future.value(true);
  return _audioServiceInitFuture ??= _doInitAudioService();
}

Future<bool> _doInitAudioService() async {
  try {
    await AudioService.init(
      builder: () => ttsAudioHandler,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.dn.epitaka.tts',
        androidNotificationChannelName: 'TTS Playback',
        // NOTE: `androidNotificationOngoing` must stay false here:
        // audio_service asserts `!ongoing || stopForegroundOnPause`, so
        // ongoing:true cannot combine with the `false` below. While the
        // service is in the foreground the system blocks dismissal of its
        // notification anyway, so nothing is lost during playback.
        androidNotificationOngoing: false,
        // MUST stay false for a TTS app. The reading loop broadcasts
        // stopped/completed between every spoken line, and the user pauses
        // constantly. With `true`, each of those moments drops the service
        // out of the foreground, and re-entering it (next line, notification
        // Play, headset button, end-of-call auto-resume) calls
        // startForegroundService() — which throws
        // ForegroundServiceStartNotAllowedException on Android 12+ whenever
        // the app happens to be backgrounded (screen off is the normal TTS
        // case). The player then never comes back and the OS kills the
        // process minutes later. With `false` the service rides through
        // pauses and line gaps in the foreground, so resume-from-background
        // never needs a restart. (This is also the workaround the
        // audio_service maintainer recommends for that exception.)
        androidStopForegroundOnPause: false,
        androidNotificationIcon: 'mipmap/ic_launcher',
      ),
    );
    _audioServiceInitialized = true;
    developer.log(
      '[AUDIO_SVC] AudioService.init() succeeded',
      name: 'epitaka.tts',
    );
    return true;
  } catch (e) {
    developer.log(
      '[AUDIO_SVC] AudioService.init() failed: $e — TTS will run without '
      'a notification and may be killed in background; will retry on next '
      'reading start',
      name: 'epitaka.tts',
    );
    // Clear the shared future so a later call (next reading start, when the
    // user is interacting and the app is foreground) retries instead of
    // caching the failure forever.
    _audioServiceInitFuture = null;
    return false;
  }
}

/// Custom [BaseAudioHandler] that bridges Android MediaSession controls
/// to the app's TTS system without owning the TTS engine itself.
///
/// Mirrors anx-reader's `TtsHandler`: the handler publishes a queue +
/// media item (with `duration: null` so the system renders no progress bar)
/// plus `queueIndex`/`updatePosition`, which is what makes the
/// notification / lock-screen / control-center metadata actually appear
/// on Samsung/Pixel devices. Without the queue, `playbackState` alone
/// often shows nothing.
class TtsAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
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
    // Ensure notification is dismissed even if callback doesn't do it
    dismiss();
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
  /// artist, artwork). Also publishes the queue so the OS control center
  /// picks up the metadata (anx-reader does `queue.add([item])` +
  /// `mediaItem.add(item)` together — both are required on some OEMs).
  void setMediaItem({
    required String id,
    required String title,
    String? artist,
    String? artUri,
  }) {
    final item = MediaItem(
      id: id,
      title: title,
      album: 'ePitaka',
      artist: artist ?? 'ePitaka',
      // Null duration = unknown/live content: the system renders no
      // progress bar (TTS has no fixed duration). (Older code passed -1ms
      // here; null is the supported signal on current audio_service and
      // the native side simply omits the duration key.)
      duration: null,
      artUri: artUri != null ? Uri.tryParse(artUri) : null,
    );
    queue.add([item]);
    mediaItem.add(item);
  }

  /// Dismiss the notification WITHOUT killing the audio service.
  ///
  /// Lifecycle rule: `AudioService` is init-once per process (see
  /// `AudioServiceInitializer`). Never broadcast `processingState: idle` —
  /// `idle` shuts the service down permanently and later sessions lose
  /// their notification with no way to restart it (`_cacheManager == null`
  /// on re-init). `completed` fades the notification away while keeping
  /// the service reusable for the next session.
  void dismiss() {
    developer.log(
      '[TTS_CTRL] dismiss() called — clearing queue and setting playbackState to completed',
      name: 'epitaka.tts',
    );
    // Clear the queue so the notification is fully dismissed
    queue.add([]);
    mediaItem.add(null);
    setPlaybackState(playing: false, paused: false);
  }

  /// Last broadcast signature, used to skip no-op rebroadcasts. The reading
  /// loop calls [setPlaybackState] before/after every spoken line, and
  /// without this each line would rebuild the Android notification even
  /// when nothing visible changed.
  String _lastBroadcast = '';

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
    final procState =
        processingState ??
        (playing
            ? AudioProcessingState.ready
            : (paused
                  ? AudioProcessingState.ready
                  : AudioProcessingState.completed));
    final signature =
        '$playing|$paused|$procState|$hasPrev|$hasNext';
    if (signature == _lastBroadcast) return;
    _lastBroadcast = signature;
    developer.log(
      '[TTS_LIFECYCLE] setPlaybackState: '
      'playing=$playing paused=$paused procState=$procState '
      'hasPrev=$hasPrev hasNext=$hasNext',
      name: 'epitaka.tts',
    );
    playbackState.add(
      PlaybackState(
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
        queueIndex: queue.value.isNotEmpty ? 0 : null,
        updatePosition: Duration.zero,
        bufferedPosition: Duration.zero,
      ),
    );
  }
}
