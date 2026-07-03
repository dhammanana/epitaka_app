import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../widgets/settings_app_bar.dart';
import '../widgets/settings_section.dart';

/// Main settings screen with grouped sections.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;

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
          // Screen title
          Text(
            'Settings',
            style: AppTypography.headlineLarge.copyWith(
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: AppDimensions.lg),

          // Sections
          SettingsSection(
            title: 'General',
            colors: colors,
            showDividers: true,
            children: [
              _SettingsTile(
                icon: Icons.language,
                title: 'Language',
                subtitle: 'English',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.translate,
                title: 'Script',
                subtitle: 'Roman',
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.md),

          SettingsSection(
            title: 'Appearance',
            colors: colors,
            showDividers: true,
            children: [
              _ThemePickerTile(),
              _SettingsTile(
                icon: Icons.palette,
                title: 'Appearance',
                subtitle: 'Theme & accent',
                onTap: () => context.push('/settings/appearance'),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.md),

          SettingsSection(
            title: 'Data & Content',
            colors: colors,
            showDividers: true,
            children: [
              _SettingsTile(
                icon: Icons.download,
                title: 'Translations & Downloads',
                onTap: () => context.push('/settings/translation'),
              ),
              _SettingsTile(
                icon: Icons.translate,
                title: 'Translation Display',
                subtitle: 'Layout, mode & typography',
                onTap: () => context.push('/settings/translation'),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.md),

          SettingsSection(
            title: 'Reading Preferences',
            colors: colors,
            showDividers: true,
            children: [
              _SettingsTile(
                icon: Icons.menu_book,
                title: 'Reading Options',
                subtitle: 'Layout, numbering & scroll',
                onTap: () => context.push('/settings/reading'),
              ),
              _SettingsTile(
                icon: Icons.record_voice_over,
                title: 'Text-to-Speech',
                subtitle: 'Voice & speed',
                onTap: () => context.push('/settings/tts'),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.md),

          SettingsSection(
            title: 'Account',
            colors: colors,
            showDividers: true,
            children: [
              _SettingsTile(
                icon: Icons.account_circle,
                title: 'Profile',
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.md),

          SettingsSection(
            title: 'System',
            colors: colors,
            showDividers: true,
            children: [
              _SettingsTile(
                icon: Icons.info,
                title: 'About ePitaka',
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}



class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md,
          vertical: AppDimensions.md,
        ),
        child: Row(
          children: [
            Icon(icon, color: colors.primary),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Text(
                title,
                style: AppTypography.labelMedium.copyWith(
                  color: colors.onSurface,
                ),
              ),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  subtitle!,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            Icon(
              Icons.chevron_right,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Theme picker tile with radio-style selection.
class _ThemePickerTile extends ConsumerWidget {
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
