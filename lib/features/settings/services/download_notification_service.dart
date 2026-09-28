import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Manages Android foreground-service download progress notifications for
/// translation DBs, AI models, and Gavesana assets.
///
/// Uses a single ongoing notification per download "family" (translations,
/// gavesana) that gets updated with progress and dismissed on
/// completion.  On Android this satisfies the
/// `FOREGROUND_SERVICE_DATA_SYNC` requirement for Google Play compliance
/// and gives the user a visible, cancellable download indicator.
///
/// The service is also initialized on other platforms (iOS/macOS/Linux) so
/// that plugin calls never throw — a notification failure must NEVER crash
/// a download. Every `_plugin` call is therefore wrapped defensively.
class DownloadNotificationService {
  DownloadNotificationService._();

  static final DownloadNotificationService instance =
      DownloadNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Local notifications are an Android/iOS concern (foreground-service
  /// compliance, background progress). On desktop/web the app window itself
  /// shows progress — and on macOS the plugin CRASHES the whole process
  /// (a Swift force-unwrap in `buildUserNotificationContent` when `show()`
  /// is called without a prior `initialize()`) in a way no Dart try/catch
  /// can intercept. So plugin calls are skipped entirely off mobile.
  static bool get _notificationsSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  // Notification IDs — keep them distinct so channels don't collide.
  static const int _translationNotificationId = 1001;
  static const int _gavesanaNotificationId = 1002;
  static const int _translatorRunNotificationId = 1004;
  static const int _indexBuildNotificationId = 1005;

  /// Must be called once at app startup (e.g. in [main] or app init).
  Future<void> init() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    // Shared by iOS and macOS (both are "Darwin" platforms).
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open',
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );
    await _plugin.initialize(settings);
    _initialized = true;
    developer.log(
      '[DL_NOTIF] DownloadNotificationService initialised',
      name: 'epitaka.download',
    );
  }

  // ── Translation download notifications ───────────────────────────────

  /// Show or update a download progress notification for a translation DB.
  void showTranslationProgress({
    required String versionKey,
    required String displayName,
    required double progress,
    required bool isIndeterminate,
  }) {
    _showProgressNotification(
      id: _translationNotificationId,
      channelId: 'download_translations',
      channelName: 'Translation Downloads',
      title: 'Downloading $displayName',
      progress: progress,
      isIndeterminate: isIndeterminate,
      ongoing: true,
    );
  }

  /// Mark translation download as complete (brief "done" then auto-dismiss).
  void showTranslationComplete(String displayName) {
    _showDoneNotification(
      id: _translationNotificationId,
      channelId: 'download_translations',
      channelName: 'Translation Downloads',
      title: '$displayName ready',
      body: 'Translation downloaded and installed.',
    );
  }

  /// Show a translation download error.
  void showTranslationError(String displayName, String error) {
    _showErrorNotification(
      id: _translationNotificationId,
      channelId: 'download_translations',
      channelName: 'Translation Downloads',
      title: '$displayName failed',
      body: error,
    );
  }

  /// Dismiss the translation download notification.
  void dismissTranslation() {
    _safeCancel(_translationNotificationId);
  }

  // ── Gavesana AI asset download notifications ─────────────────────────

  void showGavesanaProgress({
    required double progress,
    required bool isIndeterminate,
    String? phase,
  }) {
    _showProgressNotification(
      id: _gavesanaNotificationId,
      channelId: 'download_gavesana',
      channelName: 'AI Search Downloads',
      title: phase == 'extracting'
          ? 'Extracting AI models…'
          : 'Downloading AI models…',
      progress: progress,
      isIndeterminate: isIndeterminate,
      ongoing: true,
    );
  }

  void showGavesanaComplete() {
    _showDoneNotification(
      id: _gavesanaNotificationId,
      channelId: 'download_gavesana',
      channelName: 'AI Search Downloads',
      title: 'AI models ready',
      body: 'AI search assets downloaded and installed.',
    );
  }

  void showGavesanaError(String error) {
    _showErrorNotification(
      id: _gavesanaNotificationId,
      channelId: 'download_gavesana',
      channelName: 'AI Search Downloads',
      title: 'AI model download failed',
      body: error,
    );
  }

  void dismissGavesana() {
    _safeCancel(_gavesanaNotificationId);
  }

  // ── Translation Builder run notifications ───────────────────────────

  /// Show or update the ongoing translation-run progress notification.
  void showTranslatorRunProgress({
    required String title,
    String? body,
    required double progress,
    bool isIndeterminate = false,
  }) {
    final pct = (progress * 100).round().clamp(0, 100);
    final androidDetails = _androidChannel(
      'translator_run',
      'Translation Builder',
      ongoing: true,
      showProgress: !isIndeterminate,
      maxProgress: 100,
      currentProgress: pct,
      indeterminate: isIndeterminate,
      // Default (not low) importance so the run notification actually
      // shows in the status bar — LOW was the reason the earlier progress
      // notifications never appeared.
    );
    _safeShow(
      _translatorRunNotificationId,
      title,
      body ?? (isIndeterminate ? null : '$pct%'),
      NotificationDetails(android: androidDetails),
    );
  }

  /// Mark the translation run as finished (brief "done" then auto-dismiss).
  void showTranslatorRunComplete(String title, String body) {
    final androidDetails = _androidChannel(
      'translator_run',
      'Translation Builder',
      ongoing: false,
      showProgress: false,
    );
    _safeShow(
      _translatorRunNotificationId,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
    Future.delayed(const Duration(seconds: 4), () {
      _safeCancel(_translatorRunNotificationId);
    });
  }

  /// Show a translation-run error.
  void showTranslatorRunError(String title, String body) {
    final androidDetails = _androidChannel(
      'translator_run',
      'Translation Builder',
      ongoing: false,
      showProgress: false,
    );
    _safeShow(
      _translatorRunNotificationId,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
    Future.delayed(const Duration(seconds: 8), () {
      _safeCancel(_translatorRunNotificationId);
    });
  }

  /// Dismiss the translation-run notification.
  void dismissTranslatorRun() {
    _safeCancel(_translatorRunNotificationId);
  }

  // ── Search-index build notifications ─────────────────────────────────

  /// Show or update the ongoing index-build progress notification.
  void showIndexProgress({
    required String title,
    String? body,
    required double progress,
    bool isIndeterminate = false,
  }) {
    final pct = (progress * 100).round().clamp(0, 100);
    final androidDetails = _androidChannel(
      'index_build',
      'Search Index',
      ongoing: true,
      showProgress: !isIndeterminate,
      maxProgress: 100,
      currentProgress: pct,
      indeterminate: isIndeterminate,
    );
    _safeShow(
      _indexBuildNotificationId,
      title,
      body ?? (isIndeterminate ? null : '$pct%'),
      NotificationDetails(android: androidDetails),
    );
  }

  /// Mark the index build as finished (brief "done" then auto-dismiss).
  void showIndexComplete(String title, String body) {
    final androidDetails = _androidChannel(
      'index_build',
      'Search Index',
      ongoing: false,
      showProgress: false,
    );
    _safeShow(
      _indexBuildNotificationId,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
    Future.delayed(const Duration(seconds: 4), () {
      _safeCancel(_indexBuildNotificationId);
    });
  }

  /// Show an index-build error.
  void showIndexError(String title, String body) {
    final androidDetails = _androidChannel(
      'index_build',
      'Search Index',
      ongoing: false,
      showProgress: false,
    );
    _safeShow(
      _indexBuildNotificationId,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
    Future.delayed(const Duration(seconds: 8), () {
      _safeCancel(_indexBuildNotificationId);
    });
  }

  /// Dismiss the index-build notification.
  void dismissIndex() {
    _safeCancel(_indexBuildNotificationId);
  }

  // ── Low-level helpers ────────────────────────────────────────────────

  AndroidNotificationDetails _androidChannel(
    String channelId,
    String channelName, {
    bool ongoing = false,
    bool showProgress = false,
    int? maxProgress,
    int? currentProgress,
    bool indeterminate = false,
  }) {
    return AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Download progress for $channelName',
      // DEFAULT (not LOW): LOW-importance channels are silent and often
      // hidden by OEMs — this was why the progress notifications never
      // showed in the status bar.
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      ongoing: ongoing,
      showProgress: showProgress,
      maxProgress: maxProgress ?? 0,
      progress: currentProgress ?? 0,
      indeterminate: indeterminate,
      onlyAlertOnce: true,
      showWhen: false,
    );
  }

  void _showProgressNotification({
    required int id,
    required String channelId,
    required String channelName,
    required String title,
    String? body,
    required double progress,
    required bool isIndeterminate,
    required bool ongoing,
  }) {
    final pct = (progress * 100).round();
    final androidDetails = _androidChannel(
      channelId,
      channelName,
      ongoing: ongoing,
      showProgress: !isIndeterminate,
      maxProgress: 100,
      currentProgress: pct.clamp(0, 100),
      indeterminate: isIndeterminate,
    );
    _safeShow(
      id,
      title,
      body ?? (isIndeterminate ? null : '$pct%'),
      NotificationDetails(android: androidDetails),
    );
  }

  void _showDoneNotification({
    required int id,
    required String channelId,
    required String channelName,
    required String title,
    required String body,
  }) {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Download progress for $channelName',
      importance: Importance.low,
      priority: Priority.defaultPriority,
      ongoing: false,
      showProgress: false,
      onlyAlertOnce: true,
      showWhen: false,
    );
    _safeShow(id, title, body, NotificationDetails(android: androidDetails));
    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      _safeCancel(id);
    });
  }

  void _showErrorNotification({
    required int id,
    required String channelId,
    required String channelName,
    required String title,
    required String body,
  }) {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Download progress for $channelName',
      importance: Importance.defaultImportance,
      priority: Priority.high,
      ongoing: false,
      showProgress: false,
      onlyAlertOnce: true,
      showWhen: true,
    );
    _safeShow(id, title, body, NotificationDetails(android: androidDetails));
    // Auto-dismiss error after 8 seconds
    Future.delayed(const Duration(seconds: 8), () {
      _safeCancel(id);
    });
  }

  /// Fire-and-forget notification show that can NEVER throw. A plugin or
  /// platform failure is logged and swallowed so a download is never
  /// interrupted by a notification problem (e.g. unsupported platform,
  /// missing permission, or a nil force-unwrap on the native side).
  ///
  /// Note: a native crash (Swift `fatalError`, as the macOS plugin raises
  /// on an un-initialized `show()`) cannot be caught from Dart — that is
  /// why [_notificationsSupported] skips desktop/web entirely instead of
  /// relying on the try/catch below.
  void _safeShow(
    int id,
    String? title,
    String? body,
    NotificationDetails details,
  ) {
    if (!_notificationsSupported) return;
    try {
      _plugin.show(id, title, body, details).catchError((Object e) {
        developer.log(
          '[DL_NOTIF] show notification failed: $e',
          name: 'epitaka.download',
        );
      });
    } catch (e) {
      developer.log(
        '[DL_NOTIF] show notification failed: $e',
        name: 'epitaka.download',
      );
    }
  }

  void _safeCancel(int id) {
    if (!_notificationsSupported) return;
    try {
      _plugin.cancel(id).catchError((Object e) {
        developer.log(
          '[DL_NOTIF] cancel notification failed: $e',
          name: 'epitaka.download',
        );
      });
    } catch (e) {
      developer.log(
        '[DL_NOTIF] cancel notification failed: $e',
        name: 'epitaka.download',
      );
    }
  }
}
