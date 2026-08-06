// lib/core/utils/process_text_service.dart
//
// Wraps the Android method channel (`epitaka/process_text`) that queries
// installed apps handling ACTION_PROCESS_TEXT (dictionaries, translators,
// note apps, …) and launches one with the selected text. On non-Android
// platforms the channel is unavailable and both calls return empty/false —
// the feature is Android-only.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One installed app that can process selected text.
class ProcessTextApp {
  final String packageName;
  final String label;

  const ProcessTextApp({required this.packageName, required this.label});

  factory ProcessTextApp.fromMap(Map<dynamic, dynamic> map) {
    return ProcessTextApp(
      packageName: map['packageName'] as String? ?? '',
      label: map['label'] as String? ?? '',
    );
  }
}

class ProcessTextService {
  ProcessTextService._();

  static const MethodChannel _channel = MethodChannel('epitaka/process_text');

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// Queries installed apps that can process selected text.
  /// Returns an empty list on non-Android platforms or on failure.
  static Future<List<ProcessTextApp>> queryApps() async {
    if (!isSupported) return const [];
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'queryProcessTextApps',
      );
      if (raw == null) return const [];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map(ProcessTextApp.fromMap)
          .where((a) => a.packageName.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Launches [app] with [text]. Returns false on failure / unsupported.
  static Future<bool> launch(ProcessTextApp app, String text) async {
    if (!isSupported) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('launchProcessTextApp', {
        'packageName': app.packageName,
        'text': text,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}
