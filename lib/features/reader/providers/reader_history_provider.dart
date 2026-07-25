import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_db_provider.dart';
import 'reader_tabs_provider.dart';

/// Service that saves reading history with debounce.
///
/// Has no observable UI state — it writes to the database and invalidates
/// [historyProvider] so the history list refreshes. Instantiated via a
/// plain [Provider] (not a StateNotifier) since there is nothing to watch.
class ReaderHistoryService {
  final Ref _ref;

  ReaderHistoryService(this._ref);

  /// Last saved paraId per book (to avoid duplicate saves).
  final Map<String, int> _lastSavedParaIdPerBook = {};

  /// Debounce timer for scroll-based history saves.
  Timer? _saveHistoryTimer;

  /// Save reading history for [bookId] to the database.
  ///
  /// If [explicitParaId] and [explicitLineId] are provided, they are used
  /// directly; otherwise the current tab's position is used.
  Future<void> saveReadingHistory(
    String bookId,
    String? bookName, {
    int? explicitParaId,
    int? explicitLineId,
  }) async {
    try {
      final db = await _ref.read(appDbProvider.future);
      final tabsState = _ref.read(readerTabsProvider);
      final tab = tabsState.tabs.firstWhere((t) => t.bookId == bookId);
      await db.recordReading(
        bookId: bookId,
        bookName: bookName,
        paraId: explicitParaId ?? tab.currentParaId,
        lineId: explicitLineId ?? tab.currentLineId,
      );
      _ref.invalidate(historyProvider);
    } catch (_) {
      // Silently fail — history is non-critical
    }
  }

  /// Schedule a debounced save of reading history.
  ///
  /// If [paraId] matches the last saved paraId for this book, the save is
  /// skipped entirely. Otherwise the previous debounce timer is cancelled
  /// and a new 3-second timer is started.
  void scheduleSaveHistory(String bookId, String? bookName, int paraId) {
    if (_lastSavedParaIdPerBook[bookId] == paraId) return;
    _lastSavedParaIdPerBook[bookId] = paraId;

    _saveHistoryTimer?.cancel();
    _saveHistoryTimer = Timer(const Duration(seconds: 3), () {
      saveReadingHistory(bookId, bookName);
    });
  }

  /// Dispose the debounce timer.
  void dispose() {
    _saveHistoryTimer?.cancel();
    _saveHistoryTimer = null;
  }
}

/// Provider for the reading history service.
///
/// This is a plain [Provider] (not a family provider) because the service
/// itself is stateless — it uses the tabs provider to find the right tab
/// by bookId when saving.
final readerHistoryProvider = Provider<ReaderHistoryService>((ref) {
  final service = ReaderHistoryService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});
