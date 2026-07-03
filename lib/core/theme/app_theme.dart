import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_typography.dart';

/// Builds the [ThemeData] for ePitaka using the Digital Manuscript design spec.
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final colorScheme = AppColors.lightColorScheme();
    return _buildTheme(colorScheme);
  }

  static ThemeData dark() {
    final colorScheme = AppColors.darkColorScheme();
    return _buildTheme(colorScheme);
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
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primary;
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primaryContainer;
          }
          return null;
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
