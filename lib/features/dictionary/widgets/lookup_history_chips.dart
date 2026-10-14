import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// The words of the lookup history under the search field, oldest on the left
/// and newest on the right, against the right edge, the same words the back and forward arrows walk
/// through. The row starts at the newest end. The chip at the history position
/// has a stronger background, and the row scrolls to it when back or forward
/// moves it out of view. The mouse wheel scrolls the row sideways.
class LookupHistoryChips extends StatefulWidget {
  const LookupHistoryChips({
    super.key,
    required this.words,
    required this.currentIndex,
    required this.onTap,
    required this.colors,
    required this.labelStyle,
  });

  /// Oldest first, as the history keeps them.
  final List<String> words;

  /// The history position; no chip is marked when it is outside the list.
  final int currentIndex;
  final ValueChanged<String> onTap;
  final ColorScheme colors;
  final TextStyle labelStyle;

  @override
  State<LookupHistoryChips> createState() => _LookupHistoryChipsState();
}

class _LookupHistoryChipsState extends State<LookupHistoryChips> {
  final _currentKey = GlobalKey();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LookupHistoryChips old) {
    super.didUpdateWidget(old);
    final i = widget.currentIndex;
    // At the history's cap a new word drops the oldest, so the position stays
    // the same while the word at it changes.
    final wordChanged =
        i >= 0 &&
        i < widget.words.length &&
        i < old.words.length &&
        old.words[i] != widget.words[i];
    if (old.currentIndex != i || wordChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = _currentKey.currentContext;
        if (mounted && context != null) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 150),
            alignment: 0.5,
          );
        }
      });
    }
  }

  /// A wheel turn moves the row; the same event moves nothing else. The row
  /// starts at the newest end (offset 0), so wheel down goes toward the newer
  /// chips and wheel up toward the older ones.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_scroll.hasClients) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      final e = event as PointerScrollEvent;
      final delta = e.scrollDelta.dy != 0 ? e.scrollDelta.dy : e.scrollDelta.dx;
      final position = _scroll.position;
      _scroll.jumpTo(
        (position.pixels - delta).clamp(0.0, position.maxScrollExtent),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          // Starts at the right end, where the newest chip is.
          reverse: true,
          child: ConstrainedBox(
            // At least as wide as the row, so a few chips sit at the right edge.
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (var i = 0; i < widget.words.length; i++) ...[
                  _chip(i, colors),
                  const SizedBox(width: 4),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(int i, ColorScheme colors) {
    final isCurrent = i == widget.currentIndex;
    return ActionChip(
      key: isCurrent ? _currentKey : null,
      label: Text(widget.words[i]),
      labelStyle: isCurrent
          ? widget.labelStyle.copyWith(color: colors.onPrimary)
          : widget.labelStyle,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: isCurrent
          ? colors.primary
          : colors.surfaceContainerHighest,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onPressed: () => widget.onTap(widget.words[i]),
    );
  }
}
