import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/providers/app_db_provider.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/database_initializer.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/app_localizations.dart';
import '../index_progress_screen.dart';

/// Tile to reset all app data (bookmarks, history, search index) and
/// rebuild the index from scratch. Shows a detailed confirmation dialog
/// with the database file path and an optional export option.
class ResetDataTile extends ConsumerWidget {
  const ResetDataTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    return InkWell(
      onTap: () => _showResetDialog(context, ref),
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
                    loc.resetAndRebuild,
                    style: AppTypography.labelMedium.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                  Text(
                    loc.resetAndRebuildSubtitle,
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

  Future<void> _showResetDialog(BuildContext context, WidgetRef ref) async {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    // Determine database path
    final dir = await getDatabaseDirectory();
    final dbPath = p.join(dir.path, 'app_data.db');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            const SizedBox(width: 8),
            Expanded(child: Text(loc.resetAndRebuildTitle)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.resetConfirmDesc,
              ),
              const SizedBox(height: 16),

              // DB path
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.databaseLocation,
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      dbPath,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Backup suggestion
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 18,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        loc.resetBackupTip,
                        style: AppTypography.labelSmall.copyWith(
                          color: Colors.orange.shade800,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(loc.cancel),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop(false);
              _exportData(context, ref);
            },
            icon: const Icon(Icons.download, size: 18),
            label: Text(loc.exportBackups),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            child: Text(loc.resetNow),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await IndexProgressScreen.show(context, resetFirst: true);
    }
  }

  /// Export bookmarks and reading history as a JSON backup file.
  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context);
    try {
      final appDb = await ref.read(appDbProvider.future);
      final bookmarks = await appDb.getAllBookmarks();
      final history = await appDb.getAllHistory();

      final backup = {
        'exportedAt': DateTime.now().toIso8601String(),
        'appVersion': 'ePitaka',
        'bookmarks': bookmarks
            .map(
              (b) => {
                'name': b.name,
                'bookId': b.bookId,
                'paraId': b.paraId,
                'lineId': b.lineId,
                'bookName': b.bookName,
                'pageNumber': b.pageNumber,
                'createdAt': b.createdAt.toIso8601String(),
                'updatedAt': b.updatedAt.toIso8601String(),
              },
            )
            .toList(),
        'readingHistory': history
            .map(
              (h) => {
                'bookId': h.bookId,
                'bookName': h.bookName,
                'paraId': h.paraId,
                'lineId': h.lineId,
                'openedAt': h.openedAt.toIso8601String(),
                'updatedAt': h.updatedAt.toIso8601String(),
                'readCount': h.readCount,
              },
            )
            .toList(),
      };

      final json = const JsonEncoder.withIndent('  ').convert(backup);

      final dir = await getDatabaseDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final filePath = p.join(dir.path, 'epitaka_backup_$timestamp.json');
      final file = File(filePath);
      await file.writeAsString(json);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${loc.backupSavedTo} $filePath'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(label: loc.ok, onPressed: () {}),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${loc.failedToExportData} $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
