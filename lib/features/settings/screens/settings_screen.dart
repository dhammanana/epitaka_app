import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/app_localizations.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/providers/translation_manifest_provider.dart';
import '../../../core/utils/pali_script_converter.dart';
import '../../gavesana/providers/gavesana_download_provider.dart';
import '../../search/providers/search_provider.dart';
import '../../ai_qa/widgets/ai_qa_settings_sheet.dart';

import '../widgets/index_progress_screen.dart';
import '../widgets/tiles/reset_data_tile.dart';
import '../widgets/settings_app_bar.dart';
import '../widgets/settings_section.dart';

/// Main settings screen with grouped sections.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          // Screen title
          Text(
            loc.settings,
            style: AppTypography.headlineLarge.copyWith(
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: AppDimensions.lg),

          // Sections
          SettingsSection(
            title: loc.general,
            colors: colors,
            showDividers: true,
            children: [
              _LanguagePickerTile(colors: colors),
              _ScriptPickerTile(),
              _LibraryExpandTile(colors: colors),
            ],
          ),

          const SizedBox(height: AppDimensions.md),

          SettingsSection(
            title: loc.appearance,
            colors: colors,
            showDividers: true,
            children: [
              _ThemePickerTile(),
              _SettingsTile(
                icon: Icons.palette,
                title: loc.appearance,
                subtitle: loc.appearanceSubtitle,
                onTap: () => context.push('/settings/appearance'),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.md),

          SettingsSection(
            title: loc.dataAndContent,
            colors: colors,
            showDividers: true,
            children: [
              _SettingsTile(
                icon: Icons.download,
                title: loc.translationsDownloads,
                onTap: () => context.push('/settings/translation'),
              ),
              _SettingsTile(
                icon: Icons.translate,
                title: loc.translationDisplay,
                subtitle: loc.translationDisplaySubtitle,
                onTap: () => context.push('/settings/translation'),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.md),

          SettingsSection(
            title: loc.readingPreferences,
            colors: colors,
            showDividers: true,
            children: [
              _SettingsTile(
                icon: Icons.menu_book,
                title: loc.readingOptions,
                subtitle: loc.readingOptionsSubtitle,
                onTap: () => context.push('/settings/reading'),
              ),
              _SettingsTile(
                icon: Icons.record_voice_over,
                title: loc.textToSpeech,
                subtitle: loc.ttsSubtitle,
                onTap: () => context.push('/settings/tts'),
              ),
              _SettingsTile(
                icon: Icons.find_replace,
                title: loc.ttsReplacements,
                subtitle: loc.ttsReplacementsSubtitle,
                onTap: () => context.push('/settings/tts/replacements'),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.md),

          // ── Search ──────────────────────────────────────────────────
          SettingsSection(
            title: loc.search,
            colors: colors,
            showDividers: true,
            children: [
              _SearchExpandToggle(colors: colors),
              _RebuildIndexTile(colors: colors),
            ],
          ),

          const SizedBox(height: AppDimensions.md),

          // ── Dictionaries ────────────────────────────────────────────
          SettingsSection(
            title: loc.dictionaries,
            colors: colors,
            children: [
              _SettingsTile(
                icon: Icons.menu_book,
                title: loc.dictionarySettings,
                subtitle: loc.dictionarySettingsSubtitle,
                onTap: () => context.push('/settings/dictionary'),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.md),

          // ── AI Q&A ──────────────────────────────────────────────────
          _buildAiQaSection(context, colors),

          const SizedBox(height: AppDimensions.md),

          // ── Gavesana ───────────────────────────────────────────────
          _buildGavesanaSection(context, colors, ref),

          const SizedBox(height: AppDimensions.md),

          SettingsSection(
            title: loc.account,
            colors: colors,
            showDividers: true,
            children: [
              _SettingsTile(
                icon: Icons.account_circle,
                title: loc.profile,
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.md),

          SettingsSection(
            title: loc.system,
            colors: colors,
            showDividers: true,
            children: [
              _SettingsTile(
                icon: Icons.help_outline,
                title: loc.help,
                subtitle: loc.keyboardShortcuts,
                onTap: () => context.push('/settings/help'),
              ),
              ResetDataTile(),
              _SettingsTile(icon: Icons.info, title: loc.about, onTap: () {}),
            ],
          ),
        ],
      ),
    );
  }

  /// AI Q&A settings section.
  Widget _buildAiQaSection(BuildContext context, ColorScheme colors) {
    return SettingsSection(
      title: 'AI Q&A',
      colors: colors,
      children: [
        _SettingsTile(
          icon: Icons.question_answer,
          title: 'AI Q&A Settings',
          subtitle: 'API key, models, etc.',
          onTap: () => showAiQaSettingsSheet(context),
        ),
      ],
    );
  }

  /// Gavesana AI-powered search settings section.
  Widget _buildGavesanaSection(
    BuildContext context,
    ColorScheme colors,
    WidgetRef ref,
  ) {
    final loc = AppLocalizations.of(context);
    return SettingsSection(
      title: loc.aiSearch,
      colors: colors,
      children: [_GavesanaDownloadTile(colors: colors)],
    );
  }
}

/// Only English and Vietnamese for now.
const _supportedLanguages = [AppLanguage.english, AppLanguage.vietnamese];

/// ── Language Picker Tile ──────────────────────────────────────────────

class _LanguagePickerTile extends ConsumerWidget {
  final ColorScheme colors;

  const _LanguagePickerTile({required this.colors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final loc = AppLocalizations.of(context);
    final currentLang = settings.appLanguage;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.md,
      ),
      child: Row(
        children: [
          Icon(Icons.language, color: colors.primary),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Text(
              loc.language,
              style: AppTypography.labelMedium.copyWith(
                color: colors.onSurface,
              ),
            ),
          ),
          PopupMenuButton<AppLanguage>(
            initialValue: currentLang,
            onSelected: (lang) {
              ref.read(settingsProvider.notifier).setAppLanguage(lang);
            },
            itemBuilder: (context) => [
              for (final lang in _supportedLanguages)
                PopupMenuItem(
                  value: lang,
                  child: Text(loc.appLanguageName(lang)),
                ),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  loc.appLanguageName(currentLang),
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

/// Tile showing Gavesana download status and action.
class _GavesanaDownloadTile extends ConsumerStatefulWidget {
  final ColorScheme colors;

  const _GavesanaDownloadTile({required this.colors});

  @override
  ConsumerState<_GavesanaDownloadTile> createState() =>
      _GavesanaDownloadTileState();
}

class _GavesanaDownloadTileState extends ConsumerState<_GavesanaDownloadTile> {
  bool _isDownloading = false;

  @override
  Widget build(BuildContext context) {
    final assetsAsync = ref.watch(gavesanaAssetsReadyProvider);
    final loc = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.md,
      ),
      child: InkWell(
        onTap: _isDownloading ? null : _handleAction,
        child: Row(
          children: [
            Icon(Icons.psychology, color: widget.colors.primary),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.aiSearchAssets,
                    style: AppTypography.labelMedium.copyWith(
                      color: widget.colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  assetsAsync.when(
                    data: (ready) => Text(
                      ready
                          ? '${loc.readyLabel} (${_sizeLabel(270 + 364 + 33)} MB)'
                          : loc.notDownloaded,
                      style: AppTypography.labelSmall.copyWith(
                        color: ready
                            ? widget.colors.tertiary
                            : widget.colors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                    loading: () => const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (_, __) => Text(loc.error),
                  ),
                ],
              ),
            ),
            if (_isDownloading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              assetsAsync.when(
                data: (ready) => Icon(
                  ready
                      ? Icons.check_circle_outline
                      : Icons.cloud_download_outlined,
                  size: 20,
                  color: ready ? widget.colors.tertiary : widget.colors.primary,
                ),
                loading: () => const SizedBox(width: 20),
                error: (_, __) => const Icon(Icons.error_outline, size: 20),
              ),
          ],
        ),
      ),
    );
  }

  String _sizeLabel(int mb) {
    if (mb >= 1000) return '${(mb / 1000).toStringAsFixed(1)} GB';
    return mb.toString();
  }

  Future<void> _handleAction() async {
    final loc = AppLocalizations.of(context);
    final assetsReady = await ref.read(gavesanaAssetsReadyProvider.future);
    if (assetsReady) {
      // Show info about the assets
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(loc.gavesanaAssetsTitle),
          content: Text(loc.gavesanaAssetsReadyDesc),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(loc.ok),
            ),
          ],
        ),
      );
      return;
    }

    // Start download
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.downloadGavesanaTitle),
        content: Text(loc.downloadGavesanaDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(loc.download),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isDownloading = true);
    try {
      final manifest = await ref.read(translationManifestProvider.future);
      final url = manifest.embeddingsUrl;
      if (url == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No download URL available for AI search assets'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        setState(() => _isDownloading = false);
        return;
      }
      final service = ref.read(gavesanaDownloadServiceProvider);
      final success = await service.downloadAssets(url: url);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.download} failed: ${service.error}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      if (mounted) {
        ref.invalidate(gavesanaAssetsReadyProvider);
        setState(() => _isDownloading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.error}: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md,
          vertical: AppDimensions.md,
        ),
        child: Row(
          children: [
            Icon(icon, color: colors.primary),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Text(
                title,
                style: AppTypography.labelMedium.copyWith(
                  color: colors.onSurface,
                ),
              ),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  subtitle!,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Script picker tile with popup menu selection.
class _ScriptPickerTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final colors = Theme.of(context).colorScheme;
    final currentScript = settings.paliScript;
    final loc = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.md,
      ),
      child: Row(
        children: [
          Icon(Icons.translate, color: colors.primary),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Text(
              loc.script,
              style: AppTypography.labelMedium.copyWith(
                color: colors.onSurface,
              ),
            ),
          ),
          PopupMenuButton<Script>(
            initialValue: currentScript,
            onSelected: (script) {
              ref.read(settingsProvider.notifier).setPaliScript(script);
            },
            itemBuilder: (context) => [
              for (final info in listOfScripts)
                PopupMenuItem(
                  value: info.script,
                  child: Text(_scriptLabel(info)),
                ),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentScriptLabel(currentScript),
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

  String _scriptLabel(ScriptInfo info) {
    return '${info.nameInLocale} (${info.script.name})';
  }

  String _currentScriptLabel(Script script) {
    for (final info in listOfScripts) {
      if (info.script == script) return info.nameInLocale;
    }
    return script.name;
  }
}

/// Library expand level tile with popup menu selection.
class _LibraryExpandTile extends ConsumerWidget {
  final ColorScheme colors;

  const _LibraryExpandTile({required this.colors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final current = settings.libraryExpandLevel;
    final loc = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.md,
      ),
      child: Row(
        children: [
          Icon(Icons.unfold_more, color: colors.primary),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.libraryBrowser,
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  loc.defaultExpandLevel,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<LibraryExpandLevel>(
            initialValue: current,
            onSelected: (level) {
              ref.read(settingsProvider.notifier).setLibraryExpandLevel(level);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: LibraryExpandLevel.collapsed,
                child: Row(
                  children: [
                    Icon(
                      Icons.unfold_less,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(loc.collapsed),
                  ],
                ),
              ),
              PopupMenuItem(
                value: LibraryExpandLevel.category,
                child: Row(
                  children: [
                    Icon(Icons.unfold_more, size: 18, color: colors.primary),
                    const SizedBox(width: 8),
                    Text(loc.category),
                  ],
                ),
              ),
              PopupMenuItem(
                value: LibraryExpandLevel.expand,
                child: Row(
                  children: [
                    Icon(
                      Icons.unfold_more_double,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(loc.expand),
                  ],
                ),
              ),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _expandLabel(current, loc),
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

  String _expandLabel(LibraryExpandLevel level, AppLocalizations loc) {
    switch (level) {
      case LibraryExpandLevel.collapsed:
        return loc.collapsed;
      case LibraryExpandLevel.category:
        return loc.category;
      case LibraryExpandLevel.expand:
        return loc.expand;
    }
  }
}

/// Theme picker tile with radio-style selection.
class _ThemePickerTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.md,
            vertical: AppDimensions.md,
          ),
          child: Row(
            children: [
              Icon(Icons.palette, color: colors.primary),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Text(
                  loc.theme,
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ),
              PopupMenuButton<ThemePreference>(
                initialValue: settings.themePreference,
                onSelected: (pref) {
                  ref.read(settingsProvider.notifier).setThemePreference(pref);
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: ThemePreference.system,
                    child: Text(_themeLabel(ThemePreference.system, loc)),
                  ),
                  PopupMenuItem(
                    value: ThemePreference.light,
                    child: Text(_themeLabel(ThemePreference.light, loc)),
                  ),
                  PopupMenuItem(
                    value: ThemePreference.dark,
                    child: Text(_themeLabel(ThemePreference.dark, loc)),
                  ),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _themeLabel(settings.themePreference, loc),
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
        ),
      ],
    );
  }

  String _themeLabel(ThemePreference pref, AppLocalizations loc) {
    switch (pref) {
      case ThemePreference.system:
        return loc.systemTheme;
      case ThemePreference.light:
        return loc.lightTheme;
      case ThemePreference.dark:
        return loc.darkTheme;
    }
  }
}

/// Toggle for expanding/collapsing search result groups by default.
class _SearchExpandToggle extends ConsumerWidget {
  final ColorScheme colors;

  const _SearchExpandToggle({required this.colors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expand = ref.watch(expandSearchResultsProvider);
    final loc = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.md,
      ),
      child: Row(
        children: [
          Icon(Icons.unfold_more, color: colors.primary),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Text(
              loc.expandResultsDefault,
              style: AppTypography.labelMedium.copyWith(
                color: colors.onSurface,
              ),
            ),
          ),
          Switch(
            value: expand,
            activeTrackColor: colors.primary,
            onChanged: (val) =>
                ref.read(expandSearchResultsProvider.notifier).state = val,
          ),
        ],
      ),
    );
  }
}

/// Button to rebuild the search index, with confirmation dialog.
/// Does NOT auto-trigger the rebuild on mount.
class _RebuildIndexTile extends ConsumerStatefulWidget {
  final ColorScheme colors;

  const _RebuildIndexTile({required this.colors});

  @override
  ConsumerState<_RebuildIndexTile> createState() => _RebuildIndexTileState();
}

class _RebuildIndexTileState extends ConsumerState<_RebuildIndexTile> {
  bool _isRebuilding = false;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.md,
      ),
      child: Row(
        children: [
          Icon(Icons.refresh, color: widget.colors.primary),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => _confirmRebuild(context),
                  child: Text(
                    loc.rebuildSearchIndex,
                    style: AppTypography.labelMedium.copyWith(
                      color: widget.colors.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  loc.rebuildSearchIndexSubtitle,
                  style: AppTypography.labelSmall.copyWith(
                    color: widget.colors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (_isRebuilding)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              icon: const Icon(Icons.play_arrow, size: 20),
              color: widget.colors.primary,
              onPressed: () => _confirmRebuild(context),
              tooltip: loc.rebuildSearchIndex,
            ),
        ],
      ),
    );
  }

  void _confirmRebuild(BuildContext context) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.rebuildSearchIndex),
        content: const Text(
          'This will delete and rebuild the full-text search index from scratch. '
          'It may take a few seconds on slower devices. '
          'You can continue using the app while indexing runs in the background.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _triggerRebuild();
            },
            child: Text(loc.rebuildSearchIndex),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerRebuild() async {
    setState(() => _isRebuilding = true);
    await IndexProgressScreen.show(context, resetFirst: false);
    if (mounted) setState(() => _isRebuilding = false);
  }
}
