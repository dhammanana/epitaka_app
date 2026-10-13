/// Strips diacritical marks, aspirate markers, and double consonants to plain
/// ASCII for fuzzy search matching.
///
/// Uses a direct rune map rather than NFD normalization — faster and correct
/// for the character sets that actually occur in the database. Pipeline:
/// 1. Strip diacritics (ṭ→t, ā→a, ś→s, etc.)
/// 2. Strip 'h' after stop consonants (kh→k, gh→g, etc.)
/// 3. Collapse repeated consonants (tt→t, cc→c, etc.)
///
/// **This must stay byte-identical to `_strip_diacritics_mobile` in the
/// exporter** (`dpd-db/exporter/mobile/mobile_exporter.py`), which generates the
/// stored `word_fuzzy` and `fuzzy_key` columns by dropping every Unicode
/// combining mark. Any character this map omits produces a key that matches
/// nothing in the database. The Sanskrit set (ś, ṣ, ṛ) was missed originally,
/// silently breaking lookups for 12% of dictionary entries.
String stripDiacritics(String text) {
  final clean = text.replaceAll('√', '').replaceAll(' ', '');
  final buffer = StringBuffer();
  for (final rune in clean.runes) {
    final mapped = _diacriticMap[rune];
    if (mapped != null) {
      buffer.write(mapped);
    } else if (_isCombiningMark(rune)) {
      continue;
    } else {
      buffer.write(String.fromCharCode(rune));
    }
  }
  return buffer
      .toString()
      .replaceAllMapped(_aspiratePattern, (m) => m.group(1)!)
      .replaceAllMapped(_doubleConsonantPattern, (m) => m.group(1)!);
}

/// Catches decomposed input, which the precomposed map cannot cover.
bool _isCombiningMark(int rune) =>
    (rune >= 0x0300 && rune <= 0x036F) ||
    (rune >= 0x1AB0 && rune <= 0x1AFF) ||
    (rune >= 0x20D0 && rune <= 0x20F0);

final _aspiratePattern = RegExp(r'([kgcjtdpb])h', caseSensitive: false);
final _doubleConsonantPattern = RegExp(r'([bcdfghjklmnpqrstvwxyz])\1', caseSensitive: false);

const _diacriticMap = <int, String>{
  0x0101: 'a', // ā
  0x012B: 'i', // ī
  0x016B: 'u', // ū
  0x1E45: 'n', // ṅ
  0x00F1: 'n', // ñ
  0x1E6D: 't', // ṭ
  0x1E0D: 'd', // ḍ
  0x1E47: 'n', // ṇ
  0x1E41: 'm', // ṁ
  0x1E43: 'm', // ṃ
  0x1E37: 'l', // ḷ
  0x1E3B: 'l', // ḻ
  0x1E25: 'h', // ḥ
  // Uppercase variants
  0x0100: 'A', // Ā
  0x012A: 'I', // Ī
  0x016A: 'U', // Ū
  0x1E44: 'N', // Ṅ
  0x00D1: 'N', // Ñ
  0x1E6C: 'T', // Ṭ
  0x1E0C: 'D', // Ḍ
  0x1E46: 'N', // Ṇ
  0x1E40: 'M', // Ṁ
  0x1E42: 'M', // Ṃ
  0x1E36: 'L', // Ḷ
  0x1E24: 'H', // Ḥ
  // Sanskrit — needed by Monier-Williams, Apte and BHS
  0x015B: 's', // ś
  0x015A: 'S', // Ś
  0x1E63: 's', // ṣ
  0x1E62: 'S', // Ṣ
  0x1E5B: 'r', // ṛ
  0x1E5A: 'R', // Ṛ
  0x1E5D: 'r', // ṝ
  0x1E5C: 'R', // Ṝ
  0x1E39: 'l', // ḹ
  0x1E38: 'L', // Ḹ
  // Stray European diacritics in transliterated source data
  0x00E7: 'c', // ç
  0x00C7: 'C', // Ç
  0x00E2: 'a', // â
  0x00F2: 'o', // ò
  0x00F4: 'o', // ô
  0x00F6: 'o', // ö
  0x00FB: 'u', // û
  0x00FC: 'u', // ü
  0x0148: 'n', // ň
  0x0129: 'i', // ĩ
  0x2260: '=', // ≠ decomposes to '=' plus a combining solidus
  // Myanmar combining signs, outside the Latin combining ranges
  0x1032: '', // ဲ
  0x1037: '', // ့
  0x1039: '', // ္
};
