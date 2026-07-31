/// Character classification for the fuzzy matcher's scoring engine.
///
/// Based on nucleo-matcher's `char_types.rs`.
library;

/// Character classes used to determine boundary bonuses.
enum CharClass {
  /// A path separator character: `/`
  separator,

  /// A word separator: `-`, `_`, ` `, `.`
  wordSep,

  /// A lowercase letter.
  lower,

  /// An uppercase letter (not commonly used in our Pāli paths but
  /// included for completeness).
  upper,

  /// A digit (0–9).
  digit,

  /// Any other character (not classified above).
  other,
}

/// Classify the character at [index] in [text].
///
/// Returns [CharClass.other] if [index] is out of bounds.
CharClass charClass(String text, int index) {
  if (index < 0 || index >= text.length) return CharClass.other;

  final cp = text.codeUnitAt(index);

  switch (cp) {
    // Path separator
    case 0x2F: // '/'
      return CharClass.separator;

    // Word separators
    case 0x2D: // '-'
    case 0x5F: // '_'
    case 0x20: // ' '
    case 0x2E: // '.'
      return CharClass.wordSep;

    default:
      if (cp >= 0x61 && cp <= 0x7A) return CharClass.lower; // a-z
      if (cp >= 0x41 && cp <= 0x5A) return CharClass.upper; // A-Z
      if (cp >= 0x30 && cp <= 0x39) return CharClass.digit; // 0-9
      return CharClass.other;
  }
}
