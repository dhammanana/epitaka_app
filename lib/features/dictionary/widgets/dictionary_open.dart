import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/responsive_breakpoint.dart';
import '../../../shared/providers/side_panel_provider.dart';

/// Route a dictionary lookup to the desktop shell's dictionary panel.
///
/// On desktop the dictionary lives in the shell — docked at the bottom of
/// the sidebar when the sidebar is open, or as an independent right column
/// when the sidebar is closed — so lookups should never open the mobile
/// bottom sheet there.
///
/// Returns `true` when the lookup was handled (desktop, or an empty word);
/// returns `false` when the caller should fall back to showing the
/// dictionary bottom sheet itself (mobile).
///
/// When [closeSheet] is true (used from modal preview sheets), the current
/// route is popped first so the opened panel isn't hidden behind the sheet.
bool openDictionaryInPanel(
  BuildContext context,
  WidgetRef ref,
  String word, {
  bool closeSheet = false,
}) {
  final trimmed = word.trim();
  if (trimmed.isEmpty) return true;
  if (!ResponsiveBreakpoint.isDesktop(context)) return false;

  if (closeSheet && Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  }

  final notifier = ref.read(sidePanelProvider.notifier);
  final sidePanels = ref.read(sidePanelProvider);
  if (sidePanels.right.openPanel == SidePanelType.dictionary) {
    // Already visible — just point it at the new word.
    notifier.updateDictionaryWord(trimmed);
  } else {
    // Open it; the shell decides placement (sidebar dock vs. right column).
    notifier.open(SidePanelType.dictionary, data: trimmed, pin: true);
  }
  return true;
}
