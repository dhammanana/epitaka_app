import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/pali_script_converter.dart';
import '../../reader/utils/reader_word_hit_test.dart' show cleanPali;

/// Expands [offset] outwards to the surrounding word.
///
/// `+` counts as a boundary so that tapping either half of a plus-joined
/// compound like `Abhimaṅgala+sammata` searches only the half that was tapped.
@visibleForTesting
String extractWordAt(String text, int offset) {
  if (offset < 0 || offset >= text.length) return '';

  int start = offset;
  int end = offset;

  while (start > 0 && !_isWordBoundary(text[start - 1])) {
    start--;
  }
  while (end < text.length && !_isWordBoundary(text[end])) {
    end++;
  }

  return text.substring(start, end);
}

bool _isWordBoundary(String char) {
  return char == ' ' ||
      char == '\n' ||
      char == '\t' ||
      char == '\r' ||
      char == '+';
}

/// Hands the word under a tap to [onWordTap], so a word inside an entry can be
/// looked up in the same sheet or panel.
///
/// Only a single tap is handled here. With the double-tap setting, the
/// sheet's own selection toolbar already offers "Search" on the selected word.
/// The DPD app's version also owns a `SelectionArea`; here the sheet's wraps
/// this widget, so selection is not duplicated.
class TapSearchWrapper extends ConsumerStatefulWidget {
  const TapSearchWrapper({
    super.key,
    required this.child,
    required this.onWordTap,
  });

  final Widget child;
  final void Function(String word) onWordTap;

  @override
  ConsumerState<TapSearchWrapper> createState() => _TapSearchWrapperState();
}

class _TapSearchWrapperState extends ConsumerState<TapSearchWrapper> {
  Offset? _downPosition;
  int _downTime = 0;

  void _handlePointerDown(PointerDownEvent event) {
    if (ref.read(settingsProvider).wordLookupGesture !=
        WordLookupGesture.singleTap) {
      return;
    }
    _downPosition = event.position;
    _downTime = DateTime.now().millisecondsSinceEpoch;
  }

  void _handlePointerUp(PointerUpEvent event) {
    final down = _downPosition;
    if (down == null) return;
    _downPosition = null;
    // The results can be replaced between the press and the release.
    if (!mounted) return;

    final elapsed = DateTime.now().millisecondsSinceEpoch - _downTime;
    // Ignore long-presses and drags
    if (elapsed > 300 || (event.position - down).distance > 20) return;

    final word = _getWordAtPosition(event.position);
    if (word == null || word.isEmpty) return;
    // After this frame: the tap itself must finish before the sheet rebuilds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onWordTap(word);
    });
    // A post-frame callback does not ask for a frame. On desktop nothing else
    // does after a click, so without this the lookup waits for the next click.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  String? _getWordAtPosition(Offset globalPosition) {
    final result = HitTestResult();
    final view = View.of(context);
    WidgetsBinding.instance.hitTestInView(result, globalPosition, view.viewId);

    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderParagraph) {
        if (_isInsideTappable(target)) return null;
        final localPosition = target.globalToLocal(globalPosition);
        final textPosition = target.getPositionForOffset(localPosition);
        final raw = extractWordAt(
          target.text.toPlainText(),
          textPosition.offset,
        );
        return cleanPali(convertToRomanPali(raw));
      }
    }
    return null;
  }

  /// A button or link inside the entry has its own tap; it is not a word.
  bool _isInsideTappable(RenderObject node) {
    RenderObject? current = node.parent;
    final boundary = context.findRenderObject();
    while (current != null) {
      if (identical(current, boundary)) return false;
      final config = SemanticsConfiguration();
      // ignore: invalid_use_of_protected_member
      current.describeSemanticsConfiguration(config);
      if (config.onTap != null) return true;
      current = current.parent;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      child: widget.child,
    );
  }
}
