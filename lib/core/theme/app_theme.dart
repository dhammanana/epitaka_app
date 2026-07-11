import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_typography.dart';

/// Builds the [ThemeData] for ePitaka using the Digital Manuscript design spec.
class AppTheme {
  AppTheme._();

  /// Build the light theme, optionally seeded from [accentColor].
  ///
  /// When a custom accent is provided, Material 3 generates a complete
  /// harmonious [ColorScheme] from that seed via [ColorScheme.fromSeed],
  /// and the [primary] is explicitly set to [accentColor] so the chosen
  /// accent is always visibly reflected in the UI.
  ///
  /// When `null`, the default Digital Manuscript palette is used.
  static ThemeData light({Color? accentColor}) {
    final colorScheme = accentColor != null
        ? ColorScheme.fromSeed(
            seedColor: accentColor,
            brightness: Brightness.light,
          ).copyWith(primary: accentColor)
        : AppColors.lightColorScheme();
    return _buildTheme(colorScheme);
  }

  /// Build the dark theme, optionally seeded from [accentColor].
  ///
  /// Unlike light mode, the dark-mode [ColorScheme.fromSeed] already
  /// generates a saturated primary that is recognisable as the chosen
  /// accent while remaining readable on the dark background, so no
  /// manual override is applied.
  static ThemeData dark({Color? accentColor}) {
    final colorScheme = accentColor != null
        ? ColorScheme.fromSeed(
            seedColor: accentColor,
            brightness: Brightness.dark,
          )
        : AppColors.darkColorScheme();
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
