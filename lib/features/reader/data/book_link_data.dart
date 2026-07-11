/// Represents a single link from the book_links table.
///
/// The book_links table stores bidirectional word-level links between
/// Pāli texts. For example, a word in a sutta (source) may link to its
/// commentary (destination) — or vice versa.
class BookLinkData {
  /// The word that is linked.
  final String word;

  /// The "other side" of the link — the book that this link points to
  /// (or from, depending on direction).
  final String linkedBookId;
  final int linkedParaId;
  final int linkedLineId;

  /// Whether this paragraph was the source (true) or destination (false).
  final bool isSource;

  const BookLinkData({
    required this.word,
    required this.linkedBookId,
    required this.linkedParaId,
    required this.linkedLineId,
    required this.isSource,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookLinkData &&
          word == other.word &&
          linkedBookId == other.linkedBookId &&
          linkedParaId == other.linkedParaId &&
          linkedLineId == other.linkedLineId &&
          isSource == other.isSource;

  @override
  int get hashCode =>
      Object.hash(word, linkedBookId, linkedParaId, linkedLineId, isSource);
}

/// All book links for a single paragraph, grouped by line ID.
///
/// lineId 1 → [BookLinkData for "evan", BookLinkData for "me", ...]
/// lineId 2 → ...
typedef ParaBookLinks = Map<int, List<BookLinkData>>;

/// All book links for a book, keyed by paragraph ID.
///
/// paraId 6 → { lineId 1: [BookLinkData(...)], lineId 2: [...] }
/// paraId 7 → ...
typedef BookLinksMap = Map<int, ParaBookLinks>;
