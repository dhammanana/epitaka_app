import 'package:flutter/foundation.dart';

/// Lightweight startup stopwatch that reports how long each phase from
/// process start to the first opened book takes.
///
/// [StartupTiming.start] is called at the very top of `main()`; every
/// [StartupTiming.mark] then prints the elapsed milliseconds since then:
///
/// ```
/// [STARTUP] +     0ms  main() entered
/// [STARTUP] +   412ms  first frame painted
/// [STARTUP] +   980ms  databases ready (copies + migration)
/// [STARTUP] +  1320ms  index check done (ready)
/// [STARTUP] +  2100ms  book open requested: Vin-i
/// [STARTUP] +  2640ms  book loaded: Vin-i (loadMs=540, paras=2475)
/// [STARTUP] +  2705ms  book first visible: Vin-i
/// ```
///
/// Uses [debugPrint] rather than `developer.log`: the Flutter engine does not
/// forward `developer.log` output to the console (the app's `[LOAD]`/`[TAB_SW]`
/// logs are only visible in DevTools), whereas `debugPrint` *is* shown. That
/// makes this timeline readable from the plain `flutter run` console.
///
/// A monotonic [Stopwatch] plus one line per milestone is cheap enough to
/// leave enabled in release builds.
class StartupTiming {
  StartupTiming._();

  static final Stopwatch _sw = Stopwatch();
  static bool _started = false;

  /// Start the clock. No-op if already started, so it is safe to call from
  /// more than one entry point.
  static void start() {
    if (_started) return;
    _started = true;
    _sw.start();
  }

  /// Print [label] with the elapsed time since [start], starting the clock on
  /// first use if [start] was not called explicitly.
  static void mark(String label) {
    if (!_started) start();
    debugPrint(
      '[STARTUP] +${_sw.elapsedMilliseconds.toString().padLeft(6)}ms  $label',
    );
  }

  /// Elapsed milliseconds since [start].
  static int get elapsedMs => _sw.elapsedMilliseconds;
}
