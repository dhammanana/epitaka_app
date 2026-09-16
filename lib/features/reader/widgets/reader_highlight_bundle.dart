import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../providers/reader_lookup_highlight_provider.dart';

/// Immutable bundle of every piece of state that affects how ONE OR FEW
/// paragraphs are highlighted in the reader: search hits, the tapped-word
/// dictionary lookup highlight, the TTS spoken line, the jump flash, and
/// the keyboard-reading cursor.
///
/// The reader list wraps all of these in one value-equality object so the
/// per-paragraph memo (see `ReaderContentList`) can compare "did anything
/// that could affect paragraph X change?" with a single `==` instead of a
/// dozen loose constructor arguments — and skip rebuilding paragraphs that
/// are unaffected (e.g. a keyboard `j` moves the cursor on 1 paragraph
/// instead of rebuilding every visible one).
class ReaderHighlightBundle {
  /// Book the bundle is scoped to (lookup highlights from other books are
  /// ignored by [sliceFor]).
  final String bookId;

  /// Active in-book search query (already display-normalized by the caller).
  final String? searchQuery;

  /// Active dictionary lookup highlight (tapped word).
  final ReaderLookupHighlight? lookupHighlight;

  /// TTS currently-spoken line (only meaningful for its paragraph).
  final int? ttsHighlightLineId;
  final int? ttsHighlightParaId;

  /// True when the spoken item is a Pali line, false for translation.
  /// Null = unknown/legacy (highlights translation).
  final bool? ttsHighlightIsPali;

  /// Jump-flash highlight (fades out after a few seconds).
  final int? jumpHighlightLineId;
  final int? jumpHighlightParaId;

  /// Paragraph that received per-line [GlobalKey]s for fine-scrolling.
  final int? ttsTargetParaId;

  /// Per-line GlobalKeys for [ttsTargetParaId].
  final Map<int, GlobalKey> ttsTargetLineKeys;

  /// Paragraph that received per-line [GlobalKey]s for the keyboard
  /// navigation centering fine-scroll (same mechanism as TTS, scoped to
  /// the keyboard focus so it never touches TTS state).
  final int? keyboardTargetParaId;

  /// Per-line GlobalKeys for [keyboardTargetParaId].
  final Map<int, GlobalKey> keyboardTargetLineKeys;

  /// Keyboard-reading cursor (focus line + selected chip).
  final int? keyboardFocusParaId;
  final int? keyboardFocusLineId;
  final int? keyboardFocusChipIndex;

  /// True when nothing in the bundle can highlight any paragraph. Used as a
  /// fast path so the common "plain reading, no search/TTS/selection" case
  /// hands every paragraph the same shared const slice.
  bool get isDefault =>
      (searchQuery == null || searchQuery!.isEmpty) &&
      lookupHighlight == null &&
      ttsHighlightLineId == null &&
      ttsHighlightParaId == null &&
      jumpHighlightLineId == null &&
      jumpHighlightParaId == null &&
      ttsTargetParaId == null &&
      ttsTargetLineKeys.isEmpty &&
      keyboardTargetParaId == null &&
      keyboardTargetLineKeys.isEmpty &&
      keyboardFocusParaId == null &&
      keyboardFocusLineId == null &&
      keyboardFocusChipIndex == null;

  const ReaderHighlightBundle({
    required this.bookId,
    this.searchQuery,
    this.lookupHighlight,
    this.ttsHighlightLineId,
    this.ttsHighlightParaId,
    this.ttsHighlightIsPali,
    this.jumpHighlightLineId,
    this.jumpHighlightParaId,
    this.ttsTargetParaId,
    this.ttsTargetLineKeys = const {},
    this.keyboardTargetParaId,
    this.keyboardTargetLineKeys = const {},
    this.keyboardFocusParaId,
    this.keyboardFocusLineId,
    this.keyboardFocusChipIndex,
  });

  /// The shared empty slice handed to every unaffected paragraph.
  static const ReaderHighlightSlice _emptySlice = ReaderHighlightSlice();

  /// Extract the parts of this bundle that apply to paragraph [paraId].
  ///
  /// Returns a value-equality object; two slices compare equal when the
  /// paragraph would render identically — which is exactly the predicate
  /// the per-paragraph memo needs.
  ReaderHighlightSlice sliceFor(int paraId) {
    if (isDefault) return _emptySlice;

    final lookup = lookupHighlight;
    final lookupForPara =
        lookup != null &&
            lookup.bookId == bookId &&
            (lookup.paraId == null || lookup.paraId == paraId)
        ? lookup
        : null;

    final ttsLine = ttsHighlightParaId == paraId ? ttsHighlightLineId : null;
    final ttsIsPali = ttsLine != null ? ttsHighlightIsPali : null;
    final jumpLine = jumpHighlightParaId == paraId ? jumpHighlightLineId : null;
    final kbPara = keyboardFocusParaId == paraId ? keyboardFocusParaId : null;
    final kbLine = keyboardFocusParaId == paraId ? keyboardFocusLineId : null;
    final kbChip =
        (keyboardFocusParaId == paraId && keyboardFocusLineId != null)
        ? keyboardFocusChipIndex
        : null;
    final lineKeys = (ttsTargetParaId == paraId && ttsTargetLineKeys.isNotEmpty)
        ? ttsTargetLineKeys
        : (keyboardTargetParaId == paraId && keyboardTargetLineKeys.isNotEmpty)
        ? keyboardTargetLineKeys
        : const <int, GlobalKey>{};

    return ReaderHighlightSlice(
      searchQuery: searchQuery,
      lookupHighlight: lookupForPara,
      ttsHighlightLineId: ttsLine,
      ttsHighlightIsPali: ttsIsPali,
      jumpHighlightLineId: jumpLine,
      lineKeys: lineKeys,
      keyboardFocusParaId: kbPara,
      keyboardFocusLineId: kbLine,
      keyboardFocusChipIndex: kbChip,
    );
  }
}

/// The per-paragraph slice of a [ReaderHighlightBundle]: only the state that
/// actually applies to one paragraph, with value equality.
class ReaderHighlightSlice {
  final String? searchQuery;
  final ReaderLookupHighlight? lookupHighlight;

  /// Line ID highlighted by TTS *in this paragraph* (null otherwise).
  final int? ttsHighlightLineId;
  final bool? ttsHighlightIsPali;

  /// Line ID flashed by a jump *in this paragraph* (null otherwise).
  final int? jumpHighlightLineId;

  /// Per-line GlobalKeys when this paragraph is the TTS fine-scroll target.
  final Map<int, GlobalKey> lineKeys;

  final int? keyboardFocusParaId;
  final int? keyboardFocusLineId;
  final int? keyboardFocusChipIndex;

  const ReaderHighlightSlice({
    this.searchQuery,
    this.lookupHighlight,
    this.ttsHighlightLineId,
    this.ttsHighlightIsPali,
    this.jumpHighlightLineId,
    this.lineKeys = const {},
    this.keyboardFocusParaId,
    this.keyboardFocusLineId,
    this.keyboardFocusChipIndex,
  });

  /// Quick "no highlight state at all" check (the common plain-reading case).
  bool get isDefault =>
      (searchQuery == null || searchQuery!.isEmpty) &&
      lookupHighlight == null &&
      ttsHighlightLineId == null &&
      jumpHighlightLineId == null &&
      lineKeys.isEmpty &&
      keyboardFocusParaId == null &&
      keyboardFocusLineId == null &&
      keyboardFocusChipIndex == null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReaderHighlightSlice &&
        other.searchQuery == searchQuery &&
        identical(other.lookupHighlight, lookupHighlight) &&
        other.ttsHighlightLineId == ttsHighlightLineId &&
        other.ttsHighlightIsPali == ttsHighlightIsPali &&
        other.jumpHighlightLineId == jumpHighlightLineId &&
        mapEquals(other.lineKeys, lineKeys) &&
        other.keyboardFocusParaId == keyboardFocusParaId &&
        other.keyboardFocusLineId == keyboardFocusLineId &&
        other.keyboardFocusChipIndex == keyboardFocusChipIndex;
  }

  @override
  int get hashCode => Object.hash(
    searchQuery,
    lookupHighlight,
    ttsHighlightLineId,
    ttsHighlightIsPali,
    jumpHighlightLineId,
    Object.hashAll(lineKeys.keys),
    keyboardFocusParaId,
    keyboardFocusLineId,
    keyboardFocusChipIndex,
  );
}
