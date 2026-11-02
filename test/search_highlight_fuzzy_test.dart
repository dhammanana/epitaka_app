/// Regression tests for search-result highlighting in the two Fuzzy modes.
///
/// The highlight used to fold diacritics always, so searching `assā` lit up
/// every `assa` on the same line even with the Fuzzy chip OFF — a word the
/// whole-word search never matched. With Fuzzy off the highlight now matches
/// the exact, whole word; with Fuzzy on it still folds diacritics.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/core/utils/pali_search_utils.dart';
import 'package:epitaka/features/search/widgets/search_result_highlight.dart';

/// The text of every span the snippet builder highlighted.
List<String> _highlighted(List<InlineSpan> spans) => [
  for (final span in spans)
    if (span is TextSpan &&
        span.text != null &&
        span.style?.backgroundColor != null)
      span.text!,
];

List<InlineSpan> _snippet(
  String text, {
  required List<String> terms,
  required bool fuzzy,
}) => buildSearchSnippetSpans(
  html: text,
  baseStyle: const TextStyle(),
  terms: terms,
  isPali: true,
  highlightColor: const Color(0x33000000),
  fuzzy: fuzzy,
);

void main() {
  group('highlight terms', () {
    test('Fuzzy off keeps the diacritics', () {
      expect(paliSearchHighlightTerms('assā', fuzzy: false), ['assā']);
    });

    test('Fuzzy on folds them', () {
      expect(paliSearchHighlightTerms('assā', fuzzy: true), ['assa']);
    });
  });

  group('whole word (Fuzzy off)', () {
    test('assā does not light up assa on the same line', () {
      final spans = _snippet(
        'assa assā',
        terms: paliSearchHighlightTerms('assā', fuzzy: false),
        fuzzy: false,
      );
      expect(_highlighted(spans), ['assā']);
    });

    test('a term does not light up part of a longer word', () {
      final spans = _snippet(
        'assa assaka',
        terms: paliSearchHighlightTerms('assa', fuzzy: false),
        fuzzy: false,
      );
      expect(_highlighted(spans), ['assa']);
    });

    test('diacritics still match case-insensitively', () {
      final spans = _snippet(
        'Assā assā',
        terms: paliSearchHighlightTerms('assā', fuzzy: false),
        fuzzy: false,
      );
      expect(_highlighted(spans), ['Assā', 'assā']);
    });
  });

  group('fuzzy (Fuzzy on)', () {
    test('assā lights up both spellings', () {
      final spans = _snippet(
        'assa assā',
        terms: paliSearchHighlightTerms('assā', fuzzy: true),
        fuzzy: true,
      );
      expect(_highlighted(spans), ['assa', 'assā']);
    });
  });

  group('word boundary helper', () {
    test('accepts a standalone word', () {
      expect(isWholePaliWord('assa dhamma', 0, 4), isTrue);
      expect(isWholePaliWord('dhamma assā', 7, 4), isTrue);
    });

    test('rejects a word inside a longer one', () {
      expect(isWholePaliWord('assaka', 0, 4), isFalse);
      expect(isWholePaliWord('upassa', 2, 4), isFalse);
    });

    test('punctuation and the snippet ellipsis are boundaries', () {
      expect(isWholePaliWord('assa,', 0, 4), isTrue);
      expect(isWholePaliWord('… assa', 2, 4), isTrue);
    });
  });
}
