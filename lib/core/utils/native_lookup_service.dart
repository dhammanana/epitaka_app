// lib/core/utils/native_lookup_service.dart
//
// Wraps the native method channel (`epitaka/native_lookup`) that triggers
// system dictionary lookups on iOS (UIReferenceLibraryViewController) and
// macOS (NSView.showDefinition).

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeLookupService {
  NativeLookupService._();

  static const MethodChannel _channel = MethodChannel('epitaka/native_lookup');

  /// Native device dictionary lookup is supported on iOS and macOS.
  static bool get isSupported =>
      !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  /// Looks up [word] in the device's native system dictionary.
  ///
  /// On iOS, presents [UIReferenceLibraryViewController].
  /// On macOS, displays the native Quick Look dictionary popover at [anchor]
  /// or at the current mouse position.
  ///
  /// Returns `true` if the lookup was handled natively, or `false` if
  /// unsupported / failed.
  static Future<bool> lookUp(String word, {Offset? anchor}) async {
    final text = word.trim();
    if (text.isEmpty || !isSupported) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('lookUp', {
        'text': text,
        if (anchor != null && anchor != Offset.zero) ...{
          'x': anchor.dx,
          'y': anchor.dy,
        },
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}
