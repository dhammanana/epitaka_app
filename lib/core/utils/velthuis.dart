/// Velthuis-to-Unicode Pāḷi converter.
///
/// Converts ASCII representations of Pāḷi diacritics into proper Unicode.
///
/// Examples:
/// - `aa` → `ā`, `ii` → `ī`, `uu` → `ū`
/// - `".t"` → `ṭ`, `".d"` → `ḍ`, `".n"` → `ṇ`, `".m"` → `ṃ`, `".l"` → `ḷ`
/// - `"~n"` → `ñ`, `"\"n"` → `ṅ`
/// - `"dhamma.m"` → `"dhammaṃ"`, `"raaga"` → `"rāga"`
/// - Already-correct IAST text passes through unchanged.
String velthuis(String input) {
  if (input.isEmpty) return input;

  return input
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
}
