// lib/features/annotations/services/highlight_span_painter.dart
//
// Paints annotation highlight backgrounds onto parsed inline spans.
//
// The input spans' flattened text (the concatenation of every leaf `text`)
// must equal the *stripped* (tag-free) text exactly (`<br>` → `\n`) — the
// same character space the highlight intervals are stored in. We walk the
// span tree recursively, track a cumulative character offset across leaves,
// and split any leaf a highlight interval overlaps, applying the background
// to just the covered slice. Container spans (which have children and no
// text of their own) are rebuilt with their children replaced, so nested
// formatting like `<b><i>…</i></b>` survives highlighting.

import 'package:flutter/material.dart';

import '../models/annotation.dart' show HighlightColor;
import 'highlight_interval_resolver.dart';

class HighlightSpanPainter {
  HighlightSpanPainter._();

  /// Paint the resolved [highlights] onto [spans] (already parsed, with
  /// [baseStyle] as the fallback style). Returns a new span list.
  static List<InlineSpan> paint({
    required BuildContext context,
    required List<InlineSpan> spans,
    required TextStyle baseStyle,
    required List<ResolvedHighlight> highlights,
  }) {
    if (spans.isEmpty || highlights.isEmpty) return spans;
    final painted = <InlineSpan>[];
    int offset = 0;
    for (final span in spans) {
      offset = _paintSpan(
        context,
        span,
        baseStyle,
        highlights,
        painted,
        offset,
      );
    }
    return painted;
  }

  /// Paint [span] (and its children) into [out], starting at character
  /// [offset] in the stripped text. Returns the offset after [span].
  static int _paintSpan(
    BuildContext context,
    InlineSpan span,
    TextStyle baseStyle,
    List<ResolvedHighlight> highlights,
    List<InlineSpan> out,
    int offset,
  ) {
    if (span is! TextSpan) {
      out.add(span);
      return offset;
    }

    // Container: no text of its own, but has children (nested tags). Rebuild
    // it with the highlighted children, keeping its style.
    if (span.text == null) {
      final children = <InlineSpan>[];
      var childOffset = offset;
      for (final child in span.children ?? const <InlineSpan>[]) {
        childOffset = _paintSpan(
          context,
          child,
          baseStyle,
          highlights,
          children,
          childOffset,
        );
      }
      out.add(TextSpan(style: span.style, children: children));
      return childOffset;
    }

    final text = span.text!;
    final len = text.length;
    if (len == 0) {
      out.add(span);
      return offset;
    }

    // Collect the highlight slices overlapping this leaf (in leaf-local
    // character coordinates).
    final slices = <(int, int, HighlightColor)>[];
    for (final h in highlights) {
      final s = h.start.clamp(offset, offset + len);
      final e = h.end.clamp(offset, offset + len);
      if (e > s) slices.add((s - offset, e - offset, h.color));
    }
    if (slices.isEmpty) {
      out.add(span);
      return offset + len;
    }

    // Merge overlapping slices (later annotations win the color).
    slices.sort((a, b) => a.$1.compareTo(b.$1));
    final merged = <(int, int, HighlightColor)>[];
    for (final s in slices) {
      if (merged.isEmpty) {
        merged.add(s);
        continue;
      }
      final last = merged.last;
      if (s.$1 <= last.$2) {
        final end = s.$2 > last.$2 ? s.$2 : last.$2;
        merged[merged.length - 1] = (last.$1, end, s.$3);
      } else {
        merged.add(s);
      }
    }

    int cursor = 0;
    for (final (s, e, color) in merged) {
      if (s > cursor) {
        out.add(TextSpan(text: text.substring(cursor, s), style: span.style));
      }
      out.add(
        TextSpan(
          text: text.substring(s, e),
          style: (span.style ?? baseStyle).copyWith(
            backgroundColor: color.color(context),
          ),
        ),
      );
      cursor = e;
    }
    if (cursor < len) {
      out.add(TextSpan(text: text.substring(cursor), style: span.style));
    }
    return offset + len;
  }
}
