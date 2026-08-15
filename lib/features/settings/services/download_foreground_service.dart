import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Android foreground service that keeps translation downloads running
/// when the app is backgrounded and shows the ongoing status-bar
/// notification.
///
/// The service itself does no work — the actual download runs in the main
/// isolate ([TranslationDownloadNotifier]'s plain `http` stream). Starting
/// the foreground service keeps the app *process* alive (with a wake lock
/// and Wi-Fi lock) so that stream keeps flowing while the user is in
/// another app, and gives the user a visible, ongoing notification with
/// progress.
///
/// Required platform setup (Android):
///   * `<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>`
///   * `<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC"/>`
///   * `<service android:name="com.pravera.flutter_foreground_task.service.ForegroundService"
///     android:foregroundServiceType="dataSync" android:exported="false"/>`
///
/// Android 13+ also requires the runtime `POST_NOTIFICATIONS` permission
/// ([ensureNotificationPermission]) — without it the service can't show
/// its notification and the OS may refuse to keep it visible.
///
/// All calls are Android-only, wrapped so a plugin/platform failure can
/// NEVER crash a download: if the service can't start, the app simply
/// falls back to the (foreground-only) `flutter_local_notifications`
/// progress shown by [DownloadNotificationService].
class DownloadForegroundService {
  DownloadForegroundService._();

  static final DownloadForegroundService instance =
      DownloadForegroundService._();

  /// Unique id for the foreground-service notification.
  static const int _serviceId = 2331;

  bool _initialized = false;
  bool _permissionRequested = false;

  /// Request the Android 13+ `POST_NOTIFICATIONS` runtime permission.
  /// Returns whether notifications are (or were already) allowed. No-op on
  /// other platforms. Only asks once per session to avoid nagging.
  Future<bool> ensureNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final status = await FlutterForegroundTask.checkNotificationPermission();
      if (status == NotificationPermission.granted) return true;
      if (_permissionRequested) return false;
      _permissionRequested = true;
      final result =
          await FlutterForegroundTask.requestNotificationPermission();
      return result == NotificationPermission.granted;
    } catch (e) {
      developer.log(
        '[DL_FGS] notification permission check/request failed: $e',
        name: 'epitaka.download',
      );
      return false;
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'epitaka_downloads',
        channelName: 'Downloads',
        channelDescription: 'Translation database download progress',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // The download runs in the main isolate; the task handler has
        // nothing to repeat.
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        // Keep the CPU + Wi-Fi awake so the HTTP stream isn't stalled by
        // Doze while the user is in another app.
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _initialized = true;
  }

  /// Start (or update) the ongoing download notification. Safe to call
  /// repeatedly — when the service is already running it just updates the
  /// notification text.
  ///
  /// Returns whether the foreground-service notification is active; the
  /// caller should fall back to a plain local notification when false.
  Future<bool> showDownload({
    required String title,
    String text = '',
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      await _ensureInitialized();
      // Ask for POST_NOTIFICATIONS before starting the service — on
      // Android 13+ the service notification is hidden without it.
      await ensureNotificationPermission();
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
        );
        return true;
      }
      final result = await FlutterForegroundTask.startService(
        serviceId: _serviceId,
        serviceTypes: const [ForegroundServiceTypes.dataSync],
        notificationTitle: title,
        notificationText: text,
        notificationInitialRoute: '/',
        callback: downloadTaskCallback,
      );
      if (result is ServiceRequestFailure) {
        developer.log(
          '[DL_FGS] startService failed: ${result.error}',
          name: 'epitaka.download',
        );
        return false;
      }
      return true;
    } catch (e) {
      developer.log(
        '[DL_FGS] start failed: $e',
        name: 'epitaka.download',
      );
      return false;
    }
  }

  /// Update the ongoing notification's progress text. No-op when the
  /// service isn't running (e.g. it failed to start).
  Future<void> updateDownload({
    required String title,
    required String text,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      if (!await FlutterForegroundTask.isRunningService) return;
      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );
    } catch (e) {
      developer.log(
        '[DL_FGS] update failed: $e',
        name: 'epitaka.download',
      );
    }
  }

  /// Stop the foreground service (removes the ongoing notification).
  Future<void> hideDownload() async {
    if (!Platform.isAndroid) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (e) {
      developer.log(
        '[DL_FGS] stop failed: $e',
        name: 'epitaka.download',
      );
    }
  }
}

/// Top-level entry point required by the plugin. The service keeps the
/// process alive; the handler itself does nothing (the download runs in the
/// main isolate), but it must be a top-level/static function.
@pragma('vm:entry-point')
void downloadTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_DownloadTaskHandler());
}

class _DownloadTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}
