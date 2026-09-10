import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';
import 'core/services/app_analytics.dart';
import 'core/utils/database_initializer.dart';
import 'features/settings/services/download_notification_service.dart';

/// Maximum number of identical errors to report in a 2-second window.
/// Prevents the console from being flooded with thousands of repeated
/// framework assertion errors (e.g. !semantics.parentDataDirty) that
/// fire on every frame after the semantics tree enters an inconsistent
/// state.
const int _kMaxRepeatedErrors = 3;

/// Tracks recent errors for deduplication.
final _errorCounts = <int, int>{};
int _lastErrorTimeMs = 0;

/// Global error handler that:
/// 1. Prints the full stack trace for the first few occurrences of an error
/// 2. Suppresses repeated identical errors to prevent console flooding
/// 3. Still logs via [developer.log] for structured access
void _handleFlutterError(FlutterErrorDetails details) {
  AppAnalytics.instance.recordFlutterError(details);
  final now = DateTime.now().millisecondsSinceEpoch;
  final msg = details.exception.toString();
  final hash = msg.hashCode;

  // Reset counter if last occurrence was > 2 seconds ago
  if (now - _lastErrorTimeMs > 2000) {
    _errorCounts.clear();
  }
  _lastErrorTimeMs = now;

  final count = (_errorCounts[hash] ?? 0) + 1;
  _errorCounts[hash] = count;

  if (count <= _kMaxRepeatedErrors) {
    // Print the full error with stack trace for the first few occurrences
    developer.log(
      '[FLUTTER_ERROR #$count] ${details.exception}\n'
      '${details.stack ?? "(no stack trace)"}',
      name: 'epitaka.framework',
      error: details.exception,
      stackTrace: details.stack,
    );
    FlutterError.dumpErrorToConsole(details);
  } else if (count == _kMaxRepeatedErrors + 1) {
    // Print a summary message once to indicate suppression has started
    developer.log(
      '[FLUTTER_ERROR] Suppressing further identical errors '
      '("${details.exception.toString().substring(0, min(80, details.exception.toString().length))}")',
      name: 'epitaka.framework',
    );
  }
  // After _kMaxRepeatedErrors + 1, silently drop the error to prevent flooding
}

Future<void> main() async {
  // Capture full stack traces for framework assertion errors.
  // Crashlytics is attached inside [_handleFlutterError] once ready.
  FlutterError.onError = _handleFlutterError;

  WidgetsFlutterBinding.ensureInitialized();

  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    AppAnalytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Initialise the port the foreground-service task handler uses to
  // communicate with the main isolate (Android downloads). Pure-Dart, cheap
  // and harmless on other platforms; must run before any download can start
  // a foreground service.
  FlutterForegroundTask.initCommunicationPort();

  // Paint the first frame immediately. Everything below is non-critical for
  // the first paint and runs in the background: the FTS gate shows a loading
  // spinner until the DB copies + check finish, and cloud/analytics features
  // degrade gracefully until their init completes.
  runApp(const ProviderScope(child: EpitakaApp()));

  unawaited(_initAsync());

  // Debug-only macOS workaround: with `flutter run -d macos` the window
  // sometimes fails to repaint frames produced after launch (e.g. the
  // "Loading available translations…" screen → setup wizard transition)
  // until the window is activated or resized. Keeping frames scheduled
  // for the first seconds of a debug session makes the UI snap to the
  // latest state. Profile/release builds are unaffected — `kDebugMode` is
  // a const false there, so this whole block is compiled out.
  if (kDebugMode && Platform.isMacOS) {
    _nudgeMacDebugRepaints();
  }
}

/// Background init deferred past the first frame so startup paints fast.
///
/// - Analytics/Firebase may hit network/disk — app works without it.
/// - DB file copies must finish before the FTS check opens the DB, so this
///   warms the shared [ensureDatabasesReady] future early; the FTS gate
///   awaits it and shows loading meanwhile.
/// - Supabase is optional/offline-safe ([AuthService] guards every access),
///   so it can finish whenever.
Future<void> _initAsync() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await AppAnalytics.instance.init(
      analyticsEnabled: prefs.getBool('analytics_enabled') ?? true,
      crashEnabled: prefs.getBool('crash_reports_enabled') ?? true,
    );
    await AppAnalytics.instance.logEvent('app_open');
  } catch (_) {}

  await ensureDatabasesReady();

  try {
    await DownloadNotificationService.instance.init();
  } catch (e) {
    developer.log(
      '[DL_NOTIF] Failed to initialise notification service: $e',
      name: 'epitaka.download',
    );
  }

  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        persistSession: true,
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
}

/// Debug-only helper backing the macOS repaint workaround in [main].
///
/// Schedules a few extra frames right after the first frame, then keeps a
/// frame scheduled every ~0.5s while startup settles (async provider
/// transitions such as the manifest fetch can complete several seconds in),
/// stopping after ~15s. Harmless in debug, compiled out elsewhere.
void _nudgeMacDebugRepaints() {
  final binding = WidgetsBinding.instance;
  binding.addPostFrameCallback((_) {
    for (var i = 0; i < 3; i++) {
      binding.scheduleFrame();
    }
    var count = 0;
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      count++;
      if (count > 30) {
        timer.cancel();
        return;
      }
      binding.scheduleFrame();
    });
  });
}
