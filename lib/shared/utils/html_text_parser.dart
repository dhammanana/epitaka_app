import 'package:flutter/material.dart';

/// Parses simple HTML tags into Flutter [InlineSpan]s for use in
/// [Text.rich] widgets.
///
/// Supports: `<b>`, `<i>`, `<u>`, `<mark>`, `<h1-6>`, `<br>`
class HtmlTextParser {
  /// Parse [html] into a list of [InlineSpan]s using [base] as the default
  /// text style.
  ///
  /// Supports nested tags: `<b><i>text</i></b>` produces a [TextSpan] with
  /// both bold and italic styles.
  ///
  /// Supported tags: `<b>`, `<i>`, `<u>`, `<mark>`, `<h1-6>`, `<br>`
  ///
  /// If [html] contains no `<` character, returns a single [TextSpan] with
  /// the plain text for efficiency.
  static List<InlineSpan> parse(String html, TextStyle base) {
    if (!html.contains('<')) return [TextSpan(text: html)];

    final spans = <InlineSpan>[];
    // Style stack: each opening tag pushes a new style, each closing tag
    // pops one. This correctly handles nested tags like <b><i>text</i></b>.
    final styleStack = <TextStyle>[base];

    final normalized = html.replaceAll('<br>', '\n').replaceAll('<br/>', '\n');
    // Match opening tags, closing tags, <br>, and plain text
    final tagPattern = RegExp(
      r'<(/?)(b|i|u|mark|h[1-6])\s*/?>|<br\s*/?>|([^<]+)',
      caseSensitive: false,
      dotAll: true,
    );

    for (final m in tagPattern.allMatches(normalized)) {
      final tag = m.group(0)!;
      if (tag.startsWith('<br')) {
        spans.add(TextSpan(text: '\n', style: styleStack.last));
      } else if (m.group(1) == '/') {
        // Closing tag — pop the style stack
        if (styleStack.length > 1) styleStack.removeLast();
      } else if (m.group(2) != null) {
        // Opening tag — push a new style
        final tagName = m.group(2)!.toLowerCase();
        final current = styleStack.last;
        TextStyle tagStyle;
        switch (tagName) {
          case 'b':
          case 'h1':
          case 'h2':
          case 'h3':
          case 'h4':
          case 'h5':
          case 'h6':
            tagStyle = current.copyWith(fontWeight: FontWeight.w700);
            break;
          case 'i':
            tagStyle = current.copyWith(fontStyle: FontStyle.italic);
            break;
          case 'u':
            tagStyle = current.copyWith(decoration: TextDecoration.underline);
            break;
          case 'mark':
            tagStyle = current.copyWith(
              backgroundColor: Colors.yellow.withValues(alpha: 0.3),
              fontWeight: FontWeight.w700,
            );
            break;
          default:
            tagStyle = current;
        }
        styleStack.add(tagStyle);
      } else if (m.group(3) != null) {
        // Plain text
        final text = m.group(3)!;
        if (text.isNotEmpty) {
          spans.add(TextSpan(text: text, style: styleStack.last));
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
