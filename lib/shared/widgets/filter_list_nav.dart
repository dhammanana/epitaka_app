import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/app_shortcuts.dart';

/// Keyboard path from a filter box into the rows it found, for the Library,
/// Contents and Outline lists (the same keys as the Search results).
///
/// Down in the box moves the cursor to the first found row. Down and Up move
/// along the rows, Enter opens the selected row, and Esc or Up on the first
/// row returns the cursor to the box.
///
/// A list gives the box [boxNode], wraps its rows in [listFocus] and
/// [FilterNavRow], and each build sets [count] to the rows found. [count] is
/// 0 while the box is empty, so Down does nothing before a search.
class FilterListNav extends ChangeNotifier {
  FilterListNav({required this.onActivate, required this.boxNode}) {
    boxNode.onKeyEvent = _onBoxKey;
    listFocus = FocusNode(onKeyEvent: _onListKey);
    listFocus.addListener(notifyListeners);
  }

  /// Opens the row at the given index.
  final void Function(int index) onActivate;

  /// The filter box's focus node.
  final FocusNode boxNode;
  late final FocusNode listFocus;

  int selected = 0;

  /// How many rows the box found; set by the list on every build.
  int count = 0;

  bool get active => listFocus.hasFocus;

  bool isSelected(int index) => count > 0 && active && index == selected;

  KeyEventResult _onBoxKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.arrowDown ||
        count == 0 ||
        listFocus.context == null) {
      return KeyEventResult.ignored;
    }
    selected = 0;
    listFocus.requestFocus();
    return KeyEventResult.handled;
  }

  KeyEventResult _onListKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown ||
        AppShortcuts.matches('search-next', event)) {
      _move(selected + 1);
      return KeyEventResult.handled;
    }
    // Only the arrow leaves the list at the top; the rebindable key stays put.
    if (key == LogicalKeyboardKey.arrowUp && selected <= 0) {
      boxNode.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        AppShortcuts.matches('search-prev', event)) {
      _move(selected - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      if (selected >= 0 && selected < count) onActivate(selected);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      boxNode.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _move(int to) {
    final next = to.clamp(0, count > 0 ? count - 1 : 0);
    if (next == selected) return;
    selected = next;
    notifyListeners();
  }

  @override
  void dispose() {
    boxNode.onKeyEvent = null;
    listFocus.dispose();
    super.dispose();
  }
}

/// One row of a list that [FilterListNav] drives: draws the selection and
/// scrolls the row into view when it becomes selected.
class FilterNavRow extends StatefulWidget {
  final bool selected;
  final Widget child;

  const FilterNavRow({super.key, required this.selected, required this.child});

  @override
  State<FilterNavRow> createState() => _FilterNavRowState();
}

class _FilterNavRowState extends State<FilterNavRow> {
  @override
  void initState() {
    super.initState();
    if (widget.selected) _scrollIntoView();
  }

  @override
  void didUpdateWidget(FilterNavRow old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected) _scrollIntoView();
  }

  void _scrollIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Scrollable.ensureVisible(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.selected) return widget.child;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: widget.child,
    );
  }
}
