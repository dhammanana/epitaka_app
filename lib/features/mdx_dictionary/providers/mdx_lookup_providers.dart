import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mdx_dictionary_provider.dart';
import '../models/mdx_dictionary_info.dart';
import '../services/mdx_errors.dart';
import '../services/mdx_text.dart';

class MdxDefKey {
  final String dictId;
  final String word;
  const MdxDefKey(this.dictId, this.word);

  @override
  bool operator ==(Object other) =>
      other is MdxDefKey && dictId == other.dictId && word == other.word;

  @override
  int get hashCode => Object.hash(dictId, word);
}

class MdxResKey {
  final String dictId;
  final String src;
  const MdxResKey(this.dictId, this.src);

  @override
  bool operator ==(Object other) =>
      other is MdxResKey && dictId == other.dictId && src == other.src;

  @override
  int get hashCode => Object.hash(dictId, src);
}

final mdxSuggestionsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, query) async {
      final q = mdxNorm(query);
      if (q.isEmpty) return [];
      final dicts = ref.watch(mdxDictionariesProvider).valueOrNull ?? [];
      final enabled =
          dicts
              .where(
                (d) =>
                    d.enabled &&
                    d.status == MdxStatus.ready &&
                    d.indexPath != null &&
                    File(d.mdxPath).existsSync(),
              )
              .toList()
            ..sort((a, b) => a.userOrder.compareTo(b.userOrder));
      if (enabled.isEmpty) return [];
      final svc = ref.watch(mdxIndexServiceProvider);
      final seen = <String>{};
      final out = <String>[];
      for (final d in enabled) {
        try {
          final hits = await svc.searchPrefix(d.indexPath!, q, limit: 15);
          for (final h in hits) {
            if (seen.add(h.toLowerCase())) {
              out.add(h);
              if (out.length >= 30) return out;
            }
          }
        } catch (e) {
          debugPrint('mdx search skipped ${d.id}: $e');
        }
      }
      return out;
    });

final mdxExactHitProvider = FutureProvider.autoDispose.family<bool, String>((
  ref,
  query,
) async {
  final q = mdxNorm(query);
  if (q.isEmpty) return false;
  final dicts = ref.watch(mdxDictionariesProvider).valueOrNull ?? [];
  final enabled = dicts.where(
    (d) =>
        d.enabled &&
        d.status == MdxStatus.ready &&
        d.indexPath != null &&
        File(d.mdxPath).existsSync(),
  );
  if (enabled.isEmpty) return false;
  final svc = ref.watch(mdxIndexServiceProvider);
  for (final d in enabled) {
    try {
      if (await svc.hasExact(d.indexPath!, q)) return true;
    } catch (e) {
      debugPrint('mdx exact skipped ${d.id}: $e');
    }
  }
  return false;
});

final mdxDefinitionsProvider = FutureProvider.autoDispose
    .family<List<String>, MdxDefKey>((ref, key) async {
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
      return ref
          .read(mdxIndexServiceProvider)
          .readDefinitions(info.mdxPath, info.indexPath!, key.word);
    });

final mdxResourceProvider = FutureProvider.autoDispose
    .family<Uint8List?, MdxResKey>((ref, key) async {
      final src = key.src.trim();
      if (src.isEmpty) return null;
      final lower = src.toLowerCase();
      if (lower.startsWith('data:') ||
          lower.startsWith('http://') ||
          lower.startsWith('https://') ||
          lower.startsWith('asset:') ||
          lower.startsWith('blob:')) {
        return null;
      }
      final dicts = ref.watch(mdxDictionariesProvider).valueOrNull ?? [];
      final info = dicts.where((d) => d.id == key.dictId).firstOrNull;
      if (info == null || !File(info.mdxPath).existsSync()) return null;
      try {
        return await ref
            .read(mdxIndexServiceProvider)
            .readResourceBytes(
              mdxPath: info.mdxPath,
              mddPaths: info.mddPaths.isEmpty ? null : info.mddPaths,
              key: src,
            );
      } catch (e) {
        debugPrint('mdx resource miss ${info.id} $src: $e');
        return null;
      }
    });
