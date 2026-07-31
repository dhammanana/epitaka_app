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
  static const Color accentCrimson = Color(0xffC62828);
  static const Color accentDeepPurple = Color(0xff5E35B1);
  static const Color accentAmber = Color(0xffFF8F00);
  static const Color accentCyan = Color(0xff00838F);
  static const Color accentLime = Color(0xff558B2F);
  static const Color accentDeepOrange = Color(0xffBF360C);
  static const Color accentBrown = Color(0xff5D4037);
  static const Color accentBlueGrey = Color(0xff455A64);

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
    accentCrimson,
    accentDeepPurple,
    accentAmber,
    accentCyan,
    accentLime,
    accentDeepOrange,
    accentBrown,
    accentBlueGrey,
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

  // ── Extra theme palettes ──────────────────────────────────────────────

  /// „Paññā-āloka“ (Sepia) — warm amber "illuminating wisdom" light theme.
  static ColorScheme sepiaColorScheme() {
    return ColorScheme(
      brightness: Brightness.light,
      primary: const Color(0xff9A5B26),
      onPrimary: const Color(0xffffffff),
      primaryContainer: const Color(0xffF5DCB8),
      onPrimaryContainer: const Color(0xff3B2A10),
      secondary: const Color(0xff7C5B3D),
      onSecondary: const Color(0xffffffff),
      secondaryContainer: const Color(0xffF6E0C4),
      onSecondaryContainer: const Color(0xff32200E),
      tertiary: const Color(0xff5C6546),
      onTertiary: const Color(0xffffffff),
      tertiaryContainer: const Color(0xffDCE8C8),
      onTertiaryContainer: const Color(0xff1B250D),
      error: const Color(0xffBA1A1A),
      onError: const Color(0xffffffff),
      errorContainer: const Color(0xffffdad6),
      onErrorContainer: const Color(0xff93000a),
      surface: const Color(0xffF6EAD3),
      onSurface: const Color(0xff3D3322),
      surfaceContainerLowest: const Color(0xffffffff),
      surfaceContainerLow: const Color(0xffF0E4CB),
      surfaceContainer: const Color(0xffEBDEC4),
      surfaceContainerHigh: const Color(0xffE5D7BA),
      surfaceContainerHighest: const Color(0xffDFD1B1),
      onSurfaceVariant: const Color(0xff6C5D47),
      outline: const Color(0xff95836B),
      outlineVariant: const Color(0xffD6C3A5),
      inverseSurface: const Color(0xff2F291A),
      inversePrimary: const Color(0xffffb87f),
    );
  }

  /// „Vimutti-rasa“ (Ocean) — cool soft-blue "taste of freedom" light theme.
  static ColorScheme oceanColorScheme() {
    return ColorScheme(
      brightness: Brightness.light,
      primary: const Color(0xff00639B),
      onPrimary: const Color(0xffffffff),
      primaryContainer: const Color(0xffC9E6FF),
      onPrimaryContainer: const Color(0xff001E31),
      secondary: const Color(0xff526070),
      onSecondary: const Color(0xffffffff),
      secondaryContainer: const Color(0xffD5E4F7),
      onSecondaryContainer: const Color(0xff0F1D2A),
      tertiary: const Color(0xff0E6B5F),
      onTertiary: const Color(0xffffffff),
      tertiaryContainer: const Color(0xffA5F2E2),
      onTertiaryContainer: const Color(0xff00201B),
      error: const Color(0xffBA1A1A),
      onError: const Color(0xffffffff),
      errorContainer: const Color(0xffffdad6),
      onErrorContainer: const Color(0xff93000a),
      surface: const Color(0xffF4F9FF),
      onSurface: const Color(0xff17212B),
      surfaceContainerLowest: const Color(0xffffffff),
      surfaceContainerLow: const Color(0xffEFF4FA),
      surfaceContainer: const Color(0xffE9EFF6),
      surfaceContainerHigh: const Color(0xffE3E9F1),
      surfaceContainerHighest: const Color(0xffDDE4EC),
      onSurfaceVariant: const Color(0xff42474E),
      outline: const Color(0xff72787F),
      outlineVariant: const Color(0xffC2C8CF),
      inverseSurface: const Color(0xff2C3138),
      inversePrimary: const Color(0xff8FD0FF),
    );
  }

  /// „Passaddhi“ (Midnight) — deep blue-black "profound tranquility" dark theme.
  static ColorScheme midnightColorScheme() {
    return ColorScheme(
      brightness: Brightness.dark,
      primary: const Color(0xff9CCBFF),
      onPrimary: const Color(0xff003354),
      primaryContainer: const Color(0xff0A4C76),
      onPrimaryContainer: const Color(0xffCDE4FF),
      secondary: const Color(0xffB4C9DC),
      onSecondary: const Color(0xff25313D),
      secondaryContainer: const Color(0xff404855),
      onSecondaryContainer: const Color(0xffD0E3F6),
      tertiary: const Color(0xffC2B9DE),
      onTertiary: const Color(0xff2B2640),
      tertiaryContainer: const Color(0xff463F5C),
      onTertiaryContainer: const Color(0xffDFD7FB),
      error: const Color(0xffffb4ab),
      onError: const Color(0xff690005),
      errorContainer: const Color(0xff93000a),
      onErrorContainer: const Color(0xffffdad6),
      surface: const Color(0xff0D141C),
      onSurface: const Color(0xffDCE4EC),
      surfaceContainerLowest: const Color(0xff090E14),
      surfaceContainerLow: const Color(0xff151C25),
      surfaceContainer: const Color(0xff1A222B),
      surfaceContainerHigh: const Color(0xff242C36),
      surfaceContainerHighest: const Color(0xff2F3742),
      onSurfaceVariant: const Color(0xffBDC6D2),
      outline: const Color(0xff88919D),
      outlineVariant: const Color(0xff3F4853),
      inverseSurface: const Color(0xffDCE4EC),
      inversePrimary: const Color(0xff00618E),
    );
  }

  /// „Arañña" (Forest) — deep green "forest seclusion" dark theme.
  static ColorScheme forestColorScheme() {
    return ColorScheme(
      brightness: Brightness.dark,
      primary: const Color(0xff9FD09F),
      onPrimary: const Color(0xff103A16),
      primaryContainer: const Color(0xff14541D),
      onPrimaryContainer: const Color(0xffC2EAC4),
      secondary: const Color(0xffBFCCB6),
      onSecondary: const Color(0xff253024),
      secondaryContainer: const Color(0xff3B4638),
      onSecondaryContainer: const Color(0xffDCE7D3),
      tertiary: const Color(0xffE3C06A),
      onTertiary: const Color(0xff3D2F00),
      tertiaryContainer: const Color(0xff584400),
      onTertiaryContainer: const Color(0xffffDF9E),
      error: const Color(0xffffb4ab),
      onError: const Color(0xff690005),
      errorContainer: const Color(0xff93000a),
      onErrorContainer: const Color(0xffffdad6),
      surface: const Color(0xff0F130E),
      onSurface: const Color(0xffE0E5DA),
      surfaceContainerLowest: const Color(0xff0A0E09),
      surfaceContainerLow: const Color(0xff171C15),
      surfaceContainer: const Color(0xff1B2118),
      surfaceContainerHigh: const Color(0xff262C22),
      surfaceContainerHighest: const Color(0xff30362D),
      onSurfaceVariant: const Color(0xffBFC5B7),
      outline: const Color(0xff8A9183),
      outlineVariant: const Color(0xff41483C),
      inverseSurface: const Color(0xffE0E5DA),
      inversePrimary: const Color(0xff2F6B36),
    );
  }
}
