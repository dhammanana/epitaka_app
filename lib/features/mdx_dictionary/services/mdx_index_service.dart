import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dict_reader/dict_reader.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'mdx_errors.dart';
import 'mdx_paths.dart';
import 'mdx_text.dart';

class MdxIndexService {
  static const int batchSize = 5000;
  static const int maxSegmentsPerEntry = 16;
  static const int maxSearchLimit = 30;
  static const int maxDefinitionChars = 20000;
  static const int maxLinkDepth = 3;
  static const int _maxPooledReaders = 4;

  final Map<String, DictReader> _readers = {};
  final List<String> _lru = [];
  final Map<String, Future<DictReader>> _pending = {};
  final Map<String, Future<void>> _pathLocks = {};

  Future<void> dispose() async {
    _pending.clear();
    _pathLocks.clear();
    _cssCache.clear();
    final readers = _readers.values.toList();
    _readers.clear();
    _lru.clear();
    for (final r in readers) {
      try {
        await r.close();
      } catch (_) {}
    }
  }

  Future<T> _withPathLock<T>(String path, Future<T> Function() fn) {
    final prev = _pathLocks[path] ?? Future.value();
    final next = prev.then((_) => fn());
    _pathLocks[path] = next.then((_) {}, onError: (_) {});
    return next;
  }

  Future<DictReader> _acquire(String path, {required bool isMdd}) {
    final hit = _readers[path];
    if (hit != null) {
      _lru.remove(path);
      _lru.add(path);
      return Future.value(hit);
    }
    final pending = _pending[path];
    if (pending != null) return pending;
    final fut = _open(path, isMdd: isMdd);
    _pending[path] = fut;
    return fut;
  }

  Future<DictReader> _open(String path, {required bool isMdd}) async {
    try {
      final reader = DictReader(path);
      if (isMdd) {
        await reader.initDict();
      } else {
        await reader.initDict(readKeys: false, readRecordBlockInfo: true);
      }
      _readers[path] = reader;
      _lru.add(path);
      while (_lru.length > _maxPooledReaders) {
        final evict = _lru.removeAt(0);
        if (evict == path) {
          _lru.add(path);
          break;
        }
        final r = _readers.remove(evict);
        if (r != null) {
          try {
            await r.close();
          } catch (_) {}
        }
      }
      return reader;
    } finally {
      _pending.remove(path);
    }
  }

  Future<int> buildIndex({required String mdxPath, required String indexPath}) {
    return Isolate.run(() => _buildSync(mdxPath, indexPath));
  }

  Future<List<String>> searchPrefix(
    String indexPath,
    String query, {
    int limit = 25,
  }) async {
    final q = mdxNorm(query);
    if (q.isEmpty) return [];
    if (!File(indexPath).existsSync()) {
      throw StateError('index missing, rebuild');
    }
    final cappedLimit = limit.clamp(1, maxSearchLimit);
    try {
      return await Isolate.run(() {
        final db = sqlite3.open(indexPath, mode: OpenMode.readOnly);
        try {
          final rows = db.select(
            'SELECT key FROM mdx_index WHERE norm_key GLOB ? COLLATE NOCASE ORDER BY norm_key LIMIT ?',
            ['$q*', cappedLimit],
          );
          return [for (final r in rows) r['key'] as String];
        } finally {
          db.dispose();
        }
      });
    } catch (e) {
      throw MdxException(describeMdxError(e, path: indexPath));
    }
  }

  Future<List<String>> readDefinitions(
    String mdxPath,
    String indexPath,
    String key, {
    bool allowScripts = false,
    int? maxChars,
  }) async {
    if (!File(mdxPath).existsSync()) throw MdxMissingFile(mdxPath);
    if (!File(indexPath).existsSync()) {
      throw MdxNotReady('Index missing. Tap Rebuild.', path: indexPath);
    }
    final norm = mdxNorm(key);
    if (norm.isEmpty) return [];
    late final List<List<dynamic>> offsets;
    try {
      offsets = await Isolate.run(() => _exactOffsets(indexPath, norm));
    } catch (e) {
      throw MdxException(describeMdxError(e, path: indexPath), path: indexPath);
    }
    if (offsets.isEmpty) return [];
    final out = <String>[];
    final visited = <String>{norm};
    for (final row in offsets.take(3)) {
      var html = await _readOne(mdxPath, row);
      html = await _followLinks(mdxPath, indexPath, html, visited, 0);
      final css = await _cssFor(mdxPath, mdxStylesheetHrefs(html));
      html = mdxStripStylesheetLinks(html);
      out.add(
        _finalize(
          css + html,
          allowScripts: allowScripts,
          // Null passes through as uncapped; never default to the cap
          // here, or long WebView documents get cut mid-tag (blank card).
          maxChars: maxChars,
        ),
      );
    }
    return out;
  }

  Future<String> _readOne(String mdxPath, List<dynamic> row) {
    return _withPathLock(mdxPath, () async {
      final reader = await _acquire(mdxPath, isMdd: false);
      return reader.readOneMdx(_infoFromRow(row));
    });
  }

  Future<String> _followLinks(
    String mdxPath,
    String indexPath,
    String html,
    Set<String> visited,
    int depth,
  ) async {
    if (depth >= maxLinkDepth) return html;
    final targets = mdxLinkTargets(html);
    if (targets.isEmpty) return html;
    final resolved = <String>[];
    for (final target in targets) {
      final norm = mdxNorm(target);
      if (norm.isEmpty || !visited.add(norm)) continue;
      late final List<List<dynamic>> rows;
      try {
        rows = await Isolate.run(() => _exactOffsets(indexPath, norm));
      } catch (_) {
        continue;
      }
      if (rows.isEmpty) continue;
      var linked = await _readOne(mdxPath, rows.first);
      linked = await _followLinks(
        mdxPath,
        indexPath,
        linked,
        visited,
        depth + 1,
      );
      resolved.add(linked);
    }
    if (resolved.isEmpty) return html;
    return resolved.join();
  }

  /// [maxChars] caps the output length (`null` = uncapped, used for full
  /// WebView documents; the flutter_html path passes an explicit cap).
  String _finalize(
    String html, {
    required bool allowScripts,
    int? maxChars,
  }) {
    var out = mdxApplyMaxChars(html, maxChars);
    if (!allowScripts) out = mdxSanitize(out);
    return out.trim();
  }

  final Map<String, String> _cssCache = {};

  Future<String> _cssFor(String mdxPath, List<String> hrefs) async {
    final blocks = <String>[];
    final seen = <String>{};
    Future<void> add(String name) async {
      final norm = name.trim().toLowerCase();
      if (norm.isEmpty || !seen.add(norm)) return;
      final key = '$mdxPath|$norm';
      var css = _cssCache[key];
      css ??= await _loadStylesheet(mdxPath, name);
      if (css == null) return;
      if (_cssCache.length > 32) _cssCache.clear();
      _cssCache[key] = css;
      blocks.add(css);
    }

    await add('${p.basenameWithoutExtension(mdxPath)}.css');
    for (final h in hrefs) {
      await add(h);
    }
    if (blocks.isEmpty) return '';
    return blocks.map((b) => '<style>$b</style>').join();
  }

  Future<String?> _loadStylesheet(String mdxPath, String name) async {
    var clean = name.trim().split('#').first.split('?').first.trim();
    if (clean.isEmpty ||
        clean.startsWith('//') ||
        RegExp(r'^[a-z][a-z0-9+.-]*:', caseSensitive: false).hasMatch(clean)) {
      return null;
    }
    try {
      clean = Uri.decodeComponent(clean);
    } catch (_) {}
    clean = clean.replaceAll('\\', '/');
    while (clean.startsWith('/')) {
      clean = clean.substring(1);
    }
    if (clean.isEmpty ||
        clean.contains('..') ||
        !clean.toLowerCase().endsWith('.css')) {
      return null;
    }
    try {
      final sidecar = File(p.join(p.dirname(mdxPath), clean));
      if (await sidecar.exists()) {
        final text = await sidecar.readAsString();
        if (text.trim().isEmpty) return null;
        return mdxSanitizeCss(_capCss(text));
      }
    } catch (_) {}
    try {
      final bytes = await readResourceBytes(mdxPath: mdxPath, key: clean);
      if (bytes == null || bytes.isEmpty) return null;
      final text = utf8.decode(bytes, allowMalformed: true);
      if (text.trim().isEmpty) return null;
      return mdxSanitizeCss(_capCss(text));
    } catch (_) {
      return null;
    }
  }

  String _capCss(String css) =>
      css.length > 50000 ? css.substring(0, 50000) : css;

  Future<Uint8List?> readResourceBytes({
    required String mdxPath,
    List<String>? mddPaths,
    required String key,
  }) async {
    var clean = key.trim();
    if (clean.isEmpty) return null;
    for (final scheme in ['entry://', 'sound://']) {
      if (clean.toLowerCase().startsWith(scheme)) {
        clean = clean.substring(scheme.length);
      }
    }
    clean = clean.split('#').first.split('?').first.trim();
    try {
      clean = Uri.decodeComponent(clean);
    } catch (_) {}
    clean = clean.replaceAll('\\', '/');
    while (clean.startsWith('/')) {
      clean = clean.substring(1);
    }
    if (clean.isEmpty || clean.contains('..')) return null;
    final dir = p.dirname(mdxPath);
    try {
      final sidecar = File(p.join(dir, clean));
      if (await sidecar.exists()) return await sidecar.readAsBytes();
    } catch (_) {}
    final mdds = mddPaths ?? discoverMddPaths(mdxPath);
    for (final mdd in mdds) {
      if (!File(mdd).existsSync()) continue;
      final bytes = await _readMddBytes(mdd, clean);
      if (bytes != null) return bytes;
    }
    return null;
  }

  Future<Uint8List?> _readMddBytes(String mddPath, String key) {
    return _withPathLock(mddPath, () async {
      DictReader reader;
      try {
        reader = await _acquire(mddPath, isMdd: true);
      } catch (_) {
        return null;
      }
      for (final k in mdxResourceKeys(key)) {
        bool exists;
        try {
          exists = reader.exist(k);
        } catch (_) {
          continue;
        }
        if (!exists) continue;
        try {
          final info = await reader.locate(k);
          if (info == null) continue;
          final data = await reader.readOneMdd(info);
          if (data.isNotEmpty) return Uint8List.fromList(data);
        } catch (_) {
          continue;
        }
      }
      return null;
    });
  }

  RecordOffsetInfo _infoFromRow(List<dynamic> row) {
    return RecordOffsetInfo(
      row[0] as String,
      row[1] as int,
      row[2] as int,
      row[3] as int,
      row[4] as int,
      segments: [
        for (final s in (jsonDecode(row[5] as String) as List))
          (s[0] as int, s[1] as int, s[2] as int, s[3] as int),
      ],
    );
  }

  Future<String?> readTitle(String mdxPath) {
    return Isolate.run(() => _readTitleSync(mdxPath));
  }

  Future<bool> hasExact(String indexPath, String key) async {
    final norm = mdxNorm(key);
    if (norm.isEmpty) return false;
    if (!File(indexPath).existsSync()) {
      throw StateError('index missing, rebuild');
    }
    try {
      return await Isolate.run(() => _exactOffsets(indexPath, norm).isNotEmpty);
    } catch (e) {
      throw MdxException(describeMdxError(e, path: indexPath));
    }
  }
}

Future<String?> _readTitleSync(String mdxPath) async {
  final reader = DictReader(mdxPath);
  try {
    await reader.initDict(readKeys: false, readRecordBlockInfo: false);
    return reader.header['Title'];
  } catch (_) {
    return null;
  } finally {
    try {
      await reader.close();
    } catch (_) {}
  }
}

List<List<dynamic>> _exactOffsets(String indexPath, String norm) {
  if (!File(indexPath).existsSync()) {
    throw StateError('index missing, rebuild');
  }
  final db = sqlite3.open(indexPath, mode: OpenMode.readOnly);
  try {
    final rows = db.select(
      'SELECT key, block_offset, start_offset, end_offset, comp_size, segments FROM mdx_index WHERE norm_key = ? COLLATE NOCASE LIMIT 5',
      [norm],
    );
    return [
      for (final r in rows)
        [
          r['key'] as String,
          r['block_offset'] as int,
          r['start_offset'] as int,
          r['end_offset'] as int,
          r['comp_size'] as int,
          (r['segments'] as String?) ?? '[]',
        ],
    ];
  } finally {
    db.dispose();
  }
}

Future<int> _buildSync(String mdxPath, String indexPath) async {
  final src = File(mdxPath);
  if (!src.existsSync()) {
    throw MdxException('MDX file not found.', path: mdxPath);
  }
  final tmpPath = '$indexPath.tmp';
  final tmp = File(tmpPath);
  if (tmp.existsSync()) tmp.deleteSync();
  final parent = File(indexPath).parent;
  if (!parent.existsSync()) parent.createSync(recursive: true);
  final db = sqlite3.open(tmpPath);
  var dbOpen = true;
  PreparedStatement? insert;
  final reader = DictReader(mdxPath);
  try {
    db.execute('PRAGMA journal_mode=OFF');
    db.execute('PRAGMA synchronous=OFF');
    db.execute('PRAGMA temp_store=MEMORY');
    db.execute(
      'CREATE TABLE mdx_index(key TEXT, norm_key TEXT, block_offset INTEGER, start_offset INTEGER, end_offset INTEGER, comp_size INTEGER, segments TEXT)',
    );
    insert = db.prepare(
      'INSERT INTO mdx_index(key, norm_key, block_offset, start_offset, end_offset, comp_size, segments) VALUES (?, ?, ?, ?, ?, ?, ?)',
    );
    try {
      await reader.initDict(readKeys: true, readRecordBlockInfo: true);
    } catch (e) {
      throw MdxException(
        'Cannot parse MDX header: ${describeMdxError(e)}',
        path: mdxPath,
      );
    }
    var count = 0;
    var batch = 0;
    var inTxn = false;
    db.execute('BEGIN');
    inTxn = true;
    try {
      await for (final info in reader.readWithOffset()) {
        final segs = info.segments.isEmpty
            ? [
                [
                  info.recordBlockOffset,
                  info.startOffset,
                  info.endOffset,
                  info.compressedSize,
                ],
              ]
            : [
                for (final s in info.segments.take(
                  MdxIndexService.maxSegmentsPerEntry,
                ))
                  [s.$1, s.$2, s.$3, s.$4],
              ];
        final key = info.keyText;
        final normKey = mdxNorm(key);
        insert.execute([
          key.length > 2048 ? key.substring(0, 2048) : key,
          normKey.length > 2048 ? normKey.substring(0, 2048) : normKey,
          info.recordBlockOffset,
          info.startOffset,
          info.endOffset,
          info.compressedSize,
          jsonEncode(segs),
        ]);
        count++;
        batch++;
        if (batch >= MdxIndexService.batchSize) {
          db.execute('COMMIT');
          inTxn = false;
          db.execute('BEGIN');
          inTxn = true;
          batch = 0;
        }
        if (count % 10000 == 0) await Future.microtask(() => {});
      }
      if (inTxn) {
        db.execute('COMMIT');
        inTxn = false;
      }
    } catch (e) {
      if (inTxn) {
        try {
          db.execute('ROLLBACK');
        } catch (_) {}
        inTxn = false;
      }
      rethrow;
    }
    if (count == 0) {
      throw const MdxException('No entries found in MDX. File may be corrupt.');
    }
    db.execute('CREATE INDEX idx_norm ON mdx_index(norm_key)');
    db.execute('CREATE TABLE meta(k TEXT PRIMARY KEY, v TEXT)');
    db.execute("INSERT INTO meta(k, v) VALUES ('count', '$count')");
    try {
      insert.dispose();
    } catch (_) {}
    insert = null;
    db.dispose();
    dbOpen = false;
    final out = File(indexPath);
    if (out.existsSync()) out.deleteSync();
    File(tmpPath).renameSync(indexPath);
    return count;
  } catch (e) {
    if (tmp.existsSync()) {
      try {
        tmp.deleteSync();
      } catch (_) {}
    }
    if (e is MdxException) rethrow;
    throw MdxException(describeMdxError(e, path: mdxPath), path: mdxPath);
  } finally {
    try {
      insert?.dispose();
    } catch (_) {}
    if (dbOpen) {
      try {
        db.dispose();
      } catch (_) {}
    }
    try {
      await reader.close();
    } catch (_) {}
  }
}
