import 'package:flutter/material.dart';

/// The ePitaka color palette derived from the "Digital Manuscript" design spec.
///
/// Light mode uses warm paper tones; dark mode uses inverse surfaces.
class AppColors {
  AppColors._();

  // ── Light Mode ──────────────────────────────────────────────────────
  static const Color lightPrimary = Color(0xff8f4900);
  static const Color lightOnPrimary = Color(0xffffffff);
  static const Color lightPrimaryContainer = Color(0xffaf6018);
  static const Color lightOnPrimaryContainer = Color(0xfffffbff);
  static const Color lightSecondary = Color(0xff994532);
  static const Color lightOnSecondary = Color(0xffffffff);
  static const Color lightSecondaryContainer = Color(0xfffe947c);
  static const Color lightOnSecondaryContainer = Color(0xff762b1a);
  static const Color lightTertiary = Color(0xff006387);
  static const Color lightOnTertiary = Color(0xffffffff);
  static const Color lightTertiaryContainer = Color(0xff007daa);
  static const Color lightOnTertiaryContainer = Color(0xfffcfcff);
  static const Color lightError = Color(0xffba1a1a);
  static const Color lightOnError = Color(0xffffffff);
  static const Color lightErrorContainer = Color(0xffffdad6);
  static const Color lightOnErrorContainer = Color(0xff93000a);
  static const Color lightSurface = Color(0xfffbf7f0); // Paper
  static const Color lightOnSurface = Color(0xff221a14);
  static const Color lightSurfaceCard = Color(0xfffff8f5);
  static const Color lightSurfaceContainerHighest = Color(0xfff0dfd6);
  static const Color lightOnSurfaceVariant = Color(0xff544338);
  static const Color lightOutline = Color(0xff877366);
  static const Color lightOutlineVariant = Color(0xffdac2b3);
  static const Color lightSurfaceDim = Color(0xffe7d7ce);
  static const Color lightSurfaceBright = Color(0xfffff8f5);
  static const Color lightSurfaceContainerLowest = Color(0xffffffff);
  static const Color lightSurfaceContainerLow = Color(0xfffff1e9);
  static const Color lightSurfaceContainer = Color(0xfffbebe1);
  static const Color lightSurfaceContainerHigh = Color(0xfff5e5dc);
  static const Color lightSurfaceContainerHighest2 = Color(0xfff0dfd6);
  static const Color lightInverseSurface = Color(0xff382f28);
  static const Color lightInversePrimary = Color(0xffffb781);

  // ── Dark Mode ───────────────────────────────────────────────────────
  static const Color darkPrimary = Color(0xffffb781);
  static const Color darkOnPrimary = Color(0xff4f2600);
  static const Color darkPrimaryContainer = Color(0xff703800);
  static const Color darkOnPrimaryContainer = Color(0xffffdcc5);
  static const Color darkSecondary = Color(0xffffb4a3);
  static const Color darkOnSecondary = Color(0xff5f1a0b);
  static const Color darkSecondaryContainer = Color(0xff7a2e1d);
  static const Color darkOnSecondaryContainer = Color(0xffffdad2);
  static const Color darkTertiary = Color(0xff7cd0ff);
  static const Color darkOnTertiary = Color(0xff00344a);
  static const Color darkTertiaryContainer = Color(0xff004c69);
  static const Color darkOnTertiaryContainer = Color(0xffc4e7ff);
  static const Color darkError = Color(0xffffb4ab);
  static const Color darkOnError = Color(0xff690005);
  static const Color darkErrorContainer = Color(0xff93000a);
  static const Color darkOnErrorContainer = Color(0xffffdad6);
  static const Color darkSurface = Color(0xff1a120c);
  static const Color darkOnSurface = Color(0xfff0dfd6);
  static const Color darkSurfaceContainerHighest = Color(0xff514338);
  static const Color darkOnSurfaceVariant = Color(0xffdac2b3);
  static const Color darkOutline = Color(0xffa38d7e);
  static const Color darkOutlineVariant = Color(0xff514338);
  static const Color darkSurfaceDim = Color(0xff1a120c);
  static const Color darkSurfaceBright = Color(0xff423830);
  static const Color darkSurfaceContainerLowest = Color(0xff150e08);
  static const Color darkSurfaceContainerLow = Color(0xff221a14);
  static const Color darkSurfaceContainer = Color(0xff271e18);
  static const Color darkSurfaceContainerHigh = Color(0xff322922);
  static const Color darkSurfaceContainerHighest2 = Color(0xff3d332c);
  static const Color darkInverseSurface = Color(0xfff0dfd6);
  static const Color darkInversePrimary = Color(0xff8f4900);

  // ── Accent presets (swatch picker in Appearance settings) ────────────
  static const Color accentSaffron = Color(0xffB5651D);
  static const Color accentMaroon = Color(0xff8B1A1A);
  static const Color accentGreen = Color(0xff3C6E47);
  static const Color accentIndigo = Color(0xff3D3D8F);
  static const Color accentSlateBlue = Color(0xff4A6FA5);
  static const Color accentRose = Color(0xff8E3A59);
  static const Color accentTeal = Color(0xff2A6B6B);
  static const Color accentGold = Color(0xff9A7B2E);

  static const Color successGreen = Color(0xff2E7D32);
  static const Color warningAmber = Color(0xffF9A825);

  static const List<Color> accentPresets = [
    accentSaffron,
    accentMaroon,
    accentGreen,
    accentIndigo,
    accentSlateBlue,
    accentRose,
    accentTeal,
    accentGold,
  ];

  // ── ColorScheme builders ────────────────────────────────────────────

  static ColorScheme lightColorScheme() {
    return ColorScheme(
      brightness: Brightness.light,
      primary: lightPrimary,
      onPrimary: lightOnPrimary,
      primaryContainer: lightPrimaryContainer,
      onPrimaryContainer: lightOnPrimaryContainer,
      secondary: lightSecondary,
      onSecondary: lightOnSecondary,
      secondaryContainer: lightSecondaryContainer,
      onSecondaryContainer: lightOnSecondaryContainer,
      tertiary: lightTertiary,
      onTertiary: lightOnTertiary,
      tertiaryContainer: lightTertiaryContainer,
      onTertiaryContainer: lightOnTertiaryContainer,
      error: lightError,
      onError: lightOnError,
      errorContainer: lightErrorContainer,
      onErrorContainer: lightOnErrorContainer,
      surface: lightSurface,
      onSurface: lightOnSurface,
      surfaceContainerHighest: lightSurfaceContainerHighest,
      onSurfaceVariant: lightOnSurfaceVariant,
      outline: lightOutline,
      outlineVariant: lightOutlineVariant,
      inverseSurface: lightInverseSurface,
      inversePrimary: lightInversePrimary,
    );
  }

  static ColorScheme darkColorScheme() {
    return ColorScheme(
      brightness: Brightness.dark,
      primary: darkPrimary,
      onPrimary: darkOnPrimary,
      primaryContainer: darkPrimaryContainer,
      onPrimaryContainer: darkOnPrimaryContainer,
      secondary: darkSecondary,
      onSecondary: darkOnSecondary,
      secondaryContainer: darkSecondaryContainer,
      onSecondaryContainer: darkOnSecondaryContainer,
      tertiary: darkTertiary,
      onTertiary: darkOnTertiary,
      tertiaryContainer: darkTertiaryContainer,
      onTertiaryContainer: darkOnTertiaryContainer,
      error: darkError,
      onError: darkOnError,
      errorContainer: darkErrorContainer,
      onErrorContainer: darkOnErrorContainer,
      surface: darkSurface,
      onSurface: darkOnSurface,
      surfaceContainerHighest: darkSurfaceContainerHighest,
      onSurfaceVariant: darkOnSurfaceVariant,
      outline: darkOutline,
      outlineVariant: darkOutlineVariant,
      inverseSurface: darkInverseSurface,
      inversePrimary: darkInversePrimary,
    );
  }
}
