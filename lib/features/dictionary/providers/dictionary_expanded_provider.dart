import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted expand/collapse state for each dictionary card.
///
/// Keyed by a stable dictionary id (`dpd`, `book_<id>`, `mdx_<id>`).
/// Defaults to expanded when no saved value exists, so first-time users
/// see all dictionaries and collapsing is opt-in.
final dictionaryExpandedProvider =
    StateNotifierProvider<DictionaryExpandedNotifier, Map<String, bool>>(
      (ref) => DictionaryExpandedNotifier(),
    );

class DictionaryExpandedNotifier extends StateNotifier<Map<String, bool>> {
  static const storeKey = 'dict_expanded_state_v1';

  DictionaryExpandedNotifier() : super(const {}) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storeKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      state = {
        for (final e in decoded.entries)
          if (e.value is bool) e.key: e.value as bool,
      };
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storeKey, jsonEncode(state));
    } catch (_) {}
  }

  /// Whether [key] is expanded. Unknown keys default to true.
  bool isExpanded(String key) => state[key] ?? true;

  void setExpanded(String key, bool expanded) {
    if (state[key] == expanded) return;
    state = {...state, key: expanded};
    _save();
  }

  void toggle(String key) => setExpanded(key, !isExpanded(key));
}

/// Reads the expanded state for [key] (defaults to true).
final dictionaryExpandedFamilyProvider = Provider.family<bool, String>((
  ref,
  key,
) {
  return ref.watch(dictionaryExpandedProvider)[key] ?? true;
});
