// Tests for the shareable app-link URL built by ReaderCopyService.
//
// The format is a contract with the epitaka.org website: the app copies
// https://epitaka.org/app/{lang}/{bookId}/{heading-slug}#{paraId}-{lineId}
// and the website rewrites `/app` → `/{lang}/book` keeping the rest
// identical (see docs/deep-links.md).

import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/features/reader/services/reader_copy_service.dart';

void main() {
  group('ReaderCopyService.buildShareUrl', () {
    test('full position: heading slug + para-line fragment', () {
      final url = ReaderCopyService.buildShareUrl(
        lang: 'en',
        bookId: 'dn1',
        slug: 'the-net-of-views-123',
        paraId: 123,
        lineId: 45,
      );
      expect(url, 'https://epitaka.org/app/en/dn1/the-net-of-views-123#123-45');
    });

    test('para without a line keeps a bare fragment', () {
      final url = ReaderCopyService.buildShareUrl(
        lang: 'vi',
        bookId: 'mn1',
        slug: 'brahmajala-1',
        paraId: 1,
      );
      expect(url, 'https://epitaka.org/app/vi/mn1/brahmajala-1#1');
    });

    test('no slug and no para yields the bare app book link', () {
      final url = ReaderCopyService.buildShareUrl(
        lang: 'my',
        bookId: 'sn1',
      );
      expect(url, 'https://epitaka.org/app/my/sn1');
    });

    test('slug only (no position) appends it to the path', () {
      final url = ReaderCopyService.buildShareUrl(
        lang: 'en',
        bookId: 'dn1',
        slug: 'the-net-of-views-123',
      );
      expect(url, 'https://epitaka.org/app/en/dn1/the-net-of-views-123');
    });
  });
}
