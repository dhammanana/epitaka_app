import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Theme;

/// The body text size of a DPD entry at the dictionary text size of 100%:
/// 0.8 of the default Pāḷi size of 19.
const double kDpdDefaultBodySize = 15.2;

extension DpdTextSize on BuildContext {
  /// [atDefault] pixels, grown or shrunk with the dictionary text size. The
  /// DPD widgets were written with fixed sizes (12, 12.8, 11.2…) beside body
  /// text that follows the setting. This keeps their proportion to the body
  /// text. `DpdResultsView` sets the body size in the ambient text theme.
  double dpdSize(double atDefault) {
    final body = Theme.of(this).textTheme.bodyMedium?.fontSize;
    return atDefault * (body ?? kDpdDefaultBodySize) / kDpdDefaultBodySize;
  }
}
