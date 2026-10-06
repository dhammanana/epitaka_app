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
import '../models/feature_guide_section.dart';

/// A small card that lists the Feature Guide sections so new users can
/// browse what ePitaka can do while the search index is being built.
///
/// Each row expands inline to reveal the section description and steps.
/// Inline expansion is deliberate: this widget lives inside [IndexGate],
/// which replaces the router content until the index is ready, so pushing
/// the full `/guide` route from here would be swallowed by the gate.
class FeatureGuideWhileWaiting extends StatefulWidget {
  const FeatureGuideWhileWaiting({super.key});

  @override
  State<FeatureGuideWhileWaiting> createState() =>
      _FeatureGuideWhileWaitingState();
}

class _FeatureGuideWhileWaitingState extends State<FeatureGuideWhileWaiting> {
  String? _expandedId;

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
          Row(
            children: [
              Icon(Icons.explore_outlined, size: 18, color: colors.primary),
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
          for (final section in kFeatureGuideSections)
            Padding(
              padding: const EdgeInsets.only(top: AppDimensions.xs),
              child: _GuideRow(
                section: section,
                expanded: _expandedId == section.id,
                onTap: () => setState(
                  () => _expandedId = _expandedId == section.id
                      ? null
                      : section.id,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GuideRow extends StatelessWidget {
  final FeatureGuideSection section;
  final bool expanded;
  final VoidCallback onTap;

  const _GuideRow({
    required this.section,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final steps = section.visibleSteps;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                    child: Icon(section.icon, size: 18, color: colors.primary),
                  ),
                  const SizedBox(width: AppDimensions.sm + 4),
                  Expanded(
                    child: Text(
                      loc.t(section.titleKey),
                      style: AppTypography.labelMedium.copyWith(
                        color: colors.onSurface,
                        fontWeight: expanded
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 8, left: 2, right: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.t(section.descKey),
                        style: AppTypography.labelSmall.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (var i = 0; i < steps.length; i++)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: i < steps.length - 1 ? 6 : 0,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                steps[i].icon,
                                size: 15,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  loc.t(steps[i].textKey),
                                  style: AppTypography.labelSmall.copyWith(
                                    color: colors.onSurface,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                crossFadeState: expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
