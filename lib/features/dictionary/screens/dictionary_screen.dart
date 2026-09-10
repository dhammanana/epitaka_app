// lib/features/dictionary/screens/dictionary_screen.dart
//
// Full-screen dictionary, reachable from the navigation drawer. On mobile
// this complements the bottom-sheet lookup with a dedicated page; on
// desktop the body is centered with a max width so it reads like part of
// the desktop layout (the shell's docked dictionary panel is unchanged).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/responsive_breakpoint.dart';
import '../widgets/dictionary_panel.dart';
import '../../gavesana/screens/gavesana_drawer.dart';

/// Full-screen dictionary page.
class DictionaryScreen extends StatelessWidget {
  const DictionaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    final panel = const DictionaryPanel();

    final isFromDrawer =
        GoRouterState.of(context).uri.queryParameters['fromDrawer'] == 'true';

    return Scaffold(
      drawer: isFromDrawer ? const MainDrawer() : null,
      appBar: AppBar(
        toolbarHeight: AppDimensions.appBarHeight,
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: isFromDrawer
            ? Builder(
                builder: (drawerContext) => IconButton(
                  icon: const Icon(Icons.menu),
                  color: colors.onSurfaceVariant,
                  tooltip: loc.back,
                  onPressed: () => Scaffold.of(drawerContext).openDrawer(),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                color: colors.onSurfaceVariant,
                tooltip: loc.back,
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
              ),
        title: Text(
          loc.dictionary,
          style: AppTypography.headlineSmall.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ResponsiveBreakpoint.isDesktop(context)
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: panel,
              ),
            )
          : panel,
    );
  }
}
