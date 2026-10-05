import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/mdx_dictionary_info.dart';
import '../services/mdx_errors.dart';
import '../services/mdx_index_service.dart';
import '../services/mdx_paths.dart';
import '../services/mdx_validate.dart';
import '../../../core/utils/database_initializer.dart';

final mdxIndexServiceProvider = Provider<MdxIndexService>((ref) {
  final svc = MdxIndexService();
  ref.onDispose(() => unawaited(svc.dispose()));
  return svc;
});

final mdxDictionariesProvider =
    StateNotifierProvider<
      MdxDictionariesNotifier,
      AsyncValue<List<MdxDictionaryInfo>>
    >((ref) => MdxDictionariesNotifier(ref));

class MdxDictionariesNotifier
    extends StateNotifier<AsyncValue<List<MdxDictionaryInfo>>> {
  final Ref ref;
  static const String storeKey = 'mdx_dictionaries_v1';
  final Map<String, double> progress = {};

  MdxDictionariesNotifier(this.ref) : super(const AsyncLoading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storeKey);
      if (raw == null || raw.isEmpty) {
        state = const AsyncData([]);
        return;
      }
      var list = (jsonDecode(raw) as List)
          .map((e) => MdxDictionaryInfo.fromJson(e as Map<String, dynamic>))
          .toList();
      var changed = false;
      // One-time sandbox migration (macOS): older builds stored the
      // user-picked external path (e.g. /Volumes/Data/….mdx). The sandboxed
      // Release app loses access to it after restart
      // (PathAccessException, errno 1), so relocate it into app-private
      // storage now while the file may still be readable. The index file is
      // renamed alongside (same logic as the id-mismatch branch below), so
      // no re-index is needed when the bytes are identical.
      if (Platform.isMacOS) {
        try {
          final base = await getDatabaseDirectory();
          for (var i = 0; i < list.length; i++) {
            var d = list[i];
            if (isInsideAppStorage(d.mdxPath, base.path)) continue;
            try {
              if (!await File(d.mdxPath).exists()) continue;
              final stable = await ensurePersistentCopy(d.mdxPath);
              if (stable == d.mdxPath) continue;
              await copyMdxSidecars(
                originalMdxPath: d.mdxPath,
                stableMdxPath: stable,
              );
              d = d.copyWith(
                mdxPath: stable,
                mddPaths: discoverMddPaths(stable),
              );
              list[i] = d;
              changed = true;
            } catch (_) {
              // Still sandboxed out (or external drive unmounted) — leave
              // the entry alone; it surfaces the actionable error below.
            }
          }
        } catch (_) {}
      }
      for (var i = 0; i < list.length; i++) {
        var d = list[i];
        final expectedId = mdxIdForPath(d.mdxPath);
        if (d.id != expectedId) {
          final oldIndex = d.indexPath;
          var newIndex = oldIndex;
          try {
            newIndex = await mdxIndexPathFor(expectedId);
            if (oldIndex != null && oldIndex != newIndex) {
              final oldFile = File(oldIndex);
              if (await oldFile.exists()) {
                final target = File(newIndex);
                if (!await target.exists()) {
                  await oldFile.rename(newIndex);
                } else {
                  await oldFile.delete();
                }
              }
            }
          } catch (_) {}
          d = d.copyWith(id: expectedId, indexPath: newIndex ?? d.indexPath);
          changed = true;
        }
        if (isLegacyMdxId(d.id)) {
          final fresh = mdxIdForPath(d.mdxPath);
          if (fresh != d.id) {
            d = d.copyWith(id: fresh);
            changed = true;
          }
        }
        bool mdxExists = false;
        try {
          mdxExists = await File(d.mdxPath).exists();
        } catch (_) {
          mdxExists = false;
        }
        if (!mdxExists) {
          // Under the macOS sandbox, exists() also returns false for files
          // outside the container once the picker grant expired — the file
          // is usually still there, the app just can't see it anymore.
          final missingMsg = Platform.isMacOS
              ? 'File not reachable (moved, deleted, or macOS sandbox '
                  'revoked access).\n${d.mdxPath}\n'
                  'Remove it and re-add to keep a private copy.'
              : 'File not found. It was moved or deleted.\n${d.mdxPath}';
          if (d.status != MdxStatus.error ||
              d.lastError == null ||
              (!d.lastError!.startsWith('File not found') &&
                  !d.lastError!.startsWith('File not reachable'))) {
            d = d.copyWith(
              status: MdxStatus.error,
              lastError: missingMsg,
            );
            changed = true;
          }
        } else if (d.status == MdxStatus.error &&
            d.lastError != null &&
            (d.lastError!.startsWith('File not found') ||
                d.lastError!.startsWith('File not reachable'))) {
          final hasIndex =
              d.indexPath != null && await File(d.indexPath!).exists();
          d = d.copyWith(
            clearError: true,
            status: hasIndex && d.entryCount > 0
                ? MdxStatus.ready
                : MdxStatus.pending,
            progress: hasIndex && d.entryCount > 0 ? 1.0 : 0.0,
          );
          changed = true;
        } else if (d.status == MdxStatus.indexing ||
            d.status == MdxStatus.pending) {
          final hasIndex =
              d.indexPath != null && await File(d.indexPath!).exists();
          if (hasIndex && d.entryCount > 0) {
            d = d.copyWith(status: MdxStatus.ready, progress: 1.0);
            changed = true;
          } else {
            d = d.copyWith(status: MdxStatus.pending, progress: 0.0);
            changed = true;
          }
        }
        if (d.mddPaths.isEmpty && await File(d.mdxPath).exists()) {
          final found = discoverMddPaths(d.mdxPath);
          if (found.isNotEmpty) {
            d = d.copyWith(mddPaths: found);
            changed = true;
          }
        }
        list[i] = d;
      }
      list.sort((a, b) => a.userOrder.compareTo(b.userOrder));
      state = AsyncData(list);
      for (final d in list) {
        if (d.status == MdxStatus.indexing || d.status == MdxStatus.pending) {
          progress[d.id] = d.progress;
        }
      }
      if (changed) {
        await prefs.setString(
          storeKey,
          jsonEncode([for (final d in list) d.toJson()]),
        );
      }
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> _save(List<MdxDictionaryInfo> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storeKey,
      jsonEncode([for (final d in list) d.toJson()]),
    );
    state = AsyncData([...list]);
  }

  Future<void> update(
    String id,
    MdxDictionaryInfo Function(MdxDictionaryInfo d) fn,
  ) async {
    final list = _current.map((d) => d.id == id ? fn(d) : d).toList();
    await _save(list);
  }

  List<MdxDictionaryInfo> get _current =>
      state is AsyncData<List<MdxDictionaryInfo>>
      ? (state as AsyncData<List<MdxDictionaryInfo>>).value
      : [];

  Future<void> toggleEnabled(String id, bool enabled) async {
    final list = _current
        .map((d) => d.id == id ? d.copyWith(enabled: enabled) : d)
        .toList();
    await _save(list);
  }

  Future<void> updateTitle(String id, String title) async {
    final list = _current
        .map((d) => d.id == id ? d.copyWith(alias: title.trim().isEmpty ? null : title.trim()) : d)
        .toList();
    await _save(list);
  }

  Future<int> getIndexSize(String indexPath) async {
    try {
      final file = File(indexPath);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (_) {}
    return 0;
  }

  Future<int> getTotalIndexDirSize() async {
    try {
      final indexDir = await mdxIndexDir();
      if (await indexDir.exists()) {
        int totalSize = 0;
        await for (final entity in indexDir.list(recursive: true)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
        return totalSize;
      }
    } catch (_) {}
    return 0;
  }

  Future<void> clearErrorsAndRebuildAll() async {
    for (final d in _current) {
      if (d.status == MdxStatus.error) {
        await update(d.id, (dict) => dict.copyWith(clearError: true, status: MdxStatus.pending, progress: 0.0));
        unawaited(_buildInBackground(d.copyWith(status: MdxStatus.pending, progress: 0.0, clearError: true)));
      }
    }
  }

  Future<void> flagMissing(String id) async {
    final dict = _current.where((d) => d.id == id).firstOrNull;
    if (dict != null) {
      await update(id, (d) => d.copyWith(
        status: MdxStatus.error,
        lastError: 'File not found. It was moved or deleted.\n${dict.mdxPath}',
      ));
    }
  }

  Future<void> reorder(List<String> orderedIds) async {
    final previous = state;
    final byId = {for (final d in _current) d.id: d};
    final reordered = <MdxDictionaryInfo>[
      for (var i = 0; i < orderedIds.length; i++)
        if (byId.containsKey(orderedIds[i]))
          byId[orderedIds[i]]!.copyWith(userOrder: i),
    ];
    for (final d in _current) {
      if (!orderedIds.contains(d.id)) {
        reordered.add(d.copyWith(userOrder: reordered.length));
      }
    }
    state = AsyncData(reordered);
    try {
      await _save(reordered);
    } catch (_) {
      state = previous;
    }
  }

  Future<void> remove(String id) async {
    final target = _current.where((d) => d.id == id).firstOrNull;
    final list = _current.where((d) => d.id != id).toList();
    for (var i = 0; i < list.length; i++) {
      list[i] = list[i].copyWith(userOrder: i);
    }
    progress.remove(id);
    await _save(list);
    if (target?.indexPath != null) {
      try {
        final f = File(target!.indexPath!);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  Future<void> addMdxFile(String mdxPath) async {
    final trimmed = mdxPath.trim();
    if (trimmed.isEmpty) {
      throw const MdxException('Empty file path returned by picker.');
    }
    final file = File(trimmed);
    if (!await file.exists()) {
      throw MdxException('MDX file not found.', path: trimmed);
    }
    if (!trimmed.toLowerCase().endsWith('.mdx')) {
      final peek = await peekMdxHeader(trimmed);
      if (!peek.isMdxLike) {
        await ensureMdxFileOrExplain(trimmed);
      }
    }
    var stable = trimmed;
    try {
      stable = await ensurePersistentCopy(trimmed);
      // The .mdx may now live in app-private storage while its .mdd/.css/.js
      // siblings stayed next to the original — bring them alongside so
      // images/audio/styling resolve. Best-effort; never blocks the import.
      try {
        await copyMdxSidecars(
          originalMdxPath: trimmed,
          stableMdxPath: stable,
        );
      } catch (_) {}
    } catch (e) {
      throw MdxException(
        'Could not copy file into app storage: ${describeMdxError(e)}',
        path: trimmed,
      );
    }
    if (_current.any((d) => d.mdxPath == trimmed || d.mdxPath == stable)) {
      throw MdxException('Already added.', path: trimmed);
    }
    final id = mdxIdForPath(stable);
    final indexPath = await mdxIndexPathFor(id);
    final entry = MdxDictionaryInfo(
      id: id,
      title: stable.split(Platform.pathSeparator).last,
      mdxPath: stable,
      userOrder: _current.length,
      enabled: true,
      entryCount: 0,
      indexPath: indexPath,
      status: MdxStatus.pending,
      progress: 0.0,
      mddPaths: discoverMddPaths(stable),
    );
    await _save([..._current, entry]);
    unawaited(_buildInBackground(entry));
  }

  Future<void> _buildInBackground(MdxDictionaryInfo entry) async {
    final id = entry.id;
    progress[id] = 0.0;
    await update(
      id,
      (d) => d.copyWith(
        status: MdxStatus.indexing,
        progress: 0.0,
        clearError: true,
      ),
    );
    try {
      String? title;
      try {
        title = await ref
            .read(mdxIndexServiceProvider)
            .readTitle(entry.mdxPath);
      } catch (_) {
        title = null;
      }
      if (title != null && title.trim().isNotEmpty) {
        await update(id, (d) => d.copyWith(title: title!.trim()));
      }
      progress[id] = 0.1;
      await update(id, (d) => d.copyWith(progress: 0.1));
      final count = await ref
          .read(mdxIndexServiceProvider)
          .buildIndex(mdxPath: entry.mdxPath, indexPath: entry.indexPath!);
      progress.remove(id);
      await update(
        id,
        (d) => d.copyWith(
          entryCount: count,
          status: MdxStatus.ready,
          progress: 1.0,
          clearError: true,
        ),
      );
    } catch (e) {
      progress.remove(id);
      final msg = describeMdxError(e, path: entry.mdxPath);
      await update(
        id,
        (d) => d.copyWith(status: MdxStatus.error, lastError: msg),
      );
    }
  }

  Future<void> rebuild(String id) async {
    final entry = _current.where((d) => d.id == id).firstOrNull;
    if (entry == null) {
      throw const MdxException('Dictionary no longer in list.');
    }
    if (!await File(entry.mdxPath).exists()) {
      final msg = 'File not found. It was moved or deleted.\n${entry.mdxPath}';
      await update(
        id,
        (d) => d.copyWith(status: MdxStatus.error, lastError: msg),
      );
      throw MdxException(msg, path: entry.mdxPath);
    }
    progress[id] = 0.0;
    await update(
      id,
      (d) => d.copyWith(
        status: MdxStatus.indexing,
        progress: 0.0,
        clearError: true,
      ),
    );
    await _buildInBackground(entry);
  }
}
