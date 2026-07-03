/// What to include when copying reading content to clipboard.
enum CopyScope { pali, translation, both }

/// Whether to append a citation/quote line to copied content.
enum CopyQuoteFormat {
  /// No citation appended.
  none,

  /// e.g. "— from DN 1"
  bookId,

  /// e.g. "— from Brahmajāla Sutta"
  bookName,

  /// e.g. "— from DN 1 (Brahmajāla Sutta), VRI p. 12"
  full,
}
