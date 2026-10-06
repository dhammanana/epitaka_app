import 'dart:convert';
import 'dart:io';

import 'package:epitaka/features/desktop/single_instance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a second launch is refused, nudges the first, and a dead first copy '
      'leaves no stale lock', () async {
    final dir = await Directory.systemTemp.createTemp('single_instance');
    addTearDown(() => dir.delete(recursive: true));

    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    final dart = flutterRoot == null ? 'dart' : '$flutterRoot/bin/dart';
    final holder = await Process.start(
      dart,
      ['test/support/hold_single_instance.dart', dir.path],
    );
    addTearDown(() => holder.kill(ProcessSignal.sigkill));

    final lines = holder.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .asBroadcastStream();
    final nudged = lines.firstWhere((l) => l == 'nudged');
    // Killing the holder closes the stream; without a handler that error
    // would surface as unhandled when the test has already failed elsewhere.
    nudged.catchError((_) => '');
    final claimLine = await lines
        .firstWhere((l) => l.startsWith('claimed:'))
        .timeout(const Duration(seconds: 30));
    expect(claimLine, 'claimed:true');

    final second = await claimSingleInstance(dir, onAnotherLaunch: () {});
    expect(second, isFalse);
    await nudged.timeout(const Duration(seconds: 5));

    holder.kill(ProcessSignal.sigkill);
    await holder.exitCode;
    expect(await claimSingleInstance(dir, onAnotherLaunch: () {}), isTrue);
    // A cold `dart` start for the helper can take longer than the default.
  }, timeout: const Timeout(Duration(seconds: 60)));
}
