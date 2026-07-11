import 'package:flutter/material.dart';

/// A small decorative chip that displays a linked Pāli word.
///
/// Rendered below a line when that line has book links. The chip shows
/// the linked word and provides a visual cue that tapping it opens a
/// bottom sheet with the linked commentary/annotation content.
class BookLinkChip extends StatelessWidget {
  final String word;
  final Color color;
  final VoidCallback onTap;

  const BookLinkChip({
    super.key,
    required this.word,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color.withValues(alpha: 0.85);

    return Padding(
      padding: const EdgeInsets.only(right: 4, bottom: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: effectiveColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: effectiveColor.withValues(alpha: 0.35),
              width: 0.8,
            ),
          ),
          child: Text(
            word,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              color: effectiveColor,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}
