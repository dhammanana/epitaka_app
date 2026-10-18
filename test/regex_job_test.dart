/// The shared regex job (spec K): every Rx match runs in its own isolate,
/// so a runaway pattern ends as "too slow" or on a cancel instead of
/// freezing the screen.
library;

import 'dart:isolate';

import 'package:epitaka/features/search/services/regex_search.dart';
import 'package:flutter_test/flutter_test.dart';

/// DN 1's opening line, 7 words: `([^ ]+ ?)+x` backtracks on it for about
/// 30 s per check (6 words: about 5 s).
const _line = 'evaṃ me sutaṃ ekaṃ samayaṃ bhagavā antarā';
const _runaway = r'([^ ]+ ?)+x';

void main() {
  test(
    'a normal pattern answers with the items and pieces it matched',
    () async {
      final r = await startRegexMatch('yaṃ|sut', [
        [_line],
        ['bhikkhave'],
        ['no', 'samayaṃ ca'],
      ], maxPieces: 5).result;
      expect(r.hits, [0, 2]);
      expect(r.pieces.toSet(), {'sut', 'yaṃ'});
    },
  );

  test('a runaway pattern ends as too slow at the time limit', () async {
    final clock = Stopwatch()..start();
    final job = startRegexMatch(_runaway, [
      [_line],
    ], limit: const Duration(milliseconds: 300));
    await expectLater(job.result, throwsA(isA<RegexTooSlow>()));
    expect(clock.elapsed, lessThan(const Duration(seconds: 3)));
  });

  test('a cancel ends a runaway job at once', () async {
    final job = startRegexMatch(_runaway, [
      [_line],
    ]);
    final clock = Stopwatch()..start();
    job.cancel();
    await expectLater(job.result, throwsA(isA<RegexCancelled>()));
    expect(clock.elapsed, lessThan(const Duration(seconds: 1)));
  });

  test('the list filter keeps its last answer while a new job runs', () async {
    var changes = 0;
    final filter = RegexListFilter(() => changes++);
    addTearDown(filter.dispose);
    final source = Object();
    List<List<String>> items() => [
      [_line],
      ['bhikkhave'],
    ];

    expect(filter.hitsFor('bhikkh', source, items), isNull);
    await pumpUntil(() => changes == 1);
    expect(filter.hitsFor('bhikkh', source, items), {1});

    // A new pattern keeps the last answer until its own arrives.
    expect(filter.hitsFor('sutaṃ', source, items), {1});
    await pumpUntil(() => changes == 2);
    expect(filter.hitsFor('sutaṃ', source, items), {0});
    expect(filter.isTooSlow('sutaṃ'), isFalse);
  });

  test('a cancel nobody awaits is no uncaught error', () async {
    // The test fails on an uncaught async error, as the app reports one as
    // a fatal crash.
    startRegexMatch(_runaway, [
      [_line],
    ]).cancel();
    startRegexMatch(_runaway, [
      [_line],
    ], limit: const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 600));
  });

  test(
    'a job that exits without an answer is an error, not a cancel',
    () async {
      final job = startRegexJob<int>(() => Isolate.exit());
      await expectLater(job.result, throwsA(isA<StateError>()));
    },
  );

  test('the list filter kills its job when the box empties', () async {
    final filter = RegexListFilter(() {});
    addTearDown(filter.dispose);
    final source = Object();
    filter.hitsFor(
      _runaway,
      source,
      () => [
        [_line],
      ],
    );
    final job = filter.runningJob!;
    final clock = Stopwatch()..start();
    filter.hitsFor('', source, () => const []);
    await expectLater(job.result, throwsA(isA<RegexCancelled>()));
    expect(clock.elapsed, lessThan(const Duration(seconds: 1)));
  });

  test('the list filter reports too slow for that pattern only', () async {
    var changes = 0;
    final filter = RegexListFilter(() => changes++);
    addTearDown(filter.dispose);
    final source = Object();
    filter.hitsFor(
      _runaway,
      source,
      () => [
        [_line],
      ],
    );
    await pumpUntil(() => changes == 1, seconds: 5);
    expect(filter.isTooSlow(_runaway), isTrue);
    expect(filter.isTooSlow('sutaṃ'), isFalse);
  });
}

Future<void> pumpUntil(bool Function() done, {int seconds = 3}) async {
  for (var i = 0; i < seconds * 100 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(done(), isTrue, reason: 'timed out after $seconds s');
}
