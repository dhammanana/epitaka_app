import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../../core/utils/database_initializer.dart';

Future<Directory> mdxIndexDir() async {
  final base = await getDatabaseDirectory();
  final dir = Directory(p.join(base.path, 'mdx_index'));
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

Future<String> mdxIndexPathFor(String id) async {
  final dir = await mdxIndexDir();
  return p.join(dir.path, '$id.sqlite');
}

String mdxIdForPath(String mdxPath) {
  final normalized = p.normalize(p.absolute(mdxPath));
  final digest = sha256
      .convert(utf8.encode(normalized))
      .toString()
      .substring(0, 16);
  final base = p.basenameWithoutExtension(mdxPath);
  var safe = base.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
  safe = safe.replaceAll(RegExp(r'^_+|_+$'), '');
  if (safe.isEmpty) safe = 'mdx';
  return '${safe}_$digest';
}

bool isLegacyMdxId(String id) {
  return !RegExp(r'_[0-9a-f]{16}$').hasMatch(id);
}

/// Sibling `.mdd` resource files next to [mdxPath], mirroring Ciyue's
/// `initDictReaders`: `<base>.mdd`, then `<base>.1.mdd`, `<base>.2.mdd`, …
/// where `<base>` is the `.mdx` path without its extension.
List<String> discoverMddPaths(String mdxPath) {
  final lower = mdxPath.toLowerCase();
  final base = lower.endsWith('.mdx')
      ? mdxPath.substring(0, mdxPath.length - 4)
      : mdxPath;
  final out = <String>[];
  final first = File('$base.mdd');
  if (first.existsSync()) out.add(first.path);
  for (var i = 1; i <= 99; i++) {
    final f = File('$base.$i.mdd');
    if (f.existsSync()) {
      out.add(f.path);
    } else {
      break;
    }
  }
  return out;
}

/// Copies a companion bundle file (`.mdd` resources, `.css` stylesheets,
/// `.js`) next to the persisted `.mdx` so sidecar lookup
/// (`discoverMddPaths`, stylesheet `href`s, image/audio sidecars) keeps
/// working after a SAF multi-pick on Android/iOS, where only the files the
/// user explicitly selects are granted to the app.
Future<void> copyCompanionNextToMdx({
  required String companionSrc,
  required String stableMdxPath,
}) async {
  final dest = File(p.join(p.dirname(stableMdxPath), p.basename(companionSrc)));
  if (p.normalize(dest.path) == p.normalize(companionSrc)) return;
  final srcFile = File(companionSrc);
  if (!await srcFile.exists()) return;
  if (await dest.exists()) {
    try {
      if (await dest.length() == await srcFile.length()) return;
    } catch (_) {}
  }
  await srcFile.copy(dest.path);
}

/// Copies `.mdd` resource siblings plus `.css`/`.js` sidecars found next to
/// [originalMdxPath] alongside the persisted copy at [stableMdxPath].
///
/// Needed on platforms where [ensurePersistentCopy] relocates the `.mdx`
/// into app-private storage (mobile, macOS sandbox): without this,
/// `discoverMddPaths(stable)` and stylesheet/image sidecar lookups next to
/// the copy would find nothing even though the originals sit next to the
/// source file. Best-effort — individual copy failures are swallowed so one
/// unreadable sidecar never blocks the import itself.
Future<void> copyMdxSidecars({
  required String originalMdxPath,
  required String stableMdxPath,
}) async {
  if (p.normalize(originalMdxPath) == p.normalize(stableMdxPath)) return;
  final srcDir = p.dirname(originalMdxPath);
  final base = p.basenameWithoutExtension(originalMdxPath);
  final candidates = <String>{};
  // Ciyue-style .mdd chain: <base>.mdd, <base>.1.mdd … <base>.99.mdd.
  candidates.add(p.join(srcDir, '$base.mdd'));
  for (var i = 1; i <= 99; i++) {
    final mdd = p.join(srcDir, '$base.$i.mdd');
    if (File(mdd).existsSync()) {
      candidates.add(mdd);
    } else {
      break;
    }
  }
  // Stylesheets / scripts / same-name sidecars with common extensions.
  for (final ext in ['.css', '.mcss', '.js', '.mdd']) {
    final f = p.join(srcDir, '$base$ext');
    if (File(f).existsSync()) candidates.add(f);
  }
  // Also pick up any other .css/.js sitting next to the .mdx (dictionary
  // bundles often ship extra stylesheets referenced by <link> hrefs).
  try {
    await for (final e in Directory(srcDir).list(followLinks: false)) {
      if (e is! File) continue;
      final lower = e.path.toLowerCase();
      if (lower.endsWith('.css') ||
          lower.endsWith('.mcss') ||
          lower.endsWith('.js')) {
        candidates.add(e.path);
      }
    }
  } catch (_) {
    // Sandbox may deny listing the source dir — the explicit candidates
    // above still get a chance below.
  }
  for (final src in candidates) {
    try {
      await copyCompanionNextToMdx(
        companionSrc: src,
        stableMdxPath: stableMdxPath,
      );
    } catch (_) {}
  }
}

/// Whether [path] already lives inside app-private [baseDir].
bool isInsideAppStorage(String path, String baseDir) {
  final baseNorm = p.normalize(baseDir);
  final pathNorm = p.normalize(path);
  return pathNorm == baseNorm ||
      pathNorm.startsWith('$baseNorm${p.separator}');
}

/// Copies [path] into app-private storage and returns the private path.
///
/// Mobile (Android/iOS) ALWAYS copies (unless already private): the system
/// picker (SAF / UIDocumentPicker) grants per-file access with no storage
/// permission, and raw shared-storage paths are not readable under scoped
/// storage — so the app must never keep a reference to them. This is what
/// keeps the app compliant with Google Play's All Files Access policy
/// (no MANAGE_EXTERNAL_STORAGE).
///
/// macOS Release builds are App-sandboxed (`com.apple.security.app-sandbox`
/// = true, only `user-selected.read-write` granted): a path picked via
/// `NSOpenPanel` is readable only while the security-scoped grant is alive.
/// It does NOT survive app restarts, and `Isolate.run` workers used for
/// indexing/lookup lose it even sooner — reopening the original later fails
/// with `PathAccessException … Operation not permitted, errno = 1`.
/// So macOS copies into the sandbox container too, exactly like mobile.
/// Windows/Linux are unsandboxed, so they keep referencing the original
/// file and only transient picker copies (`/tmp/…`, `/cache/…`) are
/// persisted.
Future<String> ensurePersistentCopy(String path) async {
  final base = await getDatabaseDirectory();
  final baseNorm = p.normalize(base.path);
  final pathNorm = p.normalize(path);
  // Already inside app-private storage — nothing to do.
  if (isInsideAppStorage(pathNorm, baseNorm)) {
    return path;
  }
  final lower = path.toLowerCase();
  final transient =
      lower.contains('/cache/') ||
      lower.contains('/tmp/') ||
      lower.contains('/temp/');
  // Desktop (non-macOS): keep referencing the original file; only transient
  // picker copies need persisting. Mobile + macOS sandbox: always persist.
  final needsCopy =
      transient ||
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS;
  if (!needsCopy) return path;
  final dir = Directory(p.join(base.path, 'mdx_files'));
  if (!await dir.exists()) await dir.create(recursive: true);
  final srcLen = await File(path).length();
  var dest = File(p.join(dir.path, p.basename(path)));
  var i = 1;
  while (await dest.exists()) {
    if (await dest.length() == srcLen) return dest.path;
    dest = File(
      p.join(
        dir.path,
        '${p.basenameWithoutExtension(path)}_$i${p.extension(path)}',
      ),
    );
    i++;
    if (i > 100) break;
  }
  await File(path).copy(dest.path);
  return dest.path;
}
