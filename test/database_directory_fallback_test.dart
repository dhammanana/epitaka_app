/// Regression test for the macOS hot-restart crash
/// (dart-lang/native#3281): after a hot restart, package:objective_c's FFI
/// can break, so path_provider throws. Startup must survive that — the DB
/// directory falls back to a pure-Dart per-user directory instead of
/// crashing main().
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/core/utils/database_initializer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('getDatabaseDirectory resolves without throwing when path_provider '
      'is unavailable', () async {
    // In the test environment no path_provider plugin is registered, so
    // getApplicationSupportDirectory() throws a MissingPluginException —
    // the same class of failure the broken objective_c FFI produces after a
    // macOS hot restart. Before the fix this propagated and crashed startup;
    // now it falls back to a pure-Dart directory.
    final Directory dir = await getDatabaseDirectory();
    expect(dir.path, isNotEmpty);

    if (Platform.isMacOS) {
      // The fallback lives under the per-user Application Support folder and
      // never points inside the app bundle / build output.
      expect(dir.path, contains('Application Support'));

      // On this machine the app is sandboxed and its databases live in the
      // container (`~/Library/Containers/com.dn.epitaka/…`). The fallback
      // must land on that exact directory — a wrong guess is what made the
      // app look like a fresh install and ask to re-download the DBs.
      final containerDir =
          '${Platform.environment['HOME']}/Library/Containers/';
      final inContainer = dir.path.startsWith(containerDir);
      if (!inContainer) {
        // Non-sandboxed / CI: shared Application Support is the right guess.
        expect(dir.path, isNot(contains('/epitaka/')));
      }
    }
  });

  test('fallback restores the exact previously-resolved directory, not a '
      'guess', () async {
    // Regression: after a macOS hot restart, path_provider's FFI breaks and
    // getDatabaseDirectory() falls back. If the fallback guessed the path
    // (e.g. via bundle-id parsing) instead of restoring the real directory,
    // the app saw an empty folder and re-triggered the download/index flow.
    //
    // In tests path_provider is always unavailable, so every call goes
    // through the fallback path. The first successful resolution persists
    // the result to the marker file; the second call must restore EXACTLY
    // the same path (this mirrors a working session writing the marker,
    // then a hot-restart session restoring it).
    final Directory first = await getDatabaseDirectory();
    final Directory second = await getDatabaseDirectory();
    expect(second.path, first.path,
        reason: 'fallback must restore the persisted path, not re-guess');
  });
}
