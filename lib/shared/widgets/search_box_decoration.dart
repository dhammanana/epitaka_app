import 'package:flutter/material.dart';

import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';

/// The gap above and below every search box, the same everywhere.
const double kSearchBoxGap = AppDimensions.sm;

/// The padding round a search box: [kSearchBoxGap] above and below, and the
/// same side margin in every desktop panel (the Search sidebar's) and on
/// every phone screen (the Search screen's).
EdgeInsets searchBoxPadding(SearchBoxSize size) => EdgeInsets.symmetric(
  horizontal: size == SearchBoxSize.panel
      ? AppDimensions.sm
      : AppDimensions.marginMobile,
  vertical: kSearchBoxGap,
);

/// [SearchBoxSize.panel] is the desktop Search sidebar's box;
/// [SearchBoxSize.screen] is the phone Search screen's.
enum SearchBoxSize { panel, screen }

/// The look of the Search boxes, shared by every box that searches Pāli so
/// they cannot drift apart: filled, rounded, no border line, a search icon
/// first. [prefixIcon] replaces the plain search icon (the phone Search
/// screen makes it a button).
InputDecoration searchBoxDecoration(
  BuildContext context, {
  required String hintText,
  SearchBoxSize size = SearchBoxSize.panel,
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? errorText,
}) {
  final colors = Theme.of(context).colorScheme;
  final panel = size == SearchBoxSize.panel;
  return InputDecoration(
    hintText: hintText,
    isDense: panel,
    prefixIcon:
        prefixIcon ??
        Icon(
          Icons.search,
          size: panel ? 18 : null,
          color: colors.onSurfaceVariant,
        ),
    suffixIcon: suffixIcon,
    errorText: errorText,
    filled: true,
    // The Annotations box's old fill: the user's pick for light and dark.
    fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(
        panel ? AppDimensions.radiusLg : AppDimensions.radiusXl,
      ),
      borderSide: BorderSide.none,
    ),
    contentPadding: panel
        ? const EdgeInsets.symmetric(horizontal: AppDimensions.sm, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: AppDimensions.md, vertical: 12),
  );
}

/// The typed text in every search box: one sans-serif font, 14 px in a
/// desktop panel and 16 px on a phone screen.
TextStyle searchBoxTextStyle(
  BuildContext context, {
  SearchBoxSize size = SearchBoxSize.panel,
}) => AppTypography.labelMedium.copyWith(
  fontSize: size == SearchBoxSize.panel ? 14 : 16,
  color: Theme.of(context).colorScheme.onSurface,
);
