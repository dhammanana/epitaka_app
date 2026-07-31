import 'package:flutter/material.dart';

import '../../../core/utils/pali_search_utils.dart';
import '../../../shared/utils/html_text_parser.dart';

/// Builds the [InlineSpan] list for a search-result snippet (Pāli or
/// translation).
///
/// The snippet is trimmed to a window around the first search-term match so
/// the matched word is always visible, even when the source line is very long
/// and would otherwise be truncated by `maxLines` + ellipsis. Every match
/// inside the window is highlighted with [highlightColor].
///
/// [html] may contain simple HTML tags (`<b>`, `<i>`, …) which are parsed
/// into styled spans; [baseStyle] is the default text style. When [isPali] is
/// true the Pāli fuzzy normalization is used for matching, otherwise
/// case-insensitive substring matching is used (translations).
List<InlineSpan> buildSearchSnippetSpans({
  required String html,
  required TextStyle baseStyle,
  required List<String> terms,
  required bool isPali,
  required Color highlightColor,
  int beforeChars = 40,
  int afterChars = 70,
}) {
  final allSpans = HtmlTextParser.parse(html, baseStyle);

  final nterms = isPali
      ? terms
            .map(normalizePaliFuzzy)
            .where((t) => t.isNotEmpty)
            .toList()
      : terms.map((t) => t.toLowerCase()).where((t) => t.isNotEmpty).toList();

  if (nterms.isEmpty) return allSpans;

  // Build the concatenated plain text plus each span's plain-text range, so a
  // plain-text window can be mapped back onto the individual spans later.
  final plain = StringBuffer();
  final ranges = <(int, int)>[];
  for (final span in allSpans) {
    final text = span is TextSpan ? (span.text ?? '') : '';
    ranges.add((plain.length, plain.length + text.length));
    plain.write(text);
  }
  final plainText = plain.toString();

  final match = _firstMatch(plainText, nterms, isPali: isPali);
  if (match == null) return allSpans;

  // Compute the window, snapped to word boundaries so we never start or end
  // mid-word. We deliberately keep the match itself fully inside the window.
  var start = match.$1 - beforeChars;
  if (start < 0) start = 0;
  var end = match.$2 + afterChars;
  if (end > plainText.length) end = plainText.length;

  if (start > 0) {
    final nextSpace = plainText.indexOf(' ', start);
    if (nextSpace != -1 && nextSpace + 1 <= match.$1) {
      start = nextSpace + 1;
    }
  }

  if (start == 0 && end == plainText.length) {
    // Nothing to trim — just highlight the whole text.
    return _highlightSpans(
      allSpans,
      nterms,
      baseStyle: baseStyle,
      isPali: isPali,
      highlightColor: highlightColor,
    );
  }

  // Slice each span down to the window.
  final windowed = <InlineSpan>[];
  if (start > 0) windowed.add(TextSpan(text: '… ', style: baseStyle));
  for (var i = 0; i < allSpans.length; i++) {
    final span = allSpans[i];
    if (span is! TextSpan || span.text == null || span.text!.isEmpty) continue;
    final (rStart, rEnd) = ranges[i];
    final from = rStart > start ? rStart : start;
    final to = rEnd < end ? rEnd : end;
    if (from >= to) continue;
    final sliced = span.text!.substring(from - rStart, to - rStart);
    if (sliced.isEmpty) continue;
    windowed.add(TextSpan(text: sliced, style: span.style ?? baseStyle));
  }
  if (end < plainText.length) {
    windowed.add(TextSpan(text: ' …', style: baseStyle));
  }

  return _highlightSpans(
    windowed,
    nterms,
    baseStyle: baseStyle,
    isPali: isPali,
    highlightColor: highlightColor,
  );
}

/// Find the first occurrence of any term in [text] and return its
/// `(start, end)` plain-text range, or null if none match.
(int, int)? _firstMatch(
  String text,
  List<String> nterms, {
  required bool isPali,
}) {
  int? bestStart;
  int bestEnd = -1;

  if (isPali) {
    for (final nt in nterms) {
      int pos = 0;
      while (pos <= text.length - nt.length) {
        final candidate = text.substring(pos, pos + nt.length);
        if (normalizePaliFuzzy(candidate) == nt) {
          if (bestStart == null || pos < bestStart) {
            bestStart = pos;
            bestEnd = pos + nt.length;
          }
          break; // first occurrence of this term is enough
        }
        pos++;
      }
    }
  } else {
    final lower = text.toLowerCase();
    for (final nt in nterms) {
      final idx = lower.indexOf(nt);
      if (idx != -1 && (bestStart == null || idx < bestStart)) {
        bestStart = idx;
        bestEnd = idx + nt.length;
      }
    }
  }

  if (bestStart == null) return null;
  return (bestStart, bestEnd);
}

/// Highlight every term match within [spans] using [highlightColor].
///
/// [baseStyle] is the fallback for spans parsed without an explicit style
/// (HtmlTextParser's fast path returns unstyled spans for tag-less text).
List<InlineSpan> _highlightSpans(
  List<InlineSpan> spans,
  List<String> nterms, {
  required TextStyle baseStyle,
  required bool isPali,
  required Color highlightColor,
}) {
  final result = <InlineSpan>[];

  for (final span in spans) {
    if (span is! TextSpan || span.text == null || span.text!.isEmpty) {
      result.add(span);
      continue;
    }

    final spanText = span.text!;
    final spanStyle = span.style ?? baseStyle;

    // Find match ranges in this span's text.
    final ranges = <MapEntry<int, int>>[];
    if (isPali) {
      for (final nt in nterms) {
        int pos = 0;
        while (pos <= spanText.length - nt.length) {
          final candidate = spanText.substring(pos, pos + nt.length);
          if (normalizePaliFuzzy(candidate) == nt) {
            ranges.add(MapEntry(pos, pos + nt.length));
            pos += nt.length;
          } else {
            pos++;
          }
        }
      }
    } else {
      final normalized = spanText.toLowerCase();
      for (final nt in nterms) {
        int pos = 0;
        while (true) {
          final idx = normalized.indexOf(nt, pos);
          if (idx < 0) break;
          ranges.add(MapEntry(idx, idx + nt.length));
          pos = idx + nt.length;
        }
      }
    }

    if (ranges.isEmpty) {
      result.add(TextSpan(text: spanText, style: spanStyle));
      continue;
    }

    // Sort and merge overlapping ranges.
    ranges.sort((a, b) => a.key.compareTo(b.key));
    final merged = <MapEntry<int, int>>[];
    for (final r in ranges) {
      if (merged.isEmpty || r.key > merged.last.value) {
        merged.add(r);
      } else if (r.value > merged.last.value) {
        merged[merged.length - 1] = MapEntry(merged.last.key, r.value);
      }
    }

    // Build highlighted spans.
    int lastEnd = 0;
    for (final r in merged) {
      if (r.key > lastEnd) {
        result.add(TextSpan(
          text: spanText.substring(lastEnd, r.key),
          style: spanStyle,
        ));
      }
      result.add(TextSpan(
        text: spanText.substring(r.key, r.value),
        style: spanStyle.copyWith(
          backgroundColor: highlightColor,
          fontWeight: FontWeight.bold,
        ),
      ));
      lastEnd = r.value;
    }
    if (lastEnd < spanText.length) {
      result.add(TextSpan(text: spanText.substring(lastEnd), style: spanStyle));
    }
  }

  return result;
}
