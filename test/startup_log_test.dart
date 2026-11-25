import 'dart:convert';
import 'dart:io';

import 'package:epitaka/core/utils/startup_timing.dart';
import 'package:epitaka/features/desktop/startup_guard.dart';
import 'package:epitaka/features/desktop/startup_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;

  File file(String name) => File(p.join(dir.path, name));
  List<String> logLines([String name = 'startup.log']) =>
      file(name).readAsLinesSync();
  List<String> names() =>
      dir.listSync().map((e) => p.basename(e.path)).toList()..sort();

  setUp(() {
    dir = Directory.systemTemp.createTempSync('startup_log_');
    StartupTiming.lines.clear();
  });

  tearDown(() {
    // `just test` runs many files in one process, so leave nothing behind.
    StartupTiming.sink = null;
    StartupTiming.lines.clear();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('each open keeps the previous log as startup.prev.log', () {
    StartupLog()
      ..open(dir)
      ..write('first start');
    StartupLog()
      ..open(dir)
      ..write('second start');
    expect(names(), ['startup.log', 'startup.prev.log']);
    expect(logLines('startup.prev.log'), contains('first start'));

    StartupLog()
      ..open(dir)
      ..write('third start');

    expect(names(), ['startup.log', 'startup.prev.log']);
    expect(logLines('startup.prev.log'), contains('second start'));
    expect(logLines('startup.prev.log'), isNot(contains('first start')));
    expect(logLines(), contains('third start'));
  });

  test('the header comes first, then the timing lines made before the log '
      'opened, then new ones', () {
    StartupTiming.lines.addAll([
      '[STARTUP] +     0ms  main() entered',
      '[STARTUP] +     5ms  single copy checked',
    ]);

    StartupLog().open(dir, now: () => DateTime(2026, 11, 25, 8));
    StartupTiming.mark('after the log opened');

    final lines = logLines();
    expect(lines[0], startsWith('[HEADER] 2026-11-25T08:00:00.000 ePitaka '));
    expect(lines[0], contains(Platform.operatingSystem));
    expect(lines.sublist(1, 3), [
      '[STARTUP] +     0ms  main() entered',
      '[STARTUP] +     5ms  single copy checked',
    ]);
    expect(lines.last, endsWith('after the log opened'));
    expect(lines, hasLength(4));
  });

  test('stops at 500 lines with one limit line', () {
    final log = StartupLog()..open(dir);
    for (var i = 0; i < 600; i++) {
      log.write('line $i');
    }

    final lines = logLines();
    expect(lines, hasLength(501));
    expect(lines[499], 'line 498');
    expect(lines.last, '[LOG] limit reached');
  });

  test('an error writes its type and stack, never its message', () {
    final log = StartupLog()..open(dir);

    log.error(
      const FormatException('secret-token-value', 'secret-source'),
      StackTrace.current,
    );

    final lines = logLines();
    expect(lines, contains('[ERROR] FormatException'));
    expect(lines.where((l) => l.startsWith('[ERROR]   ')), isNotEmpty);
    expect(lines.where((l) => l.startsWith('[ERROR]   ')).length,
        lessThanOrEqualTo(10));
    expect(file('startup.log').readAsStringSync(), isNot(contains('secret')));
  });

  test('no settings value reaches either log', () {
    final settings = file('shared_preferences.json');
    final lastGood = file('shared_preferences.last_good.json');

    // A start after an unfinished one compares the keys of two readable
    // files that both hold a secret.
    settings.writeAsStringSync(json.encode({
      'flutter.sb-test-auth-token': 'sb-test-auth-token-VALUE123',
      'flutter.mcp_token': 'VALUE456',
    }));
    lastGood.writeAsStringSync(json.encode({
      'flutter.sb-test-auth-token': 'sb-test-auth-token-VALUE789',
    }));
    file('startup_pending').writeAsStringSync('1');
    StartupGuard.begin(dir, detectCrashes: true, log: StartupLog()..open(dir))
        .finish();

    // The next start finds a file cut short in the middle of a secret.
    settings.writeAsStringSync(
        '{"flutter.sb-test-auth-token":"sb-test-auth-token-VALUE123');
    StartupGuard.begin(dir, detectCrashes: true, log: StartupLog()..open(dir));

    final both = file('startup.log').readAsStringSync() +
        file('startup.prev.log').readAsStringSync();
    expect(both, contains('[GUARD] keys changed since the last good copy: '
        'flutter.sb-test-auth-token'));
    expect(both, contains('readable: no (FormatException at '));
    for (final secret in ['VALUE123', 'VALUE456', 'VALUE789']) {
      expect(both, isNot(contains(secret)));
    }
  });

  test('a write that fails turns logging off without throwing', () {
    final log = StartupLog()..open(dir);
    expect(log.isOpen, isTrue);
    dir.deleteSync(recursive: true);

    expect(() => log.write('lost'), returnsNormally);
    expect(log.isOpen, isFalse);

    dir.createSync();
    log.write('after');
    expect(file('startup.log').existsSync(), isFalse);
  });
}
