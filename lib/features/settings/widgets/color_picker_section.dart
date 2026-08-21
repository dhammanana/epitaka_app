import 'dart:math' as math;

import 'package:flutter/material.dart' hide ColorSwatch;
import 'package:flutter/services.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
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

// ── Color Formats ──────────────────────────────────────────────────────────

/// Supported color display and input formats.
enum ColorFormat {
  hex('Hex'),
  rgb('RGB'),
  hsl('HSL'),
  hsv('HSV');

  final String label;
  const ColorFormat(this.label);
}

// ── 2D Saturation / Value Picker ──────────────────────────────────────────

class _SaturationValuePicker extends StatelessWidget {
  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;

  const _SaturationValuePicker({
    required this.hsv,
    required this.onChanged,
  });

  void _handleGesture(Offset localPosition, Size size) {
    final saturation = (localPosition.dx / size.width).clamp(0.0, 1.0);
    final value = (1.0 - (localPosition.dy / size.height)).clamp(0.0, 1.0);
    onChanged(hsv.withSaturation(saturation).withValue(value));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = (width * 0.58).clamp(160.0, 240.0);
        final thumbX = (hsv.saturation * width).clamp(0.0, width);
        final thumbY = ((1.0 - hsv.value) * height).clamp(0.0, height);

        return GestureDetector(
          onPanDown: (details) =>
              _handleGesture(details.localPosition, Size(width, height)),
          onPanUpdate: (details) =>
              _handleGesture(details.localPosition, Size(width, height)),
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 2D HSV Saturation/Value gradient
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Base pure hue color
                      Container(
                        color: HSVColor.fromAHSV(1.0, hsv.hue, 1.0, 1.0).toColor(),
                      ),
                      // Horizontal white gradient (saturation)
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Colors.white, Colors.transparent],
                          ),
                        ),
                      ),
                      // Vertical black gradient (value/brightness)
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Thumb circle with white ring
                Positioned(
                  left: thumbX - 12,
                  top: thumbY - 12,
                  child: IgnorePointer(
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Hue Rainbow Slider ────────────────────────────────────────────────────

class _HueSlider extends StatelessWidget {
  final double hue;
  final ValueChanged<double> onChanged;

  const _HueSlider({
    required this.hue,
    required this.onChanged,
  });

  static const List<Color> _rainbowColors = [
    Color(0xFFFF0000), // Red
    Color(0xFFFF8800), // Orange
    Color(0xFFFFFF00), // Yellow
    Color(0xFF00FF00), // Green
    Color(0xFF00FFFF), // Cyan
    Color(0xFF0000FF), // Blue
    Color(0xFFFF00FF), // Magenta
    Color(0xFFFF0000), // Red
  ];

  void _handleGesture(Offset localPosition, double width) {
    final fraction = (localPosition.dx / width).clamp(0.0, 1.0);
    onChanged(fraction * 360.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final thumbX = ((hue / 360.0) * width).clamp(0.0, width);
        final hueColor = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();

        return GestureDetector(
          onPanDown: (details) => _handleGesture(details.localPosition, width),
          onPanUpdate: (details) => _handleGesture(details.localPosition, width),
          child: SizedBox(
            width: width,
            height: 26,
            child: Stack(
              alignment: Alignment.centerLeft,
              clipBehavior: Clip.none,
              children: [
                // Rainbow track
                Container(
                  width: width,
                  height: 14,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    gradient: const LinearGradient(
                      colors: _rainbowColors,
                    ),
                  ),
                ),
                // Circular thumb with white outer ring and colored center
                Positioned(
                  left: thumbX - 12,
                  child: IgnorePointer(
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hueColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Reusable Color Picker Content Widget ───────────────────────────────────

/// Reusable color picker view with 2D palette, rainbow hue slider, text preview,
/// direct hex input, format switching, copy button, and random palette button.
class ColorPickerContent extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorChanged;
  final String? sampleText;

  const ColorPickerContent({
    super.key,
    required this.initialColor,
    required this.onColorChanged,
    this.sampleText,
  });

  @override
  State<ColorPickerContent> createState() => _ColorPickerContentState();
}

class _ColorPickerContentState extends State<ColorPickerContent> {
  late HSVColor _hsv;
  late Color _pickedColor;
  ColorFormat _selectedFormat = ColorFormat.hex;
  late TextEditingController _textController;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _pickedColor = widget.initialColor;
    _hsv = HSVColor.fromColor(_pickedColor);
    _textController = TextEditingController(text: _colorToHex(_pickedColor));
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _syncControllerWithColor(_pickedColor);
    }
  }

  // ── Color Utilities ──────────────────────────────────────────────────────

  static int _r(Color c) => (c.toARGB32() >> 16) & 0xFF;
  static int _g(Color c) => (c.toARGB32() >> 8) & 0xFF;
  static int _b(Color c) => c.toARGB32() & 0xFF;

  static String _colorToHex(Color c) {
    final argb = c.toARGB32();
    return (argb & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
  }

  static Color? _hexToColor(String input) {
    var clean = input
        .replaceAll('#', '')
        .replaceAll('0x', '')
        .replaceAll('0X', '')
        .trim();
    if (clean.length == 3) {
      clean = clean.split('').map((char) => '$char$char').join();
    }
    if (clean.length != 6 && clean.length != 8) return null;
    final val = int.tryParse(clean, radix: 16);
    if (val == null) return null;
    if (clean.length == 6) {
      return Color(0xFF000000 | val);
    }
    return Color(val);
  }

  static String _colorToRgb(Color c) => '${_r(c)}, ${_g(c)}, ${_b(c)}';

  static Color? _rgbToColor(String input) {
    final clean = input
        .replaceAll('rgb', '')
        .replaceAll('RGB', '')
        .replaceAll('(', '')
        .replaceAll(')', '')
        .trim();
    final parts =
        clean.split(RegExp(r'[, ]+')).where((s) => s.isNotEmpty).toList();
    if (parts.length < 3) return null;
    final r = int.tryParse(parts[0]);
    final g = int.tryParse(parts[1]);
    final b = int.tryParse(parts[2]);
    if (r == null || g == null || b == null) return null;
    if (r < 0 || r > 255 || g < 0 || g > 255 || b < 0 || b > 255) return null;
    return Color.fromARGB(255, r, g, b);
  }

  static String _colorToHsl(Color c) {
    final hsl = HSLColor.fromColor(c);
    return '${hsl.hue.round()}, ${(hsl.saturation * 100).round()}%, ${(hsl.lightness * 100).round()}%';
  }

  static Color? _hslToColor(String input) {
    final clean = input
        .replaceAll('hsl', '')
        .replaceAll('HSL', '')
        .replaceAll('(', '')
        .replaceAll(')', '')
        .replaceAll('%', '')
        .trim();
    final parts =
        clean.split(RegExp(r'[, ]+')).where((s) => s.isNotEmpty).toList();
    if (parts.length < 3) return null;
    final h = double.tryParse(parts[0]);
    final s = double.tryParse(parts[1]);
    final l = double.tryParse(parts[2]);
    if (h == null || s == null || l == null) return null;
    if (h < 0 || h > 360 || s < 0 || s > 100 || l < 0 || l > 100) return null;
    return HSLColor.fromAHSL(
      1.0,
      h.clamp(0.0, 360.0),
      (s / 100.0).clamp(0.0, 1.0),
      (l / 100.0).clamp(0.0, 1.0),
    ).toColor();
  }

  static String _colorToHsv(Color c) {
    final hsv = HSVColor.fromColor(c);
    return '${hsv.hue.round()}, ${(hsv.saturation * 100).round()}%, ${(hsv.value * 100).round()}%';
  }

  static Color? _hsvToColor(String input) {
    final clean = input
        .replaceAll('hsv', '')
        .replaceAll('HSV', '')
        .replaceAll('(', '')
        .replaceAll(')', '')
        .replaceAll('%', '')
        .trim();
    final parts =
        clean.split(RegExp(r'[, ]+')).where((s) => s.isNotEmpty).toList();
    if (parts.length < 3) return null;
    final h = double.tryParse(parts[0]);
    final s = double.tryParse(parts[1]);
    final v = double.tryParse(parts[2]);
    if (h == null || s == null || v == null) return null;
    if (h < 0 || h > 360 || s < 0 || s > 100 || v < 0 || v > 100) return null;
    return HSVColor.fromAHSV(
      1.0,
      h.clamp(0.0, 360.0),
      (s / 100.0).clamp(0.0, 1.0),
      (v / 100.0).clamp(0.0, 1.0),
    ).toColor();
  }

  void _syncControllerWithColor(Color color) {
    switch (_selectedFormat) {
      case ColorFormat.hex:
        _textController.text = _colorToHex(color);
        break;
      case ColorFormat.rgb:
        _textController.text = _colorToRgb(color);
        break;
      case ColorFormat.hsl:
        _textController.text = _colorToHsl(color);
        break;
      case ColorFormat.hsv:
        _textController.text = _colorToHsv(color);
        break;
    }
  }

  void _onSatValChanged(HSVColor newHsv) {
    setState(() {
      _hsv = newHsv;
      _pickedColor = newHsv.toColor();
    });
    widget.onColorChanged(_pickedColor);
    if (!_focusNode.hasFocus) {
      _syncControllerWithColor(_pickedColor);
    }
  }

  void _onHueChanged(double newHue) {
    setState(() {
      _hsv = _hsv.withHue(newHue);
      _pickedColor = _hsv.toColor();
    });
    widget.onColorChanged(_pickedColor);
    if (!_focusNode.hasFocus) {
      _syncControllerWithColor(_pickedColor);
    }
  }

  void _onTextChanged(String text) {
    Color? parsedColor;
    switch (_selectedFormat) {
      case ColorFormat.hex:
        parsedColor = _hexToColor(text);
        break;
      case ColorFormat.rgb:
        parsedColor = _rgbToColor(text);
        break;
      case ColorFormat.hsl:
        parsedColor = _hslToColor(text);
        break;
      case ColorFormat.hsv:
        parsedColor = _hsvToColor(text);
        break;
    }

    if (parsedColor != null &&
        parsedColor.toARGB32() != _pickedColor.toARGB32()) {
      setState(() {
        _pickedColor = parsedColor!;
        _hsv = HSVColor.fromColor(_pickedColor);
      });
      widget.onColorChanged(_pickedColor);
    }
  }

  void _copyColorToClipboard() {
    String textToCopy;
    switch (_selectedFormat) {
      case ColorFormat.hex:
        textToCopy = '#${_colorToHex(_pickedColor)}';
        break;
      case ColorFormat.rgb:
        textToCopy = 'rgb(${_colorToRgb(_pickedColor)})';
        break;
      case ColorFormat.hsl:
        textToCopy = 'hsl(${_colorToHsl(_pickedColor)})';
        break;
      case ColorFormat.hsv:
        textToCopy = 'hsv(${_colorToHsv(_pickedColor)})';
        break;
    }

    Clipboard.setData(ClipboardData(text: textToCopy));
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $textToCopy to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _generateRandomColor() {
    final random = math.Random();
    final hue = random.nextDouble() * 360.0;
    final saturation = 0.45 + random.nextDouble() * 0.50;
    final value = 0.55 + random.nextDouble() * 0.40;
    final hsv = HSVColor.fromAHSV(1.0, hue, saturation, value);
    final color = hsv.toColor();

    _focusNode.unfocus();
    setState(() {
      _hsv = hsv;
      _pickedColor = color;
      _syncControllerWithColor(color);
    });
    widget.onColorChanged(color);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isHex = _selectedFormat == ColorFormat.hex;
    final loc = AppLocalizations.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 2D Saturation / Value area
        _SaturationValuePicker(
          hsv: _hsv,
          onChanged: _onSatValChanged,
        ),
        const SizedBox(height: 12),

        // Rainbow Hue slider right under the palette
        _HueSlider(
          hue: _hsv.hue,
          onChanged: _onHueChanged,
        ),
        const SizedBox(height: 14),

        // Color Input Card (preview circle + format input + copy + dropdown)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.8),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              // Color swatch preview circle
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _pickedColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Optional prefix (e.g. '#' for Hex)
              if (isHex)
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Text(
                    '#',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),

              // Editable color code input
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  inputFormatters: isHex
                      ? [_HexInputFormatter()]
                      : [LengthLimitingTextInputFormatter(24)],
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                    letterSpacing: isHex ? 1.0 : 0.4,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 4,
                    ),
                    border: InputBorder.none,
                  ),
                  textCapitalization: isHex
                      ? TextCapitalization.characters
                      : TextCapitalization.none,
                  onChanged: _onTextChanged,
                ),
              ),

              // Copy to clipboard button
              IconButton(
                icon: Icon(
                  Icons.copy_rounded,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
                tooltip: 'Copy color',
                splashRadius: 18,
                visualDensity: VisualDensity.compact,
                onPressed: _copyColorToClipboard,
              ),

              const SizedBox(width: 4),

              // Format selector dropdown
              PopupMenuButton<ColorFormat>(
                initialValue: _selectedFormat,
                onSelected: (format) {
                  setState(() {
                    _selectedFormat = format;
                    _syncControllerWithColor(_pickedColor);
                  });
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                itemBuilder: (context) => ColorFormat.values.map((format) {
                  final isSelected = format == _selectedFormat;
                  return PopupMenuItem<ColorFormat>(
                    value: format,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          format.label,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? colors.primary
                                : colors.onSurface,
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check, size: 16, color: colors.primary),
                      ],
                    ),
                  );
                }).toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedFormat.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 15,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Live text preview card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    loc.preview,
                    style: TextStyle(
                      fontFamily: AppTypography.translationFont,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _pickedColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                widget.sampleText ?? 'Evaṃ me sutaṃ… Thus have I heard…',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _pickedColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Random palette button
        OutlinedButton(
          onPressed: _generateRandomColor,
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.onSurface,
            side: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.8),
              width: 1.2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
          ),
          child: Text(
            'Random palette',
            style: TextStyle(
              fontFamily: AppTypography.translationFont,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colors.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Color Picker Dialog ───────────────────────────────────────────────────

/// Modal dialog for color picking with live text preview, hex input, and actions.
class _ColorPickerDialog extends StatefulWidget {
  final String title;
  final Color initialColor;
  final ValueChanged<Color> onApply;
  final String? sampleText;

  const _ColorPickerDialog({
    required this.title,
    required this.initialColor,
    required this.onApply,
    this.sampleText,
  });

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _pickedColor;

  @override
  void initState() {
    super.initState();
    _pickedColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dialog header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontFamily: AppTypography.translationFont,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    visualDensity: VisualDensity.compact,
                    splashRadius: 18,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Scrollable color picker content
              Flexible(
                child: SingleChildScrollView(
                  child: ColorPickerContent(
                    initialColor: widget.initialColor,
                    sampleText: widget.sampleText,
                    onColorChanged: (c) => _pickedColor = c,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Dialog action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(loc.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      widget.onApply(_pickedColor);
                      Navigator.of(context).pop();
                    },
                    child: Text(loc.apply),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Full-Screen / Inline Color Picker ─────────────────────────────────────

/// A color picker screen/widget that can be used inline (e.g. embedded with
/// [onBack] inside wizards) or pushed as a route.
class ColorPickerScreen extends StatefulWidget {
  final String title;
  final Color initialColor;
  final ValueChanged<Color> onApply;
  final VoidCallback? onBack;
  final String? sampleText;

  const ColorPickerScreen({
    super.key,
    required this.title,
    required this.initialColor,
    required this.onApply,
    this.onBack,
    this.sampleText,
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
    final loc = AppLocalizations.of(context);

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
            child: Text(loc.apply),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ColorPickerContent(
          initialColor: widget.initialColor,
          sampleText: widget.sampleText,
          onColorChanged: (c) => _pickedColor = c,
        ),
      ),
    );
  }
}

// ── Custom Input Formatter for Hex Codes ───────────────────────────────────

/// Formatter that automatically removes leading hashes, discards non-hex
/// characters, uppercases the text, and limits to 6 characters.
class _HexInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final clean = newValue.text
        .replaceAll('#', '')
        .replaceAll(RegExp(r'[^0-9a-fA-F]'), '')
        .toUpperCase();
    final truncated = clean.length > 6 ? clean.substring(0, 6) : clean;
    return TextEditingValue(
      text: truncated,
      selection: TextSelection.collapsed(offset: truncated.length),
    );
  }
}

/// Opens the color picker as a modal dialog with text preview, direct hex
/// input, format switching, copy button, and random palette button.
Future<void> showColorPickerScreen(
  BuildContext context, {
  required String title,
  required Color initialColor,
  required ValueChanged<Color> onApply,
  String? sampleText,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _ColorPickerDialog(
      title: title,
      initialColor: initialColor,
      onApply: onApply,
      sampleText: sampleText,
    ),
  );
}
