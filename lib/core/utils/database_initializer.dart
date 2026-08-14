import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart' show MethodChannel, rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Returns the directory where translation databases are stored.
///
/// Resolution order:
/// 1. `EPITAKA_DB_PATH` environment variable (explicit override — the
///    directory is created when missing)
/// 2. Application documents directory on mobile (Android/iOS)
/// 3. Application support directory on desktop (Windows/macOS/Linux)
///
/// IMPORTANT (Windows bug fix): this previously looked for a `data/` folder
/// relative to the current working directory on desktop. On a packaged
/// Windows app the cwd is unpredictable — when the app sits in
/// `C:\Program Files\ePitaka\` (or any Flutter build folder) the `data/`
/// check matches the bundled `data/flutter_assets/` folder, so databases
/// were "found" in a *write-protected* Program Files location. Downloads
/// then failed with Access Denied and the setup wizard showed the download
/// button again forever. The database directory is now deterministic:
/// a per-user, always-writable folder that is never inside Program Files.
Future<Directory> getDatabaseDirectory() async {
  final envDbPath = Platform.environment['EPITAKA_DB_PATH'];
  if (envDbPath != null && envDbPath.isNotEmpty) {
    final dir = Directory(envDbPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  if (Platform.isAndroid || Platform.isIOS) {
    return getApplicationDocumentsDirectory();
  }

  return getApplicationSupportDirectory();
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
          // Skip 0-byte stray files — an empty db bundled into the app must
          // never shadow the real database (which arrives later from the
          // install-time asset pack on Android).
          if (onDisk.lengthSync() == 0) continue;
          await onDisk.copy(destPath);
          continue;
        }
      }
      final data = await rootBundle.load(assetPath);
      // Skip 0-byte assets for the same reason as above.
      if (data.lengthInBytes == 0) continue;
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

/// One-time migration of databases and user data from the locations used by
/// older builds into the current canonical database directory (desktop only).
///
/// Older desktop builds used two other locations:
///  - the Documents folder (the previous fallback), and
///  - an exe-adjacent `data/` folder (the previous cwd heuristic — for a
///    packaged app this is e.g. `C:\Program Files\ePitaka\data`, or a
///    Flutter build output folder).
///
/// If a user already downloaded databases (sometimes hundreds of MB) or has
/// bookmarks/history in `app_data.db` from a previous version, this copies
/// everything into the new canonical directory once so nothing needs to be
/// re-downloaded and no data is lost. Only files that don't already exist in
/// the target are copied, and each legacy location is best-effort (failures
/// are logged, never fatal).
Future<void> migrateLegacyDatabases() async {
  if (Platform.isAndroid || Platform.isIOS) return;

  final target = await getDatabaseDirectory();
  if (!await target.exists()) {
    await target.create(recursive: true);
  }

  final legacyDirs = <String>[
    // Documents was the old fallback when no cwd-relative data/ existed.
    (await getApplicationDocumentsDirectory()).path,
    // The exe-adjacent data/ folder the old cwd heuristic could point at.
    p.join(File(Platform.resolvedExecutable).parent.path, 'data'),
  ];

  final targetPath = p.normalize(target.path);

  for (final legacyPath in legacyDirs) {
    final dir = Directory(legacyPath);
    if (!await dir.exists()) continue;
    if (p.normalize(legacyPath) == targetPath) continue;

    try {
      // Copy each *.db plus its SQLite journal siblings (-wal/-shm/-journal).
      for (final entry in dir.listSync()) {
        if (entry is! File) continue;
        final name = p.basename(entry.path);
        if (!name.endsWith('.db')) continue;
        for (final suffix in ['', '-wal', '-shm', '-journal']) {
          final src = File('${entry.path}$suffix');
          if (!await src.exists()) continue;
          final dest = File(p.join(target.path, '$name$suffix'));
          if (await dest.exists()) continue;
          await src.copy(dest.path);
          developer.log('[DB_MIGRATE] Copied $name$suffix → ${dest.path}',
              name: 'epitaka.database');
        }
      }

      // Also migrate the Gavesana AI-asset folder (ONNX model, tokenizer,
      // vector DB) so a multi-hundred-MB download is not repeated.
      final gavesanaSrc = Directory(p.join(legacyPath, 'gavesana'));
      if (await gavesanaSrc.exists()) {
        final gavesanaDest = Directory(p.join(target.path, 'gavesana'));
        if (!await gavesanaDest.exists()) {
          await gavesanaDest.create(recursive: true);
        }
        for (final f in gavesanaSrc.listSync()) {
          if (f is! File) continue;
          final dest = File(p.join(gavesanaDest.path, p.basename(f.path)));
          if (await dest.exists()) continue;
          await f.copy(dest.path);
          developer.log('[DB_MIGRATE] Copied gavesana/${p.basename(f.path)} '
              '→ ${dest.path}', name: 'epitaka.database');
        }
      }
    } catch (e) {
      developer.log('[DB_MIGRATE] Failed to migrate from $legacyPath: $e',
          name: 'epitaka.database');
    }
  }
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

  // On Android getDatabaseDirectory() is the application documents
  // directory — identical to the old direct call, but using the shared
  // accessor keeps every data path flowing through one place.
  final appDir = await getDatabaseDirectory();
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
