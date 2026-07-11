import 'pali_script_converter.dart';

/// Returns the best font family name for displaying text in [script].
///
/// Uses the script-specific fonts bundled in `assets/fonts/` when available,
/// falling back to a general-purpose font otherwise.
String scriptFontFamily(Script script) {
  switch (script) {
    case Script.sinhala:
      return 'NotoSansSinhala';
    case Script.devanagari:
      return 'NotoSansDevanagari';
    case Script.roman:
      return 'NotoSerif';
    case Script.taitham:
      return 'NotoSansTaiTham';
    case Script.myanmar:
      return 'Pyidaungsu';
    case Script.laos:
      // Use LaoPaliRegular (not NotoSansLao) because NotoSansLao lacks
      // the Pali-specific Lao characters (e.g. ຆ LAO LETTER PALI GH,
      // ຉ LAO LETTER PALI CH, etc.) which are needed for Pali text.
      return 'LaoPaliRegular';
    case Script.brahmi:
      return 'NotoSansBrahmi';
    case Script.cyrillic:
      return 'DejaVuSans';
    case Script.bengali:
    case Script.gurmukhi:
    case Script.gujarati:
    case Script.telugu:
    case Script.kannada:
    case Script.malayalam:
    case Script.thai:
    case Script.khmer:
    case Script.tibetan:
      // These scripts don't have dedicated fonts in assets/fonts yet.
      // NotoSerif may have limited support; fall back to NotoSerif.
      return 'NotoSerif';
  }
}

/// Converts Roman-script Pāli text (with diacritics) to the target script.
///
/// The database stores Pāli in romanised form (e.g. "ā", "ṭ", "ñ"). When the
/// user chooses a non-Roman script (Sinhala, Thai, Burmese, etc.), this
/// first converts Roman → Sinhala (the internal intermediate format) and
/// then Sinhala → the requested script.
///
/// When [targetScript] is `null` or [Script.roman], the original text is
/// returned unchanged (only beautifyCommon is applied).
String convertPaliToScript(String text, Script? targetScript) {
  if (text.isEmpty) return text;
  if (targetScript == null || targetScript == Script.roman) {
    // For Roman, only apply common beautification (cleanup)
    return TextProcessor.beautify(text, Script.roman);
  }

  // Step 1: Roman → Sinhala (internal intermediate)
  final sinhalaText = TextProcessor.convertFrom(text, Script.roman);

  if (sinhalaText.isEmpty) return text;

  // Step 2: Sinhala → target script
  return TextProcessor.convert(sinhalaText, targetScript);
}

/// Converts a search [query] (in Roman Pali) to [script] so that the
/// converted terms can be matched against Pāli text that was also converted
/// to the same [script].
///
/// Example: searching for "dhamma" in Sinhala script will convert each
/// Roman word to its Sinhala equivalent before highlighting, so "dhamma"
/// matches "ධම්ම" in the converted Pali text.
///
/// When [script] is Roman, the query is returned unchanged.
String convertSearchQueryForScript(String query, Script script) {
  if (query.isEmpty || script == Script.roman) return query;

  // Convert each word individually to preserve word boundaries
  final words = query.split(RegExp(r'\s+'));
  final converted = words.map((w) {
    if (w.trim().isEmpty) return w;
    return convertPaliToScript(w.trim(), script);
  }).join(' ');

  return converted;
}
