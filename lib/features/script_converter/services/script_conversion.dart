// lib/features/script_converter/services/script_conversion.dart
//
// Conversion helpers for the Script Converter screen. The app's canonical
// script pipeline pivots every script through Sinhala (the internal
// intermediate), so converting between ANY two scripts is:
//
//     input (any script) ──convertFromMixed──▶ Sinhala ──convert──▶ target
//
// The same path powers `velthuis()`, `convertToRomanPali()`, dictionary
// lookups and search, so results here match every other surface.

import '../../../core/utils/pali_script_converter.dart';

/// Convert Pāli [text] written in ANY script (or mixed scripts) into
/// [target]. Falls back to the original text if conversion fails so the
/// UI never crashes on unusual input.
String convertPaliAnyScript(String text, Script target) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return '';
  // Roman → Roman: pass through unchanged. Round-tripping through the
  // Sinhala pivot would lowercase the text (unCapitalize) — right for app
  // storage, but surprising in a converter tool where users type proper
  // casing.
  if (target == Script.roman && !isNonLatinScript(trimmed)) return trimmed;
  try {
    final sinhala = TextProcessor.convertFromMixed(trimmed);
    return TextProcessor.convert(sinhala, target);
  } catch (_) {
    return text;
  }
}

/// Best-effort detection of the dominant script in [text], for the UI's
/// "detected" badge. Returns null for empty input. Whitespace is ignored;
/// characters not matching any non-Roman script (ASCII/IAST) count as
/// [Script.roman].
///
/// Counts are per code unit, not per character: Brahmi (U+11000+, outside
/// the BMP) is a surrogate pair and contributes two units — both fall in
/// Brahmi's declared ranges, so every Brahmi char inflates equally and
/// majority voting still works.
Script? detectDominantScript(String text) {
  if (text.trim().isEmpty) return null;
  final counts = <Script, int>{};
  for (final unit in text.codeUnits) {
    // Skip whitespace (0x20 would otherwise inflate the Roman count for
    // any mixed-script sentence).
    if (unit == 0x20 || unit == 0x09 || unit == 0x0A || unit == 0x0D) {
      continue;
    }
    Script? found;
    for (final info in listOfScripts) {
      if (info.script == Script.roman) continue;
      for (final r in info.codePointRanges) {
        if (unit >= r.start && unit <= r.end) {
          found = info.script;
          break;
        }
      }
      if (found != null) break;
    }
    counts[found ?? Script.roman] = (counts[found ?? Script.roman] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;
  MapEntry<Script, int>? best;
  counts.forEach((script, count) {
    if (best == null || count > best!.value) best = MapEntry(script, count);
  });
  return best!.key;
}
