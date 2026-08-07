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
  ///
  /// ## Performance
  ///
  /// The regex/tag walk is memoized *per input HTML string*: [parse] is
  /// called from inside widget `build()` (PaliTextWithVariants, previews,
  /// search snippets) with the *same* html string on every rebuild but a
  /// freshly-constructed [TextStyle]. Caching the token stream (plain-text
  /// runs + their accumulated markup flags) means a rebuild only re-applies
  /// the new base style to the cached tokens instead of re-running the regex
  /// walk — a significant win during reader scroll, where every visible
  /// paragraph is rebuilt per frame.
  static List<InlineSpan> parse(String html, TextStyle base) {
    if (!html.contains('<')) return [TextSpan(text: html)];

    final segments = _segmentCache[html] ??= _tokenize(html);

    return List<InlineSpan>.generate(segments.length, (i) {
      final s = segments[i];
      return TextSpan(text: s.text, style: _styleFor(s, base));
    });
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

/// A single plain-text run from the HTML tokenizer, carrying the markup
/// flags that were active at its position.
class _HtmlSegment {
  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final Color? background;

  const _HtmlSegment(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.background,
  });
}

/// The mark highlight color (kept constant so cached segments stay valid
/// across callers — the previous parser also hardcoded `Colors.yellow`).
final Color _markColor = Colors.yellow.withValues(alpha: 0.3);

/// Bounded cache: html string → token segments. FIFO eviction keeps memory
/// bounded while making repeat parses (per-frame rebuilds) effectively free.
const int _segmentCacheLimit = 2000;
final Map<String, List<_HtmlSegment>> _segmentCache = {};

/// Tokenize [html] into plain-text runs with their active markup flags.
///
/// Mirrors the observable output of the parser's style-stack walk: opening
/// tags push a flag, closing tags pop, `<br>` emits a newline, and every
/// plain-text run is stamped with the flags active at its position (so
/// nested tags like `<b><i>x</i></b>` accumulate correctly).
List<_HtmlSegment> _tokenize(String html) {
  final segments = <_HtmlSegment>[];
  final boldStack = <bool>[false];
  final italicStack = <bool>[false];
  final underlineStack = <bool>[false];
  final backgroundStack = <Color?>[null];

  final normalized = html.replaceAll('<br>', '\n').replaceAll('<br/>', '\n');
  // Match opening tags, closing tags, <br>, and plain text
  final tagPattern = RegExp(
    r'<(/?)(b|i|u|mark|h[1-6])\s*/?>|<br\s*/?>|([^<]+)',
    caseSensitive: false,
    dotAll: true,
  );

  _HtmlSegment seg(String text) => _HtmlSegment(
        text,
        bold: boldStack.last,
        italic: italicStack.last,
        underline: underlineStack.last,
        background: backgroundStack.last,
      );

  for (final m in tagPattern.allMatches(normalized)) {
    final tag = m.group(0)!;
    if (tag.startsWith('<br')) {
      segments.add(seg('\n'));
    } else if (m.group(1) == '/') {
      // Closing tag — pop the style stack
      if (boldStack.length > 1) boldStack.removeLast();
      if (italicStack.length > 1) italicStack.removeLast();
      if (underlineStack.length > 1) underlineStack.removeLast();
      if (backgroundStack.length > 1) backgroundStack.removeLast();
    } else if (m.group(2) != null) {
      // Opening tag — push a new style
      final tagName = m.group(2)!.toLowerCase();
      final isMark = tagName == 'mark';
      final isBold = isMark ||
          switch (tagName) {
            'b' || 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6' => true,
            _ => false,
          };
      final isItalic = tagName == 'i';
      final isUnderline = tagName == 'u';
      boldStack.add(isBold || boldStack.last);
      italicStack.add(isItalic || italicStack.last);
      underlineStack.add(isUnderline || underlineStack.last);
      backgroundStack.add(isMark ? _markColor : backgroundStack.last);
    } else if (m.group(3) != null) {
      // Plain text
      final text = m.group(3)!;
      if (text.isNotEmpty) {
        segments.add(seg(text));
      }
    }
  }

  if (_segmentCache.length >= _segmentCacheLimit) {
    _segmentCache.remove(_segmentCache.keys.first);
  }
  _segmentCache[html] = segments;
  return segments;
}

/// Build the [TextStyle] for a segment by copying markup flags onto [base].
TextStyle _styleFor(_HtmlSegment s, TextStyle base) {
  if (!s.bold && !s.italic && !s.underline && s.background == null) {
    return base;
  }
  return base.copyWith(
    fontWeight: s.bold ? FontWeight.w700 : base.fontWeight,
    fontStyle: s.italic ? FontStyle.italic : base.fontStyle,
    decoration: s.underline ? TextDecoration.underline : base.decoration,
    backgroundColor: s.background ?? base.backgroundColor,
  );
}
