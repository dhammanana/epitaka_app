// The two ways a database gets into the app without a plain download:
// continuing one that stopped (resume), and installing a zip the reader
// already has (import from file). The DPD download, the translation files and
// the core assets (epitaka.db) all come through here, so the behaviour is the
// same everywhere and nothing is copied per screen.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/database_initializer.dart';
import '../providers/translation_download_provider.dart';

/// The folder the reader last imported from, so the desktop dialog opens there.
const _kLastImportFolder = 'zip_import_last_folder';

/// The path of the zip the reader picks, or null when they cancel.
///
/// A phone uses the system picker, which copies the file into the app's
/// cache — [discardPickerCopy] removes that copy. A desktop uses the same
/// dialog as the MDX import: the file_picker dialog on Linux is opened
/// without a parent window, so the desktop leaves it behind the app.
Future<String?> pickZipToImport(String title) async {
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

/// Removes the copy the file picker made of the reader's file, but only when
/// it lies under the picker's folder in the cache: any other path is the
/// reader's own file, and the app never deletes that.
Future<void> discardPickerCopy(String path, {Directory? cacheDir}) async {
  final cache = cacheDir ?? await getTemporaryDirectory();
  if (!p.isWithin(p.join(cache.path, 'file_picker'), path)) return;
  try {
    await File(path).delete();
  } on FileSystemException {
    // Only a cache copy; the system clears the cache itself.
  }
}

/// Installs a zip the reader picks as the download of [versionKey].
///
/// [install] receives the picked path and returns whether it was installed;
/// [filename] and [title] only drive the picker and the error text. The
/// picker's cache copy is removed afterwards, whatever the outcome.
Future<bool> importZipWithPicker({
  required WidgetRef ref,
  required String title,
  required String versionKey,
  required Future<bool> Function(String path) install,
}) async {
  final notifier = ref.read(translationDownloadProvider.notifier);
  final String? path;
  try {
    path = await pickZipToImport(title);
  } catch (e) {
    notifier.report(
      versionKey,
      TranslationDownloadState(
        status: DownloadStatus.error,
        errorMessage: 'Could not open the file picker: $e',
      ),
    );
    return false;
  }
  if (path == null) return false;
  try {
    return await install(path);
  } finally {
    if (Platform.isAndroid || Platform.isIOS) await discardPickerCopy(path);
  }
}

/// The bytes an interrupted download of [filename] left on disk, or 0.
///
/// [partialName] is the partial of the release the next press will download
/// (see `partialZipName`); when null, the largest partial of any release
/// counts. A partial of an older release is not counted when the name is
/// known, because the next download deletes it.
Future<int> partialZipBytesIn(
  Directory dir, {
  required String filename,
  String? partialName,
}) async {
  var largest = 0;
  try {
    await for (final entity in dir.list()) {
      final name = p.basename(entity.path);
      final matches = partialName != null
          ? name == partialName
          : name.startsWith('$filename.') && name.endsWith('.zip.part');
      if (entity is File && matches) {
        final length = await entity.length();
        if (length > largest) largest = length;
      }
    }
  } on FileSystemException {
    return largest;
  }
  return largest;
}

/// [partialZipBytesIn] as the UI wants it: 0 while a download or unpack runs,
/// so Stop and a failure show what is actually on disk.
final partialDownloadBytesProvider = FutureProvider.autoDispose
    .family<int, ({String filename, String? partialName, String versionKey})>((
      ref,
      query,
    ) async {
      final state = ref.watch(translationDownloadProvider)[query.versionKey];
      if (state != null &&
          (state.status == DownloadStatus.downloading ||
              state.status == DownloadStatus.extracting)) {
        return 0;
      }
      final dir = await getDatabaseDirectory();
      return partialZipBytesIn(
        dir,
        filename: query.filename,
        partialName: query.partialName,
      );
    });
