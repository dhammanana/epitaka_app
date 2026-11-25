import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/utils/app_version.g.dart';
import '../../core/utils/startup_timing.dart';

const _logName = 'startup.log';
const _prevLogName = 'startup.prev.log';
const _maxLines = 500;

/// A small log of each desktop start in the app support folder. A Windows
/// release build has no console, so this is the only record a user can
/// send. It holds error types and stack lines, never a settings value or an
/// error message, which can quote one.
class StartupLog {
  File? _file;
  int _lines = 0;

  bool get isOpen => _file != null;

  /// Keeps the previous start's log as `startup.prev.log`, then starts a new
  /// one with a header and the timing lines made so far.
  void open(Directory dir, {DateTime Function()? now}) {
    final log = File(p.join(dir.path, _logName));
    final prev = File(p.join(dir.path, _prevLogName));
    try {
      if (log.existsSync()) {
        try {
          log.renameSync(prev.path);
        } on FileSystemException {
          if (prev.existsSync()) prev.deleteSync();
          log.renameSync(prev.path);
        }
      }
      log.writeAsStringSync('', flush: true);
    } catch (_) {
      return;
    }
    _file = log;
    _lines = 0;
    final time = (now ?? DateTime.now)();
    write('[HEADER] ${time.toIso8601String()} '
        'ePitaka $kPubspecAppVersion+$kPubspecAppBuildNumber '
        '${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    StartupTiming.lines.forEach(write);
    StartupTiming.sink = write;
  }

  /// Appends with a flush, so the last line before a hard crash is on disk.
  void write(String line) {
    final file = _file;
    if (file == null || _lines > _maxLines) return;
    final text = _lines == _maxLines ? '[LOG] limit reached' : line;
    try {
      file.writeAsStringSync('$text\n', mode: FileMode.append, flush: true);
      _lines++;
    } catch (_) {
      _file = null;
    }
  }

  /// The error's type and the top of its stack. Release builds are not
  /// obfuscated, so the stack names the failing code.
  void error(Object error, StackTrace? stack) {
    write('[ERROR] ${error.runtimeType}');
    if (stack == null) return;
    final frames = stack
        .toString()
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .take(10);
    for (final frame in frames) {
      write('[ERROR]   $frame');
    }
  }
}

final startupLog = StartupLog();
