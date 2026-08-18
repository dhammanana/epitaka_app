import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';
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
  // Capture full stack traces for framework assertion errors
  FlutterError.onError = _handleFlutterError;

  WidgetsFlutterBinding.ensureInitialized();

  // Desktop only: copy databases/downloads left in the old locations
  // (Documents or an exe-adjacent data/ folder) into the canonical per-user
  // database directory, so existing users never have to re-download and
  // bookmarks/history are preserved. Must run before any DB is opened.
  //
  // Both this and ensureBundledDatabases() are best-effort and must never
  // prevent startup: path_provider's FFI (package:objective_c) can break
  // after a macOS hot restart (dart-lang/native#3281) and throw here.
  // getDatabaseDirectory() itself falls back to a pure-Dart directory, so
  // the app keeps working until the next full restart.
  try {
    await migrateLegacyDatabases();
  } catch (e) {
    developer.log(
      '[DB_MIGRATE] Legacy migration skipped: $e',
      name: 'epitaka.database',
    );
  }

  // Copy bundled databases from assets to writable storage (needed on
  // Android/iOS where assets aren't directly file-system accessible).
  try {
    await ensureBundledDatabases();
  } catch (e) {
    developer.log(
      '[DB_INIT] Bundled database copy skipped: $e',
      name: 'epitaka.database',
    );
  }

  // On Android, copy the core databases (epitaka.db, dpd-dictionary.db) out
  // of the install-time Play Asset Delivery pack so the app works fully
  // offline (no download required). Falls back silently when the pack isn't
  // present (debug builds, side-loaded APKs).
  await ensureAssetPackDatabases();

  // Initialise the download notification service for showing progress
  // in the Android notification bar. Wrapped in try-catch so that a
  // plugin initialization failure (e.g. during hot restart) doesn't
  // prevent the app from starting.
  try {
    await DownloadNotificationService.instance.init();
  } catch (e) {
    developer.log(
      '[DL_NOTIF] Failed to initialise notification service: $e',
      name: 'epitaka.download',
    );
  }

  // Initialise the port the foreground-service task handler uses to
  // communicate with the main isolate (Android downloads). Pure-Dart and
  // harmless on other platforms; must run before any download can start a
  // foreground service.
  FlutterForegroundTask.initCommunicationPort();

  // Initialise Supabase (auth + cloud sync). Failures here only disable
  // cloud features; the app must still start fully offline.
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        persistSession: true,
        // Native: the app handles the OAuth redirect itself via
        // DeepLinkService → AuthService.handleRedirectUri, so disable the
        // plugin's built-in deep-link session detection to avoid a double
        // PKCE exchange.
        //
        // Web: DeepLinkService never runs on web (there are no custom
        // scheme links), so the plugin must recover the session from the
        // callback URL itself — otherwise the Google redirect lands back
        // on the app with a `?code=…` query that nobody consumes, and the
        // sign-in never completes.
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

  runApp(const ProviderScope(child: EpitakaApp()));

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
