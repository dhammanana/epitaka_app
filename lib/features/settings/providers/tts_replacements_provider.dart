import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_db_provider.dart';
import '../../../core/database/app_database.dart';

/// Provider that fetches all TTS replacement rules from the database.
/// Auto-refreshes when the list changes.
final ttsReplacementsProvider =
    FutureProvider<List<TtsReplacement>>((ref) async {
  final db = await ref.read(appDbProvider.future);
  return db.getAllTtsReplacements();
});

/// Notifier for managing TTS replacement rules (CRUD + refresh).
final ttsReplacementsNotifierProvider =
    StateNotifierProvider<TtsReplacementsNotifier, AsyncValue<List<TtsReplacement>>>((ref) {
  return TtsReplacementsNotifier(ref);
});

class TtsReplacementsNotifier extends StateNotifier<AsyncValue<List<TtsReplacement>>> {
  final Ref _ref;

  TtsReplacementsNotifier(this._ref) : super(const AsyncLoading());

  /// Load replacements from the database.
  Future<void> load() async {
    state = const AsyncLoading();
    try {
      final db = await _ref.read(appDbProvider.future);
      final rules = await db.getAllTtsReplacements();
      state = AsyncData(rules);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Add a new replacement rule and refresh.
  Future<void> add({
    required String pattern,
    required String replacement,
    bool isRegex = false,
  }) async {
    try {
      final db = await _ref.read(appDbProvider.future);
      await db.addTtsReplacement(
        pattern: pattern,
        replacement: replacement,
        isRegex: isRegex,
      );
      _ref.invalidate(ttsReplacementsProvider);
      await load();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Update an existing replacement rule and refresh.
  Future<void> update(
    int id, {
    required String pattern,
    required String replacement,
    required bool isRegex,
    required bool enabled,
  }) async {
    try {
      final db = await _ref.read(appDbProvider.future);
      await db.updateTtsReplacement(
        id,
        pattern: pattern,
        replacement: replacement,
        isRegex: isRegex,
        enabled: enabled,
      );
      _ref.invalidate(ttsReplacementsProvider);
      await load();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Toggle a replacement rule's enabled state and refresh.
  Future<void> toggle(int id, bool enabled) async {
    try {
      final db = await _ref.read(appDbProvider.future);
      await db.toggleTtsReplacement(id, enabled);
      _ref.invalidate(ttsReplacementsProvider);
      await load();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Delete a replacement rule and refresh.
  Future<void> delete(int id) async {
    try {
      final db = await _ref.read(appDbProvider.future);
      await db.deleteTtsReplacement(id);
      _ref.invalidate(ttsReplacementsProvider);
      await load();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

/// Synchronous cached provider that returns only the active (enabled) TTS
/// replacement rules. Updated automatically when [ttsReplacementsNotifierProvider]
/// changes (e.g. after CRUD operations).
///
/// Returns an empty list while the data is still loading or on error.
final activeTtsReplacementsProvider = Provider<List<TtsReplacement>>((ref) {
  final state = ref.watch(ttsReplacementsNotifierProvider);
  return state.whenOrNull(
    data: (rules) => rules.where((r) => r.enabled).toList(),
  ) ?? [];
});
