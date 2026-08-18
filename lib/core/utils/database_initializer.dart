import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart'
    show AssetManifest, MethodChannel, rootBundle;
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
///
/// The last directory returned by [getDatabaseDirectory]. Hot restart keeps
/// the Dart isolate alive, so this survives a hot restart — it's the most
/// reliable way to keep using the exact same database directory after
/// path_provider's FFI breaks (dart-lang/native#3281).
Directory? _lastResolvedDbDir;

Future<Directory> getDatabaseDirectory() async {
  final envDbPath = Platform.environment['EPITAKA_DB_PATH'];
  if (envDbPath != null && envDbPath.isNotEmpty) {
    final dir = Directory(envDbPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return _lastResolvedDbDir = dir;
  }

  if (Platform.isAndroid || Platform.isIOS) {
    final dir = await getApplicationDocumentsDirectory();
    return _lastResolvedDbDir = dir;
  }

  // Desktop. path_provider's macOS implementation resolves the directory via
  // FFI (package:objective_c), which can break after a Flutter hot restart
  // (upstream dart-lang/native#3281 — `DOBJC_initializeApi` no longer
  // resolves). A failure here used to crash startup; now the last
  // successfully-resolved directory is restored instead, so the app keeps
  // working (same databases, bookmarks, downloads) until the next full
  // restart.
  try {
    final dir = await getApplicationSupportDirectory();
    _lastResolvedDbDir = dir;
    await _rememberDatabasePath(dir.path);
    return dir;
  } catch (e) {
    developer.log(
      '[DB_DIR] getApplicationSupportDirectory failed ($e) — using '
      'last-known database directory',
      name: 'epitaka.database',
    );
    final dir = _fallbackAppSupportDirectory();
    _lastResolvedDbDir = dir;
    return dir;
  }
}

/// Marker files holding the last path_provider-resolved database directory.
/// Lives at pure-Dart, per-user locations that need no plugin/FFI to find,
/// so the fallback in [getDatabaseDirectory] can restore the EXACT directory
/// the app used on its previous (working) run — a guessed path would look
/// like a fresh install and ask to re-download/index everything.
///
/// On macOS the app is sandboxed: writes outside the app's container
/// (`~/Library/Containers/<bundleId>/…`) silently fail, so the marker is
/// written to BOTH the container (guaranteed writable) and the shared
/// `~/Library/Application Support` location.
List<File> _databasePathMarkers() {
  if (Platform.isMacOS) {
    final home = Platform.environment['HOME'] ?? '.';
    final markers = <File>[
      File('$home/Library/Application Support/epitaka_db_path'),
    ];
    final container = _macContainerAppSupportDir();
    if (container != null) {
      markers.add(
        File('${container.path}/epitaka_db_path'),
      );
    }
    return markers;
  }
  if (Platform.isWindows) {
    final appData = Platform.environment['APPDATA'] ?? '.';
    return [File('$appData/epitaka_db_path')];
  }
  final dataHome = Platform.environment['XDG_DATA_HOME'] ??
      '${Platform.environment['HOME'] ?? '.'}/.local/share';
  return [File('$dataHome/epitaka_db_path')];
}

/// Persist [path] as the last-known database directory. Best-effort: if the
/// write fails, the fallback simply uses the last in-session directory or the
/// per-platform guess instead.
Future<void> _rememberDatabasePath(String path) async {
  for (final marker in _databasePathMarkers()) {
    try {
      if (marker.existsSync() && marker.readAsStringSync().trim() == path) {
        continue;
      }
      await marker.parent.create(recursive: true);
      await marker.writeAsString(path, flush: true);
    } catch (_) {}
  }
}

/// Pure-Dart directory used when path_provider's FFI is unavailable (e.g.
/// after a macOS hot restart). Resolution order:
/// 1. the directory resolved earlier in this session (hot restart keeps the
///    isolate alive, so this is the exact directory the app was using),
/// 2. the last-known directory from the marker files,
/// 3. a best-effort per-platform guess (macOS: the sandbox container path,
///    which is where path_provider actually points on this app).
Directory _fallbackAppSupportDirectory() {
  final inSession = _lastResolvedDbDir;
  if (inSession != null && inSession.path.isNotEmpty) {
    return inSession;
  }

  for (final marker in _databasePathMarkers()) {
    try {
      if (marker.existsSync()) {
        final saved = marker.readAsStringSync().trim();
        if (saved.isNotEmpty) return Directory(saved);
      }
    } catch (_) {}
  }

  if (Platform.isMacOS) {
    final home = Platform.environment['HOME'] ?? '.';
    // A sandboxed macOS app gets its per-user directories redirected into
    // `~/Library/Containers/<bundleId>/Data/…` — path_provider resolves the
    // Application Support directory to
    // `~/Library/Containers/<bundleId>/Data/Library/Application Support/`
    // `<bundleId>` for sandboxed apps (and `~/Library/Application Support/`
    // `<bundleId>` for non-sandboxed ones). Prefer the container form — it's
    // where a sandboxed app's data actually lives.
    final container = _macContainerAppSupportDir();
    if (container != null) {
      // A sandboxed app's data lives in the container, so path_provider
      // always points here — prefer it over the shared location even when
      // the directory is still empty (fresh install).
      return container;
    }
    return Directory(
      '$home/Library/Application Support/${_macBundleIdentifier()}'
          .replaceAll(RegExp(r'/+'), '/'),
    );
  }
  if (Platform.isWindows) {
    final appData = Platform.environment['APPDATA'] ?? '.';
    return Directory('$appData/epitaka');
  }
  final dataHome = Platform.environment['XDG_DATA_HOME'] ??
      '${Platform.environment['HOME'] ?? '.'}/.local/share';
  return Directory('$dataHome/epitaka');
}

/// The sandbox container's Application Support directory for this app on
/// macOS, or null when the container can't be located. Mirrors what
/// path_provider's `getApplicationSupportDirectory()` returns for a sandboxed
/// app (NSSearchPathForDirectoriesInDomains is redirected into the container,
/// then the bundle identifier is appended).
Directory? _macContainerAppSupportDir() {
  try {
    final home = Platform.environment['HOME'] ?? '.';
    final bundleId = _macBundleIdentifier();
    if (bundleId.isEmpty || bundleId.startsWith(r'$(')) return null;
    final containerBase =
        Directory('$home/Library/Containers/$bundleId/Data');
    if (!containerBase.existsSync()) return null;
    final appSupport = Directory(
      p.join(containerBase.path, 'Library', 'Application Support', bundleId),
    );
    return appSupport.existsSync() ? appSupport : null;
  } catch (_) {
    return null;
  }
}

/// The app's bundle identifier, read from the built app's Info.plist.
/// Returns the project's known bundle id ('com.dn.epitaka') when it can't be
/// determined — matching what path_provider sees is what matters, and this is
/// the id the app is actually built with (macos/Runner.xcodeproj).
String _macBundleIdentifier() {
  try {
    final exe = File(Platform.resolvedExecutable);
    final infoPlist = File('${exe.parent.path}/../Info.plist');
    if (infoPlist.existsSync()) {
      final xml = infoPlist.readAsStringSync();
      final match = RegExp(
        r'<key>CFBundleIdentifier</key>\s*<string>([^<]+)</string>',
      ).firstMatch(xml);
      if (match != null) {
        final id = match.group(1)!.trim();
        // Build-config placeholders (e.g. $(PRODUCT_BUNDLE_IDENTIFIER))
        // are unresolved in the template — use the known bundle id instead.
        if (id.isNotEmpty && !id.startsWith(r'$(')) return id;
      }
    }
  } catch (_) {}
  return 'com.dn.epitaka';
}

/// Removes any SQLite WAL, SHM, or journal files associated with [dbPath].
Future<void> cleanWalFiles(String dbPath) async {
  for (final suffix in ['-wal', '-shm', '-journal']) {
    final walFile = File('$dbPath$suffix');
    if (await walFile.exists()) {
      try {
        await walFile.delete();
      } catch (_) {}
    }
  }
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

  // Auto Dynamic Discovery: instead of hardcoded list of database assets.
  // discover any .db files actually bundled in the Flutter asset bundle, instead of har
  // On mobile release builds, no .db files are bundled in assets/ (translations
  // are downloaded on demand).
  // On desktop or standalone offline builds where .db files are bundled,
  // this extracts them to the writable database directory.
  final bundledDbs = <String>{};
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    for (final asset in manifest.listAssets()) {
      if (asset.startsWith('assets/db/') && asset.endsWith('.db')) {
        bundledDbs.add(asset);
      }
    }
  } catch (_) {}

  if (bundledDbs.isEmpty) return;

  for (final assetPath in bundledDbs) {
    final filename = p.basename(assetPath);
    final destPath = p.join(appDir.path, filename);
    final destFile = File(destPath);

    // Only skip if the destination exists and is not empty (0-byte file).
    if (await destFile.exists()) {
      try {
        if (await destFile.length() > 0) continue;
      } catch (_) {}
    }

    try {
      // Clean up stale WAL / SHM files before writing or copying
      await cleanWalFiles(destPath);

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
          final tempPath = '$destPath.tmp';
          final tempFile = File(tempPath);
          await onDisk.copy(tempFile.path);
          if (await tempFile.length() > 0) {
            await tempFile.rename(destPath);
            continue;
          } else {
            if (await tempFile.exists()) await tempFile.delete();
          }
        }
      }

      final data = await rootBundle.load(assetPath);
      // Skip 0-byte assets for the same reason as above.
      if (data.lengthInBytes == 0) continue;
      final tempPath = '$destPath.tmp';
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(data.buffer.asUint8List(), flush: true);
      if (await tempFile.length() > 0) {
        await tempFile.rename(destPath);
      } else {
        if (await tempFile.exists()) await tempFile.delete();
      }
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
    // The exe-adjacent data/ folder the old cwd heuristic could point at.
    p.join(File(Platform.resolvedExecutable).parent.path, 'data'),
  ];

  // Documents was the old fallback when no cwd-relative data/ existed.
  // Best-effort like the rest of the migration: path_provider's FFI can
  // fail after a hot restart (dart-lang/native#3281).
  try {
    legacyDirs.insert(0, (await getApplicationDocumentsDirectory()).path);
  } catch (e) {
    developer.log(
      '[DB_MIGRATE] Documents dir unavailable: $e',
      name: 'epitaka.database',
    );
  }

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
