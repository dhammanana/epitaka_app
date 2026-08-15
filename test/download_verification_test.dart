import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/settings/providers/translation_download_provider.dart';

void main() {
  group('verifyDownloadedDb', () {
    test('accepts content matching the manifest checksum (SHA-256 of the db)', () {
      // The server hashes the .db file inside the zip, so the extracted
      // bytes must hash to the manifest checksum.
      final content = utf8.encode('fake sqlite database bytes');
      final checksum = sha256.convert(content).toString();

      final error = verifyDownloadedDb(
        dbContent: content,
        expectedChecksum: checksum,
      );
      expect(error, isNull);
    });

    test('accepts uppercase hex checksums (comparison is case-insensitive)', () {
      final content = utf8.encode('some bytes');
      final checksum = sha256.convert(content).toString().toUpperCase();

      final error = verifyDownloadedDb(
        dbContent: content,
        expectedChecksum: checksum,
      );
      expect(error, isNull);
    });

    test('rejects content with a mismatched checksum', () {
      final content = utf8.encode('correct bytes');
      final checksum = sha256.convert(utf8.encode('different bytes')).toString();

      final error = verifyDownloadedDb(
        dbContent: content,
        expectedChecksum: checksum,
      );
      expect(error, isNotNull);
      expect(error, contains('Checksum mismatch'));
      expect(error, contains(checksum));
    });

    test('skips the checksum check when the manifest has no checksum', () {
      final error = verifyDownloadedDb(
        dbContent: utf8.encode('anything'),
        expectedChecksum: null,
      );
      expect(error, isNull);

      final empty = verifyDownloadedDb(
        dbContent: utf8.encode('anything'),
        expectedChecksum: '',
      );
      expect(empty, isNull);
    });

    test('accepts content matching the manifest dbSize', () {
      final content = List<int>.generate(100, (i) => i);
      final error = verifyDownloadedDb(
        dbContent: content,
        expectedDbSize: 100,
      );
      expect(error, isNull);
    });

    test('rejects content whose size differs from the manifest dbSize', () {
      final error = verifyDownloadedDb(
        dbContent: List<int>.generate(99, (i) => i),
        expectedDbSize: 100,
      );
      expect(error, isNotNull);
      expect(error, contains('Size mismatch'));
    });

    test('rejects when both checksum and size mismatch (reports checksum)', () {
      final content = utf8.encode('a');
      final wrongChecksum =
          sha256.convert(utf8.encode('b')).toString();

      final error = verifyDownloadedDb(
        dbContent: content,
        expectedChecksum: wrongChecksum,
        expectedDbSize: 500,
      );
      expect(error, contains('Checksum mismatch'));
    });
  });
}
