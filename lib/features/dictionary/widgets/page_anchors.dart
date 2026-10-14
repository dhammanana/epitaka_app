import 'package:flutter/material.dart';

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
        await Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.05,
        );
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
