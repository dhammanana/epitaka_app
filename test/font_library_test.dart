/// The downloadable-font library must (1) ship a catalog whose entries this
/// build can actually parse and render, and (2) let a downloaded font win
/// over the bundled one only for the scripts it declares.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/core/providers/settings_provider.dart'
    show ReadingFontFamily;
import 'package:epitaka/core/utils/pali_script_converter.dart';
import 'package:epitaka/core/utils/pali_text_utils.dart';
import 'package:epitaka/features/fonts/models/downloadable_font.dart';
import 'package:epitaka/features/fonts/services/font_library_service.dart';

void main() {
  group('bundled font catalog', () {
    final json =
        jsonDecode(File('assets/font_catalog.json').readAsStringSync())
            as Map<String, dynamic>;
    final fonts = DownloadableFont.listFromJson(json);

    test('parses every entry', () {
      expect(fonts.length, greaterThanOrEqualTo(15));
      expect(fonts.map((f) => f.id).toSet().length, fonts.length,
          reason: 'ids must be unique — they name the stored file');
    });

    test('every entry can be downloaded and rendered somewhere', () {
      for (final font in fonts) {
        expect(font.url, startsWith('https://'), reason: font.id);
        expect(font.name, isNotEmpty, reason: font.id);
        expect(font.scripts, isNotEmpty, reason: '${font.id} has no script');
        expect(font.license, isNotEmpty, reason: font.id);
      }
    });

    test('covers Latin and the main Pāli scripts', () {
      for (final script in [
        Script.roman,
        Script.sinhala,
        Script.devanagari,
        Script.thai,
        Script.myanmar,
        Script.khmer,
        Script.tamil,
        Script.tibetan,
      ]) {
        expect(
          fonts.any((f) => f.covers(script)),
          isTrue,
          reason: 'no downloadable font for ${script.name}',
        );
      }
    });

    testWidgets('the catalog ships as a bundled asset', (tester) async {
      // The File read above only proves the source tree has the catalog; the
      // app reads it through rootBundle, so the pubspec entry must exist.
      final asset = await rootBundle.loadString('assets/font_catalog.json');
      expect(asset, contains('"fonts"'));
    });

    test('ignores script names this build does not know', () {
      // A newer catalog may list a script added later; parsing must not throw
      // or drop the whole entry.
      final font = DownloadableFont.fromJson({
        'id': 'x',
        'name': 'X',
        'url': 'https://example.test/x.ttf',
        'scripts': ['roman', 'klingon'],
      });
      expect(font.scripts, [Script.roman]);
    });
  });

  group('downloaded font resolution', () {
    tearDown(() => setDownloadedPaliFonts(const {}));

    test('wins for the scripts it covers', () {
      setDownloadedPaliFonts({Script.sinhala: 'gfont_notoserifsinhala'});
      expect(
        paliReadingFontFamily(Script.sinhala, ReadingFontFamily.serif),
        'gfont_notoserifsinhala',
      );
    });

    test('leaves other scripts on their bundled font', () {
      setDownloadedPaliFonts({Script.sinhala: 'gfont_notoserifsinhala'});
      // Thai has no bundled font, so it stays on the platform font.
      expect(paliReadingFontFamily(Script.thai, ReadingFontFamily.serif), isNull);
      expect(
        paliReadingFontFamily(Script.roman, ReadingFontFamily.sansSerif),
        'DejaVuSans',
      );
    });

    test('clearing the choice restores the bundled fonts', () {
      setDownloadedPaliFonts({Script.roman: 'gfont_literata'});
      expect(
        paliReadingFontFamily(Script.roman, ReadingFontFamily.serif),
        'gfont_literata',
      );
      setDownloadedPaliFonts(const {});
      expect(
        paliReadingFontFamily(Script.roman, ReadingFontFamily.serif),
        'NotoSerif',
      );
    });

    test('family names are namespaced away from bundled families', () {
      expect(FontLibraryService.familyFor('literata'), 'gfont_literata');
      expect(
        FontLibraryService.familyFor('literata'),
        isNot(scriptFontFamily(Script.roman)),
      );
    });
  });
}
