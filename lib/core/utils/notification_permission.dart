import 'package:flutter/material.dart';

/// Request notification permissions (required for Android 13+ media
/// notifications during TTS playback). On other platforms this is a no-op.
Future<void> requestNotificationPermission(BuildContext context) async {
  // TODO: Android 13+ POST_NOTIFICATIONS permission
  // For now this is a no-op placeholder.
  // On platforms that require it, this should show the system dialog.
}
