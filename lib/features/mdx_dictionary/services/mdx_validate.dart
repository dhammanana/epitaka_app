import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'mdx_errors.dart';

class MdxPeek {
  final bool isMdxLike;
  final String detail;
  const MdxPeek(this.isMdxLike, this.detail);
}

Future<MdxPeek> peekMdxHeader(String path) async {
  final file = File(path);
  int length;
  try {
    length = await file.length();
  } catch (e) {
    return MdxPeek(false, describeMdxError(e, path: path));
  }
  if (length < 16) return MdxPeek(false, 'File is only $length bytes.');
  final raf = await file.open();
  try {
    await raf.setPosition(0);
    final sizeBytes = await raf.read(4);
    if (sizeBytes.length < 4) {
      return const MdxPeek(false, 'Cannot read header.');
    }
    var size = 0;
    for (final b in sizeBytes) {
      size = size * 256 + b;
    }
    if (size < 8 || size + 4 > length || size > 256 * 1024) {
      return MdxPeek(
        false,
        'Header size $size invalid for a $length-byte file: not MDX format.',
      );
    }
    await raf.setPosition(4);
    final content = await raf.read(min(size, 8192));
    String text;
    if (content.length >= 2 &&
        content[content.length - 1] == 0 &&
        content[content.length - 2] == 0) {
      final units = <int>[];
      for (var i = 0; i + 1 < content.length; i += 2) {
        units.add(content[i] | (content[i + 1] << 8));
      }
      text = String.fromCharCodes(units);
    } else {
      text = utf8.decode(content, allowMalformed: true);
    }
    if (text.contains('GeneratedByEngineVersion')) {
      return const MdxPeek(true, 'MDX header OK.');
    }
    return const MdxPeek(false, 'No MDX header marker found.');
  } catch (e) {
    return MdxPeek(false, describeMdxError(e, path: path));
  } finally {
    try {
      await raf.close();
    } catch (_) {}
  }
}

Future<void> ensureMdxFileOrExplain(String path) async {
  if (path.trim().toLowerCase().endsWith('.mdx')) return;
  final dot = path.lastIndexOf('.');
  final ext = dot >= 0 ? path.substring(dot + 1).toLowerCase() : '';
  final label = ext.isEmpty ? '(no extension)' : '.$ext';
  if (ext == 'mdd') {
    throw MdxException(
      'This is an .mdd resource file (images/audio). Import the .mdx with the same name instead.',
      path: path,
    );
  }
  if (ext == 'zip' || ext == 'tar' || ext == 'gz' || ext == 'rar') {
    throw MdxException(
      'This is a compressed archive. Unpack it first, then import the .mdx inside.',
      path: path,
    );
  }
  final peek = await peekMdxHeader(path);
  if (peek.isMdxLike) {
    throw MdxException(
      "This looks like an MDX dictionary but is named '$label'. Rename it to end with .mdx and try again.",
      path: path,
    );
  }
  throw MdxException('Not an .mdx file ($label). ${peek.detail}', path: path);
}

class MdxScanResult {
  final List<String> mdxPaths;
  final int filesSeen;
  final Map<String, int> extCounts;
  final int mddCount;
  final List<String> misnamed;
  final List<String> candidates;
  const MdxScanResult({
    required this.mdxPaths,
    required this.filesSeen,
    required this.extCounts,
    required this.mddCount,
    required this.misnamed,
    this.candidates = const [],
  });

  String describe(String dirPath) {
    final top = extCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final seen = top
        .take(8)
        .map(
          (e) =>
              e.key.isEmpty ? "(no ext) x${e.value}" : ".${e.key} x${e.value}",
        )
        .join(", ");
    final buf = StringBuffer('No .mdx found in\n$dirPath');
    buf.write('\nScanned $filesSeen file${filesSeen == 1 ? '' : 's'}');
    if (seen.isNotEmpty) buf.write(' ($seen)');
    buf.write('.');
    if (mddCount > 0) {
      buf.write(
        ' Found $mddCount .mdd resource file${mddCount == 1 ? '' : 's'} but no .mdx: import the .mdx with the same name.',
      );
    }
    if (misnamed.isNotEmpty) {
      buf.write(
        ' ${misnamed.length} file${misnamed.length == 1 ? '' : 's'} look${misnamed.length == 1 ? 's' : ''} like MDX but ${misnamed.length == 1 ? 'is' : 'are'} misnamed: rename to .mdx and retry.',
      );
    }
    return buf.toString();
  }
}
