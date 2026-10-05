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
      // errno 1 (EPERM, "Operation not permitted") is what the macOS App
      // sandbox returns when the app reopens a user-picked file outside its
      // container after the picker grant expired (restart, background
      // isolate). errno 13 (EACCES) is the classic Unix permission denial.
      if (Platform.isMacOS) {
        return 'macOS blocked access to this file (sandbox, errno $code). '
            'Remove the dictionary and re-add it so the app can keep a '
            'private copy, or move the .mdx into the appʼs storage.\n'
            '${path ?? e.path}';
      }
      return 'Permission denied. Move the .mdx out of Downloads/iCloud or grant access.\n${path ?? e.path}';
    }
    return 'File error: ${e.message}\n${path ?? e.path ?? ''}'.trim();
  }
  final s = e.toString();
  // Dart wraps sandbox denials as PathAccessException without a
  // FileSystemException type when thrown from RandomAccessFile paths —
  // match the text so those get the actionable hint too.
  if (s.contains('Operation not permitted') ||
      s.contains('PathAccessException')) {
    if (Platform.isMacOS) {
      return 'macOS blocked access to this file (sandbox). '
          'Remove the dictionary and re-add it so the app can keep a '
          'private copy.\n${path ?? ''}'.trim();
    }
    return 'Permission denied. Move the .mdx out of Downloads/iCloud or grant access.\n${path ?? ''}'
        .trim();
  }
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
