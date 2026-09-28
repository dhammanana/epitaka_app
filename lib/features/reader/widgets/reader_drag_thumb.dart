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
  static const double _trackWidth = 3.0;
  static const double _thumbWidth = 8.0;
  static const double _totalTrackWidth = 12.0; // hit area for gestures

  /// Minimum vertical gap (as a fraction of the track) between two kept
  /// section ticks. Books with hundreds of sections would otherwise render
  /// a solid band of overlapping marks.
  static const double _kMinMarkGapRatio = 0.006;

  /// Scroll-ratio changes smaller than this never move the thumb a full
  /// pixel, so they skip the rebuild (which would repaint the whole track
  /// for an invisible movement).
  static const double _kScrollRatioEpsilon = 0.002;

  /// Scroll position ratio 0.0–1.0 computed from ItemPositionsListener.
  double _scrollRatio = 0.0;

  /// Thumb's vertical offset (px from top) during a drag (overrides ratio).
  double? _dragOffset;

  /// Available height for thumb movement (parent height - thumb height).
  double _availableDragHeight = 0;

  /// Cached heading marks computed from paragraphs.
  List<_HeadingMark>? _cachedMarks;

  /// Last paragraph index issued during an active drag. Drag updates that
  /// resolve to the same index skip the (expensive) list jump.
  int? _lastDragJumpIndex;

  /// The heading currently shown in the tooltip during drag.
  String? _tooltipHeading;

  @override
  void initState() {
    super.initState();
    widget.itemPositionsListener?.itemPositions.addListener(
      _onPositionsChanged,
    );
  }

  @override
  void didUpdateWidget(ReaderDragThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemPositionsListener != widget.itemPositionsListener) {
      oldWidget.itemPositionsListener?.itemPositions.removeListener(
        _onPositionsChanged,
      );
      widget.itemPositionsListener?.itemPositions.addListener(
        _onPositionsChanged,
      );
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
    widget.itemPositionsListener?.itemPositions.removeListener(
      _onPositionsChanged,
    );
    super.dispose();
  }

  void _onPositionsChanged() {
    final positions = widget.itemPositionsListener?.itemPositions.value;
    if (positions == null) return;
    _updateScrollRatio(positions);
  }

  void _updateScrollRatio(Iterable<ItemPosition>? positions) {
    if (positions == null || positions.isEmpty) return;

    ItemPosition? topVisible;
    for (final position in positions) {
      if (position.itemTrailingEdge <= 0) continue;
      if (topVisible == null ||
          position.itemLeadingEdge < topVisible.itemLeadingEdge) {
        topVisible = position;
      }
    }
    if (topVisible == null) return;

    final topIndex = topVisible.index;
    final total = widget.readerState.paragraphs.length;
    if (total <= 1) return;

    // Avoid setState if the thumb is being dragged by the user
    if (_dragOffset != null) return;

    final newRatio = topIndex / (total - 1);
    // Skip sub-pixel updates: this listener fires on every scroll frame
    // and a setState per frame rebuilds the whole track for an invisible
    // (<1px) thumb movement.
    if ((newRatio - _scrollRatio).abs() < _kScrollRatioEpsilon) return;
    setState(() {
      _scrollRatio = newRatio;
    });
  }

  /// Build heading marks from paragraphs (cached for performance).
  ///
  /// Chapters (level 1–2) always get a tick. Deeper section marks are only
  /// kept when far enough below the previous kept mark — without this a
  /// book with hundreds of sections renders as one solid band.
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
        final ratio = i / (total - 1);
        if (heading.level > 2 &&
            marks.isNotEmpty &&
            ratio - marks.last.ratio < _kMinMarkGapRatio) {
          continue;
        }
        marks.add(
          _HeadingMark(
            title: heading.title,
            level: heading.level,
            ratio: ratio,
            paraIndex: i,
          ),
        );
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
    _lastDragJumpIndex = null;
    setState(() {
      _dragOffset = details.localPosition.dy - _thumbHeight / 2;
      // Immediately update tooltip based on position
      final ratio = (_dragOffset! / _availableDragHeight).clamp(0.0, 1.0);
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
    // Ratio is clamped above, so the rounded index is always in range.
    final targetIndex = (ratio * (total - 1)).round();

    // Drag updates fire per pointer event; jumping the list is the most
    // expensive part of the drag, so skip it when the index is unchanged.
    if (targetIndex == _lastDragJumpIndex) return;
    _lastDragJumpIndex = targetIndex;

    widget.itemScrollController?.jumpTo(index: targetIndex, alignment: 0.0);
  }

  void _onDragEnd(DragEndDetails details) {
    _lastDragJumpIndex = null;
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
        _availableDragHeight = (constraints.maxHeight - _thumbHeight).clamp(
          0.0,
          double.infinity,
        );

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
                        color: colors.surfaceContainerHighest.withValues(
                          alpha: 0.4,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // ── Heading tick marks ───────────────────────────────
                  // One CustomPaint draw instead of hundreds of Positioned
                  // widgets, and isolated from the per-frame thumb rebuilds
                  // via shouldRepaint (repaints only when the marks change).
                  Positioned(
                    left: trackLeft,
                    top: _thumbHeight / 2,
                    bottom: _thumbHeight / 2,
                    width: _trackWidth,
                    child: CustomPaint(
                      painter: _HeadingTicksPainter(
                        marks: marks,
                        color: colors.primary,
                      ),
                    ),
                  ),

                  // ── Thumb ────────────────────────────────────────────
                  Positioned(
                    top: thumbTop,
                    left: 0,
                    right: 0,
                    height: _thumbHeight,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: _dragOffset != null
                            ? _thumbWidth + 2
                            : _thumbWidth,
                        height: _thumbHeight * 0.55,
                        decoration: BoxDecoration(
                          color: _dragOffset != null
                              ? colors.primary.withValues(alpha: 0.7)
                              : colors.primary.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(9999),
                          boxShadow: _dragOffset != null
                              ? [
                                  BoxShadow(
                                    color: colors.primary.withValues(
                                      alpha: 0.3,
                                    ),
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

/// Paints the chapter/section tick marks onto the scrollbar track.
///
/// A single canvas draw for all marks (instead of one widget per mark), so
/// books with many sections stay cheap to build and scroll. Deeper heading
/// levels draw thinner/dimmer ticks.
class _HeadingTicksPainter extends CustomPainter {
  final List<_HeadingMark> marks;
  final Color color;

  const _HeadingTicksPainter({required this.marks, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height <= 0) return;
    for (final mark in marks) {
      final h = (2.5 - (mark.level - 1) * 0.25).clamp(1.0, 2.5);
      final opacity = (0.45 - (mark.level - 1) * 0.06).clamp(0.15, 0.45);
      final y = (mark.ratio * size.height).clamp(0.0, size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width / 2, y),
            width: size.width,
            height: h,
          ),
          const Radius.circular(1),
        ),
        Paint()..color = color.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HeadingTicksPainter oldDelegate) =>
      !identical(oldDelegate.marks, marks) || oldDelegate.color != color;
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
      color: isDark ? colors.surfaceContainerHigh : colors.surfaceContainerLow,
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
