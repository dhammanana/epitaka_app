// lib/features/guide/widgets/feature_guide_while_waiting.dart
//
// Compact, self-contained Feature Guide preview shown on the first-run
// indexing screen. Fills the "what do I do while the index builds?" gap
// without blocking the build or affecting the rest of the app's rendering.
//
// Deliberately light: static content only, no providers, no timers.

import 'package:flutter/material.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../feature_guide_content.dart';

/// A small card that lists the Feature Guide sections so new users can
/// browse what ePitaka can do while the search index is being built.
class FeatureGuideWhileWaiting extends StatelessWidget {
  const FeatureGuideWhileWaiting({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────
          Row(
            children: [
              Icon(
                Icons.explore_outlined,
                size: 18,
                color: colors.primary,
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Text(
                  loc.exploreWhileWaiting,
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            loc.exploreWhileWaitingDesc,
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          // ── One row per section ───────────────────────────────
          for (final section in kFeatureGuideSections)
            Padding(
              padding: const EdgeInsets.only(top: AppDimensions.sm),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusMd,
                      ),
                    ),
                    child: Icon(
                      section.icon,
                      size: 18,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.sm + 4),
                  Expanded(
                    child: Text(
                      loc.t(section.titleKey),
                      style: AppTypography.labelMedium.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
