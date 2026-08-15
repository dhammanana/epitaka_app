import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';

/// Android foreground service that keeps long-running jobs alive when the
/// app is backgrounded and shows an ongoing status-bar notification.
///
/// Two kinds of jobs share this one service (the OS allows a single
/// foreground service per app, so the service is ref-counted per owner):
///   * translation database downloads ([DownloadForegroundService.instance]),
///   * the on-device Translation Builder run (the runner starts the service
///     when a run begins and stops it when the run finishes).
///
/// The service itself does no work — the actual job (download stream or AI
/// translation loop) runs in the main isolate. Starting the foreground
/// service keeps the app *process* alive (with a wake lock and Wi-Fi lock)
/// so the job keeps flowing while the user is in another app, and gives the
/// user a visible, ongoing notification with progress.
///
/// Required platform setup (Android):
///   * `<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>`
///   * `<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC"/>`
///   * `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>`
///   * `<service android:name="com.pravera.flutter_foreground_task.service.ForegroundService"
///     android:foregroundServiceType="dataSync" android:exported="false"/>`
///
/// On Android 13+ the service notification is HIDDEN unless the runtime
/// `POST_NOTIFICATIONS` permission is granted, so every owner must request it
/// (see [ensureNotificationPermission]) BEFORE starting the service. If the
/// user permanently denies it, we tell the caller to guide the user to the
/// app's notification settings instead of silently starting an invisible
/// service.
///
/// All calls are Android-only, wrapped so a plugin/platform failure can
/// NEVER crash a job: if the service can't start, the caller falls back to a
/// plain (foreground-only) `flutter_local_notifications` notification via
/// [DownloadNotificationService].
class DownloadForegroundService {
  DownloadForegroundService._();

  static final DownloadForegroundService instance =
      DownloadForegroundService._();

  /// Unique id for the foreground-service notification.
  static const int _serviceId = 2331;

  bool _initialized = false;

  /// How many download jobs are currently holding the service open.
  int _downloadRefCount = 0;

  /// How many translation-builder runs are currently holding the service.
  int _translatorRefCount = 0;

  /// Request the Android 13+ `POST_NOTIFICATIONS` runtime permission.
  ///
  /// Returns one of:
  ///   * [NotificationPermissionState.granted] — notifications are allowed;
  ///   * [NotificationPermissionState.denied] — the user denied the dialog
  ///     (can ask again later);
  ///   * [NotificationPermissionState.permanentlyDenied] — the user checked
  ///     "don't ask again"; the caller should open app settings.
  ///
  /// No-op (returns granted) on other platforms and on Android < 13, where
  /// no runtime permission exists.
  Future<NotificationPermissionState> ensureNotificationPermission() async {
    if (!Platform.isAndroid) return NotificationPermissionState.granted;
    try {
      final status = await Permission.notification.status;
      if (status.isGranted || status.isLimited) {
        return NotificationPermissionState.granted;
      }
      if (status.isPermanentlyDenied) {
        return NotificationPermissionState.permanentlyDenied;
      }
      // Not yet decided — ask. `request()` on Android 13+ shows the system
      // dialog; on older Android it resolves immediately as granted.
      final result = await Permission.notification.request();
      if (result.isGranted || result.isLimited) {
        return NotificationPermissionState.granted;
      }
      if (result.isPermanentlyDenied) {
        return NotificationPermissionState.permanentlyDenied;
      }
      return NotificationPermissionState.denied;
    } catch (e) {
      developer.log(
        '[DL_FGS] notification permission check/request failed: $e',
        name: 'epitaka.download',
      );
      return NotificationPermissionState.denied;
    }
  }

  /// Open the app's notification settings page (used when the user has
  /// permanently denied `POST_NOTIFICATIONS`). Android-only.
  Future<void> openNotificationSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await openAppSettings();
    } catch (e) {
      developer.log(
        '[DL_FGS] openAppSettings failed: $e',
        name: 'epitaka.download',
      );
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'epitaka_downloads',
        channelName: 'ePitaka tasks',
        channelDescription: 'Translation and download progress',
        // DEFAULT (not LOW): the notification must actually appear in the
        // status bar and shade — LOW is silent and often hidden by OEMs,
        // which is why the progress notification "never showed".
        channelImportance: NotificationChannelImportance.DEFAULT,
        priority: NotificationPriority.DEFAULT,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // The job runs in the main isolate; the task handler has nothing to
        // repeat.
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        // Keep the CPU + Wi-Fi awake so the HTTP stream / AI calls aren't
        // stalled by Doze while the user is in another app.
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _initialized = true;
  }

  /// Shared start-or-update: initialise the plugin, request notification
  /// permission, then start the service (or update its text when already
  /// running). Returns whether the service notification is active.
  Future<bool> _startOrUpdate({
    required String title,
    required String text,
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

  /// Stop the service once no owner needs it any more.
  Future<void> _stopWhenIdle() async {
    if (_downloadRefCount <= 0 && _translatorRefCount <= 0) {
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

  // ── Download owner ──────────────────────────────────────────────────

  /// Start (or attach to) the foreground service for a download. Returns
  /// whether the ongoing status-bar notification is active (callers fall
  /// back to a plain local notification when false).
  Future<bool> showDownload({
    required String title,
    String text = '',
  }) async {
    final active = await _startOrUpdate(title: title, text: text);
    if (active) _downloadRefCount++;
    return active;
  }

  /// Update the download notification's progress text.
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

  /// Detach this download from the foreground service, stopping it (and
  /// removing its notification) once no job needs it any more.
  Future<void> hideDownload() async {
    if (_downloadRefCount > 0) _downloadRefCount--;
    await _stopWhenIdle();
  }

  // ── Translation builder owner ───────────────────────────────────────

  /// Start (or attach to) the foreground service for a translation run.
  /// Returns whether the ongoing status-bar notification is active (callers
  /// fall back to a plain local notification when false).
  Future<bool> showTranslation({
    required String title,
    String text = '',
  }) async {
    final active = await _startOrUpdate(title: title, text: text);
    if (active) _translatorRefCount++;
    return active;
  }

  /// Update the translation-run notification's progress text.
  Future<void> updateTranslation({
    required String title,
    required String text,
  }) async {
    await updateDownload(title: title, text: text);
  }

  /// Detach this translation run from the foreground service, stopping it
  /// once no job needs it any more.
  Future<void> hideTranslation() async {
    if (_translatorRefCount > 0) _translatorRefCount--;
    await _stopWhenIdle();
  }
}

/// Result of [DownloadForegroundService.ensureNotificationPermission].
enum NotificationPermissionState { granted, denied, permanentlyDenied }

/// Top-level entry point required by the plugin. The service keeps the
/// process alive; the handler itself does nothing (the job runs in the main
/// isolate), but it must be a top-level/static function.
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
