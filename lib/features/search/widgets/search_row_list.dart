import 'package:flutter/material.dart';

import 'search_results_navigator.dart';

/// Rows a lazy result list has built, by row index. Both result lists (the
/// full screen and the desktop sidebar) build one list item per navigator
/// row, so after a mouse scroll the keyboard-selected row may not exist.
class BuiltSearchRows {
  final Map<int, BuildContext> _rows = {};

  /// Wraps the row at [index] so it is recorded while it is built.
  Widget track(int index, Widget child) =>
      _BuiltRow(index: index, registry: _rows, child: child);

  /// Scrolls the selected row into view. When it is not built yet, moves one
  /// screen toward it per frame until it is.
  void reveal({
    required GlobalKey selectedKey,
    required SearchResultsNavigator nav,
    required bool Function() isMounted,
    int attempt = 0,
  }) {
    if (!isMounted()) return;
    final ctx = selectedKey.currentContext;
    if (ctx != null && ctx.mounted) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.25,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
      return;
    }
    // The load-more row carries no key and never scrolled into view.
    if (nav.selectedRow?.kind == SearchRowKind.loadMore) return;
    if (attempt >= 100 || _rows.isEmpty) return;
    final built = _rows.keys;
    final selected = nav.selected;
    final first = built.reduce((a, b) => a < b ? a : b);
    final last = built.reduce((a, b) => a > b ? a : b);
    if (selected >= first && selected <= last) return;
    final position = Scrollable.of(_rows[first]!).position;
    final step = selected < first
        ? -position.viewportDimension
        : position.viewportDimension;
    // A selection thousands of rows away is more than 100 screens off, so
    // the first jump goes by the row's share of the list. The extent is an
    // estimate for a lazy list; the one-screen steps after it finish the job.
    final target = attempt == 0 && nav.rows.length > 1
        ? position.minScrollExtent +
              (position.maxScrollExtent - position.minScrollExtent) *
                  selected /
                  (nav.rows.length - 1)
        : position.pixels + step;
    position.jumpTo(
      target.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => reveal(
        selectedKey: selectedKey,
        nav: nav,
        isMounted: isMounted,
        attempt: attempt + 1,
      ),
    );
  }
}

/// Records its row index in [registry] while it is built, so the view knows
/// which rows exist when a keyboard selection needs scrolling into view.
class _BuiltRow extends StatefulWidget {
  final int index;
  final Map<int, BuildContext> registry;
  final Widget child;

  const _BuiltRow({
    required this.index,
    required this.registry,
    required this.child,
  });

  @override
  State<_BuiltRow> createState() => _BuiltRowState();
}

class _BuiltRowState extends State<_BuiltRow> {
  @override
  void initState() {
    super.initState();
    widget.registry[widget.index] = context;
  }

  @override
  void didUpdateWidget(_BuiltRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      if (identical(oldWidget.registry[oldWidget.index], context)) {
        oldWidget.registry.remove(oldWidget.index);
      }
      widget.registry[widget.index] = context;
    }
  }

  @override
  void dispose() {
    if (identical(widget.registry[widget.index], context)) {
      widget.registry.remove(widget.index);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// One row's slice of a book's card. Stacked slices look like the single
/// card a book used to be: the header slice has the top border and corners,
/// the last slice the bottom ones and the gap to the next book.
class BookCardSlice extends StatelessWidget {
  final bool isFirst;
  final bool isLast;
  final double radius;
  final ColorScheme colors;
  final Widget child;

  const BookCardSlice({
    super.key,
    required this.isFirst,
    required this.isLast,
    required this.radius,
    required this.colors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final corner = Radius.circular(radius);
    final side = BorderSide(
      color: colors.outlineVariant.withValues(alpha: 0.3),
    );
    final borderRadius = BorderRadius.vertical(
      top: isFirst ? corner : Radius.zero,
      bottom: isLast ? corner : Radius.zero,
    );
    // The border is drawn over the content, as the card drew its outline,
    // so it does not pad the row the way a Container's border would.
    Widget slice = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: borderRadius,
      ),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border(
            left: side,
            right: side,
            top: isFirst ? side : BorderSide.none,
            bottom: isLast ? side : BorderSide.none,
          ),
          borderRadius: borderRadius,
        ),
        // The tiles' ink splashes paint on the nearest Material; without
        // this one they would draw on the screen's Material, under the
        // background above.
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
    if (isFirst || isLast) {
      slice = ClipRRect(borderRadius: borderRadius, child: slice);
    }
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 6 : 0),
      child: slice,
    );
  }
}

/// Inner highlight for a row inside a grouped book card — no outer margin
/// so header and results span the full card width consistently.
class GroupRowHighlight extends StatelessWidget {
  final bool selected;
  final ColorScheme colors;
  final Widget child;

  const GroupRowHighlight({
    super.key,
    required this.selected,
    required this.colors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      decoration: BoxDecoration(
        color: selected
            ? colors.primary.withValues(alpha: 0.10)
            : Colors.transparent,
        border: Border.all(
          color: selected
              ? colors.primary.withValues(alpha: 0.6)
              : Colors.transparent,
          width: 1.2,
        ),
      ),
      child: child,
    );
  }
}
