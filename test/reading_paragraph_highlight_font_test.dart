/// Regression: a search-highlighted Pāli line must render with the same
/// script-specific font as a normal (non-highlighted) line.
///
/// Previously `ReadingParagraph._buildPaliLine` passed a style WITHOUT the
/// script font family to the highlight builder, so scripts that have a
/// dedicated bundled font (Lao → LaoPaliRegular, Myanmar → Pyidaungsu,
/// Sinhala, Devanagari, …) fell back to the platform default font and
/// rendered incorrectly (e.g. missing the Pali-specific Lao characters).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/reader/providers/reader_provider.dart'
    show LineData, ParagraphData;
import '../lib/core/utils/pali_script_converter.dart';
import '../lib/core/utils/pali_text_utils.dart';
import '../lib/shared/widgets/reading_paragraph.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  /// `Text.rich` wraps the passed [TextSpan] in a parent span styled with
  /// the ambient `DefaultTextStyle`. The wrapper's family is the app's
  /// default (e.g. 'Roboto' in tests) and is not our concern; what matters
  /// is that every span in the content subtree below it resolves to the
  /// script font at paint time.
  ///
  /// Models Flutter's inheritance: a span's family comes from its own style
  /// when set, otherwise from the nearest ancestor that set one. Without the
  /// fix, the content root has no family and everything inherits the
  /// wrapper's default — which this walk exposes.
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

  /// True when any span in the content subtree carries a background (search
  /// highlight).
  bool hasHighlightBackground(TextSpan wrapper) {
    var found = false;
    void walk(InlineSpan span) {
      if (span is TextSpan) {
        if (span.style?.backgroundColor != null) {
          found = true;
          return;
        }
        for (final child in span.children ?? const <InlineSpan>[]) {
          walk(child);
        }
      }
    }

    for (final child in wrapper.children ?? const <InlineSpan>[]) {
      walk(child);
    }
    return found;
  }

  // Scripts that have a dedicated bundled font — the ones that regressed.
  final bundledFontScripts = Script.values
      .where((s) => scriptFontFamily(s) != null)
      .toList();

  for (final script in bundledFontScripts) {
    final font = scriptFontFamily(script)!;

    testWidgets('highlighted Pāli line resolves to $font (${script.name})', (
      tester,
    ) async {
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
            searchQuery: 'dhamma',
            enabledLangCodes: const [],
          ),
        ),
      );

      final richText = tester.widget<RichText>(find.byType(RichText));
      final wrapper = richText.text as TextSpan;

      final families = contentSpanFamilies(wrapper);
      expect(
        families.where((f) => f != font),
        isEmpty,
        reason: 'every content span must inherit $font, got $families',
      );
    });

    testWidgets('highlighted Pāli line with <b> keeps $font (${script.name})', (
      tester,
    ) async {
      final paragraph = ParagraphData(
        paraId: 1,
        lines: const [
          LineData(
            lineId: 1,
            paliText: 'dhamma <b>khetta</b>',
            normalizedText: '',
          ),
        ],
      );

      await tester.pumpWidget(
        wrap(
          ReadingParagraph(
            paragraph: paragraph,
            script: script,
            pageNumberingSystem: 'vri',
            searchQuery: 'khetta',
            enabledLangCodes: const [],
          ),
        ),
      );

      final richText = tester.widget<RichText>(find.byType(RichText));
      final wrapper = richText.text as TextSpan;
      final families = contentSpanFamilies(wrapper);
      expect(
        families.where((f) => f != font),
        isEmpty,
        reason: 'the bold <b> span must inherit $font, got $families',
      );
    });
  }

  testWidgets('Lao highlighted line: term is painted and keeps LaoPaliRegular',
      (tester) async {
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
          script: Script.laos,
          pageNumberingSystem: 'vri',
          searchQuery: 'dhamma',
          enabledLangCodes: const [],
        ),
      ),
    );

    final richText = tester.widget<RichText>(find.byType(RichText));
    final wrapper = richText.text as TextSpan;

    // Sanity: the conversion pipeline actually matches the query in Lao,
    // otherwise there would be nothing to highlight in the app either.
    final convertedText = convertPaliToScriptPreservingHtml(
      'dhamma khetta',
      Script.laos,
    );
    final convertedQuery = convertSearchQueryForScript('dhamma', Script.laos);
    expect(
      convertedText.contains(convertedQuery),
      isTrue,
      reason: '"$convertedText" should contain "$convertedQuery"',
    );

    expect(hasHighlightBackground(wrapper), isTrue);
    expect(
      contentSpanFamilies(wrapper).where((f) => f != 'LaoPaliRegular'),
      isEmpty,
    );
  });

  testWidgets('normal (no query) Pāli line keeps the script font', (
    tester,
  ) async {
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
          script: Script.laos,
          pageNumberingSystem: 'vri',
          enabledLangCodes: const [],
        ),
      ),
    );

    final richText = tester.widget<RichText>(find.byType(RichText));
    final wrapper = richText.text as TextSpan;
    expect(
      contentSpanFamilies(wrapper).where((f) => f != 'LaoPaliRegular'),
      isEmpty,
    );
  });
}
