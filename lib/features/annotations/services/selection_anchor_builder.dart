// lib/features/annotations/services/selection_anchor_builder.dart
//
// Turns a SelectionArea selection into precise annotation anchors.
//
// An anchor identifies WHERE in a book the selection sits:
//   • structural — (paraId, lineId, segment, langCode) + char offsets in the
//     segment's stripped text,
//   • text-quote — exact/prefix/suffix text so the highlight can be
//     re-anchored later even if the displayed text changed (script switch,
//     font size, whitespace, …).
//
// The matching strategy mirrors the reader copy service: it rebuilds the
// exact *displayed* text (script conversion + tag stripping + whitespace
// normalization) from the loaded paragraphs, concatenates segments the same
// way SelectionArea does, locates the selected plain text inside it, then
// maps the boundaries back to per-segment stripped-text offsets.

import 'dart:developer' as developer;

import '../../../core/utils/pali_script_converter.dart' show Script;
import '../../../core/utils/pali_text_utils.dart'
    show convertPaliToScriptPreservingHtml;
import '../../reader/providers/reader_provider.dart';

/// A single anchor produced from a selection.
class SelectionAnchor {
  final int paraId;
  final int lineId;

  /// 'pali' | 'translation'. Headings produce segment='pali' with
  /// lineId == -1 (a pseudo-line) so highlights on headings still render.
  final String segment;
  final String? langCode;

  /// Offsets in the segment's stripped (tag-free) text.
  final int startOffset;
  final int endOffset;

  /// Text-quote selector (stripped, non-normalized text).
  final String exactText;
  final String prefixText;
  final String suffixText;

  const SelectionAnchor({
    required this.paraId,
    required this.lineId,
    required this.segment,
    this.langCode,
    required this.startOffset,
    required this.endOffset,
    required this.exactText,
    required this.prefixText,
    required this.suffixText,
  });

  /// The visible text (with tags intact) of the anchored range — used to
  /// render the annotation's preview text in panels.
  String? get displayText => exactText.isEmpty ? null : exactText;
}

/// One selectable unit of text used for matching (mirrors the copy
/// service's internal segment but keeps the data we need for anchors).
class _Segment {
  final int paraId;
  final int lineId;
  final bool isPali;
  final String? langCode;
  final String strippedText; // display text with tags removed

  /// Index of this segment's paragraph in the FULL paragraphs list (not the
  /// search window). Used to prefer the occurrence nearest the visible
  /// range when the same text repeats across paragraphs.
  final int paragraphIndex;

  _Segment({
    required this.paraId,
    required this.lineId,
    required this.isPali,
    this.langCode,
    required this.strippedText,
    required this.paragraphIndex,
  });
}

/// Builds [SelectionAnchor]s from the current selection.
class SelectionAnchorBuilder {
  SelectionAnchorBuilder._();

  /// Score penalty applied to every occurrence OUTSIDE the visible
  /// paragraph range — large enough that any in-range match (max realistic
  /// score is a few hundred) always beats any out-of-range one.
  static const int _kOutOfRangePenalty = 1000000;

  /// Resolve the selected [plainText] (as reported by SelectionArea) against
  /// the loaded paragraphs and produce one anchor per matched segment.
  ///
  /// Returns an empty list when the selection can't be matched (the caller
  /// should then fall back to a paragraph-level anchor or bail out).
  static List<SelectionAnchor> buildAnchors({
    required List<ParagraphData> paragraphs,
    required String plainText,
    required Script script,
    required Set<String> enabledLangCodes,
    int visibleStartIndex = 0,
    int visibleEndIndex = 0,
  }) {
    final needle = _normalize(plainText.replaceAll('\u{FFFC}', '').trim());
    if (needle.isEmpty || paragraphs.isEmpty) return const [];

    // Constrain matching to a window around the visible range (same as the
    // copy service) — searching the whole book is wasteful and can match
    // identical text far away.
    final searchStart = (visibleStartIndex - 50).clamp(0, paragraphs.length - 1);
    final searchEnd = (visibleEndIndex + 50).clamp(0, paragraphs.length - 1);
    final searchRange = paragraphs.sublist(searchStart, searchEnd + 1);

    final segments = _buildSegments(
      searchRange,
      script,
      enabledLangCodes,
      searchStartIndex: searchStart,
    );
    if (segments.isEmpty) return const [];

    // Concatenate normalized segment text, tracking per-segment ranges and
    // a normalized→stripped offset map (SelectionArea concatenates selectable
    // children with NO separator).
    final combined = StringBuffer();
    final segStart = <int>[];
    final segEnd = <int>[];
    final segNormMap = <List<int>>[];

    for (final seg in segments) {
      final (normText, normMap) = _normalizeWithMap(seg.strippedText);
      segStart.add(combined.length);
      combined.write(normText);
      segEnd.add(combined.length);
      // normMap already maps normalized offsets → STRIPPED-text indices.
      // Do NOT compose it with a stripped→tagged map here (as the copy
      // service does for its tagged-space cuts) — these offsets are used
      // to cut `strippedText`, so tagged-space indices overshoot whenever
      // the selection contains HTML markup, throwing RangeError and
      // silently blocking highlight/note creation.
      segNormMap.add(normMap);
    }

    final combinedText = combined.toString();

    // Find the BEST occurrence of the needle, not the first one. Pāli texts
    // repeat formulaic passages constantly (e.g. "Yasmiṃ, upāli, vatthusmiṃ
    // hoti saṅghassa bhaṇḍanaṃ …" appears at para 2701, 2702 AND 2703 of
    // Vin-iii), so the first `indexOf` match in the window is frequently
    // several paragraphs ABOVE the one the user actually selected — the
    // highlight then gets stored against the wrong (off-screen) paragraph
    // and the render path, which paints only the exact stored paraId/lineId,
    // shows nothing where the user is looking. This is why highlights at
    // the TOP of a book worked (the first occurrence is the right one) but
    // deep in the book they silently didn't. Prefer the occurrence whose
    // paragraph is inside the visible range; among in-range candidates pick
    // the one nearest the range center; out-of-range candidates are ranked
    // by distance to the nearest boundary.
    final matchPos = _bestMatchPosition(
      combinedText: combinedText,
      needle: needle,
      segments: segments,
      segStart: segStart,
      segEnd: segEnd,
      visibleStartIndex: visibleStartIndex,
      visibleEndIndex: visibleEndIndex,
    );
    if (matchPos < 0) {
      developer.log(
        '[ANCHOR] no match for selection len=${needle.length}',
        name: 'epitaka.annotations',
      );
      return const [];
    }
    final matchEnd = matchPos + needle.length;

    // Locate the segment(s) spanned by the match.
    final startSegIdx = _segmentIndexAt(matchPos, segStart, segEnd);
    final endSegIdx = _segmentIndexAt(matchEnd, segStart, segEnd);
    if (startSegIdx < 0 || endSegIdx < 0 || startSegIdx > endSegIdx) {
      return const [];
    }
    final startOffInSeg = matchPos - segStart[startSegIdx];
    final endOffInSeg = matchEnd - segStart[endSegIdx];

    final anchors = <SelectionAnchor>[];
    for (int i = startSegIdx; i <= endSegIdx; i++) {
      final seg = segments[i];
      final map = segNormMap[i];

      // Map normalized-space boundaries back to stripped-space indices.
      int cutStart = 0;
      int cutEnd = seg.strippedText.length;
      if (i == startSegIdx) {
        cutStart = startOffInSeg < map.length
            ? map[startOffInSeg]
            : seg.strippedText.length;
      }
      if (i == endSegIdx) {
        if (endOffInSeg <= 0) {
          cutEnd = 0;
        } else if (endOffInSeg - 1 < map.length) {
          cutEnd = map[endOffInSeg - 1] + 1;
        } else {
          cutEnd = seg.strippedText.length;
        }
      }
      if (cutStart > cutEnd) cutStart = cutEnd;

      final exact = seg.strippedText.substring(cutStart, cutEnd);
      if (exact.isEmpty) continue;

      anchors.add(
        SelectionAnchor(
          paraId: seg.paraId,
          lineId: seg.lineId,
          segment: seg.isPali ? 'pali' : 'translation',
          langCode: seg.isPali ? null : seg.langCode,
          startOffset: cutStart,
          endOffset: cutEnd,
          exactText: exact,
          prefixText: _surrounding(seg.strippedText, cutStart, before: true),
          suffixText: _surrounding(seg.strippedText, cutEnd, before: false),
        ),
      );
    }
    return anchors;
  }

  /// Build the display segments (headings, Pāli lines, enabled translations)
  /// in the same order SelectionArea would present them.
  static List<_Segment> _buildSegments(
    List<ParagraphData> paragraphs,
    Script script,
    Set<String> enabledLangCodes, {
    int searchStartIndex = 0,
  }) {
    final segments = <_Segment>[];

    for (int i = 0; i < paragraphs.length; i++) {
      final para = paragraphs[i];
      final paragraphIndex = searchStartIndex + i;
      if (para.heading != null && para.heading!.title.trim().isNotEmpty) {
        final tagged = convertPaliToScriptPreservingHtml(
          para.heading!.title.trim(),
          script,
        );
        final stripped = _stripTags(tagged);
        if (stripped.isNotEmpty) {
          segments.add(
            _Segment(
              paraId: para.paraId,
              lineId: -1,
              isPali: true,
              strippedText: stripped,
              paragraphIndex: paragraphIndex,
            ),
          );
        }
      }

      for (final line in para.lines) {
        if (line.paliText != null && line.paliText!.trim().isNotEmpty) {
          final tagged = convertPaliToScriptPreservingHtml(
            line.paliText!.trim(),
            script,
          );
          final stripped = _stripTags(tagged);
          if (stripped.isNotEmpty) {
            segments.add(
              _Segment(
                paraId: para.paraId,
                lineId: line.lineId,
                isPali: true,
                strippedText: stripped,
                paragraphIndex: paragraphIndex,
              ),
            );
          }
        }

        final entries = enabledLangCodes.isNotEmpty
            ? line.translations.entries.where(
                (e) => enabledLangCodes.contains(e.key),
              )
            : line.translations.entries;
        for (final entry in entries) {
          final tagged = entry.value.trim();
          if (tagged.isEmpty) continue;
          final stripped = _stripTags(tagged);
          if (stripped.isEmpty) continue;
          segments.add(
            _Segment(
              paraId: para.paraId,
              lineId: line.lineId,
              isPali: false,
              langCode: entry.key,
              strippedText: stripped,
              paragraphIndex: paragraphIndex,
            ),
          );
        }
      }
    }
    return segments;
  }

  /// Score how good a match starting in [paragraphIndex] is: 0 when the
  /// paragraph is inside the visible range (tie-broken by distance to the
  /// range center), otherwise [_kOutOfRangePenalty] + distance to the
  /// nearest boundary. Lower is better.
  static int _matchScore(int paragraphIndex, int visibleStart, int visibleEnd) {
    final inRange =
        paragraphIndex >= visibleStart && paragraphIndex <= visibleEnd;
    if (inRange) {
      final center = (visibleStart + visibleEnd) ~/ 2;
      return (paragraphIndex - center).abs();
    }
    final dist = paragraphIndex < visibleStart
        ? visibleStart - paragraphIndex
        : paragraphIndex - visibleEnd;
    return _kOutOfRangePenalty + dist;
  }

  /// Index of the segment containing [offset] in the combined text, or -1.
  /// Boundary convention matches the match-spanning logic: an offset exactly
  /// on a segment boundary belongs to the segment it ENDS (the earlier one),
  /// so scoring and anchor generation always agree on which paragraph an
  /// occurrence belongs to.
  static int _segmentIndexAt(int offset, List<int> segStart, List<int> segEnd) {
    for (int i = 0; i < segStart.length; i++) {
      if (offset >= segStart[i] && offset <= segEnd[i]) {
        return i;
      }
    }
    return -1;
  }

  /// Scan ALL occurrences of [needle] in [combinedText] and return the
  /// position of the best-scoring one, or -1 when the needle never appears.
  static int _bestMatchPosition({
    required String combinedText,
    required String needle,
    required List<_Segment> segments,
    required List<int> segStart,
    required List<int> segEnd,
    required int visibleStartIndex,
    required int visibleEndIndex,
  }) {
    int bestPos = -1;
    int bestScore = 1 << 62;
    var from = 0;
    while (true) {
      final pos = combinedText.indexOf(needle, from);
      if (pos < 0) break;

      // Map this occurrence back to the paragraph its start falls in.
      final segIdx = _segmentIndexAt(pos, segStart, segEnd);
      if (segIdx >= 0) {
        final score = _matchScore(
          segments[segIdx].paragraphIndex,
          visibleStartIndex,
          visibleEndIndex,
        );
        if (score < bestScore) {
          bestScore = score;
          bestPos = pos;
        }
      }
      from = pos + 1;
    }
    return bestPos;
  }

  /// Up to ~30 chars of stripped text before ([before] true) or after
  /// ([before] false) a boundary, used as the quote selector context.
  static String _surrounding(String text, int boundary, {required bool before}) {
    if (before) {
      final start = (boundary - 30).clamp(0, text.length);
      return text.substring(start, boundary);
    }
    final end = (boundary + 30).clamp(0, text.length);
    return text.substring(boundary, end);
  }

  /// Strip HTML tags from [html], returning the plain text.
  ///
  /// `<br>` is normalized to `\n` FIRST (matching how the display parser
  /// renders it) so the offset space here matches the space the reader
  /// paints highlights in.
  static String _stripTags(String html) {
    final normalized = html.replaceAll('<br>', '\n').replaceAll('<br/>', '\n');
    final buf = StringBuffer();
    bool inTag = false;
    for (int i = 0; i < normalized.length; i++) {
      final c = normalized[i];
      if (c == '<') {
        inTag = true;
        continue;
      }
      if (c == '>') {
        inTag = false;
        continue;
      }
      if (!inTag) {
        buf.write(c);
      }
    }
    return buf.toString();
  }

  /// Collapse whitespace runs to a single space, mapping each output char
  /// index back to the input index it came from.
  static (String, List<int>) _normalizeWithMap(String s) {
    final buf = StringBuffer();
    final map = <int>[];
    bool inWhitespace = false;
    for (int i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == ' ' || c == '\n' || c == '\t' || c == '\r') {
        if (!inWhitespace) {
          buf.write(' ');
          map.add(i);
          inWhitespace = true;
        }
      } else {
        buf.write(c);
        map.add(i);
        inWhitespace = false;
      }
    }
    return (buf.toString(), map);
  }

  /// Normalize whitespace for matching.
  static String _normalize(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();
}
