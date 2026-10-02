// lib/core/models/shortcut_override.dart
//
// A user's own key combination for a keyboard shortcut, as stored in
// SharedPreferences (Settings → Keyboard Shortcuts).
//
// Only the shortcuts the user changed are stored, so a later app version
// can still change the defaults of the others.

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// `{"key": keyId, "control": …, "shift": …, "alt": …, "meta": …}` for one
/// combination, where `keyId` is [LogicalKeyboardKey.keyId].
Map<String, Object> encodeActivator(SingleActivator activator) => {
  'key': activator.trigger.keyId,
  'control': activator.control,
  'shift': activator.shift,
  'alt': activator.alt,
  'meta': activator.meta,
};

/// The combination stored by [encodeActivator], or null when [json] is not
/// one or names a key this Flutter version does not know.
SingleActivator? decodeActivator(Object? json) {
  if (json is! Map) return null;
  final keyId = json['key'];
  if (keyId is! int) return null;
  // Keys typed as characters outside Flutter's table (e.g. ā on a Pāḷi
  // layout) have their Unicode code point as id and still match by id.
  final key =
      LogicalKeyboardKey.findKeyByKeyId(keyId) ??
      (keyId >= 0 && keyId <= 0x10FFFF ? LogicalKeyboardKey(keyId) : null);
  if (key == null) return null;
  return SingleActivator(
    key,
    control: json['control'] == true,
    shift: json['shift'] == true,
    alt: json['alt'] == true,
    meta: json['meta'] == true,
  );
}

/// The whole saved map, shortcut id → combination, as one JSON string. A
/// null combination (the shortcut was given to another action) is `null`.
String encodeOverrides(Map<String, SingleActivator?> overrides) => jsonEncode({
  for (final MapEntry(:key, :value) in overrides.entries)
    key: value == null ? null : encodeActivator(value),
});

/// The map stored by [encodeOverrides]. Bad data gives an empty map or drops
/// the bad entries, so a corrupt preference never blocks start-up.
Map<String, SingleActivator?> decodeOverrides(String? raw) {
  if (raw == null || raw.isEmpty) return {};
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return {};
  }
  if (decoded is! Map) return {};
  final result = <String, SingleActivator?>{};
  for (final entry in decoded.entries) {
    final id = entry.key;
    if (id is! String) continue;
    if (entry.value == null) {
      result[id] = null;
      continue;
    }
    final activator = decodeActivator(entry.value);
    if (activator != null) result[id] = activator;
  }
  return result;
}
