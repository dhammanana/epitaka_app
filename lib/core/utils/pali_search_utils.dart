/// Clean Pali text for FTS5 indexing by stripping annotations, removing
/// punctuation, and normalizing whitespace.
String cleanPaliForIndexing(String text) {
  // 1. Strip [...] and all content inside (variant annotations like
  //    "[variant text]" should not contribute any words to the index).
  text = text.replaceAll(RegExp(r'\[[^\]]*\]'), '');

  // 2. Strip (...) that contain at least one digit (page/location
  //    references like "(page 12.3)") but preserve parentheses that
  //    wrap actual text like "(and)" — those will be handled below.
  text = text.replaceAll(RegExp(r'\([^)]*\d+[^)]*\)'), '');

  // 3. Strip HTML tags (e.g. "<b>", "<mark>") that should never become
  //    part of the index or the word-frequency table.
  text = text.replaceAll(RegExp(r'<[^>]*>'), '');

  // 4. Remove any remaining individual bracket characters that survived
  //    the content-stripping regexes (e.g. `(text)` without numbers, or
  //    unmatched brackets).
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
