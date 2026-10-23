import 'package:flutter/material.dart' hide ColorSwatch;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/translation_version.dart'
    show TranslationLanguageRegistry;
import '../../../core/utils/app_localizations.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/color_pair.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/pali_text_utils.dart'
    show convertPaliToScript, paliReadingFontFamily;
import '../widgets/color_picker_section.dart';
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
    final visibleLangs = settings.visibleTranslationLangs;
    // Each translation language has its own colour; the screen previews the
    // first one, exactly like the reader's top translation line.
    final previewLang = visibleLangs.isNotEmpty
        ? visibleLangs.first
        : settings.primaryTranslationLang;
    final transPair = settings.translationColorPairFor(previewLang);
    final previewTrans = transPair.resolve(brightness);
    final loc = AppLocalizations.of(context);
    // Styled exactly as the reader styles them: a colour set on the Pāli or
    // translation card overrides the reading colour chosen here.
    final paliTypo = settings.typography.pali;
    final paliStyle = paliTypo
        .toTextStyle(fallbackColor: previewPali)
        .copyWith(
          fontFamily: paliReadingFontFamily(
            settings.paliScript,
            paliTypo.fontFamily,
          ),
        );
    final transStyle = settings.typography
        .typographyFor(previewLang)
        .toTextStyle(fallbackColor: previewTrans);

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
            loc.readingColors,
            style: AppTypography.headlineLarge.copyWith(
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
          _LivePreviewCard(
            paliStyle: paliStyle,
            transStyle: transStyle,
            paliText: convertPaliToScript(
              'Evaṃ me sutaṃ…',
              settings.paliScript,
            ),
            transText: 'Thus have I heard…',
            label: isDark ? loc.darkModePreview : loc.lightModePreview,
            colors: colors,
          ),
          const SizedBox(height: AppDimensions.lg),
          SettingsSection(
            title: loc.paliTextColor,
            colors: colors,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppDimensions.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ColorRow(
                      label: loc.lightModeLabel,
                      color: settings.paliColorPair.light,
                      colors: colors,
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    Wrap(
                      spacing: AppDimensions.sm,
                      runSpacing: AppDimensions.sm,
                      children: [
                        ..._paliColorPresets().map(
                          (c) => ColorSwatch(
                            color: c,
                            isSelected: settings.paliColorPair.light == c,
                            onTap: () => ref
                                .read(settingsProvider.notifier)
                                .setPaliColor(c),
                          ),
                        ),
                        _CustomColorButton(
                          onTap: () => _showColorPicker(
                            context,
                            settings.paliColorPair.light,
                            (c) => ref
                                .read(settingsProvider.notifier)
                                .setPaliColor(c),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    Divider(
                      color: colors.outlineVariant.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    _ColorRow(
                      label: settings.paliColorPair.darkPicked
                          ? loc.darkMode
                          : loc.darkModeAuto,
                      color: settings.paliColorPair.dark,
                      colors: colors,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (visibleLangs.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.md),
            // One colour group per shown translation: picking a colour changes
            // only that language.
            SettingsSection(
              title: loc.translationTextColor,
              colors: colors,
              children: [
                for (final langCode in visibleLangs)
                  _TranslationColourGroup(
                    key: ValueKey('translation_colour_$langCode'),
                    langCode: langCode,
                    pair: settings.translationColorPairFor(langCode),
                    presets: _transColorPresets(),
                    colors: colors,
                    onPick: (c) => ref
                        .read(settingsProvider.notifier)
                        .setTranslationColorForLang(langCode, c),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Color> _paliColorPresets() => [
    const Color(0xFF000000),
    const Color(0xFF7A2E1D),
    const Color(0xFF994532),
    const Color(0xFFB5651D),
    const Color(0xFF8B1A1A),
    const Color(0xFF3D3D8F),
    const Color(0xFF2A6B6B),
    const Color(0xFF5D4037),
    const Color(0xFF6A1B9A),
  ];
  List<Color> _transColorPresets() => [
    const Color(0xFF33312E),
    const Color(0xFF221A14),
    const Color(0xFF544338),
    const Color(0xFF3C6E47),
    const Color(0xFF4A6FA5),
    const Color(0xFF6B635A),
    const Color(0xFF2E7D32),
    const Color(0xFF5D4037),
    const Color(0xFF2A6B6B),
    const Color(0xFF994532),
    const Color(0xFF6A1B9A),
  ];

  /// Show the full color picker screen.
  static Future<void> _showColorPicker(
    BuildContext context,
    Color current,
    ValueChanged<Color> onPicked,
  ) {
    final loc = AppLocalizations.of(context);
    return showColorPickerScreen(
      context,
      title: loc.pickAColor,
      initialColor: current,
      onApply: onPicked,
    );
  }
}

class _CustomColorButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CustomColorButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: colors.outlineVariant, width: 2),
        ),
        child: Icon(Icons.colorize, size: 18, color: colors.onSurfaceVariant),
      ),
    );
  }
}

/// The colour picker for one translation language.
class _TranslationColourGroup extends StatelessWidget {
  final String langCode;
  final ColorPair pair;
  final List<Color> presets;
  final ColorScheme colors;
  final ValueChanged<Color> onPick;

  const _TranslationColourGroup({
    super.key,
    required this.langCode,
    required this.pair,
    required this.presets,
    required this.colors,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            TranslationLanguageRegistry.englishName(langCode),
            style: AppTypography.labelMedium.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          _ColorRow(
            label: loc.lightModeLabel,
            color: pair.light,
            colors: colors,
          ),
          const SizedBox(height: AppDimensions.sm),
          Wrap(
            spacing: AppDimensions.sm,
            runSpacing: AppDimensions.sm,
            children: [
              ...presets.map(
                (c) => ColorSwatch(
                  color: c,
                  isSelected: pair.light == c,
                  onTap: () => onPick(c),
                ),
              ),
              _CustomColorButton(
                onTap: () => ReadingColorsScreen._showColorPicker(
                  context,
                  pair.light,
                  onPick,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Divider(color: colors.outlineVariant.withValues(alpha: 0.4)),
          const SizedBox(height: AppDimensions.sm),
          _ColorRow(
            label: pair.darkPicked ? loc.darkMode : loc.darkModeAuto,
            color: pair.dark,
            colors: colors,
          ),
        ],
      ),
    );
  }
}

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
          '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
          style: AppTypography.labelSmall.copyWith(
            color: colors.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _LivePreviewCard extends StatelessWidget {
  final TextStyle paliStyle;
  final TextStyle transStyle;
  final String paliText;
  final String transText;
  final String label;
  final ColorScheme colors;
  const _LivePreviewCard({
    required this.paliStyle,
    required this.transStyle,
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
                  color: paliStyle.color,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: transStyle.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(paliText, style: paliStyle),
          const SizedBox(height: 4),
          Text(transText, style: transStyle),
        ],
      ),
    );
  }
}
