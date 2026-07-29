import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/download_service.dart';

/// Provider for the Gavesana download service (singleton).
final gavesanaDownloadServiceProvider = Provider<GavesanaDownloadService>((ref) {
  final service = GavesanaDownloadService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider that exposes whether Gavesana assets are ready for use.
/// Simply checks if all three asset files exist in the gavesana/ directory.
/// No longer tries to copy from the asset bundle — that bloats the APK.
final gavesanaAssetsReadyProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(gavesanaDownloadServiceProvider);
  return await service.areAssetsReady();
});

/// Provider for download status stream.
final gavesanaDownloadStatusProvider = StreamProvider<GavesanaDownloadStatus>(
  (ref) => ref.watch(gavesanaDownloadServiceProvider).statusStream,
);

/// Provider for the current download progress (0.0 - 1.0).
final gavesanaDownloadProgressProvider = Provider<double>((ref) {
  return ref.watch(gavesanaDownloadServiceProvider).progress;
});
