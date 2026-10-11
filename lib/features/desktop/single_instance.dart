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

/// True when this process is the first copy. When it is not, the running
/// copy has already been asked to come forward; the caller should quit.
Future<bool> claimSingleInstance(
  Directory dir, {
  required void Function() onAnotherLaunch,
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
    await _nudgeRunningCopy(portFile);
    return false;
  }
  _held.add(lock);

  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  _held.add(server);
  server.listen(
    (socket) {
      socket.destroy();
      onAnotherLaunch();
    },
    onError: (Object e) => developer.log('Single-copy listener failed: $e',
        name: 'epitaka.single_instance'),
  );
  await portFile.writeAsString('${server.port}', flush: true);
  return true;
}

/// A failure here still means another copy holds the lock, so the caller
/// quits either way; the running window just does not come forward.
Future<void> _nudgeRunningCopy(File portFile) async {
  try {
    // Windows lets only the foreground process raise a window. This copy was
    // just launched by the user, so it may pass that right on.
    if (Platform.isWindows) AllowSetForegroundWindow(_anyProcess);
    final port = int.parse((await portFile.readAsString()).trim());
    final socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      port,
      timeout: const Duration(seconds: 2),
    );
    socket.destroy();
  } catch (e) {
    developer.log('Could not reach the running copy: $e',
        name: 'epitaka.single_instance');
  }
}
