import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/providers/side_panel_provider.dart';

/// What the desktop dictionary panel remembers between runs: whether it was
/// open, and the last word looked up in it. It works like the reader's saved
/// text position: written as it changes, read once at start-up.
class DictionaryPanelMemory {
  const DictionaryPanelMemory._();

  static const openKey = 'dictionary_panel_open';
  static const wordKey = 'dictionary_panel_word';

  /// The desktop shell is built again when the window crosses the phone
  /// breakpoint. The panel is restored once per run, so a panel the user
  /// closed stays shut.
  static bool restoredThisRun = false;

  static Future<void> saveOpen(bool open) =>
      _write((p) => p.setBool(openKey, open));

  static Future<void> saveWord(String word) =>
      _write((p) => p.setString(wordKey, word));

  /// Opens the panel on the saved word when it was open at the last exit. It
  /// opens pinned, as a lookup from the reader would open it, so later
  /// lookups land in it. Nothing happens when another panel already holds the
  /// slot ([slotFree] is false: the user was faster than this read).
  static Future<void> restore(
    SidePanelNotifier panels, {
    required bool Function() slotFree,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(openKey) != true) return;
      if (!slotFree()) return;
      final word = prefs.getString(wordKey)?.trim();
      panels.open(
        SidePanelType.dictionary,
        data: word == null || word.isEmpty ? null : word,
        pin: true,
      );
    } on Object catch (e) {
      debugPrint('[Dictionary] panel state not restored: $e');
    }
  }

  static Future<void> _write(
    Future<bool> Function(SharedPreferences prefs) write,
  ) async {
    try {
      await write(await SharedPreferences.getInstance());
    } on Object catch (e) {
      debugPrint('[Dictionary] panel state not saved: $e');
    }
  }
}
