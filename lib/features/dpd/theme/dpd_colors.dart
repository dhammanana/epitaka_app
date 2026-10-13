import 'package:flutter/material.dart';

abstract final class DpdColors {
  // Visual Styling Constants — theme-independent layout metrics.
  // Match the visual weight of webapp's 7px radius.
  static const double borderRadiusValue = 7.0;
  static final BorderRadius borderRadius = BorderRadius.circular(
    borderRadiusValue,
  );

  // Global padding for section content (Grammar, Examples, Families, etc.)
  static const EdgeInsets sectionPadding = EdgeInsets.symmetric(
    horizontal: 10.0,
    vertical: 3.0,
  );
}
