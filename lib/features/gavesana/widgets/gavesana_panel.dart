import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/providers/side_panel_provider.dart';

/// A compact Gavesana panel for the sidebar.
/// Currently acts as a gateway to the full Gavesana screen.
class GavesanaPanel extends ConsumerWidget {
  const GavesanaPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 48,
              color: colors.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppDimensions.md),
            Text(
              'Gavesana AI Search',
              style: AppTypography.headlineSmall.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              'AI-powered semantic search across the Tipiṭaka.\n\nOpen the full Gavesana panel for detailed results.',
              textAlign: TextAlign.center,
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            FilledButton.icon(
              onPressed: () {
                ref.read(sidePanelProvider.notifier).close(SidePanelType.gavesana);
                context.push('/gavesana');
              },
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Open Gavesana'),
            ),
          ],
        ),
      ),
    );
  }
}
