import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../../settings/services/download_notification_service.dart';

/// Represents the download status for Gavesana assets.
enum GavesanaDownloadStatus {
  notDownloaded,
  downloading,
  extracting,
  ready,
  error,
}

/// Service to manage Gavesana AI assets (ONNX model, tokenizer, vector DB).
///
/// Download flow:
/// 1. Check if all three asset files exist in the gavesana/ directory
/// 2. If missing, download embeddings.zip from the release server and extract
///
/// No longer supports bundled assets or /sdcard/ fallback paths — those
/// were removed to reduce complexity. Everything comes from one zip.
class GavesanaDownloadService {
  GavesanaDownloadStatus _status = GavesanaDownloadStatus.notDownloaded;
  double _progress = 0.0;
  String? _error;

  GavesanaDownloadStatus get status => _status;
  double get progress => _progress;
  String? get error => _error;

  final StreamController<GavesanaDownloadStatus> _statusCtrl =
      StreamController<GavesanaDownloadStatus>.broadcast();
  Stream<GavesanaDownloadStatus> get statusStream => _statusCtrl.stream;

  static const Map<String, int> _minFileSizes = {
    'model_quantized.onnx': 100_000_000,
    'tokenizer.json': 1_000_000,
    'epitaka_vec.db': 100_000_000,
  };

  Future<String> get _appDir async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final gavesanaDir = Directory(p.join(appDocDir.path, 'gavesana'));
    if (!await gavesanaDir.exists()) {
      await gavesanaDir.create(recursive: true);
    }
    return gavesanaDir.path;
  }

  /// Check whether all three Gavesana asset files are present and valid.
  Future<bool> areAssetsReady() async {
    final dir = await _appDir;
    return _checkCoreAssetsExist(dir);
  }

  bool _checkCoreAssetsExist(String dir) {
    bool allOk = true;
    for (final entry in _minFileSizes.entries) {
      final filePath = p.join(dir, entry.key);
      final file = File(filePath);

      if (!file.existsSync()) {
        allOk = false;
        continue;
      }

      final size = file.lengthSync();
      if (size == 0) {
        _deleteFile(file);
        allOk = false;
        continue;
      }
      if (size < entry.value) {
        _deleteFile(file);
        allOk = false;
        continue;
      }

      if (entry.key == 'epitaka_vec.db') {
        if (!_validateVectorDbSchema(filePath)) {
          _deleteFile(file);
          allOk = false;
          continue;
        }
      }
    }
    return allOk;
  }

  void _deleteFile(File file) {
    try {
      file.deleteSync();
    } catch (_) {}
  }

  bool _validateVectorDbSchema(String dbPath) {
    try {
      final db = sqlite3.open(dbPath);
      try {
        return db
            .select(
                "SELECT name FROM sqlite_master WHERE type='table' AND name='chunks'")
            .isNotEmpty;
      } finally {
        db.close();
      }
    } catch (_) {
      return false;
    }
  }

  /// Download the Gavesana AI asset archive and extract it into the
  /// gavesana/ directory.
  ///
  /// [url] is the download URL for the assets zip, normally obtained from
  /// the translation manifest (TranslationManifest.embeddingsUrl).
  Future<bool> downloadAssets({required String url}) async {
    _status = GavesanaDownloadStatus.downloading;
    _progress = 0.0;
    _error = null;
    _statusCtrl.add(_status);

    try {
      final dir = await _appDir;

      final response = await http.Client().send(
        http.Request('GET', Uri.parse(url)),
      );
      if (response.statusCode != 200) {
        throw HttpException(
            'Download failed with status ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      final bytes = <int>[];
      final completer = Completer<List<int>>();

      response.stream.listen(
        (chunk) {
          bytes.addAll(chunk);
          if (contentLength > 0) {
            _progress = bytes.length / contentLength;
            DownloadNotificationService.instance.showGavesanaProgress(
              progress: _progress,
              isIndeterminate: false,
              phase: 'downloading',
            );
          }
        },
        onDone: () => completer.complete(bytes),
        onError: (e) => completer.completeError(e),
      );

      final data = await completer.future;
      _status = GavesanaDownloadStatus.extracting;
      _progress = 0.0;
      _statusCtrl.add(_status);
      DownloadNotificationService.instance.showGavesanaProgress(
        progress: 1.0,
        isIndeterminate: true,
        phase: 'extracting',
      );

      await _extractZip(data, dir);

      _status = GavesanaDownloadStatus.ready;
      _progress = 1.0;
      _statusCtrl.add(_status);
      DownloadNotificationService.instance.showGavesanaComplete();
      return true;
    } catch (e) {
      _status = GavesanaDownloadStatus.error;
      _error = e.toString();
      _statusCtrl.add(_status);
      DownloadNotificationService.instance.showGavesanaError(e.toString());
      return false;
    }
  }

  Future<void> _extractZip(List<int> data, String destDir) async {
    final archive = ZipDecoder().decodeBytes(data);
    for (final file in archive.files) {
      if (file.isFile) {
        // Skip __MACOSX and other metadata entries
        if (file.name.startsWith('__MACOSX') || file.name.startsWith('.')) {
          continue;
        }
        final outPath = p.join(destDir, p.basename(file.name));
        await File(outPath).create(recursive: true);
        await File(outPath).writeAsBytes(file.content as List<int>);
      }
    }
  }

  /// Get the path to the vector database file, or null if not available.
  Future<String?> getVectorDbPath() async {
    final dir = await _appDir;
    final path = p.join(dir, 'epitaka_vec.db');
    final file = File(path);
    if (!file.existsSync()) return null;
    final size = file.lengthSync();
    if (size == 0) {
      _deleteFile(file);
      return null;
    }
    if (!_validateVectorDbSchema(path)) {
      _deleteFile(file);
      return null;
    }
    return path;
  }

  /// Get the path to the ONNX model file, or null if not available.
  Future<String?> getModelPath() async {
    final dir = await _appDir;
    final path = p.join(dir, 'model_quantized.onnx');
    if (await File(path).exists()) return path;
    return null;
  }

  /// Get the path to the tokenizer JSON file, or null if not available.
  Future<String?> getTokenizerPath() async {
    final dir = await _appDir;
    final path = p.join(dir, 'tokenizer.json');
    if (await File(path).exists()) return path;
    return null;
  }

  /// Delete all downloaded Gavesana assets.
  Future<void> deleteAssets() async {
    final dir = await _appDir;
    for (final f in [
      'model_quantized.onnx',
      'tokenizer.json',
      'epitaka_vec.db'
    ]) {
      try {
        await File(p.join(dir, f)).delete();
      } catch (_) {}
    }
    _status = GavesanaDownloadStatus.notDownloaded;
    _progress = 0.0;
    _statusCtrl.add(_status);
  }

  void dispose() {
    _statusCtrl.close();
  }
}
