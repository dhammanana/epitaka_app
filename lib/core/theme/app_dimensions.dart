/// Spacing, border radius, and layout dimension constants.
///
/// All values are derived from the ePitaka "Digital Manuscript" design spec.
class AppDimensions {
  AppDimensions._();

  // ── Spacing (8px baseline grid) ─────────────────────────────────────
  static const double base = 8;
  static const double xs = 4; // base / 2
  static const double sm = 8; // base
  static const double md = 16; // base * 2
  static const double lg = 24; // base * 3
  static const double xl = 32; // base * 4
  static const double xxl = 40; // base * 5

  // ── Page Margins ────────────────────────────────────────────────────
  static const double marginMobile = 20;
  static const double marginDesktop = 40;

  // ── Reading Column ──────────────────────────────────────────────────
  static const double readingWidthMax = 680;

  // ── Border Radius ───────────────────────────────────────────────────
  static const double radiusSm = 4;
  static const double radiusMd = 8;
  static const double radiusLg = 12;
  static const double radiusXl = 16;
  static const double radiusSheet = 20;
  static const double radiusFull = 9999;

  // ── Elevation / Shadows ─────────────────────────────────────────────
  // Tonal layers rather than aggressive shadows — see DESIGN.md

  // ── Icon Sizes ──────────────────────────────────────────────────────
  static const double iconSm = 16;
  static const double iconMd = 24;
  static const double iconLg = 32;

  // ── Misc ────────────────────────────────────────────────────────────
  static const double tabHeight = 44;
  static const double bottomToolbarHeight = 56;
  static const double appBarHeight = 64;
}
