import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../indexing/index_controller.dart';
import '../../../indexing/index_build_dialog.dart';
import 'confirm_action_dialog.dart';

/// Tile to view/manage the FTS search index.
class RebuildIndexTile extends ConsumerWidget {
  const RebuildIndexTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final indexState = ref.watch(indexControllerProvider);
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () async {
        if (indexState.isBuilt) {
          final confirmed = await showConfirmActionDialog(
            context,
            title: 'Rebuild Search Index?',
            message:
                'This will clear the current search index and rebuild it from '
                'scratch. Previously indexed data will be lost until the rebuild '
                'completes.',
            confirmLabel: 'Rebuild',
          );
          if (!confirmed) return;
        }
        if (context.mounted) {
          IndexBuildDialog.show(context);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md,
          vertical: AppDimensions.md,
        ),
        child: Row(
          children: [
            Icon(
              indexState.isBuilt ? Icons.storage : Icons.storage_outlined,
              color: indexState.isBuilt ? Colors.green : colors.primary,
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Search Index',
                    style: AppTypography.labelMedium.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                  Text(
                    indexState.isBuilt
                        ? 'Indexed · ${indexState.indexedTranslationLang?.toUpperCase() ?? ""} · ${indexState.totalProgress} sentences'
                        : indexState.isBuilding
                            ? 'Building…'
                            : 'Not built',
                    style: AppTypography.labelSmall.copyWith(
                      color: indexState.isBuilt
                          ? Colors.green
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (indexState.isBuilding)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                Icons.chevron_right,
                color: colors.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}
