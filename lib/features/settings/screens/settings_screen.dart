import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/pali_script_converter.dart';
import '../../gavesana/providers/gavesana_download_provider.dart';
import '../../gavesana/services/download_service.dart';
import '../../search/providers/search_provider.dart';

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
            'Settings',
            style: AppTypography.headlineLarge.copyWith(
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: AppDimensions.lg),

          // Sections
          SettingsSection(
            title: 'General',
            colors: colors,
            showDividers: true,
            children: [
              _SettingsTile(
                icon: Icons.language,
                title: 'Language',
                subtitle: 'English',
                onTap: () {},
              ),
              _ScriptPickerTile(),
              _LibraryExpandTile(colors: colors),
            ],
          ),

          const SizedBox(height: AppDimensions.md),

          SettingsSection(
            title: 'Appearance',
            colors: colors,
            showDividers: true,
            children: [
              _ThemePickerTile(),
              _SettingsTile(
                icon: Icons.palette,
                title: 'Appearance',
                subtitle: 'Theme & accent',
                onTap: () => context.push('/settings/appearance'),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.md),

          SettingsSection(
            title: 'Data & Content',
            colors: colors,
            showDividers: true,
            children: [
              _SettingsTile(
                icon: Icons.download,
                title: 'Translations & Downloads',
                onTap: () => context.push('/settings/translation'),
              ),
              _SettingsTile(
                icon: Icons.translate,
                title: 'Translation Display',
                subtitle: 'Layout, mode & typography',
                onTap: () => context.push('/settings/translation'),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.md),

          SettingsSection(
            title: 'Reading Preferences',
            colors: colors,
            showDividers: true,
            children: [
              _SettingsTile(
                icon: Icons.menu_book,
                title: 'Reading Options',
                subtitle: 'Layout, numbering & scroll',
                onTap: () => context.push('/settings/reading'),
              ),
              _SettingsTile(
                icon: Icons.record_voice_over,
                title: 'Text-to-Speech',
                subtitle: 'Voice & speed',
                onTap: () => context.push('/settings/tts'),
              ),
              _SettingsTile(
                icon: Icons.find_replace,
                title: 'TTS Replacements',
                subtitle: 'Regex text replacements',
                onTap: () => context.push('/settings/tts/replacements'),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.md),

          // ── Search ──────────────────────────────────────────────────
          SettingsSection(
            title: 'Search',
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
            title: 'Dictionaries',
            colors: colors,
            children: [
              _SettingsTile(
                icon: Icons.menu_book,
                title: 'Dictionary Settings',
                subtitle: 'Enable, disable & reorder',
                onTap: () => context.push('/settings/dictionary'),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.md),

          // ── Gavesana ───────────────────────────────────────────────
          _buildGavesanaSection(colors, ref),

          const SizedBox(height: AppDimensions.md),

          SettingsSection(
            title: 'Account',
            colors: colors,
            showDividers: true,
            children: [
              _SettingsTile(
                icon: Icons.account_circle,
                title: 'Profile',
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.md),

          SettingsSection(
            title: 'System',
            colors: colors,
            showDividers: true,
            children: [
              ResetDataTile(),
              _SettingsTile(
                icon: Icons.info,
                title: 'About ePitaka',
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Gavesana AI-powered search settings section.
  Widget _buildGavesanaSection(ColorScheme colors, WidgetRef ref) {
    return SettingsSection(
      title: 'Gavesana (AI Search)',
      colors: colors,
      children: [
        _GavesanaDownloadTile(colors: colors),
      ],
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

class _GavesanaDownloadTileState
    extends ConsumerState<_GavesanaDownloadTile> {
  bool _isDownloading = false;

  @override
  Widget build(BuildContext context) {
    final assetsAsync = ref.watch(gavesanaAssetsReadyProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.md,
      ),
      child: InkWell(
        onTap: _isDownloading ? null : _handleAction,
        child: Row(
          children: [
            Icon(
              Icons.psychology,
              color: widget.colors.primary,
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Search Assets',
                    style: AppTypography.labelMedium.copyWith(
                      color: widget.colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  assetsAsync.when(
                    data: (ready) => Text(
                      ready
                          ? 'Ready (${_sizeLabel(270 + 364 + 33)} MB)'
                          : 'Not downloaded — tap to download',
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
                    error: (_, __) => const Text('Check failed'),
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
                  color: ready
                      ? widget.colors.tertiary
                      : widget.colors.primary,
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
    final assetsReady =
        await ref.read(gavesanaAssetsReadyProvider.future);
    if (assetsReady) {
      // Show info about the assets
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Gavesana AI Assets'),
          content: const Text(
            'The AI search model and vector database are ready to use.\n\n'
            'Open the sidebar in the Library screen and tap the '
            'Gavesana icon to start searching semantically.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
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
        title: const Text('Download Gavesana Assets?'),
        content: const Text(
          'This will download approximately 670 MB of data:\n'
          '- AI model (270 MB)\n'
          '- Vector database (364 MB)\n'
          '- Tokenizer config (33 MB)\n\n'
          'A Wi-Fi connection is recommended.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Download'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isDownloading = true);
    try {
      final service = ref.read(gavesanaDownloadServiceProvider);
      final success = await service.downloadAssets();
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${service.error}'),
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
            content: Text('Error: $e'),
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
            Icon(
              Icons.chevron_right,
              color: colors.onSurfaceVariant,
            ),
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
              'Script',
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
                Icon(
                  Icons.chevron_right,
                  color: colors.onSurfaceVariant,
                ),
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
                  'Library Browser',
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Default expand level',
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
                    Icon(Icons.unfold_less, size: 18, color: colors.onSurfaceVariant),
                    const SizedBox(width: 8),
                    const Text('Collapsed'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: LibraryExpandLevel.category,
                child: Row(
                  children: [
                    Icon(Icons.unfold_more, size: 18, color: colors.primary),
                    const SizedBox(width: 8),
                    const Text('Category'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: LibraryExpandLevel.expand,
                child: Row(
                  children: [
                    Icon(Icons.unfold_more_double, size: 18, color: colors.onSurfaceVariant),
                    const SizedBox(width: 8),
                    const Text('Expand'),
                  ],
                ),
              ),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _expandLabel(current),
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _expandLabel(LibraryExpandLevel level) {
    switch (level) {
      case LibraryExpandLevel.collapsed:
        return 'Collapsed';
      case LibraryExpandLevel.category:
        return 'Category';
      case LibraryExpandLevel.expand:
        return 'Expand';
    }
  }
}

/// Theme picker tile with radio-style selection.
class _ThemePickerTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final colors = Theme.of(context).colorScheme;

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
                  'Theme',
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
                    child: Text(_themeLabel(ThemePreference.system)),
                  ),
                  PopupMenuItem(
                    value: ThemePreference.light,
                    child: Text(_themeLabel(ThemePreference.light)),
                  ),
                  PopupMenuItem(
                    value: ThemePreference.dark,
                    child: Text(_themeLabel(ThemePreference.dark)),
                  ),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _themeLabel(settings.themePreference),
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _themeLabel(ThemePreference pref) {
    switch (pref) {
      case ThemePreference.system:
        return 'System';
      case ThemePreference.light:
        return 'Paper (Light)';
      case ThemePreference.dark:
        return 'Dark';
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
              'Expand results by default',
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
                    'Rebuild search index',
                    style: AppTypography.labelMedium.copyWith(
                      color: widget.colors.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Re-indexes Pāli texts & translations',
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
              tooltip: 'Rebuild',
            ),
        ],
      ),
    );
  }

  void _confirmRebuild(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rebuild Search Index?'),
        content: const Text(
          'This will delete and rebuild the full-text search index from scratch. '
          'It may take a few seconds on slower devices. '
          'You can continue using the app while indexing runs in the background.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _triggerRebuild();
            },
            child: const Text('Rebuild'),
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
