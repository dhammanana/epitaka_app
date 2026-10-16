import 'dart:async';
import 'dart:io' show ProcessInfo;
import 'dart:ui' show FrameTiming, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Percentiles and over-budget count for one batch of frames.
class FrameSummary {
  const FrameSummary({
    required this.frames,
    required this.buildP50,
    required this.buildP90,
    required this.buildMax,
    required this.rasterP50,
    required this.rasterP90,
    required this.rasterMax,
    required this.over,
  });

  final int frames;
  final int buildP50, buildP90, buildMax;
  final int rasterP50, rasterP90, rasterMax;

  /// Frames where build or raster took longer than the frame budget.
  final int over;
}

/// Summary of parallel build/raster durations (one entry per frame).
/// Percentiles use the nearest-rank rule: the smallest value with at least
/// p percent of the frames at or below it.
FrameSummary summarizeFrames(
  List<Duration> build,
  List<Duration> raster,
  Duration budget,
) {
  assert(build.length == raster.length);
  int pct(List<Duration> d, double p) {
    final sorted = d.map((x) => x.inMilliseconds).toList()..sort();
    final rank = (p * sorted.length).ceil().clamp(1, sorted.length);
    return sorted[rank - 1];
  }

  var over = 0;
  for (var i = 0; i < build.length; i++) {
    if (build[i] > budget || raster[i] > budget) over++;
  }
  return FrameSummary(
    frames: build.length,
    buildP50: pct(build, 0.5),
    buildP90: pct(build, 0.9),
    buildMax: pct(build, 1.0),
    rasterP50: pct(raster, 0.5),
    rasterP90: pct(raster, 0.9),
    rasterMax: pct(raster, 1.0),
    over: over,
  );
}

/// Prints one `[PERF] frames` line every 5 s while frames are being drawn.
/// Started from `main()` in profile and debug builds only, so release builds
/// pay nothing for it.
class FrameStats {
  FrameStats._();

  static final List<Duration> _build = [];
  static final List<Duration> _raster = [];
  static bool _started = false;

  static void start() {
    if (_started) return;
    _started = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    Timer.periodic(const Duration(seconds: 5), (_) => _flush());
  }

  static void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _build.add(t.buildDuration);
      _raster.add(t.rasterDuration);
    }
  }

  static void _flush() {
    if (_build.isEmpty) return;
    final budget = _budget();
    final s = summarizeFrames(_build, _raster, budget);
    _build.clear();
    _raster.clear();
    debugPrint(
      '[PERF] frames n=${s.frames} '
      'build p50/p90/max=${s.buildP50}/${s.buildP90}/${s.buildMax} '
      'raster p50/p90/max=${s.rasterP50}/${s.rasterP90}/${s.rasterMax} '
      'over=${s.over} budgetMs=${budget.inMilliseconds} '
      'rssMB=${ProcessInfo.currentRss >> 20}',
    );
  }

  static Duration _budget() {
    final displays = PlatformDispatcher.instance.displays;
    final hz = displays.isEmpty ? 60.0 : displays.first.refreshRate;
    return Duration(microseconds: (1000000 / (hz > 0 ? hz : 60)).round());
  }
}
