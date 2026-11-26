import 'dart:convert';
import 'dart:io';

import 'package:epitaka/features/desktop/startup_guard.dart';
import 'package:epitaka/features/desktop/startup_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_linux/path_provider_linux.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_linux/shared_preferences_linux.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

/// Points the real Linux settings store at the test's temp folder.
class _DirPathProvider extends PathProviderLinux {
  _DirPathProvider(this.dirPath);
  final String dirPath;

  @override
  Future<String?> getApplicationSupportPath() async => dirPath;
}

class _MemoryLog extends StartupLog {
  final lines = <String>[];

  @override
  void write(String line) => lines.add(line);
}

/// A read-only folder only blocks writes for a normal user on Linux.
final _cannotBlockWrites =
    Platform.isWindows || Process.runSync('id', ['-u']).stdout.toString().trim() == '0';

void main() {
  late Directory dir;
  late SharedPreferencesStorePlatform original;
  late _MemoryLog log;

  File file(String name) => File(p.join(dir.path, name));
  File settings() => file('shared_preferences.json');
  File lastGood() => file('shared_preferences.last_good.json');
  File marker() => file('startup_pending');

  void writeJson(File f, Map<String, Object?> values) =>
      f.writeAsStringSync(json.encode(values));

  List<String> failedCopies() => dir
      .listSync()
      .map((e) => p.basename(e.path))
      .where((n) => n.startsWith('shared_preferences.failed-'))
      .toList()
    ..sort();

  StartupGuard begin({bool detectCrashes = true, DateTime Function()? now}) =>
      StartupGuard.begin(dir,
          detectCrashes: detectCrashes, log: log, now: now);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('startup_guard_');
    log = _MemoryLog();
    original = SharedPreferencesStorePlatform.instance;
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = SharedPreferencesLinux()
      ..pathProvider = _DirPathProvider(dir.path);
  });

  tearDown(() {
    // `just test` runs many files in one process, so leave nothing behind.
    SharedPreferencesStorePlatform.instance = original;
    SharedPreferences.resetStatic();
    dir.deleteSync(recursive: true);
  });

  test('a cut-short settings file still opens, and the file is set aside',
      () async {
    const cutShort = '{"flutter.a":"b","flutter.c":';
    file('shared_preferences.json').writeAsStringSync(cutShort);

    final prefs =
        await StartupGuard.begin(dir, detectCrashes: true).openSettings();

    expect(prefs.getKeys(), isEmpty);
    expect(file('shared_preferences.json').existsSync(), isFalse);
    final failed = failedCopies();
    expect(failed, hasLength(1));
    expect(file(failed.single).readAsStringSync(), cutShort);
  });

  group('crash check and readability', () {
    test('no marker and a readable file: no recovery, the marker counts '
        'this start', () {
      writeJson(settings(), {'flutter.a': 'b'});
      final before = settings().readAsBytesSync();

      final guard = begin();

      expect(guard.recovery, isNull);
      expect(marker().readAsStringSync(), '1');
      expect(settings().readAsBytesSync(), before);
      expect(failedCopies(), isEmpty);
    });

    test('one unfinished start with a last good copy: the copy goes back, '
        'and the marker was written first', () {
      writeJson(settings(), {'flutter.a': 1, 'flutter.b': 2, 'flutter.new': 1});
      final failedText = settings().readAsStringSync();
      writeJson(lastGood(), {'flutter.a': 1, 'flutter.b': 3, 'flutter.old': 1});
      final goodTime = DateTime(2026, 11, 20, 9, 30);
      lastGood().setLastModifiedSync(goodTime);
      marker().writeAsStringSync('1');
      String? markerAtSetAside;

      final guard = begin(now: () {
        markerAtSetAside = marker().readAsStringSync();
        return DateTime(2026, 11, 25, 8, 0, 0, 5);
      });

      final r = guard.recovery!;
      expect(r.cause, StartupRecoveryCause.unfinishedStart);
      expect(r.outcome, StartupRecoveryOutcome.restored);
      expect(r.failedStarts, 1);
      expect(r.lastGoodTime, goodTime);
      expect(r.folder, dir.path);
      expect(settings().readAsStringSync(), lastGood().readAsStringSync());
      expect(failedCopies(),
          ['shared_preferences.failed-20261125-080000-005-01.json']);
      expect(file(failedCopies().single).readAsStringSync(), failedText);
      expect(marker().readAsStringSync(), '2');
      expect(markerAtSetAside, '2');
      expect(
          log.lines,
          containsAll([
            '[GUARD] keys added since the last good copy: flutter.new',
            '[GUARD] keys removed since the last good copy: flutter.old',
            '[GUARD] keys changed since the last good copy: flutter.b',
          ]));
    });

    for (final unfinished in [1, 2]) {
      test('$unfinished unfinished start(s) and no last good copy: the '
          'settings are left alone', () {
        writeJson(settings(), {'flutter.a': 'b'});
        final before = settings().readAsStringSync();
        marker().writeAsStringSync('$unfinished');

        final guard = begin();

        expect(guard.recovery, isNull);
        expect(settings().readAsStringSync(), before);
        expect(failedCopies(), isEmpty);
        expect(marker().readAsStringSync(), '${unfinished + 1}');
      });
    }

    test('two unfinished starts with a last good copy: the copy goes back, '
        'and it is kept', () {
      writeJson(settings(), {'flutter.a': 'b'});
      writeJson(lastGood(), {'flutter.a': 'c'});
      marker().writeAsStringSync('2');

      final r = begin().recovery!;

      expect(r.cause, StartupRecoveryCause.unfinishedStart);
      expect(r.outcome, StartupRecoveryOutcome.restored);
      expect(r.failedStarts, 2);
      expect(json.decode(settings().readAsStringSync()), {'flutter.a': 'c'});
      expect(lastGood().existsSync(), isTrue);
      expect(failedCopies(), hasLength(1));
      expect(marker().readAsStringSync(), '3');
    });

    test('three unfinished starts: starts with no settings and drops the '
        'last good copy', () {
      writeJson(settings(), {'flutter.a': 'b'});
      writeJson(lastGood(), {'flutter.a': 'c'});
      marker().writeAsStringSync('3');

      final r = begin().recovery!;

      expect(r.cause, StartupRecoveryCause.unfinishedStart);
      expect(r.outcome, StartupRecoveryOutcome.startedEmpty);
      expect(r.failedStarts, 3);
      expect(settings().existsSync(), isFalse);
      expect(lastGood().existsSync(), isFalse);
      expect(failedCopies(), hasLength(1));
      expect(marker().readAsStringSync(), '4');
    });

    test('three unfinished starts and no last good copy: the settings are '
        'set aside', () {
      writeJson(settings(), {'flutter.a': 'b'});
      marker().writeAsStringSync('3');

      final r = begin().recovery!;

      expect(r.cause, StartupRecoveryCause.unfinishedStart);
      expect(r.outcome, StartupRecoveryOutcome.startedEmpty);
      expect(r.failedStarts, 3);
      expect(settings().existsSync(), isFalse);
      expect(failedCopies(), hasLength(1));
      expect(marker().readAsStringSync(), '4');
    });

    test('four unfinished starts: no settings file is touched', () {
      writeJson(settings(), {'flutter.a': 'b'});
      writeJson(lastGood(), {'flutter.a': 'c'});
      final settingsBefore = settings().readAsStringSync();
      final lastGoodBefore = lastGood().readAsStringSync();
      marker().writeAsStringSync('4');

      final r = begin().recovery!;

      expect(r.cause, StartupRecoveryCause.unfinishedStart);
      expect(r.outcome, StartupRecoveryOutcome.stillFailing);
      expect(r.failedStarts, 4);
      expect(settings().readAsStringSync(), settingsBefore);
      expect(lastGood().readAsStringSync(), lastGoodBefore);
      expect(failedCopies(), isEmpty);
      expect(marker().readAsStringSync(), '5');
    });

    for (final (label, bytes) in [
      ('text', utf8.encode('abc')),
      ('nothing', <int>[]),
      ('bad UTF-8', [0xff, 0xfe, 0x31]),
    ]) {
      test('a marker holding $label counts as one unfinished start', () {
        writeJson(settings(), {'flutter.a': 'b'});
        writeJson(lastGood(), {'flutter.a': 'c'});
        marker().writeAsBytesSync(bytes);

        final r = begin().recovery!;

        expect(r.outcome, StartupRecoveryOutcome.restored);
        expect(r.failedStarts, 1);
        expect(json.decode(settings().readAsStringSync()), {'flutter.a': 'c'});
        expect(marker().readAsStringSync(), '2');
      });
    }

    test('a restored last good copy that is cut short is set aside too', () {
      writeJson(settings(), {'flutter.a': 'b'});
      lastGood().writeAsStringSync('{"flutter.a":');
      marker().writeAsStringSync('1');

      final r = begin(now: () => DateTime(2026, 11, 25, 8)).recovery!;

      expect(r.cause, StartupRecoveryCause.unfinishedStart);
      expect(r.outcome, StartupRecoveryOutcome.startedEmpty);
      expect(r.failedStarts, 1);
      expect(r.lastGoodTime, isNull);
      expect(settings().existsSync(), isFalse);
      expect(failedCopies(), [
        'shared_preferences.failed-20261125-080000-000-01.json',
        'shared_preferences.failed-20261125-080000-000-02.json',
      ]);
    });

    test('an unreadable file with no marker goes back to a readable last '
        'good copy', () {
      settings().writeAsStringSync('{"flutter.a":');
      writeJson(lastGood(), {'flutter.a': 'c'});

      final r = begin().recovery!;

      expect(r.cause, StartupRecoveryCause.unreadableFile);
      expect(r.outcome, StartupRecoveryOutcome.restored);
      expect(r.failedStarts, 0);
      expect(r.lastGoodTime, isNotNull);
      expect(json.decode(settings().readAsStringSync()), {'flutter.a': 'c'});
      expect(failedCopies(), hasLength(1));
      expect(marker().readAsStringSync(), '1');
      expect(
          log.lines,
          anyElement(startsWith(
              '[GUARD] settings: 13 bytes, readable: no (FormatException at ')));
    });

    test('with crash detection off, the marker is left alone', () {
      writeJson(settings(), {'flutter.a': 'b'});
      writeJson(lastGood(), {'flutter.a': 'c'});
      final before = settings().readAsStringSync();
      marker().writeAsStringSync('1');

      final guard = begin(detectCrashes: false);

      expect(guard.recovery, isNull);
      expect(marker().readAsStringSync(), '1');
      expect(settings().readAsStringSync(), before);
      expect(failedCopies(), isEmpty);
    });

    test('only the three newest set-aside copies are kept', () {
      for (var i = 0; i < 4; i++) {
        settings().writeAsStringSync('{"cut short $i"');
        begin(detectCrashes: false, now: () => DateTime(2026, 11, 25, 8, 0, i));
      }

      expect(failedCopies(), [
        'shared_preferences.failed-20261125-080001-000-01.json',
        'shared_preferences.failed-20261125-080002-000-01.json',
        'shared_preferences.failed-20261125-080003-000-01.json',
      ]);
      expect(file(failedCopies().first).readAsStringSync(), '{"cut short 1"');
    });

    test('two set-asides in the same millisecond are both kept, the second '
        'sorting as newer', () {
      final t = DateTime(2026, 11, 25, 8);
      for (var i = 0; i < 2; i++) {
        settings().writeAsStringSync('{"cut short $i"');
        begin(detectCrashes: false, now: () => t);
      }

      final names = failedCopies();
      expect(names, [
        'shared_preferences.failed-20261125-080000-000-01.json',
        'shared_preferences.failed-20261125-080000-000-02.json',
      ]);
      expect(file(names.last).readAsStringSync(), '{"cut short 1"');
    });
  });

  group('finish', () {
    test('keeps the settings as they are at that moment', () {
      writeJson(settings(), {'flutter.a': 'b'});
      final guard = begin();
      writeJson(settings(), {'flutter.a': 'changed'});

      guard.finish();

      expect(json.decode(lastGood().readAsStringSync()),
          {'flutter.a': 'changed'});
      expect(file('shared_preferences.last_good.json.tmp').existsSync(),
          isFalse);
    });

    test('with no settings file, deletes the last good copy', () {
      writeJson(lastGood(), {'flutter.a': 'c'});
      final guard = begin();
      expect(lastGood().existsSync(), isTrue);

      guard.finish();

      expect(lastGood().existsSync(), isFalse);
    });

    test('deletes the marker, and runs only once', () {
      writeJson(settings(), {'flutter.a': 'b'});
      final guard = begin();
      expect(marker().existsSync(), isTrue);

      guard.finish();
      expect(marker().existsSync(), isFalse);

      marker().writeAsStringSync('5');
      final saved = lastGood().readAsStringSync();
      writeJson(settings(), {'flutter.a': 'later'});
      guard.finish();

      expect(marker().readAsStringSync(), '5');
      expect(lastGood().readAsStringSync(), saved);
      expect(log.lines.where((l) => l == '[GUARD] start finished'),
          hasLength(1));
    });

    test('a last good write that fails still deletes the marker', () {
      writeJson(settings(), {'flutter.a': 'b'});
      Directory(lastGood().path).createSync();
      final guard = begin();
      expect(marker().existsSync(), isTrue);

      guard.finish();

      expect(marker().existsSync(), isFalse);
      expect(
          log.lines,
          anyElement(startsWith(
              '[GUARD] save shared_preferences.last_good.json failed: ')));
      expect(file('shared_preferences.last_good.json.tmp').existsSync(),
          isFalse);
    });

    test('with crash detection off, only logs', () {
      writeJson(settings(), {'flutter.a': 'b'});
      marker().writeAsStringSync('1');
      final guard = begin(detectCrashes: false);

      guard.finish();

      expect(lastGood().existsSync(), isFalse);
      expect(marker().readAsStringSync(), '1');
      expect(log.lines.last, '[GUARD] start finished');
    });
  });

  group('failing file steps', () {
    test('a settings path that is a folder does not stop the start',
        () async {
      Directory(settings().path).createSync();

      final guard = begin();

      expect(log.lines, anyElement(matches(r'^\[GUARD\] .+ failed: ')));
      final prefs = await guard.openSettings();
      expect(prefs.getKeys(), isEmpty);
    });

    test('a set-aside that fails leaves the file in place, and the open '
        'error is logged', () async {
      const cutShort = '{"flutter.a":';
      settings().writeAsStringSync(cutShort);
      Process.runSync('chmod', ['555', dir.path]);
      addTearDown(() => Process.runSync('chmod', ['755', dir.path]));

      final guard = begin();

      expect(guard.recovery, isNull);
      expect(settings().readAsStringSync(), cutShort);
      expect(
          log.lines,
          anyElement(startsWith(
              '[GUARD] set aside shared_preferences.json failed: ')));
      await expectLater(guard.openSettings(), throwsA(isA<FormatException>()));
      expect(log.lines, contains('[GUARD] settings open failed: FormatException'));
    }, skip: _cannotBlockWrites ? 'needs chmod, and not root' : null);

    test('three unfinished starts and a failed set-aside keep the last good '
        'copy', () {
      settings().writeAsStringSync('{"flutter.a":"b"}');
      writeJson(lastGood(), {'flutter.a': 'c'});
      marker().writeAsStringSync('3');
      Process.runSync('chmod', ['555', dir.path]);
      addTearDown(() => Process.runSync('chmod', ['755', dir.path]));

      final guard = begin();

      expect(guard.recovery, isNull);
      expect(lastGood().existsSync(), isTrue);
      expect(settings().existsSync(), isTrue);
    }, skip: _cannotBlockWrites ? 'needs chmod, and not root' : null);

    for (final unfinished in [1, 2]) {
      test('$unfinished unfinished start(s) and a failed set-aside keep the '
          'settings and the last good copy', () {
        const text = '{"flutter.a":"b"}';
        settings().writeAsStringSync(text);
        writeJson(lastGood(), {'flutter.a': 'c'});
        marker().writeAsStringSync('$unfinished');
        Process.runSync('chmod', ['555', dir.path]);
        addTearDown(() => Process.runSync('chmod', ['755', dir.path]));

        final guard = begin();

        // Nothing is copied over a file that could not be moved.
        expect(guard.recovery, isNull);
        expect(settings().readAsStringSync(), text);
        expect(lastGood().existsSync(), isTrue);
        expect(failedCopies(), isEmpty);
      }, skip: _cannotBlockWrites ? 'needs chmod, and not root' : null);
    }
  });
}
