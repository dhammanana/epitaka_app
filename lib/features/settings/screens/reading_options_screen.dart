import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_localizations.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/utils/reading_clipboard.dart' show CopyScope;
import '../../../features/reader/utils/reader_quote_utils.dart' show pageSystemLabel;
import '../widgets/settings_app_bar.dart';
import '../widgets/settings_section.dart';

class ReadingOptionsScreen extends StatelessWidget {
  const ReadingOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: SettingsAppBar(colors: colors),
      body: const ReadingOptionsBody(),
    );
  }
}

/// Scrollable body of the reading options — shared between the mobile screen
/// and the desktop settings window.
class ReadingOptionsBody extends ConsumerWidget {
  const ReadingOptionsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    return ListView(
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
            title: loc.dictionaryLookup,
            colors: colors,
            children: [
              _DropdownTile<WordLookupGesture>(
                icon: Icons.touch_app,
                title: loc.wordLookupGesture,
                subtitle: loc.wordLookupGestureSubtitle,
                value: _wordLookupGestureLabel(
                  settings.wordLookupGesture,
                  loc,
                ),
                options: [loc.doubleTap, loc.singleTap],
                selectedValue: _wordLookupGestureLabel(
                  settings.wordLookupGesture,
                  loc,
                ),
                onSelected: (label) {
                  ref
                      .read(settingsProvider.notifier)
                      .setWordLookupGesture(
                        _wordLookupGestureCode(label, loc),
                      );
                },
                colors: colors,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          SettingsSection(
            title: loc.copyClipboard,
            colors: colors,
            children: [
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
          _QuoteFormatSection(colors: colors, settings: settings, loc: loc),
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
              _SwitchTile(
                icon: Icons.link,
                title: loc.showBookLinks,
                subtitle: loc.showBookLinksSubtitle,
                value: settings.showBookLinks,
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).setShowBookLinks(v),
                colors: colors,
              ),
            ],
          ),
        ],
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

String _wordLookupGestureLabel(
  WordLookupGesture gesture,
  AppLocalizations loc,
) {
  switch (gesture) {
    case WordLookupGesture.doubleTap:
      return loc.doubleTap;
    case WordLookupGesture.singleTap:
      return loc.singleTap;
  }
}

WordLookupGesture _wordLookupGestureCode(
  String label,
  AppLocalizations loc,
) {
  if (label == loc.singleTap) return WordLookupGesture.singleTap;
  return WordLookupGesture.doubleTap;
}

/// Settings section for customizing the quote/citation format.
class _QuoteFormatSection extends ConsumerStatefulWidget {
  final ColorScheme colors;
  final AppSettings settings;
  final AppLocalizations loc;

  const _QuoteFormatSection({
    required this.colors,
    required this.settings,
    required this.loc,
  });

  @override
  _QuoteFormatSectionState createState() => _QuoteFormatSectionState();
}

class _QuoteFormatSectionState extends ConsumerState<_QuoteFormatSection> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.settings.quoteTemplate);
  }

  @override
  void didUpdateWidget(_QuoteFormatSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.quoteTemplate != widget.settings.quoteTemplate) {
      _controller.text = widget.settings.quoteTemplate;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final loc = widget.loc;
    final settings = ref.watch(settingsProvider);

    return SettingsSection(
      title: loc.quoteFormat,
      colors: colors,
      children: [
        // ── Template text field ──
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.md,
            AppDimensions.md,
            AppDimensions.md,
            0,
          ),
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: '- {book_name} > {heading} VRI p.{vri_page}',
              labelText: loc.template,
              helperText: loc.quoteFormatHelper,
              helperMaxLines: 5,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            maxLines: 2,
            minLines: 1,
            textInputAction: TextInputAction.done,
            style: AppTypography.bodyPali.copyWith(
              fontFamily: 'monospace',
              fontSize: 14,
              color: colors.onSurface,
            ),
            onChanged: (v) {
              ref
                  .read(settingsProvider.notifier)
                  .setQuoteTemplate(v);
            },
          ),
        ),
        const SizedBox(height: 4),
        // ── Available variables help ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
          child: Text(
            loc.availableVariables,
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.md),
        // ── Page numbering system ──
        _DropdownTile(
          icon: Icons.numbers,
          title: loc.pageSystem,
          subtitle: pageSystemLabel(settings.quotePageNumberSystem),
          value: pageSystemLabel(settings.quotePageNumberSystem),
          options: [
            pageSystemLabel('vri'),
            pageSystemLabel('pts'),
            pageSystemLabel('thai'),
            pageSystemLabel('my'),
          ],
          selectedValue: pageSystemLabel(settings.quotePageNumberSystem),
          onSelected: (label) {
            final code = _pageSystemCode(label);
            ref
                .read(settingsProvider.notifier)
                .setQuotePageNumberSystem(code);
          },
          colors: colors,
        ),
        // ── Preview ──
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.md,
            0,
            AppDimensions.md,
            AppDimensions.md,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withOpacity(0.4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.preview,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _previewCitation(settings),
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurface,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _previewCitation(AppSettings settings) {
    String result = settings.quoteTemplate;
    result = result.replaceAll('{book_id}', 'dn1');
    result = result.replaceAll('{book_name}', 'Brahmajāla Sutta');
    result = result.replaceAll('{heading}', '1. The Net of Views');
    result = result.replaceAll('{vri_page}', '12');
    result = result.replaceAll('{pts_page}', '8');
    result = result.replaceAll('{thai_page}', '15');
    result = result.replaceAll('{myanmar_page}', '10');
    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _pageSystemCode(String label) {
    if (label == pageSystemLabel('vri')) return 'vri';
    if (label == pageSystemLabel('pts')) return 'pts';
    if (label == pageSystemLabel('thai')) return 'thai';
    if (label == pageSystemLabel('my')) return 'my';
    return 'vri';
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
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
