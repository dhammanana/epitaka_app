import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show GlobalKey;

import '../../../core/database/dpd_dictionary_database.dart';
import '../../../core/utils/pali_script_converter.dart';

/// Cleans a raw Pāli word by removing non-word characters.
///
/// Unicode-aware: keeps every letter / combining mark / number from any
/// language (Pāli diacritics, Vietnamese đ ư ơ, etc.), so the same cleaner
/// is safe for both Pāli and translation words.
String cleanPali(String text) {
  return text
      .replaceAll(RegExp(r'[^\p{L}\p{M}\p{Nd}_\s]', unicode: true), '')
      .trim();
}

/// Cleans a raw translation word (any language) by stripping surrounding
/// punctuation while preserving all Unicode letters, combining marks and
/// numbers inside the word (e.g. Vietnamese "được" stays intact).
String cleanTranslationWord(String text) {
  return text
      .replaceAll(RegExp(r'[^\p{L}\p{M}\p{Nd}_\s]', unicode: true), '')
      .trim();
}

/// Characters that terminate a Pāli word in ANY script: whitespace and
/// sentence punctuation (Latin, plus script-specific marks: Devanagari/
/// Sinhala dandas, Tibetan tsheg + dandas, Sinhala kunddaliya). Everything
/// else — letters of any script, combining marks, the Tamil superscripts
/// ² ³ ⁴, ZWJ/ZWNJ, digits — belongs inside the word.
final RegExp _kWordTerminator = RegExp(
  r'''[\s.,;:!?()\[\]{}“”"«»‘’'…*·।॥<>།༎་෴§\u2013\u2014]''',
);

/// Returns the word range covering [tapOffset] in [text], expanding outward
/// across every adjacent character that belongs to a word.
///
/// This deliberately does NOT rely on [RenderParagraph.getWordBoundary]:
/// that engine API splits words in several scripts — e.g. Myanmar
/// "ဘဂဝတော" → "ဘ", "ဂ", "ဝ", "တော", Thai "ภควโต" → "ภคว", "โต" and
/// Tamil "த⁴ம்ம" → "த", "⁴", "ம்ம" — so a double-tap would only extract
/// part of the word. Words in this app are always space-separated (the
/// source Pāli is romanised with spaces and conversion preserves them), so
/// expanding to the nearest whitespace/punctuation on both sides is exact
/// for every script.
///
/// Returns [TextRange.empty] when [tapOffset] falls on whitespace or
/// punctuation (there is no word to look up there) or when [text] is empty.
TextRange wordRangeAt(String text, int tapOffset) {
  if (text.isEmpty) return TextRange.empty;
  final offset = tapOffset.clamp(0, text.length - 1);
  if (_kWordTerminator.hasMatch(text[offset])) return TextRange.empty;
  var start = offset;
  var end = offset;
  while (start > 0 && !_kWordTerminator.hasMatch(text[start - 1])) {
    start--;
  }
  while (end < text.length && !_kWordTerminator.hasMatch(text[end])) {
    end++;
  }
  return TextRange(start: start, end: end);
}

/// Characters that may form a CLOSING quote run between a word and its
/// joined dictionary form: CST writes closing quotes (and the verse elision
/// mark) as a space-separated run of 1–4 of these: `oghamatarin ’’’ ti`,
/// `dhammapuṇṇo ’ va`. Opening quotes (`‘` U+2018) are NOT in this set —
/// a word before an opening quote is already complete (measured: joining
/// across opening quotes produces only false positives).
const String _kClosingQuotes = '\u2019\'';
final RegExp _kNonLetters = RegExp(r'[^\p{L}\p{M}\p{Nd}]', unicode: true);

/// Whitespace for the quote-join scan — same `\s` class [wordRangeAt] uses
/// to terminate words, so the two routines agree about gaps (NBSP, tabs,
/// newlines included).
final RegExp _kJoinWhitespace = RegExp(r'\s');

/// Builds the quote-run join candidate for a tapped word, or null.
///
/// [wordEnd] is the end offset of the tapped word in [fullText];
/// [wordPrefix] is the cleaned Roman word itself. When the text at
/// [wordEnd] is `whitespace + closing-quote run (1–4) + whitespace +
/// token`, the CST source means the word and the token are ONE dictionary
/// word with the quote run marking an elided junction (`oghamatarin ’’’ ti`
/// → `oghamatarinti`; `dhammapuṇṇo ’ va` → `dhammapuṇṇova`). The candidate
/// is therefore [wordPrefix] + that token, joined VERBATIM — no letter
/// replacement, no folding; a wrong candidate simply misses the dictionary
/// like the bare word would.
///
/// [fullText] is in the DISPLAY script (the reader renders Sinhala,
/// Myanmar, …), so the raw token is pushed through the same
/// `convertToRomanPali` + `cleanPali` pipeline as the tapped word before
/// joining — otherwise the candidate would be a mixed-script key that can
/// never match a Roman DPD lookup key. Non-letter residue (markup
/// leftovers) is stripped along the way; an empty token or any non-quote
/// content after the word returns null.
String? quoteJoinCandidate(String fullText, int wordEnd, String wordPrefix) {
  bool isSpace(int i) => _kJoinWhitespace.hasMatch(fullText[i]);
  var i = wordEnd;
  // Whitespace between word and quote run.
  while (i < fullText.length && isSpace(i)) {
    i++;
  }
  // Closing quote run, 1–4 characters.
  var quotes = 0;
  while (i < fullText.length &&
      quotes < 4 &&
      _kClosingQuotes.contains(fullText[i])) {
    i++;
    quotes++;
  }
  if (quotes == 0) return null;
  // Whitespace between quote run and the joined token.
  while (i < fullText.length && isSpace(i)) {
    i++;
  }
  if (i >= fullText.length || isSpace(i)) return null;
  // Token up to the next whitespace, letters only.
  var j = i;
  while (j < fullText.length && !isSpace(j)) {
    j++;
  }
  // Push the raw (display-script) token through the same Roman pipeline
  // as the tapped word, so the candidate matches Roman DPD lookup keys in
  // every display script.
  final rawToken = fullText.substring(i, j).replaceAll(_kNonLetters, '');
  final token = cleanPali(convertToRomanPali(rawToken));
  if (token.isEmpty) return null;
  return wordPrefix + token;
}

/// Whether a DPD lookup row carries anything worth showing: headwords,
/// deconstructor candidates or EPD HTML. A bare null row or an empty one
/// counts as a miss for the two-stage pick below.
bool lookupRowHasContent(DpdLookupRow? row) {
  if (row == null) return false;
  return row.headwords.isNotEmpty ||
      row.deconstructor.isNotEmpty ||
      (row.epd?.isNotEmpty ?? false);
}

/// Two-stage lookup pick for the reader tap path: the bare tapped [word]
/// keeps priority; the quote-run join candidate [joinedWord] is routed only
/// when the bare word misses entirely AND the joined form would resolve.
/// When both miss (or there is no candidate), the bare word is returned so
/// the dictionary shows its usual empty state for what was tapped.
String pickLookupWord(
  String word,
  String? joinedWord,
  DpdLookupRow? bare,
  DpdLookupRow? joined,
) {
  if (joinedWord == null) return word;
  if (lookupRowHasContent(bare)) return word;
  return lookupRowHasContent(joined) ? joinedWord : word;
}

/// Metadata attached to a line or paragraph render box for hit testing.
class ReaderLineMetadata {
  final int paraId;
  final int? lineId;
  final String segment; // 'pali' or 'translation'
  final String? langCode;

  const ReaderLineMetadata({
    required this.paraId,
    this.lineId,
    this.segment = 'pali',
    this.langCode,
  });
}

/// Result of a word hit-test in the reader view.
class ReaderWordHitResult {
  /// Cleaned Roman word for dictionary lookup.
  final String word;

  /// Raw word in the display script as extracted from the render paragraph.
  final String rawWord;

  /// Paragraph ID containing the hit word, if available from metadata.
  final int? paraId;

  /// Line ID containing the hit word, if available from metadata (-1 for heading, null for joined).
  final int? lineId;

  /// Segment type ('pali' or 'translation').
  final String segment;

  /// Language code for translation segments.
  final String? langCode;

  /// Character range of the word within the RenderParagraph text.
  final TextRange range;

  /// Quote-run join candidate (`oghamatarin ’’’ ti` → `oghamatarinti`),
  /// built by [quoteJoinCandidate] when the tapped word is directly
  /// followed by a closing quote run. Null for translation segments and
  /// when no quote run follows. The lookup stage tries [word] first and
  /// only falls back to this on a total miss.
  final String? joinedWord;

  const ReaderWordHitResult({
    required this.word,
    required this.rawWord,
    this.paraId,
    this.lineId,
    this.segment = 'pali',
    this.langCode,
    required this.range,
    this.joinedWord,
  });
}

/// Hit-tests the render tree under [contentHitTestKey] at [globalPosition]
/// and returns the detailed hit result at that position, or `null` if no word is found.
ReaderWordHitResult? hitTestWordAt(
  GlobalKey contentHitTestKey,
  Offset globalPosition,
) {
  final context = contentHitTestKey.currentContext;
  if (context == null) return null;

  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox) return null;

  final local = renderObject.globalToLocal(globalPosition);
  final result = BoxHitTestResult();
  renderObject.hitTest(result, position: local);

  // Walk the hit-test path to find the RenderParagraph and any ReaderLineMetadata.
  RenderParagraph? paragraph;
  ReaderLineMetadata? lineMetadata;

  for (final entry in result.path) {
    final target = entry.target;
    if (target is RenderMetaData && target.metaData is ReaderLineMetadata) {
      lineMetadata ??= target.metaData as ReaderLineMetadata;
    }
    if (target is RenderParagraph && paragraph == null) {
      paragraph = target;
    }
  }

  // Fallback: walk up the parent chain from the first hit target.
  if (paragraph == null && result.path.isNotEmpty) {
    RenderObject? node = result.path.first.target as RenderObject?;
    while (node != null) {
      if (node is RenderMetaData &&
          node.metaData is ReaderLineMetadata &&
          lineMetadata == null) {
        lineMetadata = node.metaData as ReaderLineMetadata;
      }
      if (node is RenderParagraph && paragraph == null) {
        paragraph = node;
      }
      node = node.parent;
    }
  }

  if (paragraph == null) return null;

  // Skip paragraphs that are NOT part of the selectable region: widgets like
  // the book-link chips are wrapped in SelectionContainer.disabled, which
  // gives their RenderParagraphs a null registrar. Tapping such a widget
  // should perform its own action (e.g. open the linked book), not a
  // dictionary lookup.
  if (paragraph.registrar == null) return null;

  // Convert to paragraph-local coordinates.
  final paragraphOrigin = paragraph.localToGlobal(Offset.zero);
  final localInParagraph = globalPosition - paragraphOrigin;
  if (localInParagraph.dx < 0 ||
      localInParagraph.dy < 0 ||
      localInParagraph.dx > paragraph.size.width ||
      localInParagraph.dy > paragraph.size.height) {
    return null;
  }

  final textPosition = paragraph.getPositionForOffset(localInParagraph);
  final fullText = paragraph.text.toPlainText();
  final range = wordRangeAt(fullText, textPosition.offset);
  if (range.isCollapsed) return null;

  final rawWord = fullText.substring(range.start, range.end);
  final isTranslation = lineMetadata?.segment == 'translation';
  // Translation words (Vietnamese, English, …) must NOT go through Pāli
  // script conversion or Pāli-only filtering — clean them with the
  // language-agnostic cleaner so diacritics survive.
  final cleaned = isTranslation
      ? cleanTranslationWord(rawWord)
      : cleanPali(convertToRomanPali(rawWord));
  if (cleaned.isEmpty) return null;

  return ReaderWordHitResult(
    word: cleaned,
    rawWord: rawWord,
    paraId: lineMetadata?.paraId,
    lineId: lineMetadata?.lineId,
    segment: lineMetadata?.segment ?? 'pali',
    langCode: lineMetadata?.langCode,
    range: range,
    // CST quote-run join candidate (`oghamatarin ’’’ ti` →
    // `oghamatarinti`), Pāli segments only — translation words are never
    // quote-joined.
    joinedWord: isTranslation
        ? null
        : quoteJoinCandidate(fullText, range.end, cleaned),
  );
}

/// Hit-tests the render tree under [contentHitTestKey] at [globalPosition]
/// and returns the word at that position, or `null` if no word is found.
///
/// This walks the hit-test path to find the [RenderParagraph] under the tap,
/// then uses [getWordBoundary] to extract the word. The function is fully
/// self-contained and does not depend on any widget state or provider.
///
/// [contentHitTestKey] should be a [GlobalKey] attached to a [Listener] or
/// other widget whose render object is a [RenderBox] that contains the text
/// paragraphs (e.g. the reader content subtree). We deliberately do NOT
/// hit-test from [SelectionArea]'s render object, whose `hitTest` is
/// overridden to only consider selection handles/toolbar.
String? selectWordAt(GlobalKey contentHitTestKey, Offset globalPosition) {
  return hitTestWordAt(contentHitTestKey, globalPosition)?.word;
}
