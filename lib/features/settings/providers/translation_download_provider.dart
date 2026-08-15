import 'dart:async';
import 'dart:io';

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
import '../../../core/utils/database_initializer.dart';

/// Download state for a specific translation version.
enum DownloadStatus { idle, downloading, extracting, completed, cancelled, error }

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

  /// Number of in-flight downloads currently keeping the Android
  /// foreground service alive. The service is only stopped once the last
  /// download finishes, so a translation and a core asset downloading at
  /// the same time don't kill each other's keep-alive.
  int _fgsRefCount = 0;

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
    final saved = prefs.getString(
      'version_updated_${versionKeyFor(version)}',
    );
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
  Future<bool> _fgsStart({
    required String title,
    required String text,
  }) async {
    final active = await DownloadForegroundService.instance.showDownload(
      title: title,
      text: text,
    );
    if (active) _fgsRefCount++;
    return active;
  }

  /// Detach this download from the foreground service, stopping it (and
  /// removing its notification) once no download needs it any more.
  Future<void> _fgsStop() async {
    if (_fgsRefCount > 0) _fgsRefCount--;
    if (_fgsRefCount == 0) {
      await DownloadForegroundService.instance.hideDownload();
    }
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

    try {
      // Download the .zip file with progress tracking.
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        await _fgsStop();
        DownloadNotificationService.instance.showTranslationError(
          version.displayName,
          'HTTP ${response.statusCode}',
        );
        state = {
          ...state,
          versionKey: TranslationDownloadState(
            status: DownloadStatus.error,
            errorMessage: 'Download failed (HTTP ${response.statusCode})',
          ),
        };
        return;
      }

      final contentLength = response.contentLength ?? 0;
      final bytes = <int>[];
      int received = 0;

      await for (final chunk in response.stream) {
        if (cancelToken.isCancelled) {
          client.close();
          await _fgsStop();
          DownloadNotificationService.instance.dismissTranslation();
          state = {
            ...state,
            versionKey: const TranslationDownloadState(
              status: DownloadStatus.cancelled,
            ),
          };
          _cancelTokens.remove(versionKey);
          return;
        }

        bytes.addAll(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          final progress = received / contentLength;
          state = {
            ...state,
            versionKey: TranslationDownloadState(
              status: DownloadStatus.downloading,
              progress: progress,
            ),
          };
          final pct = (progress * 100).round();
          if (fgsActive) {
            DownloadForegroundService.instance.updateDownload(
              title: 'Downloading ${version.displayName}',
              text: '$pct%',
            );
          } else {
            DownloadNotificationService.instance.showTranslationProgress(
              versionKey: versionKey,
              displayName: version.displayName,
              progress: progress,
              isIndeterminate: false,
            );
          }
        }
      }

      client.close();
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
        versionKey: const TranslationDownloadState(status: DownloadStatus.extracting),
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

      final dbDir = await getDatabaseDirectory();
      final archive = ZipDecoder().decodeBytes(bytes);

      ArchiveFile? dbEntry;
      for (final entry in archive) {
        if (entry.isFile && entry.name.endsWith('.db')) {
          dbEntry = entry;
          break;
        }
      }

      if (dbEntry == null) {
        await _fgsStop();
        DownloadNotificationService.instance.showTranslationError(
          version.displayName,
          'No database file found in archive',
        );
        state = {
          ...state,
          versionKey: const TranslationDownloadState(
            status: DownloadStatus.error,
            errorMessage: 'No database file found in the archive',
          ),
        };
        return;
      }

      final dbContent = dbEntry.content as List<int>;

      // ── Integrity verification against the manifest ─────────────────
      // The server (upload_github_release.py) computes the manifest
      // `checksum` as the SHA-256 of the .db FILE inside the zip, so the
      // extracted database content must hash to the same value. `dbSize`
      // is the size of that same .db file — a cheap extra check. A
      // mismatch means the zip is corrupted, truncated, or from a
      // different version than the manifest, and must never be installed.
      final verifyError = verifyDownloadedDb(
        dbContent: dbContent,
        expectedChecksum: version.checksum,
        expectedDbSize: version.dbSize,
      );
      if (verifyError != null) {
        await _fgsStop();
        _failDownload(
          versionKey: versionKey,
          displayName: version.displayName,
          message: verifyError,
        );
        _cancelTokens.remove(versionKey);
        return;
      }

      // Write the .db file safely via a temp file to prevent corruption/truncation
      final destPath = p.join(dbDir.path, version.filename);
      final tempPath = '$destPath.tmp';
      final tempFile = File(tempPath);

      await tempFile.writeAsBytes(
        dbEntry.content as List<int>,
        flush: true,
      );

      final writtenSize = await tempFile.length();
      if (writtenSize == 0) {
        if (await tempFile.exists()) await tempFile.delete();
        throw Exception('Extracted database file is empty (0 bytes)');
      }

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
  }) async {
    final key = versionKey ?? filename.replaceAll('.db', '');

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

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        await _fgsStop();
        state = {
          ...state,
          key: TranslationDownloadState(
            status: DownloadStatus.error,
            errorMessage: 'Download failed (HTTP ${response.statusCode})',
          ),
        };
        return false;
      }

      final contentLength = response.contentLength ?? 0;
      final bytes = <int>[];
      int received = 0;

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          state = {
            ...state,
            key: TranslationDownloadState(
              status: DownloadStatus.downloading,
              progress: received / contentLength,
            ),
          };
          if (fgsActive) {
            DownloadForegroundService.instance.updateDownload(
              title: 'Downloading $displayName',
              text: '${(received / contentLength * 100).round()}%',
            );
          }
        }
      }
      client.close();

      state = {
        ...state,
        key: const TranslationDownloadState(status: DownloadStatus.extracting),
      };

      final dbDir = await getDatabaseDirectory();
      final archive = ZipDecoder().decodeBytes(bytes);

      ArchiveFile? dbEntry;
      for (final entry in archive) {
        if (entry.isFile && entry.name.endsWith('.db')) {
          dbEntry = entry;
          break;
        }
      }

      if (dbEntry == null) {
        await _fgsStop();
        state = {
          ...state,
          key: TranslationDownloadState(
            status: DownloadStatus.error,
            errorMessage: 'No database file found in the archive',
          ),
        };
        return false;
      }

      final destPath = p.join(dbDir.path, filename);
      final tempPath = '$destPath.tmp';
      final tempFile = File(tempPath);

      await tempFile.writeAsBytes(
        dbEntry.content as List<int>,
        flush: true,
      );

      final writtenSize = await tempFile.length();
      if (writtenSize == 0) {
        if (await tempFile.exists()) await tempFile.delete();
        throw Exception('Extracted database file is empty (0 bytes)');
      }

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

      // Invalidate translation-registry providers so the startup wizard
      // updates the continue button state after a core download finishes.
      ref.invalidate(translationRegistryProvider);
      ref.invalidate(localTranslationVersionsProvider);

      return true;
    } catch (e) {
      await _fgsStop();
      state = {
        ...state,
        key: TranslationDownloadState(
          status: DownloadStatus.error,
          errorMessage: e.toString(),
        ),
      };
      return false;
    }
  }

  /// Report a download failure through state + notification and clean up.
  void _failDownload({
    required String versionKey,
    required String displayName,
    required String message,
  }) {
    DownloadNotificationService.instance.showTranslationError(
      displayName,
      message,
    );
    state = {
      ...state,
      versionKey: TranslationDownloadState(
        status: DownloadStatus.error,
        errorMessage: message,
      ),
    };
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
bool _hexEquals(String a, String b) =>
    a.toLowerCase() == b.toLowerCase();

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

final translationDownloadProvider = StateNotifierProvider<
    TranslationDownloadNotifier, Map<String, TranslationDownloadState>>(
  (ref) => TranslationDownloadNotifier(),
);
