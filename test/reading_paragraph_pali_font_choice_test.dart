/// The Pāli font choice (Serif / Sans-Serif / Monospace) must reach the
/// reader wherever a bundled font exists for it (Roman, Cyrillic, Tai Tham),
/// while every other script keeps its own font. Size, colour and weight
/// must apply in every script.
///
/// Previously the reader always used the script font, so Roman Pāli stayed
/// NotoSerif whatever the user picked; only the settings preview changed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/core/providers/settings_provider.dart'
    show LanguageTypography, ReadingFontFamily;
import 'package:epitaka/features/reader/providers/reader_provider.dart'
    show LineData, ParagraphData, ParagraphHeading;
import 'package:epitaka/core/utils/pali_script_converter.dart';
import 'package:epitaka/core/utils/pali_text_utils.dart';
import 'package:epitaka/shared/widgets/reading_paragraph.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  // Same walk as reading_paragraph_highlight_font_test.dart: a span's family
  // is its own, else the nearest ancestor's; the Text.rich wrapper is skipped.
  List<String?> contentSpanFamilies(TextSpan wrapper) {
    final families = <String?>[];
    void walk(InlineSpan span, String? parentFamily) {
      if (span is TextSpan) {
        final family = span.style?.fontFamily ?? parentFamily;
        families.add(family);
        for (final child in span.children ?? const <InlineSpan>[]) {
          walk(child, family);
        }
      }
    }

    final wrapperFamily = wrapper.style?.fontFamily;
    for (final child in wrapper.children ?? const <InlineSpan>[]) {
      walk(child, wrapperFamily);
    }
    return families;
  }

  Future<List<String?>> familiesFor(
    WidgetTester tester, {
    required Script script,
    String? searchQuery,
  }) async {
    final paragraph = ParagraphData(
      paraId: 1,
      lines: const [
        LineData(lineId: 1, paliText: 'dhamma khetta', normalizedText: ''),
      ],
    );

    await tester.pumpWidget(
      wrap(
        ReadingParagraph(
          paragraph: paragraph,
          script: script,
          pageNumberingSystem: 'vri',
          searchQuery: searchQuery,
          enabledLangCodes: const [],
          paliTypography: const LanguageTypography(
            fontSize: 19,
            fontFamily: ReadingFontFamily.sansSerif,
          ),
        ),
      ),
    );

    final richText = tester.widget<RichText>(find.byType(RichText));
    return contentSpanFamilies(richText.text as TextSpan);
  }

  testWidgets('Roman Pāli uses the chosen Sans-Serif font', (tester) async {
    final families = await familiesFor(tester, script: Script.roman);
    expect(families, isNotEmpty);
    expect(
      families.where((f) => f != 'DejaVuSans'),
      isEmpty,
      reason: 'every content span must be DejaVuSans, got $families',
    );
  });

  testWidgets('Roman Pāli with a search highlight uses Sans-Serif', (
    tester,
  ) async {
    final families = await familiesFor(
      tester,
      script: Script.roman,
      searchQuery: 'dhamma',
    );
    expect(families, isNotEmpty);
    expect(
      families.where((f) => f != 'DejaVuSans'),
      isEmpty,
      reason: 'every content span must be DejaVuSans, got $families',
    );
  });

  testWidgets('Myanmar Pāli keeps Pyidaungsu when Sans-Serif is chosen', (
    tester,
  ) async {
    final families = await familiesFor(tester, script: Script.myanmar);
    expect(families, isNotEmpty);
    expect(
      families.where((f) => f != 'Pyidaungsu'),
      isEmpty,
      reason: 'every content span must be Pyidaungsu, got $families',
    );
  });

  // Literal names so the test also guards the font mapping itself. Scripts
  // not listed keep their script font whatever the choice.
  String? expectedFamily(Script script, ReadingFontFamily choice) {
    const latin = {
      ReadingFontFamily.serif: 'NotoSerif',
      ReadingFontFamily.sansSerif: 'DejaVuSans',
      ReadingFontFamily.mono: 'DejaVuSansMono',
    };
    switch (script) {
      case Script.roman:
      case Script.cyrillic:
        return latin[choice];
      case Script.taitham:
        return choice == ReadingFontFamily.serif
            ? 'PaliSerifTaiLnTilok'
            : 'NotoSansTaiTham';
      default:
        return scriptFontFamily(script);
    }
  }

  // Effective style of every content span, merged down from its ancestors
  // the way Flutter resolves inherited text styles.
  List<TextStyle> contentSpanStyles(TextSpan wrapper) {
    final styles = <TextStyle>[];
    void walk(InlineSpan span, TextStyle parent) {
      if (span is TextSpan) {
        final style = parent.merge(span.style);
        styles.add(style);
        for (final child in span.children ?? const <InlineSpan>[]) {
          walk(child, style);
        }
      }
    }

    final base = wrapper.style ?? const TextStyle();
    for (final child in wrapper.children ?? const <InlineSpan>[]) {
      walk(child, base);
    }
    return styles;
  }

  const paliColor = Color(0xFF123456);

  for (final script in Script.values) {
    for (final choice in ReadingFontFamily.values) {
      testWidgets('${script.name} Pāli with ${choice.name}: font, size, '
          'colour and weight', (tester) async {
        final paragraph = ParagraphData(
          paraId: 1,
          lines: const [
            LineData(lineId: 1, paliText: 'dhamma khetta', normalizedText: ''),
          ],
        );
        await tester.pumpWidget(
          wrap(
            ReadingParagraph(
              paragraph: paragraph,
              script: script,
              pageNumberingSystem: 'vri',
              enabledLangCodes: const [],
              paliTypography: LanguageTypography(
                fontSize: 23,
                fontFamily: choice,
                bold: true,
                color: paliColor,
              ),
            ),
          ),
        );

        final wrapper =
            tester.widget<RichText>(find.byType(RichText)).text as TextSpan;
        final styles = contentSpanStyles(wrapper);
        final expected =
            expectedFamily(script, choice) ?? wrapper.style?.fontFamily;
        expect(styles, isNotEmpty);
        for (final style in styles) {
          expect(style.fontFamily, expected);
          expect(style.fontSize, 23);
          expect(style.color, paliColor);
          expect(style.fontWeight, FontWeight.w700);
        }
      });
    }
  }

  for (final script in [Script.roman, Script.cyrillic, Script.taitham]) {
    testWidgets('${script.name} plain heading follows Sans-Serif', (
      tester,
    ) async {
      final paragraph = ParagraphData(
        paraId: 1,
        heading: const ParagraphHeading(
          title: 'verañjakaṇḍaṃ',
          level: 2,
          paraId: 1,
        ),
      );
      await tester.pumpWidget(
        wrap(
          ReadingParagraph(
            paragraph: paragraph,
            script: script,
            pageNumberingSystem: 'vri',
            enabledLangCodes: const [],
            paliTypography: const LanguageTypography(
              fontSize: 19,
              fontFamily: ReadingFontFamily.sansSerif,
            ),
          ),
        ),
      );

      final wrapper =
          tester.widget<RichText>(find.byType(RichText).first).text
              as TextSpan;
      // A plain `Text` heading is a single span holding the text itself,
      // with no children for the content walk to reach.
      final families = wrapper.text != null
          ? [wrapper.style?.fontFamily]
          : contentSpanFamilies(wrapper);
      final expected = expectedFamily(script, ReadingFontFamily.sansSerif);
      expect(families, isNotEmpty);
      expect(
        families.where((f) => f != expected),
        isEmpty,
        reason: 'heading spans must be $expected, got $families',
      );
    });
  }
}
