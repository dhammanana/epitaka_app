/// Represents a book in the Tipitaka.
class BookInfo {
  final int id;
  final int? refId;
  final String? vriId;
  final String bookId;
  final String? category;
  final String? nikaya;
  final String? subNikaya;
  final String? bookName;
  final String? description;
  final String? mulaRef;
  final String? atthaRef;
  final String? tikaRef;
  final int? paraId;
  final int? chapterLen;

  const BookInfo({
    required this.id,
    this.refId,
    this.vriId,
    required this.bookId,
    this.category,
    this.nikaya,
    this.subNikaya,
    this.bookName,
    this.description,
    this.mulaRef,
    this.atthaRef,
    this.tikaRef,
    this.paraId,
    this.chapterLen,
  });

  /// Get the display name for the book.
  String get displayName => bookName ?? bookId;
}

/// Represents a heading (TOC entry) within a book.
class HeadingInfo {
  final String bookId;
  final int paraId;
  final int? level;
  final String? title;
  final int? chapterLen;
  final int? parent;
  final String? scId;

  const HeadingInfo({
    required this.bookId,
    required this.paraId,
    this.level,
    this.title,
    this.chapterLen,
    this.parent,
    this.scId,
  });
}

/// Represents a single Pāli sentence with its line number.
class SentenceInfo {
  final String bookId;
  final int paraId;
  final int lineId;
  final String? pali;

  const SentenceInfo({
    required this.bookId,
    required this.paraId,
    required this.lineId,
    this.pali,
  });
}

/// Represents a translation sentence from a language database.
class TranslationInfo {
  final String bookId;
  final int paraId;
  final int lineId;
  final String? paliSentence;
  final String? translation;
  final String? translationConfidence;
  final String? confidenceNote;

  const TranslationInfo({
    required this.bookId,
    required this.paraId,
    required this.lineId,
    this.paliSentence,
    this.translation,
    this.translationConfidence,
    this.confidenceNote,
  });
}

/// Supported translation languages.
enum TranslationLanguage {
  thai('th', 'ไทย', 'Thai'),
  sinhala('si', 'සිංහල', 'Sinhala'),
  myanmar('my', 'မြန်မာ', 'Myanmar'),
  english('en', 'English', 'English');

  final String code;
  final String nativeName;
  final String englishName;

  const TranslationLanguage(this.code, this.nativeName, this.englishName);

  String get filename => 'epitaka_$code.db';

  static TranslationLanguage fromCode(String code) {
    return TranslationLanguage.values.firstWhere(
      (l) => l.code == code,
      orElse: () => english,
    );
  }
}
