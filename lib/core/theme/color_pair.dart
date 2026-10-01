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
    light: Color(0xFF7A2E1D), // terracotta
    dark: ColorPair._paliDark,
  );
  static const Color _paliDark = Color(0xFFFFB4A3); // light salmon

  /// Default pair for translation text.
  static const ColorPair translation = ColorPair(
    light: Color(0xFF33312E), // warm charcoal
    dark: ColorPair._transDark,
  );
  static const Color _transDark = Color(0xFFE0D6CC); // light beige

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
