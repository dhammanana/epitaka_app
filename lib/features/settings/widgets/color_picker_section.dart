import 'package:flutter/material.dart' hide ColorSwatch;
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import 'color_swatch.dart';

/// Predefined color options for Pāli text.
const List<Color> kPaliTextPresetColors = [
  Color(0xFF7A2E1D), // Default warm brown
  Color(0xFF994532), // Rust red
  Color(0xFFB5651D), // Golden amber
  Color(0xFF8B1A1A), // Deep red
  Color(0xFF3D3D8F), // Indigo
  Color(0xFF2A6B6B), // Teal
  Color(0xFF5D4037), // Coffee brown
  Color(0xFF6A1B9A), // Purple
];

/// Predefined color options for translation text.
const List<Color> kTranslationTextPresetColors = [
  Color(0xFF33312E), // Default dark gray
  Color(0xFF221A14), // Espresso
  Color(0xFF544338), // Warm taupe
  Color(0xFF3C6E47), // Forest green
  Color(0xFF4A6FA5), // Steel blue
  Color(0xFF6B635A), // Charcoal
  Color(0xFF2E7D32), // Green
  Color(0xFF5D4037), // Brown
];

// ── Color Picker Section Widget ───────────────────────────────────────────

/// A reusable color picker section with preset swatches + a custom picker button.
///
/// [currentColor] is the resolved color (shown in the circle indicator),
/// while [selectedColor] is used for comparing against presets to determine
/// which swatch is selected. Usually [selectedColor] should be the light
/// color from the ColorPair (the user's chosen color).
class ColorPickerSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color currentColor;
  final Color selectedColor;
  final List<Color> presetColors;
  final ColorScheme colors;
  final ValueChanged<Color> onColorSelected;
  final VoidCallback onCustomColor;

  const ColorPickerSection({
    super.key,
    required this.title,
    required this.icon,
    required this.currentColor,
    required this.selectedColor,
    required this.presetColors,
    required this.colors,
    required this.onColorSelected,
    required this.onCustomColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colors.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Current color indicator (shows the resolved brightness color)
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: currentColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.outlineVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              // Preset swatches — compare against selectedColor (light color)
              ...presetColors.map((c) => ColorSwatch(
                    color: c,
                    isSelected: selectedColor.toARGB32() == c.toARGB32(),
                    size: 36,
                    iconSize: 14,
                    onTap: () => onColorSelected(c),
                  )),
              // Custom color button
              GestureDetector(
                onTap: onCustomColor,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: presetColors
                              .any((c) => c.toARGB32() == selectedColor.toARGB32())
                          ? colors.outlineVariant
                          : colors.primary,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.colorize,
                    size: 16,
                    color: presetColors
                            .any((c) => c.toARGB32() == selectedColor.toARGB32())
                        ? colors.onSurfaceVariant
                        : colors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Full-Screen Color Picker ──────────────────────────────────────────────

/// A full-screen color picker using the
/// [flutter_colorpicker](https://pub.dev/packages/flutter_colorpicker) package.
///
/// Renders its own [Scaffold] so it can be used either inline (pass an
/// [onBack] to replace the default back button behavior, e.g. when embedded
/// without a Navigator) or pushed as a route (default back arrow is shown).
/// [onApply] is invoked with the picked color when the user taps "Apply".
class ColorPickerScreen extends StatefulWidget {
  final String title;
  final Color initialColor;
  final ValueChanged<Color> onApply;
  final VoidCallback? onBack;

  const ColorPickerScreen({
    super.key,
    required this.title,
    required this.initialColor,
    required this.onApply,
    this.onBack,
  });

  @override
  State<ColorPickerScreen> createState() => _ColorPickerScreenState();
}

class _ColorPickerScreenState extends State<ColorPickerScreen> {
  late Color _pickedColor;

  @override
  void initState() {
    super.initState();
    _pickedColor = widget.initialColor;
  }

  void _close() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: () {
              widget.onApply(_pickedColor);
              _close();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Color picker from flutter_colorpicker package
            ColorPicker(
              pickerColor: _pickedColor,
              onColorChanged: (color) => setState(() => _pickedColor = color),
              enableAlpha: false,
              displayThumbColor: true,
              labelTypes: const [],
              pickerAreaHeightPercent: 0.7,
            ),
            const SizedBox(height: 16),
            // Preview
            Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: _pickedColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.outlineVariant),
              ),
            ),
            const SizedBox(height: 16),
            // Hex display
            Center(
              child: Text(
                '#${_pickedColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens [ColorPickerScreen] as a route and applies the picked color via
/// [onApply] when the user taps "Apply".
Future<void> showColorPickerScreen(
  BuildContext context, {
  required String title,
  required Color initialColor,
  required ValueChanged<Color> onApply,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ColorPickerScreen(
        title: title,
        initialColor: initialColor,
        onApply: onApply,
      ),
    ),
  );
}
