import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/history_store.dart';

/// Persistent history of previous Tipitaka searches.
///
/// Stored as a most-recent-first string list in SharedPreferences so it
/// survives restarts and is shared by every search UI (full screen, sidebar
/// panel, bottom sheet). Tapping a row fills the search bar and re-runs
/// the search (handled by each UI).
final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryNotifier, List<String>>(
      (ref) => SearchHistoryNotifier(),
    );

class SearchHistoryNotifier extends HistoryStore {
  static const prefsKey = 'tipitaka_search_history';
  static const maxLen = 30;

  SearchHistoryNotifier() : super(storageKey: prefsKey, capacity: maxLen);
}
