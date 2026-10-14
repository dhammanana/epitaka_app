import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_localizations.dart';
import '../../settings/providers/translation_download_provider.dart';
import '../services/dpd_installer.dart';
import '../services/dpd_release_service.dart';
import 'dpd_download_control.dart';

/// Offers a newer DPD release. Only its buttons close it (user: "It can't be
/// something that pops up and disappears"): a tap outside or the back key
/// does nothing. Later waits for the next daily check. After Download it
/// shows the progress, and closes itself once the new file is in place; the
/// download carries on if it is closed earlier.
class DpdUpdateDialog extends ConsumerWidget {
  const DpdUpdateDialog({super.key, required this.release});

  final DpdRelease release;

  static Future<void> show(BuildContext context, DpdRelease release) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DpdUpdateDialog(release: release),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    ref.listen(
      translationDownloadProvider.select((m) => m[kDpdDownloadKey]?.status),
      (_, status) {
        if (status != DownloadStatus.completed || !context.mounted) return;
        // Removes this dialog even when another route opened above it.
        final route = ModalRoute.of(context);
        if (route != null) Navigator.of(context).removeRoute(route);
      },
    );
    final download =
        ref.watch(translationDownloadProvider)[kDpdDownloadKey] ??
        const TranslationDownloadState();
    final running =
        download.status == DownloadStatus.downloading ||
        download.status == DownloadStatus.extracting;
    final failed = download.status == DownloadStatus.error;
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(loc.dpdUpdateTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.dpdUpdateBody(release.tag, formatDpdSize(release.size))),
            // Progress shows in the body; the buttons stay together below.
            if (running) ...[
              const SizedBox(height: 16),
              DpdDownloadControl(release: release),
            ],
            if (failed && download.errorMessage != null) ...[
              const SizedBox(height: 16),
              SelectableText(
                download.errorMessage!,
                style: TextStyle(color: colors.error),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(running ? loc.close : loc.later),
          ),
          if (!running)
            FilledButton.icon(
              onPressed: () => installDpdRelease(ref, release: release),
              icon: Icon(failed ? Icons.refresh : Icons.download),
              label: Text(failed ? loc.retry : loc.download),
            ),
        ],
      ),
    );
  }
}
