import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../settings/providers/translation_download_provider.dart';
import '../providers/dpd_database_provider.dart';
import '../services/dpd_installer.dart';
import '../services/dpd_release_service.dart';

/// The folder the reader last imported from, so the desktop dialog opens there.
const _kLastImportFolder = 'dpd_import_last_folder';

/// The DPD download as one control: the button (Resume when a partial file is
/// on disk), then progress with Stop, or the error with Retry. The start-up
/// gate, the dictionary message and settings all show this, so a download
/// started in one shows in the others.
class DpdDownloadControl extends ConsumerWidget {
  const DpdDownloadControl({
    super.key,
    this.release,
    this.label,
    this.centered = false,
    this.leading,
    this.primary = true,
  });

  /// Downloaded when known; otherwise the newest release is looked up first.
  final DpdRelease? release;

  /// The button's text when idle; "Download" by default.
  final String? label;

  /// For a centred screen (the start-up gate, the dictionary message);
  /// settings lines it up on the left.
  final bool centered;

  /// A button placed first in the row of buttons, so a screen can keep its own
  /// action (Check now in settings) in the same row.
  final Widget? leading;

  /// Whether the main button is the recommended next step, so it is filled.
  /// Otherwise it is outlined like the other buttons. A failure or a partial
  /// file to resume always makes it the recommended step.
  final bool primary;

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

    // Retry only makes sense with nothing installed: a failed import or
    // download leaves a good database as it was, and the error line says why.
    final installed = ref.watch(dpdFileInstalledProvider).valueOrNull ?? false;
    final failed = state.status == DownloadStatus.error && !installed;
    final partial =
        ref
            .watch(
              dpdPartialBytesProvider(
                release == null
                    ? null
                    : partialZipName(kDpdFilename, release!.sha256),
              ),
            )
            .valueOrNull ??
        0;
    final resumable = partial > 0;
    const mb = 1024 * 1024;
    final mainButton = primary || resumable || failed
        ? FilledButton.icon
        : OutlinedButton.icon;
    return Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state.status == DownloadStatus.error &&
            state.errorMessage != null) ...[
          SelectableText(
            state.errorMessage!,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: AppTypography.labelSmall.copyWith(color: colors.error),
          ),
          const SizedBox(height: 8),
        ],
        if (resumable) ...[
          Text(
            loc.dpdAlreadyDownloaded(
              (partial / mb).round(),
              release == null ? null : (release!.size / mb).round(),
            ),
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: centered ? WrapAlignment.center : WrapAlignment.start,
          children: [
            ?leading,
            mainButton(
              onPressed: () => installDpdRelease(ref, release: release),
              icon: Icon(
                resumable
                    ? Icons.play_arrow
                    : failed
                    ? Icons.refresh
                    : Icons.download,
              ),
              label: Text(
                resumable
                    ? loc.resume
                    : failed
                    ? loc.retry
                    : (label ?? loc.download),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _importFromFile(ref, loc.dpdImportFromFile),
              icon: const Icon(Icons.folder_open),
              label: Text(loc.dpdImportFromFile),
            ),
          ],
        ),
      ],
    );
  }

  /// The path of the zip the reader picks, or null when they cancel. A phone
  /// uses the system picker, which copies the file into the app's cache. A
  /// desktop uses the same picker as the MDX import: the file_picker dialog
  /// on Linux is opened without a parent window, so the desktop leaves it
  /// behind the app.
  Future<String?> _pickZip(String title) async {
    if (Platform.isAndroid || Platform.isIOS) {
      final picked = await FilePicker.pickFiles(
        dialogTitle: title,
        type: FileType.custom,
        allowedExtensions: const ['zip'],
      );
      return picked?.files.firstOrNull?.path;
    }
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(_kLastImportFolder);
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'ZIP', extensions: ['zip']),
      ],
      initialDirectory: last != null && Directory(last).existsSync()
          ? last
          : null,
      confirmButtonText: title,
    );
    if (file == null) return null;
    await prefs.setString(_kLastImportFolder, p.dirname(file.path));
    return file.path;
  }

  /// Installs a `dpd-mobile-db.zip` the reader already has. The picker hands
  /// a phone a copy in the app's cache: that copy goes once the import ends,
  /// and no other file is ever deleted.
  Future<void> _importFromFile(WidgetRef ref, String title) async {
    final notifier = ref.read(translationDownloadProvider.notifier);
    final String? path;
    try {
      path = await _pickZip(title);
    } catch (e) {
      notifier.report(
        kDpdDownloadKey,
        TranslationDownloadState(
          status: DownloadStatus.error,
          errorMessage: 'Could not open the file picker: $e',
        ),
      );
      return;
    }
    if (path == null) return;
    await importDpdZip(ref, path);
    if (Platform.isAndroid || Platform.isIOS) {
      await deletePickerCopy(path, await getTemporaryDirectory());
    }
  }
}
