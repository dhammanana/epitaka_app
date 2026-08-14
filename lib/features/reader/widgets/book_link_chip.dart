import 'package:flutter/material.dart';

import '../../../core/utils/pali_script_converter.dart';
import '../../../shared/widgets/pali_text.dart';

/// A small decorative chip that displays a linked Pāli word.
///
/// Rendered below a line when that line has book links. The chip shows
/// the linked word and provides a visual cue that tapping it opens a
/// bottom sheet with the linked commentary/annotation content.
///
/// The [word] is converted to the user's selected Pāli [script] (if any)
/// so it matches the display style of the surrounding text.
class BookLinkChip extends StatelessWidget {
  final String word;
  final Color color;
  final VoidCallback onTap;

  /// The target Pāli script to convert the word to.
  final Script? script;

  /// When true (keyboard navigation selected this chip), draw a stronger
  /// border and a filled tint so the focused chip is unmistakable.
  final bool selected;

  const BookLinkChip({
    super.key,
    required this.word,
    required this.color,
    required this.onTap,
    this.script,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color.withValues(alpha: 0.85);

    return Padding(
      padding: const EdgeInsets.only(right: 4, bottom: 2),
      child: SelectionContainer.disabled(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: selected
                  ? effectiveColor.withValues(alpha: 0.28)
                  : effectiveColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? effectiveColor : effectiveColor.withValues(alpha: 0.35),
                width: selected ? 1.6 : 0.8,
              ),
            ),
            child: PaliTextStatic(
              word,
              script,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontStyle: FontStyle.italic,
                color: effectiveColor,
                height: 1.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
