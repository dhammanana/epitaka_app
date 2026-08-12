// lib/features/annotations/services/highlight_interval_resolver.dart
//
// Re-anchors stored annotations onto the *currently displayed* stripped text
// of a segment. Offsets can drift when the reader changes script, font size
// or translation version, so the text-quote selector (exact/prefix/suffix)
// is the source of truth; structural offsets are only a hint.
//
// Strategy per annotation:
//   1. If the stored offsets land on exactly the stored exact text, use them.
//   2. Otherwise search for the exact text in the displayed text.
//   3. If that fails, try converting the exact text back to Roman and
//      re-converting to the *current* script (handles script switches, e.g.
//      the user highlighted in Sinhala and now reads in Devanagari).
//   4. As a last resort, clamp the stored offsets into range.

import '../../../core/utils/pali_script_converter.dart'
    show Script, convertToRomanPali;
import '../../../core/utils/pali_text_utils.dart' show convertPaliToScript;
import '../models/annotation.dart';

/// A resolved paint interval in stripped-text character space.
class ResolvedHighlight {
  final int start;
  final int end;
  final HighlightColor color;

  /// The annotation id — lets callers dedupe overlapping highlights.
  final String id;

  const ResolvedHighlight({
    required this.start,
    required this.end,
    required this.color,
    required this.id,
  });
}

class HighlightIntervalResolver {
  HighlightIntervalResolver._();

  /// Resolve [annotations] that target [segmentType] (+ [langCode] for
  /// translations) onto [strippedText]. Returns intervals sorted by start,
  /// with overlaps merged (later annotations win the color).
  static List<ResolvedHighlight> resolve({
    required String strippedText,
    required List<Annotation> annotations,
    required String segmentType,
    String? langCode,

    /// Current display script. Used to re-anchor highlights that were
    /// created while the reader showed a *different* script (the quote text
    /// is converted Roman → current script before searching).
    Script script = Script.roman,
  }) {
    if (strippedText.isEmpty || annotations.isEmpty) return const [];

    final resolved = <ResolvedHighlight>[];
    for (final a in annotations) {
      if (a.segment != segmentType) continue;
      if (segmentType == 'translation' && a.langCode != langCode) continue;
      if (a.exactText == null || a.exactText!.isEmpty) continue;
      if (a.paraId == null || a.lineId == null) continue;

      final range = _locate(
        strippedText,
        exactText: a.exactText!,
        startHint: a.startOffset,
        endHint: a.endOffset,
        script: script,
      );
      if (range == null) continue;
      resolved.add(
        ResolvedHighlight(
          start: range.$1,
          end: range.$2,
          color: a.color ?? HighlightColor.yellow,
          id: a.id,
        ),
      );
    }

    resolved.sort((x, y) {
      final c = x.start.compareTo(y.start);
      return c != 0 ? c : x.end.compareTo(y.end);
    });

    // Merge overlapping intervals: keep the longest, latest-painted color.
    final merged = <ResolvedHighlight>[];
    for (final r in resolved) {
      if (merged.isEmpty) {
        merged.add(r);
        continue;
      }
      final last = merged.last;
      if (r.start <= last.end) {
        if (r.end > last.end) {
          merged[merged.length - 1] = ResolvedHighlight(
            start: last.start,
            end: r.end,
            color: r.color,
            id: last.id,
          );
        }
      } else {
        merged.add(r);
      }
    }
    return merged;
  }

  /// Locate [exactText] in [strippedText], preferring the stored offsets when
  /// they line up with the quote text. Returns (start, end) or null.
  static (int, int)? _locate(
    String strippedText, {
    required String exactText,
    int? startHint,
    int? endHint,
    required Script script,
  }) {
    final len = strippedText.length;
    final exact = exactText.trim();
    if (exact.isEmpty || len == 0) return null;

    // 1) Stored offsets line up with the quote text → use them directly.
    if (startHint != null && endHint != null) {
      final s = startHint.clamp(0, len);
      final e = endHint.clamp(s, len);
      if (e > s) {
        final slice = strippedText.substring(s, e);
        if (_normWhitespace(slice) == _normWhitespace(exact)) {
          return (s, e);
        }
      }
    }

    // 2) Search the displayed text for the exact text.
    var idx = strippedText.indexOf(exact);
    if (idx >= 0) return (idx, idx + exact.length);

    // 3) Script switch: exact text was captured in another script. Round-trip
    // it Roman → current script and search again.
    try {
      final roman = convertToRomanPali(exact);
      if (roman.isNotEmpty && roman != exact) {
        final converted = convertPaliToScript(roman, script);
        if (converted.isNotEmpty && converted != exact) {
          idx = strippedText.indexOf(converted);
          if (idx >= 0) return (idx, idx + converted.length);
        }
      }
    } catch (_) {}

    // 4) Clamp stored offsets as a best-effort fallback.
    if (startHint != null && endHint != null) {
      final s = startHint.clamp(0, len);
      final e = endHint.clamp(s, len);
      if (e > s) return (s, e);
    }
    return null;
  }

  static String _normWhitespace(String s) =>
      s.replaceAll(RegExp(r'\s+'), ' ').trim();
}
