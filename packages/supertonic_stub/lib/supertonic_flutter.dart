// Local stub for the real `supertonic_flutter` package.
//
// The real package depends on `flutter_onnxruntime`, whose bundled
// `onnxruntime-c` CocoaPod ships only an arm64 (Apple Silicon) static
// library. On Intel (x86_64) macOS the linker fails with
// `Undefined symbols for architecture x86_64`, so this stub replaces the
// package in the dependency graph and the ONNX Runtime drops out of the
// build entirely.
//
// Every API reports SuperTonic TTS as unavailable with a clear error.
// The app's other TTS engine (system TTS via `flutter_tts`) is unaffected.
//
// To restore the real SuperTonic TTS, delete `pubspec_overrides.yaml` (or
// remove the `supertonic_flutter` override from it) and run
// `flutter pub get`.

import 'dart:async';

import 'package:audioplayers/audioplayers.dart' show PlayerState;
import 'package:dio/dio.dart';

const String _unavailable =
    'SuperTonic TTS is not available in this build: it requires the ONNX '
    'Runtime (flutter_onnxruntime), which cannot be linked on this '
    'platform/architecture. Please use the system TTS engine instead.';

/// Synthesis quality configuration. Kept for API compatibility; unused by
/// the stub.
class TTSConfig {
  final int denoisingSteps;
  final double speechSpeed;

  const TTSConfig({this.denoisingSteps = 4, this.speechSpeed = 1.0});
}

/// Stub of the SuperTonic neural TTS engine.
class SupertonicTTS {
  SupertonicTTS();

  /// Models are never considered ready in this build.
  static Future<bool> modelsReady() async => false;

  /// Downloading models is not supported in this build.
  static Future<void> preDownloadModels({
    required void Function(int done, int total, String file, double progress)
        onProgress,
    CancelToken? cancelToken,
  }) async {
    throw UnsupportedError(_unavailable);
  }

  /// Initializing the engine is not supported in this build.
  Future<void> initialize() async {
    throw UnsupportedError(_unavailable);
  }

  /// Synthesis is not supported in this build.
  Future<dynamic> synthesize(
    String text, {
    String? language,
    String? voiceStyle,
    TTSConfig? config,
  }) async {
    throw UnsupportedError(_unavailable);
  }

  /// No-op; there is nothing to dispose.
  void dispose() {}
}

/// Stub of the SuperTonic audio player. Reuses the audioplayers
/// [PlayerState] type, exactly like the real package, so the app's imports
/// stay unambiguous.
class TTSAudioPlayer {
  final StreamController<PlayerState> _controller =
      StreamController<PlayerState>.broadcast();

  /// An empty stream — nothing ever plays in this build.
  Stream<PlayerState> get playerStateStream => _controller.stream;

  Future<void> play(dynamic result) async {
    throw UnsupportedError(_unavailable);
  }

  Future<void> pause() async {}

  Future<void> resume() async {}

  Future<void> stop() async {}
}
