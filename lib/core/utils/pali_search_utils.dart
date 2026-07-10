/// Clean Pali text for FTS5 indexing by removing punctuation and normalizing whitespace.
String cleanPaliForIndexing(String text) {
  // Remove punctuation marks common in Pali texts
  final cleaned = text
      .replaceAll('[', '')
      .replaceAll(']', '')
      .replaceAll('(', '')
      .replaceAll(')', '')
      .replaceAll('{', '')
      .replaceAll('}', '')
      .replaceAll('\u27e8', '')
      .replaceAll('\u27e9', '')
      .replaceAll(':', '')
      .replaceAll(';', '')
      .replaceAll('.', '')
      .replaceAll(',', '')
      .replaceAll('!', '')
      .replaceAll('?', '')
      .replaceAll('\u2026', '')
      .replaceAll('\u2014', '')
      .replaceAll('\u2013', '')
      .replaceAll('-', ' ')
      .replaceAll('"', '')
      .replaceAll('\u00ab', '')
      .replaceAll('\u00bb', '')
      .replaceAll('\u201c', '')
      .replaceAll('\u201d', '')
      .replaceAll("'", '')
      .replaceAll('\u2018', '')
      .replaceAll('\u2019', '');
  return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Normalize a Pali string for fuzzy matching by replacing diacritics with
/// their base ASCII equivalents (e.g. ā→a, ṃ→m) and lowercasing.
String normalizePaliFuzzy(String text) {
  return text
      .toLowerCase()
      .replaceAll('ā', 'a')
      .replaceAll('ī', 'i')
      .replaceAll('ū', 'u')
      .replaceAll('ō', 'o')
      .replaceAll('ṅ', 'n')
      .replaceAll('ñ', 'n')
      .replaceAll('ṭ', 't')
      .replaceAll('ḍ', 'd')
      .replaceAll('ṇ', 'n')
      .replaceAll('ḷ', 'l')
      .replaceAll('ṃ', 'm')
      .replaceAll('ṁ', 'm')
      .replaceAll('[', '')
      .replaceAll(']', '')
      .replaceAll('(', '')
      .replaceAll(')', '')
      .replaceAll(':', '')
      .replaceAll(';', '')
      .replaceAll('.', '')
      .replaceAll(',', '')
      .replaceAll('"', '')
      .replaceAll("'", '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
