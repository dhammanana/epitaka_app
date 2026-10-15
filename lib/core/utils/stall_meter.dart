import 'dart:async';

/// Measures how long the main isolate was busy while the meter ran: a 1 ms
/// timer should tick on time, so each late tick is time spent on other work.
/// Unlike frame timings, it also sees work that runs between frames (an
/// awaited load, a timer callback).
class StallMeter {
  StallMeter() {
    _timer = Timer.periodic(const Duration(milliseconds: 1), (_) => _tick());
  }

  final Stopwatch _sw = Stopwatch()..start();
  late final Timer _timer;
  int _lastUs = 0;
  int _busyUs = 0;
  int _maxGapUs = 0;

  void _tick() {
    final now = _sw.elapsedMicroseconds;
    final gap = now - _lastUs;
    _lastUs = now;
    // Under 2 ms is ordinary timer jitter, not work.
    if (gap > 2000) _busyUs += gap - 1000;
    if (gap > _maxGapUs) _maxGapUs = gap;
  }

  /// Stops the meter: the busy time and the longest gap between ticks, in
  /// milliseconds.
  ({int busyMs, int maxGapMs}) stop() {
    _timer.cancel();
    _tick();
    return (busyMs: _busyUs ~/ 1000, maxGapMs: _maxGapUs ~/ 1000);
  }
}
