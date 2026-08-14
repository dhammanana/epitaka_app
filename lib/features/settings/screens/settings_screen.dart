import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/app_localizations.dart';
import '../../annotations/widgets/account_sync_tile.dart';
import '../../../core/utils/l10n/app_strings.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/pali_script_converter.dart';
import '../../../router/app_router.dart' show AppRoutes;
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
          const SettingsGeneralSection(),

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
              _SettingsTile(
                icon: Icons.touch_app,
                title: loc.contextMenu,
                subtitle: loc.contextMenuSubtitle,
                onTap: () => context.push('/settings/context-menu'),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.md),

          // ── Search ──────────────────────────────────────────────────
          const SettingsSearchSection(),

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

          // ── AI Q&A + Gavesana ───────────────────────────────────────
          const SettingsAiSection(),

          const SizedBox(height: AppDimensions.md),

          const SettingsAccountSection(),

          const SizedBox(height: AppDimensions.md),

          const SettingsSystemSection(),
        ],
      ),
    );
  }

}

/// General settings section: language, script, library expand, script
/// converter. Shared between the mobile settings screen and the desktop
/// settings window.
class SettingsGeneralSection extends ConsumerWidget {
  const SettingsGeneralSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    return SettingsSection(
      title: loc.general,
      colors: colors,
      showDividers: true,
      children: [
        _LanguagePickerTile(colors: colors),
        _ScriptPickerTile(),
        _LibraryExpandTile(colors: colors),
        // Script Converter — reachable on desktop too (no drawer there;
        // the settings dialog embeds this section).
        _SettingsTile(
          icon: Icons.swap_horiz,
          title: loc.scriptConverter,
          subtitle: loc.scriptConverterSubtitle,
          onTap: () => context.push(AppRoutes.scriptConverter),
        ),
      ],
    );
  }
}

/// Search settings section: default result expansion + index rebuild.
class SettingsSearchSection extends ConsumerWidget {
  const SettingsSearchSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    return SettingsSection(
      title: loc.search,
      colors: colors,
      showDividers: true,
      children: [
        _SearchExpandToggle(colors: colors),
        _RebuildIndexTile(colors: colors),
      ],
    );
  }
}

/// AI Q&A + Gavesana AI-powered search settings section.
///
/// Gavesana runs on the cloud AI (same settings as Vimaṃsa), so both link
/// to the shared AI settings sheet — no on-device asset downloads anymore.
class SettingsAiSection extends ConsumerWidget {
  const SettingsAiSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    return Column(
      children: [
        SettingsSection(
          title: loc.aiQa,
          colors: colors,
          children: [
            _SettingsTile(
              icon: Icons.question_answer,
              title: loc.aiQaSettings,
              subtitle: loc.aiQaSettingsSubtitle,
              onTap: () => showAiQaSettingsSheet(context),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.md),
        SettingsSection(
          title: loc.aiSearch,
          colors: colors,
          children: [
            _SettingsTile(
              icon: Icons.auto_awesome,
              title: loc.gavesanaAiSearch,
              subtitle: loc.aiQaSettingsSubtitle,
              onTap: () => showAiQaSettingsSheet(context),
            ),
          ],
        ),
      ],
    );
  }
}

/// Account section: cloud sync (Google account + annotation sync status).
class SettingsAccountSection extends StatelessWidget {
  const SettingsAccountSection({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    return SettingsSection(
      title: loc.account,
      colors: colors,
      showDividers: true,
      children: [
        // Cloud sync: Google account + annotation sync status.
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: AccountSyncTile(),
        ),
      ],
    );
  }
}

/// System section: feature guide, help, reset data, about.
class SettingsSystemSection extends StatelessWidget {
  const SettingsSystemSection({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    return SettingsSection(
      title: loc.system,
      colors: colors,
      showDividers: true,
      children: [
        _SettingsTile(
          icon: Icons.explore_outlined,
          title: loc.featureGuide,
          subtitle: loc.featureGuideSubtitle,
          onTap: () => context.push(AppRoutes.featureGuide),
        ),
        _SettingsTile(
          icon: Icons.help_outline,
          title: loc.help,
          subtitle: loc.keyboardShortcuts,
          onTap: () => context.push('/settings/help'),
        ),
        ResetDataTile(),
        _SettingsTile(icon: Icons.info, title: loc.about, onTap: () {}),
      ],
    );
  }
}

/// Languages shown in the picker — derived from the registry
/// (`AppStrings.supportedCodes`), so adding a language file to
/// `core/utils/l10n/` automatically adds it to this menu.
final List<AppLanguage> _supportedLanguages = [
  for (final code in AppStrings.supportedCodes)
    AppLanguage.values.firstWhere(
      (l) => l.code == code,
      orElse: () => AppLanguage.english,
    ),
];

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
    final titleStyle = AppTypography.labelMedium.copyWith(
      color: colors.onSurface,
    );
    final subtitleStyle = AppTypography.labelSmall.copyWith(
      color: colors.onSurfaceVariant,
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md,
          vertical: AppDimensions.md,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The trailing subtitle is a short hint; when it is long (e.g. a
            // verbose translation on a narrow phone) the unconstrained Text
            // squeezes the title's Expanded slot to nothing, which looks
            // broken. Strip the subtitle unless the title and subtitle both
            // fit beside the icon and chevron.
            final showSubtitle = subtitle != null &&
                _titleAndSubtitleFit(
                  constraints.maxWidth,
                  title,
                  titleStyle,
                  subtitle!,
                  subtitleStyle,
                  Directionality.of(context),
                  MediaQuery.textScalerOf(context),
                );
            return Row(
              children: [
                Icon(icon, color: colors.primary),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  child: Text(title, style: titleStyle),
                ),
                if (showSubtitle)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      subtitle!,
                      style: subtitleStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Whether [title] and [subtitle] fit side-by-side with the icon and
  /// chevron. Fixed-width items in the row: icon (24), gap after it (md),
  /// a small gap before the subtitle (8), the subtitle's right padding (8),
  /// and the chevron (24). When they don't fit, the subtitle is stripped so
  /// the title always keeps the full row.
  bool _titleAndSubtitleFit(
    double available,
    String title,
    TextStyle titleStyle,
    String subtitle,
    TextStyle subtitleStyle,
    TextDirection direction,
    TextScaler textScaler,
  ) {
    const fixed = 24.0 + AppDimensions.md + 8.0 + 8.0 + 24.0;
    return _textWidth(title, titleStyle, direction, textScaler) +
            _textWidth(subtitle, subtitleStyle, direction, textScaler) +
            fixed <=
        available;
  }

  double _textWidth(
    String text,
    TextStyle style,
    TextDirection direction,
    TextScaler textScaler,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: direction,
      textScaler: textScaler,
    )..layout();
    return painter.width;
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
                  for (final pref in ThemePreference.displayOrder)
                    PopupMenuItem(
                      value: pref,
                      child: Text(_themeLabel(pref, loc)),
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

  String _themeLabel(ThemePreference pref, AppLocalizations loc) =>
      loc.themeName(pref);
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
        content: Text(loc.rebuildIndexConfirmDesc),
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
