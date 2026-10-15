import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/utils/app_localizations.dart';
import 'dictionary_search_shared.dart';

/// The whole lookup history as a list over the results, newest first, drawn
/// like the suggestion box. A tap on a word looks it up. [words] come oldest
/// first, as the history keeps them.
///
/// With a keyboard or mouse the newest word takes focus when the list opens,
/// so Down, Up and Enter work at once, and Escape closes the list.
class LookupHistoryList extends StatefulWidget {
  const LookupHistoryList({
    super.key,
    required this.words,
    required this.colors,
    required this.onTap,
    required this.onClose,
  });

  final List<String> words;
  final ColorScheme colors;
  final void Function(String word) onTap;
  final VoidCallback onClose;

  @override
  State<LookupHistoryList> createState() => _LookupHistoryListState();
}

class _LookupHistoryListState extends State<LookupHistoryList> {
  final _listNode = FocusNode(
    debugLabel: 'lookup history list',
    skipTraversal: true,
  );
  final _firstRowNode = FocusNode(debugLabel: 'lookup history first row');
  // Where the keyboard was before the list took it, for Escape to hand back.
  FocusNode? _previousFocus;

  @override
  void initState() {
    super.initState();
    _previousFocus = FocusManager.instance.primaryFocus;
    // Touch leaves focus alone: moving it would close the phone's keyboard.
    if (FocusManager.instance.highlightMode != FocusHighlightMode.traditional) {
      return;
    }
    // After the first frame, so the first row exists to take the focus.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      (widget.words.isEmpty ? _listNode : _firstRowNode).requestFocus();
    });
  }

  @override
  void dispose() {
    _listNode.dispose();
    _firstRowNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    widget.onClose();
    // A node whose widget is gone keeps its context but loses its parent;
    // asking it for focus would only be deferred until it came back.
    if (_previousFocus?.parent != null) _previousFocus!.requestFocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final words = widget.words;
    final colors = widget.colors;
    return Focus(
      focusNode: _listNode,
      onKeyEvent: _onKey,
      child: Material(
        color: colors.surface,
        child: Container(
          margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        loc.dictionaryHeaderHistoryTitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      iconSize: 18,
                      visualDensity: VisualDensity.compact,
                      tooltip: loc.closePanel,
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 4),
                  itemCount: words.length,
                  itemBuilder: (context, i) {
                    final word = words[words.length - 1 - i];
                    return SuggestionTile(
                      word: word,
                      colors: colors,
                      focusNode: i == 0 ? _firstRowNode : null,
                      onTap: () => widget.onTap(word),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
