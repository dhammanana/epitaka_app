import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart' show MethodChannel, rootBundle;
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

/// Copies bundled database files from assets to the app's writable database
/// directory on first launch.
///
/// CI bundles the core DBs (epitaka.db, dpd-dictionary.db) into `assets/db/`
/// for every platform, so the built app contains them inside `flutter_assets`.
/// Flutter assets are not directly accessible as file paths (mobile) or live
/// inside the app bundle (desktop), so this function extracts them into
/// [getDatabaseDirectory] where Drift (which needs a real writable file path)
/// and the providers can open them — making the bundled DBs usable offline
/// without re-downloading.
Future<void> ensureBundledDatabases() async {
  final appDir = await getDatabaseDirectory();
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
      // On desktop the assets are real files inside the app bundle — copy
      // them directly (streamed) instead of loading hundreds of MB into
      // memory through rootBundle.
      if (!Platform.isAndroid && !Platform.isIOS) {
        final onDisk = _assetOnDisk(assetPath);
        if (onDisk != null) {
          await onDisk.copy(destPath);
          continue;
        }
      }
      final data = await rootBundle.load(assetPath);
      final file = File(destPath);
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    } catch (e) {
      // Asset might not exist in this build variant — skip silently.
      continue;
    }
  }
}

/// Resolves a Flutter asset to its on-disk path on desktop platforms, or
/// null when the asset isn't stored as a plain file (e.g. debug runs where
/// assets are served from the workspace).
File? _assetOnDisk(String assetPath) {
  try {
    final exe = File(Platform.resolvedExecutable);
    final exeDir = exe.parent;
    final base = exeDir.path;

    List<String> roots;
    if (Platform.isMacOS) {
      // Layout: <App>.app/Contents/MacOS/epitaka
      // Assets live in <App>.app/Contents/Frameworks/App.framework/
      // Resources/flutter_assets (some layouts: Contents/Resources/…).
      roots = [
        p.join(base, '..', 'Frameworks', 'App.framework', 'Resources',
            'flutter_assets'),
        p.join(base, '..', 'Resources', 'flutter_assets'),
      ];
    } else {
      // Windows/Linux: <exe_dir>/data/flutter_assets
      roots = [p.join(base, 'data', 'flutter_assets')];
    }

    for (final root in roots) {
      final candidate = File(p.join(root, assetPath));
      if (candidate.existsSync()) return candidate;
    }
  } catch (_) {}
  return null;
}

/// Copies the core databases (epitaka.db, dpd-dictionary.db) out of the
/// Android install-time Play Asset Delivery pack on first launch.
///
/// The pack is delivered inside the AAB, so this works fully offline. The
/// copy itself runs natively (MainActivity.kt — MethodChannel
/// `epitaka/asset_pack`) because the files are too large to stream through
/// the Dart isolate.
///
/// Falls back silently when the pack isn't present (debug builds,
/// side-loaded APKs, or platforms other than Android) — the regular
/// bundled-assets / runtime download paths then take over.
Future<void> ensureAssetPackDatabases() async {
  if (!Platform.isAndroid) return;

  final appDir = await getApplicationDocumentsDirectory();
  final dbDir = Directory(appDir.path);
  if (!await dbDir.exists()) {
    await dbDir.create(recursive: true);
  }

  try {
    const channel = MethodChannel('epitaka/asset_pack');
    final copied = await channel.invokeMethod<List<dynamic>>(
      'copyCoreDatabases',
      {'destDir': appDir.path},
    );
    if (copied != null && copied.isNotEmpty) {
      developer.log(
        '[ASSET_PACK] Copied from install-time asset pack: $copied',
        name: 'epitaka.database',
      );
    }
  } catch (e) {
    // Asset pack not available (debug/side-load, or channel missing) —
    // fall through to the bundled-assets / download paths.
    developer.log(
      '[ASSET_PACK] Asset pack unavailable (falling back): $e',
      name: 'epitaka.database',
    );
  }
}
