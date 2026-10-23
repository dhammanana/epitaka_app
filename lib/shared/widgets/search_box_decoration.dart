import 'package:flutter/material.dart';

import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';

/// The gap above and below every search box, the same everywhere.
const double kSearchBoxGap = AppDimensions.sm;

/// The padding round a search box: [kSearchBoxGap] above and below, and a
/// slim side margin in every desktop panel (the Search sidebar's) and on
/// every phone screen (the Search screen's). It was the desktop margin wide
/// on phones too; the row kept the word from filling out on a phone, so it
/// is one gutter-grain now.
EdgeInsets searchBoxPadding(SearchBoxSize size) => EdgeInsets.symmetric(
  horizontal: size == SearchBoxSize.panel
      ? AppDimensions.sm
      : AppDimensions.sm + 2,
  vertical: kSearchBoxGap,
);

/// [SearchBoxSize.panel] is the desktop Search sidebar's box;
/// [SearchBoxSize.screen] is the phone Search screen's.
enum SearchBoxSize { panel, screen }

/// The look of the Search boxes, shared by every box that searches Pāli so
/// they cannot drift apart: filled, rounded, no border line, and — for room
/// — no leading icon; the box ends in the suffix's clear button and "more"
/// menu (search_box_actions.dart). The text field padding below reads fresh
/// from that.
InputDecoration searchBoxDecoration(
  BuildContext context, {
  required String hintText,
  SearchBoxSize size = SearchBoxSize.panel,
  Widget? suffixIcon,
  String? errorText,
}) {
  final colors = Theme.of(context).colorScheme;
  final panel = size == SearchBoxSize.panel;
  return InputDecoration(
    hintText: hintText,
    isDense: panel,
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
    // The screen box's inner padding is a grain narrower than the panel's:
    // on a phone the row held the word from filling out the box.
    contentPadding: panel
        ? const EdgeInsets.symmetric(horizontal: AppDimensions.md, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: AppDimensions.sm + 2, vertical: 12),
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
