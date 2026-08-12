// lib/features/annotations/screens/annotations_screen.dart
//
// A full-screen overview of ALL the user's annotations (highlights, notes,
// bookmarks) across every book, reachable from the navigation drawer.
//
// The screen is a thin chrome wrapper around [GlobalAnnotationsView], which
// holds the search field, filter chips (with live counts), the book filter,
// and the collapsible per-book groups. On desktop the body is centered with
// a max width so it reads like part of the desktop layout; the desktop
// sidebar reuses the same view as a panel.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/responsive_breakpoint.dart';
import '../widgets/global_annotations_view.dart';

/// Full-screen overview of all annotations across every book.
class AnnotationsScreen extends StatelessWidget {
  const AnnotationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    final isFromDrawer =
        GoRouterState.of(context).uri.queryParameters['fromDrawer'] == 'true';

    final view = const GlobalAnnotationsView();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: AppDimensions.appBarHeight,
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(isFromDrawer ? Icons.menu : Icons.arrow_back),
          color: colors.onSurfaceVariant,
          tooltip: loc.navigationMenu,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          loc.annotations,
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
                child: view,
              ),
            )
          : view,
    );
  }
}
