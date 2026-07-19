import 'package:flutter/material.dart' hide ColorSwatch;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_localizations.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../widgets/color_swatch.dart';
import '../widgets/settings_app_bar.dart';
import '../widgets/settings_section.dart';

class ReadingColorsScreen extends ConsumerWidget {
  const ReadingColorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brightness = isDark ? Brightness.dark : Brightness.light;
    final previewPali = settings.paliColorPair.resolve(brightness);
    final previewTrans = settings.translationColorPair.resolve(brightness);
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: SettingsAppBar(colors: colors),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppDimensions.marginMobile, AppDimensions.md, AppDimensions.marginMobile, 120),
        children: [
          Text(loc.readingColors, style: AppTypography.headlineLarge.copyWith(color: colors.onSurface)),
          const SizedBox(height: AppDimensions.lg),
          _LivePreviewCard(paliColor: previewPali, transColor: previewTrans, paliText: 'Evam me sutam…', transText: 'Thus have I heard…',
            label: isDark ? loc.darkModePreview : loc.lightModePreview, colors: colors),
          const SizedBox(height: AppDimensions.lg),
          SettingsSection(title: loc.paliTextColor, colors: colors, children: [
            Padding(padding: const EdgeInsets.all(AppDimensions.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _ColorRow(label: loc.lightModeLabel, color: settings.paliColorPair.light, colors: colors),
              const SizedBox(height: AppDimensions.sm),
              Wrap(spacing: AppDimensions.sm, runSpacing: AppDimensions.sm, children: [..._paliColorPresets().map((c) => ColorSwatch(color: c, isSelected: settings.paliColorPair.light == c, onTap: () => ref.read(settingsProvider.notifier).setPaliColor(c)))]),
              const SizedBox(height: AppDimensions.sm), Divider(color: colors.outlineVariant.withValues(alpha: 0.4)), const SizedBox(height: AppDimensions.sm),
              _ColorRow(label: loc.darkModeAuto, color: settings.paliColorPair.dark, colors: colors),
            ])),
          ]),
          const SizedBox(height: AppDimensions.md),
          SettingsSection(title: loc.translationTextColor, colors: colors, children: [
            Padding(padding: const EdgeInsets.all(AppDimensions.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _ColorRow(label: loc.lightModeLabel, color: settings.translationColorPair.light, colors: colors),
              const SizedBox(height: AppDimensions.sm),
              Wrap(spacing: AppDimensions.sm, runSpacing: AppDimensions.sm, children: [..._transColorPresets().map((c) => ColorSwatch(color: c, isSelected: settings.translationColorPair.light == c, onTap: () => ref.read(settingsProvider.notifier).setTranslationColor(c)))]),
              const SizedBox(height: AppDimensions.sm), Divider(color: colors.outlineVariant.withValues(alpha: 0.4)), const SizedBox(height: AppDimensions.sm),
              _ColorRow(label: loc.darkModeAuto, color: settings.translationColorPair.dark, colors: colors),
            ])),
          ]),
        ],
      ),
    );
  }

  List<Color> _paliColorPresets() => [const Color(0xFF7A2E1D), const Color(0xFF994532), const Color(0xFFB5651D), const Color(0xFF8B1A1A), const Color(0xFF3D3D8F), const Color(0xFF2A6B6B), const Color(0xFF5D4037), const Color(0xFF6A1B9A)];
  List<Color> _transColorPresets() => [const Color(0xFF33312E), const Color(0xFF221A14), const Color(0xFF544338), const Color(0xFF3C6E47), const Color(0xFF4A6FA5), const Color(0xFF6B635A), const Color(0xFF2E7D32), const Color(0xFF5D4037)];
}

class _ColorRow extends StatelessWidget {
  final String label; final Color color; final ColorScheme colors;
  const _ColorRow({required this.label, required this.color, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 20, height: 20, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: colors.outlineVariant))),
      const SizedBox(width: AppDimensions.sm),
      Text(label, style: AppTypography.labelSmall.copyWith(color: colors.onSurfaceVariant)),
      const Spacer(),
      Text('#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}', style: AppTypography.labelSmall.copyWith(color: colors.onSurfaceVariant, fontSize: 11)),
    ]);
  }
}

class _LivePreviewCard extends StatelessWidget {
  final Color paliColor; final Color transColor; final String paliText; final String transText; final String label; final ColorScheme colors;
  const _LivePreviewCard({required this.paliColor, required this.transColor, required this.paliText, required this.transText, required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(width: double.infinity, padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(AppDimensions.radiusXl), border: Border.all(color: colors.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Text(label, style: AppTypography.labelSmall.copyWith(color: colors.onSurfaceVariant)), const SizedBox(width: 8),
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: paliColor)),
          const SizedBox(width: 4), Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: transColor))]),
        const SizedBox(height: AppDimensions.sm),
        Text(paliText, style: AppTypography.bodyPali.copyWith(color: paliColor)),
        const SizedBox(height: 4), Text(transText, style: AppTypography.bodyTranslation.copyWith(color: transColor)),
      ]),
    );
  }
}
