import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../widgets/settings_app_bar.dart';

/// Feedback screen: the way to send the developers an email.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: SettingsAppBar(colors: colors),
      body: const HelpScreenBody(),
    );
  }
}

/// Scrollable body of the feedback screen — shared between the mobile screen
/// and the desktop settings window.
class HelpScreenBody extends StatelessWidget {
  const HelpScreenBody({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.marginMobile,
        AppDimensions.md,
        AppDimensions.marginMobile,
        120,
      ),
      children: [
        Text(
          loc.feedback,
          style: AppTypography.headlineLarge.copyWith(
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: AppDimensions.lg),
        _FeedbackTile(colors: colors, loc: loc),
      ],
    );
  }
}

/// A tile that opens the default email client to send feedback.
class _FeedbackTile extends StatelessWidget {
  final ColorScheme colors;
  final AppLocalizations loc;

  const _FeedbackTile({required this.colors, required this.loc});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        child: InkWell(
          onTap: () async {
            final uri = Uri(
              scheme: 'mailto',
              path: 'epitaka.org@gmail.com',
              queryParameters: {
                'subject': 'ePitaka Feedback',
                'body': '',
              },
            );
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusMd,
                    ),
                  ),
                  child: Icon(
                    Icons.feedback_outlined,
                    color: colors.onPrimaryContainer,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.sendFeedback,
                        style: AppTypography.labelMedium.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'epitaka.org@gmail.com',
                        style: AppTypography.labelSmall.copyWith(
                          color: colors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.open_in_new, color: colors.onSurfaceVariant, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
