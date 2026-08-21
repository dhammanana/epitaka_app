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

  // Phase 1: Convert any non-Roman script to Roman (IAST).
  input = convertToRomanPali(input);

  // Phase 2: Velthuis diacritic conversion
  return _velthuisDiacritics(input);
}

/// Applies only the Velthuis diacritic pass of [velthuis] (Phase 2):
/// ASCII notation like `aa` → `ā` or `dhamma.m` → `dhammaṃ` becomes
/// proper Unicode diacritics.
///
/// Unlike [velthuis], it does **not** convert non-Latin scripts to Roman.
/// Use this when updating the *displayed* text of an input field, so a user
/// typing in Myanmar (or any other Pāli script) keeps seeing their own script
/// on screen; use [velthuis] when the text is actually searched.
String velthuisDiacritics(String input) {
  if (input.isEmpty) return input;
  return _velthuisDiacritics(input);
}

String _velthuisDiacritics(String input) => input
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

/// Converts [value] for display in an input field while keeping the cursor in
/// a sensible place, instead of always snapping it to the end of the text.
///
/// Only the Velthuis diacritic pass ([velthuisDiacritics]) is applied, so the
/// field keeps whatever script the user typed (e.g. Myanmar) — script-to-Roman
/// conversion happens solely behind the scenes when the text is searched via
/// [velthuis]. Velthuis ASCII notation (`dhamma.m` → `dhammaṃ`) still renders
/// as Unicode diacritics in the field.
TextEditingValue convertedTextEditingValue(TextEditingValue value) {
  final oldOffset = value.selection.baseOffset < 0
      ? value.text.length
      : value.selection.baseOffset;

  final converted = velthuisDiacritics(value.text);

  final beforeCursor = value.text.substring(
    0,
    oldOffset.clamp(0, value.text.length),
  );
  final newOffset = velthuisDiacritics(
    beforeCursor,
  ).length.clamp(0, converted.length);

  return TextEditingValue(
    text: converted,
    selection: TextSelection.collapsed(offset: newOffset),
  );
}
