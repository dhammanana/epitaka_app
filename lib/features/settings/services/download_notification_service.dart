import 'dart:developer' as developer;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Manages Android foreground-service download progress notifications for
/// translation DBs, AI models, and Gavesana assets.
///
/// Uses a single ongoing notification per download "family" (translations,
/// supertonic, gavesana) that gets updated with progress and dismissed on
/// completion.  On Android this satisfies the
/// `FOREGROUND_SERVICE_DATA_SYNC` requirement for Google Play compliance
/// and gives the user a visible, cancellable download indicator.
class DownloadNotificationService {
  DownloadNotificationService._();

  static final DownloadNotificationService instance =
      DownloadNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Notification IDs — keep them distinct so channels don't collide.
  static const int _translationNotificationId = 1001;
  static const int _gavesanaNotificationId = 1002;
  static const int _supertonicNotificationId = 1003;

  /// Must be called once at app startup (e.g. in [main] or app init).
  Future<void> init() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
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
    _plugin.cancel(_translationNotificationId);
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
    _plugin.cancel(_gavesanaNotificationId);
  }

  // ── Supertonic TTS model download notifications ─────────────────────

  void showSupertonicProgress({
    required double progress,
    required bool isIndeterminate,
    String? currentFile,
    int filesDone = 0,
    int filesTotal = 0,
  }) {
    final title = filesTotal > 0
        ? 'Downloading TTS voice ($filesDone/$filesTotal)'
        : 'Downloading TTS voice…';
    final body = currentFile != null ? 'File: $currentFile' : null;
    _showProgressNotification(
      id: _supertonicNotificationId,
      channelId: 'download_supertonic',
      channelName: 'TTS Voice Downloads',
      title: title,
      body: body,
      progress: progress,
      isIndeterminate: isIndeterminate,
      ongoing: true,
    );
  }

  void showSupertonicComplete() {
    _showDoneNotification(
      id: _supertonicNotificationId,
      channelId: 'download_supertonic',
      channelName: 'TTS Voice Downloads',
      title: 'TTS voice ready',
      body: 'High-quality TTS model downloaded.',
    );
  }

  void showSupertonicError(String error) {
    _showErrorNotification(
      id: _supertonicNotificationId,
      channelId: 'download_supertonic',
      channelName: 'TTS Voice Downloads',
      title: 'TTS voice download failed',
      body: error,
    );
  }

  void dismissSupertonic() {
    _plugin.cancel(_supertonicNotificationId);
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
      importance: Importance.low,
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
    _plugin.show(
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
    _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      _plugin.cancel(id);
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
    _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
    // Auto-dismiss error after 8 seconds
    Future.delayed(const Duration(seconds: 8), () {
      _plugin.cancel(id);
    });
  }
}
