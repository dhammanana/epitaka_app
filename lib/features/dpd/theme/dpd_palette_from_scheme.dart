import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'dpd_palette.dart';

/// WCAG AA for body text.
const double kDpdMinContrast = 4.5;

double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Builds the DPD widgets' palette from an ePitaka [ColorScheme], so DPD
/// entries follow every theme and the custom accent colour instead of the
/// DPD app's own five schemes.
DpdPalette dpdPaletteFromScheme(ColorScheme s) {
  final isDark = s.brightness == Brightness.dark;
  // The DPD widgets put text on the surface and on the shade behind results.
  final shade = s.surfaceContainerHigh;
  final backgrounds = [s.surface, shade];

  // DPD's `light` is always the lighter colour and `dark` the darker, in
  // either brightness; the widgets pick between them by brightness.
  final lightBg = isDark ? s.onSurface : s.surface;
  final darkBg = isDark ? s.surface : s.onSurface;

  Color readable(Color fg) => _readable(fg, backgrounds, s.onSurface);

  final primaryText = readable(s.primary);
  final gray = readable(s.onSurfaceVariant);
  final hueLightness = isDark ? 0.72 : 0.34;
  Color accent(double hue, double saturation) => readable(
    HSLColor.fromAHSL(1, hue, saturation, hueLightness).toColor(),
  );

  return DpdPalette(
    primary: s.primary,
    primaryAlt: Color.lerp(s.primary, isDark ? s.surface : s.onSurface, 0.35)!,
    primaryText: primaryText,
    primaryTextDark: primaryText,
    light: lightBg,
    lightShade: isDark ? Color.lerp(s.onSurface, s.surface, 0.1)! : shade,
    dark: darkBg,
    darkShade: isDark ? shade : Color.lerp(s.onSurface, s.surface, 0.1)!,
    gray: gray,
    grayLight: readable(Color.lerp(s.onSurfaceVariant, s.surface, 0.15)!),
    grayDark: Color.lerp(s.onSurfaceVariant, s.onSurface, 0.5)!,
    grayTransparent: s.outlineVariant,
    secondary: readable(s.secondary),
    freq: _heatMap(s.surface, s.primary, s.onSurface),
    accentRed: accent(0, 0.45),
    accentRedDark: accent(0, 0.45),
    accentGreen: accent(125, 0.35),
    accentGreenDark: accent(125, 0.35),
    accentOrange: accent(32, 0.55),
    accentOrangeDark: accent(32, 0.55),
    accentPurple: accent(255, 0.30),
    accentPurpleDark: accent(255, 0.30),
    accentBrown: accent(22, 0.30),
    accentBrownDark: accent(22, 0.30),
    shadowDefault: [
      BoxShadow(
        offset: const Offset(2, 2),
        blurRadius: 4,
        color: s.shadow.withValues(alpha: isDark ? 0.5 : 0.35),
      ),
    ],
    shadowHover: [
      BoxShadow(
        offset: const Offset(2, 2),
        blurRadius: 4,
        color: s.shadow.withValues(alpha: isDark ? 0.6 : 0.5),
      ),
    ],
  );
}

/// Eleven steps from [surface] toward [primary]. Halfway between a light
/// and a dark colour no text colour reaches AA, so the steps stop at the
/// deepest one on which [text] still reads.
List<Color> _heatMap(Color surface, Color primary, Color text) {
  var reach = 1.0;
  while (reach > 0 &&
      contrastRatio(text, Color.lerp(surface, primary, reach)!) <
          kDpdMinContrast) {
    reach -= 0.02;
  }
  return [
    for (var i = 1; i <= 10; i++) Color.lerp(surface, primary, reach * i / 10)!,
    Color.lerp(surface, primary, reach)!,
  ];
}

/// Moves [fg] toward [toward] until it reads on every one of [backgrounds].
/// A custom accent can be any colour, so its own contrast is not trusted.
Color _readable(Color fg, List<Color> backgrounds, Color toward) {
  for (var t = 0.0; t <= 1.0; t += 0.05) {
    final c = Color.lerp(fg, toward, t)!;
    if (backgrounds.every((bg) => contrastRatio(c, bg) >= kDpdMinContrast)) {
      return c;
    }
  }
  return toward;
}
