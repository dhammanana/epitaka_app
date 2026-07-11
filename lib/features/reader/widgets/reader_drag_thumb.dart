import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../providers/reader_provider.dart';

/// A thin draggable handle on the right edge of the reader that the user can
/// grab and drag to scroll through the book quickly. No scrollbar track is
/// rendered — just the thumb (a small rounded pill).
///
/// Position tracking: the thumb's vertical position follows the first visible
/// item's index as a fraction of the total item count. When dragged, it
/// jumps (or scrolls via [ItemScrollController]) to the corresponding index.
class ReaderDragThumb extends StatefulWidget {
  final ReaderDataState readerState;
  final ItemScrollController? itemScrollController;
  final ItemPositionsListener? itemPositionsListener;

  const ReaderDragThumb({
    super.key,
    required this.readerState,
    this.itemScrollController,
    this.itemPositionsListener,
  });

  @override
  State<ReaderDragThumb> createState() => _ReaderDragThumbState();
}

class _ReaderDragThumbState extends State<ReaderDragThumb> {
  static const double _thumbHeight = 48.0;
  static const double _thumbWidth = 20.0;

  /// Scroll position ratio 0.0–1.0 computed from ItemPositionsListener.
  double _scrollRatio = 0.0;

  /// Thumb's vertical offset (px from top) during a drag (overrides ratio).
  double? _dragOffset;

  /// Available height for thumb movement (parent height - thumb height).
  double _availableDragHeight = 0;

  @override
  void initState() {
    super.initState();
    widget.itemPositionsListener?.itemPositions.addListener(_onPositionsChanged);
  }

  @override
  void didUpdateWidget(ReaderDragThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemPositionsListener != widget.itemPositionsListener) {
      oldWidget.itemPositionsListener?.itemPositions
          .removeListener(_onPositionsChanged);
      widget.itemPositionsListener?.itemPositions
          .addListener(_onPositionsChanged);
    }
    if (oldWidget.readerState.paragraphs.length !=
        widget.readerState.paragraphs.length) {
      final positions = widget.itemPositionsListener?.itemPositions.value;
      if (positions != null) {
        _updateScrollRatio(positions);
      }
    }
  }

  @override
  void dispose() {
    widget.itemPositionsListener?.itemPositions
        .removeListener(_onPositionsChanged);
    super.dispose();
  }

  void _onPositionsChanged() {
    final positions = widget.itemPositionsListener?.itemPositions.value;
    if (positions == null) return;
    _updateScrollRatio(positions);
  }

  void _updateScrollRatio(Iterable<ItemPosition>? positions) {
    if (positions == null || positions.isEmpty) return;

    final visible = positions.where((p) => p.itemTrailingEdge > 0).toList()
      ..sort((a, b) => a.itemLeadingEdge.compareTo(b.itemLeadingEdge));
    if (visible.isEmpty) return;

    final topIndex = visible.first.index;
    final total = widget.readerState.paragraphs.length;
    if (total <= 1) return;

    // Avoid setState if the thumb is being dragged by the user
    if (_dragOffset != null) return;

    setState(() {
      _scrollRatio = topIndex / (total - 1);
    });
  }

  void _onDragStart(DragStartDetails details) {
    setState(() {
      _dragOffset = details.localPosition.dy - _thumbHeight / 2;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_dragOffset == null) return;
    final newOffset = _dragOffset! + details.delta.dy;
    setState(() {
      _dragOffset = newOffset.clamp(0.0, _availableDragHeight);
    });

    // Scroll in real-time while dragging
    final total = widget.readerState.paragraphs.length;
    if (total <= 1) return;
    final ratio = (_dragOffset! / _availableDragHeight).clamp(0.0, 1.0);
    final targetIndex = (ratio * (total - 1)).round();

    widget.itemScrollController?.jumpTo(
      index: targetIndex.clamp(0, total - 1),
      alignment: 0.0,
    );
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() {
      _dragOffset = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        _availableDragHeight =
            (constraints.maxHeight - _thumbHeight).clamp(0.0, double.infinity);

        final total = widget.readerState.paragraphs.length;
        if (total <= 1) return const SizedBox.shrink();

        // Compute thumb position
        final effectiveRatio = _dragOffset != null
            ? (_dragOffset! / _availableDragHeight).clamp(0.0, 1.0)
            : _scrollRatio;
        final top = effectiveRatio * _availableDragHeight;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragStart: _onDragStart,
          onVerticalDragUpdate: _onDragUpdate,
          onVerticalDragEnd: _onDragEnd,
          child: Stack(
            children: [
              // Hit area extension (invisible) for easier grabbing
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(
                    color: Colors.transparent,
                  ),
                ),
              ),
              // The visible thumb
              Positioned(
                top: top,
                left: 0,
                right: 0,
                height: _thumbHeight,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: _thumbWidth,
                    height: _thumbHeight * 0.6,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(
                        alpha: _dragOffset != null ? 0.5 : 0.3,
                      ),
                      borderRadius: BorderRadius.circular(9999),
                      boxShadow: _dragOffset != null
                          ? [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
