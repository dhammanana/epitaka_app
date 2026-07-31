import 'package:flutter/material.dart' hide ColorSwatch;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_localizations.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/color_pair.dart';
import '../widgets/color_swatch.dart';
import '../widgets/settings_app_bar.dart';
import '../widgets/settings_section.dart';

class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final darkAccent = ColorPair.deriveDark(settings.accentColor);
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: SettingsAppBar(colors: colors),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.marginMobile, AppDimensions.md, AppDimensions.marginMobile, 120,
        ),
        children: [
          Text(loc.appearance, style: AppTypography.headlineLarge.copyWith(color: colors.onSurface)),
          const SizedBox(height: AppDimensions.lg),
          _AccentPairCard(lightAccent: settings.accentColor, darkAccent: darkAccent, isDarkMode: isDark, colors: colors),
          const SizedBox(height: AppDimensions.lg),
          SettingsSection(title: loc.theme, colors: colors, children: [
            _ThemeGrid(
              current: settings.themePreference,
              accentColor: settings.accentColor,
              platformBrightness: isDark ? Brightness.dark : Brightness.light,
              onSelected: (pref) =>
                  ref.read(settingsProvider.notifier).setThemePreference(pref),
              colors: colors,
            ),
          ]),
          const SizedBox(height: AppDimensions.md),
          SettingsSection(title: loc.accentColor, colors: colors, children: [
            Padding(padding: const EdgeInsets.all(AppDimensions.md), child: Wrap(spacing: AppDimensions.sm, runSpacing: AppDimensions.sm, children: [
              for (final accent in AppColors.accentPresets)
                ColorSwatch(color: accent, isSelected: settings.accentColor == accent, onTap: () => ref.read(settingsProvider.notifier).setAccentColor(accent)),
            ])),
          ]),
        ],
      ),
    );
  }
}

class _AccentPairCard extends StatelessWidget {
  final Color lightAccent; final Color darkAccent; final bool isDarkMode; final ColorScheme colors;
  const _AccentPairCard({required this.lightAccent, required this.darkAccent, required this.isDarkMode, required this.colors});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(AppDimensions.radiusXl), border: Border.all(color: colors.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(loc.accentPairPreview, style: AppTypography.labelSmall.copyWith(color: colors.onSurfaceVariant)),
        const SizedBox(height: AppDimensions.md),
        _AccentRow(label: loc.lightMode, color: lightAccent, isActive: !isDarkMode, colors: colors),
        const SizedBox(height: AppDimensions.sm), const Divider(height: 1), const SizedBox(height: AppDimensions.sm),
        _AccentRow(label: loc.darkMode, color: darkAccent, isActive: isDarkMode, colors: colors),
      ]),
    );
  }
}

class _AccentRow extends StatelessWidget {
  final String label; final Color color; final bool isActive; final ColorScheme colors;
  const _AccentRow({required this.label, required this.color, required this.isActive, required this.colors});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Opacity(
      opacity: isActive ? 1.0 : 0.5,
      child: Row(children: [
        Container(width: 28, height: 28, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: isActive ? color : colors.outlineVariant, width: 2))),
        const SizedBox(width: AppDimensions.sm),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppTypography.labelSmall.copyWith(color: colors.onSurface, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400)),
          Text(_hex(color), style: AppTypography.labelSmall.copyWith(color: colors.onSurfaceVariant, fontSize: 10)),
        ]),
        const Spacer(),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9999)),
          child: Text(loc.buttonLabel, style: AppTypography.labelSmall.copyWith(color: _onColor(color), fontWeight: FontWeight.w600))),
        const SizedBox(width: 8),
        Icon(Icons.favorite, color: color, size: 18),
        const SizedBox(width: 8),
        Container(width: 16, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
      ]),
    );
  }

  String _hex(Color c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  Color _onColor(Color bg) => bg.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
}

/// Grid of theme cards, each showing a live mini-preview of its palette.
class _ThemeGrid extends StatelessWidget {
  final ThemePreference current;
  final Color? accentColor;
  final Brightness platformBrightness;
  final ValueChanged<ThemePreference> onSelected;
  final ColorScheme colors;

  const _ThemeGrid({
    required this.current,
    required this.accentColor,
    required this.platformBrightness,
    required this.onSelected,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    // Build each theme's color scheme once per build — the accent is shared
    // by every card, so per-card construction would be wasteful.
    final schemes = <ThemePreference, ColorScheme>{
      for (final pref in ThemePreference.displayOrder)
        pref: AppTheme.forPreference(
          pref,
          platformBrightness: platformBrightness,
          accentColor: accentColor,
        ).colorScheme,
    };

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 260,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
        ),
        children: [
          for (final pref in ThemePreference.displayOrder)
            _ThemePreviewCard(
              preference: pref,
              scheme: schemes[pref]!,
              selected: pref == current,
              onTap: () => onSelected(pref),
            ),
        ],
      ),
    );
  }
}

/// A tappable card that renders a miniature preview of one theme using its
/// real color scheme, so users see what they're choosing before selecting.
class _ThemePreviewCard extends StatelessWidget {
  final ThemePreference preference;
  final ColorScheme scheme;
  final bool selected;
  final VoidCallback onTap;

  const _ThemePreviewCard({
    required this.preference,
    required this.scheme,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final cs = scheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            // ── Live preview ──
            Expanded(
              child: Container(
                width: double.infinity,
                color: cs.surface,
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 5,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: cs.secondaryContainer,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: cs.onSecondaryContainer.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      'Evaṃ me sutaṃ',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Thus have I heard…',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 8,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final c in [
                          cs.primary,
                          cs.primaryContainer,
                          cs.secondary,
                          cs.tertiary,
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // ── Name + gloss ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 7,
              ),
              decoration: BoxDecoration(color: colors.surfaceContainerLow),
              child: Row(
                children: [
                  if (selected)
                    Icon(Icons.check_circle, size: 14, color: colors.primary)
                  else
                    const SizedBox(width: 14),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.themeName(preference),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelSmall.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          loc.themeGloss(preference),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelSmall.copyWith(
                            color: colors.onSurfaceVariant,
                            fontSize: 9,
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
      ),
    );
  }
}
