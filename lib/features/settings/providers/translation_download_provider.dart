import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/download_foreground_service.dart';
import '../services/download_notification_service.dart';

import '../../../core/models/app_models.dart';
import '../../../core/models/translation_version.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/translation_manifest_provider.dart';
import '../../../core/providers/translation_registry_provider.dart';
import '../../../core/providers/dpd_dictionary_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/database_initializer.dart';

/// Download state for a specific translation version.
enum DownloadStatus {
  idle,
  downloading,
  extracting,
  completed,
  cancelled,
  error,
}

class TranslationDownloadState {
  final DownloadStatus status;
  final double progress;
  final String? errorMessage;

  const TranslationDownloadState({
    this.status = DownloadStatus.idle,
    this.progress = 0.0,
    this.errorMessage,
  });

  TranslationDownloadState copyWith({
    DownloadStatus? status,
    double? progress,
    String? errorMessage,
  }) {
    return TranslationDownloadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Provider that manages downloading translation database files.
///
/// State is a map of version key (langCode[_suffix]) → download state,
/// so multiple downloads can be tracked independently.
class TranslationDownloadNotifier
    extends StateNotifier<Map<String, TranslationDownloadState>> {
  final Map<String, CancelableCompleter> _cancelTokens = {};

  TranslationDownloadNotifier() : super({});

  /// Get the download state for a specific version key.
  TranslationDownloadState stateFor(String versionKey) {
    return state[versionKey] ?? const TranslationDownloadState();
  }

  /// Stable per-version key used for download state and installed-date
  /// metadata (e.g. `en`, `my_nissaya`).
  static String versionKeyFor(TranslationVersion version) {
    return version.suffix != null && version.suffix!.isNotEmpty
        ? '${version.languageCode}_${version.suffix}'
        : version.languageCode;
  }

  /// Get the download URL for a translation version.
  /// Returns null if no URL is available from the manifest.
  static String? getDownloadUrl(TranslationVersion version) {
    return version.hasDownloadUrl ? version.downloadUrl : null;
  }

  /// The date (`yyyy-MM-dd`) of the version currently installed on disk.
  ///
  /// For databases downloaded through the app this is the manifest date that
  /// was recorded when the download finished. For bundled databases (which
  /// are copied from the app assets on first launch and never downloaded
  /// through the app, e.g. English) it falls back to the DB file's
  /// last-modified date. Returns null when the version isn't installed.
  ///
  /// [dbDir] overrides the database directory (tests inject a temp dir;
  /// production leaves it null to use the real per-user directory).
  static Future<String?> getInstalledDate(
    TranslationVersion version, {
    Directory? dbDir,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('version_updated_${versionKeyFor(version)}');
    if (saved != null && saved.isNotEmpty) return saved;
    return _fileModifiedDate(version, dbDir: dbDir);
  }

  /// The DB file's last-modified date formatted `yyyy-MM-dd`, or null when
  /// the file isn't on disk. Used as the installed-date fallback for
  /// bundled translations that never went through the download flow.
  static Future<String?> _fileModifiedDate(
    TranslationVersion version, {
    Directory? dbDir,
  }) async {
    try {
      final dir = dbDir ?? await getDatabaseDirectory();
      final file = File(p.join(dir.path, version.filename));
      if (!await file.exists()) return null;
      if (await file.length() == 0) return null;
      final stat = await file.stat();
      final t = stat.modified;
      return '${t.year.toString().padLeft(4, '0')}-'
          '${t.month.toString().padLeft(2, '0')}-'
          '${t.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return null;
    }
  }

  /// Check if an update is available for a locally installed version.
  /// Returns true when the installed date is older than the manifest's
  /// [TranslationVersion.updatedAt] (dates always move forward). Works for
  /// both app-downloaded and bundled databases — bundled ones fall back to
  /// the file's modification date instead of a recorded download date.
  ///
  /// [dbDir] overrides the database directory (tests inject a temp dir).
  static Future<bool> isUpdateAvailable(
    TranslationVersion version, {
    Directory? dbDir,
  }) async {
    if (!version.isAvailable || !version.hasDownloadUrl) return false;
    if (version.updatedAt == null || version.updatedAt!.isEmpty) return false;

    final installed = await getInstalledDate(version, dbDir: dbDir);
    if (installed == null || installed.isEmpty) return false;
    return installed.compareTo(version.updatedAt!) < 0;
  }

  /// Start (or attach to) the download foreground service. Returns whether
  /// the ongoing status-bar notification is active (callers fall back to a
  /// plain local notification when false).
  ///
  /// The foreground service itself is ref-counted per owner (downloads vs
  /// translation runs), so multiple downloads and a translation run sharing
  /// the process keep each other alive until the last one finishes.
  Future<bool> _fgsStart({required String title, required String text}) async {
    return DownloadForegroundService.instance.showDownload(
      title: title,
      text: text,
    );
  }

  /// Detach this download from the foreground service. The service stops
  /// itself once no download or translation run needs it any more.
  Future<void> _fgsStop() async {
    await DownloadForegroundService.instance.hideDownload();
  }

  /// Cancel an in-progress download for a version key.
  void cancelDownload(String versionKey) {
    final token = _cancelTokens[versionKey];
    if (token != null) {
      token.cancel();
      _cancelTokens.remove(versionKey);
    }
    state = {
      ...state,
      versionKey: const TranslationDownloadState(
        status: DownloadStatus.cancelled,
      ),
    };
  }

  /// Download and install a translation database version.
  /// Pass [ref] to invalidate the registry after success.
  Future<void> downloadVersion(
    TranslationVersion version,
    WidgetRef ref,
  ) async {
    final versionKey = version.suffix != null && version.suffix!.isNotEmpty
        ? '${version.languageCode}_${version.suffix}'
        : version.languageCode;

    // Clean up any previous cancel token
    _cancelTokens.remove(versionKey);

    // Get download URL
    final url = getDownloadUrl(version);
    if (url == null) {
      state = {
        ...state,
        versionKey: TranslationDownloadState(
          status: DownloadStatus.error,
          errorMessage: 'No download URL available for ${version.displayName}',
        ),
      };
      return;
    }

    // Mark as downloading.
    state = {
      ...state,
      versionKey: const TranslationDownloadState(
        status: DownloadStatus.downloading,
        progress: 0.0,
      ),
    };
    // Show an ongoing status-bar notification. On Android this starts a
    // real foreground service (dataSync type) that keeps the app process
    // alive so the download continues while the user is in another app;
    // when the service can't start (e.g. notification permission denied)
    // it falls back to a plain local notification that only shows while
    // the app is foregrounded.
    final fgsActive = await _fgsStart(
      title: 'Downloading ${version.displayName}',
      text: '0%',
    );
    if (!fgsActive) {
      DownloadNotificationService.instance.showTranslationProgress(
        versionKey: versionKey,
        displayName: version.displayName,
        progress: 0.0,
        isIndeterminate: false,
      );
    }

    final cancelToken = CancelableCompleter();
    _cancelTokens[versionKey] = cancelToken;

    // Temp files (declared here so the catch block can clean them up).
    File? zipFile;
    String? tmpDbPath;

    try {
      final dbDir = await getDatabaseDirectory();
      // Stream the .zip straight to disk: the databases are hundreds of MB
      // and holding them in memory OOM-kills low-RAM devices (the main
      // Tipitaka zip died at ~79% on a 2GB Android 10 tablet).
      zipFile = File(p.join(dbDir.path, '${version.filename}.zip.tmp'));
      if (await zipFile.exists()) await zipFile.delete();
      tmpDbPath = p.join(dbDir.path, '${version.filename}.tmp');

      final client = http.Client();
      var lastShownPct = -1;
      try {
        await _streamDownloadToFile(
          url: url,
          destZip: zipFile,
          cancelToken: cancelToken,
          client: client,
          expectedBytes: version.fileSize ?? 0,
          onProgress: (progress) {
            final pct = (progress * 100).round().clamp(0, 100);
            state = {
              ...state,
              versionKey: TranslationDownloadState(
                status: DownloadStatus.downloading,
                progress: pct / 100,
              ),
            };
            if (pct == lastShownPct) return;
            lastShownPct = pct;
            if (fgsActive) {
              DownloadForegroundService.instance.updateDownload(
                title: 'Downloading ${version.displayName}',
                text: '$pct%',
              );
            } else {
              DownloadNotificationService.instance.showTranslationProgress(
                versionKey: versionKey,
                displayName: version.displayName,
                progress: pct / 100,
                isIndeterminate: false,
              );
            }
          },
        );
      } finally {
        client.close();
      }
      _cancelTokens.remove(versionKey);

      if (cancelToken.isCancelled) {
        await _fgsStop();
        DownloadNotificationService.instance.dismissTranslation();
        state = {
          ...state,
          versionKey: const TranslationDownloadState(
            status: DownloadStatus.cancelled,
          ),
        };
        return;
      }

      // Extract the .db from the zip.
      state = {
        ...state,
        versionKey: const TranslationDownloadState(
          status: DownloadStatus.extracting,
        ),
      };
      if (fgsActive) {
        DownloadForegroundService.instance.updateDownload(
          title: 'Extracting ${version.displayName}',
          text: '…',
        );
      } else {
        DownloadNotificationService.instance.showTranslationProgress(
          versionKey: versionKey,
          displayName: version.displayName,
          progress: 1.0,
          isIndeterminate: true,
        );
      }

      // Streams the entry straight to disk and verifies size/checksum, so
      // the ~500MB database is never held fully in memory. Throws with a
      // human-readable message when the zip has no .db or is corrupt.
      await _extractDbFromZip(
        zipPath: zipFile.path,
        tmpPath: tmpDbPath,
        expectedChecksum: version.checksum,
        expectedDbSize: version.dbSize,
      );

      // Write the .db file safely via a temp file to prevent corruption/truncation
      final destPath = p.join(dbDir.path, version.filename);
      final tempFile = File(tmpDbPath);

      // Remove stale WAL/SHM files before replacing the database
      await cleanWalFiles(destPath);

      // Atomically replace destination
      await tempFile.rename(destPath);

      // Save the updatedAt metadata for update-checking
      if (version.updatedAt != null && version.updatedAt!.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'version_updated_$versionKey',
          version.updatedAt!,
        );
      }

      // Invalidate providers
      ref.invalidate(translationRegistryProvider);
      ref.invalidate(mergedTranslationVersionsProvider);
      ref.invalidate(localTranslationVersionsProvider);

      // Also invalidate version-specific db providers if applicable
      if (version.isNissaya) {
        ref.invalidate(nissayaDbByFilenameProvider(version.filename));
      } else {
        ref.invalidate(translationDbProvider(version.languageCode));
      }

      // Auto-enable the newly downloaded translation so the user doesn't
      // have to manually toggle it on after waiting for the download.
      final settingsState = ref.read(settingsProvider);
      if (!settingsState.enabledTranslations.contains(version.languageCode)) {
        await ref
            .read(settingsProvider.notifier)
            .setTranslationEnabled(version.languageCode, true);
      }

      await _fgsStop();
      state = {
        ...state,
        versionKey: const TranslationDownloadState(
          status: DownloadStatus.completed,
          progress: 1.0,
        ),
      };
      DownloadNotificationService.instance.showTranslationComplete(
        version.displayName,
      );
    } catch (e) {
      await _fgsStop();
      if (cancelToken.isCancelled) {
        DownloadNotificationService.instance.dismissTranslation();
        state = {
          ...state,
          versionKey: const TranslationDownloadState(
            status: DownloadStatus.cancelled,
          ),
        };
      } else {
        DownloadNotificationService.instance.showTranslationError(
          version.displayName,
          e.toString(),
        );
        state = {
          ...state,
          versionKey: TranslationDownloadState(
            status: DownloadStatus.error,
            errorMessage: e.toString(),
          ),
        };
      }
      _cancelTokens.remove(versionKey);
    }
  }

  /// Legacy method: download a translation by language.
  /// Delegates to downloadVersion with a default version.
  Future<void> downloadTranslation(
    TranslationLanguage lang,
    WidgetRef ref,
  ) async {
    final version = TranslationVersion(
      languageCode: lang.code,
      filename: lang.filename,
      isAvailable: false,
      displayName: 'Default',
    );
    await downloadVersion(version, ref);
  }

  /// Download a core asset (epitaka, dpd_dictionary) from the given URL
  /// and save the extracted .db file to the database directory.
  Future<bool> downloadCoreAsset({
    required String url,
    required String filename,
    required String displayName,
    required WidgetRef ref,
    String? versionKey,
    int? expectedBytes,
  }) async {
    final key = versionKey ?? filename.replaceAll('.db', '');
    _cancelTokens.remove(key);

    state = {
      ...state,
      key: const TranslationDownloadState(
        status: DownloadStatus.downloading,
        progress: 0.0,
      ),
    };

    // Same background keep-alive as translation downloads: these are the
    // large core databases (epitaka.db, dpd-dictionary.db), so a dropped
    // download while switching apps would be especially painful.
    final fgsActive = await _fgsStart(
      title: 'Downloading $displayName',
      text: '0%',
    );
    if (!fgsActive) {
      DownloadNotificationService.instance.showTranslationProgress(
        versionKey: key,
        displayName: displayName,
        progress: 0.0,
        isIndeterminate: false,
      );
    }
    final cancelToken = CancelableCompleter();
    _cancelTokens[key] = cancelToken;

    try {
      final dbDir = await getDatabaseDirectory();
      // Stream the .zip straight to disk: the core databases are hundreds
      // of MB and holding them in memory OOM-kills low-RAM devices (the
      // main Tipitaka zip died at ~79% on a 2GB Android 10 tablet).
      final zipFile = File(p.join(dbDir.path, '$filename.zip.tmp'));
      if (await zipFile.exists()) await zipFile.delete();
      final tmpDbPath = p.join(dbDir.path, '$filename.tmp');

      final client = http.Client();
      var lastShownPct = -1;
      try {
        await _streamDownloadToFile(
          url: url,
          destZip: zipFile,
          cancelToken: cancelToken,
          client: client,
          expectedBytes: expectedBytes ?? 0,
          onProgress: (progress) {
            final pct = (progress * 100).round().clamp(0, 100);
            state = {
              ...state,
              key: TranslationDownloadState(
                status: DownloadStatus.downloading,
                progress: pct / 100,
              ),
            };
            if (pct == lastShownPct) return;
            lastShownPct = pct;
            if (fgsActive) {
              DownloadForegroundService.instance.updateDownload(
                title: 'Downloading $displayName',
                text: '$pct%',
              );
            } else {
              DownloadNotificationService.instance.showTranslationProgress(
                versionKey: key,
                displayName: displayName,
                progress: pct / 100,
                isIndeterminate: false,
              );
            }
          },
        );
      } finally {
        client.close();
      }
      _cancelTokens.remove(key);

      if (cancelToken.isCancelled) {
        await _fgsStop();
        DownloadNotificationService.instance.dismissTranslation();
        state = {
          ...state,
          key: const TranslationDownloadState(status: DownloadStatus.cancelled),
        };
        return false;
      }

      state = {
        ...state,
        key: const TranslationDownloadState(status: DownloadStatus.extracting),
      };
      if (fgsActive) {
        DownloadForegroundService.instance.updateDownload(
          title: 'Extracting $displayName',
          text: '…',
        );
      } else {
        DownloadNotificationService.instance.showTranslationProgress(
          versionKey: key,
          displayName: displayName,
          progress: 1.0,
          isIndeterminate: true,
        );
      }

      // Streams the entry straight to disk, so the ~500MB database is never
      // held fully in memory. Throws with a human-readable message when the
      // zip has no .db or is corrupt.
      await _extractDbFromZip(zipPath: zipFile.path, tmpPath: tmpDbPath);

      final destPath = p.join(dbDir.path, filename);
      final tempFile = File(tmpDbPath);

      // Clean up stale WAL / SHM files
      await cleanWalFiles(destPath);

      // Atomically replace destination
      await tempFile.rename(destPath);

      // If the DPD dictionary was just replaced on disk, drop the memoized
      // lookup/headword results in the open handle so it never serves stale
      // rows for words the user looks up again after the update.
      if (filename == 'dpd-dictionary.db') {
        final db = await ref.read(dpdDictionaryDbProvider.future);
        db.clearCaches();
      }

      await _fgsStop();
      state = {
        ...state,
        key: const TranslationDownloadState(
          status: DownloadStatus.completed,
          progress: 1.0,
        ),
      };
      DownloadNotificationService.instance.showTranslationComplete(displayName);

      // Invalidate translation-registry providers so the startup wizard
      // updates the continue button state after a core download finishes.
      ref.invalidate(translationRegistryProvider);
      ref.invalidate(localTranslationVersionsProvider);

      return true;
    } catch (e) {
      await _fgsStop();
      _cancelTokens.remove(key);
      if (cancelToken.isCancelled) {
        DownloadNotificationService.instance.dismissTranslation();
        state = {
          ...state,
          key: const TranslationDownloadState(status: DownloadStatus.cancelled),
        };
      } else {
        // Previously silent: the notification just vanished and the wizard
        // showed no reason, so failures looked like the download "closed".
        DownloadNotificationService.instance.showTranslationError(
          displayName,
          e.toString(),
        );
        state = {
          ...state,
          key: TranslationDownloadState(
            status: DownloadStatus.error,
            errorMessage: e.toString(),
          ),
        };
      }
      return false;
    }
  }

  /// Streams the response body of [url] into [destZip] chunk by chunk, so
  /// even multi-hundred-MB zips never sit in memory (in-memory accumulation
  /// OOM-killed low-RAM devices mid-download).
  ///
  /// Progress reports are throttled to ~1 percentage point / 400ms and
  /// clamped to 0..1 (a wrong Content-Length must never show 789%). When
  /// the server sends no Content-Length, [expectedBytes] (the manifest zip
  /// size) is used as the denominator; when neither is known, progress
  /// stays 0.0 so the UI shows an indeterminate bar.
  ///
  /// Throws [HttpException] on HTTP errors, [_DownloadCancelled] when
  /// [cancelToken] is cancelled. Partial files are deleted before throwing.
  Future<void> _streamDownloadToFile({
    required String url,
    required File destZip,
    required CancelableCompleter cancelToken,
    required http.Client client,
    int expectedBytes = 0,
    void Function(double progress)? onProgress,
  }) async {
    final request = http.Request('GET', Uri.parse(url));
    final response = await client.send(request);

    if (response.statusCode != 200) {
      await _deleteQuietly(destZip);
      throw HttpException('Download failed (HTTP ${response.statusCode})');
    }

    final headerLength = response.contentLength ?? 0;
    final total = headerLength > 0 ? headerLength : expectedBytes;
    final sink = destZip.openWrite();
    try {
      var received = 0;
      var lastReportMs = 0;
      var lastReportedPct = -1;
      await for (final chunk in response.stream) {
        if (cancelToken.isCancelled) throw _DownloadCancelled();
        sink.add(chunk);
        received += chunk.length;
        if (total <= 0) continue;
        final pct = (received / total * 100).round().clamp(0, 100);
        final now = DateTime.now().millisecondsSinceEpoch;
        if (pct != lastReportedPct &&
            (pct - lastReportedPct >= 1 || now - lastReportMs >= 400)) {
          lastReportedPct = pct;
          lastReportMs = now;
          onProgress?.call(pct / 100);
        }
      }
      await sink.flush();
      if (total > 0) {
        onProgress?.call((received / total).clamp(0.0, 1.0));
      } else {
        onProgress?.call(1.0);
      }
    } catch (_) {
      await sink.close();
      await _deleteQuietly(destZip);
      rethrow;
    }
    await sink.close();
  }

  /// Extracts the first `.db` entry of the zip at [zipPath] to [tmpPath]
  /// and verifies it against [expectedChecksum]/[expectedDbSize].
  ///
  /// The inflate runs in a background isolate and streams straight to
  /// disk (`ArchiveFile.writeContent`), and the checksum is computed by
  /// streaming the file back — the ~500MB database is never held fully
  /// in memory. Throws with a human-readable message on any failure.
  Future<void> _extractDbFromZip({
    required String zipPath,
    required String tmpPath,
    String? expectedChecksum,
    int? expectedDbSize,
  }) async {
    final tmpFile = File(tmpPath);
    if (await tmpFile.exists()) await tmpFile.delete();
    try {
      await Isolate.run(() async {
        final input = InputFileStream(zipPath);
        try {
          final archive = ZipDecoder().decodeStream(input);
          ArchiveFile? dbEntry;
          for (final entry in archive) {
            if (entry.isFile && entry.name.endsWith('.db')) {
              dbEntry = entry;
              break;
            }
          }
          if (dbEntry == null) {
            throw const FormatException(
              'No database file found in the archive',
            );
          }
          final output = OutputFileStream(tmpPath);
          try {
            dbEntry.writeContent(output);
          } finally {
            await output.close();
          }
        } finally {
          await input.close();
        }
      });

      final size = await tmpFile.length();
      if (size == 0) {
        throw const FormatException(
          'Extracted database file is empty (0 bytes)',
        );
      }
      if (expectedDbSize != null &&
          expectedDbSize > 0 &&
          size != expectedDbSize) {
        throw FormatException(
          'Size mismatch — expected $expectedDbSize bytes, got $size',
        );
      }
      if (expectedChecksum != null && expectedChecksum.isNotEmpty) {
        final actual = await _sha256OfFile(tmpFile);
        if (!_hexEquals(actual, expectedChecksum)) {
          throw FormatException(
            'Checksum mismatch — expected $expectedChecksum, got $actual',
          );
        }
      }
    } catch (_) {
      await _deleteQuietly(tmpFile);
      rethrow;
    }
  }

  /// SHA-256 of [file], computed by streaming so large databases don't
  /// need to fit in memory.
  Future<String> _sha256OfFile(File file) async {
    final accumulator = _DigestAccumulator();
    final hashSink = sha256.startChunkedConversion(accumulator);
    await for (final chunk in file.openRead()) {
      hashSink.add(chunk);
    }
    hashSink.close();
    return accumulator.value.toString();
  }

  /// Best-effort delete of a temp/partial file. Never throws.
  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Delete a translation database file from disk.
  Future<bool> deleteVersion(TranslationVersion version) async {
    final dbDir = await getDatabaseDirectory();
    final filePath = p.join(dbDir.path, version.filename);
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }
}

/// Case-insensitive hex comparison for SHA-256 strings (the server emits
/// lowercase; keep the comparison forgiving).
bool _hexEquals(String a, String b) => a.toLowerCase() == b.toLowerCase();

/// Verify downloaded database content against the manifest.
///
/// The server's `checksum` is the SHA-256 of the .db file inside the zip
/// (not the zip itself), so [dbContent] (the extracted bytes) must hash to
/// it. [expectedDbSize] is the size of that same .db file. Returns null
/// when everything matches, otherwise an error message describing the
/// mismatch. A missing/empty expected checksum or size skips that check
/// (older manifest entries may not publish them).
String? verifyDownloadedDb({
  required List<int> dbContent,
  String? expectedChecksum,
  int? expectedDbSize,
}) {
  if (expectedChecksum != null && expectedChecksum.isNotEmpty) {
    final actual = sha256.convert(dbContent).toString();
    if (!_hexEquals(actual, expectedChecksum)) {
      return 'Checksum mismatch — expected $expectedChecksum, got $actual';
    }
  }
  if (expectedDbSize != null && expectedDbSize > 0) {
    if (dbContent.length != expectedDbSize) {
      return 'Size mismatch — expected $expectedDbSize bytes, got ${dbContent.length}';
    }
  }
  return null;
}

/// Simple cancel token for cooperative cancellation.
class CancelableCompleter {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
  }
}

/// Thrown to unwind a streaming download the user cancelled. Caught by the
/// download methods and mapped to [DownloadStatus.cancelled] (never shown
/// as an error).
class _DownloadCancelled implements Exception {
  const _DownloadCancelled();
}

/// Minimal [Sink] collecting the single [Digest] produced by a chunked
/// hash conversion, so large files can be hashed by streaming.
class _DigestAccumulator implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value ??= data;

  @override
  void close() {}
}

final translationDownloadProvider =
    StateNotifierProvider<
      TranslationDownloadNotifier,
      Map<String, TranslationDownloadState>
    >((ref) => TranslationDownloadNotifier());
