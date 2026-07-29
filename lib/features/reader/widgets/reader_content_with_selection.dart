import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/reader_provider.dart';
import 'reader_content_list.dart';

/// Wraps a [ReaderContentList] in a [Listener] for hit-testing,
/// an [AnimatedBuilder] for tab swipe animation, and a [SelectionArea]
/// for native text selection (long-press + drag handles).
class ReaderContentWithSelection extends StatelessWidget {
  const ReaderContentWithSelection({
    super.key,
    required this.bookId,
    required this.data,
    required this.settings,
    required this.colors,
    required this.paliColor,
    required this.translationColor,
    required this.enabledLangs,
    required this.langTypographies,
    required this.itemScrollController,
    required this.itemPositionsListener,
    required this.scrollOffsetListener,
    required this.contentHitTestKey,
    required this.dragDxNotifier,
    required this.selectableRegionKey,
    required this.onPointerDown,
    this.onPointerMove,
    this.onPointerUp,
    this.onPointerCancel,
    this.scrollOffsetController,
    required this.onSelectionChanged,
    required this.contextMenuBuilder,
    this.ttsHighlightLineId,
    this.ttsHighlightParaId,
    this.ttsTargetParaId,
    this.ttsTargetLineKeys = const {},
    this.searchQuery,
    this.onFirstContentFrame,
  });

  final String bookId;
  final ReaderDataState data;
  final AppSettings settings;
  final ColorScheme colors;
  final Color paliColor;
  final Color translationColor;
  final List<String> enabledLangs;
  final Map<String, LanguageTypography> langTypographies;

  // Scroll controllers
  final ItemScrollController itemScrollController;
  final ItemPositionsListener itemPositionsListener;
  final ScrollOffsetListener scrollOffsetListener;

  // Hit-test / drag
  final GlobalKey contentHitTestKey;
  final ValueNotifier<double> dragDxNotifier;

  // Raw pointer events (passive — don't participate in gesture arena)
  final void Function(PointerDownEvent) onPointerDown;
  final void Function(PointerMoveEvent)? onPointerMove;
  final void Function(PointerUpEvent)? onPointerUp;
  final void Function(PointerCancelEvent)? onPointerCancel;

  // Scroll controller for auto-scroll
  final ScrollOffsetController? scrollOffsetController;

  // SelectionArea
  final GlobalKey<SelectableRegionState> selectableRegionKey;
  final void Function(SelectedContent?) onSelectionChanged;
  final Widget Function(BuildContext, SelectableRegionState) contextMenuBuilder;

  // TTS
  final int? ttsHighlightLineId;
  final int? ttsHighlightParaId;
  final int? ttsTargetParaId;
  final Map<int, GlobalKey> ttsTargetLineKeys;

  // Search
  final String? searchQuery;

  // Misc
  final VoidCallback? onFirstContentFrame;

  @override
  Widget build(BuildContext context) {
    final readerContent = ReaderContentList(
      bookId: bookId,
      data: data,
      settings: settings,
      colors: colors,
      paliColor: paliColor,
      translationColor: translationColor,
      enabledLangs: enabledLangs,
      langTypographies: langTypographies,
      itemScrollController: itemScrollController,
      itemPositionsListener: itemPositionsListener,
      scrollOffsetListener: scrollOffsetListener,
      scrollOffsetController: scrollOffsetController,
      ttsHighlightLineId: ttsHighlightLineId,
      ttsHighlightParaId: ttsHighlightParaId,
      ttsTargetParaId: ttsTargetParaId,
      ttsTargetLineKeys: ttsTargetLineKeys,
      searchQuery: searchQuery,
      onFirstContentFrame: onFirstContentFrame,
    );

    // The Listener provides a stable hit-test anchor for
    // _selectWordAt (its key never changes).
    final content = Listener(
      key: contentHitTestKey,
      onPointerDown: onPointerDown,
      onPointerMove: onPointerMove,
      onPointerUp: onPointerUp,
      onPointerCancel: onPointerCancel,
      child: AnimatedBuilder(
        animation: dragDxNotifier,
        builder: (context, child) => Transform.translate(
          offset: Offset(dragDxNotifier.value, 0),
          child: child,
        ),
        child: KeyedSubtree(
          key: ValueKey('tab-$bookId'),
          child: readerContent,
        ),
      ),
    );

    return SelectionArea(
      key: selectableRegionKey,
      onSelectionChanged: onSelectionChanged,
      contextMenuBuilder: contextMenuBuilder,
      child: content,
    );
  }
}
