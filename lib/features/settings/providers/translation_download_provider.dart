import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/app_models.dart';
import '../../../core/models/translation_version.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/translation_manifest_provider.dart';
import '../../../core/providers/translation_registry_provider.dart';
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

  TranslationDownloadNotifier() : super({});

  /// Get the download state for a specific version key.
  TranslationDownloadState stateFor(String versionKey) {
    return state[versionKey] ?? const TranslationDownloadState();
  }

  /// Get the download URL for a translation version.
  /// Returns null if no URL is available from the manifest.
  static String? getDownloadUrl(TranslationVersion version) {
    return version.hasDownloadUrl ? version.downloadUrl : null;
  }

  /// Check if an update is available for a locally installed version.
  /// Returns true when the manifest's updatedAt is different from what was
  /// saved when the version was last downloaded.
  static Future<bool> isUpdateAvailable(TranslationVersion version) async {
    if (!version.isAvailable || !version.hasDownloadUrl) return false;
    if (version.updatedAt == null || version.updatedAt!.isEmpty) return false;

    final versionKey = version.suffix != null && version.suffix!.isNotEmpty
        ? '${version.languageCode}_${version.suffix}'
        : version.languageCode;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('version_updated_$versionKey');
    // If nothing saved locally, treat as not available for update
    if (saved == null || saved.isEmpty) return false;
    // Compare dates — different means a newer version is available
    return saved != version.updatedAt;
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

    final cancelToken = CancelableCompleter();
    _cancelTokens[versionKey] = cancelToken;

    try {
      // Download the .zip file with progress tracking.
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
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
          state = {
            ...state,
            versionKey: TranslationDownloadState(
              status: DownloadStatus.downloading,
              progress: received / contentLength,
            ),
          };
        }
      }

      client.close();
      _cancelTokens.remove(versionKey);

      if (cancelToken.isCancelled) {
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
        state = {
          ...state,
          versionKey: const TranslationDownloadState(
            status: DownloadStatus.error,
            errorMessage: 'No database file found in the archive',
          ),
        };
        return;
      }

      // Write the .db file
      final destPath = p.join(dbDir.path, version.filename);
      await File(destPath).writeAsBytes(
        dbEntry.content as List<int>,
        flush: true,
      );

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
        ref.invalidate(translationDbProvider(
          TranslationLanguage.fromCode(version.languageCode),
        ));
      }

      state = {
        ...state,
        versionKey: const TranslationDownloadState(
          status: DownloadStatus.completed,
          progress: 1.0,
        ),
      };
    } catch (e) {
      if (cancelToken.isCancelled) {
        state = {
          ...state,
          versionKey: const TranslationDownloadState(
            status: DownloadStatus.cancelled,
          ),
        };
      } else {
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

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
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
      await File(destPath).writeAsBytes(
        dbEntry.content as List<int>,
        flush: true,
      );

      state = {
        ...state,
        key: const TranslationDownloadState(
          status: DownloadStatus.completed,
          progress: 1.0,
        ),
      };

      // Invalidate FTS required-asset providers so the startup wizard
      // updates the continue button state after a core download finishes.
      ref.invalidate(translationRegistryProvider);
      ref.invalidate(localTranslationVersionsProvider);

      return true;
    } catch (e) {
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
