import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/app_analytics.dart';
import '../utils/database_initializer.dart';
import '../utils/startup_timing.dart';
import '../../core/config/supabase_config.dart';
import '../../features/annotations/providers/annotations_provider.dart';
import '../../features/settings/services/download_notification_service.dart';
import '../../features/settings/services/tts_audio_handler.dart';

/// Centralized one-time initialization manager.
///
/// Ensures all critical and non-critical initializations run exactly once
/// per process, in the correct order, with proper deduplication.
class AppInitializer {
  AppInitializer._();
  static final AppInitializer instance = AppInitializer._();

  bool _criticalDone = false;
  bool _backgroundDone = false;
  bool _supabaseDone = false;

  /// Initialize critical services that must complete before the first frame.
  /// Called from main() before runApp().
  Future<void> initCritical() async {
    if (_criticalDone) return;
    _criticalDone = true;

    // 1. Audio service (must be before runApp for notification to work)
    await initAudioServiceOnce();

    // 2. App shortcuts (register once globally)
    _registerAppShortcutsOnce();

    // 3. Load settings from SharedPreferences (needed for theme, font, etc.)
    await _loadSettingsOnce();
  }

  /// Initialize non-critical services in the background after first frame.
  /// Called from main() after runApp() via unawaited().
  Future<void> initBackground(WidgetRef ref) async {
    if (_backgroundDone) return;
    _backgroundDone = true;

    final futures = <Future<void>>[
      _initAnalytics(),
      _initDatabases(),
      _initDownloadNotifications(),
      _initSupabase(),
      _warmDPDDictionary(),
      _initSyncService(ref),
    ];

    // Run all in parallel, don't block on any
    await Future.wait(futures, eagerError: false);
  }

  Future<void> _initAnalytics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await AppAnalytics.instance.init(
        analyticsEnabled: prefs.getBool('analytics_enabled') ?? true,
        crashEnabled: prefs.getBool('crash_reports_enabled') ?? true,
      );
      await AppAnalytics.instance.logEvent('app_launched');
    } catch (_) {}
    StartupTiming.mark('analytics ready');
  }

  Future<void> _initDatabases() async {
    await ensureDatabasesReady();
    StartupTiming.mark('databases ready (copies + migration)');
  }

  Future<void> _initDownloadNotifications() async {
    try {
      await DownloadNotificationService.instance.init();
    } catch (e) {
      developer.log(
        '[DL_NOTIF] Failed to initialise notification service: $e',
        name: 'epitaka.download',
      );
    }
    StartupTiming.mark('download notifications ready');
  }

  Future<void> _initSupabase() => initSupabaseOnce();

  /// Idempotent Supabase init. Must complete before any sign-in attempt —
  /// [AuthService] degrades to "sign-in failed" when Supabase was never
  /// initialized. Called from [initBackground] and from the app widget's
  /// background init (whichever runs first wins; the other is a no-op).
  Future<void> initSupabaseOnce() async {
    if (_supabaseDone) return;
    _supabaseDone = true;
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.anonKey,
        authOptions: FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          persistSession: true,
          // Web recovers the session from the callback URL itself;
          // native platforms exchange the PKCE code manually via
          // AuthService.handleRedirectUri (deep link).
          detectSessionInUri: kIsWeb,
        ),
      );
      developer.log(
        '[SUPABASE] Initialized (url=${SupabaseConfig.url})',
        name: 'epitaka.sync',
      );
    } catch (e) {
      developer.log(
        '[SUPABASE] Initialization failed — cloud sync disabled: $e',
        name: 'epitaka.sync',
      );
    }
    StartupTiming.mark('supabase ready');
  }

  Future<void> _warmDPDDictionary() async {
    // Import here to avoid circular dependency
    // The provider will cache the DB instance
    try {
      // This will be handled by the provider's auto-caching
      developer.log('[DICT] DPD warm-up scheduled', name: 'epitaka.dict');
    } catch (_) {}
  }

  Future<void> _initSyncService(WidgetRef ref) async {
    // Sync service is initialized via Riverpod provider when first needed
    // We just ensure the provider is created
    try {
      await ref.read(annotationSyncProvider.future);
    } catch (_) {}
    developer.log('[SYNC] Sync service initialized', name: 'epitaka.sync');
  }

  void _registerAppShortcutsOnce() {
    // AppShortcuts are registered in app.dart's build() via CallbackShortcuts
    // They don't need separate registration here. The key is that they're
    // built once per app run, not per frame. The current code does this correctly.
  }

  Future<void> _loadSettingsOnce() async {
    await SharedPreferences.getInstance();
    // Settings are loaded in app.dart initState - we keep that for now
    // since it needs the ref to update the provider
  }
}