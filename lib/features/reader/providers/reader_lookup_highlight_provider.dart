import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/reader_word_hit_test.dart';

/// Represents an active dictionary lookup highlight on a tapped word in the reader.
class ReaderLookupHighlight {
  /// Book ID containing the highlighted word.
  final String bookId;

  /// Paragraph ID containing the highlighted word, if known.
  final int? paraId;

  /// Line ID containing the highlighted word (-1 for heading, null for joined text).
  final int? lineId;

  /// Segment type ('pali' or 'translation').
  final String segment;

  /// Language code for translations.
  final String? langCode;

  /// Cleaned Roman word for dictionary lookup (e.g. "bhagavato").
  final String word;

  /// Raw word in the display script as tapped (e.g. "ဘဂဝတော").
  final String rawWord;

  /// Character range within the line or paragraph text.
  final TextRange? range;

  const ReaderLookupHighlight({
    required this.bookId,
    this.paraId,
    this.lineId,
    this.segment = 'pali',
    this.langCode,
    required this.word,
    required this.rawWord,
    this.range,
  });

  /// Factory from a [ReaderWordHitResult].
  factory ReaderLookupHighlight.fromHit({
    required String bookId,
    required ReaderWordHitResult hit,
  }) {
    return ReaderLookupHighlight(
      bookId: bookId,
      paraId: hit.paraId,
      lineId: hit.lineId,
      segment: hit.segment,
      langCode: hit.langCode,
      word: hit.word,
      rawWord: hit.rawWord,
      range: hit.range,
    );
  }

  /// Whether this highlight applies to the given paragraph and line.
  bool matches({
    required int paraId,
    int? lineId,
    required String segment,
    String? langCode,
  }) {
    if (this.paraId != null && this.paraId != paraId) return false;
    if (this.segment != segment) return false;
    if (segment == 'translation' && this.langCode != langCode) return false;
    // When lineId is specified in both this highlight and the target line, they must match.
    if (this.lineId != null && lineId != null && this.lineId != lineId) {
      return false;
    }
    return true;
  }
}

/// Manages the state of the active dictionary lookup highlight.
class ReaderLookupHighlightNotifier
    extends StateNotifier<ReaderLookupHighlight?> {
  ReaderLookupHighlightNotifier() : super(null);

  /// Set the active lookup highlight.
  void setHighlight(ReaderLookupHighlight highlight) {
    state = highlight;
  }

  /// Clear the active lookup highlight.
  void clear() {
    state = null;
  }

  /// Clear the highlight if it belongs to [bookId].
  void clearForBook(String bookId) {
    if (state?.bookId == bookId) {
      state = null;
    }
  }
}

/// Provider for the active dictionary lookup word highlight in the reader.
final readerLookupHighlightProvider =
    StateNotifierProvider<ReaderLookupHighlightNotifier, ReaderLookupHighlight?>(
  (ref) => ReaderLookupHighlightNotifier(),
);
