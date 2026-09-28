// lib/features/reader/providers/tts_speak_unit.dart
//
// Batched paragraph TTS: groups consecutive [TtsLineItem]s that share one
// voice (same paragraph + same Pali/translation side + same language) into a
// single utterance, so the engine speaks a whole paragraph without the
// stop-and-wait gap that one-speak-per-line causes.
//
// Highlight mapping (all pure, unit-tested):
//   unit.text joins its lines with single spaces; [TtsLineRange] records
//   each line's char offsets in that joined string. The engine's progress
//   callback (a char offset in the utterance) maps back to a line via
//   [findLineSlotAtOffset], and to a line-local word range via [toLocal].
//
// Word highlight (removable):
//   Everything word-related is gated behind [kTtsWordHighlightEnabled].
//   To drop word highlighting for performance, set it to false (no progress
//   subscription, no per-word rebuilds, plain line underline only) — or
//   delete the word sections marked `WORD-HIGHLIGHT` in this file plus the
//   `ttsHighlightWordStart/End` params in the reader widgets.
//   Line underline works without word highlight.
//
// Fidelity notes:
//   * Translation lines: speak text == stripped display text (modulo user
//     replacement rules), so word offsets are exact.
//   * Pāli lines: the engine may re-encode the script before speaking, so
//     word offsets are best-effort (word order is preserved, lengths may
//     drift). Line mapping is still correct.
//   * Engines with no progress support (Apple native channel, some OEM
//     voices): no callbacks fire, the unit highlights its first line until
//     the next unit starts. On those platforms batching is disabled and
//     single-line units keep today's per-line behavior (see startReading).

import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/pali_script_converter.dart'
    show TextProcessor, isNonLatinScript;

// ── WORD-HIGHLIGHT kill switch ──────────────────────────────────────────
/// Master switch for spoken-word highlighting. false = line underline only:
/// no `setProgressHandler` subscription, no per-word state updates.
const bool kTtsWordHighlightEnabled = true;

// ── PREFETCH kill switch ────────────────────────────────────────────────
/// Master switch for queue-ahead prefetch (Android QUEUE_ADD): while unit N
/// plays, N+1 is queued so the engine pre-loads the next voice instead of
/// going idle between utterances. This is what removes the Pāli→translation
/// voice-switch delay in "both" mode. false = strict stop-and-wait.
/// Prefetch additionally requires an engine with queue support (see
/// `TtsNotifier.supportsPrefetch`); elsewhere the flag is a no-op.
const bool kTtsPrefetchEnabled = true;

/// Progress callback: char offsets into the caller's utterance text plus
/// the word being spoken.
typedef TtsProgressCallback = void Function(int start, int end, String word);

/// Max chars per utterance. Engines cap input (~4000); stay well below and
/// only ever split on line boundaries, never mid-word.
const int kTtsMaxUnitChars = 1500;

/// Char offsets of one line inside its unit's joined [TtsSpeakUnit.text].
class TtsLineRange {
  final int lineId;
  final int start;
  final int end;

  const TtsLineRange({
    required this.lineId,
    required this.start,
    required this.end,
  });
}

/// One speakable utterance: consecutive lines sharing a voice.
///
/// [lineIndices] parallels [lineRanges] and holds each line's global index
/// in the reader's `lines` list, so progress can sync the line-level
/// `currentIndex` without changing any downstream consumer.
/// [paliRoman] is the joined Roman source for Pāli units (null otherwise);
///
/// the engine re-encodes from it when needed.
class TtsSpeakUnit {
  final int paraId;
  final bool isPali;
  final String? language;
  final String text;
  final List<TtsLineRange> lineRanges;
  final List<int> lineIndices;
  final String? paliRoman;

  const TtsSpeakUnit({
    required this.paraId,
    required this.isPali,
    required this.language,
    required this.text,
    required this.lineRanges,
    required this.lineIndices,
    this.paliRoman,
  });

  bool get isEmpty => text.trim().isEmpty;
}

/// Group [lines] into speakable units.
///
/// Consecutive lines with the same (paraId, isPali, language) merge into one
/// unit. A voice/language switch (e.g. Pāli ↔ translation in "both" mode)
/// always starts a new unit — one utterance can only carry one voice, so
/// alternating content intentionally stays line-by-line. Empty lines are
/// skipped.
///
/// Generic over the line type (with field extractors) so this file stays
/// dependency-free: `tts_reading_provider.dart` owns `TtsLineItem` and would
/// otherwise import-cycle. Pure.
List<TtsSpeakUnit> buildSpeakUnits<T>({
  required List<T> lines,
  required String Function(T) textOf,
  required int Function(T) paraIdOf,
  required int Function(T) lineIdOf,
  required String? Function(T) languageOf,
  required String? Function(T) paliRomanOf,
}) {
  final units = <TtsSpeakUnit>[];
  String? curKey;
  int curParaId = 0;
  bool curIsPali = false;
  String? curLanguage;
  final buf = StringBuffer();
  final ranges = <TtsLineRange>[];
  final indices = <int>[];
  final romanBuf = StringBuffer();

  void flush() {
    if (ranges.isEmpty) return;
    units.add(
      TtsSpeakUnit(
        paraId: curParaId,
        isPali: curIsPali,
        language: curLanguage,
        text: buf.toString(),
        lineRanges: List.of(ranges),
        lineIndices: List.of(indices),
        paliRoman: curIsPali && romanBuf.isNotEmpty ? romanBuf.toString() : null,
      ),
    );
    buf.clear();
    ranges.clear();
    indices.clear();
    romanBuf.clear();
    curKey = null;
  }

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final String text = textOf(line);
    if (text.trim().isEmpty) continue;
    final int paraId = paraIdOf(line);
    final String roman = paliRomanOf(line) ?? '';
    final bool isPali = roman.trim().isNotEmpty;
    final String? language = languageOf(line);
    final key = '$paraId|$isPali|${language ?? ''}';
    final wouldExceed =
        ranges.isNotEmpty && buf.length + 1 + text.length > kTtsMaxUnitChars;
    if (curKey != key || wouldExceed) {
      flush();
      curKey = key;
      curParaId = paraId;
      curIsPali = isPali;
      curLanguage = language;
    }
    final start = buf.isEmpty ? 0 : buf.length + 1;
    if (buf.isNotEmpty) buf.write(' ');
    buf.write(text);
    ranges.add(
      TtsLineRange(
        lineId: lineIdOf(line),
        start: start,
        end: buf.length,
      ),
    );
    indices.add(i);
    if (isPali) {
      if (romanBuf.isNotEmpty) romanBuf.write(' ');
      romanBuf.write(roman);
    }
  }
  flush();
  return units;
}

/// Wrap a single line as its own unit (fallback for engines without progress
/// support — preserves today's per-line highlight exactly). Pure.
TtsSpeakUnit singleLineUnit<T>({
  required T line,
  required int globalIndex,
  required String Function(T) textOf,
  required int Function(T) paraIdOf,
  required int Function(T) lineIdOf,
  required String? Function(T) languageOf,
  required String? Function(T) paliRomanOf,
}) {
  final String text = textOf(line);
  final String? paliRoman = paliRomanOf(line);
  final bool isPali = paliRoman != null && paliRoman.trim().isNotEmpty;
  return TtsSpeakUnit(
    paraId: paraIdOf(line),
    isPali: isPali,
    language: languageOf(line),
    text: text,
    lineRanges: [TtsLineRange(lineId: lineIdOf(line), start: 0, end: text.length)],
    lineIndices: [globalIndex],
    paliRoman: isPali ? paliRoman : null,
  );
}

/// Slot index in [unit.lineRanges] containing char [offset] (clamped to a
/// valid slot). Pure.
int findLineSlotAtOffset(TtsSpeakUnit unit, int offset) {
  final ranges = unit.lineRanges;
  for (var i = 0; i < ranges.length; i++) {
    if (offset < ranges[i].end) return i;
  }
  return ranges.length - 1;
}

/// Convert a unit-level char offset to a line-local offset inside [range]
/// (clamped). Pure.
int toLocal(TtsLineRange range, int offset) =>
    (offset - range.start).clamp(0, range.end - range.start);

// ── Utterance completion queue ──────────────────────────────────────────
// Pure FIFO routing for overlapped utterances (prefetch): while unit N
// plays, N+1 sits queued in the engine. Engine callbacks carry no
// utterance id (flutter_tts exposes none), so routing is positional —
// sound because the engine delivers them in queue order over the FIFO
// platform channel:
//   * start  → oldest unstarted entry (only the head can start playing);
//   * done/cancel/error → head entry;
//   * progress → first entry whose text matches (the plugin echoes the
//     full utterance text; adjacent identical texts resolve to the older
//     entry, which is correct since its events precede its completion
//     that pops it).
// Holds [Completer]s (dart:async, still pure/testable); the engine layer
// only awaits them.

/// One outstanding utterance.
class TtsQueuedUtterance {
  /// Exact text handed to the engine (progress routing key).
  final String speakText;

  /// Caller-side text the progress offsets map back to. Differs from
  /// [speakText] for Pāli (script-converted before speaking); identical
  /// otherwise.
  final String sourceText;

  /// Callbacks for this utterance (set by its speaker).
  final TtsProgressCallback? onProgress;
  final VoidCallback? onStarted;

  bool started = false;
  final Completer<void> completer = Completer<void>();

  TtsQueuedUtterance(
    this.speakText, {
    String? sourceText,
    this.onProgress,
    this.onStarted,
  }) : sourceText = sourceText ?? speakText;

  /// Resolve without throwing when already completed (flush paths race
  /// engine cancel callbacks that pop the same entry).
  void resolve() {
    if (!completer.isCompleted) completer.complete();
  }
}

class TtsUtteranceQueue {
  final Queue<TtsQueuedUtterance> _q = Queue<TtsQueuedUtterance>();

  int get length => _q.length;
  bool get isEmpty => _q.isEmpty;

  /// Enqueue and return the entry whose future the speaker awaits.
  TtsQueuedUtterance enqueue(
    String speakText, {
    String? sourceText,
    TtsProgressCallback? onProgress,
    VoidCallback? onStarted,
  }) {
    final entry = TtsQueuedUtterance(
      speakText,
      sourceText: sourceText,
      onProgress: onProgress,
      onStarted: onStarted,
    );
    _q.add(entry);
    return entry;
  }

  /// Oldest unstarted entry, marked started (a start-event owner).
  TtsQueuedUtterance? markStarted() {
    for (final u in _q) {
      if (!u.started) {
        u.started = true;
        return u;
      }
    }
    return null;
  }

  /// Pops the head (a done/cancel/error owner). Null when empty.
  TtsQueuedUtterance? popHead() => _q.isEmpty ? null : _q.removeFirst();

  /// Removes a specific entry (rejected speaks that will never play).
  bool removeEntry(TtsQueuedUtterance entry) => _q.remove(entry);

  /// First entry whose text matches (a progress-event owner).
  TtsQueuedUtterance? matchByText(String text) {
    for (final u in _q) {
      if (u.speakText == text) return u;
    }
    return null;
  }

  /// Resolve every outstanding entry (engine flush: their callbacks will
  /// never arrive or land in an empty queue and are ignored).
  void resolveAll() {
    while (_q.isNotEmpty) {
      _q.removeFirst().resolve();
    }
  }
}

// ── WORD-HIGHLIGHT model + state ────────────────────────────────────────
// WORD-HIGHLIGHT: delete this section to remove word tracking entirely.
//
// Highlight is tracked by WORD INDEX within the line, not char offsets:
// the engine may speak a different script than the one displayed
// (e.g. Kannada voice, Thai display), and transliteration preserves word
// order/count while changing char lengths — so offsets don't transfer
// across scripts but indices do.

/// Spoken-word position. [wordIndex] is the 0-based index into the line's
/// words; [lineText] is the line's speak substring (unit-text space) so the
/// UI can render exactly what is spoken (Pāli: converted to display script).
class TtsWordHighlight {
  final int paraId;
  final int lineId;
  final bool isPali;
  final int wordIndex;
  final String lineText;

  const TtsWordHighlight({
    required this.paraId,
    required this.lineId,
    required this.isPali,
    required this.wordIndex,
    required this.lineText,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TtsWordHighlight &&
          other.paraId == paraId &&
          other.lineId == lineId &&
          other.isPali == isPali &&
          other.wordIndex == wordIndex &&
          other.lineText == lineText;

  @override
  int get hashCode =>
      Object.hash(paraId, lineId, isPali, wordIndex, lineText);
}

/// Current spoken word (null = none). Updated per progress callback (~a few
/// Hz); only the active paragraph rebuilds from it.
final ttsWordHighlightProvider =
    StateProvider<TtsWordHighlight?>((ref) => null);

// ── WORD-HIGHLIGHT offset helpers ───────────────────────────────────────
// WORD-HIGHLIGHT: delete this section alongside the model above.

/// Char spans of the whitespace-separated words in [text]. Pure.
List<({int start, int end})> ttsWordSpansOf(String text) {
  final spans = <({int start, int end})>[];
  for (final m in RegExp(r'\S+').allMatches(text)) {
    spans.add((start: m.start, end: m.end));
  }
  return spans;
}

/// 0-based index of the word containing char [offset] (clamped to a valid
/// word, 0 when there are none). Pure.
int ttsWordIndexAtOffset(String text, int offset) {
  final spans = ttsWordSpansOf(text);
  if (spans.isEmpty) return 0;
  for (var i = 0; i < spans.length; i++) {
    if (offset < spans[i].end) return i;
  }
  return spans.length - 1;
}

/// Normalize one word for comparison: optionally pivot non-Latin text back
/// to the Sinhala source script, then strip edge punctuation. Pure
/// (a failed conversion keeps the original word).
String ttsComparableWord(String word, {required bool pivotToSource}) {
  var w = word;
  if (pivotToSource && isNonLatinScript(w)) {
    try {
      w = TextProcessor.convertFromMixed(w);
    } catch (_) {}
  }
  return w.replaceAll(
    RegExp(r'^[^\p{L}\p{Nd}]+|[^\p{L}\p{Nd}]+$', unicode: true),
    '',
  );
}

/// Reconcile the offset-based [expectedIndex] with the engine-reported word.
///
/// Some engines (notably a few Indic voices, e.g. Kannada) segment speech
/// differently than whitespace splitting — merging/splitting words or
/// reporting odd ranges. A single such callback would otherwise desync
/// every later word. Re-anchoring on the word TEXT each callback keeps the
/// highlight self-healing: the reported word (pivoted to source script for
/// Pāli) is matched against the line's words nearest the expected position
/// (exact, then prefix either way for merged/split ranges); when nothing
/// matches, the offset-based index stands. Pure.
int ttsReconcileWordIndex({
  required String lineText,
  required int expectedIndex,
  required String reportedWord,
  required bool isPali,
  int window = 4,
}) {
  final spans = ttsWordSpansOf(lineText);
  if (spans.isEmpty || reportedWord.trim().isEmpty) return expectedIndex;
  final sourceWords = [
    for (final s in spans)
      ttsComparableWord(
        lineText.substring(s.start, s.end),
        pivotToSource: false,
      ),
  ];
  final reported = ttsComparableWord(reportedWord, pivotToSource: isPali);
  if (reported.isEmpty) return expectedIndex;
  bool matches(String src) =>
      src.isNotEmpty &&
      (src == reported ||
          src.startsWith(reported) ||
          reported.startsWith(src));
  final exp = expectedIndex.clamp(0, sourceWords.length - 1);
  if (matches(sourceWords[exp])) return exp;
  for (var d = 1; d <= window; d++) {
    for (final i in [exp - d, exp + d]) {
      if (i >= 0 && i < sourceWords.length && matches(sourceWords[i])) {
        return i;
      }
    }
  }
  return exp;
}

/// Translate a char offset in the SPOKEN text back to the SOURCE (unit)
/// text the caller passed in.
///
/// Both share word order and count (space-preserving transliteration, and
/// Pāli numbers are pre-stripped before batching so the engine's own
/// stripping is a no-op): the word containing [spokenOffset] maps to the
/// same-index word in [source], preserving the intra-word fraction. Falls
/// back to proportional mapping when word counts differ (e.g. user TTS
/// replacements that add/remove words). Pure.
int mapSpokenOffsetToSource({
  required String source,
  required String spoken,
  required int spokenOffset,
}) {
  if (source == spoken) return spokenOffset.clamp(0, source.length);
  if (source.isEmpty || spoken.isEmpty) return 0;
  final srcSpans = ttsWordSpansOf(source);
  final postSpans = ttsWordSpansOf(spoken);
  if (srcSpans.isEmpty || postSpans.isEmpty) return 0;
  if (srcSpans.length == postSpans.length) {
    final i = ttsWordIndexAtOffset(spoken, spokenOffset)
        .clamp(0, postSpans.length - 1);
    final post = postSpans[i];
    final denom = post.end - post.start;
    final frac = denom <= 0
        ? 0.0
        : ((spokenOffset - post.start) / denom).clamp(0.0, 1.0);
    final src = srcSpans[i];
    return (src.start + frac * (src.end - src.start))
        .round()
        .clamp(0, source.length);
  }
  final frac = (spokenOffset / spoken.length).clamp(0.0, 1.0);
  return (frac * source.length).round().clamp(0, source.length);
}

// ── WORD-HIGHLIGHT span + decoration helpers ────────────────────────────
// WORD-HIGHLIGHT: delete this section alongside the model above.

/// Plain speak-equivalent of raw reader HTML.
///
/// Must stay in sync with `stripHtmlForTts` (which delegates here): the
/// engine speaks this string, so progress offsets index into it.
String ttsPlainTextForSpeech(String rawHtml) {
  return rawHtml
      .replaceAll(RegExp(r'<i>.*?</i>', caseSensitive: false, dotAll: true), '')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'\\s+'), ' ')
      .trim();
}

/// Shared underline style for the actively-spoken line: subtle wash plus a
/// 2px primary underline inside a rounded card. Single source so Pāli and
/// translation match in light and dark themes.
BoxDecoration ttsActiveLineDecoration(ColorScheme colors) {
  return BoxDecoration(
    color: colors.primary.withValues(alpha: 0.07),
    borderRadius: BorderRadius.circular(10),
    border: Border(
      bottom: BorderSide(color: colors.primary, width: 2.5),
    ),
  );
}

/// Split [plainText] into spans with the [wordIndex]-th word filled as a
/// rounded pill. Out-of-range indices degrade to plain text (never throws).
/// The pill is a WidgetSpan (TextStyle backgrounds can't round corners);
/// selection skips it, which is fine for the transient spoken line. Pure.
List<InlineSpan> buildTtsWordIndexSpans({
  required String plainText,
  required TextStyle baseStyle,
  required ColorScheme colors,
  required int wordIndex,
}) {
  final spans = ttsWordSpansOf(plainText);
  if (spans.isEmpty || wordIndex < 0 || wordIndex >= spans.length) {
    return [TextSpan(text: plainText, style: baseStyle)];
  }
  final target = spans[wordIndex];
  final out = <InlineSpan>[];
  if (target.start > 0) {
    out.add(
      TextSpan(text: plainText.substring(0, target.start), style: baseStyle),
    );
  }
  out.add(
    WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.30),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          plainText.substring(target.start, target.end),
          style: baseStyle.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    ),
  );
  if (target.end < plainText.length) {
    out.add(
      TextSpan(text: plainText.substring(target.end), style: baseStyle),
    );
  }
  return out;
}
