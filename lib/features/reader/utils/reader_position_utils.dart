import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../providers/reader_provider.dart';

/// Get the [paraId] of the paragraph the user is actually reading, based on
/// [positions] and [readerState].
///
/// Returns the [paraId] of the first paragraph whose leading edge is past
/// [threshold] (fraction of the viewport from the top), falling back to the
/// topmost visible paragraph if none is found past that threshold. Returns
/// `null` if there are no visible positions or paragraphs.
///
/// - [threshold] 0.0: the first paragraph whose top has fully scrolled past
///   the top of the viewport. After a programmatic jump the target paragraph
///   sits a few percent below the top (alignment 0.05), so the PREVIOUS
///   paragraph still peeks in at the very top and would be reported as
///   "topmost"; 0.0 finds the paragraph whose text actually fills the screen
///   (what the TOC / jump sheet / bookmark naming should reflect).
/// - [threshold] 0.3: the paragraph approximately 1/3 from the top.
int? getCurrentParaId(
  Iterable<ItemPosition>? positions,
  ReaderDataState readerState, {
  double threshold = 0.3,
}) {
  if (positions == null || positions.isEmpty) return null;

  final visible = positions.where((p) => p.itemTrailingEdge > 0).toList()
    ..sort((a, b) => a.itemLeadingEdge.compareTo(b.itemLeadingEdge));

  if (visible.isEmpty) return null;

  // Find the first paragraph with leading edge past the threshold
  int? targetIndex;
  for (final pos in visible) {
    if (pos.itemLeadingEdge >= threshold) {
      targetIndex = pos.index;
      break;
    }
  }
  // Fallback to the topmost visible paragraph
  targetIndex ??= visible.first.index;

  if (targetIndex >= 0 && targetIndex < readerState.paragraphs.length) {
    return readerState.paragraphs[targetIndex].paraId;
  }
  return null;
}

/// Check whether the TTS paragraph ([ttsParaId]) is currently visible in the
/// viewport, based on [positions] and [readerState].
///
/// Returns `true` if any visible paragraph position maps to a paragraph with
/// the given [ttsParaId]. Returns `false` if [ttsParaId] is null or if the
/// paragraph is not visible.
bool isTtsLineVisible(
  Iterable<ItemPosition>? positions,
  ReaderDataState readerState,
  int? ttsParaId,
) {
  if (ttsParaId == null) return false;
  if (positions == null || positions.isEmpty) return false;

  final visibleIndices = positions
      .where((p) => p.itemTrailingEdge > 0)
      .map((p) => p.index)
      .toSet();
  if (visibleIndices.isEmpty) return false;

  for (final idx in visibleIndices) {
    if (idx >= 0 && idx < readerState.paragraphs.length) {
      if (readerState.paragraphs[idx].paraId == ttsParaId) return true;
    }
  }
  return false;
}
