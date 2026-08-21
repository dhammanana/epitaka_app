/// Unit tests for [buildCitationFromTemplate] — the template that renders the
/// excerpt/share citation line.
///
/// Pins the two behaviors that recently changed:
/// 1. A leading "- " (the excerpt dash prefix) must survive the cleanup pass.
/// 2. Dangling punctuation left by an empty `{heading}` placeholder is still
///    stripped from the start/end of the citation.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/features/reader/providers/reader_provider.dart';
import 'package:epitaka/features/reader/utils/reader_quote_utils.dart';

void main() {
  const bookId = 'dn1';
  const bookName = 'Brahmajāla Sutta';
  const pages = {'vri': '12', 'pts': '8', 'thai': '15', 'my': '10'};

  group('buildCitationFromTemplate', () {
    test('keeps the leading "- " dash prefix (VRI Short preset)', () {
      final citation = buildCitationFromTemplate(
        '- {book_id} VRI p.{vri_page}',
        bookId,
        bookName,
        null,
        pages,
      );
      expect(citation, '- dn1 VRI p.12');
    });

    test('PTS / Myanmar / Thai short presets render their own system', () {
      expect(
        buildCitationFromTemplate(
          '- {book_id} PTS p.{pts_page}',
          bookId,
          bookName,
          null,
          pages,
        ),
        '- dn1 PTS p.8',
      );
      expect(
        buildCitationFromTemplate(
          '- {book_id} Myanmar p.{myanmar_page}',
          bookId,
          bookName,
          null,
          pages,
        ),
        '- dn1 Myanmar p.10',
      );
      expect(
        buildCitationFromTemplate(
          '- {book_id} Thai p.{thai_page}',
          bookId,
          bookName,
          null,
          pages,
        ),
        '- dn1 Thai p.15',
      );
    });

    test('default long template keeps the dash and the heading', () {
      final heading = const ParagraphHeading(
        title: '1. The Net of Views',
        level: 1,
        paraId: 100,
      );
      final citation = buildCitationFromTemplate(
        '- {book_name} > {heading} VRI p.{vri_page}',
        bookId,
        bookName,
        heading,
        pages,
      );
      expect(citation, '- Brahmajāla Sutta > 1. The Net of Views VRI p.12');
    });

    test('empty heading leaves no dangling leading punctuation', () {
      // "{heading} — {book_id}" with no heading must collapse to the book id,
      // not "— dn1".
      final citation = buildCitationFromTemplate(
        '{heading} — {book_id}',
        bookId,
        bookName,
        null,
        pages,
      );
      expect(citation, 'dn1');
    });

    test('templates without a dash prefix stay as typed (no forced dash)', () {
      final citation = buildCitationFromTemplate(
        '{book_id} VRI p.{vri_page}, {book_id} PTS p.{pts_page}',
        bookId,
        bookName,
        null,
        pages,
      );
      expect(citation, 'dn1 VRI p.12, dn1 PTS p.8');
    });
  });
}
