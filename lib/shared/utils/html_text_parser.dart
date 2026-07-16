import 'package:flutter/material.dart';

/// Parses simple HTML tags into Flutter [InlineSpan]s for use in
/// [Text.rich] widgets.
///
/// Supports: `<b>`, `<i>`, `<u>`, `<mark>`, `<h1-6>`, `<br>`
class HtmlTextParser {
  /// Parse [html] into a list of [InlineSpan]s using [base] as the default
  /// text style.
  ///
  /// If [html] contains no `<` character, returns a single [TextSpan] with
  /// the plain text for efficiency.
  static List<InlineSpan> parse(String html, TextStyle base) {
    if (!html.contains('<')) return [TextSpan(text: html)];

    final spans = <InlineSpan>[];
    final boldStyle = base.copyWith(fontWeight: FontWeight.w700);
    final italicStyle = base.copyWith(fontStyle: FontStyle.italic);
    final underlineStyle = base.copyWith(decoration: TextDecoration.underline);
    final markStyle = base.copyWith(
      backgroundColor: Colors.yellow.withValues(alpha: 0.3),
      fontWeight: FontWeight.w700,
    );

    final normalized = html.replaceAll('<br>', '\n').replaceAll('<br/>', '\n');
    final pattern = RegExp(
      r'<b>(.*?)</b>|<i>(.*?)</i>|<u>(.*?)</u>|<mark>(.*?)</mark>|'
      r'<h[1-6][^>]*>(.*?)</h[1-6]>|'
      r'([^<]+)',
      dotAll: true,
      caseSensitive: false,
    );

    for (final m in pattern.allMatches(normalized)) {
      if (m.group(1) != null) {
        spans.add(TextSpan(text: m.group(1), style: boldStyle));
      } else if (m.group(2) != null) {
        spans.add(TextSpan(text: m.group(2), style: italicStyle));
      } else if (m.group(3) != null) {
        spans.add(TextSpan(text: m.group(3), style: underlineStyle));
      } else if (m.group(4) != null) {
        spans.add(TextSpan(text: m.group(4), style: markStyle));
      } else if (m.group(5) != null) {
        spans.add(TextSpan(text: m.group(5), style: boldStyle));
      } else if (m.group(6) != null) {
        final text = m.group(6)!;
        if (text.trim().isNotEmpty || text == '\n') {
          spans.add(TextSpan(text: text));
        }
      }
    }

    return spans;
  }

  /// Convenience: build a [Text.rich] widget from an HTML string.
  static Widget richText(
    String html,
    TextStyle style, {
    int? maxLines,
    TextOverflow? overflow,
    TextAlign? textAlign,
  }) {
    return Text.rich(
      TextSpan(style: style, children: parse(html, style)),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      textAlign: textAlign ?? TextAlign.start,
    );
  }
}
