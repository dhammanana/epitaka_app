import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supertonic_flutter/supertonic_flutter.dart';

import '../../../core/providers/settings_provider.dart';

/// Download state for Supertonic TTS models.
enum SupertonicDownloadStatus { idle, downloading, completed, error }

class SupertonicDownloadState {
  final SupertonicDownloadStatus status;
  final double progress;
  final String? currentFile;
  final int filesDone;
  final int filesTotal;
  final String? errorMessage;

  const SupertonicDownloadState({
    this.status = SupertonicDownloadStatus.idle,
    this.progress = 0.0,
    this.currentFile,
    this.filesDone = 0,
    this.filesTotal = 0,
    this.errorMessage,
  });

  SupertonicDownloadState copyWith({
    SupertonicDownloadStatus? status,
    double? progress,
    String? currentFile,
    int? filesDone,
    int? filesTotal,
    String? errorMessage,
  }) {
    return SupertonicDownloadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      currentFile: currentFile ?? this.currentFile,
      filesDone: filesDone ?? this.filesDone,
      filesTotal: filesTotal ?? this.filesTotal,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Provider that manages downloading Supertonic TTS models (~400 MB).
class SupertonicDownloadNotifier
    extends StateNotifier<SupertonicDownloadState> {
  CancelToken? _cancelToken;

  SupertonicDownloadNotifier() : super(const SupertonicDownloadState());

  /// Check if models are already downloaded.
  Future<bool> areModelsReady() async {
    return SupertonicTTS.modelsReady();
  }

  /// Start downloading Supertonic models.
  /// Call [ref]'s [settings.notifier].setTtsSupertonicDownloaded after success.
  Future<void> downloadModels(WidgetRef ref) async {
    if (state.status == SupertonicDownloadStatus.downloading) return;

    _cancelToken = CancelToken();
    state = const SupertonicDownloadState(status: SupertonicDownloadStatus.downloading);

    try {
      await SupertonicTTS.preDownloadModels(
        onProgress: (done, total, file, progress) {
          state = SupertonicDownloadState(
            status: SupertonicDownloadStatus.downloading,
            progress: progress,
            currentFile: file,
            filesDone: done,
            filesTotal: total,
          );
        },
        cancelToken: _cancelToken,
      );

      // Update settings to mark models as downloaded
      ref.read(settingsProvider.notifier).setTtsSupertonicDownloaded(true);

      state = const SupertonicDownloadState(
        status: SupertonicDownloadStatus.completed,
        progress: 1.0,
      );
    } catch (e) {
      if (_cancelToken?.isCancelled ?? false) {
        state = const SupertonicDownloadState(status: SupertonicDownloadStatus.idle);
      } else {
        state = SupertonicDownloadState(
          status: SupertonicDownloadStatus.error,
          errorMessage: e.toString(),
        );
      }
    }
  }

  /// Cancel an in-progress download.
  void cancelDownload() {
    _cancelToken?.cancel();
    _cancelToken = null;
    state = const SupertonicDownloadState(status: SupertonicDownloadStatus.idle);
  }
}

final supertonicDownloadProvider = StateNotifierProvider<
    SupertonicDownloadNotifier, SupertonicDownloadState>(
  (ref) => SupertonicDownloadNotifier(),
);
