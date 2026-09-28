import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent history of previous Tipitaka searches.
///
/// Stored as a most-recent-first string list in SharedPreferences so it
/// survives restarts and is shared by every search UI (full screen, sidebar
/// panel, bottom sheet). Tapping a chip fills the search bar and re-runs
/// the search (handled by each UI).
final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryNotifier, List<String>>(
      (ref) => SearchHistoryNotifier(),
    );

class SearchHistoryNotifier extends StateNotifier<List<String>> {
  static const prefsKey = 'tipitaka_search_history';
  static const maxLen = 30;

  SearchHistoryNotifier() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(prefsKey) ?? const [];
      if (saved.isNotEmpty) state = List.unmodifiable(saved);
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(prefsKey, state);
    } catch (_) {}
  }

  /// Record [query] as the most recent search (deduplicated).
  void add(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    final next = [...state]..remove(q);
    next.insert(0, q);
    if (next.length > maxLen) next.removeRange(maxLen, next.length);
    state = List.unmodifiable(next);
    _save();
  }

  void remove(String query) {
    if (!state.contains(query)) return;
    state = List.unmodifiable([...state]..remove(query));
    _save();
  }

  void clear() {
    if (state.isEmpty) return;
    state = const [];
    _save();
  }
}
