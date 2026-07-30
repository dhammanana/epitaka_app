import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../providers/reader_provider.dart';

/// Data for a heading tick mark on the scrollbar track.
class _HeadingMark {
  final String title;
  final int level;
  final double ratio; // 0.0–1.0 position on the track
  final int paraIndex; // paragraph index for scrolling

  const _HeadingMark({
    required this.title,
    required this.level,
    required this.ratio,
    required this.paraIndex,
  });
}

/// A very thin scrollbar on the right edge of the reader with tick marks at
/// heading positions (chapter/section boundaries) and a floating tooltip that
/// shows the heading name while the user drags the thumb.
///
/// The vertical position of the thumb follows the first visible item's index
/// as a fraction of the total item count. When dragged, it jumps via
/// [ItemScrollController] to the corresponding index.
///
/// Heading marks are computed from [readerState.paragraphs] — every paragraph
/// with a non-null [ParagraphData.heading] gets a tick on the track, helping
/// the user perceive chapter lengths and fast-scroll to a specific section.
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
  static const double _thumbHeight = 32.0;
  static const double _trackWidth = 4.0;
  static const double _thumbWidth = 8.0;
  static const double _totalTrackWidth = 12.0; // hit area for gestures

  /// Scroll position ratio 0.0–1.0 computed from ItemPositionsListener.
  double _scrollRatio = 0.0;

  /// Thumb's vertical offset (px from top) during a drag (overrides ratio).
  double? _dragOffset;

  /// Available height for thumb movement (parent height - thumb height).
  double _availableDragHeight = 0;

  /// Cached heading marks computed from paragraphs.
  List<_HeadingMark>? _cachedMarks;

  /// The heading currently shown in the tooltip during drag.
  String? _tooltipHeading;

  @override
  void initState() {
    super.initState();
    widget.itemPositionsListener?.itemPositions
        .addListener(_onPositionsChanged);
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
      _cachedMarks = null;
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

    final visible = positions
        .where((p) => p.itemTrailingEdge > 0)
        .toList()
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

  /// Build heading marks from paragraphs (cached for performance).
  List<_HeadingMark> _buildHeadingMarks() {
    if (_cachedMarks != null) return _cachedMarks!;
    final paragraphs = widget.readerState.paragraphs;
    final total = paragraphs.length;
    if (total <= 1) {
      _cachedMarks = const [];
      return _cachedMarks!;
    }

    final marks = <_HeadingMark>[];
    for (int i = 0; i < total; i++) {
      final heading = paragraphs[i].heading;
      if (heading != null) {
        marks.add(_HeadingMark(
          title: heading.title,
          level: heading.level,
          ratio: i / (total - 1),
          paraIndex: i,
        ));
      }
    }
    _cachedMarks = marks;
    return marks;
  }

  /// Find the nearest heading mark to the given ratio.
  _HeadingMark? _findNearestHeading(double ratio) {
    final marks = _buildHeadingMarks();
    if (marks.isEmpty) return null;

    _HeadingMark? best;
    double bestDist = double.infinity;
    for (final m in marks) {
      final dist = (m.ratio - ratio).abs();
      if (dist < bestDist) {
        bestDist = dist;
        best = m;
      }
    }
    // Only show tooltip if within a reasonable proximity
    return bestDist < 0.15 ? best : null;
  }

  void _onDragStart(DragStartDetails details) {
    setState(() {
      _dragOffset = details.localPosition.dy - _thumbHeight / 2;
      // Immediately update tooltip based on position
      final ratio =
          (_dragOffset! / _availableDragHeight).clamp(0.0, 1.0);
      final nearest = _findNearestHeading(ratio);
      _tooltipHeading = nearest?.title;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_dragOffset == null) return;
    final newOffset = _dragOffset! + details.delta.dy;
    setState(() {
      _dragOffset = newOffset.clamp(0.0, _availableDragHeight);

      // Update tooltip: show nearest heading at current position
      final ratio = (_dragOffset! / _availableDragHeight).clamp(0.0, 1.0);
      final nearest = _findNearestHeading(ratio);
      _tooltipHeading = nearest?.title;
    });

    // Scroll in real-time while dragging.
    // Also sync _scrollRatio so that on release (_dragOffset = null)
    // the thumb snaps to the position we've already shown during drag,
    // not back to the old position from before the drag started.
    final total = widget.readerState.paragraphs.length;
    if (total <= 1) return;
    final ratio = (_dragOffset! / _availableDragHeight).clamp(0.0, 1.0);
    _scrollRatio = ratio;
    final targetIndex = (ratio * (total - 1)).round();

    widget.itemScrollController?.jumpTo(
      index: targetIndex.clamp(0, total - 1),
      alignment: 0.0,
    );
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() {
      _dragOffset = null;
      _tooltipHeading = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = colors.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        _availableDragHeight =
            (constraints.maxHeight - _thumbHeight).clamp(0.0, double.infinity);

        final total = widget.readerState.paragraphs.length;
        if (total <= 1) return const SizedBox.shrink();

        final marks = _buildHeadingMarks();

        // Compute thumb position
        final effectiveRatio = _dragOffset != null
            ? (_dragOffset! / _availableDragHeight).clamp(0.0, 1.0)
            : _scrollRatio;
        final thumbTop = effectiveRatio * _availableDragHeight;

        // Track edge positions
        final trackLeft = (_totalTrackWidth - _trackWidth) / 2;
        final trackTop = 0.0;
        final trackBottom = constraints.maxHeight;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragStart: _onDragStart,
          onVerticalDragUpdate: _onDragUpdate,
          onVerticalDragEnd: _onDragEnd,
          child: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: _totalTrackWidth,
              child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ── Track background ─────────────────────────────────
                Positioned(
                  left: trackLeft,
                  top: trackTop,
                  bottom: trackBottom,
                  width: _trackWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // ── Heading tick marks ───────────────────────────────
                ...marks.map((mark) {
                  final tickTop =
                      mark.ratio * _availableDragHeight + _thumbHeight / 2;
                  // Deeper heading levels get slightly shorter/dimmer ticks
                  final opacity =
                      (0.5 - (mark.level - 1) * 0.08).clamp(0.2, 0.5);
                  final height = (4.0 - (mark.level - 1) * 0.4).clamp(2.0, 4.0);
                  return Positioned(
                    left: trackLeft - 1,
                    top: tickTop - height / 2,
                    width: _trackWidth + 2,
                    height: height,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.primary
                            .withValues(alpha: opacity),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  );
                }),

                // ── Thumb ────────────────────────────────────────────
                Positioned(
                  top: thumbTop,
                  left: 0,
                  right: 0,
                  height: _thumbHeight,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: _dragOffset != null ? _thumbWidth + 2 : _thumbWidth,
                      height: _thumbHeight * 0.55,
                      decoration: BoxDecoration(
                        color: _dragOffset != null
                            ? colors.primary.withValues(alpha: 0.7)
                            : colors.primary.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(9999),
                        boxShadow: _dragOffset != null
                            ? [
                                BoxShadow(
                                  color: colors.primary
                                      .withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),

                // ── Tooltip (shown during drag, to the left of track) ─
                if (_dragOffset != null && _tooltipHeading != null)
                  Positioned(
                    top: (thumbTop + _thumbHeight / 2).clamp(
                      0.0,
                      constraints.maxHeight - 28,
                    ),
                    right: _totalTrackWidth + 4,
                    child: _HeadingTooltip(
                      title: _tooltipHeading!,
                      isDark: isDark,
                      colors: colors,
                    ),
                  ),
              ],
            ),
          ),
        ),
        );
      },
    );
  }
}

/// A small floating card that displays the heading name during drag.
class _HeadingTooltip extends StatelessWidget {
  final String title;
  final bool isDark;
  final ColorScheme colors;

  const _HeadingTooltip({
    required this.title,
    required this.isDark,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      color: isDark
          ? colors.surfaceContainerHigh
          : colors.surfaceContainerLow,
      surfaceTintColor: colors.primary,
      child: Container(
        constraints: BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colors.onSurface,
            height: 1.2,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
        ),
      ),
    );
  }
}
