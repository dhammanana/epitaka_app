import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The words looked up in the dictionary sheet and panel, with a position in
/// them. The back and forward buttons move the position, and the chips under
/// the search field show the same words, so the two cannot disagree. Ported
/// from the DPD app's `HistoryState` and `HistoryNotifier`
/// (`providers/history_provider.dart`). One list is shared by the sheet and
/// the panel, and saved, so it survives a restart.
///
/// The position is an index into the words. It sits one past the end after
/// [resetPosition] and after a load, so that going back returns to the last
/// word.
class LookupHistory extends ChangeNotifier {
  LookupHistory({this.persist = false});

  static const maxWords = 100;

  static const wordsPrefsKey = 'dict_lookup_nav';

  /// The sheet's old recent-words list, newest first. It is read once, to fill
  /// the history of a user who has none yet.
  static const legacyRecentPrefsKey = 'dict_search_history';

  /// False in unit tests, which have no preferences to write.
  final bool persist;

  final List<String> _words = [];
  int _index = -1;

  /// Nothing is written before the saved words are read: a lookup that came
  /// first would overwrite the saved list on disk before [load] could read it.
  bool _loaded = false;

  /// Oldest first, for the chips under the search field.
  List<String> get words => List.unmodifiable(_words);

  /// Where the word on screen sits in [words]; -1 or the length when none is.
  int get currentIndex => _index;

  String? get current =>
      _index >= 0 && _index < _words.length ? _words[_index] : null;

  bool get canGoBack => _index > 0;
  bool get canGoForward => _index >= 0 && _index < _words.length - 1;

  String? get backWord =>
      canGoBack ? _words[_index.clamp(1, _words.length) - 1] : null;
  String? get forwardWord => canGoForward ? _words[_index + 1] : null;

  /// A new lookup goes to the end, even after going back: the words ahead of
  /// the position stay (the user's rule; a browser would drop them). A word is
  /// never in the list twice: looking up a word already in it moves it to the
  /// end. The newest word as the current word adds nothing.
  void navigateTo(String word) {
    if (word.isEmpty) return;
    if (_index == _words.length - 1 && current == word) return;
    _words
      ..remove(word)
      ..add(word);
    if (_words.length > maxWords) _words.removeAt(0);
    _index = _words.length - 1;
    _changed();
  }

  /// Moves the position and returns the word to show, or null at an end.
  String? goBack() {
    if (!canGoBack) return null;
    _index = _index.clamp(1, _words.length) - 1;
    _changed();
    return _words[_index];
  }

  String? goForward() {
    if (!canGoForward) return null;
    _index++;
    _changed();
    return _words[_index];
  }

  /// The search field was cleared: no word is current, but back still reaches
  /// the last one.
  void resetPosition() {
    _index = _words.isEmpty ? -1 : _words.length;
    _changed();
  }

  /// Reads the saved words. A word looked up before the read finished stays,
  /// at the end, after the saved ones; it is saved again so it does not
  /// replace the saved list on disk.
  Future<void> load() async {
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } on Object catch (e) {
      // Nothing was read, so nothing may be written: a save would replace the
      // saved list with only this run's words.
      debugPrint('[DPD] lookup history not loaded: $e');
      return;
    }
    final saved = <String>[];
    try {
      final json = prefs.getString(wordsPrefsKey);
      if (json != null) {
        saved.addAll((jsonDecode(json) as List).cast<String>());
      } else {
        saved.addAll(
          (prefs.getStringList(legacyRecentPrefsKey) ?? const <String>[])
              .reversed,
        );
      }
    } on Object catch (e) {
      // Damaged prefs: start with no saved history. Thrown out of here, the
      // error would leave the list unloaded, and nothing would be saved.
      debugPrint('[DPD] lookup history not read: $e');
    }
    final early = [..._words];
    _words
      ..clear()
      // A word is never in the list twice, even if the saved list says so; the
      // newest copy stays, as a repeated lookup moves a word to the end.
      ..addAll(
        saved.reversed.toSet().toList().reversed.where((w) => !early.contains(w)),
      )
      ..addAll(early);
    if (_words.length > maxWords) {
      _words.removeRange(0, _words.length - maxWords);
    }
    _index = early.isEmpty ? _words.length : _words.length - 1;
    _loaded = true;
    if (early.isEmpty) {
      notifyListeners();
    } else {
      _changed();
    }
  }

  void _changed() {
    notifyListeners();
    if (persist && _loaded) _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(wordsPrefsKey, jsonEncode(_words));
  }
}

final lookupHistoryProvider = ChangeNotifierProvider<LookupHistory>((ref) {
  final history = LookupHistory(persist: true);
  history.load();
  return history;
});
