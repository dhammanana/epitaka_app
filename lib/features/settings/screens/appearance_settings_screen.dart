import 'package:flutter/material.dart' hide ColorSwatch;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/color_pair.dart';
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
    final darkAccent = ColorPair.deriveDark(settings.accentColor);

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

          // Accent Colour Pair Preview — shows the accent in both
          // light and dark variants side by side.
          _AccentPairCard(
            lightAccent: settings.accentColor,
            darkAccent: darkAccent,
            isDarkMode: isDark,
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

/// Shows a live preview of the chosen accent colour applied to a small
/// card — buttons, switches, highlights, showing both light and dark
/// variants side by side so the user sees the "pair" at a glance.
class _AccentPairCard extends StatelessWidget {
  final Color lightAccent;
  final Color darkAccent;
  final bool isDarkMode;
  final ColorScheme colors;

  const _AccentPairCard({
    required this.lightAccent,
    required this.darkAccent,
    required this.isDarkMode,
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
            'Accent Pair Preview',
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.md),

          // ── Light-mode row ──────────────────────────────────────────
          _AccentRow(
            label: 'Light mode',
            color: lightAccent,
            isActive: !isDarkMode,
            colors: colors,
          ),
          const SizedBox(height: AppDimensions.sm),
          const Divider(height: 1),
          const SizedBox(height: AppDimensions.sm),

          // ── Dark-mode row ───────────────────────────────────────────
          _AccentRow(
            label: 'Dark mode',
            color: darkAccent,
            isActive: isDarkMode,
            colors: colors,
          ),
        ],
      ),
    );
  }
}

/// One row inside the accent pair card: colour circle, label, hex, and
/// sample button.
class _AccentRow extends StatelessWidget {
  final String label;
  final Color color;
  final bool isActive;
  final ColorScheme colors;

  const _AccentRow({
    required this.label,
    required this.color,
    required this.isActive,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isActive ? 1.0 : 0.5,
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive
                    ? color
                    : colors.outlineVariant,
                width: 2,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurface,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              Text(
                _hex(color),
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Sample button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Text(
              'Button',
              style: AppTypography.labelSmall.copyWith(
                color: _onColor(color),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.favorite, color: color, size: 18),
          const SizedBox(width: 8),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  String _hex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  /// Simple black/white contrast chooser.
  Color _onColor(Color bg) =>
      bg.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
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
