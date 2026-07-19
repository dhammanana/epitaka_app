import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/responsive_breakpoint.dart';

/// AppShell adapts between mobile and desktop layout.
///
/// On mobile: renders as a [Scaffold] with a bottom navigation bar.
/// On desktop: renders as a simple [Scaffold] with app bar and drawer.
/// Sidebar panels (TOC, Dictionary) are provided by ResponsiveScaffold
/// which wraps only the reader route, not the library home screen.
class AppShell extends ConsumerWidget {
  final Widget child;
  final PreferredSizeWidget? appBar;
  final Widget? drawer;

  const AppShell({super.key, required this.child, this.appBar, this.drawer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = ResponsiveBreakpoint.isDesktop(context);

    final colors = Theme.of(context).colorScheme;

    // Desktop: use a simple Scaffold with app bar and drawer (no bottom toolbar)
    // Keep the Column+Expanded structure identical to mobile (minus toolbar)
    // to avoid layout differences that could cause the macOS freeze issue.
    if (isDesktop) {
      debugPrint(
        '[APP_SHELL] desktop layout (width=${MediaQuery.sizeOf(context).width})',
      );
      return Scaffold(
        appBar: appBar,
        drawer: drawer,
        backgroundColor: colors.surface,
        body: Column(children: [Expanded(child: child)]),
      );
    }

    // Mobile: scaffold with no bottom bar (library is dialog-driven on desktop;
    // on mobile it is a plain scrollable screen).
    debugPrint(
      '[APP_SHELL] mobile layout (width=${MediaQuery.sizeOf(context).width})',
    );
    return Scaffold(
      appBar: appBar,
      drawer: drawer,
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(children: [Expanded(child: child)]),
      ),
    );
  }
}
