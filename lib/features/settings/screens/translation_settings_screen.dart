import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/translation_version.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/translation_manifest_provider.dart';
import '../../../core/providers/translation_registry_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../providers/translation_download_provider.dart';
import '../widgets/color_picker_section.dart';
import '../widgets/settings_app_bar.dart';
import '../widgets/settings_section.dart';

/// Translation & Downloads screen: version management, download, delete, and
/// typography settings for each translation language.
class TranslationSettingsScreen extends ConsumerStatefulWidget {
  const TranslationSettingsScreen({super.key});

  @override
  ConsumerState<TranslationSettingsScreen> createState() =>
      _TranslationSettingsScreenState();
}

class _TranslationSettingsScreenState
    extends ConsumerState<TranslationSettingsScreen> {
  bool _manifestLoading = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final mergedVersionsAsync = ref.watch(mergedTranslationVersionsProvider);
    final localVersionsAsync = ref.watch(localTranslationVersionsProvider);
    final downloadStates = ref.watch(translationDownloadProvider);

    // Only translations that are actually downloaded (DB present locally)
    // can be reordered — a language merely offered by the manifest but not
    // yet downloaded should not appear in the order list.
    final downloadedCodes = localVersionsAsync.maybeWhen(
      data: (versions) => versions.map((v) => v.languageCode).toSet(),
      orElse: () => <String>{},
    );
    final reorderableCodes = settings.enabledTranslations
        .where((code) => downloadedCodes.contains(code))
        .toList();

    return Scaffold(
      backgroundColor: colors.surface,
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
            loc.translationsDownloads,
            style: AppTypography.headlineLarge.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            loc.manageTranslationsSubtitle,
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
          _buildUpdateBanner(colors),
          const SizedBox(height: AppDimensions.lg),
          SettingsSection(
            title: loc.displayMode,
            colors: colors,
            children: [
              _ModeSelector(
                currentMode: settings.showTranslation
                    ? settings.translationDisplayMode
                    : null,
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
                  ref.read(settingsProvider.notifier).setShowTranslation(show);
                },
                colors: colors,
              ),
              const SizedBox(height: 4),
              _ShowBookLinksTile(
                value: settings.showBookLinks,
                onChanged: (v) {
                  ref.read(settingsProvider.notifier).setShowBookLinks(v);
                },
                colors: colors,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.lg),
          SettingsSection(
            title: loc.paliTextLabel,
            colors: colors,
            children: [
              _LanguageTypographyCard(
                isEnabled: settings.showPali,
                title: loc.pali,
                subtitle: loc.paliRomanScript,
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
          const SizedBox(height: AppDimensions.lg),
          SettingsSection(
            title: loc.translationOrder,
            colors: colors,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.md,
                  AppDimensions.sm,
                  AppDimensions.md,
                  AppDimensions.sm,
                ),
                child: Text(
                  loc.reorderTranslationsHint,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
              if (reorderableCodes.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.md,
                    0,
                    AppDimensions.md,
                    AppDimensions.md,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppDimensions.md),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest.withValues(
                        alpha: 0.35,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      loc.noTranslationsDownloadedYet,
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.sm,
                    0,
                    AppDimensions.sm,
                    AppDimensions.sm,
                  ),
                  child: ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    children: reorderableCodes.asMap().entries.map((entry) {
                      final code = entry.value;
                      final index = entry.key;
                      final langName = TranslationLanguageRegistry.englishName(
                        code,
                      );
                      final nativeName = TranslationLanguageRegistry.nativeName(
                        code,
                      );
                      return _ReorderableTranslationTile(
                        key: ValueKey(code),
                        index: index,
                        code: code,
                        langName: langName,
                        nativeName: nativeName,
                        colors: colors,
                      );
                    }).toList(),
                    onReorderItem: (oldIndex, newIndex) {
                      // onReorderItem returns the FINAL index (Flutter already
                      // adjusts for the removed item) — do NOT decrement.
                      final reordered = List<String>.from(reorderableCodes);
                      final moved = reordered.removeAt(oldIndex);
                      reordered.insert(newIndex, moved);

                      // Rebuild the FULL enabled list, keeping non-downloaded
                      // (e.g. not-yet-downloaded) languages in place and only
                      // applying the new order to the downloaded subset.
                      final reorderedQueue = List<String>.from(reordered);
                      final full = settings.enabledTranslations.map((code) {
                        if (!downloadedCodes.contains(code)) return code;
                        return reorderedQueue.removeAt(0);
                      }).toList();

                      ref
                          .read(settingsProvider.notifier)
                          .setTranslationsOrder(full);
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.lg),
          SettingsSection(
            title: loc.translationDatabases,
            colors: colors,
            children: [
              mergedVersionsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppDimensions.lg),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(AppDimensions.md),
                  child: Text(
                    '${loc.error} $e',
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.error,
                    ),
                  ),
                ),
                data: (versions) {
                  if (versions.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(AppDimensions.md),
                      child: Text(
                        loc.noTranslationsFound,
                        style: AppTypography.labelSmall.copyWith(
                          color: colors.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    );
                  }
                  final grouped = <String, List<TranslationVersion>>{};
                  for (final v in versions) {
                    grouped.putIfAbsent(v.languageCode, () => []);
                    grouped[v.languageCode]!.add(v);
                  }
                  final langCodes = grouped.keys.toList();
                  langCodes.sort((a, b) {
                    final aEnabled = settings.enabledTranslations.contains(a);
                    final bEnabled = settings.enabledTranslations.contains(b);
                    if (aEnabled && bEnabled) {
                      return settings.enabledTranslations
                          .indexOf(a)
                          .compareTo(settings.enabledTranslations.indexOf(b));
                    }
                    if (aEnabled) return -1;
                    if (bEnabled) return 1;
                    return a.compareTo(b);
                  });
                  return Column(
                    children: langCodes.expand((code) {
                      final langVersions = grouped[code]!;
                      final langName = TranslationLanguageRegistry.englishName(
                        code,
                      );
                      final nativeName = TranslationLanguageRegistry.nativeName(
                        code,
                      );
                      final isAnyEnabled = settings.enabledTranslations
                          .contains(code);
                      return [
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppDimensions.sm,
                            bottom: 2,
                          ),
                          child: _LanguageHeader(
                            code: code,
                            englishName: langName,
                            nativeName: nativeName,
                            isAnyEnabled: isAnyEnabled,
                            isAnyVersionInstalled: langVersions.any(
                              (v) => v.isAvailable,
                            ),
                            colors: colors,
                            onEnableChanged: (enabled) {
                              final notifier = ref.read(
                                settingsProvider.notifier,
                              );
                              notifier.setTranslationEnabled(code, enabled);
                              // Auto-select the first available version when
                              // enabling, if none is selected yet.  This way
                              // the user doesn't have to also tap "Select this
                              // version" separately — the nissaya (or default)
                              // version just works after enabling the language.
                              if (enabled) {
                                final currentSuffix =
                                    settings.translationVersionMap[code];
                                if (currentSuffix == null ||
                                    currentSuffix.isEmpty) {
                                  final available = langVersions
                                      .where((v) => v.isAvailable)
                                      .toList();
                                  if (available.isNotEmpty) {
                                    // Prefer nissaya versions when auto-
                                    // selecting — users who have installed a
                                    // nissaya DB are most likely trying to
                                    // use that specific version.
                                    final best = available.firstWhere(
                                      (v) => v.isNissaya,
                                      orElse: () => available.first,
                                    );
                                    notifier.setTranslationVersion(
                                      code,
                                      best.suffix,
                                    );
                                  }
                                }
                              }
                            },
                          ),
                        ),
                        ...langVersions.map((v) {
                          final versionKey =
                              v.suffix != null && v.suffix!.isNotEmpty
                              ? '${v.languageCode}_${v.suffix}'
                              : v.languageCode;
                          final dlState =
                              downloadStates[versionKey] ??
                              const TranslationDownloadState();
                          final typo = settings.typography.typographyFor(code);
                          final selectedSuffix =
                              settings.translationVersionMap[code];

                          return _TranslationVersionTile(
                            version: v,
                            downloadState: dlState,
                            typography: typo,
                            isEnabled: isAnyEnabled,
                            selectedSuffix: selectedSuffix,
                            colors: colors,
                            onDownload: () {
                              ref
                                  .read(translationDownloadProvider.notifier)
                                  .downloadVersion(v, ref);
                            },
                            onDelete: () => _confirmDeleteVersion(v),
                            onCancel:
                                dlState.status == DownloadStatus.downloading ||
                                    dlState.status == DownloadStatus.extracting
                                ? () => ref
                                      .read(
                                        translationDownloadProvider.notifier,
                                      )
                                      .cancelDownload(versionKey)
                                : null,
                            onEnableChanged: (enabled) {
                              ref
                                  .read(settingsProvider.notifier)
                                  .setTranslationEnabled(code, enabled);
                            },
                            onTypographyChanged: (newTypo) {
                              ref
                                  .read(settingsProvider.notifier)
                                  .setLanguageTypography(code, newTypo);
                            },
                            onVersionChanged: (String? suffix) {
                              ref
                                  .read(settingsProvider.notifier)
                                  .setTranslationVersion(code, suffix);
                            },
                          );
                        }),
                        if (langCodes.last != code)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppDimensions.sm,
                            ),
                            child: Divider(
                              height: 1,
                              thickness: 1,
                              color: colors.outlineVariant.withValues(
                                alpha: 0.25,
                              ),
                            ),
                          ),
                      ];
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateBanner(ColorScheme colors) {
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm + 2,
      ),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _manifestLoading ? Icons.sync : Icons.cloud_sync_outlined,
              size: 17,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: AppDimensions.sm + 2),
          Expanded(
            child: Text(
              _manifestLoading
                  ? loc.checkingForUpdates
                  : loc.checkForTranslationUpdates,
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _manifestLoading
                ? null
                : () async {
                    setState(() => _manifestLoading = true);
                    ref.invalidate(translationManifestProvider);
                    ref.invalidate(mergedTranslationVersionsProvider);
                    await Future.delayed(const Duration(milliseconds: 500));
                    if (mounted) {
                      setState(() => _manifestLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(loc.updateCheckComplete),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
            icon: const Icon(Icons.refresh, size: 15),
            label: Text(loc.check),
            style: TextButton.styleFrom(
              foregroundColor: colors.primary,
              backgroundColor: colors.primary.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteVersion(TranslationVersion version) async {
    final loc = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(loc.deleteTranslationTitle),
        content: Text(
          '${loc.deleteTranslationConfirm} "${version.displayName}" (${version.englishName})?\n'
          '${loc.deleteTranslationRemoveDb}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(loc.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final deleted = await ref
          .read(translationDownloadProvider.notifier)
          .deleteVersion(version);
      if (deleted) {
        ref.invalidate(mergedTranslationVersionsProvider);
        ref.invalidate(localTranslationVersionsProvider);
        ref.invalidate(translationRegistryProvider);
        if (version.isNissaya) {
          ref.invalidate(nissayaDbByFilenameProvider(version.filename));
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${loc.deletedLabel} ${version.englishName} (${version.displayName})',
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    }
  }
}

// ── Language Header ─────────────────────────────────────────────────────────

class _LanguageHeader extends StatelessWidget {
  final String code;
  final String englishName;
  final String nativeName;
  final bool isAnyEnabled;
  final bool isAnyVersionInstalled;
  final ColorScheme colors;
  final ValueChanged<bool>? onEnableChanged;

  const _LanguageHeader({
    required this.code,
    required this.englishName,
    required this.nativeName,
    required this.isAnyEnabled,
    required this.isAnyVersionInstalled,
    required this.colors,
    this.onEnableChanged,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm + 2,
        vertical: AppDimensions.sm,
      ),
      decoration: BoxDecoration(
        color: isAnyEnabled
            ? colors.primary.withValues(alpha: 0.06)
            : colors.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isAnyVersionInstalled
                  ? Icons.translate
                  : Icons.cloud_download_outlined,
              size: 15,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        code.toUpperCase(),
                        style: AppTypography.labelSmall.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$englishName · $nativeName',
                        style: AppTypography.labelSmall.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (isAnyVersionInstalled && onEnableChanged != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(
                          isAnyEnabled
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          size: 11,
                          color: isAnyEnabled
                              ? Colors.green.shade600
                              : colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isAnyEnabled ? loc.enabled : loc.disabled,
                          style: TextStyle(
                            fontSize: 10,
                            color: isAnyEnabled
                                ? Colors.green.shade700
                                : colors.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (isAnyVersionInstalled)
            Transform.scale(
              scale: 0.85,
              child: Switch(
                value: isAnyEnabled,
                onChanged: onEnableChanged == null
                    ? null
                    : (v) => onEnableChanged!(v),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Translation Version Tile ─────────────────────────────────────────────────

class _TranslationVersionTile extends StatefulWidget {
  final TranslationVersion version;
  final TranslationDownloadState downloadState;
  final LanguageTypography typography;
  final bool isEnabled;
  final String? selectedSuffix;
  final ColorScheme colors;
  final VoidCallback onDownload;
  final VoidCallback onDelete;
  final VoidCallback? onCancel;
  final ValueChanged<bool> onEnableChanged;
  final ValueChanged<LanguageTypography> onTypographyChanged;
  final ValueChanged<String?> onVersionChanged;

  const _TranslationVersionTile({
    required this.version,
    required this.downloadState,
    required this.typography,
    required this.isEnabled,
    this.selectedSuffix,
    required this.colors,
    required this.onDownload,
    required this.onDelete,
    this.onCancel,
    required this.onEnableChanged,
    required this.onTypographyChanged,
    required this.onVersionChanged,
  });

  @override
  State<_TranslationVersionTile> createState() =>
      _TranslationVersionTileState();
}

class _TranslationVersionTileState extends State<_TranslationVersionTile> {
  bool _expanded = false;
  bool _hasUpdate = false;

  @override
  void initState() {
    super.initState();
    _checkUpdate();
  }

  Future<void> _checkUpdate() async {
    final hasUpdate = await TranslationDownloadNotifier.isUpdateAvailable(
      widget.version,
    );
    if (mounted && hasUpdate != _hasUpdate) {
      setState(() => _hasUpdate = hasUpdate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.version;
    final dlState = widget.downloadState;
    final colors = widget.colors;
    final isInstalled = v.isAvailable;

    final isSelected =
        widget.selectedSuffix == v.suffix ||
        (widget.selectedSuffix == null &&
            (v.suffix == null || v.suffix!.isEmpty));

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: 5,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected && isInstalled
                ? colors.primary.withValues(alpha: 0.35)
                : colors.outlineVariant.withValues(alpha: 0.25),
            width: isSelected && isInstalled ? 1.2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderRow(context, colors, v, dlState, isInstalled),
            if (dlState.status == DownloadStatus.downloading ||
                dlState.status == DownloadStatus.extracting)
              _buildProgress(dlState, colors),
            if (dlState.status == DownloadStatus.error &&
                dlState.errorMessage != null)
              _buildError(dlState.errorMessage!, colors),
            if (_expanded) _buildExpandedContent(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow(
    BuildContext context,
    ColorScheme colors,
    TranslationVersion v,
    TranslationDownloadState dlState,
    bool isInstalled,
  ) {
    final loc = AppLocalizations.of(context);
    final isSelected =
        widget.selectedSuffix == v.suffix ||
        (widget.selectedSuffix == null &&
            (v.suffix == null || v.suffix!.isEmpty));

    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.sm + 2,
          vertical: AppDimensions.sm + 2,
        ),
        child: Row(
          children: [
            _VersionBadge(version: v, colors: colors),
            const SizedBox(width: AppDimensions.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    v.displayName,
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    v.filename,
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Active version indicator
            if (isSelected && isInstalled) ...[
              _StatusChip(
                label: loc.active,
                color: colors.primary,
                colors: colors,
              ),
              const SizedBox(width: 6),
            ],
            // Status / action buttons
            if (dlState.status == DownloadStatus.downloading ||
                dlState.status == DownloadStatus.extracting)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: colors.primary,
                    ),
                  ),
                  if (widget.onCancel != null) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: widget.onCancel,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.error.withValues(alpha: 0.1),
                        ),
                        child: Icon(Icons.stop, size: 14, color: colors.error),
                      ),
                    ),
                  ],
                ],
              )
            else if (dlState.status == DownloadStatus.completed)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 14, color: Colors.green),
              )
            else if (isInstalled && v.isNissaya)
              _StatusChip(label: loc.nissaya, color: Colors.teal, colors: colors)
            else if (isInstalled)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_hasUpdate && v.hasDownloadUrl)
                    _SmallButton(
                      label: loc.update,
                      icon: Icons.system_update,
                      onTap: widget.onDownload,
                      colors: colors,
                    ),
                  if (_hasUpdate) const SizedBox(width: 6),
                  InkWell(
                    onTap: widget.onDelete,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.error.withValues(alpha: 0.08),
                      ),
                      child: Icon(
                        Icons.delete_outline,
                        size: 15,
                        color: colors.error.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ],
              )
            else if (!isInstalled && v.hasDownloadUrl)
              _SmallButton(
                label: loc.download,
                icon: Icons.download,
                onTap: widget.onDownload,
                colors: colors,
              ),
            const SizedBox(width: 6),
            Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress(TranslationDownloadState dlState, ColorScheme colors) {
    final loc = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.sm + 2,
        0,
        AppDimensions.sm + 2,
        AppDimensions.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: dlState.status == DownloadStatus.extracting
                  ? null
                  : dlState.progress,
              minHeight: 4,
              backgroundColor: colors.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            dlState.status == DownloadStatus.extracting
                ? loc.installing
                : '${(dlState.progress * 100).toStringAsFixed(0)}%',
            style: AppTypography.labelSmall.copyWith(
              color: colors.primary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.sm + 2,
        0,
        AppDimensions.sm + 2,
        AppDimensions.sm,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: colors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 13, color: colors.error),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                error,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.error,
                  fontSize: 10,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedContent(ColorScheme colors) {
    final loc = AppLocalizations.of(context);
    final typo = widget.typography;
    final defaultColor = AppSettings.defaultTranslationColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.sm + 2,
        0,
        AppDimensions.sm + 2,
        AppDimensions.sm + 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            height: 1,
            color: colors.outlineVariant.withValues(alpha: 0.25),
          ),
          const SizedBox(height: AppDimensions.sm + 2),
          _SectionLabel(loc.fontFamily, colors),
          const SizedBox(height: 8),
          _FontFamilySelector(
            current: typo.fontFamily,
            colors: colors,
            onChanged: (family) {
              widget.onTypographyChanged(typo.copyWith(fontFamily: family));
            },
          ),
          const SizedBox(height: AppDimensions.md),
          _SectionLabel(loc.fontSize, colors),
          const SizedBox(height: 8),
          _FontSizeControl(
            fontSize: typo.fontSize,
            colors: colors,
            onChanged: (size) {
              widget.onTypographyChanged(typo.copyWith(fontSize: size));
            },
          ),
          const SizedBox(height: AppDimensions.md),
          _SectionLabel(loc.style, colors),
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
          ColorPickerSection(
            title: loc.colorLabel,
            icon: Icons.palette_outlined,
            currentColor: typo.color ?? defaultColor,
            selectedColor: typo.color ?? defaultColor,
            presetColors: _colorPresets(defaultColor),
            colors: colors,
            onColorSelected: (c) {
              widget.onTypographyChanged(typo.copyWith(color: c));
            },
            onCustomColor: () {
              showColorPickerScreen(
                context,
                title: loc.pickColor,
                initialColor: typo.color ?? defaultColor,
                onApply: (c) {
                  widget.onTypographyChanged(typo.copyWith(color: c));
                },
              );
            },
          ),
          const SizedBox(height: AppDimensions.md),

          // Version selector
          _SectionLabel(loc.useForReading, colors),
          const SizedBox(height: 8),
          _VersionSelector(
            version: widget.version,
            currentSuffix: widget.selectedSuffix,
            colors: colors,
            onChanged: widget.onVersionChanged,
          ),
          const SizedBox(height: AppDimensions.md),

          // Version info
          _SectionLabel(loc.versionInfo, colors),
          const SizedBox(height: 8),
          _VersionInfo(version: widget.version, colors: colors),

          if (widget.version.isNissaya) ...[
            const SizedBox(height: AppDimensions.sm + 2),
            _NissayaInfoCard(colors: colors),
          ],
          if (widget.version.isAvailable) ...[
            const SizedBox(height: AppDimensions.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: Text(loc.deleteTranslationShort),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.error,
                  side: BorderSide(color: colors.error.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Color> _colorPresets(Color defaultColor) {
    // Dedupe by ARGB value so the default color (which may itself be
    // black, or match one of the fixed swatches) never appears twice.
    final swatches = <Color>[
      defaultColor,
      const Color(0xFF7A2E1D),
      const Color(0xFF33312E),
      const Color(0xFF3D3D8F),
      const Color(0xFF2A6B6B),
      const Color(0xFF3C6E47),
      const Color(0xFFB5651D),
      const Color(0xFF4A6FA5),
      const Color(0xFF6B635A),
      Colors.black,
    ];
    final seen = <int>{};
    return [
      for (final c in swatches)
        if (seen.add(c.toARGB32())) c,
    ];
  }
}

// ── Version Badge ───────────────────────────────────────────────────────────

class _VersionBadge extends StatelessWidget {
  final TranslationVersion version;
  final ColorScheme colors;

  const _VersionBadge({required this.version, required this.colors});

  @override
  Widget build(BuildContext context) {
    final isNissaya = version.isNissaya;
    final isDefault = version.suffix == null || version.suffix!.isEmpty;

    Color bgColor;
    String label;

    if (isNissaya) {
      bgColor = Colors.teal;
      label = 'N';
    } else if (isDefault) {
      bgColor = colors.primary;
      label = 'T';
    } else {
      bgColor = colors.tertiary;
      label = 'V';
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: bgColor.withValues(alpha: 0.25)),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: bgColor,
          ),
        ),
      ),
    );
  }
}

// ── Status Chip ─────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final ColorScheme colors;

  const _StatusChip({
    required this.label,
    required this.color,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ── Version Selector ─────────────────────────────────────────────────────────

class _VersionSelector extends StatelessWidget {
  final TranslationVersion version;
  final String? currentSuffix;
  final ColorScheme colors;
  final ValueChanged<String?> onChanged;

  const _VersionSelector({
    required this.version,
    required this.currentSuffix,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isCurrentlySelected =
        currentSuffix == version.suffix ||
        (currentSuffix == null &&
            (version.suffix == null || version.suffix!.isEmpty));
    final canBeSelected = version.isAvailable;

    return InkWell(
      onTap: canBeSelected && !isCurrentlySelected
          ? () => onChanged(version.suffix)
          : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isCurrentlySelected
              ? colors.primary.withValues(alpha: 0.1)
              : colors.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCurrentlySelected
                ? colors.primary.withValues(alpha: 0.5)
                : colors.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isCurrentlySelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              size: 16,
              color: isCurrentlySelected
                  ? colors.primary
                  : canBeSelected
                  ? colors.onSurfaceVariant
                  : colors.outlineVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCurrentlySelected
                        ? loc.activeVersion
                        : loc.selectThisVersion,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isCurrentlySelected
                          ? colors.primary
                          : colors.onSurface,
                    ),
                  ),
                  Text(
                    version.isNissaya
                        ? loc.nissayaDesc
                        : loc.standardTranslation,
                    style: TextStyle(
                      fontSize: 10,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (!canBeSelected)
              Text(
                loc.installFirst,
                style: TextStyle(
                  fontSize: 10,
                  color: colors.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Small Button ────────────────────────────────────────────────────────────

class _SmallButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final ColorScheme colors;

  const _SmallButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: colors.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Version Info ────────────────────────────────────────────────────────────

class _VersionInfo extends StatelessWidget {
  final TranslationVersion version;
  final ColorScheme colors;

  const _VersionInfo({required this.version, required this.colors});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final items = <String, String>{
      loc.filename: version.filename,
      loc.type: version.isNissaya
          ? loc.nissayaDesc
          : loc.standardTranslation,
      loc.language: version.englishName,
      loc.suffix: version.suffix ?? loc.defaultLabel,
      if (version.fileSize != null)
        loc.size: '${(version.fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB',
      if (version.updatedAt != null) loc.updated: version.updatedAt!,
      if (version.isAvailable) loc.status: loc.installed,
    };

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: items.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.value,
                    style: TextStyle(fontSize: 10, color: colors.onSurface),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Nissaya Info Card ───────────────────────────────────────────────────────

class _NissayaInfoCard extends StatelessWidget {
  final ColorScheme colors;

  const _NissayaInfoCard({required this.colors});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 14, color: Colors.teal),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${loc.nissayaInfo}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.teal.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Language Typography Card (for Pāli) ─────────────────────────────────────

class _LanguageTypographyCard extends StatefulWidget {
  final bool isEnabled;
  final String title;
  final String subtitle;
  final LanguageTypography typography;
  final Color defaultColor;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<LanguageTypography> onTypographyChanged;
  final ColorScheme colors;

  const _LanguageTypographyCard({
    required this.isEnabled,
    required this.title,
    required this.subtitle,
    required this.typography,
    required this.defaultColor,
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
    final loc = AppLocalizations.of(context);
    final typo = widget.typography;
    final effectiveColor = typo.effectiveColor(widget.defaultColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.md,
              vertical: AppDimensions.sm + 2,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => widget.onEnabledChanged(!widget.isEnabled),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: widget.isEnabled
                          ? colors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
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
                              ? FontWeight.w700
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
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: effectiveColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.outlineVariant),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(
                      alpha: 0.6,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${typo.fontSize.round()}px',
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: colors.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
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
                Divider(
                  height: 1,
                  color: colors.outlineVariant.withValues(alpha: 0.25),
                ),
                const SizedBox(height: AppDimensions.md),
                _SectionLabel(loc.fontFamily, colors),
                const SizedBox(height: 8),
                _FontFamilySelector(
                  current: typo.fontFamily,
                  colors: colors,
                  onChanged: (family) {
                    widget.onTypographyChanged(
                      typo.copyWith(fontFamily: family),
                    );
                  },
                ),
                const SizedBox(height: AppDimensions.md),
                _SectionLabel(loc.fontSize, colors),
                const SizedBox(height: 8),
                _FontSizeControl(
                  fontSize: typo.fontSize,
                  colors: colors,
                  onChanged: (size) {
                    widget.onTypographyChanged(typo.copyWith(fontSize: size));
                  },
                ),
                const SizedBox(height: AppDimensions.md),
                _SectionLabel(loc.style, colors),
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
                ColorPickerSection(
                  title: loc.colorLabel,
                  icon: Icons.palette_outlined,
                  currentColor: typo.color ?? widget.defaultColor,
                  selectedColor: typo.color ?? widget.defaultColor,
                  presetColors: _colorPresets(widget.defaultColor),
                  colors: colors,
                  onColorSelected: (c) {
                    widget.onTypographyChanged(typo.copyWith(color: c));
                  },
                  onCustomColor: () {
                    showColorPickerScreen(
                      context,
                      title: loc.pickColor,
                      initialColor: typo.color ?? widget.defaultColor,
                      onApply: (c) {
                        widget.onTypographyChanged(typo.copyWith(color: c));
                      },
                    );
                  },
                ),
                const SizedBox(height: AppDimensions.md),
                _SectionLabel(loc.preview, colors),
                const SizedBox(height: 8),
                _TextPreview(
                  typography: typo,
                  fallbackColor: widget.defaultColor,
                ),
              ],
            ),
          ),
      ],
    );
  }

  List<Color> _colorPresets(Color defaultColor) {
    // Dedupe by ARGB value so the default color (which may itself be
    // black, or match one of the fixed swatches) never appears twice.
    final swatches = <Color>[
      defaultColor,
      const Color(0xFF7A2E1D),
      const Color(0xFF33312E),
      const Color(0xFF3D3D8F),
      const Color(0xFF2A6B6B),
      const Color(0xFF3C6E47),
      const Color(0xFFB5651D),
      const Color(0xFF4A6FA5),
      const Color(0xFF6B635A),
      Colors.black,
    ];
    final seen = <int>{};
    return [
      for (final c in swatches)
        if (seen.add(c.toARGB32())) c,
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
      label.toUpperCase(),
      style: AppTypography.labelSmall.copyWith(
        color: colors.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        fontSize: 10,
        letterSpacing: 0.4,
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
      runSpacing: 8,
      children: ReadingFontFamily.values.map((family) {
        final isSelected = current == family;
        return GestureDetector(
          onTap: () => onChanged(family),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected
                  ? colors.primaryContainer
                  : colors.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? colors.primary
                    : colors.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              family.label,
              style: TextStyle(
                fontFamily: family.fontFamily,
                fontSize: 14,
                color: isSelected
                    ? colors.onPrimaryContainer
                    : colors.onSurface,
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
        const SizedBox(width: 10),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              overlayShape: SliderComponentShape.noOverlay,
            ),
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
        ),
        const SizedBox(width: 10),
        _CircleButton(
          icon: Icons.add,
          colors: colors,
          onTap: () => onChanged((fontSize + 1).clamp(10.0, 48.0)),
        ),
        const SizedBox(width: 12),
        Container(
          width: 36,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${fontSize.round()}',
            textAlign: TextAlign.center,
            style: AppTypography.labelSmall.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w700,
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
          color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.6),
          ),
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
          color: active
              ? colors.primaryContainer
              : colors.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? colors.primary
                : colors.outlineVariant.withValues(alpha: 0.5),
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

class _TextPreview extends StatelessWidget {
  final LanguageTypography typography;
  final Color fallbackColor;

  const _TextPreview({required this.typography, required this.fallbackColor});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Text(
        'Evaṃ me sutaṃ… Thus have I heard…',
        style: typography.toTextStyle(fallbackColor: fallbackColor),
      ),
    );
  }
}

// ── Display mode selector ────────────────────────────────────────────────────

/// Checkbox row toggling the inlined commentary/book-link chips (persisted).
class _ShowBookLinksTile extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final ColorScheme colors;

  const _ShowBookLinksTile({
    required this.value,
    required this.onChanged,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: 2,
      ),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.sm + 2,
            vertical: AppDimensions.sm + 2,
          ),
          decoration: BoxDecoration(
            color: value
                ? colors.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: colors.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              Icon(Icons.link, size: 20, color: colors.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.showBookLinks,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: value ? FontWeight.w600 : FontWeight.w400,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      loc.showBookLinksSubtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    final loc = AppLocalizations.of(context);
    final options = [
      _ModeOption(
        mode: null,
        icon: Icons.visibility_off,
        title: loc.hideTranslationMode,
        subtitle: loc.hideTranslationModeSubtitle,
        isSelected: !showTranslation,
      ),
      _ModeOption(
        mode: TranslationDisplayMode.lineByLine,
        icon: Icons.view_headline,
        title: loc.lineByLineMode,
        subtitle: loc.lineByLineModeSubtitle,
        isSelected:
            showTranslation && currentMode == TranslationDisplayMode.lineByLine,
      ),
      _ModeOption(
        mode: TranslationDisplayMode.sideBySide,
        icon: Icons.view_column,
        title: loc.sideBySideMode,
        subtitle: loc.sideBySideModeSubtitle,
        isSelected:
            showTranslation && currentMode == TranslationDisplayMode.sideBySide,
      ),
    ];

    return Column(
      children: options.map((option) {
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.sm,
            vertical: 2,
          ),
          child: InkWell(
            onTap: () {
              if (option.mode == null) {
                onToggleTranslation(false);
              } else {
                onSelectMode(option.mode!);
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.sm + 2,
                vertical: AppDimensions.sm + 2,
              ),
              decoration: BoxDecoration(
                color: option.isSelected
                    ? colors.primary.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
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
                  const SizedBox(width: AppDimensions.sm + 2),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: option.isSelected
                          ? colors.primary.withValues(alpha: 0.14)
                          : colors.surfaceContainerHighest.withValues(
                              alpha: 0.5,
                            ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(option.icon, color: colors.primary, size: 17),
                  ),
                  const SizedBox(width: AppDimensions.sm + 2),
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
                            fontWeight: option.isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
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
          ),
        );
      }).toList(),
    );
  }
}

/// A draggable row representing an enabled translation in the order list.
class _ReorderableTranslationTile extends StatelessWidget {
  final int index;
  final String code;
  final String langName;
  final String nativeName;
  final ColorScheme colors;

  const _ReorderableTranslationTile({
    super.key,
    required this.index,
    required this.code,
    required this.langName,
    required this.nativeName,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm + 2,
        vertical: AppDimensions.sm + 2,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(
                Icons.drag_indicator,
                size: 20,
                color: colors.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${index + 1}',
              style: AppTypography.labelSmall.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  langName,
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  nativeName,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
