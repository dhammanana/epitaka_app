import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/translation_registry_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../widgets/settings_app_bar.dart';

/// Granular typography & font size settings.
///
/// Shows Pāli settings and per-language translation settings
/// based on which translation DB files are available.
class TypographySettingsScreen extends ConsumerWidget {
  const TypographySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final colors = Theme.of(context).colorScheme;
    final availableTranslationsAsync = ref.watch(translationRegistryProvider);

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
            'Typography & Font Size',
            style: AppTypography.headlineLarge.copyWith(
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: AppDimensions.lg),

          // Pāli typography section
          _TypographySection(
            title: 'Pāli Text',
            icon: Icons.text_fields,
            fontSize: settings.typography.pali.fontSize,
            defaultFontSize: 19,
            onFontSizeChanged: (value) {
              ref.read(settingsProvider.notifier).setPaliTypography(
                    settings.typography.pali.copyWith(fontSize: value),
                  );
            },
            onLineHeightChanged: (_) {},
          ),

          const SizedBox(height: AppDimensions.md),

          // Per-language translation typography
          ...availableTranslationsAsync.when(
            loading: () => [
              _LoadingPlaceholder(colors: colors),
            ],
            error: (e, _) => [
              _ErrorPlaceholder(colors: colors, message: e.toString()),
            ],
            data: (translations) {
              final available = translations.where((t) => t.isAvailable).toList();
              if (available.isEmpty) {
                return [
                  _NoTranslationPlaceholder(colors: colors),
                ];
              }

              return available.map((translation) {
                final langCode = translation.languageCode;
                final langName = translation.englishName;
                final fontSize = settings.typography.fontSizeFor(langCode);
                const defaultFontSize = 17.0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.md),
                  child: _TypographySection(
                    title: '$langName Translation',
                    subtitle: translation.nativeName,
                    icon: Icons.translate,
                    fontSize: fontSize,
                    defaultFontSize: defaultFontSize,
                    onFontSizeChanged: (value) {
                      ref
                          .read(settingsProvider.notifier)
                          .setLanguageTypography(
                            langCode,
                            LanguageTypography(fontSize: value),
                          );
                    },
                    onLineHeightChanged: (_) {},
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
    );
  }
}

/// A collapsible section for configuring typography of a language.
class _TypographySection extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final double fontSize;
  final double defaultFontSize;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onLineHeightChanged;

  const _TypographySection({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.fontSize,
    required this.defaultFontSize,
    required this.onFontSizeChanged,
    required this.onLineHeightChanged,
  });

  @override
  State<_TypographySection> createState() => _TypographySectionState();
}

class _TypographySectionState extends State<_TypographySection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fontSizePercent =
        ((widget.fontSize / widget.defaultFontSize) * 100).round();

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.md),
              child: Row(
                children: [
                  Icon(widget.icon, color: colors.primary),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: AppTypography.labelMedium.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                        if (widget.subtitle != null)
                          Text(
                            widget.subtitle!,
                            style: AppTypography.labelSmall.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${widget.fontSize.round()}px',
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          if (_expanded) ...[
            // Font size slider
            _buildFontSizeControl(colors, fontSizePercent),
          ],
        ],
      ),
    );
  }

  Widget _buildFontSizeControl(ColorScheme colors, int percent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        0,
        AppDimensions.md,
        AppDimensions.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Font Size',
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _FontSizeButton(
                icon: Icons.remove,
                onTap: () {
                  final newSize = (widget.fontSize - 1).clamp(12.0, 40.0);
                  widget.onFontSizeChanged(newSize);
                },
                colors: colors,
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Slider(
                  value: widget.fontSize,
                  min: 12,
                  max: 40,
                  divisions: 28,
                  label: '${widget.fontSize.round()}px',
                  onChanged: widget.onFontSizeChanged,
                ),
              ),
              const SizedBox(width: AppDimensions.md),
              _FontSizeButton(
                icon: Icons.add,
                onTap: () {
                  final newSize = (widget.fontSize + 1).clamp(12.0, 40.0);
                  widget.onFontSizeChanged(newSize);
                },
                colors: colors,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '$percent% · ${widget.fontSize.round()}px',
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FontSizeButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ColorScheme colors;

  const _FontSizeButton({
    required this.icon,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9999),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Icon(icon, size: 16, color: colors.onSurfaceVariant),
      ),
    );
  }
}

class _LoadingPlaceholder extends StatelessWidget {
  final ColorScheme colors;

  const _LoadingPlaceholder({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

class _ErrorPlaceholder extends StatelessWidget {
  final ColorScheme colors;
  final String message;

  const _ErrorPlaceholder({required this.colors, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(color: colors.errorContainer),
      ),
      child: Text(
        'Could not load translations: $message',
        style: AppTypography.labelSmall.copyWith(color: colors.error),
      ),
    );
  }
}

class _NoTranslationPlaceholder extends StatelessWidget {
  final ColorScheme colors;

  const _NoTranslationPlaceholder({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.translate, size: 32, color: colors.outlineVariant),
          const SizedBox(height: 8),
          Text(
            'No translation databases found.',
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Download translations in Settings → Translations & Downloads.',
            style: AppTypography.labelSmall.copyWith(
              color: colors.outline,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
