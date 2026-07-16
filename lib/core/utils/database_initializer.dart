import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Returns the directory where translation databases are stored.
///
/// Resolution order:
/// 1. `EPITAKA_DB_PATH` environment variable (if set and exists)
/// 2. `data/` directory relative to cwd (desktop only)
/// 3. Application documents directory (mobile)
Future<Directory> getDatabaseDirectory() async {
  final envDbPath = Platform.environment['EPITAKA_DB_PATH'];
  if (envDbPath != null && envDbPath.isNotEmpty) {
    final dir = Directory(envDbPath);
    if (await dir.exists()) {
      return dir;
    }
  }

  if (!Platform.isAndroid && !Platform.isIOS) {
    final cwd = Directory.current;
    final dataDir = Directory(p.join(cwd.path, 'data'));
    if (await dataDir.exists()) {
      return dataDir;
    }
  }

  final appDir = await getApplicationDocumentsDirectory();
  return appDir;
}

/// Copies bundled database files from assets to the app's writable documents
/// directory on first launch.
///
/// On Android/iOS, Flutter assets are bundled inside the APK/IPA and are not
/// directly accessible as file paths. This function extracts them so Drift
/// (which needs a real file path) can open them.
///
/// On desktop (macOS/Windows/Linux), this is a no-op because the DB files
/// are already accessible via the relative `data/` directory.
Future<void> ensureBundledDatabases() async {
  // On desktop, DB files are at ../data/ relative to the working directory.
  // No need to copy from assets.
  if (!Platform.isAndroid && !Platform.isIOS) return;

  final appDir = await getApplicationDocumentsDirectory();
  final dbDir = Directory(appDir.path);
  if (!await dbDir.exists()) {
    await dbDir.create(recursive: true);
  }

  // List of bundled databases to copy from assets.
  const bundledDbs = [
    'assets/db/epitaka.db',
    'assets/db/epitaka_en.db',
    'assets/db/dpd-dictionary.db',
    'assets/db/epitaka_my_nissaya.db',
  ];

  for (final assetPath in bundledDbs) {
    final filename = p.basename(assetPath);
    final destPath = p.join(appDir.path, filename);

    // Only copy if the destination doesn't already exist.
    if (await File(destPath).exists()) continue;

    try {
      final data = await rootBundle.load(assetPath);
      final file = File(destPath);
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    } catch (e) {
      // Asset might not exist in this build variant — skip silently.
      continue;
    }
  }
}
