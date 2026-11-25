import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'startup_log.dart';

const _settingsName = 'shared_preferences.json';
const _markerName = 'startup_pending';
const _lastGoodName = 'shared_preferences.last_good.json';
const _lastGoodTmpName = 'shared_preferences.last_good.json.tmp';
const _keptFailedCopies = 3;
final _failedCopyName = RegExp(r'^shared_preferences\.failed-.+\.json$');

enum StartupRecoveryCause { unfinishedStart, unreadableFile }

enum StartupRecoveryOutcome { restored, startedEmpty, stillFailing }

class StartupRecovery {
  const StartupRecovery({
    required this.cause,
    required this.outcome,
    required this.folder,
    this.lastGoodTime,
    this.failedStarts = 0,
  });

  final StartupRecoveryCause cause;
  final StartupRecoveryOutcome outcome;

  /// The app support folder path.
  final String folder;

  /// Modification time of the restored last good copy.
  final DateTime? lastGoodTime;

  /// How many starts in a row did not finish, for an unfinished-start cause.
  final int failedStarts;
}

/// Set by main from [StartupGuard.recovery]; read and cleared once by the
/// notice widget.
StartupRecovery? pendingStartupRecovery;

/// Gets a desktop start past a settings file that stops it, on Windows and
/// Linux, where the settings live in a JSON file in the app support folder.
///
/// A marker file counts the starts that did not reach [finish]. After one,
/// the last good copy of the settings goes back in place; after two, the
/// start goes ahead with no settings. A file that does not read as a JSON
/// object is set aside at once. Every file step is guarded on its own: a
/// failure is logged and skipped, so the guard never stops a start.
class StartupGuard {
  StartupGuard._(this.dir, this.detectCrashes, this._log, this._now);

  factory StartupGuard.begin(
    Directory dir, {
    required bool detectCrashes,
    StartupLog? log,
    DateTime Function()? now,
  }) {
    final guard = StartupGuard._(dir, detectCrashes, log, now ?? DateTime.now);
    guard._crashCheck();
    guard._readabilityCheck();
    guard._recovery = guard._result();
    final r = guard._recovery;
    guard._note(r == null
        ? '[GUARD] recovery: none'
        : '[GUARD] recovery: ${r.cause.name}, ${r.outcome.name}');
    return guard;
  }

  final Directory dir;
  final bool detectCrashes;
  final StartupLog? _log;
  final DateTime Function() _now;
  StartupRecovery? _recovery;
  StartupRecovery? get recovery => _recovery;

  int _failedStarts = 0;
  StartupRecoveryOutcome? _crashOutcome;
  StartupRecoveryOutcome? _readOutcome;
  DateTime? _lastGoodTime;
  bool _finished = false;

  /// The first settings read in the process. Later `getInstance` calls get
  /// the cached instance.
  Future<SharedPreferences> openSettings() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e) {
      _note('[GUARD] settings open failed: ${e.runtimeType}');
      rethrow;
    }
  }

  /// Marks this start as finished and keeps the settings as the last good
  /// copy. Called once the app has run for a while after its first frame.
  void finish() {
    if (_finished) return;
    _finished = true;
    if (detectCrashes) {
      final settings = _read(_file(_settingsName));
      final lastGood = _file(_lastGoodName);
      if (settings.readable) {
        final tmp = _file(_lastGoodTmpName);
        final saved = _try('save $_lastGoodName', () {
          // Through a temp file, so a cut-short write never replaces a good
          // copy.
          tmp.writeAsBytesSync(settings.bytes!, flush: true);
          tmp.renameSync(lastGood.path);
        });
        if (saved) {
          _note('[GUARD] saved $_lastGoodName');
        } else {
          _try('delete $_lastGoodTmpName', () {
            if (tmp.existsSync()) tmp.deleteSync();
          });
        }
      } else if (!settings.exists) {
        _try('delete $_lastGoodName', () {
          if (!lastGood.existsSync()) return;
          lastGood.deleteSync();
          _note('[GUARD] no settings file, deleted $_lastGoodName');
        });
      } else {
        _note('[GUARD] settings unreadable at finish '
            '(${settings.describe()}), $_lastGoodName not updated');
      }
      // Even when the copy failed: a marker left behind would make the next
      // launch treat this finished start as a crash.
      _try('delete $_markerName', () {
        final marker = _file(_markerName);
        if (marker.existsSync()) marker.deleteSync();
      });
    }
    _note('[GUARD] start finished');
  }

  /// Spec step 2: count the starts that did not finish and act on them.
  void _crashCheck() {
    if (!detectCrashes) {
      _note('[GUARD] crash detection off');
      return;
    }
    final n = _readMarker();
    // Written before any recovery, so a crash during it counts as well.
    _try('write $_markerName', () {
      _file(_markerName).writeAsStringSync('${n + 1}', flush: true);
    });
    _note('[GUARD] start attempt ${n + 1}');
    if (n == 0) return;
    _failedStarts = n;
    _note('[GUARD] the last $n start(s) did not finish');
    if (n >= 3) {
      // Those starts already began with no settings, so the settings are not
      // what stops them.
      _note('[GUARD] settings left as they are');
      _crashOutcome = StartupRecoveryOutcome.stillFailing;
      return;
    }
    final lastGood = _file(_lastGoodName);
    final hasLastGood = _exists(lastGood);
    if (hasLastGood) {
      _logKeyChanges();
    } else {
      _note('[GUARD] no $_lastGoodName to compare');
    }
    final placeFree = _setAside();
    if (n == 1 && hasLastGood) {
      if (placeFree && _restoreLastGood()) {
        _crashOutcome = StartupRecoveryOutcome.restored;
      } else if (placeFree) {
        _crashOutcome = StartupRecoveryOutcome.startedEmpty;
      }
      return;
    }
    // A settings file that could not be set aside is still in place, so the
    // last good copy stays: it is the only known-good backup.
    if (!placeFree) return;
    if (hasLastGood) {
      _try('delete $_lastGoodName', () {
        lastGood.deleteSync();
        _note('[GUARD] deleted $_lastGoodName');
      });
    }
    _crashOutcome = StartupRecoveryOutcome.startedEmpty;
  }

  /// Spec step 3: a settings file the store cannot read is set aside now,
  /// in this launch.
  void _readabilityCheck() {
    final settings = _read(_file(_settingsName));
    _note('[GUARD] settings: ${settings.describe()}');
    if (!settings.exists || settings.readable) return;
    if (!_setAside()) return;
    final lastGood = _read(_file(_lastGoodName));
    if (lastGood.readable && _restoreLastGood()) {
      _readOutcome = StartupRecoveryOutcome.restored;
      return;
    }
    if (lastGood.exists && !lastGood.readable) {
      _note('[GUARD] $_lastGoodName: ${lastGood.describe()}');
    }
    _readOutcome = StartupRecoveryOutcome.startedEmpty;
  }

  /// Spec step 4: one cause and one outcome per launch.
  StartupRecovery? _result() {
    final crash = _crashOutcome;
    final read = _readOutcome;
    if (crash == null && read == null) return null;
    final outcome = crash == StartupRecoveryOutcome.stillFailing
        ? crash!
        : (read ?? crash!);
    return StartupRecovery(
      cause: crash != null
          ? StartupRecoveryCause.unfinishedStart
          : StartupRecoveryCause.unreadableFile,
      outcome: outcome,
      folder: dir.path,
      lastGoodTime:
          outcome == StartupRecoveryOutcome.restored ? _lastGoodTime : null,
      failedStarts: crash != null ? _failedStarts : 0,
    );
  }

  /// Missing means the last start finished. Anything else that is not a
  /// whole number of one or more still means a start did not finish.
  int _readMarker() {
    var n = 0;
    final ok = _try('read $_markerName', () {
      final marker = _file(_markerName);
      if (!marker.existsSync()) return;
      final value = int.tryParse(marker.readAsStringSync().trim());
      n = value != null && value >= 1 ? value : 1;
    });
    return ok ? n : 1;
  }

  /// Moves the settings file to a new `failed-…` name. True when no
  /// settings file is left in place: a restore must never overwrite a file
  /// that could not be set aside.
  bool _setAside() {
    final settings = _file(_settingsName);
    var moved = false;
    final ok = _try('set aside $_settingsName', () {
      if (FileSystemEntity.typeSync(settings.path) ==
          FileSystemEntityType.notFound) {
        return;
      }
      final stamp = _stamp(_now());
      var counter = 1;
      while (counter < 99 &&
          _file(_failedName(stamp, counter)).existsSync()) {
        counter++;
      }
      final name = _failedName(stamp, counter);
      settings.renameSync(_file(name).path);
      moved = true;
      _note('[GUARD] set aside $_settingsName as $name');
    });
    if (moved) _pruneFailedCopies();
    return ok;
  }

  void _pruneFailedCopies() {
    _try('list set-aside copies', () {
      final names = dir
          .listSync()
          .map((e) => p.basename(e.path))
          .where(_failedCopyName.hasMatch)
          .toList()
        ..sort((a, b) => b.compareTo(a));
      for (final name in names.skip(_keptFailedCopies)) {
        _try('delete $name', () {
          _file(name).deleteSync();
          _note('[GUARD] deleted $name');
        });
      }
    });
  }

  /// Copies, not moves, so a failed copy loses nothing.
  bool _restoreLastGood() {
    final lastGood = _file(_lastGoodName);
    return _try('restore $_lastGoodName', () {
      final time = lastGood.lastModifiedSync();
      lastGood.copySync(_file(_settingsName).path);
      _lastGoodTime = time;
      _note('[GUARD] restored $_settingsName from $_lastGoodName');
    });
  }

  /// Key names only: a value can be a sign-in session or an API key.
  void _logKeyChanges() {
    final now = _read(_file(_settingsName));
    final good = _read(_file(_lastGoodName));
    final current = now.map;
    final kept = good.map;
    if (current == null || kept == null) {
      _note('[GUARD] keys not compared: $_settingsName ${now.state}, '
          '$_lastGoodName ${good.state}');
      return;
    }
    String names(Iterable<String> keys) {
      final sorted = keys.toList()..sort();
      return sorted.isEmpty ? 'none' : sorted.join(', ');
    }

    final added = current.keys.where((k) => !kept.containsKey(k));
    final removed = kept.keys.where((k) => !current.containsKey(k));
    final changed = current.keys.where((k) =>
        kept.containsKey(k) && jsonEncode(current[k]) != jsonEncode(kept[k]));
    _note('[GUARD] keys added since the last good copy: ${names(added)}');
    _note('[GUARD] keys removed since the last good copy: ${names(removed)}');
    _note('[GUARD] keys changed since the last good copy: ${names(changed)}');
  }

  /// Runs one file step. A failure logs the error type, never the message
  /// (it can quote a settings value), and returns false.
  bool _try(String action, void Function() op) {
    try {
      op();
      return true;
    } catch (e) {
      _note('[GUARD] $action failed: ${e.runtimeType}');
      return false;
    }
  }

  bool _exists(File f) {
    var exists = false;
    _try('check ${p.basename(f.path)}', () => exists = f.existsSync());
    return exists;
  }

  File _file(String name) => File(p.join(dir.path, name));

  void _note(String line) => _log?.write(line);
}

String _failedName(String stamp, int counter) =>
    'shared_preferences.failed-$stamp-${counter.toString().padLeft(2, '0')}.json';

/// Local time with milliseconds, so names sort in the order they were made.
String _stamp(DateTime t) {
  String pad(int v, [int width = 2]) => v.toString().padLeft(width, '0');
  return '${pad(t.year, 4)}${pad(t.month)}${pad(t.day)}-'
      '${pad(t.hour)}${pad(t.minute)}${pad(t.second)}-'
      '${pad(t.millisecond, 3)}';
}

/// What reading a settings file gave. [error] holds the error type, plus the
/// offset for a [FormatException]; never the message.
class _SettingsRead {
  const _SettingsRead({this.exists = true, this.bytes, this.map, this.error});

  final bool exists;
  final List<int>? bytes;
  final Map<String, Object?>? map;
  final String? error;

  bool get readable => map != null;

  String get state => !exists
      ? 'missing'
      : readable
          ? 'readable'
          : 'unreadable';

  String describe() {
    if (!exists) return 'missing';
    final result = readable ? 'yes' : 'no ($error)';
    return '${bytes?.length ?? '?'} bytes, readable: $result, '
        'keys: ${map?.length ?? '-'}';
  }
}

/// Strict UTF-8, as the settings store reads it; it must give a JSON object.
/// An empty file fails too: it is what a write cut short leaves.
_SettingsRead _read(File f) {
  final List<int> bytes;
  try {
    if (FileSystemEntity.typeSync(f.path) == FileSystemEntityType.notFound) {
      return const _SettingsRead(exists: false);
    }
    bytes = f.readAsBytesSync();
  } catch (e) {
    return _SettingsRead(error: '${e.runtimeType}');
  }
  try {
    final data = json.decode(utf8.decode(bytes));
    if (data is Map<String, Object?>) {
      return _SettingsRead(bytes: bytes, map: data);
    }
    return _SettingsRead(bytes: bytes, error: 'not a JSON object');
  } on FormatException catch (e) {
    final at = e.offset == null ? '' : ' at ${e.offset}';
    return _SettingsRead(bytes: bytes, error: 'FormatException$at');
  } catch (e) {
    return _SettingsRead(bytes: bytes, error: '${e.runtimeType}');
  }
}
