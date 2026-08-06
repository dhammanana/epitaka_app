// lib/features/guide/screens/feature_guide_screen.dart
//
// Full-screen Feature Guide — the "how do I use ePitaka?" reference.
//
// Opened as a pushed route (drawer button, settings tile, welcome sheet),
// so when it is closed it contributes nothing to the widget tree or the
// render pipeline — zero performance cost while reading.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../feature_guide_content.dart';
import '../widgets/feature_guide_section_card.dart';

/// Full screen listing every Feature Guide section with expandable steps.
class FeatureGuideScreen extends ConsumerWidget {
  /// When true (opened from the first-run welcome), shows a short intro
  /// header before the sections.
  final bool showIntro;

  const FeatureGuideScreen({super.key, this.showIntro = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: colors.primary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          loc.featureGuide,
          style: AppTypography.headlineSmall.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.marginMobile,
          AppDimensions.md,
          AppDimensions.marginMobile,
          120,
        ),
        children: [
          if (showIntro) ...[
            _buildIntroCard(context, colors, loc),
            const SizedBox(height: AppDimensions.lg),
          ],
          for (var i = 0; i < kFeatureGuideSections.length; i++) ...[
            FeatureGuideSectionCard(
              section: kFeatureGuideSections[i],
              initiallyExpanded: showIntro && i == 0,
            ),
            if (i < kFeatureGuideSections.length - 1)
              const SizedBox(height: AppDimensions.md),
          ],
        ],
      ),
    );
  }

  Widget _buildIntroCard(
    BuildContext context,
    ColorScheme colors,
    AppLocalizations loc,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryContainer,
            colors.primaryContainer.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusLg,
                  ),
                ),
                child: Icon(
                  Icons.menu_book,
                  color: colors.onPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Text(
                  loc.welcomeToEpitaka,
                  style: AppTypography.headlineSmall.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            loc.featureGuideIntro,
            style: AppTypography.labelMedium.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
