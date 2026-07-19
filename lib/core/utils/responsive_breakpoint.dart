import 'package:flutter/material.dart';

import 'platform_info.dart';

/// Breakpoint thresholds for responsive layout decisions.
///
/// Uses both the platform (desktop OS) and the actual screen width to
/// determine the layout mode. On mobile platforms (Android/iOS), width
/// is the primary discriminator between phone and tablet layouts.
class ResponsiveBreakpoint {
  ResponsiveBreakpoint._();

  /// Minimum width for desktop-style layout (sidebars, collapsible panels).
  static const double desktopWidth = 900;

  /// Minimum width for tablet-style layout (hybrid panels, compact sidebars).
  static const double tabletWidth = 600;

  /// True when running on a desktop OS (Windows, macOS, Linux).
  static bool isPlatformDesktop(BuildContext context) => PlatformInfo.isDesktop;

  /// True when running on desktop OR a very wide tablet (e.g. iPad Pro in
  /// landscape). This is the primary check for enabling sidebar layout.
  static bool isDesktop(BuildContext context) {
    return PlatformInfo.isDesktop &&
        MediaQuery.sizeOf(context).width >= desktopWidth;
  }

  /// True for tablets (width >= 600 but not desktop width).
  static bool isTablet(BuildContext context) {
    return !PlatformInfo.isDesktop &&
        MediaQuery.sizeOf(context).width >= tabletWidth;
  }

  /// True for phones (smallest width < 600).
  static bool isPhone(BuildContext context) {
    return !PlatformInfo.isDesktop &&
        MediaQuery.sizeOf(context).shortestSide < tabletWidth;
  }

  /// True when side panels should be usable (desktop or large tablet).
  static bool supportsSidePanels(BuildContext context) {
    return PlatformInfo.isDesktop &&
        MediaQuery.sizeOf(context).width >= desktopWidth;
  }

  /// Width allocated to a side panel (left or right) when open.
  static double panelWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1400) return 380;
    if (width >= 1200) return 360;
    if (width >= desktopWidth) return 340;
    return 320;
  }

  /// Minimum width the main content area must retain when panels are open.
  static double minContentWidth(BuildContext context) {
    return 400;
  }

  /// Whether there's room for BOTH left and right panels simultaneously.
  static bool canFitBothPanels(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return screenWidth >= desktopWidth + panelWidth(context) + 400;
  }
}
