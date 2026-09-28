import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/providers/settings_provider.dart';
import '../models/mdx_dictionary_info.dart';
import '../services/mdx_errors.dart';
import '../services/mdx_web.dart';
import 'mdx_dictionary_provider.dart';
import 'mdx_lookup_providers.dart';

/// Measured WebView content heights keyed by `$dictId\n$word`, so each
/// definition section sizes its embedded WebView inside the scrolling list.
final mdxWebHeightsProvider =
    StateProvider<Map<String, double>>((ref) => const {});

String mdxWebHeightKey(String dictId, String word) => '$dictId\n$word';

/// Full HTML document for one lookup, Ciyue-style: raw entry bodies (scripts
/// kept) plus auto-injected `<basename>.css` / `<basename>.js` bundle links
/// when present as sidecar files or inside the `.mdd` archives.
final mdxWebDocumentProvider =
    FutureProvider.autoDispose.family<String, MdxDefKey>((ref, key) async {
  final dicts = ref.watch(mdxDictionariesProvider).valueOrNull ?? [];
  final info = dicts.where((d) => d.id == key.dictId).firstOrNull;
  if (info == null) {
    throw MdxNotReady('Dictionary removed from list.');
  }
  if (!File(info.mdxPath).existsSync()) {
    throw MdxMissingFile(info.mdxPath);
  }
  if (info.indexPath == null || info.status != MdxStatus.ready) {
    throw MdxNotReady(
      'Index not ready. Tap Rebuild in dictionary settings.',
      path: info.mdxPath,
    );
  }
  final collapseByDefault = ref.watch(settingsProvider).mdxCollapseByDefault;
  final svc = ref.watch(mdxIndexServiceProvider);
  final bodies = await svc.readDefinitions(
    info.mdxPath,
    info.indexPath!,
    key.word,
    allowScripts: true,
    maxChars: null,
  );
  // No entry in this dictionary → empty document; the section hides itself.
  if (bodies.isEmpty) return '';
  final base = p.basenameWithoutExtension(info.mdxPath);
  final mdds = info.mddPaths.isEmpty ? null : info.mddPaths;
  Future<bool> available(String name) async {
    final sidecar = File(p.join(p.dirname(info.mdxPath), name));
    try {
      if (await sidecar.exists()) return true;
    } catch (_) {}
    try {
      final bytes = await svc.readResourceBytes(
        mdxPath: info.mdxPath,
        mddPaths: mdds,
        key: name,
      );
      return bytes != null && bytes.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  final cssName = '$base.css';
  final jsName = '$base.js';
  final cssHref = await available(cssName)
      ? '$mdxWebAssetBaseUrl${Uri.encodeComponent(cssName)}'
      : null;
  final jsSrc = await available(jsName)
      ? '$mdxWebAssetBaseUrl${Uri.encodeComponent(jsName)}'
      : null;
  return buildMdxWebDocument(
    cssHref: cssHref,
    jsSrc: jsSrc,
    bodies: bodies,
    collapseByDefault: collapseByDefault,
  );
});
