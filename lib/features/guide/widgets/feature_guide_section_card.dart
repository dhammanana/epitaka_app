// lib/features/guide/widgets/feature_guide_section_card.dart
//
// Expandable card for one Feature Guide section: icon + title + description
// on the header, numbered instruction steps revealed on tap.

import 'package:flutter/material.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../models/feature_guide_section.dart';

/// An expandable [FeatureGuideSection] card.
class FeatureGuideSectionCard extends StatefulWidget {
  final FeatureGuideSection section;
  final bool initiallyExpanded;

  const FeatureGuideSectionCard({
    super.key,
    required this.section,
    this.initiallyExpanded = false,
  });

  @override
  State<FeatureGuideSectionCard> createState() =>
      _FeatureGuideSectionCardState();
}

class _FeatureGuideSectionCardState extends State<FeatureGuideSectionCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final section = widget.section;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.md),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusLg,
                      ),
                    ),
                    child: Icon(
                      section.icon,
                      size: 22,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.t(section.titleKey),
                          style: AppTypography.labelMedium.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          loc.t(section.descKey),
                          style: AppTypography.labelSmall.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── Steps ─────────────────────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _buildSteps(colors, loc, section),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildSteps(
    ColorScheme colors,
    AppLocalizations loc,
    FeatureGuideSection section,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        0,
        AppDimensions.md,
        AppDimensions.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            height: 1,
            thickness: 1,
            color: colors.outlineVariant,
            endIndent: 4,
          ),
          const SizedBox(height: AppDimensions.sm),
          for (var i = 0; i < section.steps.length; i++) ...[
            _StepRow(
              step: section.steps[i],
              colors: colors,
              loc: loc,
            ),
            if (i < section.steps.length - 1)
              const SizedBox(height: AppDimensions.sm),
          ],
        ],
      ),
    );
  }
}

/// One instruction row, showing the icon of the real toolbar button / screen
/// element (so users can recognise the feature at a glance).
class _StepRow extends StatelessWidget {
  final FeatureGuideStep step;
  final ColorScheme colors;
  final AppLocalizations loc;

  const _StepRow({
    required this.step,
    required this.colors,
    required this.loc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          ),
          alignment: Alignment.center,
          child: Icon(
            step.icon,
            size: 15,
            color: colors.primary,
          ),
        ),
        const SizedBox(width: AppDimensions.sm + 2),
        Expanded(
          child: Text(
            loc.t(step.textKey),
            style: AppTypography.labelMedium.copyWith(
              color: colors.onSurface,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
