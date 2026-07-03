import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/utils/reading_clipboard.dart';
import '../widgets/settings_app_bar.dart';
import '../widgets/settings_section.dart';

/// Reading Options: page numbering system, default layout, auto-scroll speed,
/// keep-screen-on toggle, and copy settings.
class ReadingOptionsScreen extends ConsumerWidget {
  const ReadingOptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
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
          Text(
            'Reading Options',
            style: AppTypography.headlineLarge.copyWith(
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: AppDimensions.lg),

          // Page Numbering
          SettingsSection(
            title: 'Page Numbering',
            colors: colors,
            children: [
              _DropdownTile(
                icon: Icons.numbers,
                title: 'System',
                value: _pageSystemLabel(settings.pageNumberingSystem),
                options: const [
                  'VRI',
                  'PTS',
                  'Thai',
                  'Myanmar',
                ],
                selectedValue: _pageSystemLabel(settings.pageNumberingSystem),
                onSelected: (label) {
                  final system = _pageSystemCode(label);
                  ref
                      .read(settingsProvider.notifier)
                      .setPageNumberingSystem(system);
                },
                colors: colors,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),

          // Layout
          SettingsSection(
            title: 'Layout',
            colors: colors,
            children: [
              _SwitchTile(
                icon: Icons.view_column,
                title: 'Side-by-Side View',
                subtitle: 'Show Pāli and translation side by side',
                value: settings.translationDisplayMode == TranslationDisplayMode.sideBySide,
                onChanged: (v) {
                  ref.read(settingsProvider.notifier).setSideBySide(v);
                },
                colors: colors,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),

          // Copy
          SettingsSection(
            title: 'Copy / Clipboard',
            colors: colors,
            children: [
              _DropdownTile<CopyQuoteFormat>(
                icon: Icons.format_quote,
                title: 'Quote Format',
                subtitle: _copyQuoteLabel(settings.copyQuoteFormat),
                value: _copyQuoteLabel(settings.copyQuoteFormat),
                options: const [
                  'None',
                  'Book ID',
                  'Book Name',
                  'Full Citation',
                ],
                selectedValue: _copyQuoteLabel(settings.copyQuoteFormat),
                onSelected: (label) {
                  final format = _copyQuoteCode(label);
                  ref
                      .read(settingsProvider.notifier)
                      .setCopyQuoteFormat(format);
                },
                colors: colors,
              ),
              _DropdownTile<CopyScope>(
                icon: Icons.content_copy,
                title: 'Default Copy Scope',
                subtitle: _copyScopeLabel(settings.copyDefaultScope),
                value: _copyScopeLabel(settings.copyDefaultScope),
                options: const [
                  'Pāli Only',
                  'Translation Only',
                  'Both',
                ],
                selectedValue: _copyScopeLabel(settings.copyDefaultScope),
                onSelected: (label) {
                  final scope = _copyScopeCode(label);
                  ref
                      .read(settingsProvider.notifier)
                      .setCopyDefaultScope(scope);
                },
                colors: colors,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),

          // Auto-scroll
          SettingsSection(
            title: 'Auto-Scroll',
            colors: colors,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.md,
                  AppDimensions.md,
                  AppDimensions.md,
                  AppDimensions.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.speed, color: colors.primary),
                        const SizedBox(width: AppDimensions.md),
                        Expanded(
                          child: Text(
                            'Auto-Scroll Speed',
                            style: AppTypography.labelMedium.copyWith(
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                        Text(
                          '${settings.autoScrollSpeed.round()} px/s',
                          style: AppTypography.labelSmall.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: settings.autoScrollSpeed,
                      min: 20,
                      max: 120,
                      divisions: 10,
                      label: '${settings.autoScrollSpeed.round()} px/s',
                      activeColor: colors.primary,
                      inactiveColor: colors.outlineVariant,
                      onChanged: (v) {
                        ref
                            .read(settingsProvider.notifier)
                            .setAutoScrollSpeed(v);
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 40),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Slow',
                            style: AppTypography.labelSmall.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            'Fast',
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
            ],
          ),
          const SizedBox(height: AppDimensions.md),

          // Keep Screen On
          SettingsSection(
            title: 'Display',
            colors: colors,
            children: [
              _SwitchTile(
                icon: Icons.brightness_medium,
                title: 'Keep Screen On',
                subtitle: 'Prevent screen from dimming while reading',
                value: settings.keepScreenOn,
                onChanged: (v) {
                  ref.read(settingsProvider.notifier).setKeepScreenOn(v);
                },
                colors: colors,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _pageSystemLabel(String code) {
    switch (code) {
      case 'vri':
        return 'VRI';
      case 'pts':
        return 'PTS';
      case 'thai':
        return 'Thai';
      case 'my':
        return 'Myanmar';
      default:
        return 'VRI';
    }
  }

  String _pageSystemCode(String label) {
    switch (label) {
      case 'VRI':
        return 'vri';
      case 'PTS':
        return 'pts';
      case 'Thai':
        return 'thai';
      case 'Myanmar':
        return 'my';
      default:
        return 'vri';
    }
  }
}

String _copyQuoteLabel(CopyQuoteFormat format) {
  switch (format) {
    case CopyQuoteFormat.none:
      return 'None';
    case CopyQuoteFormat.bookId:
      return 'Book ID';
    case CopyQuoteFormat.bookName:
      return 'Book Name';
    case CopyQuoteFormat.full:
      return 'Full Citation';
  }
}

CopyQuoteFormat _copyQuoteCode(String label) {
  switch (label) {
    case 'Book ID':
      return CopyQuoteFormat.bookId;
    case 'Book Name':
      return CopyQuoteFormat.bookName;
    case 'Full Citation':
      return CopyQuoteFormat.full;
    default:
      return CopyQuoteFormat.none;
  }
}

String _copyScopeLabel(CopyScope scope) {
  switch (scope) {
    case CopyScope.pali:
      return 'Pāli Only';
    case CopyScope.translation:
      return 'Translation Only';
    case CopyScope.both:
      return 'Both';
  }
}

CopyScope _copyScopeCode(String label) {
  switch (label) {
    case 'Pāli Only':
      return CopyScope.pali;
    case 'Translation Only':
      return CopyScope.translation;
    default:
      return CopyScope.both;
  }
}

class _DropdownTile<T> extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String value;
  final List<String> options;
  final String selectedValue;
  final ValueChanged<String> onSelected;
  final ColorScheme colors;

  const _DropdownTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.md,
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: subtitle != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.labelMedium.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                      Text(
                        subtitle!,
                        style: AppTypography.labelSmall.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  )
                : Text(
                    title,
                    style: AppTypography.labelMedium.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
          ),
          PopupMenuButton<String>(
            initialValue: selectedValue,
            onSelected: onSelected,
            itemBuilder: (context) => [
              for (final opt in options)
                PopupMenuItem(
                  value: opt,
                  child: Text(opt),
                ),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
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
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final ColorScheme colors;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.md,
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 20,
            child: Switch(
              value: value,
              activeTrackColor: colors.primary,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
