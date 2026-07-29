import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
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
    try {
      await _checkStatusInternal();
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
    try {
      final status = _lastStatus ?? await _service.checkStatus();
      if (status.isComplete) {
        state = IndexState.ready();
        return;
      }

      final result = await _service.build(
        status,
        onProgress: (p, msg) =>
            state = IndexState.building(progress: p, status: msg),
      );

      if (result.pendingLanguages.isNotEmpty) {
        debugPrint(
          '[INDEX] controller: build finished with languages still '
          'pending: ${result.pendingLanguages}',
        );
      }
      _lastStatus = null; // force a fresh checkStatus() next time
      state = IndexState.ready();
    } on AppDatabaseCorruptedException catch (e) {
      state = IndexState.corrupted('app_data.db could not be opened: $e');
    } catch (e) {
      debugPrint('[INDEX] controller: build failed: $e');
      state = IndexState.failed('$e');
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