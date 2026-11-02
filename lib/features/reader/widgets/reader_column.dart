import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';

/// Below this reader width the columns give way to the active tab alone.
/// Material's "expanded" size class; three columns of 280 px are tight.
const double kReaderColumnsMinWidth = 840;

/// The keys and controllers one reader content area owns.
///
/// The single-tab reader has one hit-test box and one selection area; each
/// column needs its own, or a tap in one column would hit-test another.
class ReaderColumnKeys {
  ReaderColumnKeys({
    this.bookId,
    GlobalKey? contentHitTest,
    GlobalKey<SelectableRegionState>? selectableRegion,
    ScrollOffsetController? autoScroll,
  }) : contentHitTest = contentHitTest ?? GlobalKey(),
       selectableRegion =
           selectableRegion ?? GlobalKey<SelectableRegionState>(),
       autoScroll = autoScroll ?? ScrollOffsetController();

  /// The column's book, or null for the single-tab reader (whose book is
  /// the active tab).
  final String? bookId;
  final GlobalKey contentHitTest;
  final GlobalKey<SelectableRegionState> selectableRegion;
  final ScrollOffsetController autoScroll;
}

/// One book shown beside others: a slim header (book name, close button)
/// over its reader [child].
///
/// A pointer down anywhere in the column calls [onFocus], so the toolbar
/// tools act on the column the user is working in.
class ReaderColumn extends StatelessWidget {
  const ReaderColumn({
    super.key,
    required this.title,
    required this.focused,
    required this.onFocus,
    required this.onClose,
    required this.child,
  });

  final String title;
  final bool focused;
  final VoidCallback onFocus;
  /// Closes the book's tab: the tab strip and the columns always match.
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 28,
          padding: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            color: focused
                ? colors.primaryContainer.withValues(alpha: 0.5)
                : colors.surfaceContainerLow,
            border: Border(
              top: BorderSide(
                color: focused ? colors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMedium.copyWith(
                    color: focused
                        ? colors.onPrimaryContainer
                        : colors.onSurfaceVariant,
                    fontWeight: focused ? FontWeight.w600 : null,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                tooltip: AppLocalizations.of(context).close,
                onPressed: onClose,
              ),
            ],
          ),
        ),
        Expanded(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) {
              if (!focused) onFocus();
            },
            child: child,
          ),
        ),
      ],
    );
  }
}

/// The padlock on a split line between two columns.
///
/// Material's open lock barely differs from the closed one at this size
/// (live test: open and closed could not be told apart), so the open
/// shackle is drawn lifted well clear of the body.
class ColumnLockGlyph extends StatelessWidget {
  const ColumnLockGlyph({super.key, required this.locked, required this.color});

  final bool locked;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(10, 15),
    painter: _LockPainter(locked: locked, color: color),
  );
}

class _LockPainter extends CustomPainter {
  const _LockPainter({required this.locked, required this.color});

  final bool locked;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bodyTop = h * 0.5;
    canvas.drawRRect(
      RRect.fromLTRBR(0, bodyTop, w, h, const Radius.circular(1.5)),
      Paint()..color = color,
    );

    final left = w * 0.2;
    final right = w * 0.8;
    final radius = (right - left) / 2;
    final top = locked ? h * 0.12 : 0.0;
    // Locked, the shackle's legs reach into the body; open, they stop a
    // clear gap above it.
    final legsBottom = locked ? bodyTop : bodyTop - h * 0.25;
    final shackle = Path()
      ..moveTo(left, legsBottom)
      ..lineTo(left, top + radius)
      ..arcTo(
        Rect.fromLTWH(left, top, right - left, radius * 2),
        math.pi,
        math.pi,
        false,
      )
      ..lineTo(right, legsBottom);
    canvas.drawPath(
      shackle,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(_LockPainter old) =>
      old.locked != locked || old.color != color;
}
