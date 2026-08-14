import 'package:flutter/material.dart';

import '../../../core/utils/responsive_breakpoint.dart';
import 'desktop_settings_dialog.dart';

/// Show the settings on desktop.
///
/// On desktop this opens a macOS-style settings window (left sidebar to pick
/// a category, scrollable pane on the right) via [showDesktopSettingsDialog].
/// Every pane reuses the real settings screens' bodies, so there is a single
/// source of truth — any future edit to a settings screen is reflected here
/// automatically. On mobile this is a no-op; callers should fall back to the
/// full-page `/settings` route instead.
Future<void> showSettingsDialog(BuildContext context) async {
  if (!ResponsiveBreakpoint.isDesktop(context)) return;

  await showDesktopSettingsDialog(context);
}
