import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:win32/win32.dart' show AllowSetForegroundWindow;

// The lock handle and the server live for the whole process: the OS drops
// the lock only when the handle closes or the process ends.
final _held = <Object>[];

/// Windows' ASFW_ANY, which win32 does not export.
const _anyProcess = 0xFFFFFFFF;

/// The codes a lock held by another process gives: EAGAIN (Linux 11,
/// macOS 35), EACCES (13), and Windows' ERROR_LOCK_VIOLATION (33). Any other
/// failure, such as a filesystem without locks, says nothing about another
/// copy, so it must not make this one quit.
const _heldElsewhere = {11, 13, 33, 35};

/// A link line longer than this is refused.
const _maxLinkBytes = 2048;

/// How long the running copy waits for the line after a connection.
const _linkReadLimit = Duration(seconds: 2);

/// The hosts a link from another launch may open. `login-callback` is never
/// among them: that link completes a sign-in, and the loopback port has no
/// password, so any program of the same user can write to it.
const _socketHosts = {'sutta', 'reader', 'search'};

/// A reader link's `#paraId` or `#paraId-lineId` position.
final _position = RegExp(r'^\d+(-\d+)?$');

/// The link a second launch handed over, rebuilt from its safe parts, or null
/// when it must be refused. `sutta` and `search` keep scheme, host and query;
/// `reader` also keeps its first path segment (the book id) and a numeric
/// position fragment (`#123-45`). Anything else, and any link with a
/// `login-callback` host or path segment, gives null.
Uri? acceptedSocketLink(String line) {
  final Uri uri;
  try {
    uri = Uri.parse(line.trim());
  } on FormatException {
    return null;
  }
  if (uri.scheme != 'epitaka' || !_socketHosts.contains(uri.host)) return null;
  if (uri.pathSegments.contains('login-callback')) return null;
  final query = uri.hasQuery && uri.query.isNotEmpty ? uri.query : null;
  return Uri(
    scheme: 'epitaka',
    host: uri.host,
    pathSegments: uri.host == 'reader' && uri.pathSegments.isNotEmpty
        ? [uri.pathSegments.first]
        : null,
    query: query,
    fragment: uri.host == 'reader' && _position.hasMatch(uri.fragment)
        ? uri.fragment
        : null,
  );
}

/// True when this process is the first copy. When it is not, the running
/// copy has already been asked to come forward and given [launchLink]; the
/// caller should quit.
///
/// The running copy calls [onAnotherLaunch] when a second copy connects, and
/// [onLink] for a link that passes [acceptedSocketLink].
Future<bool> claimSingleInstance(
  Directory dir, {
  String? launchLink,
  required void Function() onAnotherLaunch,
  required void Function(Uri) onLink,
}) async {
  await dir.create(recursive: true);
  final portFile = File('${dir.path}/single_instance.port');
  // Append, not write: opening for write truncates, which Windows may refuse
  // on a file another process has locked.
  final lock = await File('${dir.path}/single_instance.lock')
      .open(mode: FileMode.append);
  try {
    await lock.lock(FileLock.exclusive);
  } on FileSystemException catch (e) {
    await lock.close();
    if (!_heldElsewhere.contains(e.osError?.errorCode)) rethrow;
    await _handOverToRunningCopy(portFile, launchLink);
    return false;
  }
  _held.add(lock);

  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  _held.add(server);
  server.listen(
    (socket) {
      onAnotherLaunch();
      unawaited(_receiveLink(socket, onLink));
    },
    onError: (Object e) => developer.log('Single-copy listener failed: $e',
        name: 'epitaka.single_instance'),
  );
  await portFile.writeAsString('${server.port}', flush: true);
  return true;
}

/// Reads one line from [socket] and passes an accepted link to [onLink]. A
/// bare launch, an old second launch, a long line, a partial line and a line
/// that is not an accepted link all leave the window forward and nothing else.
Future<void> _receiveLink(Socket socket, void Function(Uri) onLink) async {
  try {
    final line = await _readLine(socket).timeout(_linkReadLimit);
    if (line == null || line.trim().isEmpty) return;
    final link = acceptedSocketLink(line);
    if (link == null) {
      developer.log('Refused a link from another launch',
          name: 'epitaka.single_instance');
      return;
    }
    developer.log('Link from another launch: $link',
        name: 'epitaka.single_instance');
    onLink(link);
  } on TimeoutException {
    developer.log('No link line from another launch in time',
        name: 'epitaka.single_instance');
  } catch (e) {
    developer.log('Could not read a link from another launch: $e',
        name: 'epitaka.single_instance');
  } finally {
    socket.destroy();
  }
}

/// The text before the first newline, or null when the line is over the size
/// limit or the other side closed without a newline.
Future<String?> _readLine(Socket socket) async {
  final bytes = <int>[];
  await for (final chunk in socket) {
    for (final byte in chunk) {
      if (byte == 0x0A) return utf8.decode(bytes);
      bytes.add(byte);
      if (bytes.length > _maxLinkBytes) return null;
    }
  }
  return null;
}

/// The running copy may not have written its port yet when a second copy
/// starts straight after it, and the file may still hold the port of an
/// earlier run. So the file is read again before each try, and a missing file,
/// an unreadable file and a refused connection are all retried for 2 s.
Future<Socket> _connectToRunningCopy(File portFile) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (true) {
    try {
      final port = int.parse((await portFile.readAsString()).trim());
      return await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(milliseconds: 500),
      );
    } on Exception {
      if (DateTime.now().isAfter(deadline)) rethrow;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

/// A failure here still means another copy holds the lock, so the caller
/// quits either way; the running window just does not come forward.
Future<void> _handOverToRunningCopy(File portFile, String? launchLink) async {
  try {
    // Windows lets only the foreground process raise a window. This copy was
    // just launched by the user, so it may pass that right on.
    if (Platform.isWindows) AllowSetForegroundWindow(_anyProcess);
    final socket = await _connectToRunningCopy(portFile);
    // Written, flushed and closed before this process exits, or the link is
    // lost with it. A bare launch sends an empty line.
    socket.write('${launchLink ?? ''}\n');
    await socket.flush();
    await socket.close();
    socket.destroy();
  } catch (e) {
    developer.log('Could not reach the running copy: $e',
        name: 'epitaka.single_instance');
  }
}
