import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../../../core/models/translation_version.dart';
import '../../../core/utils/database_initializer.dart';
import '../../settings/providers/translation_download_provider.dart';
import '../providers/dpd_database_provider.dart';
import 'dpd_release_service.dart';

/// The download-state key of the DPD database, in the wizard, the gate, the
/// dictionary message and settings alike.
const kDpdDownloadKey = 'dpd_mobile';
const kDpdFilename = 'dpd-mobile.db';
const kDpdDisplayName = 'DPD Pāli Dictionary';

/// The wizard's required item for DPD. Its URL and size come from the newest
/// release when Download is tapped, not from the manifest.
const kDpdCoreAsset = CoreAsset(
  slug: kDpdDownloadKey,
  displayName: kDpdDisplayName,
  url: '',
  filename: kDpdFilename,
  compulsory: true,
);

/// The newest release, for showing its size before the download.
final dpdLatestReleaseProvider = FutureProvider.autoDispose<DpdRelease>(
  (ref) => DpdReleaseService().fetchLatest(),
);

/// Removes the copy the file picker made of the reader's file, but only when
/// it lies under the picker's folder in [cacheDir]: any other path is the
/// reader's own file, and the app never deletes that.
Future<void> deletePickerCopy(String path, Directory cacheDir) async {
  if (!p.isWithin(p.join(cacheDir.path, 'file_picker'), path)) return;
  try {
    await File(path).delete();
  } on FileSystemException {
    // Only a cache copy; the system clears the cache itself.
  }
}

/// The bytes an interrupted download left on disk, or 0. [partialName] is
/// the partial of the release the next press will download
/// ([partialZipName]); when the release is not known yet, the largest partial
/// of any release counts. A partial of an older release is not counted when
/// the name is known, because the next download deletes it. Nothing is
/// counted while a download or unpack runs. It reads again whenever a download
/// state changes, so Stop and a failure show their partial.
final dpdPartialBytesProvider = FutureProvider.autoDispose.family<int, String?>((
  ref,
  partialName,
) async {
  final state = ref.watch(translationDownloadProvider)[kDpdDownloadKey];
  if (state != null &&
      (state.status == DownloadStatus.downloading ||
          state.status == DownloadStatus.extracting)) {
    return 0;
  }
  final file = await ref.watch(dpdDatabaseFileProvider.future);
  var largest = 0;
  try {
    await for (final entity in file.parent.list()) {
      final name = p.basename(entity.path);
      final matches = partialName != null
          ? name == partialName
          : name.startsWith('$kDpdFilename.') && name.endsWith('.zip.part');
      if (entity is File && matches) {
        final length = await entity.length();
        if (length > largest) largest = length;
      }
    }
  } on FileSystemException {
    return 0;
  }
  return largest;
});

String formatDpdSize(int bytes) => '${(bytes / (1024 * 1024)).round()} MB';

/// A downloaded release this build cannot read.
class DpdUnsupportedRelease implements Exception {
  const DpdUnsupportedRelease(this.schema);

  final String? schema;

  @override
  String toString() =>
      'Update ePitaka to use this DPD release (schema ${schema ?? '?'}).';
}

/// Checks a freshly extracted DPD file before it replaces the old one, and
/// switches it out of WAL mode: the app opens it with writes refused, so this
/// is the only moment the switch can happen, and a WAL file would grow
/// `-wal` and `-shm` files next to it on every open.
Future<void> verifyDpdDownload(File tmpDb) async {
  final Database db;
  try {
    db = sqlite3.open(tmpDb.path);
  } on SqliteException catch (e) {
    throw FormatException(
      'The downloaded DPD database cannot be read: ${e.message}',
    );
  }
  try {
    final rows = db.select(
      "SELECT value FROM db_info WHERE key = 'db_schema_version'",
    );
    final schema = rows.isEmpty ? null : rows.first['value']?.toString();
    if (!kSupportedDpdSchemas.contains(schema)) {
      throw DpdUnsupportedRelease(schema);
    }
    db.execute('PRAGMA journal_mode=DELETE');
  } on SqliteException catch (e) {
    throw FormatException(
      'The downloaded DPD database cannot be read: ${e.message}',
    );
  } finally {
    db.dispose();
  }
  await cleanWalFiles(tmpDb.path);
}

/// Downloads [release], or the newest one when it is null, and puts it in
/// place of the current DPD file. The old file keeps answering until the new
/// one has passed every check. Progress and errors go to
/// [translationDownloadProvider] under [kDpdDownloadKey].
///
/// [service], [dbDir] and [client] are for tests.
Future<bool> installDpdRelease(
  WidgetRef ref, {
  DpdRelease? release,
  DpdReleaseService? service,
  Directory? dbDir,
  http.Client? client,
}) async {
  final notifier = ref.read(translationDownloadProvider.notifier);
  var target = release;
  if (target == null) {
    notifier.report(
      kDpdDownloadKey,
      const TranslationDownloadState(status: DownloadStatus.downloading),
    );
    try {
      target = await (service ?? DpdReleaseService()).fetchLatest();
    } on DpdReleaseException catch (e) {
      // A Stop during the lookup wins over the error it caused.
      if (notifier.stateFor(kDpdDownloadKey).status ==
          DownloadStatus.cancelled) {
        return false;
      }
      notifier.report(
        kDpdDownloadKey,
        TranslationDownloadState(
          status: DownloadStatus.error,
          errorMessage: e.message,
        ),
      );
      return false;
    }
    // Stop pressed while the release was looked up.
    if (notifier.stateFor(kDpdDownloadKey).status ==
        DownloadStatus.cancelled) {
      return false;
    }
  }
  return notifier.downloadCoreAsset(
    url: target.url,
    filename: kDpdFilename,
    displayName: kDpdDisplayName,
    ref: ref,
    versionKey: kDpdDownloadKey,
    expectedBytes: target.size,
    expectedZipSha256: target.sha256,
    resume: true,
    verify: verifyDpdDownload,
    swap: (replace, invalidate) => swapDpdDatabase(invalidate, replace),
    dbDir: dbDir,
    client: client,
  );
}

/// Installs the zip the reader picked, as [installDpdRelease] installs a
/// download, with the same checks. The picked file is never deleted. [dbDir]
/// is for tests.
Future<bool> importDpdZip(
  WidgetRef ref,
  String path, {
  Directory? dbDir,
}) {
  return ref
      .read(translationDownloadProvider.notifier)
      .importCoreZip(
        zip: File(path),
        filename: kDpdFilename,
        displayName: kDpdDisplayName,
        ref: ref,
        versionKey: kDpdDownloadKey,
        verify: verifyDpdDownload,
        swap: (replace, invalidate) => swapDpdDatabase(invalidate, replace),
        dbDir: dbDir,
      );
}
