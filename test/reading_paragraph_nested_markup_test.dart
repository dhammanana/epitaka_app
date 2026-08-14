/// Regression: nested `<b>`/`<i>` markup in translation text must render with
/// the outer style surviving the inner close.
///
/// The reader's HTML parser (`ReadingParagraph._parseHtml`) used a
/// non-greedy regex that swallowed nested tags — `<b>a<i>b</i>c</b>` rendered
/// the literal `<i>` as text. It now walks a tag stack, so nested markup
/// (e.g. the markdown converter's `***…***` → `<b><i>…</i></b>`) renders
/// correctly.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/reader/providers/reader_provider.dart'
    show LineData, ParagraphData;
import '../lib/core/utils/pali_script_converter.dart';
import '../lib/shared/widgets/reading_paragraph.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  /// Collect every plain-text run with its style across all RichText
  /// widgets in the tree, so the test can assert on what actually renders.
  List<({String text, FontWeight? weight, FontStyle? style})> collectSpans(
    WidgetTester tester,
  ) {
    final out = <({String text, FontWeight? weight, FontStyle? style})>[];
    void walk(InlineSpan span) {
      if (span is TextSpan) {
        final text = span.text;
        if (text != null && text.isNotEmpty) {
          out.add((
            text: text,
            weight: span.style?.fontWeight,
            style: span.style?.fontStyle,
          ));
        }
        for (final child in span.children ?? const <InlineSpan>[]) {
          walk(child);
        }
      }
    }

    for (final richText
        in tester.widgetList<RichText>(find.byType(RichText))) {
      walk(richText.text);
    }
    return out;
  }

  ParagraphData paragraphWith(String translationHtml) => ParagraphData(
        paraId: 1,
        lines: [
          LineData(
            lineId: 1,
            paliText: 'dhamma',
            normalizedText: '',
            translations: {'en': translationHtml},
          ),
        ],
      );

  testWidgets('nested <b>a<i>b</i>c</b>: "c" keeps bold after </i>', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ReadingParagraph(
          paragraph: paragraphWith('<b>a<i>b</i>c</b>'),
          script: Script.roman,
          pageNumberingSystem: 'vri',
          enabledLangCodes: const ['en'],
        ),
      ),
    );

    final spans = collectSpans(tester);
    final a = spans.firstWhere((s) => s.text == 'a');
    final b = spans.firstWhere((s) => s.text == 'b');
    final c = spans.firstWhere((s) => s.text == 'c');
    expect(a.weight, FontWeight.w700);
    expect(a.style, isNot(FontStyle.italic));
    expect(b.weight, FontWeight.w700);
    expect(b.style, FontStyle.italic);
    expect(
      c.weight,
      FontWeight.w700,
      reason: '"c" must keep bold after the inner </i> closes',
    );
    expect(c.style, isNot(FontStyle.italic));
  });

  testWidgets('nested <i>x<b>y</b>z</i>: "z" keeps italic after </b>', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ReadingParagraph(
          paragraph: paragraphWith('<i>x<b>y</b>z</i>'),
          script: Script.roman,
          pageNumberingSystem: 'vri',
          enabledLangCodes: const ['en'],
        ),
      ),
    );

    final spans = collectSpans(tester);
    final x = spans.firstWhere((s) => s.text == 'x');
    final y = spans.firstWhere((s) => s.text == 'y');
    final z = spans.firstWhere((s) => s.text == 'z');
    expect(x.style, FontStyle.italic);
    expect(x.weight, isNull);
    expect(y.style, FontStyle.italic);
    expect(y.weight, FontWeight.w700);
    expect(
      z.style,
      FontStyle.italic,
      reason: '"z" must keep italic after the inner </b> closes',
    );
    expect(z.weight, isNull);
  });

  testWidgets('***both*** nesting renders one bold-italic run, no literal tags',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        ReadingParagraph(
          paragraph: paragraphWith('<b><i>both</i></b>'),
          script: Script.roman,
          pageNumberingSystem: 'vri',
          enabledLangCodes: const ['en'],
        ),
      ),
    );

    final spans = collectSpans(tester);
    // The literal "<i>" must not appear as text anywhere.
    expect(spans.any((s) => s.text.contains('<')), isFalse);
    final both = spans.firstWhere((s) => s.text == 'both');
    expect(both.weight, FontWeight.w700);
    expect(both.style, FontStyle.italic);
  });
}
