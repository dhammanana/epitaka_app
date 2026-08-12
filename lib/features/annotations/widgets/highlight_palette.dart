// lib/features/annotations/widgets/highlight_palette.dart
//
// Small floating color palette shown when the user picks "Highlight" from the
// selection toolbar. Six semantic colors; tapping one creates the highlight.

import 'package:flutter/material.dart';

import '../../../core/utils/app_localizations.dart';
import '../models/annotation.dart';

/// Show a compact palette near [anchor]. Returns the chosen color or null
/// when dismissed.
Future<HighlightColor?> showHighlightColorPalette(
  BuildContext context, {
  required Offset anchor,
  HighlightColor? initialColor,
}) {
  return showGeneralDialog<HighlightColor>(
    context: context,
    barrierDismissible: true,
    barrierLabel: AppLocalizations.of(context).close,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (context, _, __) => Stack(
      children: [
        Positioned(
          left: (anchor.dx - 150).clamp(8, MediaQuery.of(context).size.width - 308),
          top: (anchor.dy - 64).clamp(8, MediaQuery.of(context).size.height - 88),
          child: _HighlightPalette(initialColor: initialColor),
        ),
      ],
    ),
  );
}

class _HighlightPalette extends StatelessWidget {
  final HighlightColor? initialColor;

  const _HighlightPalette({this.initialColor});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick palette — the full extended set lives behind the picker.
            for (final c in HighlightColor.quick)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _ColorDot(
                  color: c,
                  selected: c == initialColor,
                  onTap: () => Navigator.of(context).pop(c),
                ),
              ),
            const SizedBox(width: 4),
            HighlightColorPickerSwatch(
              size: 34,
              onColorPicked: (c) => Navigator.of(context).pop(c),
            ),
          ],
        ),
      ),
    );
  }
}

/// Show a dialog with a grid of EVERY highlight color. Returns the chosen
/// color or null when dismissed. Used by the "more colors" swatch at the
/// end of every inline color row.
Future<HighlightColor?> showHighlightColorPicker(
  BuildContext context, {
  HighlightColor? initialColor,
}) {
  return showDialog<HighlightColor>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        AppLocalizations.of(dialogContext).pickColor,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      content: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: [
          for (final c in HighlightColor.values)
            _ColorDot(
              color: c,
              selected: c == initialColor,
              onTap: () => Navigator.of(dialogContext).pop(c),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(AppLocalizations.of(dialogContext).cancel),
        ),
      ],
    ),
  );
}

/// A rainbow swatch that opens [showHighlightColorPicker]. Shown at the end
/// of the quick color rows (palette, note editor, action sheet) so the full
/// extended palette stays one tap away without overflowing the row.
class HighlightColorPickerSwatch extends StatelessWidget {
  /// Currently selected color (outlined when non-null).
  final HighlightColor? initialColor;

  final double size;
  final ValueChanged<HighlightColor> onColorPicked;

  const HighlightColorPickerSwatch({
    super.key,
    this.initialColor,
    this.size = 28,
    required this.onColorPicked,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: AppLocalizations.of(context).moreColors,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () async {
            final picked = await showHighlightColorPicker(
              context,
              initialColor: initialColor,
            );
            if (picked != null) onColorPicked(picked);
          },
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [for (final c in HighlightColor.values) c.swatch],
              ),
              border: Border.all(color: colors.outlineVariant, width: 1),
            ),
            child: Icon(
              Icons.palette_outlined,
              size: size * 0.55,
              color: Colors.black.withValues(alpha: 0.65),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatefulWidget {
  final HighlightColor color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_ColorDot> createState() => _ColorDotState();
}

class _ColorDotState extends State<_ColorDot> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: widget.color.swatch,
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.selected
                  ? colors.onSurface
                  : colors.outlineVariant.withValues(alpha: 0.8),
              width: widget.selected ? 2.5 : 1,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: widget.color.swatch.withValues(alpha: 0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: widget.selected
              ? const Icon(Icons.check, size: 18, color: Colors.black87)
              : null,
        ),
      ),
    );
  }
}
