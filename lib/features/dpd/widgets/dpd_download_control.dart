import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../settings/providers/translation_download_provider.dart';
import '../services/dpd_installer.dart';
import '../services/dpd_release_service.dart';

/// The DPD download as one control: the button, then progress with Stop, or
/// the error with Retry. The start-up gate, the dictionary message and
/// settings all show this, so a download started in one shows in the others.
class DpdDownloadControl extends ConsumerWidget {
  const DpdDownloadControl({
    super.key,
    this.release,
    this.label,
    this.centered = false,
  });

  /// Downloaded when known; otherwise the newest release is looked up first.
  final DpdRelease? release;

  /// The button's text when idle; "Download" by default.
  final String? label;

  /// For a centred screen (the start-up gate, the dictionary message);
  /// settings lines it up on the left.
  final bool centered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final state =
        ref.watch(translationDownloadProvider)[kDpdDownloadKey] ??
        const TranslationDownloadState();
    final extracting = state.status == DownloadStatus.extracting;

    if (state.status == DownloadStatus.downloading || extracting) {
      final known = !extracting && state.progress > 0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            extracting
                ? loc.dpdUnpacking
                : known
                ? '${loc.dpdDownloading} ${(state.progress * 100).round()}%'
                : loc.dpdDownloading,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: AppTypography.labelMedium.copyWith(color: colors.primary),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: known ? state.progress.clamp(0.0, 1.0) : null,
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
          if (!extracting)
            Align(
              alignment: centered ? Alignment.center : Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => ref
                    .read(translationDownloadProvider.notifier)
                    .cancelDownload(kDpdDownloadKey),
                icon: const Icon(Icons.stop),
                label: Text(loc.stopLabel),
              ),
            ),
        ],
      );
    }

    final failed = state.status == DownloadStatus.error;
    return Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (failed && state.errorMessage != null) ...[
          SelectableText(
            state.errorMessage!,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: AppTypography.labelSmall.copyWith(color: colors.error),
          ),
          const SizedBox(height: 8),
        ],
        FilledButton.icon(
          onPressed: () => installDpdRelease(ref, release: release),
          icon: Icon(failed ? Icons.refresh : Icons.download),
          label: Text(failed ? loc.retry : (label ?? loc.download)),
        ),
      ],
    );
  }
}
