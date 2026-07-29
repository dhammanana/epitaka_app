/// Language detection and display utilities for the AI Assistant.
///
/// Detects the language of user input based on Unicode character ranges,
/// so the AI can translate and answer in the appropriate language.
library;

/// Supported languages for the AI Assistant.
enum DetectedLanguage {
  /// English (default)
  english('en', 'English'),

  /// Burmese / Myanmar
  burmese('my', 'မြန်မာ'),

  /// Thai
  thai('th', 'ไทย'),

  /// Lao
  lao('lo', 'ລາວ'),

  /// Sinhala
  sinhala('si', 'සිංහල'),

  /// Khmer
  khmer('km', 'ខ្មែរ'),

  /// Hindi / Sanskrit / Marathi etc. (Devanagari script)
  devanagari('hi', 'हिन्दी'),

  /// Vietnamese (Latin with diacritics, detected via keyword analysis)
  vietnamese('vi', 'Tiếng Việt');

  /// ISO 639-1 language code.
  final String code;

  /// Native name of the language for display.
  final String nativeName;

  const DetectedLanguage(this.code, this.nativeName);

  /// Whether this language is a non-English script that needs translation.
  bool get needsTranslation => this != english && this != vietnamese;
}

/// Detect the language of a text string based on Unicode character ranges.
///
/// Checks the first 500 non-whitespace characters for dominant script.
/// Falls back to English if no non-Latin script is detected.
DetectedLanguage detectLanguage(String text) {
  if (text.trim().isEmpty) return DetectedLanguage.english;

  final scriptCounts = <DetectedLanguage, int>{};

  // Analyze characters
  for (final char in text.runes) {
    final lang = _charToLanguage(char);
    if (lang != null) {
      scriptCounts[lang] = (scriptCounts[lang] ?? 0) + 1;
    }
  }

  // If no non-Latin characters found, check for Vietnamese diacritics
  if (scriptCounts.isEmpty) {
    if (_isVietnamese(text)) return DetectedLanguage.vietnamese;
    return DetectedLanguage.english;
  }

  // Return the language with the most characters
  return scriptCounts.entries
      .reduce((a, b) => a.value > b.value ? a : b)
      .key;
}

/// Map a Unicode code point to a [DetectedLanguage] based on script range.
DetectedLanguage? _charToLanguage(int codePoint) {
  // Burmese: U+1000–U+109F
  if (codePoint >= 0x1000 && codePoint <= 0x109F) {
    return DetectedLanguage.burmese;
  }
  // Thai: U+0E00–U+0E7F
  if (codePoint >= 0x0E00 && codePoint <= 0x0E7F) {
    return DetectedLanguage.thai;
  }
  // Lao: U+0E80–U+0EFF
  if (codePoint >= 0x0E80 && codePoint <= 0x0EFF) {
    return DetectedLanguage.lao;
  }
  // Sinhala: U+0D80–U+0DFF
  if (codePoint >= 0x0D80 && codePoint <= 0x0DFF) {
    return DetectedLanguage.sinhala;
  }
  // Khmer: U+1780–U+17FF
  if (codePoint >= 0x1780 && codePoint <= 0x17FF) {
    return DetectedLanguage.khmer;
  }
  // Devanagari: U+0900–U+097F
  if (codePoint >= 0x0900 && codePoint <= 0x097F) {
    return DetectedLanguage.devanagari;
  }
  return null;
}

// Vietnamese diacritic characters commonly used.
const _vietnameseChars = <int>{
  // Lowercase
  0x00E0, // à
  0x00E1, // á
  0x00E2, // â
  0x00E3, // ã
  0x00E8, // è
  0x00E9, // é
  0x00EA, // ê
  0x00EC, // ì
  0x00ED, // í
  0x00F2, // ò
  0x00F3, // ó
  0x00F4, // ô
  0x00F5, // õ
  0x00F9, // ù
  0x00FA, // ú
  0x00FD, // ý
  0x0103, // ă
  0x0111, // đ
  0x0129, // ĩ
  0x0169, // ũ
  0x01A1, // ơ
  0x01B0, // ư
  // Uppercase
  0x00C0, // À
  0x00C1, // Á
  0x00C2, // Â
  0x00C3, // Ã
  0x00C8, // È
  0x00C9, // É
  0x00CA, // Ê
  0x00CC, // Ì
  0x00CD, // Í
  0x00D2, // Ò
  0x00D3, // Ó
  0x00D4, // Ô
  0x00D5, // Õ
  0x00D9, // Ù
  0x00DA, // Ú
  0x00DD, // Ý
  0x0102, // Ă
  0x0110, // Đ
  0x0128, // Ĩ
  0x0168, // Ũ
  0x01A0, // Ơ
  0x01AF, // Ư
};

/// Check if text is likely Vietnamese by looking for Vietnamese-specific
/// diacritic characters.
bool _isVietnamese(String text) {
  int vietnameseCount = 0;
  for (final char in text.runes) {
    if (_vietnameseChars.contains(char)) {
      vietnameseCount++;
    }
  }
  // If at least 3 Vietnamese characters found, it's likely Vietnamese
  return vietnameseCount >= 3;
}
