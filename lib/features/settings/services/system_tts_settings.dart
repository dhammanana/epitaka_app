import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/app_localizations.dart';

/// Opens the platform's Text-to-speech settings so the user can install
/// TTS voices (e.g. Sinhala or Hindi for Pāli reading).
///
/// - Android: launches the official TTS settings screen
///   (`Settings.ACTION_TTS_SETTINGS`) through a small native channel.
///   url_launcher can't do this — it only launches `ACTION_VIEW` intents,
///   so an `intent:` URI is treated as a VIEW of that literal string and
///   fails with "No Activity found".
/// - Other platforms (iOS, desktop, web): there is no public deep link
///   into TTS voice management (iOS voices live under Settings →
///   Accessibility → Spoken Content, which apps cannot deep-link to), so
///   we show a hint instead.
Future<void> openSystemTtsSettings(BuildContext context) async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      const channel = MethodChannel('epitaka/tts_settings');
      final ok = await channel.invokeMethod<bool>('openTtsSettings');
      if (ok == true) return;
    } catch (_) {
      // Fall through to the hint (e.g. an OEM without the TTS settings
      // activity).
    }
  }
  if (context.mounted) _showHint(context);
}

void _showHint(BuildContext context) {
  final loc = AppLocalizations.of(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(loc.ttsInstallVoiceHint)),
  );
}
