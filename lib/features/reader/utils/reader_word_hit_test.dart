import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show GlobalKey;

/// Cleans a raw Pāli word by removing non-word characters.
String cleanPali(String text) {
  return text
      .replaceAll(
        RegExp(r"[^\wāīūōṅñṭḍṇḷṃĀĪŪŌṄÑṬḌṆḶṀ\s]"),
        '',
      )
      .trim();
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
  final boundary = paragraph.getWordBoundary(textPosition);
  if (!boundary.isValid || boundary.isCollapsed) return null;

  final fullText = paragraph.text.toPlainText();
  if (boundary.end > fullText.length) return null;

  final rawWord = fullText.substring(boundary.start, boundary.end);
  return cleanPali(rawWord);
}
