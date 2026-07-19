import 'package:flutter/material.dart';

import '../../../core/utils/responsive_breakpoint.dart';
import '../../../shared/widgets/screen_dialog.dart';
import '../screens/settings_screen.dart';

/// Show the settings as a dialog on desktop.
///
/// The dialog **embeds the real [SettingsScreen]** so there is a single
/// source of truth — any future edit to [SettingsScreen] is reflected here
/// automatically. On mobile this is a no-op; callers should fall back to the
/// full-page `/settings` route instead.
Future<void> showSettingsDialog(BuildContext context) async {
  if (!ResponsiveBreakpoint.isDesktop(context)) return;

  await showScreenDialog(context: context, child: const SettingsScreen());
}
