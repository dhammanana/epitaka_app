import 'dart:io';

class MdxException implements Exception {
  final String message;
  final String? path;
  const MdxException(this.message, {this.path});

  @override
  String toString() => path == null ? message : '$message\n$path';
}

class MdxMissingFile extends MdxException {
  const MdxMissingFile(String path)
    : super('MDX file not found. It was moved or deleted.', path: path);
}

class MdxNotReady extends MdxException {
  const MdxNotReady(super.message, {super.path});
}

String describeMdxError(Object e, {String? path}) {
  if (e is MdxException) return e.toString();
  if (e is FileSystemException) {
    final code = e.osError?.errorCode;
    if (code == 28) return 'Disk full while writing index.\n${path ?? e.path}';
    if (code == 13 || code == 1) {
      return 'Permission denied. Move the .mdx out of Downloads/iCloud or grant access.\n${path ?? e.path}';
    }
    return 'File error: ${e.message}\n${path ?? e.path ?? ''}'.trim();
  }
  final s = e.toString();
  if (s.contains('Failed to load dynamic library')) {
    return 'SQLite native library missing (sqlite3_flutter_libs not initialized). Restart the app.';
  }
  if (s.contains('not a database') || s.contains('malformed')) {
    return 'Index is corrupt. Tap Rebuild.\n${path ?? ''}'.trim();
  }
  if (s.contains('@@@LINK') == false && s.length > 300) {
    return s.substring(0, 300);
  }
  return s.replaceFirst('Exception: ', '');
}
