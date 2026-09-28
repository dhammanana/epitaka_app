import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Ensure the Android 13+ `POST_NOTIFICATIONS` runtime permission is granted
/// so the TTS media notification / player can appear in the notification
/// shade. Returns whether notifications are allowed.
///
/// Best-effort and idempotent: when already granted (or on other platforms /
/// older Android, where no runtime permission exists) this returns true
/// without showing anything. When the user has permanently denied it, this
/// returns false without showing a dialog — the caller keeps playing anyway
/// (foreground-service notifications are exempt from the permission on stock
/// Android, but several OEM skins hide the whole player without it).
/// Never throws.
Future<bool> ensureNotificationPermission() async {
  if (!Platform.isAndroid) return true;
  try {
    var status = await Permission.notification.status;
    if (status.isGranted || status.isLimited) return true;
    if (status.isPermanentlyDenied) return false;
    status = await Permission.notification.request();
    return status.isGranted || status.isLimited;
  } catch (_) {
    return false;
  }
}
