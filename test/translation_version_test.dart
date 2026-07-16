import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../lib/core/database/nissaya_database.dart';
import '../lib/core/models/translation_version.dart';

void main() {
  group('TranslationFilenameParser', () {
    test('parses default filename', () {
      final (code, suffix) = TranslationFilenameParser.parse('epitaka_en.db');
      expect(code, 'en');
      expect(suffix, isNull);
    });

    test('parses suffixed filename', () {
      final (code, suffix) =
          TranslationFilenameParser.parse('epitaka_my_nissaya.db');
      expect(code, 'my');
      expect(suffix, 'nissaya');
    });

    test('matches valid filenames', () {
      expect(TranslationFilenameParser.matches('epitaka_en.db'), isTrue);
      expect(TranslationFilenameParser.matches('epitaka_th.db'), isTrue);
      expect(TranslationFilenameParser.matches('epitaka_my_nissaya.db'), isTrue);
      expect(TranslationFilenameParser.matches('epitaka_si_v2.db'), isTrue);
    });

    test('rejects invalid filenames', () {
      expect(TranslationFilenameParser.matches('epitaka.db'), isFalse);
      expect(TranslationFilenameParser.matches('epitaka.db.zip'), isFalse);
      expect(TranslationFilenameParser.matches('dpd-dictionary.db'), isFalse);
      expect(TranslationFilenameParser.matches('random.db'), isFalse);
    });

    test('detects nissaya', () {
      expect(TranslationFilenameParser.isNissaya('nissaya'), isTrue);
      expect(TranslationFilenameParser.isNissaya('my_nissaya'), isTrue);
      expect(TranslationFilenameParser.isNissaya(null), isFalse);
      expect(TranslationFilenameParser.isNissaya(''), isFalse);
      expect(TranslationFilenameParser.isNissaya('v2'), isFalse);
    });

    test('builds filename correctly', () {
      expect(TranslationFilenameParser.build('en'), 'epitaka_en.db');
      expect(
          TranslationFilenameParser.build('my', suffix: 'nissaya'),
          'epitaka_my_nissaya.db');
      expect(
          TranslationFilenameParser.build('th', suffix: 'v2'),
          'epitaka_th_v2.db');
    });

    test('scanDirectory returns correct versions', () {
      final dir = Directory.systemTemp.createTempSync('epitaka_test');
      try {
        File(p.join(dir.path, 'epitaka_en.db')).createSync();
        File(p.join(dir.path, 'epitaka_my_nissaya.db')).createSync();
        File(p.join(dir.path, 'epitaka_th.db')).createSync();
        File(p.join(dir.path, 'epitaka.db')).createSync();
        File(p.join(dir.path, 'dpd-dictionary.db')).createSync();
        File(p.join(dir.path, 'epitaka_vec.db')).createSync();

        final versions = TranslationFilenameParser.scanDirectory(dir);

        expect(versions.length, 3);

        final en = versions.firstWhere((v) => v.languageCode == 'en');
        expect(en.suffix, isNull);
        expect(en.isNissaya, isFalse);
        expect(en.isAvailable, isTrue);
        expect(en.filename, 'epitaka_en.db');

        final my = versions.firstWhere(
            (v) => v.languageCode == 'my' && v.suffix == 'nissaya');
        expect(my.isNissaya, isTrue);
        expect(my.isAvailable, isTrue);
        expect(my.filename, 'epitaka_my_nissaya.db');

        final th = versions.firstWhere((v) => v.languageCode == 'th');
        expect(th.isNissaya, isFalse);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  });

  group('TranslationVersion model', () {
    test('copyWith preserves fields', () {
      final v = TranslationVersion(
        languageCode: 'my',
        suffix: 'nissaya',
        filename: 'epitaka_my_nissaya.db',
        isNissaya: true,
        isAvailable: true,
        displayName: 'Nissaya',
        downloadUrl: 'https://example.com/epitaka_my_nissaya.db.zip',
        fileSize: 649498624,
        updatedAt: '2026-07-16',
        checksum: 'abc123',
      );

      final copy = v.copyWith(isAvailable: false, clearDownloadUrl: true);
      expect(copy.languageCode, 'my');
      expect(copy.suffix, 'nissaya');
      expect(copy.isNissaya, isTrue);
      expect(copy.isAvailable, isFalse);
      expect(copy.downloadUrl, isNull);

      final copy2 = v.copyWith(suffix: 'v2');
      expect(copy2.suffix, 'v2');
      expect(copy2.filename, 'epitaka_my_nissaya.db');
    });

    test('toJson produces correct format', () {
      final v = TranslationVersion(
        languageCode: 'my',
        suffix: 'nissaya',
        filename: 'epitaka_my_nissaya.db',
        isNissaya: true,
        displayName: 'Nissaya',
        downloadUrl: 'https://example.com/db.zip',
        fileSize: 1000,
        updatedAt: '2026-07-16',
        checksum: 'abc',
      );

      final json = v.toJson();
      expect(json['displayName'], 'Nissaya');
      expect(json['suffix'], 'nissaya');
      expect(json['url'], 'https://example.com/db.zip');
      expect(json['size'], 1000);
      expect(json['type'], 'nissaya');
      expect(json['checksum'], 'abc');
      expect(json['updated'], '2026-07-16');
    });

    test('fromJson parses correctly', () {
      final v = TranslationVersion.fromJson('my', {
        'displayName': 'Nissaya',
        'suffix': 'nissaya',
        'url': 'https://example.com/db.zip',
        'size': 1000,
        'type': 'nissaya',
        'updated': '2026-07-16',
        'checksum': 'abc',
      });

      expect(v.languageCode, 'my');
      expect(v.suffix, 'nissaya');
      expect(v.isNissaya, isTrue);
      expect(v.filename, 'epitaka_my_nissaya.db');
      expect(v.downloadUrl, 'https://example.com/db.zip');
      expect(v.fileSize, 1000);
      expect(v.updatedAt, '2026-07-16');
    });

    test('hasDownloadUrl returns correct value', () {
      final withUrl = TranslationVersion(
          languageCode: 'en',
          filename: 'epitaka_en.db',
          downloadUrl: 'https://example.com/db.zip');
      expect(withUrl.hasDownloadUrl, isTrue);

      final withoutUrl = TranslationVersion(
          languageCode: 'en', filename: 'epitaka_en.db');
      expect(withoutUrl.hasDownloadUrl, isFalse);
    });

    test('equality works correctly', () {
      final a = TranslationVersion(
          languageCode: 'en', filename: 'epitaka_en.db');
      final b = TranslationVersion(
          languageCode: 'en', filename: 'epitaka_en.db');
      final c = TranslationVersion(
          languageCode: 'my', filename: 'epitaka_my.db');

      expect(a == b, isTrue);
      expect(a == c, isFalse);
      expect(a.hashCode == b.hashCode, isTrue);
    });

    test('displayName defaults to empty string when not provided', () {
      final v = TranslationVersion(
          languageCode: 'en', filename: 'epitaka_en.db');
      expect(v.displayName, '');
    });

    test('displayName set via fromJson defaults to suffix or Default', () {
      final v = TranslationVersion.fromJson('my', {
        'url': 'https://example.com/db.zip',
      });
      expect(v.displayName, 'Default');

      final v2 = TranslationVersion.fromJson('my', {
        'suffix': 'nissaya',
        'url': 'https://example.com/db.zip',
      });
      expect(v2.displayName, 'nissaya');
    });

    test('englishName and nativeName via TranslationLanguageRegistry', () {
      final en = TranslationVersion(
          languageCode: 'en', filename: 'epitaka_en.db');
      expect(en.englishName, 'English');
      expect(en.nativeName, 'English');

      final my = TranslationVersion(
          languageCode: 'my', filename: 'epitaka_my.db');
      expect(my.englishName, 'Myanmar');
      expect(my.nativeName, 'မြန်မာ');
    });
  });

  group('TranslationManifest', () {
    test('parses from JSON correctly', () {
      final json = {
        'version': 1,
        'languages': {
          'my': {
            'englishName': 'Myanmar',
            'nativeName': 'မြန်မာ',
            'versions': {
              'default': {
                'displayName': 'Default',
                'url':
                    'https://github.com/example/epitaka_my.db.zip',
                'size': 1000000,
              },
              'nissaya': {
                'displayName': 'Nissaya',
                'suffix': 'nissaya',
                'url':
                    'https://github.com/example/epitaka_my_nissaya.db.zip',
                'size': 2000000,
                'type': 'nissaya',
              },
            },
          },
          'en': {
            'versions': {
              'default': {
                'displayName': 'Default',
                'url':
                    'https://github.com/example/epitaka_en.db.zip',
              },
            },
          },
        },
      };

      final manifest = TranslationManifest.fromJson(json);
      expect(manifest.version, 1);
      expect(manifest.languages.length, 2);

      final myVersions = manifest.versionsFor('my');
      expect(myVersions.length, 2);

      final defaultVersion =
          myVersions.firstWhere((v) => v.suffix == null);
      expect(defaultVersion.isNissaya, isFalse);
      expect(defaultVersion.fileSize, 1000000);

      final nissayaVersion =
          myVersions.firstWhere((v) => v.suffix == 'nissaya');
      expect(nissayaVersion.isNissaya, isTrue);
      expect(nissayaVersion.fileSize, 2000000);

      final enVersions = manifest.versionsFor('en');
      expect(enVersions.length, 1);
      expect(enVersions.first.downloadUrl,
          'https://github.com/example/epitaka_en.db.zip');
    });

    test('parses from string', () {
      final raw = jsonEncode({
        'version': 1,
        'languages': {
          'th': {
            'versions': {
              'default': {
                'displayName': 'Default',
                'url': 'https://example.com/epitaka_th.db.zip',
              },
            },
          },
        },
      });

      final manifest = TranslationManifest.fromString(raw);
      expect(manifest.versionsFor('th').length, 1);
      expect(manifest.allVersions.length, 1);
    });

    test('handles empty manifest', () {
      final manifest = const TranslationManifest();
      expect(manifest.allVersions, isEmpty);
      expect(manifest.versionsFor('en'), isEmpty);
    });
  });

  group('TranslationLanguageRegistry', () {
    test('returns correct names for known codes', () {
      expect(TranslationLanguageRegistry.englishName('en'), 'English');
      expect(TranslationLanguageRegistry.nativeName('th'), 'ไทย');
      expect(TranslationLanguageRegistry.englishName('my'), 'Myanmar');
    });

    test('falls back to code for unknown codes', () {
      expect(TranslationLanguageRegistry.englishName('xx'), 'xx');
      expect(TranslationLanguageRegistry.nativeName('fr'), 'fr');
    });
  });

  group('NissayaSentenceLine', () {
    test('formattedText returns pali: meaning pairs for JSON content', () {
      // NissayaSentenceLine with pre-parsed pairs (from JSON)
      final line = NissayaSentenceLine(
        bookId: 'Ps-i',
        paraId: 790,
        lineId: 4,
        nissayaId: 20,
        content: jsonEncode([
          {'pali': 'samanumodimsūti', 'meaning': 'samanumodimsu的意思是'},
          {'pali': 'samaṃ', 'meaning': 'equally'},
        ]),
        pairs: [
          NissayaWordPair(
              pali: 'samanumodimsūti', meaning: 'samanumodimsu的意思是'),
          NissayaWordPair(pali: 'samaṃ', meaning: 'equally'),
        ],
        isJsonFormatted: true,
      );

      expect(line.pairs.length, 2);
      expect(line.pairs[0].pali, 'samanumodimsūti');
      expect(line.pairs[0].meaning, 'samanumodimsu的意思是');
      expect(line.formattedText,
          'samanumodimsūti: samanumodimsu的意思是 | samaṃ: equally');
    });

    test('formattedText returns raw text for non-JSON content', () {
      final line = NissayaSentenceLine(
        bookId: 'Ps-i',
        paraId: 790,
        lineId: 4,
        nissayaId: 20,
        content: 'This is plain text translation content',
        isJsonFormatted: false,
      );

      expect(line.formattedText, 'This is plain text translation content');
      expect(line.pairs, isEmpty);
    });

    test('formattedText returns raw text when pairs are empty despite isJsonFormatted', () {
      final line = NissayaSentenceLine(
        bookId: 'Ps-i',
        paraId: 790,
        lineId: 4,
        nissayaId: 20,
        content: '[]',
        isJsonFormatted: true,
        pairs: [],
      );

      expect(line.formattedText, '[]');
    });

    test('NissayaWordPair stores pali and meaning', () {
      final pair = NissayaWordPair(pali: 'dhamma', meaning: 'truth');
      expect(pair.pali, 'dhamma');
      expect(pair.meaning, 'truth');
    });
  });
}
