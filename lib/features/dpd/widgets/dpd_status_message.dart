import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../providers/dpd_database_provider.dart';
import 'dpd_download_control.dart';

/// Says why DPD has no answer: no file, or a file this build cannot read.
/// The path is selectable, so it can be copied. With no file it also offers
/// the download, and shows its progress while one runs.
class DpdStatusMessage extends StatelessWidget {
  const DpdStatusMessage({super.key, required this.unavailable});

  final DpdUnavailable unavailable;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final state = unavailable.state;
    final headline = state.status == DpdDatabaseStatus.unsupportedSchema
        ? loc.dpdUnsupportedSchema(state.schemaVersion)
        : loc.dpdNotInstalled;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storage, size: 40, color: colors.outlineVariant),
            const SizedBox(height: 12),
            Text(
              headline,
              textAlign: TextAlign.center,
              style: AppTypography.bodyTranslation.copyWith(
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              '${loc.dpdExpectedFile}: ${state.path}',
              textAlign: TextAlign.center,
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            if (state.status == DpdDatabaseStatus.notInstalled) ...[
              const SizedBox(height: 16),
              const DpdDownloadControl(centered: true),
            ],
          ],
        ),
      ),
    );
  }
}
