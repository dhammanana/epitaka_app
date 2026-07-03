import 'package:flutter/material.dart';

/// Typography constants matching the ePitaka design spec.
///
/// Uses Noto Serif for Pāli content and headings, Inter for UI and translations.
class AppTypography {
  AppTypography._();

  // ── Font Families ───────────────────────────────────────────────────
  static const String paliFont = 'Noto Serif';
  static const String translationFont = 'Inter';

  // ── Text Styles ─────────────────────────────────────────────────────

  /// Display Pāli — 32px/44px Bold — for main sutta titles
  static const TextStyle displayPali = TextStyle(
    fontFamily: paliFont,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 44 / 32,
  );

  /// Headline Large — 24px/32px SemiBold — for screen titles
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: paliFont,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 32 / 24,
  );

  /// Headline Small — 20px/28px SemiBold — for section headings
  static const TextStyle headlineSmall = TextStyle(
    fontFamily: paliFont,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 28 / 20,
  );

  /// Body Pāli — 19px/32px Regular — for Pāli text content
  static const TextStyle bodyPali = TextStyle(
    fontFamily: paliFont,
    fontSize: 19,
    fontWeight: FontWeight.w400,
    height: 32 / 19,
  );

  /// Body Translation — 17px/28px Regular — for translation text
  static const TextStyle bodyTranslation = TextStyle(
    fontFamily: translationFont,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 28 / 17,
  );

  /// Label Medium — 14px/20px Medium with 2% letter spacing — for UI labels
  static const TextStyle labelMedium = TextStyle(
    fontFamily: translationFont,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 20 / 14,
    letterSpacing: 0.28,
  );

  /// Label Small — 12px/16px Medium with 4% letter spacing — for caption text
  static const TextStyle labelSmall = TextStyle(
    fontFamily: translationFont,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
    letterSpacing: 0.48,
  );

  // ── Configurable Typography ─────────────────────────────────────────
  // These allow user-driven scaling from Settings.

  static double paliFontSize = 19;
  static double translationFontSize = 17;
  static double paliLineHeight = 32 / 19;
  static double translationLineHeight = 28 / 17;

  static void resetToDefaults() {
    paliFontSize = 19;
    translationFontSize = 17;
    paliLineHeight = 32 / 19;
    translationLineHeight = 28 / 17;
  }

  static TextStyle get scaledBodyPali => bodyPali.copyWith(
        fontSize: paliFontSize,
        height: paliLineHeight,
      );

  static TextStyle get scaledBodyTranslation => bodyTranslation.copyWith(
        fontSize: translationFontSize,
        height: translationLineHeight,
      );
}
