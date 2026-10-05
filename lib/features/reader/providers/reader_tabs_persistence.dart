import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

import 'reader_tabs_provider.dart';

const _kOpenTabsKey = 'reader_open_tabs';

/// Only the book and the last-read place are kept. Search highlights and
/// jump requests belong to the session that made them.
String encodeReaderTabs(ReaderTabsState state) => jsonEncode({
      'active': state.activeIndex,
      'tabs': [
        for (final tab in state.tabs)
          {
            'bookId': tab.bookId,
            'bookName': tab.bookName,
            'bookDescription': tab.bookDescription,
            'paraId': tab.currentParaId,
            'lineId': tab.currentLineId,
            'offset': tab.scrollOffset,
          },
      ],
    });

/// Returns null for data it cannot read, so the app starts with no tabs.
ReaderTabsState? decodeReaderTabs(String raw) {
  try {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final tabs = [
      for (final entry in map['tabs'] as List)
        _decodeTab(entry as Map<String, dynamic>),
    ];
    final active = (map['active'] as num?)?.toInt() ?? 0;
    return ReaderTabsState(
      tabs: tabs,
      activeIndex: tabs.isEmpty ? 0 : active.clamp(0, tabs.length - 1),
    );
  } catch (e) {
    developer.log('Ignoring unreadable saved tabs: $e', name: 'epitaka.tabs');
    return null;
  }
}

// Restored tabs carry the place in the current* fields, not initialParaId:
// the reader's tab-restore path reads those, the same as on a tab switch.
ReaderTabInfo _decodeTab(Map<String, dynamic> tab) => ReaderTabInfo(
      bookId: tab['bookId'] as String,
      bookName: tab['bookName'] as String,
      bookDescription: tab['bookDescription'] as String?,
      currentParaId: (tab['paraId'] as num?)?.toInt(),
      currentLineId: (tab['lineId'] as num?)?.toInt(),
      scrollOffset: (tab['offset'] as num?)?.toDouble(),
    );

ReaderTabsState? loadSavedReaderTabs(SharedPreferences prefs) {
  try {
    final raw = prefs.getString(_kOpenTabsKey);
    return raw == null ? null : decodeReaderTabs(raw);
  } catch (e) {
    developer.log('Could not load saved tabs: $e', name: 'epitaka.tabs');
    return null;
  }
}

/// Takes prefs that are already loaded so the write starts at once. Awaiting
/// `SharedPreferences.getInstance()` here first let two quick saves finish in
/// the wrong order, which left the older tabs stored.
void saveReaderTabs(SharedPreferences prefs, ReaderTabsState state) {
  prefs
      .setString(_kOpenTabsKey, encodeReaderTabs(state))
      .catchError((Object e) {
    developer.log('Could not save tabs: $e', name: 'epitaka.tabs');
    return false;
  });
}
