import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
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

  // Copy bundled databases from assets to writable storage (needed on
  // Android/iOS where assets aren't directly file-system accessible).
  await ensureBundledDatabases();

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

  runApp(const ProviderScope(child: EpitakaApp()));
}
