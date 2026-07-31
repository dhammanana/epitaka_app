import 'package:flutter/material.dart';

import '../providers/settings_provider.dart' show ThemePreference;
import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_typography.dart';

/// Builds the [ThemeData] for ePitaka using the Digital Manuscript design spec.
class AppTheme {
  AppTheme._();

  /// Build the [ThemeData] for a [ThemePreference], resolving `system`
  /// against [platformBrightness].
  static ThemeData forPreference(
    ThemePreference preference, {
    required Brightness platformBrightness,
    Color? accentColor,
  }) {
    switch (preference) {
      case ThemePreference.system:
        return platformBrightness == Brightness.dark
            ? dark(accentColor: accentColor)
            : light(accentColor: accentColor);
      case ThemePreference.light:
        return light(accentColor: accentColor);
      case ThemePreference.sepia:
        return sepia(accentColor: accentColor);
      case ThemePreference.ocean:
        return ocean(accentColor: accentColor);
      case ThemePreference.dark:
        return dark(accentColor: accentColor);
      case ThemePreference.midnight:
        return midnight(accentColor: accentColor);
      case ThemePreference.forest:
        return forest(accentColor: accentColor);
    }
  }

  /// Build the light („Tālapatta“) theme, optionally seeded from [accentColor].
  static ThemeData light({Color? accentColor}) =>
      _themed(base: AppColors.lightColorScheme(), accentColor: accentColor);

  /// Build the dark („Samādhi“) theme, optionally seeded from [accentColor].
  static ThemeData dark({Color? accentColor}) =>
      _themed(base: AppColors.darkColorScheme(), accentColor: accentColor);

  /// Build the sepia („Paññā-āloka“) light theme.
  static ThemeData sepia({Color? accentColor}) =>
      _themed(base: AppColors.sepiaColorScheme(), accentColor: accentColor);

  /// Build the ocean („Vimutti-rasa“) light theme.
  static ThemeData ocean({Color? accentColor}) =>
      _themed(base: AppColors.oceanColorScheme(), accentColor: accentColor);

  /// Build the midnight („Passaddhi“) dark theme.
  static ThemeData midnight({Color? accentColor}) =>
      _themed(base: AppColors.midnightColorScheme(), accentColor: accentColor);

  /// Build the forest („Arañña“) dark theme.
  static ThemeData forest({Color? accentColor}) =>
      _themed(base: AppColors.forestColorScheme(), accentColor: accentColor);

  /// Build a theme from a fixed base palette, optionally seeding accent colors.
  ///
  /// The surface family always comes from [base] so every theme keeps its own
  /// character (paper, sepia, midnight…) even when a custom accent is chosen;
  /// the accent only drives the primary/secondary/tertiary roles.  In dark
  /// themes the seeded primary is left untouched so it stays readable on the
  /// dark background.
  static ThemeData _themed({required ColorScheme base, Color? accentColor}) {
    final ColorScheme colors;
    if (accentColor == null) {
      colors = base;
    } else {
      final seed = ColorScheme.fromSeed(
        seedColor: accentColor,
        brightness: base.brightness,
      );
      colors = seed.copyWith(
        primary: base.brightness == Brightness.light ? accentColor : null,
        surface: base.surface,
        onSurface: base.onSurface,
        surfaceContainerLowest: base.surfaceContainerLowest,
        surfaceContainerLow: base.surfaceContainerLow,
        surfaceContainer: base.surfaceContainer,
        surfaceContainerHigh: base.surfaceContainerHigh,
        surfaceContainerHighest: base.surfaceContainerHighest,
        onSurfaceVariant: base.onSurfaceVariant,
        outline: base.outline,
        outlineVariant: base.outlineVariant,
        inverseSurface: base.inverseSurface,
        inversePrimary: base.inversePrimary,
      );
    }
    return _buildTheme(colors);
  }

  static ThemeData _buildTheme(ColorScheme colors) {
    return ThemeData(
      useMaterial3: true,
      brightness: colors.brightness,
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,

      // ── AppBar ──────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.labelMedium.copyWith(
          color: colors.onSurface,
        ),
        iconTheme: IconThemeData(color: colors.onSurfaceVariant),
      ),

      // ── Text Theme ──────────────────────────────────────────────────
      textTheme: TextTheme(
        displayLarge: AppTypography.displayPali.copyWith(
          color: colors.primary,
        ),
        headlineLarge: AppTypography.headlineLarge.copyWith(
          color: colors.onSurface,
        ),
        headlineSmall: AppTypography.headlineSmall.copyWith(
          color: colors.onSurface,
        ),
        bodyLarge: AppTypography.bodyPali.copyWith(
          color: colors.onSurface,
        ),
        bodyMedium: AppTypography.bodyTranslation.copyWith(
          color: colors.onSurfaceVariant,
        ),
        labelMedium: AppTypography.labelMedium.copyWith(
          color: colors.onSurfaceVariant,
        ),
        labelSmall: AppTypography.labelSmall.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),

      // ── Card ────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          side: BorderSide(color: colors.outlineVariant, width: 1),
        ),
      ),

      // ── Bottom Sheet ────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusSheet),
          ),
        ),
      ),

      // ── Divider ─────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        thickness: 1,
        space: 0,
      ),

      // ── Navigation Bar (bottom nav) ─────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: colors.secondaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.labelSmall.copyWith(
              color: colors.onSecondaryContainer,
            );
          }
          return AppTypography.labelSmall.copyWith(
            color: colors.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colors.onSecondaryContainer);
          }
          return IconThemeData(color: colors.onSurfaceVariant);
        }),
      ),

      // ── Switch ──────────────────────────────────────────────────────
      // Enabled switches use a contrasting thumb (onPrimary) on the primary
      // track so they read as a proper switch instead of a solid pill of
      // color.  Disabled ones use a neutral track with a subtle outline.
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.onPrimary;
          return colors.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.primary;
          return colors.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return colors.outlineVariant;
        }),
      ),

      // ── Slider ──────────────────────────────────────────────────────
      sliderTheme: SliderThemeData(
        activeTrackColor: colors.primary,
        inactiveTrackColor: colors.outlineVariant,
        thumbColor: colors.primary,
        overlayColor: colors.primary.withValues(alpha: 0.12),
      ),
    );
  }
}
