import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sqlite3/sqlite3.dart';

/// One paragraph found by [scanPaliRegex].
typedef RegexHit = ({String bookId, int paraId});

/// The pattern as every rx box runs it: case does not matter, diacritics do
/// (`ā` matches only `ā`).
RegExp compileSearchRegex(String pattern) =>
    RegExp(pattern, caseSensitive: false, unicode: true);

/// `null` when [pattern] compiles, otherwise why it does not.
String? regexError(String pattern) {
  try {
    compileSearchRegex(pattern);
    return null;
  } on FormatException catch (e) {
    return e.message;
  }
}

/// How long an in-memory regex job may run before it is ended as too slow.
const kRegexTimeLimit = Duration(seconds: 3);

/// How long the main Search scan may run. A normal scan of the whole canon
/// takes about 1 s on a desktop and on a Pixel 8 Pro.
const kRegexScanTimeLimit = Duration(seconds: 10);

/// A regex job ran past its time limit. A nested repeat such as `(a+)+`
/// backtracks exponentially, and one check can take minutes.
class RegexTooSlow implements Exception {
  const RegexTooSlow();

  @override
  String toString() => 'Pattern too slow';
}

/// A regex job was cancelled before it answered: a new query, Clear, or the
/// box closed.
class RegexCancelled implements Exception {
  const RegexCancelled();

  @override
  String toString() => 'Regex job cancelled';
}

/// A regex match running in its own isolate, so a runaway pattern never
/// freezes the screen. One regex check cannot be interrupted in Dart, so a
/// cancel and the time limit kill the isolate.
class RegexJob<T> {
  RegexJob._(this._killOnCancel) {
    // A cancel or "too slow" that no caller awaits is expected, not a crash:
    // unhandled, it would reach the app's fatal error reporting.
    _done.future.ignore();
  }

  final bool _killOnCancel;
  final _done = Completer<T>();
  final _port = ReceivePort();
  Isolate? _isolate;
  Timer? _hardLimit;
  bool _killed = false;

  /// The answer; throws [RegexTooSlow] or [RegexCancelled] instead.
  Future<T> get result => _done.future;

  bool get isDone => _done.isCompleted;

  /// Drop the answer. The isolate is killed too, unless it holds a database
  /// (see [scanPaliRegex]): that one ends on its own time limit, and the
  /// hard limit still kills it if it is stuck.
  void cancel() {
    _answer(error: const RegexCancelled());
    if (_killOnCancel) _kill();
  }

  void _answer({Object? error, T? value}) {
    if (_done.isCompleted) return;
    if (error != null) {
      _done.completeError(error);
    } else {
      _done.complete(value as T);
    }
  }

  void _kill() {
    _killed = true;
    _isolate?.kill(priority: Isolate.immediate);
    _ended();
  }

  /// The isolate is gone: stop listening, drop the hard limit.
  void _ended() {
    _hardLimit?.cancel();
    _port.close();
  }
}

/// Run [work] as a [RegexJob]. Past [hardLimit] the isolate is killed and
/// the job ends with [RegexTooSlow]. [work] may throw [RegexTooSlow] itself
/// to stop early. With [killOnCancel] off, [RegexJob.cancel] only drops the
/// answer.
RegexJob<T> startRegexJob<T>(
  T Function() work, {
  Duration hardLimit = kRegexTimeLimit,
  bool killOnCancel = true,
}) {
  final job = RegexJob<T>._(killOnCancel);
  job._port.listen((message) {
    // (kind, value) from the job, or null when the isolate exits; the VM
    // sends the exit last.
    if (message is! (String, Object?)) {
      // Ended without an answer: killed, or something went wrong.
      job._answer(
        error: job._killed
            ? const RegexCancelled()
            : StateError('Regex job ended without an answer'),
      );
      job._ended();
      return;
    }
    switch (message.$1) {
      case 'ok':
        job._answer(value: message.$2 as T);
      case 'slow':
        job._answer(error: const RegexTooSlow());
      default:
        job._answer(error: StateError('${message.$2}'));
    }
  });
  job._hardLimit = Timer(hardLimit, () {
    job._answer(error: const RegexTooSlow());
    job._kill();
  });
  Isolate.spawn(_runJob<T>, (
    job._port.sendPort,
    work,
  ), onExit: job._port.sendPort).then(
    (isolate) {
      job._isolate = isolate;
      // Killed while the isolate was starting.
      if (job._killed) isolate.kill(priority: Isolate.immediate);
    },
    onError: (Object e) {
      job._answer(error: e);
      job._ended();
    },
  );
  return job;
}

void _runJob<T>((SendPort, T Function()) message) {
  final (port, work) = message;
  try {
    port.send(('ok', work()));
  } on RegexTooSlow {
    port.send(('slow', null));
  } catch (e) {
    port.send(('error', '$e'));
  }
}

/// The indices of [items] with a text [pattern] matches (an item is one
/// entry's texts: a title, or a line's Pāli and translations, so `^` and
/// `$` mean one text), and with [maxPieces], up to that many distinct
/// pieces of text it matched, for highlighting.
({List<int> hits, List<String> pieces}) matchRegexItems(
  String pattern,
  List<List<String>> items, {
  int maxPieces = 0,
}) {
  final regex = compileSearchRegex(pattern);
  final hits = <int>[];
  final pieces = <String>{};
  for (var i = 0; i < items.length; i++) {
    var matched = false;
    for (final text in items[i]) {
      if (maxPieces == 0) {
        if (regex.hasMatch(text)) {
          matched = true;
          break;
        }
        continue;
      }
      for (final m in regex.allMatches(text)) {
        matched = true;
        if (m.end > m.start && pieces.length < maxPieces) pieces.add(m[0]!);
      }
    }
    if (matched) hits.add(i);
  }
  return (hits: hits, pieces: pieces.toList());
}

/// [matchRegexItems] as a [RegexJob], ended as too slow after [limit].
RegexJob<({List<int> hits, List<String> pieces})> startRegexMatch(
  String pattern,
  List<List<String>> items, {
  int maxPieces = 0,
  Duration limit = kRegexTimeLimit,
}) => startRegexJob(
  () => matchRegexItems(pattern, items, maxPieces: maxPieces),
  hardLimit: limit,
);

/// A live list filter for a box with Rx on. It runs the pattern over the
/// list's texts as a [RegexJob] and keeps the last answer; [onChange] runs
/// when an answer or "too slow" arrives, so the box can redraw. Typing
/// again, or an empty pattern, cancels the running job.
class RegexListFilter {
  RegexListFilter(this.onChange);

  final void Function() onChange;

  String _pattern = '';
  Object? _source;
  RegexJob<({List<int> hits, List<String> pieces})>? _job;
  Set<int>? _hits;

  /// The pattern whose job ran past its time limit.
  String? _slowPattern;

  /// [pattern]'s job ran past its time limit. Asked with the box's current
  /// text, so an earlier pattern's "too slow" never lingers.
  bool isTooSlow(String pattern) =>
      pattern.isNotEmpty && pattern == _slowPattern;

  @visibleForTesting
  RegexJob<Object?>? get runningJob => _job;

  /// The indices of the items that [pattern] matches. While a new job runs,
  /// the last answer for the same [source] (identity) stays, so the list
  /// does not flash empty; `null` before the first answer. [items] builds
  /// the texts per item and is called only when a job starts.
  Set<int>? hitsFor(
    String pattern,
    Object source,
    List<List<String>> Function() items,
  ) {
    if (pattern == _pattern && identical(source, _source)) return _hits;
    _job?.cancel();
    _job = null;
    if (!identical(source, _source)) _hits = null;
    _pattern = pattern;
    _source = source;
    _slowPattern = null;
    if (pattern.isEmpty || regexError(pattern) != null) return _hits;
    final job = _job = startRegexMatch(pattern, items());
    job.result.then(
      (r) {
        if (!identical(_job, job)) return;
        _hits = r.hits.toSet();
        onChange();
      },
      onError: (Object e) {
        if (!identical(_job, job) || e is! RegexTooSlow) return;
        _slowPattern = pattern;
        onChange();
      },
    );
    return _hits;
  }

  /// Forget the pattern and cancel the job (Rx off, the box cleared).
  void reset() {
    _job?.cancel();
    _job = null;
    _pattern = '';
    _source = null;
    _hits = null;
    _slowPattern = null;
  }

  void dispose() => _job?.cancel();
}

/// Every paragraph whose Pāli search copy in `search_fts` matches
/// [pattern], in index order, as a [RegexJob].
///
/// The scan reads all 471,658 rows (about 1 s on a desktop), so it runs in
/// its own isolate on its own read-only connection to [dbPath]. On desktop
/// the app's Drift connection runs on the main isolate, and the window would
/// freeze for the whole scan.
///
/// The pattern runs in Dart on rows read with a cursor, not as a `regexp`
/// function SQLite calls back: killing an isolate inside that callback
/// crashes the app. The scan checks [limit] between rows and stops itself,
/// closing the database. Cancelling only drops the answer, because a killed
/// scan leaves its connection open (about 2 file handles); the kill comes 2 s
/// past [limit], for a pattern stuck on one row. A nested repeat sticks on
/// any row of six or more words, so a runaway scan usually ends there.
RegexJob<List<RegexHit>> scanPaliRegex(
  String dbPath,
  String pattern, {
  Duration limit = kRegexScanTimeLimit,
}) => startRegexJob(
  () => _scan(dbPath, pattern, limit),
  hardLimit: limit + const Duration(seconds: 2),
  killOnCancel: false,
);

List<RegexHit> _scan(String dbPath, String pattern, Duration limit) {
  final clock = Stopwatch()..start();
  final regex = compileSearchRegex(pattern);
  final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
  try {
    final statement = db.prepare(
      'SELECT book_id, para_id, pali_text FROM search_fts ORDER BY rowid',
    );
    try {
      final rows = statement.selectCursor();
      final hits = <RegexHit>[];
      while (rows.moveNext()) {
        if (clock.elapsed > limit) throw const RegexTooSlow();
        final row = rows.current;
        final text = row.columnAt(2);
        if (text is String && regex.hasMatch(text)) {
          hits.add((
            bookId: row.columnAt(0) as String,
            paraId: row.columnAt(1) as int,
          ));
        }
      }
      return hits;
    } finally {
      statement.dispose();
    }
  } finally {
    db.dispose();
  }
}
