import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/platform_info.dart';
import '../../../shared/providers/side_panel_provider.dart';
import 'dictionary_sheet.dart';

/// Route a dictionary lookup to the dictionary panel (desktop) or the modal
/// bottom sheet (mobile).
///
/// Desktop: the dictionary lives in the shell — docked in the sidebar (its
/// height is user-resizable and its placement is remembered), or as an
/// independent right column when the sidebar is closed. When it is already
/// open, the lookup simply re-points it at the new word in place (the panel
/// syncs with [sidePanelProvider]).
///
/// Mobile: the dictionary is the modal bottom sheet — easy to close with the
/// back button, by pulling it down, or by tapping outside.
///
/// Returns `true` when the lookup was handled (always, including empty
/// words); returns `false` when the caller should fall back to showing the
/// dictionary bottom sheet itself (never happens today — kept for symmetry).
///
/// When [closeSheet] is true (used from modal preview sheets), the current
/// route is popped first so the opened dictionary isn't hidden behind the
/// sheet.
bool openDictionaryInPanel(
  BuildContext context,
  WidgetRef ref,
  String word, {
  bool closeSheet = false,
}) {
  final trimmed = word.trim();
  if (trimmed.isEmpty) return true;

  if (closeSheet && Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  }

  if (PlatformInfo.isDesktop) {
    // Desktop: docked sidebar panel / right column — unchanged.
    final notifier = ref.read(sidePanelProvider.notifier);
    final sidePanels = ref.read(sidePanelProvider);
    if (sidePanels.right.openPanel == SidePanelType.dictionary) {
      // Already visible — just point it at the new word.
      notifier.updateDictionaryWord(trimmed);
    } else {
      // Open it; the shell (sidebar dock / right column) decides the exact
      // placement.
      notifier.open(SidePanelType.dictionary, data: trimmed, pin: true);
    }
  } else {
    // Mobile: modal bottom sheet — back button, pull down, or tap outside
    // to close.
    showDictionarySheet(context, trimmed);
  }
  return true;
}
