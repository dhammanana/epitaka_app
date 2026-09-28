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
  if (dest.path == companionSrc) return;
  final srcFile = File(companionSrc);
  if (!await srcFile.exists()) return;
  if (await dest.exists()) {
    try {
      if (await dest.length() == await srcFile.length()) return;
    } catch (_) {}
  }
  await srcFile.copy(dest.path);
}

Future<String> ensurePersistentCopy(String path) async {
  final lower = path.toLowerCase();
  final transient =
      lower.contains('/cache/') ||
      lower.contains('/tmp/') ||
      lower.contains('/temp/');
  if (!transient) return path;
  final base = await getDatabaseDirectory();
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
