import 'package:flutter/material.dart' hide ColorSwatch;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/color_pair.dart';
import '../widgets/color_swatch.dart';
import '../widgets/settings_app_bar.dart';
import '../widgets/settings_section.dart';

/// Reading Colors settings: Pāli and translation text color pickers with live
/// preview showing how the colour looks in both light and dark mode.
class ReadingColorsScreen extends ConsumerWidget {
  const ReadingColorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brightness =
        isDark ? Brightness.dark : Brightness.light;

    // Resolve preview colours via ColorPair (automatically picks dark variant)
    final previewPali = settings.paliColorPair.resolve(brightness);
    final previewTrans = settings.translationColorPair.resolve(brightness);

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
            'Reading Colors',
            style: AppTypography.headlineLarge.copyWith(
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: AppDimensions.lg),

          // Live Preview — shows the ACTUAL colour for current mode
          _LivePreviewCard(
            paliColor: previewPali,
            transColor: previewTrans,
            paliText: 'Evam me sutam…',
            transText: 'Thus have I heard…',
            label: isDark ? 'Dark Mode Preview' : 'Light Mode Preview',
            colors: colors,
          ),
          const SizedBox(height: AppDimensions.lg),

          // Pāli Color
          SettingsSection(
            title: 'Pāli Text Color',
            colors: colors,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppDimensions.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Light mode colour swatch
                    _ColorRow(
                      label: 'Light mode',
                      color: settings.paliColorPair.light,
                      colors: colors,
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    Wrap(
                      spacing: AppDimensions.sm,
                      runSpacing: AppDimensions.sm,
                      children: [
                        ..._paliColorPresets().map((c) => ColorSwatch(
                              color: c,
                              isSelected: settings.paliColorPair.light == c,
                              onTap: () => ref
                                  .read(settingsProvider.notifier)
                                  .setPaliColor(c),
                            )),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    Divider(color: colors.outlineVariant.withValues(alpha: 0.4)),
                    const SizedBox(height: AppDimensions.sm),
                    // Dark mode colour swatch (auto-derived)
                    _ColorRow(
                      label: 'Dark mode (auto)',
                      color: settings.paliColorPair.dark,
                      colors: colors,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),

          // Translation Color
          SettingsSection(
            title: 'Translation Text Color',
            colors: colors,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppDimensions.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Light mode colour swatch
                    _ColorRow(
                      label: 'Light mode',
                      color: settings.translationColorPair.light,
                      colors: colors,
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    Wrap(
                      spacing: AppDimensions.sm,
                      runSpacing: AppDimensions.sm,
                      children: [
                        ..._transColorPresets().map((c) => ColorSwatch(
                              color: c,
                              isSelected: settings.translationColorPair.light == c,
                              onTap: () => ref
                                  .read(settingsProvider.notifier)
                                  .setTranslationColor(c),
                            )),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    Divider(color: colors.outlineVariant.withValues(alpha: 0.4)),
                    const SizedBox(height: AppDimensions.sm),
                    // Dark mode colour swatch (auto-derived)
                    _ColorRow(
                      label: 'Dark mode (auto)',
                      color: settings.translationColorPair.dark,
                      colors: colors,
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

  String _colorHex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  List<Color> _paliColorPresets() => [
        const Color(0xFF7A2E1D), // terracotta (default)
        const Color(0xFF994532), // secondary
        const Color(0xFFB5651D), // saffron
        const Color(0xFF8B1A1A), // maroon
        const Color(0xFF3D3D8F), // indigo
        const Color(0xFF2A6B6B), // teal
        const Color(0xFF5D4037), // brown
        const Color(0xFF6A1B9A), // purple
      ];

  List<Color> _transColorPresets() => [
        const Color(0xFF33312E), // warm charcoal (default)
        const Color(0xFF221A14), // on-surface
        const Color(0xFF544338), // on-surface-variant
        const Color(0xFF3C6E47), // green
        const Color(0xFF4A6FA5), // slate blue
        const Color(0xFF6B635A), // mid grey
        const Color(0xFF2E7D32), // dark green
        const Color(0xFF5D4037), // brown
      ];
}

/// Small helper: colour circle + hex label.
class _ColorRow extends StatelessWidget {
  final String label;
  final Color color;
  final ColorScheme colors;

  const _ColorRow({
    required this.label,
    required this.color,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: colors.outlineVariant),
          ),
        ),
        const SizedBox(width: AppDimensions.sm),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          _colorHex(color),
          style: AppTypography.labelSmall.copyWith(
            color: colors.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  String _colorHex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
}

class _LivePreviewCard extends StatelessWidget {
  final Color paliColor;
  final Color transColor;
  final String paliText;
  final String transText;
  final String label;
  final ColorScheme colors;

  const _LivePreviewCard({
    required this.paliColor,
    required this.transColor,
    required this.paliText,
    required this.transText,
    required this.label,
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
          Row(
            children: [
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: paliColor,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: transColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            paliText,
            style: AppTypography.bodyPali.copyWith(color: paliColor),
          ),
          const SizedBox(height: 4),
          Text(
            transText,
            style: AppTypography.bodyTranslation.copyWith(color: transColor),
          ),
        ],
      ),
    );
  }
}
