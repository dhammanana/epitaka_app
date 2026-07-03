import 'package:flutter/material.dart' hide ColorSwatch;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../widgets/color_swatch.dart';
import '../widgets/settings_app_bar.dart';
import '../widgets/settings_section.dart';

/// Appearance settings: theme mode, accent color, live preview.
class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Build preview colors based on current settings
    final previewPaliColor = isDark
        ? settings.accentColor.withValues(alpha: 0.9)
        : settings.paliColor;
    final previewTransColor = isDark
        ? settings.translationColor.withValues(alpha: 0.85)
        : settings.translationColor;

    return Scaffold(
      appBar: SettingsAppBar(colors: colors),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.marginMobile,
          AppDimensions.md,
          AppDimensions.marginMobile,
          120,
        ),
        children: [
          Text(
            'Appearance',
            style: AppTypography.headlineLarge.copyWith(
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: AppDimensions.lg),

          // Live Preview Card
          _LivePreviewCard(
            paliColor: previewPaliColor,
            transColor: previewTransColor,
            colors: colors,
          ),
          const SizedBox(height: AppDimensions.lg),

          // Theme section
          SettingsSection(
            title: 'Theme',
            colors: colors,
            children: [
              _ThemeSelector(
                current: settings.themePreference,
                onSelected: (pref) {
                  ref.read(settingsProvider.notifier).setThemePreference(pref);
                },
                colors: colors,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),

          // Accent Color section
          SettingsSection(
            title: 'Accent Color',
            colors: colors,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppDimensions.md),
                child: Wrap(
                  spacing: AppDimensions.sm,
                  runSpacing: AppDimensions.sm,
                  children: [
                    for (final accent in AppColors.accentPresets)
                      ColorSwatch(
                        color: accent,
                        isSelected: settings.accentColor == accent,
                        onTap: () {
                          ref
                              .read(settingsProvider.notifier)
                              .setAccentColor(accent);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LivePreviewCard extends StatelessWidget {
  final Color paliColor;
  final Color transColor;
  final ColorScheme colors;

  const _LivePreviewCard({
    required this.paliColor,
    required this.transColor,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preview',
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            'Evam me sutam…',
            style: AppTypography.bodyPali.copyWith(color: paliColor),
          ),
          const SizedBox(height: 4),
          Text(
            'Thus have I heard…',
            style: AppTypography.bodyTranslation.copyWith(color: transColor),
          ),
        ],
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  final ThemePreference current;
  final ValueChanged<ThemePreference> onSelected;
  final ColorScheme colors;

  const _ThemeSelector({
    required this.current,
    required this.onSelected,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.sm),
      child: Row(
        children: [
          Icon(Icons.palette, color: colors.primary),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Text(
              'Theme',
              style: AppTypography.labelMedium.copyWith(
                color: colors.onSurface,
              ),
            ),
          ),
          PopupMenuButton<ThemePreference>(
            initialValue: current,
            onSelected: onSelected,
            itemBuilder: (context) => [
              for (final pref in ThemePreference.values)
                PopupMenuItem(
                  value: pref,
                  child: Text(_themeLabel(pref)),
                ),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _themeLabel(current),
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _themeLabel(ThemePreference pref) {
    switch (pref) {
      case ThemePreference.system:
        return 'System';
      case ThemePreference.light:
        return 'Paper (Light)';
      case ThemePreference.dark:
        return 'Dark';
    }
  }
}
