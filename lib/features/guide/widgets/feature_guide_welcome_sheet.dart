// lib/features/guide/widgets/feature_guide_welcome_sheet.dart
//
// One-time welcome bottom sheet shown to new users (on first app start, or
// after the initial index build). Introduces the Feature Guide and links to
// the full screen. A modal sheet leaves no trace in the widget tree once
// dismissed, so it costs nothing while reading.
//
// The caller is responsible for the one-time gate: read `featureGuideSeen`
// from settings, mark it seen, then call [showFeatureGuideWelcome].

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../router/app_router.dart' show AppRoutes;
import '../feature_guide_content.dart';

/// Shows the welcome bottom sheet.
Future<void> showFeatureGuideWelcome(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const FeatureGuideWelcomeSheet(),
  );
}

/// The welcome sheet content itself.
class FeatureGuideWelcomeSheet extends StatelessWidget {
  const FeatureGuideWelcomeSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusSheet),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.marginMobile,
        AppDimensions.lg,
        AppDimensions.marginMobile,
        AppDimensions.lg,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.lg),

              // ── Header ────────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusLg,
                      ),
                    ),
                    child: Icon(
                      Icons.menu_book,
                      size: 26,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.welcomeToEpitaka,
                          style: AppTypography.headlineSmall.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          loc.featureGuideSubtitle,
                          style: AppTypography.labelSmall.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.md),

              Text(
                loc.featureGuideWelcomeDesc,
                style: AppTypography.labelMedium.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppDimensions.lg),

              // ── Quick overview of the guide sections ─────────
              for (final section in kFeatureGuideSections)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.md),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusMd,
                          ),
                        ),
                        child: Icon(
                          section.icon,
                          size: 20,
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
                            Text(
                              loc.t(section.descKey),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelSmall.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: AppDimensions.sm),

              // ── Actions ──────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    // Capture the router BEFORE popping: the sheet's context
                    // is deactivated during the pop, so using `context.push`
                    // afterwards would look up an inherited widget from a
                    // deactivated element.
                    final router = GoRouter.of(context);
                    Navigator.of(context).pop();
                    router.push('${AppRoutes.featureGuide}?intro=true');
                  },
                  icon: const Icon(Icons.explore_outlined),
                  label: Text(loc.exploreFeatures),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusLg,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(loc.gotIt),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
