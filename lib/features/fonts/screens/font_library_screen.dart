import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart' show settingsProvider;
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/pali_script_converter.dart' show Script;
import '../../../core/utils/pali_text_utils.dart' show convertPaliToScript;
import '../models/downloadable_font.dart';
import '../providers/font_library_provider.dart';
import '../services/font_library_service.dart';

/// Browse, download and pick Google Fonts for Pāli reading.
///
/// Selection is one tap: tapping a font that is already on the device makes
/// it the Pāli reading font for every script it covers, and downloading a
/// font selects it straight away. "Use built-in fonts" clears the choice.
class FontLibraryScreen extends ConsumerStatefulWidget {
  const FontLibraryScreen({super.key});

  @override
  ConsumerState<FontLibraryScreen> createState() => _FontLibraryScreenState();
}

class _FontLibraryScreenState extends ConsumerState<FontLibraryScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<DownloadableFont> _visible(FontLibraryState state) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return state.catalog;
    return state.catalog.where((font) {
      return font.name.toLowerCase().contains(q) ||
          font.category.contains(q) ||
          font.scriptLabels.toLowerCase().contains(q) ||
          font.license.toLowerCase().contains(q);
    }).toList();
  }

  /// Preview line in the font's own script, so the list reads like the
  /// reader will.
  String _sample(DownloadableFont font) {
    final script = font.scripts.isEmpty ? Script.roman : font.scripts.first;
    return convertPaliToScript('dhammaṃ bhagavā', script);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final state = ref.watch(fontLibraryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(loc.fontLibrary)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.md,
              AppDimensions.sm,
              AppDimensions.md,
              0,
            ),
            child: Text(
              loc.fontLibraryDesc,
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: loc.searchFonts,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: loc.clear,
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                isDense: true,
              ),
            ),
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.md,
                0,
                AppDimensions.md,
                AppDimensions.sm,
              ),
              child: Text(
                loc.errorMessage(state.error!),
                style: AppTypography.labelSmall.copyWith(color: colors.error),
              ),
            ),
          Expanded(
            child: state.loading
                ? const Center(child: CircularProgressIndicator())
                : _buildList(state, loc, colors),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    FontLibraryState state,
    AppLocalizations loc,
    ColorScheme colors,
  ) {
    final fonts = _visible(state);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        0,
        AppDimensions.md,
        AppDimensions.lg,
      ),
      children: [
        if (state.selectedId != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.sm),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.settings_backup_restore, size: 18),
              label: Text(loc.useBuiltInFonts),
              onPressed: () async {
                await ref.read(fontLibraryProvider.notifier).select(null);
                ref.read(settingsProvider.notifier).refresh();
              },
            ),
          ),
        if (fonts.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.lg),
            child: Center(
              child: Text(
                loc.noFontsFound,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        for (final font in fonts)
          _FontCard(
            font: font,
            sample: _sample(font),
            state: state,
            onDownload: () => _download(font),
            onSelect: () => _select(font),
            onRemove: () => _remove(font),
          ),
      ],
    );
  }

  Future<void> _download(DownloadableFont font) async {
    final loc = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(fontLibraryProvider.notifier).download(font);
    // The family is resolved at build time by the reader, so nudge the
    // widgets that watch settings to rebuild with the new font.
    ref.read(settingsProvider.notifier).refresh();
    final error = ref.read(fontLibraryProvider).error;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          error == null
              ? loc.fontDownloaded(font.name)
              : loc.errorMessage(error),
        ),
      ),
    );
  }

  Future<void> _select(DownloadableFont font) async {
    await ref.read(fontLibraryProvider.notifier).select(font);
    ref.read(settingsProvider.notifier).refresh();
  }

  Future<void> _remove(DownloadableFont font) async {
    final loc = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.fontRemoveTitle),
        content: Text(loc.fontRemoveMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(loc.remove),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(fontLibraryProvider.notifier).remove(font);
    ref.read(settingsProvider.notifier).refresh();
  }
}

/// One catalog font: name, a preview line in its own script, coverage chips
/// and the download / select / remove actions.
class _FontCard extends StatelessWidget {
  final DownloadableFont font;
  final String sample;
  final FontLibraryState state;
  final VoidCallback onDownload;
  final VoidCallback onSelect;
  final VoidCallback onRemove;

  const _FontCard({
    required this.font,
    required this.sample,
    required this.state,
    required this.onDownload,
    required this.onSelect,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final installed = state.isInstalled(font.id);
    final selected = state.isSelected(font.id);
    final downloading = state.isDownloading(font.id);
    final progress = state.progress[font.id] ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        onTap: installed && !downloading ? onSelect : null,
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            color: selected
                ? colors.primaryContainer.withValues(alpha: 0.35)
                : colors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            font.name,
                            style: AppTypography.labelMedium.copyWith(
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                        if (selected) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.check_circle, size: 16, color: colors.primary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sample,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        // Not downloaded yet: the preview falls back to the
                        // default family so the row still shows the text.
                        fontFamily: installed
                            ? FontLibraryService.familyFor(font.id)
                            : null,
                        fontSize: 18,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (selected) _Chip(text: loc.fontInUse, colors: colors, highlight: true),
                        _Chip(text: font.category, colors: colors),
                        _Chip(text: font.scriptLabels, colors: colors),
                        _Chip(text: font.license, colors: colors),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              if (downloading)
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        value: progress > 0 ? progress : null,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                )
              else if (installed)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: loc.remove,
                  color: colors.onSurfaceVariant,
                  onPressed: onRemove,
                )
              else
                IconButton(
                  icon: const Icon(Icons.download_for_offline_outlined, size: 22),
                  tooltip: loc.download,
                  color: colors.primary,
                  onPressed: onDownload,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final ColorScheme colors;
  final bool highlight;

  const _Chip({required this.text, required this.colors, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: highlight
            ? colors.primary.withValues(alpha: 0.16)
            : colors.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: AppTypography.labelSmall.copyWith(
          fontSize: 10,
          color: highlight ? colors.primary : colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
