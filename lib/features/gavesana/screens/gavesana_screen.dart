import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../widgets/gavesana_search_view.dart';
import 'gavesana_drawer.dart';

/// Full-screen Gavesana AI search.
///
/// The user describes what they're looking for; an AI model plans and runs
/// the searches against the local Tipitaka databases (using the same
/// tool-calling engine as Vīmaṃsā), then the passages it gathers are shown
/// in the normal search results format.
///
/// The search bar and all AI states live in the shared [GavesanaSearchView]
/// widget — the same one embedded directly in the desktop sidebar panel —
/// so both desktop and mobile get the same search experience.
class GavesanaScreen extends StatelessWidget {
  const GavesanaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

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
                  onPressed: () => Scaffold.of(drawerContext).openDrawer(),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                color: colors.onSurfaceVariant,
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
              ),
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.psychology, size: 16, color: colors.primary),
            ),
            const SizedBox(width: 8),
            Text(
              loc.gavesana,
              style: AppTypography.headlineSmall.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: const GavesanaSearchView(autoFocus: true),
    );
  }
}
