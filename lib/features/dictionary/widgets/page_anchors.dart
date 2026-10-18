import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// The space left above a card's title after a jump: about one line.
const double kTitleGap = 24;

/// Where on a lookup page each summary line can jump to.
///
/// One [GlobalKey] per target id, handed to the widget the id names. The page
/// is a lazy list: a card below the screen has no widget yet, so [jumpTo]
/// scrolls down a screen at a time until the card exists, then settles on it.
class PageAnchors {
  final Map<String, GlobalKey> _keys = {};

  /// The key to put on the widget that [id] names.
  GlobalKey keyFor(String id) =>
      _keys.putIfAbsent(id, () => GlobalKey(debugLabel: id));

  /// Whether a widget with [id] has been given a key on this page.
  bool has(String id) => _keys.containsKey(id);

  /// The scroll offset that puts [context]'s widget [kTitleGap] below the top
  /// edge, or null when it has no place in a scrolling list yet.
  double? _offsetFor(BuildContext context, ScrollController controller) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !controller.hasClients) {
      return null;
    }
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return null;
    final position = controller.position;
    return (viewport.getOffsetToReveal(box, 0.0).offset - kTitleGap).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
  }

  /// Scrolls to the card, then keeps it in place while the cards above it
  /// finish loading. Each card shows a small loading card first and grows when
  /// its text arrives, which moves everything below it; one scroll alone
  /// lands the title in a different place each time. A card can load well
  /// after its neighbours, so it checks for the whole two seconds, and stops
  /// early only when the user scrolls by hand.
  Future<void> _settleOn(GlobalKey key, ScrollController controller) async {
    final first = key.currentContext;
    if (first == null) return;
    final firstOffset = _offsetFor(first, controller);
    if (firstOffset == null) return;
    await controller.animateTo(
      firstOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    // The user scrolling by hand ends the animation early.
    if (!controller.hasClients ||
        (controller.position.pixels - firstOffset).abs() > 1) {
      return;
    }
    for (var check = 0; check < 20; check++) {
      final left = controller.hasClients ? controller.position.pixels : 0.0;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final context = key.currentContext;
      if (context == null || !context.mounted || !controller.hasClients) return;
      // A move we did not make: the user took over.
      if ((controller.position.pixels - left).abs() > 1) return;
      final target = _offsetFor(context, controller);
      if (target == null) return;
      if ((controller.position.pixels - target).abs() >= 1) {
        controller.jumpTo(target);
        await WidgetsBinding.instance.endOfFrame;
      }
    }
  }

  /// Scrolls [controller]'s list so that the widget for [id] is near the top.
  /// Does nothing for an unknown id, and stops when a pass from the top has
  /// not found it either.
  Future<void> jumpTo(String id, ScrollController controller) async {
    final key = _keys[id];
    if (key == null) return;
    var fromTop = false;
    // A page has a handful of screens; the limit only guards a bad state.
    for (var step = 0; step < 80; step++) {
      final context = key.currentContext;
      if (context != null && context.mounted) {
        await _settleOn(key, controller);
        return;
      }
      if (!controller.hasClients) return;
      final position = controller.position;
      if (position.pixels >= position.maxScrollExtent - 1) {
        // The card can sit above the screen, dropped by the lazy list when
        // the summary is placed below it. Search once more from the top.
        if (fromTop) return;
        fromTop = true;
        controller.jumpTo(0);
        await WidgetsBinding.instance.endOfFrame;
        continue;
      }
      controller.jumpTo(
        (position.pixels + position.viewportDimension * 0.8).clamp(
          0.0,
          position.maxScrollExtent,
        ),
      );
      await WidgetsBinding.instance.endOfFrame;
    }
  }
}
