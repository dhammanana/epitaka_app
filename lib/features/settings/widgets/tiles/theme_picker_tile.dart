import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/settings_provider.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';

/// Theme picker tile with radio-style selection dropdown.
class ThemePickerTile extends ConsumerWidget {
  const ThemePickerTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.md,
            vertical: AppDimensions.md,
          ),
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
                initialValue: settings.themePreference,
                onSelected: (pref) {
                  ref.read(settingsProvider.notifier).setThemePreference(pref);
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: ThemePreference.system,
                    child: Text(_themeLabel(ThemePreference.system)),
                  ),
                  PopupMenuItem(
                    value: ThemePreference.light,
                    child: Text(_themeLabel(ThemePreference.light)),
                  ),
                  PopupMenuItem(
                    value: ThemePreference.dark,
                    child: Text(_themeLabel(ThemePreference.dark)),
                  ),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _themeLabel(settings.themePreference),
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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
