import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// Represents the download status for Gavesana assets.
enum GavesanaDownloadStatus {
  notDownloaded,
  downloading,
  extracting,
  ready,
  error,
}

/// Service to manage Gavesana AI assets.
/// The vector DB uses sqlite_vector extension from pub.dev (not manual .so).
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

  /// Ensures concurrent callers await the in-flight copy rather than
  /// triggering a duplicate or failing.
  Future<bool>? _copyInFlight;

  static const String _downloadUrl =
      'https://github.com/epitaka/gavesana-assets/releases/latest/download/epitaka_gavesana.zip';

  static const Map<String, int> _minFileSizes = {
    'model_quantized.onnx': 100_000_000,
    'tokenizer.json': 1_000_000,
    'epitaka_vec.db': 100_000_000,
  };

  Future<String> get _appDir async {
    final appDocDir = await getApplicationDocumentsDirectory();
    print('[DL] docs dir: ${appDocDir.path}');
    final gavesanaDir = Directory(p.join(appDocDir.path, 'gavesana'));
    if (!await gavesanaDir.exists()) {
      await gavesanaDir.create(recursive: true);
      print('[DL] created gavesana dir');
    }
    return gavesanaDir.path;
  }

  Future<bool> areAssetsReady() async {
    final dir = await _appDir;
    print('[DL] checking assets in: $dir');
    final ready = _checkCoreAssetsExist(dir);
    print('[DL] assets ready: $ready');
    return ready;
  }

  bool _checkCoreAssetsExist(String dir) {
    bool allOk = true;
    for (final entry in _minFileSizes.entries) {
      final filePath = p.join(dir, entry.key);
      final file = File(filePath);

      if (!file.existsSync()) {
        print('[DL]   MISSING: ${entry.key}');
        allOk = false;
        continue;
      }

      final size = file.lengthSync();
      if (size == 0) {
        print('[DL]   STALE (0 bytes): ${entry.key} — deleting');
        _deleteFile(file);
        allOk = false;
        continue;
      }
      if (size < entry.value) {
        print('[DL]   TOO SMALL ($size bytes): ${entry.key} — deleting');
        _deleteFile(file);
        allOk = false;
        continue;
      }

      if (entry.key == 'epitaka_vec.db') {
        if (!_validateVectorDbSchema(filePath)) {
          print('[DL]   INVALID SCHEMA: ${entry.key} (needs chunks table) — deleting');
          _deleteFile(file);
          allOk = false;
          continue;
        }
        print('[DL]   ✅ ${entry.key} ($size bytes, schema OK)');
      } else {
        print('[DL]   ✅ ${entry.key} ($size bytes)');
      }
    }
    return allOk;
  }

  void _deleteFile(File file) {
    try { file.deleteSync(); print('[DL]   deleted: ${file.path}'); } catch (_) {}
  }

  bool _validateVectorDbSchema(String dbPath) {
    try {
      final db = sqlite3.open(dbPath);
      try {
        return db
            .select("SELECT name FROM sqlite_master WHERE type='table' AND name='chunks'")
            .isNotEmpty;
      } finally {
        db.close();
      }
    } catch (_) {
      return false;
    }
  }

  Future<bool> downloadAssets({String? customUrl}) async {
    _status = GavesanaDownloadStatus.downloading;
    _progress = 0.0;
    _error = null;
    _statusCtrl.add(_status);

    try {
      final dir = await _appDir;
      final url = customUrl ?? _downloadUrl;

      final response = await http.Client().send(
        http.Request('GET', Uri.parse(url)),
      );
      if (response.statusCode != 200) {
        throw HttpException('Download failed with status ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      final bytes = <int>[];
      final completer = Completer<List<int>>();

      response.stream.listen(
        (chunk) { bytes.addAll(chunk); if (contentLength > 0) _progress = bytes.length / contentLength; },
        onDone: () => completer.complete(bytes),
        onError: (e) => completer.completeError(e),
      );

      final data = await completer.future;
      _status = GavesanaDownloadStatus.extracting;
      _progress = 0.0;
      _statusCtrl.add(_status);

      await _extractZip(data, dir);

      _status = GavesanaDownloadStatus.ready;
      _progress = 1.0;
      _statusCtrl.add(_status);
      return true;
    } catch (e) {
      _status = GavesanaDownloadStatus.error;
      _error = e.toString();
      _statusCtrl.add(_status);
      return false;
    }
  }

  Future<void> _extractZip(List<int> data, String destDir) async {
    final archive = ZipDecoder().decodeBytes(data);
    for (final file in archive.files) {
      if (file.isFile) {
        final outPath = p.join(destDir, file.name);
        await File(outPath).create(recursive: true);
        await File(outPath).writeAsBytes(file.content as List<int>);
      }
    }
  }

  /// Copy model + tokenizer + vector DB from Flutter asset bundle.
  /// If a copy is already in-flight, await it instead of duplicating.
  Future<bool> tryCopyFromAssets() async {
    // If a copy is already running, await its result
    if (_copyInFlight != null) {
      print('[DL] tryCopyFromAssets() — awaiting in-flight copy…');
      return await _copyInFlight!;
    }

    _copyInFlight = _doCopyFromAssets();
    try {
      return await _copyInFlight!;
    } finally {
      _copyInFlight = null;
    }
  }

  Future<bool> _doCopyFromAssets() async {
    print('[DL] tryCopyFromAssets() — reading asset bundle…');
    try {
      final dir = await _appDir;
      final assetFiles = [
        'assets/models/model_quantized.onnx',
        'assets/models/tokenizer.json',
        'assets/db/epitaka_vec.db',
      ];

      for (final assetPath in assetFiles) {
        try {
          final data = await rootBundle.load(assetPath);
          final fileName = p.basename(assetPath);
          final outFile = File(p.join(dir, fileName));
          await outFile.writeAsBytes(data.buffer.asUint8List());
          print('[DL]   ✅ Copied $assetPath (${data.lengthInBytes} bytes)');
        } catch (e) {
          print('[DL]   ❌ $assetPath not in bundle: $e');
        }
      }

      if (_checkCoreAssetsExist(dir)) {
        _status = GavesanaDownloadStatus.ready;
        _statusCtrl.add(_status);
        print('[DL] ✅ All assets ready after bundle copy');
        return true;
      }
    } catch (e) {
      print('[DL] ❌ tryCopyFromAssets error: $e');
    }

    print('[DL] ❌ Not all assets ready after bundle copy');
    return false;
  }

  /// Fallback: copy vector DB from a local filesystem path.
  Future<bool> tryCopyVectorDbFromLocal(String sourcePath) async {
    final dir = await _appDir;
    final destPath = p.join(dir, 'epitaka_vec.db');
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        print('[DL]   ℹ️  DB not found at: $sourcePath');
        return false;
      }
      final size = await sourceFile.length();
      if (size < (_minFileSizes['epitaka_vec.db'] ?? 100_000_000)) {
        print('[DL]   ❌ DB at $sourcePath too small ($size bytes)');
        return false;
      }
      await sourceFile.copy(destPath);
      print('[DL]   ✅ Copied DB from $sourcePath ($size bytes)');
      return true;
    } catch (e) {
      print('[DL]   ❌ Failed to copy DB from $sourcePath: $e');
      return false;
    }
  }

  Future<String?> getVectorDbPath() async {
    final dir = await _appDir;
    final path = p.join(dir, 'epitaka_vec.db');
    final file = File(path);
    if (!file.existsSync()) {
      print('[DL] getVectorDbPath() => $path — NOT FOUND');
      return null;
    }
    final size = file.lengthSync();
    print('[DL] getVectorDbPath() => $path ($size bytes)');

    if (size == 0) {
      print('[DL]   stale (0 bytes) — deleting');
      _deleteFile(file);
      return null;
    }

    if (!_validateVectorDbSchema(path)) {
      print('[DL]   invalid schema (no chunks table) — deleting');
      _deleteFile(file);
      return null;
    }

    return path;
  }

  Future<String?> getModelPath() async {
    final dir = await _appDir;
    final path = p.join(dir, 'model_quantized.onnx');
    if (await File(path).exists()) return path;
    return null;
  }

  Future<String?> getTokenizerPath() async {
    final dir = await _appDir;
    final path = p.join(dir, 'tokenizer.json');
    if (await File(path).exists()) return path;
    return null;
  }

  Future<void> deleteAssets() async {
    final dir = await _appDir;
    for (final f in ['model_quantized.onnx', 'tokenizer.json', 'epitaka_vec.db']) {
      try { await File(p.join(dir, f)).delete(); } catch (_) {}
    }
    _status = GavesanaDownloadStatus.notDownloaded;
    _progress = 0.0;
    _statusCtrl.add(_status);
  }

  void dispose() { _statusCtrl.close(); }
}
