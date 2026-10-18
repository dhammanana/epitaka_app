import 'package:epitaka/core/utils/frame_stats.dart';
import 'package:flutter_test/flutter_test.dart';

List<Duration> ms(List<int> v) => [for (final x in v) Duration(milliseconds: x)];

void main() {
  test('summarizeFrames gives nearest-rank percentiles, max and over count', () {
    // Ten frames: build 1..10 ms, raster 10, 20, ..., 100 ms.
    final build = ms([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    final raster = ms([10, 20, 30, 40, 50, 60, 70, 80, 90, 100]);
    final s = summarizeFrames(build, raster, const Duration(milliseconds: 16));

    expect(s.frames, 10);
    expect(s.buildP50, 5);
    expect(s.buildP90, 9);
    expect(s.buildMax, 10);
    expect(s.rasterP50, 50);
    expect(s.rasterP90, 90);
    expect(s.rasterMax, 100);
    // Raster is over 16 ms from the second frame on: 9 frames.
    expect(s.over, 9);
  });

  test('a frame counts once when both build and raster are over budget', () {
    final s = summarizeFrames(
      ms([30, 5]),
      ms([40, 5]),
      const Duration(milliseconds: 16),
    );
    expect(s.over, 1);
  });
}
