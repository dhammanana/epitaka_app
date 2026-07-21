import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_localizations.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/utils/reading_clipboard.dart';
import '../widgets/settings_app_bar.dart';
import '../widgets/settings_section.dart';

class ReadingOptionsScreen extends ConsumerWidget {
  const ReadingOptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

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
            loc.readingOptions,
            style: AppTypography.headlineLarge.copyWith(
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
          SettingsSection(
            title: loc.pageNumbering,
            colors: colors,
            children: [
              _DropdownTile(
                icon: Icons.numbers,
                title: loc.systemLabel,
                value: loc.pageSystemLabel(settings.pageNumberingSystem),
                options: [
                  loc.pageSystemLabel('vri'),
                  loc.pageSystemLabel('pts'),
                  loc.pageSystemLabel('thai'),
                  loc.pageSystemLabel('my'),
                ],
                selectedValue: loc.pageSystemLabel(
                  settings.pageNumberingSystem,
                ),
                onSelected: (label) {
                  final system = _pageSystemCode(label, loc);
                  ref
                      .read(settingsProvider.notifier)
                      .setPageNumberingSystem(system);
                },
                colors: colors,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          SettingsSection(
            title: loc.layout,
            colors: colors,
            children: [
              _SwitchTile(
                icon: Icons.view_column,
                title: loc.sideBySideView,
                subtitle: loc.sideBySideSubtitle,
                value:
                    settings.translationDisplayMode ==
                    TranslationDisplayMode.sideBySide,
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).setSideBySide(v),
                colors: colors,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          SettingsSection(
            title: loc.copyClipboard,
            colors: colors,
            children: [
              _DropdownTile<CopyQuoteFormat>(
                icon: Icons.format_quote,
                title: loc.quoteFormat,
                subtitle: _copyQuoteLabel(settings.copyQuoteFormat, loc),
                value: _copyQuoteLabel(settings.copyQuoteFormat, loc),
                options: [
                  loc.none,
                  loc.bookIdLabel,
                  loc.bookNameLabel,
                  loc.fullCitation,
                ],
                selectedValue: _copyQuoteLabel(settings.copyQuoteFormat, loc),
                onSelected: (label) {
                  ref
                      .read(settingsProvider.notifier)
                      .setCopyQuoteFormat(_copyQuoteCode(label, loc));
                },
                colors: colors,
              ),
              _DropdownTile<CopyScope>(
                icon: Icons.content_copy,
                title: loc.defaultCopyScope,
                subtitle: _copyScopeLabel(settings.copyDefaultScope, loc),
                value: _copyScopeLabel(settings.copyDefaultScope, loc),
                options: [loc.paliOnly, loc.translationOnly, loc.both],
                selectedValue: _copyScopeLabel(settings.copyDefaultScope, loc),
                onSelected: (label) {
                  ref
                      .read(settingsProvider.notifier)
                      .setCopyDefaultScope(_copyScopeCode(label, loc));
                },
                colors: colors,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          SettingsSection(
            title: loc.autoScrollSpeed,
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
                            loc.autoScrollSpeed,
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
                      onChanged: (v) => ref
                          .read(settingsProvider.notifier)
                          .setAutoScrollSpeed(v),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 40),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            loc.slow,
                            style: AppTypography.labelSmall.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            loc.fast,
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
          SettingsSection(
            title: loc.display,
            colors: colors,
            children: [
              _SwitchTile(
                icon: Icons.brightness_medium,
                title: loc.keepScreenOn,
                subtitle: loc.keepScreenOnSubtitle,
                value: settings.keepScreenOn,
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).setKeepScreenOn(v),
                colors: colors,
              ),
              _SwitchTile(
                icon: Icons.remove_red_eye_outlined,
                title: loc.stripVariantAnnotations,
                subtitle: loc.stripVariantAnnotationsSubtitle,
                value: settings.stripVariantAnnotations,
                onChanged: (v) => ref
                    .read(settingsProvider.notifier)
                    .setStripVariantAnnotations(v),
                colors: colors,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _pageSystemCode(String label, AppLocalizations loc) {
    if (label == loc.pageSystemLabel('vri')) return 'vri';
    if (label == loc.pageSystemLabel('pts')) return 'pts';
    if (label == loc.pageSystemLabel('thai')) return 'thai';
    if (label == loc.pageSystemLabel('my')) return 'my';
    return 'vri';
  }
}

String _copyQuoteLabel(CopyQuoteFormat format, AppLocalizations loc) {
  switch (format) {
    case CopyQuoteFormat.none:
      return loc.none;
    case CopyQuoteFormat.bookId:
      return loc.bookIdLabel;
    case CopyQuoteFormat.bookName:
      return loc.bookNameLabel;
    case CopyQuoteFormat.full:
      return loc.fullCitation;
  }
}

CopyQuoteFormat _copyQuoteCode(String label, AppLocalizations loc) {
  if (label == loc.bookNameLabel) return CopyQuoteFormat.bookName;
  if (label == loc.bookIdLabel) return CopyQuoteFormat.bookId;
  if (label == loc.fullCitation) return CopyQuoteFormat.full;
  return CopyQuoteFormat.none;
}

String _copyScopeLabel(CopyScope scope, AppLocalizations loc) {
  switch (scope) {
    case CopyScope.pali:
      return loc.paliOnly;
    case CopyScope.translation:
      return loc.translationOnly;
    case CopyScope.both:
      return loc.both;
  }
}

CopyScope _copyScopeCode(String label, AppLocalizations loc) {
  if (label == loc.paliOnly) return CopyScope.pali;
  if (label == loc.translationOnly) return CopyScope.translation;
  return CopyScope.both;
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
                PopupMenuItem(value: opt, child: Text(opt)),
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
