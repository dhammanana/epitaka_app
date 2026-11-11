import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A saved, capped list of strings, newest first. Every search box that keeps
/// a history extends this and only picks its key, cap and what counts as the
/// same entry.
abstract class HistoryStore extends StateNotifier<List<String>> {
  HistoryStore({required this.storageKey, required this.capacity})
    : super(const []) {
    _ready = _load();
  }

  // A save waits for the load, or it would write over the stored list before
  // the load has read it.
  late final Future<void> _ready;

  final String storageKey;
  final int capacity;

  /// Two entries with the same identity are one entry.
  String identity(String entry) => entry;

  /// A saved string that fails this is dropped on load.
  bool accepts(String entry) => true;

  // The load is async. Changes made before it finishes must not be undone by
  // the saved list arriving afterwards.
  bool _cleared = false;
  final Set<String> _removed = {};

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final saved = prefs.getStringList(storageKey) ?? const <String>[];
      if (saved.isEmpty) return;
      if (_cleared) {
        // The user cleared before the saved list arrived: it is stale.
        _save();
        return;
      }
      final merged = [...state];
      final seen = {for (final e in merged) identity(e)};
      for (final entry in saved) {
        if (!accepts(entry)) {
          developer.log(
            'dropped a bad saved entry',
            name: 'epitaka.history',
            error: storageKey,
          );
          continue;
        }
        final id = identity(entry);
        if (_removed.contains(id) || !seen.add(id)) continue;
        merged.add(entry);
      }
      if (merged.length > capacity) merged.removeRange(capacity, merged.length);
      state = List.unmodifiable(merged);
      // A remove made before the load must reach the disk too.
      if (_removed.isNotEmpty) _save();
    } catch (e, st) {
      developer.log(
        'load failed for $storageKey',
        name: 'epitaka.history',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _save() async {
    try {
      await _ready;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(storageKey, state);
    } catch (e, st) {
      developer.log(
        'save failed for $storageKey',
        name: 'epitaka.history',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Record [entry] as the newest (a repeat moves to the top).
  void add(String entry) {
    final e = entry.trim();
    if (e.isEmpty) return;
    final id = identity(e);
    _removed.remove(id);
    final next = [for (final s in state) if (identity(s) != id) s];
    next.insert(0, e);
    if (next.length > capacity) next.removeRange(capacity, next.length);
    state = List.unmodifiable(next);
    _save();
  }

  void remove(String entry) {
    final id = identity(entry);
    _removed.add(id);
    if (!state.any((s) => identity(s) == id)) return;
    state = List.unmodifiable([
      for (final s in state)
        if (identity(s) != id) s,
    ]);
    _save();
  }

  void clear() {
    _cleared = true;
    if (state.isEmpty) return;
    state = const [];
    _save();
  }
}
