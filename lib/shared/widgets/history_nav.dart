import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import 'history_list.dart';

/// The keyboard model for a history list while the text box keeps the
/// cursor: [index] is the highlighted row (-1 is none). Down moves the
/// highlight down and stops at the last row, Up moves it back and from the
/// first row clears it (the user then types at once), Enter on a highlighted
/// row calls [onActivate] once. The Search suggestion list works the same way.
class HistoryNav {
  HistoryNav({required this.onChanged, required this.onActivate});

  final VoidCallback onChanged;
  final void Function(int index) onActivate;
  int index = -1;

  void _set(int next) {
    if (next == index) return;
    index = next;
    onChanged();
  }

  void reset() => _set(-1);

  int _count = 0;

  /// Call on every build of the rows. When the row count changed (a delete, a
  /// late load) the rows moved under the highlight, so it is dropped: Enter
  /// must not open a row the user did not point at. It sets the field only,
  /// because the build that calls it reads [index] straight after.
  void clamp(int count) {
    if (count != _count) {
      _count = count;
      index = -1;
    } else if (index >= count) {
      index = count - 1;
    }
  }

  KeyEventResult handle(KeyEvent event, int count) {
    if (count == 0) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _set(index + 1 > count - 1 ? count - 1 : index + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp && index >= 0) {
      _set(index - 1);
      return KeyEventResult.handled;
    }
    if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) &&
        index >= 0) {
      if (event is KeyDownEvent) onActivate(index);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Scrolls row [index] into view; rows are [kHistoryRowHeight] high.
  void scrollTo(ScrollController controller) {
    if (index < 0 || !controller.hasClients) return;
    final position = controller.position;
    final top = index * kHistoryRowHeight;
    if (top < position.pixels) {
      controller.jumpTo(top);
    } else if (top + kHistoryRowHeight >
        position.pixels + position.viewportDimension) {
      controller.jumpTo(top + kHistoryRowHeight - position.viewportDimension);
    }
  }
}
