/// Debug-only timing instrumentation for search performance benchmarking.
/// 
/// This module provides utilities to measure query execution time, 
/// rendering time, and overall search pipeline performance.
/// 
/// To enable timing, set [enableSearchTiming] to true.
/// All timing is disabled by default to avoid production overhead.
library;

import 'dart:developer' as developer;

/// Global flag to enable/disable search timing instrumentation.
/// Set to true during benchmarking, false for normal operation.
bool enableSearchTiming = false;

/// Stores timing data for a single search operation.
class SearchTimingData {
  /// Query execution times in milliseconds
  final Map<String, Duration> queryTimes = {};
  
  /// Rendering start time
  DateTime? renderStartTime;
  
  /// Total render time
  Duration? renderTime;
  
  /// Total search pipeline time (from query to first render)
  Duration? totalSearchTime;
  
  /// The query string being timed
  final String query;
  
  /// Timestamp when search started
  final DateTime startedAt;
  
  SearchTimingData({required this.query}) : startedAt = DateTime.now();
  
  void recordQueryTime(String operation, Duration duration) {
    queryTimes[operation] = duration;
  }
  
  void startRenderTimer() {
    renderStartTime = DateTime.now();
  }
  
  void endRenderTimer() {
    if (renderStartTime != null) {
      renderTime = DateTime.now().difference(renderStartTime!);
    }
  }
  
  void recordTotalSearchTime(Duration duration) {
    totalSearchTime = duration;
  }
  
  /// Format timing data for display
  String toSummaryString() {
    final buffer = StringBuffer();
    buffer.writeln('=== Search Timing: "$query" ===');
    buffer.writeln('Total search time: ${totalSearchTime?.inMilliseconds}ms');
    buffer.writeln('Query times:');
    for (final entry in queryTimes.entries) {
      buffer.writeln('  ${entry.key}: ${entry.value.inMilliseconds}ms');
    }
    if (renderTime != null) {
      buffer.writeln('Render time: ${renderTime!.inMilliseconds}ms');
    }
    buffer.writeln('===========================');
    return buffer.toString();
  }
  
  /// Format as a compact single-line string for console output
  String toCompactString() {
    final queryTimesSum = queryTimes.values.fold<int>(
      0,
      (sum, d) => sum + d.inMilliseconds,
    );
    return 'SEARCH "$query": '
        'total=${totalSearchTime?.inMilliseconds ?? "?"}ms, '
        'queries=${queryTimesSum}ms, '
        'render=${renderTime?.inMilliseconds ?? "?"}ms';
  }
}

/// Global collector for timing data (cleared between benchmark runs).
List<SearchTimingData> timingLog = [];

/// Record a timing data point.
void recordTiming(SearchTimingData data) {
  timingLog.add(data);
  if (enableSearchTiming) {
    developer.log(data.toCompactString(), name: 'search-timing');
  }
}

/// Clear all recorded timing data.
void clearTimingLog() {
  timingLog.clear();
}

/// Get timing data summarized for the last N searches.
String getLastTimings({int count = 5}) {
  final recent = timingLog.length > count
      ? timingLog.sublist(timingLog.length - count)
      : timingLog;
  
  final buffer = StringBuffer();
  buffer.writeln('\n=== Recent Search Timings (last $count) ===');
  for (final data in recent) {
    buffer.writeln(data.toSummaryString());
  }
  return buffer.toString();
}

/// Wrapper to time an async operation.
Future<T> timeAsync<T>(
  String operationName,
  Future<T> Function() operation,
) async {
  if (!enableSearchTiming) {
    return operation();
  }
  
  final sw = Stopwatch()..start();
  final result = await operation();
  sw.stop();
  
  developer.log('$operationName: ${sw.elapsedMilliseconds}ms', name: 'search-timing');
  return result;
}
