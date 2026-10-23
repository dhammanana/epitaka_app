import 'package:flutter/material.dart';

/// A pair of colors for light and dark mode.
///
/// When a user picks a color in light mode, the dark-mode variant is
/// automatically derived so the text remains readable on dark backgrounds.
class ColorPair {
  final Color light;
  final Color dark;

  // True once the user picked the dark colour themselves. Until then a new
  // light colour also re-derives the dark one; after, it never touches it.
  final bool darkPicked;

  const ColorPair({
    required this.light,
    required this.dark,
    this.darkPicked = false,
  });

  /// This pair with a new light colour. The dark colour follows it only
  /// while the user has not picked one.
  ColorPair withLight(Color lightColor) => darkPicked
      ? ColorPair(light: lightColor, dark: dark, darkPicked: true)
      : ColorPair.fromLight(lightColor);

  /// This pair with a dark colour the user picked.
  ColorPair withDark(Color darkColor) =>
      ColorPair(light: light, dark: darkColor, darkPicked: true);

  /// Resolve to the active color based on the current brightness.
  Color resolve(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// Derive a readable dark-mode variant from [lightColor].
  ///
  /// Lightens the color significantly and reduces saturation so it
  /// stands out against the dark background (#1a120c).  The minimum
  /// lightness is deliberately high (0.70) so even very dark light-mode
  /// colours produce readable text on dark backgrounds.
  static Color deriveDark(Color lightColor) {
    final hsl = HSLColor.fromColor(lightColor);
    // Aggressively boost lightness for dark-background readability
    final lightness = (hsl.lightness * 4.0).clamp(0.70, 0.93);
    // Reduce saturation so the colour feels natural on dark bg
    final saturation = (hsl.saturation * 0.65).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).withSaturation(saturation).toColor();
  }

  /// Create a [ColorPair] from a single light-mode color, auto-deriving
  /// the dark-mode variant.
  factory ColorPair.fromLight(Color lightColor) =>
      ColorPair(light: lightColor, dark: deriveDark(lightColor));

  /// Default pair for Pāli text.
  static const ColorPair pali = ColorPair(
    light: Color(0xFF000000), // black
    dark: ColorPair._paliDark,
  );
  static const Color _paliDark = Color(0xFFE8E1D9); // warm off-white

  /// Neutral fallback for translation text, used where no language is known.
  static const ColorPair translation = ColorPair(
    light: Color(0xFF33312E), // warm charcoal
    dark: ColorPair._transDark,
  );
  static const Color _transDark = Color(0xFFE0D6CC); // light beige

  /// Translation colours in display order. Takes no language list, so any
  /// number of translations works; the palette cycles past its length.
  static const List<Color> translationPalette = [
    Color(0xFF4A6FA5), // steel blue
    Color(0xFF3C6E47), // forest green
    Color(0xFF2A6B6B), // teal
    Color(0xFF994532), // rust
    Color(0xFF6A1B9A), // purple
    Color(0xFF5D4037), // brown
  ];

  /// The preset pair for the translation at [index] in the visible order.
  static ColorPair translationAt(int index) => ColorPair.fromLight(
    translationPalette[index % translationPalette.length],
  );

  Map<String, dynamic> toJson() => {
    'light': light.toARGB32().toRadixString(16).padLeft(8, '0'),
    'dark': dark.toARGB32().toRadixString(16).padLeft(8, '0'),
    'darkPicked': darkPicked,
  };

  factory ColorPair.fromJson(Map<String, dynamic> json) {
    final lightHex = json['light'] as String?;
    final darkHex = json['dark'] as String?;
    if (lightHex == null || darkHex == null) return ColorPair.pali;
    final lightVal = int.tryParse(lightHex, radix: 16);
    final darkVal = int.tryParse(darkHex, radix: 16);
    if (lightVal == null || darkVal == null) return ColorPair.pali;
    final light = Color(lightVal);
    final dark = Color(darkVal);
    // Saves from before the flag: a dark colour that is neither derived
    // from the light one nor a built-in default was picked by the user.
    final darkPicked =
        json['darkPicked'] as bool? ??
        (dark != deriveDark(light) &&
            !(light == pali.light && dark == pali.dark) &&
            !(light == translation.light && dark == translation.dark));
    return ColorPair(light: light, dark: dark, darkPicked: darkPicked);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ColorPair &&
          light == other.light &&
          dark == other.dark &&
          darkPicked == other.darkPicked;

  @override
  int get hashCode => Object.hash(light, dark, darkPicked);

  @override
  String toString() =>
      'ColorPair(light: $light, dark: $dark, darkPicked: $darkPicked)';
}
