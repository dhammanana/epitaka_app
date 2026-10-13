import 'package:flutter/material.dart';

import '../../../core/utils/app_localizations.dart';
import '../theme/dpd_palette.dart';

enum ResultTier { partial, fuzzy }

/// The heading between the exact results and a looser tier of headwords. From
/// the DPD app's `TierDivider`, with its labels from ePitaka's strings.
class TierDivider extends StatelessWidget {
  const TierDivider({super.key, required this.tier});

  final ResultTier tier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final palette = context.palette;
    final loc = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      color: isDark ? palette.darkShade : palette.lightShade,
      margin: const EdgeInsets.only(top: 24, bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        tier == ResultTier.partial ? loc.dpdPartialResults : loc.dpdFuzzyResults,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
