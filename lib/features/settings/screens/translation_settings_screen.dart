import 'package:flutter/material.dart' hide ColorSwatch;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/translation_registry_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/translation_download_provider.dart';
import '../widgets/color_swatch.dart';
import '../widgets/settings_app_bar.dart';
import '../widgets/settings_section.dart';

/// Translation display settings: mode selection, per-language typography & downloads.
///
/// This is the consolidated screen replacing the old "Typography & Font Size"
/// and "Reading Colors" screens. Each installed (or available) translation
/// language has an expandable tile where you can:
///   - Toggle the language on/off (checkbox)
///   - Choose font family (serif / sans-serif)
///   - Adjust font size
///   - Toggle bold, italic, underline
///   - Pick a text color
///
/// The Pāli text also has its own expandable typography card at the top.
class TranslationSettingsScreen extends ConsumerWidget {
  const TranslationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final colors = Theme.of(context).colorScheme;
    final availableTranslationsAsync = ref.watch(translationRegistryProvider);
    final downloadStates = ref.watch(translationDownloadProvider);

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
            'Translation Display',
            style: AppTypography.headlineLarge.copyWith(
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: AppDimensions.md),

          // Display mode selection
          SettingsSection(
            title: 'Display Mode',
            colors: colors,
            children: [
              _ModeSelector(
                currentMode:
                    settings.showTranslation ? settings.translationDisplayMode : null,
                showTranslation: settings.showTranslation,
                onSelectMode: (mode) {
                  ref
                      .read(settingsProvider.notifier)
                      .setTranslationDisplayMode(mode);
                  if (!settings.showTranslation) {
                    ref
                        .read(settingsProvider.notifier)
                        .setShowTranslation(true);
                  }
                },
                onToggleTranslation: (show) {
                  ref
                      .read(settingsProvider.notifier)
                      .setShowTranslation(show);
                },
                colors: colors,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),

          // ── Pāli Typography ──────────────────────────────────────────
          SettingsSection(
            title: 'Pāli Text',
            colors: colors,
            children: [
              _LanguageTypographyCard(
                isEnabled: settings.showPali,
                title: 'Pāli',
                subtitle: 'Pali (Roman script)',
                typography: settings.typography.pali,
                defaultColor: AppSettings.defaultPaliColor,
                onEnabledChanged: (v) {
                  ref.read(settingsProvider.notifier).setShowPali(v);
                },
                onTypographyChanged: (typo) {
                  ref.read(settingsProvider.notifier).setPaliTypography(typo);
                },
                colors: colors,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),

          // ── Translation languages ────────────────────────────────────
          SettingsSection(
            title: 'Translations',
            colors: colors,
            children: [
              availableTranslationsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppDimensions.md),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(AppDimensions.md),
                  child: Text(
                    'Error: $e',
                    style: AppTypography.labelSmall.copyWith(color: colors.error),
                  ),
                ),
                data: (translations) {
                  // Sort: enabled translations first (in user's order),
                  // then disabled/not-installed translations.
                  final enabledCodes = settings.enabledTranslations;
                  final sorted = List<AvailableTranslation>.from(translations);
                  sorted.sort((a, b) {
                    final aEnabled = enabledCodes.contains(a.languageCode);
                    final bEnabled = enabledCodes.contains(b.languageCode);
                    if (aEnabled && bEnabled) {
                      return enabledCodes.indexOf(a.languageCode)
                          .compareTo(enabledCodes.indexOf(b.languageCode));
                    }
                    if (aEnabled) return -1;
                    if (bEnabled) return 1;
                    return 0;
                  });

                  return ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    children: sorted.map((t) {
                      final langCode = t.languageCode;
                      final dlState = downloadStates[langCode] ??
                          const TranslationDownloadState();
                      final isEnabled =
                          enabledCodes.contains(langCode);
                      final typo = settings.typography.typographyFor(langCode);

                      // Wrap enabled items with drag listener so the
                      // drag handle icon (shown inside the card) can
                      // initiate the reorder. The listener must be a
                      // direct child of ReorderableListView.
                      Widget itemContainer = Container(
                        key: ValueKey('translation-$langCode'),
                        child: Column(
                          children: [
                            if (!t.isAvailable)
                              _TranslationDownloadTile(
                                translation: t,
                                downloadState: dlState,
                                colors: colors,
                                onDownload: () {
                                  ref
                                      .read(translationDownloadProvider.notifier)
                                      .downloadTranslation(t.language, ref);
                                },
                                onCancel: dlState.status == DownloadStatus.downloading ||
                                        dlState.status == DownloadStatus.extracting
                                    ? () => ref
                                        .read(translationDownloadProvider.notifier)
                                        .cancelDownload(t.languageCode)
                                    : null,
                              )
                            else
                              _LanguageTypographyCard(
                                isEnabled: isEnabled,
                                title: t.englishName,
                                subtitle: t.nativeName,
                                typography: typo,
                                defaultColor: AppSettings.defaultTranslationColor,
                                showDragHandle: isEnabled,
                                onEnabledChanged: (v) {
                                  ref
                                      .read(settingsProvider.notifier)
                                      .setTranslationEnabled(langCode, v);
                                },
                                onTypographyChanged: (newTypo) {
                                  ref
                                      .read(settingsProvider.notifier)
                                      .setLanguageTypography(langCode, newTypo);
                                },
                                colors: colors,
                              ),
                            if (t != sorted.last)
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: colors.outlineVariant.withValues(alpha: 0.3),
                                indent: AppDimensions.md,
                                endIndent: AppDimensions.md,
                              ),
                          ],
                        ),
                      );

                      if (isEnabled) {
                        final itemIndex = sorted.indexOf(t);
                        itemContainer = ReorderableDragStartListener(
                          index: itemIndex,
                          key: ValueKey('drag-$langCode'),
                          child: itemContainer,
                        );
                      }

                      return itemContainer;
                    }).toList(),
                    onReorder: (int oldIndex, int newIndex) {
                      // Adjust newIndex when moving forward
                      if (oldIndex < newIndex) newIndex -= 1;

                      // Get current ordered list of enabled lang codes
                      final currentOrder =
                          List<String>.from(settings.enabledTranslations);

                      // Find which translation was moved
                      final movedCode = sorted[oldIndex].languageCode;

                      // Only reorder enabled items
                      if (!currentOrder.contains(movedCode)) return;

                      // Remove from current position in enabled list
                      currentOrder.remove(movedCode);

                      // Count enabled items before newIndex in sorted list
                      int enabledCount = 0;
                      for (int i = 0; i < sorted.length; i++) {
                        if (i == newIndex) break;
                        if (currentOrder.contains(sorted[i].languageCode)) {
                          enabledCount++;
                        }
                      }

                      currentOrder.insert(enabledCount, movedCode);
                      ref
                          .read(settingsProvider.notifier)
                          .setTranslationsOrder(currentOrder);
                    },
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Language Typography Card ────────────────────────────────────────────────

/// An expandable card for configuring typography of one language (Pali or translation).
/// Shows a toggle checkbox at the top, and expands to show:
///   - Font family selector
///   - Font size slider
///   - Bold / Italic / Underline toggles
///   - Color swatches
///
/// When [showDragHandle] is true, a drag handle is shown for reordering.
class _LanguageTypographyCard extends StatefulWidget {
  final bool isEnabled;
  final String title;
  final String subtitle;
  final LanguageTypography typography;
  final Color defaultColor;
  final bool showDragHandle;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<LanguageTypography> onTypographyChanged;
  final ColorScheme colors;

  const _LanguageTypographyCard({
    required this.isEnabled,
    required this.title,
    required this.subtitle,
    required this.typography,
    required this.defaultColor,
    this.showDragHandle = false,
    required this.onEnabledChanged,
    required this.onTypographyChanged,
    required this.colors,
  });

  @override
  State<_LanguageTypographyCard> createState() =>
      _LanguageTypographyCardState();
}

class _LanguageTypographyCardState extends State<_LanguageTypographyCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final typo = widget.typography;
    final effectiveColor = typo.effectiveColor(widget.defaultColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row: drag handle + checkbox + name + expand toggle
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.md,
              vertical: AppDimensions.sm,
            ),
            child: Row(
              children: [
                // Drag handle for reordering (only on enabled translations).
                // The actual drag listener is in the parent ReorderableListView
                // wrapping the entire card; this icon is purely a visual cue.
                if (widget.showDragHandle) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.drag_handle,
                      size: 20,
                      color: widget.colors.onSurfaceVariant,
                    ),
                  ),
                ],
                // Enable/disable checkbox
                GestureDetector(
                  onTap: () => widget.onEnabledChanged(!widget.isEnabled),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: widget.isEnabled ? colors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: widget.isEnabled
                            ? colors.primary
                            : colors.outlineVariant,
                        width: 1.5,
                      ),
                    ),
                    child: widget.isEnabled
                        ? Icon(Icons.check, size: 14, color: colors.onPrimary)
                        : null,
                  ),
                ),
                const SizedBox(width: AppDimensions.md),
                // Name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: AppTypography.labelMedium.copyWith(
                          color: widget.isEnabled
                              ? colors.onSurface
                              : colors.onSurfaceVariant,
                          fontWeight: widget.isEnabled
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      Text(
                        widget.subtitle,
                        style: AppTypography.labelSmall.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Color preview dot
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: effectiveColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.outlineVariant),
                  ),
                ),
                const SizedBox(width: 8),
                // Font size preview
                Text(
                  '${typo.fontSize.round()}px',
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: colors.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ),

        // Expanded controls
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.md,
              0,
              AppDimensions.md,
              AppDimensions.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),

                // Font family
                _SectionLabel('Font Family', colors),
                const SizedBox(height: 8),
                _FontFamilySelector(
                  current: typo.fontFamily,
                  colors: colors,
                  onChanged: (family) {
                    widget.onTypographyChanged(
                        typo.copyWith(fontFamily: family));
                  },
                ),
                const SizedBox(height: AppDimensions.md),

                // Font size
                _SectionLabel('Font Size', colors),
                const SizedBox(height: 8),
                _FontSizeControl(
                  fontSize: typo.fontSize,
                  colors: colors,
                  onChanged: (size) {
                    widget.onTypographyChanged(typo.copyWith(fontSize: size));
                  },
                ),
                const SizedBox(height: AppDimensions.md),

                // Style toggles
                _SectionLabel('Style', colors),
                const SizedBox(height: 8),
                _StyleToggles(
                  bold: typo.bold,
                  italic: typo.italic,
                  underline: typo.underline,
                  colors: colors,
                  onBoldChanged: (v) =>
                      widget.onTypographyChanged(typo.copyWith(bold: v)),
                  onItalicChanged: (v) =>
                      widget.onTypographyChanged(typo.copyWith(italic: v)),
                  onUnderlineChanged: (v) =>
                      widget.onTypographyChanged(typo.copyWith(underline: v)),
                ),
                const SizedBox(height: AppDimensions.md),

                // Color
                _SectionLabel('Color', colors),
                const SizedBox(height: 8),
                _ColorPicker(
                  currentColor: typo.color ?? widget.defaultColor,
                  presets: _colorPresets(widget.defaultColor),
                  colors: colors,
                  onChanged: (c) {
                    widget.onTypographyChanged(typo.copyWith(color: c));
                  },
                ),

                // Live preview
                const SizedBox(height: AppDimensions.md),
                _SectionLabel('Preview', colors),
                const SizedBox(height: 6),
                _TextPreview(typography: typo, fallbackColor: widget.defaultColor),
              ],
            ),
          ),
      ],
    );
  }

  List<Color> _colorPresets(Color defaultColor) {
    // Offer a set of themed reading colors
    return [
      defaultColor,
      const Color(0xFF7A2E1D), // terracotta
      const Color(0xFF33312E), // warm charcoal
      const Color(0xFF3D3D8F), // indigo
      const Color(0xFF2A6B6B), // teal
      const Color(0xFF3C6E47), // green
      const Color(0xFFB5651D), // saffron
      const Color(0xFF4A6FA5), // slate blue
      const Color(0xFF6B635A), // mid grey
      Colors.black,
    ];
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final ColorScheme colors;

  const _SectionLabel(this.label, this.colors);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTypography.labelSmall.copyWith(
        color: colors.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _FontFamilySelector extends StatelessWidget {
  final ReadingFontFamily current;
  final ColorScheme colors;
  final ValueChanged<ReadingFontFamily> onChanged;

  const _FontFamilySelector({
    required this.current,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: ReadingFontFamily.values.map((family) {
        final isSelected = current == family;
        return GestureDetector(
          onTap: () => onChanged(family),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? colors.primaryContainer : colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? colors.primary : colors.outlineVariant,
              ),
            ),
            child: Text(
              family.label,
              style: TextStyle(
                fontFamily: family.fontFamily,
                fontSize: 14,
                color: isSelected ? colors.onPrimaryContainer : colors.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _FontSizeControl extends StatelessWidget {
  final double fontSize;
  final ColorScheme colors;
  final ValueChanged<double> onChanged;

  const _FontSizeControl({
    required this.fontSize,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CircleButton(
          icon: Icons.remove,
          colors: colors,
          onTap: () => onChanged((fontSize - 1).clamp(10.0, 48.0)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Slider(
            value: fontSize,
            min: 10,
            max: 48,
            divisions: 38,
            label: '${fontSize.round()}px',
            onChanged: (v) => onChanged(v),
            activeColor: colors.primary,
          ),
        ),
        const SizedBox(width: 8),
        _CircleButton(
          icon: Icons.add,
          colors: colors,
          onTap: () => onChanged((fontSize + 1).clamp(10.0, 48.0)),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 40,
          child: Text(
            '${fontSize.round()}',
            textAlign: TextAlign.center,
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final ColorScheme colors;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9999),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Icon(icon, size: 14, color: colors.onSurfaceVariant),
      ),
    );
  }
}

class _StyleToggles extends StatelessWidget {
  final bool bold;
  final bool italic;
  final bool underline;
  final ColorScheme colors;
  final ValueChanged<bool> onBoldChanged;
  final ValueChanged<bool> onItalicChanged;
  final ValueChanged<bool> onUnderlineChanged;

  const _StyleToggles({
    required this.bold,
    required this.italic,
    required this.underline,
    required this.colors,
    required this.onBoldChanged,
    required this.onItalicChanged,
    required this.onUnderlineChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StyleToggleChip(
          label: 'B',
          active: bold,
          colors: colors,
          fontWeight: FontWeight.w900,
          onTap: () => onBoldChanged(!bold),
        ),
        const SizedBox(width: 8),
        _StyleToggleChip(
          label: 'I',
          active: italic,
          colors: colors,
          fontStyle: FontStyle.italic,
          onTap: () => onItalicChanged(!italic),
        ),
        const SizedBox(width: 8),
        _StyleToggleChip(
          label: 'U',
          active: underline,
          colors: colors,
          decoration: TextDecoration.underline,
          onTap: () => onUnderlineChanged(!underline),
        ),
      ],
    );
  }
}

class _StyleToggleChip extends StatelessWidget {
  final String label;
  final bool active;
  final ColorScheme colors;
  final VoidCallback onTap;
  final FontWeight fontWeight;
  final FontStyle fontStyle;
  final TextDecoration decoration;

  const _StyleToggleChip({
    required this.label,
    required this.active,
    required this.colors,
    required this.onTap,
    this.fontWeight = FontWeight.w400,
    this.fontStyle = FontStyle.normal,
    this.decoration = TextDecoration.none,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44,
        height: 36,
        decoration: BoxDecoration(
          color: active ? colors.primaryContainer : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? colors.primary : colors.outlineVariant,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: fontWeight,
              fontStyle: fontStyle,
              decoration: decoration,
              color: active ? colors.onPrimaryContainer : colors.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  final Color currentColor;
  final List<Color> presets;
  final ColorScheme colors;
  final ValueChanged<Color> onChanged;

  const _ColorPicker({
    required this.currentColor,
    required this.presets,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimensions.sm,
      runSpacing: AppDimensions.sm,
      children: presets.map((c) {
        return ColorSwatch(
          color: c,
          isSelected: currentColor == c,
          onTap: () => onChanged(c),
          size: 34,
          iconSize: 14,
        );
      }).toList(),
    );
  }
}

class _TextPreview extends StatelessWidget {
  final LanguageTypography typography;
  final Color fallbackColor;

  const _TextPreview({
    required this.typography,
    required this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Text(
        'Evaṃ me sutaṃ… Thus have I heard…',
        style: typography.toTextStyle(fallbackColor: fallbackColor),
      ),
    );
  }
}

// ── Download tile (for not-yet-installed translations) ──────────────────────

class _TranslationDownloadTile extends StatelessWidget {
  final AvailableTranslation translation;
  final TranslationDownloadState downloadState;
  final ColorScheme colors;
  final VoidCallback onDownload;
  final VoidCallback? onCancel;

  const _TranslationDownloadTile({
    required this.translation,
    required this.downloadState,
    required this.colors,
    required this.onDownload,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = translation.isAvailable;
    final name = translation.englishName;
    final native = translation.nativeName;
    final hasUrl = TranslationDownloadNotifier.hasDownloadUrl(
      translation.languageCode,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            _statusIcon,
            color: _statusColor,
            size: 20,
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle(native),
                  style: AppTypography.labelSmall.copyWith(
                    color: _statusColor,
                  ),
                ),
                if (downloadState.status == DownloadStatus.downloading ||
                    downloadState.status == DownloadStatus.extracting)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: LinearProgressIndicator(
                      value: downloadState.status == DownloadStatus.extracting
                          ? null
                          : downloadState.progress,
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(2),
                      backgroundColor: colors.surfaceContainerHighest,
                    ),
                  ),
                if (downloadState.status == DownloadStatus.error &&
                    downloadState.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      downloadState.errorMessage!,
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.error,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (downloadState.status == DownloadStatus.completed)
            Icon(Icons.check_circle, color: Colors.green, size: 22)
          else if (downloadState.status == DownloadStatus.downloading ||
              downloadState.status == DownloadStatus.extracting)
            // Show stop button alongside progress indicator
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 6),
                if (onCancel != null)
                  _StopButton(onTap: onCancel!, colors: colors),
              ],
            )
          else if (!isAvailable && hasUrl)
            _DownloadButton(
              onTap: onDownload,
              colors: colors,
            ),
        ],
      ),
    );
  }

  IconData get _statusIcon {
    switch (downloadState.status) {
      case DownloadStatus.downloading:
      case DownloadStatus.extracting:
        return Icons.downloading;
      case DownloadStatus.completed:
        return Icons.check_circle;
      case DownloadStatus.cancelled:
        return Icons.cancel_outlined;
      case DownloadStatus.error:
        return Icons.error_outline;
      case DownloadStatus.idle:
        return translation.isAvailable
            ? Icons.check_circle
            : Icons.cloud_download;
    }
  }

  Color get _statusColor {
    switch (downloadState.status) {
      case DownloadStatus.downloading:
      case DownloadStatus.extracting:
        return colors.primary;
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.cancelled:
        return colors.onSurfaceVariant;
      case DownloadStatus.error:
        return colors.error;
      case DownloadStatus.idle:
        return translation.isAvailable ? Colors.green : colors.onSurfaceVariant;
    }
  }

  String _subtitle(String native) {
    switch (downloadState.status) {
      case DownloadStatus.downloading:
        return 'Downloading…';
      case DownloadStatus.extracting:
        return 'Installing…';
      case DownloadStatus.completed:
        return 'Installed · $native';
      case DownloadStatus.cancelled:
        return 'Cancelled';
      case DownloadStatus.error:
        return 'Download failed';
      case DownloadStatus.idle:
        return translation.isAvailable ? 'Installed · $native' : 'Not installed';
    }
  }
}

/// A small stop/cancel button.
class _StopButton extends StatelessWidget {
  final VoidCallback onTap;
  final ColorScheme colors;

  const _StopButton({
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9999),
          color: colors.error.withValues(alpha: 0.1),
          border: Border.all(
            color: colors.error.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.stop, size: 14, color: colors.error),
            const SizedBox(width: 2),
            Text(
              'Stop',
              style: AppTypography.labelSmall.copyWith(
                color: colors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small download button.
class _DownloadButton extends StatelessWidget {
  final VoidCallback onTap;
  final ColorScheme colors;

  const _DownloadButton({
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9999),
          color: colors.primary,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download, size: 14, color: colors.onPrimary),
            const SizedBox(width: 4),
            Text(
              'Download',
              style: AppTypography.labelSmall.copyWith(
                color: colors.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Display mode selector ────────────────────────────────────────────────────

/// Display mode selector with radio-style options.
class _ModeSelector extends StatelessWidget {
  final TranslationDisplayMode? currentMode;
  final bool showTranslation;
  final ValueChanged<TranslationDisplayMode> onSelectMode;
  final ValueChanged<bool> onToggleTranslation;
  final ColorScheme colors;

  const _ModeSelector({
    required this.currentMode,
    required this.showTranslation,
    required this.onSelectMode,
    required this.onToggleTranslation,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      _ModeOption(
        mode: null,
        icon: Icons.visibility_off,
        title: 'Hide Translation',
        subtitle: 'Show only Pāli text, joined as paragraphs',
        isSelected: !showTranslation,
      ),
      _ModeOption(
        mode: TranslationDisplayMode.lineByLine,
        icon: Icons.view_headline,
        title: 'Line by Line',
        subtitle: 'Show Pāli followed by its translation',
        isSelected: showTranslation && currentMode == TranslationDisplayMode.lineByLine,
      ),
      _ModeOption(
        mode: TranslationDisplayMode.sideBySide,
        icon: Icons.view_column,
        title: 'Side by Side',
        subtitle: 'Show Pāli and translation in two columns',
        isSelected: showTranslation && currentMode == TranslationDisplayMode.sideBySide,
      ),
    ];

    return Column(
      children: options.map((option) {
        return InkWell(
          onTap: () {
            if (option.mode == null) {
              onToggleTranslation(false);
            } else {
              onSelectMode(option.mode!);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.md,
              vertical: AppDimensions.sm,
            ),
            child: Row(
              children: [
                Icon(
                  option.isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: option.isSelected
                      ? colors.primary
                      : colors.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: AppDimensions.md),
                Icon(option.icon, color: colors.primary, size: 20),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.title,
                        style: AppTypography.labelMedium.copyWith(
                          color: option.isSelected
                              ? colors.primary
                              : colors.onSurface,
                          fontWeight:
                              option.isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      Text(
                        option.subtitle,
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
        );
      }).toList(),
    );
  }
}

class _ModeOption {
  final TranslationDisplayMode? mode;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;

  const _ModeOption({
    required this.mode,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
  });
}
