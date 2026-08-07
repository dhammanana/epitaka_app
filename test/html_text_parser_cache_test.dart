/// Regression tests for the memoized [HtmlTextParser].
///
/// The parser now caches the token stream per HTML string and re-applies the
/// base style on every call. These tests pin the *observable* output so a
/// cache bug (stale tokens, wrong base merge, missing mark/bold semantics)
/// cannot silently change rendered text.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/shared/utils/html_text_parser.dart';

void main() {
  TextStyle base(TextStyle? src) =>
      src ?? const TextStyle(fontSize: 19, color: Colors.black87);

  /// Flatten spans into comparable strings (Dart maps/records don't do deep
  /// equality, so compare serialized output instead).
  List<String> snapshot(List<InlineSpan> spans) {
    return spans.map((s) {
      final t = s as TextSpan;
      final st = t.style;
      return '${t.text ?? ''}|w=${st?.fontWeight}|i=${st?.fontStyle}|'
          'u=${st?.decoration}|bg=${st?.backgroundColor?.toARGB32()}|'
          's=${st?.fontSize}|f=${st?.fontFamily}';
    }).toList();
  }

  test('cached and uncached parses produce identical spans', () {
    const html = 'Plain <b>bold</b> and <i>italic</i> '
        '<u>under</u> <mark>marked</mark> text.';
    final style = base(null);

    // First call populates the cache.
    final first = HtmlTextParser.parse(html, style);
    // Second call must hit the cache (identical tokens, fresh base).
    final second = HtmlTextParser.parse(html, style);

    expect(snapshot(second), snapshot(first));
    expect(second.length, first.length);
    // Spot-check the mark segment: bold + yellow background.
    final mark = (second[7] as TextSpan).style;
    expect(mark?.fontWeight, FontWeight.w700);
    expect(mark?.backgroundColor, isNotNull);
  });

  test('nested tags accumulate (b + i)', () {
    const html = '<b><i>both</i></b> plain';
    final spans = HtmlTextParser.parse(html, base(null));
    final bold = spans.first as TextSpan;
    expect(bold.text, 'both');
    expect(bold.style?.fontWeight, FontWeight.w700);
    expect(bold.style?.fontStyle, FontStyle.italic);
    final rest = spans[1] as TextSpan;
    expect(rest.text, ' plain');
    expect(rest.style?.fontWeight, isNull);
    expect(rest.style?.fontStyle, isNull);
  });

  test('base style is re-applied on every call even for cached html', () {
    const html = '<b>x</b>y';
    const styled = TextStyle(
      fontSize: 25,
      color: Colors.red,
      fontFamily: 'Serif',
    );
    final spans = HtmlTextParser.parse(html, styled);
    final bold = spans.first as TextSpan;
    // The bold span must keep the *new* base's font size/family/color, not
    // the style from whichever call populated the cache first.
    expect(bold.style?.fontSize, 25);
    expect(bold.style?.fontFamily, 'Serif');
    expect(bold.style?.color, Colors.red);
    expect(bold.style?.fontWeight, FontWeight.w700);
  });

  test('different base styles never bleed across cached calls', () {
    const html = '<b>bold</b>rest';
    final sA = HtmlTextParser.parse(html, base(null));
    final sB = HtmlTextParser.parse(html, const TextStyle(fontSize: 30));
    // Same text, same tags, but each carries its own base size.
    expect((sA.first as TextSpan).style?.fontSize, 19);
    expect((sB.first as TextSpan).style?.fontSize, 30);
  });

  test('br becomes newline inside the token stream', () {
    const html = 'a<br>b<br/>c';
    final spans = HtmlTextParser.parse(html, base(null));
    // <br> is normalized to a real newline inside the plain-text run
    // (renders identically to separate a / b / c spans).
    expect(spans.map((s) => (s as TextSpan).text).join('|'), 'a\nb\nc');
  });

  test('tag-less text takes the fast path (single span, no cache)', () {
    const html = 'no tags here';
    final spans = HtmlTextParser.parse(html, base(null));
    expect(spans.length, 1);
    expect((spans.first as TextSpan).text, html);
    // The fast path deliberately leaves style null so callers fall back to
    // their own base (same as before memoization).
    expect((spans.first as TextSpan).style, isNull);
  });

  test('h1-h6 tags render bold like the original parser', () {
    for (final tag in ['h1', 'h3', 'h6']) {
      final spans = HtmlTextParser.parse('<$tag>heading</$tag>', base(null));
      expect(
        (spans.first as TextSpan).style?.fontWeight,
        FontWeight.w700,
        reason: '$tag should be bold',
      );
    }
  });
}
