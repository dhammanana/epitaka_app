import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show GlobalKey;

import '../../../core/utils/pali_script_converter.dart';

/// Cleans a raw Pāli word by removing non-word characters.
String cleanPali(String text) {
  return text
      .replaceAll(
        RegExp(r"[^\wāīūōṅñṭḍṇḷṃĀĪŪŌṄÑṬḌṆḶṀ\s]"),
        '',
      )
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
  final context = contentHitTestKey.currentContext;
  if (context == null) return null;

  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox) return null;

  final local = renderObject.globalToLocal(globalPosition);
  final result = BoxHitTestResult();
  renderObject.hitTest(result, position: local);

  // Walk the hit-test path to find the first RenderParagraph.
  RenderParagraph? paragraph;
  for (final entry in result.path) {
    final target = entry.target;
    if (target is RenderParagraph) {
      paragraph = target;
      break;
    }
  }

  // Fallback: walk up the parent chain from the first hit target.
  if (paragraph == null && result.path.isNotEmpty) {
    RenderObject? node = result.path.first.target as RenderObject?;
    while (node != null) {
      if (node is RenderParagraph) {
        paragraph = node;
        break;
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
  // Convert from any Pali script to Roman for dictionary lookup.
  final romanWord = convertToRomanPali(rawWord);
  return cleanPali(romanWord);
}
