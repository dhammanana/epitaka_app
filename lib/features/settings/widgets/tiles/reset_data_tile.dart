import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/app_db_provider.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../indexing/index_controller.dart';
import 'confirm_action_dialog.dart';

/// Tile to reset all app data (bookmarks, history, search index).
class ResetDataTile extends ConsumerWidget {
  const ResetDataTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () async {
        final confirmed = await showConfirmActionDialog(
          context,
          title: 'Reset All App Data?',
          message:
              'This will permanently delete all bookmarks, reading history, '
              'and the search index. Translation databases will not be affected. '
              'This action cannot be undone.',
          confirmLabel: 'Reset All',
          icon: Icons.delete_forever,
        );
        if (!confirmed) return;

        try {
          final appDb = await ref.read(appDbProvider.future);
          // Delete and recreate the database file
          await AppDatabase.deleteDatabaseFile();
          ref.invalidate(appDbProvider);
          // Trigger index rebuild
          await ref.read(indexControllerProvider.notifier).clearAndRebuild();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('App data has been reset.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to reset data: $e'),
                backgroundColor: colors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md,
          vertical: AppDimensions.md,
        ),
        child: Row(
          children: [
            Icon(Icons.delete_outline, color: colors.error),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reset App Data',
                    style: AppTypography.labelMedium.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                  Text(
                    'Clear bookmarks, history & search index',
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
