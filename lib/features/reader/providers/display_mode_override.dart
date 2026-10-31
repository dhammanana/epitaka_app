import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';

/// Why the reader shows line-by-line for now.
enum DisplayModeReason {
  /// Read-aloud follows the spoken line, and only line-by-line draws one
  /// widget per line for it to scroll to.
  tts,

  /// Side-by-side is too wide for a column; the other modes fit.
  columns,
}

/// Switches the display mode to line-by-line while any reason needs it,
/// and back to the mode from before when none does.
///
/// Each reason used to remember its own "mode before", so whichever
/// stopped first put side-by-side back under the other. The switch never
/// writes the saved setting.
class DisplayModeOverride {
  DisplayModeOverride(this._ref);

  final Ref _ref;
  final Set<DisplayModeReason> _reasons = {};

  /// The mode to put back, or null while nothing is switched.
  TranslationDisplayMode? _before;

  void add(DisplayModeReason reason) {
    _reasons.add(reason);
    final current = _ref.read(settingsProvider).translationDisplayMode;
    if (!_needs(reason, current)) return;
    // Only line-by-line is ever forced, so any other mode on screen is the
    // user's own, even one picked by hand while a reason was active.
    _before = current;
    _set(TranslationDisplayMode.lineByLine);
  }

  void remove(DisplayModeReason reason) {
    if (!_reasons.remove(reason)) return;
    final before = _before;
    if (before == null) return;
    if (_reasons.any((r) => _needs(r, before))) return;
    _before = null;
    final current = _ref.read(settingsProvider).translationDisplayMode;
    // A mode picked by hand in the meantime stays.
    if (current == TranslationDisplayMode.lineByLine || current == before) {
      _set(before);
    }
  }

  static bool _needs(DisplayModeReason reason, TranslationDisplayMode mode) =>
      switch (reason) {
        DisplayModeReason.tts => mode != TranslationDisplayMode.lineByLine,
        DisplayModeReason.columns => mode == TranslationDisplayMode.sideBySide,
      };

  void _set(TranslationDisplayMode mode) => _ref
      .read(settingsProvider.notifier)
      .setTranslationDisplayModeTemporary(mode);
}

final displayModeOverrideProvider = Provider<DisplayModeOverride>(
  (ref) => DisplayModeOverride(ref),
);
