import 'package:flutter/material.dart';
import 'pali_script_converter.dart';

/// Velthuis-to-Unicode Pāḷi converter.
///
/// Converts ASCII representations of Pāḷi diacritics into proper Unicode.
/// Also converts text from any supported script (Devanagari, Sinhala, Thai,
/// Myanmar, Khmer, etc.) to Pāli Roman (IAST) before applying the Velthuis
/// conversion, so users typing in any script can search.
///
/// Examples:
/// - `aa` → `ā`, `ii` → `ī`, `uu` → `ū`
/// - `".t"` → `ṭ`, `".d"` → `ḍ`, `".n"` → `ṇ`, `".m"` → `ṃ`, `".l"` → `ḷ`
/// - `"~n"` → `ñ`, `"\"n"` → `ṅ`
/// - `"dhamma.m"` → `"dhammaṃ"`, `"raaga"` → `"rāga"`
/// - `धम्म` (Devanagari) → `"dhamma"`
/// - `ධම්ම` (Sinhala) → `"dhamma"`
/// - `ธรรม` (Thai) → `"dhamma"`
/// - `ធម្ម` (Khmer) → `"dhamma"`
/// - Already-correct IAST text passes through unchanged.
String velthuis(String input) {
  if (input.isEmpty) return input;

  // Phase 1: Convert any non-Roman script to Roman via the Sinhala pivot.
  // TextProcessor.convertFromMixed converts mixed-script text to Sinhala,
  // then TextProcessor.convert converts Sinhala to the target script (Roman).
  if (isNonLatinScript(input)) {
    try {
      input = TextProcessor.convert(
        TextProcessor.convertFromMixed(input),
        Script.roman,
      );
    } catch (_) {
      // If conversion fails, continue with the original input.
    }
  }

  // Phase 2: Velthuis diacritic conversion
  input = input
      // Long vowels (lowercase)
      .replaceAll('aa', 'ā')
      .replaceAll('ii', 'ī')
      .replaceAll('uu', 'ū')
      // Velar nasal
      .replaceAll('"n', 'ṅ')
      // Palatal nasal
      .replaceAll('~n', 'ñ')
      // Retroflex / dental specials (dot notation)
      .replaceAll('.t', 'ṭ')
      .replaceAll('.d', 'ḍ')
      .replaceAll('.n', 'ṇ')
      .replaceAll('.m', 'ṃ')
      .replaceAll('.l', 'ḷ')
      .replaceAll('.h', 'ḥ')
      // Uppercase long vowels
      .replaceAll('AA', 'Ā')
      .replaceAll('II', 'Ī')
      .replaceAll('UU', 'Ū')
      // Uppercase consonants
      .replaceAll('"N', 'Ṅ')
      .replaceAll('~N', 'Ñ')
      .replaceAll('.T', 'Ṭ')
      .replaceAll('.D', 'Ḍ')
      .replaceAll('.N', 'Ṇ')
      .replaceAll('.M', 'Ṃ')
      .replaceAll('.L', 'Ḷ');

  return input;
}

/// Converts [value] with velthuis() while keeping the cursor in a sensible
/// place, instead of always snapping it to the end of the text.
///
/// Also applies script-to-Roman conversion, so typing in another script
/// yields correct IAST while preserving the cursor position.
TextEditingValue convertedTextEditingValue(TextEditingValue value) {
  final oldOffset = value.selection.baseOffset < 0
      ? value.text.length
      : value.selection.baseOffset;

  final converted = velthuis(value.text);

  final beforeCursor = value.text.substring(
    0,
    oldOffset.clamp(0, value.text.length),
  );
  final newOffset = velthuis(beforeCursor).length.clamp(0, converted.length);

  return TextEditingValue(
    text: converted,
    selection: TextSelection.collapsed(offset: newOffset),
  );
}
