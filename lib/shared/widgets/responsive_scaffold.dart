import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/responsive_breakpoint.dart';
import '../../features/desktop/desktop_shell.dart';
import 'app_shell.dart';

/// A responsive scaffold that adapts between mobile and desktop layouts.
///
/// **Mobile/Phone** — delegates to [AppShell] with a bottom navigation bar.
/// **Desktop** — renders the IDE-style [DesktopShell]: a VS Code-like
/// activity bar, a one-at-a-time sidebar (library / search / history /
/// bookmarks / contents / gavesana) with the dictionary docked at its
/// bottom, the reader + Vimaṃsa in the center, and an attached status
/// bar at the bottom.
class ResponsiveScaffold extends ConsumerWidget {
  /// The main content widget (e.g. [ReaderScreen]).
  final Widget child;

  /// Optional app bar for the main content area (mobile only; the desktop
  /// shell has its own chrome).
  final PreferredSizeWidget? appBar;

  /// Optional drawer for mobile.
  final Widget? drawer;

  const ResponsiveScaffold({
    super.key,
    required this.child,
    this.appBar,
    this.drawer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = ResponsiveBreakpoint.isDesktop(context);

    // Mobile/tablet: traditional AppShell (unchanged).
    if (!isDesktop) {
      return AppShell(
        appBar: appBar,
        drawer: drawer,
        child: child,
      );
    }

    // Desktop: IDE-style shell.
    return DesktopShell(child: child);
  }
}
