import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/app_db_provider.dart';
import '../../core/utils/startup_timing.dart';
import '../settings/services/download_foreground_service.dart';
import '../settings/services/download_notification_service.dart';
import 'index_service.dart';
import 'index_state.dart';

final indexServiceProvider = Provider<IndexService>((ref) => IndexService(ref));

/// Owns index state for the whole app. The constructor does NOT check or
/// build anything — nothing happens until something explicitly calls
/// `checkStatus()` (cheap, read-only, safe to call anytime) or
/// `buildIndex()` (only ever call this in direct response to a user
/// action — a "Build now" button in `IndexBuildDialog`).
///
/// This is the ONE place that calls `buildSearchIndex` /
/// `buildTranslationSearchIndex`. `search_provider.dart` no longer builds
/// anything itself — it just reads this controller's state and, if it's
/// an `IndexNeedsBuild` state, surfaces a prompt instead of running a
/// search against an incomplete index.
final indexControllerProvider =
    StateNotifierProvider<IndexController, IndexState>((ref) {
      return IndexController(ref);
    });

class IndexController extends StateNotifier<IndexState> {
  final Ref _ref;
  IndexCheckStatus? _lastStatus;
  bool _busy = false;

  IndexController(this._ref) : super(IndexState.unknown());

  IndexService get _service => _ref.read(indexServiceProvider);

  /// Cheap, read-only. Safe to call from app startup, opening Settings, or
  /// opening Search — as often as needed. Never builds anything.
  Future<void> checkStatus() async {
    if (_busy) return;
    _busy = true;
    StartupTiming.mark('index check started');
    try {
      await _checkStatusInternal();
      StartupTiming.mark('index check done (${state.status})');
    } finally {
      _busy = false;
    }
  }

  Future<void> _checkStatusInternal() async {
    state = IndexState.checking();
    try {
      final status = await _service.checkStatus();
      _lastStatus = status;

      if (!status.healthy) {
        state = IndexState.corrupted(
          'The search index is damaged, most likely from the app being '
          'closed while it was still building. Clear it and rebuild to fix.',
        );
        return;
      }

      if (status.isComplete) {
        // If FTS is built but mention isn't, we're still "ready" for
        // the main search — mention will auto-build on first use.
        if (!status.mentionBuilt) {
          debugPrint('[INDEX] controller: FTS ready, mention not built yet');
          _lastStatus = status;
        }
        state = IndexState.ready();
        return;
      }

      debugPrint(
        '[INDEX] controller: needs build '
        '(paliMissing=${!status.paliBuilt})',
      );
      state = const IndexState.notBuilt();
    } on AppDatabaseCorruptedException catch (e) {
      state = IndexState.corrupted('app_data.db could not be opened: $e');
    } on TimeoutException {
      // The check hung rather than failed (typical after a hot restart:
      // path_provider's FFI can stall, or a stale SQLite lock blocks the
      // open). Drop the cached provider future so Retry re-opens the
      // database instead of re-awaiting the stuck attempt.
      try {
        _ref.invalidate(appDbProvider);
      } catch (_) {}
      state = IndexState.failed(
        'The search index check timed out. This sometimes happens after a '
        'hot restart — tap Retry, or fully stop and restart the app if it '
        'persists.',
      );
    } catch (e) {
      debugPrint('[INDEX] controller: checkStatus failed unexpectedly: $e');
      state = IndexState.failed('$e');
    }
  }

  /// Actually builds the index. Only call this in direct response to a
  /// user action (a "Build now" button) — never automatically.
  Future<void> buildIndex() async {
    if (_busy) return;
    _busy = true;
    try {
      await _buildIndexInternal();
    } finally {
      _busy = false;
    }
  }

  Future<void> _buildIndexInternal() async {
    state = IndexState.building(progress: 0, status: 'Preparing…');
    final fgsActive = await _startIndexKeepAlive();
    var lastPct = -1;
    var lastNotif = DateTime.fromMillisecondsSinceEpoch(0);
    void report(double p, String msg) {
      state = IndexState.building(progress: p, status: msg);
      final pct = (p * 100).round().clamp(0, 100);
      final now = DateTime.now();
      if (pct == lastPct ||
          now.difference(lastNotif) < const Duration(seconds: 1)) {
        return;
      }
      lastPct = pct;
      lastNotif = now;
      final text = msg.isEmpty ? '$pct%' : '$pct% · $msg';
      if (fgsActive) {
        DownloadForegroundService.instance.updateIndex(
          title: 'Building search index',
          text: text,
        );
      } else {
        DownloadNotificationService.instance.showIndexProgress(
          title: 'Building search index',
          body: text,
          progress: p.clamp(0.0, 1.0),
        );
      }
    }

    try {
      final status = _lastStatus ?? await _service.checkStatus();
      if (status.isComplete) {
        await _stopIndexKeepAlive(fgsActive, done: true);
        state = IndexState.ready();
        return;
      }

      final result = await _service.build(status, onProgress: report);

      if (result.pendingLanguages.isNotEmpty) {
        debugPrint(
          '[INDEX] controller: build finished with languages still '
          'pending: ${result.pendingLanguages}',
        );
      }
      _lastStatus = null; // force a fresh checkStatus() next time
      await _stopIndexKeepAlive(fgsActive, done: true);
      state = IndexState.ready();
    } on AppDatabaseCorruptedException catch (e) {
      await _stopIndexKeepAlive(fgsActive, error: e.toString());
      state = IndexState.corrupted('app_data.db could not be opened: $e');
    } catch (e) {
      debugPrint('[INDEX] controller: build failed: $e');
      await _stopIndexKeepAlive(fgsActive, error: e.toString());
      state = IndexState.failed('$e');
    }
  }

  /// Start the Android foreground service so the index build survives
  /// backgrounding, mirroring downloads and translator runs. Returns whether
  /// the service notification is active (else the caller uses the plain
  /// local-notification fallback). Never throws.
  Future<bool> _startIndexKeepAlive() async {
    try {
      final active = await DownloadForegroundService.instance.showIndex(
        title: 'Building search index',
        text: 'Preparing…',
      );
      if (!active) {
        DownloadNotificationService.instance.showIndexProgress(
          title: 'Building search index',
          body: 'Preparing…',
          progress: 0,
          isIndeterminate: true,
        );
      }
      return active;
    } catch (e) {
      debugPrint('[INDEX] foreground service start failed: $e');
      return false;
    }
  }

  /// Stop the keep-alive and surface the outcome. Never throws.
  Future<void> _stopIndexKeepAlive(
    bool fgsActive, {
    bool done = false,
    String? error,
  }) async {
    try {
      await DownloadForegroundService.instance.hideIndex();
      if (error != null) {
        DownloadNotificationService.instance.showIndexError(
          'Search index failed',
          error,
        );
      } else if (done) {
        DownloadNotificationService.instance.showIndexComplete(
          'Search index ready',
          'Index built successfully.',
        );
      } else {
        DownloadNotificationService.instance.dismissIndex();
      }
    } catch (e) {
      debugPrint('[INDEX] foreground service stop failed: $e');
    }
  }

  /// Destructive recovery: wipes app_data.db (bookmarks + reading history
  /// are lost — the caller's confirmation dialog should say so), then
  /// builds fresh. Used for `IndexCorrupted` recovery.
  Future<void> clearAndRebuild() async {
    if (_busy) return;
    _busy = true;
    try {
      state = IndexState.checking();
      await _service.clearOnly();
      _lastStatus = null;
      await _checkStatusInternal();
      await _buildIndexInternal();
    } catch (e) {
      debugPrint('[INDEX] controller: clearAndRebuild failed: $e');
      state = IndexState.failed('Rebuild failed: $e');
    } finally {
      _busy = false;
    }
  }

  /// Settings' explicit "Clear database" action: wipes WITHOUT rebuilding.
  /// The next `checkStatus()` call (e.g. next time Search or Settings
  /// opens) will correctly report a needs-build state.
  Future<void> clearOnly() async {
    if (_busy) return;
    _busy = true;
    try {
      state = IndexState.checking();
      await _service.clearOnly();
      _lastStatus = null;
      await _checkStatusInternal();
    } catch (e) {
      debugPrint('[INDEX] controller: clearOnly failed: $e');
      state = IndexState.failed('Clear failed: $e');
    } finally {
      _busy = false;
    }
  }

  /// Retry after a non-corruption failure.
  Future<void> retry() => checkStatus();
}
