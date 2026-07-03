import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../../core/models/app_models.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/translation_registry_provider.dart';
import '../../../core/utils/database_initializer.dart';

/// Download state for a specific translation.
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

/// Maps language codes to their downloadable .zip URLs.
const Map<String, String> _downloadUrls = {
  'en':
      'https://github.com/dhammanana/epitaka_release/releases/download/v1.0.1/epitaka_en.db.zip',
  'si':
      'https://github.com/dhammanana/epitaka_release/releases/download/v1.0.1/epitaka_si.db.zip',
  'th':
      'https://github.com/dhammanana/epitaka_release/releases/download/v1.0.1/epitaka_th.db.zip',
};

/// Provider that manages downloading translation database files.
///
/// State is a map of language code → download state, so multiple downloads
/// can be tracked independently.
class TranslationDownloadNotifier
    extends StateNotifier<Map<String, TranslationDownloadState>> {
  final Map<String, CancelableCompleter> _cancelTokens = {};

  TranslationDownloadNotifier() : super({});

  /// Get the download state for a specific language code.
  TranslationDownloadState stateFor(String languageCode) {
    return state[languageCode] ?? const TranslationDownloadState();
  }

  /// Returns true if a download URL is available for this language.
  static bool hasDownloadUrl(String languageCode) =>
      _downloadUrls.containsKey(languageCode);

  /// Cancel an in-progress download for a language.
  void cancelDownload(String languageCode) {
    final token = _cancelTokens[languageCode];
    if (token != null) {
      token.cancel();
      _cancelTokens.remove(languageCode);
    }
    state = {
      ...state,
      languageCode: const TranslationDownloadState(
        status: DownloadStatus.cancelled,
      ),
    };
  }

  /// Download and install a translation database.
  /// Pass [ref] to invalidate the registry after success.
  Future<void> downloadTranslation(
    TranslationLanguage lang,
    WidgetRef ref,
  ) async {
    final code = lang.code;

    // Clean up any previous cancel token
    _cancelTokens.remove(code);

    // Bail early if no URL configured.
    final url = _downloadUrls[code];
    if (url == null) {
      state = {
        ...state,
        code: TranslationDownloadState(
          status: DownloadStatus.error,
          errorMessage: 'No download URL available for ${lang.englishName}',
        ),
      };
      return;
    }

    // Mark as downloading.
    state = {
      ...state,
      code: const TranslationDownloadState(
        status: DownloadStatus.downloading,
        progress: 0.0,
      ),
    };

    final cancelToken = CancelableCompleter();
    _cancelTokens[code] = cancelToken;

    try {
      // Download the .zip file with progress tracking.
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        state = {
          ...state,
          code: TranslationDownloadState(
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
        // Check for cancellation
        if (cancelToken.isCancelled) {
          client.close();
          state = {
            ...state,
            code: const TranslationDownloadState(
              status: DownloadStatus.cancelled,
            ),
          };
          _cancelTokens.remove(code);
          return;
        }

        bytes.addAll(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          state = {
            ...state,
            code: TranslationDownloadState(
              status: DownloadStatus.downloading,
              progress: received / contentLength,
            ),
          };
        }
      }

      client.close();
      _cancelTokens.remove(code);

      // Check cancellation before extraction
      if (cancelToken.isCancelled) {
        state = {
          ...state,
          code: const TranslationDownloadState(
            status: DownloadStatus.cancelled,
          ),
        };
        return;
      }

      // Extract the .db from the zip.
      state = {
        ...state,
        code: const TranslationDownloadState(status: DownloadStatus.extracting),
      };

      final dbDir = await getDatabaseDirectory();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Find the first .db file in the archive.
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
          code: const TranslationDownloadState(
            status: DownloadStatus.error,
            errorMessage: 'No database file found in the archive',
          ),
        };
        return;
      }

      // Write the .db file to the database directory.
      final destPath = p.join(dbDir.path, lang.filename);
      await File(destPath).writeAsBytes(
        dbEntry.content as List<int>,
        flush: true,
      );

      // Invalidate providers so the UI and reader pick up the new DB.
      ref.invalidate(translationRegistryProvider);
      ref.invalidate(translationDbProvider(lang));

      // Mark as completed.
      state = {
        ...state,
        code: const TranslationDownloadState(
          status: DownloadStatus.completed,
          progress: 1.0,
        ),
      };
    } catch (e) {
      if (cancelToken.isCancelled) {
        state = {
          ...state,
          code: const TranslationDownloadState(
            status: DownloadStatus.cancelled,
          ),
        };
      } else {
        state = {
          ...state,
          code: TranslationDownloadState(
            status: DownloadStatus.error,
            errorMessage: e.toString(),
          ),
        };
      }
      _cancelTokens.remove(code);
    }
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
