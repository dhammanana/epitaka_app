import 'package:flutter/material.dart' hide ColorSwatch;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../widgets/color_swatch.dart';
import '../widgets/settings_app_bar.dart';
import '../widgets/settings_section.dart';

/// Reading Colors settings: Pāli and translation text color pickers with live preview.
class ReadingColorsScreen extends ConsumerWidget {
  const ReadingColorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Derive preview colors (dark mode lightens them)
    final previewPali = isDark
        ? settings.paliColor.withValues(alpha: 0.9)
        : settings.paliColor;
    final previewTrans = isDark
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
            'Reading Colors',
            style: AppTypography.headlineLarge.copyWith(
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: AppDimensions.lg),

          // Live Preview
          _LivePreviewCard(
            paliColor: previewPali,
            transColor: previewTrans,
            paliText: 'Evam me sutam…',
            transText: 'Thus have I heard…',
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
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: settings.paliColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.outlineVariant),
                          ),
                        ),
                        const SizedBox(width: AppDimensions.sm),
                        Text(
                          _colorHex(settings.paliColor),
                          style: AppTypography.labelSmall.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    Wrap(
                      spacing: AppDimensions.sm,
                      runSpacing: AppDimensions.sm,
                      children: [
                        ..._paliColorPresets().map((c) => ColorSwatch(
                              color: c,
                              isSelected: settings.paliColor == c,
                              onTap: () => ref
                                  .read(settingsProvider.notifier)
                                  .setPaliColor(c),
                            )),
                      ],
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
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: settings.translationColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.outlineVariant),
                          ),
                        ),
                        const SizedBox(width: AppDimensions.sm),
                        Text(
                          _colorHex(settings.translationColor),
                          style: AppTypography.labelSmall.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    Wrap(
                      spacing: AppDimensions.sm,
                      runSpacing: AppDimensions.sm,
                      children: [
                        ..._transColorPresets().map((c) => ColorSwatch(
                              color: c,
                              isSelected: settings.translationColor == c,
                              onTap: () => ref
                                  .read(settingsProvider.notifier)
                                  .setTranslationColor(c),
                            )),
                      ],
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
      ];

  List<Color> _transColorPresets() => [
        const Color(0xFF33312E), // warm charcoal (default)
        const Color(0xFF221A14), // on-surface
        const Color(0xFF544338), // on-surface-variant
        const Color(0xFF3C6E47), // green
        const Color(0xFF4A6FA5), // slate blue
        const Color(0xFF6B635A), // mid grey
      ];
}

class _LivePreviewCard extends StatelessWidget {
  final Color paliColor;
  final Color transColor;
  final String paliText;
  final String transText;
  final ColorScheme colors;

  const _LivePreviewCard({
    required this.paliColor,
    required this.transColor,
    required this.paliText,
    required this.transText,
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
