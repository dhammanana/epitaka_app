import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/app_localizations.dart';
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
    final loc = AppLocalizations.of(context);

    return InkWell(
      onTap: () async {
        if (indexState.isBuilt) {
          final confirmed = await showConfirmActionDialog(
            context,
            title: loc.rebuildSearchIndexTitle,
            message: loc.clearIndexConfirmDesc,
            confirmLabel: loc.rebuild,
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
                    loc.searchIndexTitle,
                    style: AppTypography.labelMedium.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                  Text(
                    indexState.isBuilt
                        ? 'Indexed · ${indexState.indexedTranslationLang?.toUpperCase() ?? ""} · ${indexState.totalProgress} ${loc.sentences}'
                        : indexState.isBuilding
                            ? loc.buildingDots
                            : loc.notBuilt,
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
