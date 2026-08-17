// lib/features/reader/widgets/reader_context_menu.dart
//
// Reusable context menu button widget. The full context menu toolbar is
// built by [ReaderCopyService.buildContextMenu] in the service layer.

import 'package:flutter/material.dart';

/// Button used inside the custom copy context menu.
/// Shows a hover highlight and a ripple effect on tap.
class ContextMenuButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme colors;

  const ContextMenuButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.colors,
  });

  @override
  State<ContextMenuButton> createState() => _ContextMenuButtonState();
}

class _ContextMenuButtonState extends State<ContextMenuButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = _isPressed
        ? widget.colors.primary.withValues(alpha: 0.2)
        : _isHovered
            ? widget.colors.surfaceContainerHighest
            : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: () {
          widget.onTap();
          Future.delayed(const Duration(milliseconds: 150), () {
            if (mounted) setState(() => _isPressed = false);
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: 16,
                  color: _isHovered
                      ? widget.colors.primary
                      : widget.colors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                // Flexible + ellipsis: inside the full-width desktop bar (or
                // a narrow overflow menu) a single button may be squeezed
                // below its intrinsic width — shrink the label rather than
                // overflow the row.
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: _isHovered
                          ? widget.colors.onSurface
                          : widget.colors.onSurfaceVariant,
                      fontWeight:
                          _isHovered ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Desktop variant of the selection context menu: a bar that spans the full
/// width of the reader content column instead of floating at its intrinsic
/// size, with the actions distributed evenly across it.
///
/// The framework lays this widget out inside a composited-follower whose
/// origin is the top-left of the screen, so global coordinates from the
/// anchors and the content render box can be used directly as local
/// coordinates.
class FullWidthSelectionToolbar extends StatefulWidget {
  final TextSelectionToolbarAnchors anchors;

  /// Key of the reader content widget — its render box defines the column
  /// width the bar should span.
  final GlobalKey contentHitTestKey;

  final List<Widget> children;

  const FullWidthSelectionToolbar({
    super.key,
    required this.anchors,
    required this.contentHitTestKey,
    required this.children,
  });

  @override
  State<FullWidthSelectionToolbar> createState() =>
      _FullWidthSelectionToolbarState();
}

class _FullWidthSelectionToolbarState extends State<FullWidthSelectionToolbar> {
  /// The content box only has a size after the first layout pass. Until the
  /// post-frame callback confirms it, fall back to the stock toolbar rather
  /// than measuring an unlaid-out box (which would silently render the
  /// content-sized pill forever).
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final anchors = widget.anchors;
    final contentHitTestKey = widget.contentHitTestKey;
    final children = widget.children;

    // Fall back to the stock anchored toolbar when the content isn't laid
    // out yet (or the anchors are the zero fallback from the crash guard).
    final contentBox =
        contentHitTestKey.currentContext?.findRenderObject() as RenderBox?;
    if (!_ready ||
        contentBox == null ||
        !contentBox.hasSize ||
        anchors.primaryAnchor == Offset.zero) {
      return AdaptiveTextSelectionToolbar(
        anchors: anchors,
        children: children,
      );
    }

    final contentLeft = contentBox.localToGlobal(Offset.zero).dx;
    final contentWidth = contentBox.size.width;

    return CustomSingleChildLayout(
      delegate: _FullWidthToolbarLayoutDelegate(
        contentLeft: contentLeft,
        contentWidth: contentWidth,
        anchor: anchors.primaryAnchor,
      ),
      child: _FullWidthToolbarBar(children: children),
    );
  }
}

/// The bar itself: a rounded elevated surface holding the actions, wrapped
/// so a narrow column (or many actions) wraps onto extra lines instead of
/// overflowing.
class _FullWidthToolbarBar extends StatelessWidget {
  final List<Widget> children;

  const _FullWidthToolbarBar({required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Wrap(
          alignment: WrapAlignment.spaceEvenly,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: children,
        ),
      ),
    );
  }
}

/// Positions the bar to span the reader content column and sit just above
/// the selection anchor (below it when there isn't room above), clamped to
/// the screen.
class _FullWidthToolbarLayoutDelegate extends SingleChildLayoutDelegate {
  final double contentLeft;
  final double contentWidth;
  final Offset anchor;

  const _FullWidthToolbarLayoutDelegate({
    required this.contentLeft,
    required this.contentWidth,
    required this.anchor,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final width = contentWidth.clamp(0.0, constraints.maxWidth);
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      minHeight: 0,
      maxHeight: constraints.maxHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    const screenMargin = 8.0;
    // Keep the bar within the screen horizontally.
    final maxLeft = (size.width - childSize.width - screenMargin).clamp(
      screenMargin,
      size.width,
    );
    final left = contentLeft.clamp(screenMargin, maxLeft);

    // Prefer above the anchor; drop below when it doesn't fit.
    var top = anchor.dy - childSize.height - 12.0;
    if (top < screenMargin) top = anchor.dy + 12.0;
    final maxTop = (size.height - childSize.height - screenMargin).clamp(
      screenMargin,
      size.height,
    );
    if (top > maxTop) top = maxTop;

    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_FullWidthToolbarLayoutDelegate oldDelegate) {
    return oldDelegate.contentLeft != contentLeft ||
        oldDelegate.contentWidth != contentWidth ||
        oldDelegate.anchor != anchor;
  }
}
