final _bracketAnnotation = RegExp(r'\[[^\]]*\]');
final _parenPageRef = RegExp(r'\([^)]*\d+[^)]*\)');
final _bracketReference = RegExp(r'\[[^\]]*\d[^\]]*\]');
final _htmlTag = RegExp(r'<[^>]*>');
final _whitespaceRun = RegExp(r'\s+');

String foldPaliDiacritics(String text) {
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
      .replaceAll('ṁ', 'm');
}

/// Clean Pali text for FTS5 indexing by stripping annotations, removing
/// punctuation, and normalizing whitespace.
///
/// By default the *content* of bracketed variant annotations
/// (`"[variant text]"`) is KEPT — only the bracket characters are
/// removed — so variant-only words are searchable (global FTS index,
/// query normalization, word frequency). Pass [stripVariantContent] to
/// remove the whole span, for search paths that must match only the main
/// text (in-book search while variant readings are hidden).
String cleanPaliForIndexing(String text, {bool stripVariantContent = false}) {
  // 1. Variant annotations like "[variant text]". In strip mode the whole
  //    span goes; by default the content stays and step 4 below drops only
  //    the bracket characters.
  if (stripVariantContent) {
    text = text.replaceAll(_bracketAnnotation, '');
  } else {
    // Reference-style brackets ("[ka.517; rū.488]", "[udā.27]") are
    // manuscript/page citations, not variant readings — drop them so they
    // never become index tokens. Genuine readings contain no digits.
    text = text.replaceAll(_bracketReference, ' ');
  }

  // 2. Strip (...) that contain at least one digit (page/location
  //    references like "(page 12.3)") but preserve parentheses that
  //    wrap actual text like "(and)" — those will be handled below.
  text = text.replaceAll(_parenPageRef, '');

  // 3. Strip HTML tags (e.g. "<b>", "<mark>") that should never become
  //    part of the index or the word-frequency table.
  text = text.replaceAll(_htmlTag, '');

  // 4. Remove any remaining individual bracket characters that survived
  //    the content-stripping regexes (e.g. `(text)` without numbers, or
  //    unmatched brackets). In keep mode the brackets become SPACES so the
  //    bracketed reading stays a separate token rather than fusing with a
  //    neighbouring word.
  final cleaned = text
      .replaceAll('[', stripVariantContent ? '' : ' ')
      .replaceAll(']', stripVariantContent ? '' : ' ')
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
  return cleaned.replaceAll(_whitespaceRun, ' ').trim();
}

/// Normalize a Pali string for fuzzy matching by replacing diacritics with
/// their base ASCII equivalents (e.g. ā→a, ṃ→m), stripping the same
/// punctuation/annotations as [cleanPaliForIndexing], and lowercasing.
///
/// Kept in sync with [cleanPaliForIndexing] so that a query pasted from a
/// book (which may contain commas, dashes, quotes, brackets, page refs,
/// HTML tags …) normalizes to the same words that were indexed — otherwise
/// FTS5 MATCH syntax errors (on `,` `'` etc.) or plain mismatches would
/// silently produce zero results.
String normalizePaliFuzzy(String text) {
  return cleanPaliForIndexing(text)
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
      // FTS5 operator characters that would otherwise break a MATCH query.
      .replaceAll('*', '')
      .replaceAll('^', '')
      .replaceAll('~', '')
      .replaceAll(_whitespaceRun, ' ')
      .trim();
}

final _incomingUrl = RegExp(r'https?://\S+', caseSensitive: false);
final _incomingApostrophe = RegExp('[\'‘’ʼ]');
final _incomingHyphen = RegExp('[-‐‑­]');
final _incomingNonWord = RegExp(r'[^\p{L}\p{M}\p{N}\s]', unicode: true);

/// Clean text that arrives from outside the app (share sheet, text-selection
/// menu, search links) before it fills the search box.
///
/// Text selected in another Pāḷi app often carries a stray `'`, `-`, quotes
/// or punctuation, and a browser share can add the page URL. Only letters
/// (any script), combining marks, digits and spaces are kept. Apostrophes are
/// deleted, as [cleanPaliForIndexing] does. Hyphens are deleted too, so
/// `dhamma-vinayaṃ` becomes `dhammavinayaṃ`: other sources hyphenate compounds
/// for reading, but the canon writes them joined. Other characters become
/// spaces.
String cleanIncomingSearchText(String text) {
  return text
      .replaceAll(_incomingUrl, ' ')
      .replaceAll(_incomingApostrophe, '')
      .replaceAll(_incomingHyphen, '')
      .replaceAll(_incomingNonWord, ' ')
      .replaceAll(_whitespaceRun, ' ')
      .trim();
}
