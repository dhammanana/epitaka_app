import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const dictionaryHeaderIconsPrefsKey = 'dictionary_header_icons';

/// Whether the dictionary's icon row shows. The user sets the dictionary up
/// once and may hide the row; Settings shows it again.
final dictionaryHeaderIconsProvider =
    StateNotifierProvider<DictionaryHeaderIconsNotifier, bool>(
      (ref) => DictionaryHeaderIconsNotifier(),
    );

class DictionaryHeaderIconsNotifier extends StateNotifier<bool> {
  DictionaryHeaderIconsNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(dictionaryHeaderIconsPrefsKey);
      if (saved != null && mounted) state = saved;
    } catch (_) {}
  }

  Future<void> set(bool visible) async {
    if (state == visible) return;
    state = visible;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(dictionaryHeaderIconsPrefsKey, visible);
    } catch (_) {}
  }
}

/// The icon row lives in the sidebar header or the sheet's top row, away from
/// the panel it acts on. It asks by raising a counter; the open panel or sheet
/// listens and does the work, so a closed one is never touched.
final dictionaryScrollTopRequestProvider = StateProvider<int>((ref) => 0);
final dictionaryHistoryRequestProvider = StateProvider<int>((ref) => 0);
