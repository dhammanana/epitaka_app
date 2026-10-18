import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_localizations.dart';
import '../../dictionary/providers/dictionary_font_scale_provider.dart';
import '../../dictionary/providers/dictionary_header_provider.dart';
import '../../dpd/providers/dictionary_list_provider.dart';
import '../../dpd/providers/dpd_database_provider.dart';
import '../../dpd/providers/dpd_settings_provider.dart';
import '../../dpd/services/dpd_installer.dart';
import '../../dpd/services/dpd_update_checker.dart';
import '../../dpd/widgets/dpd_download_control.dart';
import '../../../features/mdx_dictionary/widgets/mdx_settings_section.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../widgets/settings_app_bar.dart';
import '../widgets/settings_section.dart';

class DictionarySettingsScreen extends StatelessWidget {
  const DictionarySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: SettingsAppBar(colors: colors),
      body: const DictionarySettingsBody(),
    );
  }
}

/// Scrollable body of the dictionary settings — shared between the mobile
/// screen and the desktop settings window.
class DictionarySettingsBody extends ConsumerWidget {
  const DictionarySettingsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          loc.dictionarySettings,
          style: AppTypography.headlineLarge.copyWith(color: colors.onSurface),
        ),
        const SizedBox(height: 4),
        Text(
          loc.dictionarySettingDesc,
          style: AppTypography.bodyTranslation.copyWith(
            color: colors.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: AppDimensions.lg),
        const _DpdLevelSection(),
        const SizedBox(height: AppDimensions.lg),
        const _DpdDatabaseSection(),
        const SizedBox(height: AppDimensions.lg),
        const _DictionaryFontSizeSection(),
        const SizedBox(height: AppDimensions.lg),
        const _DictionaryListSection(),
        const SizedBox(height: AppDimensions.lg),
        const _DpdOptionsSection(),
        MdxSettingsSection(colors: colors),
      ],
    );
  }
}

/// How much of each DPD entry the dictionary shows.
class _DpdLevelSection extends ConsumerWidget {
  const _DpdLevelSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final level = ref.watch(dpdSettingsProvider.select((s) => s.level));
    return SettingsSection(
      title: loc.dpdLevel,
      colors: colors,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<DictionaryLevel>(
                  showSelectedIcon: false,
                  segments: [
                    for (final l in DictionaryLevel.values)
                      ButtonSegment(
                        value: l,
                        label: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(l.paliName),
                            Text(
                              loc.t(l.englishName),
                              style: AppTypography.labelSmall,
                            ),
                          ],
                        ),
                      ),
                  ],
                  selected: {level},
                  onSelectionChanged: (s) => ref
                      .read(dpdSettingsProvider.notifier)
                      .setLevel(s.first),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                loc.dpdLevelHelp,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        _OptionTile(
          title: loc.dictionaryHeaderIconsShow,
          value: ref.watch(dictionaryHeaderIconsProvider),
          onChanged: ref.read(dictionaryHeaderIconsProvider.notifier).set,
          colors: colors,
        ),
      ],
    );
  }
}

/// Which DPD release is installed, or why there is none; the last check,
/// Check now with its answer, and the download.
class _DpdDatabaseSection extends ConsumerWidget {
  const _DpdDatabaseSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final state = ref.watch(dpdDatabaseProvider);
    final subtitle = state.when(
      loading: () => '…',
      error: (e, _) => loc.errorMessage(e.toString()),
      data: (s) => switch (s.status) {
        DpdDatabaseStatus.ready => loc.dpdInstalledRelease(
          s.releaseVersion ?? '?',
        ),
        DpdDatabaseStatus.notInstalled => loc.dpdNotInstalled,
        DpdDatabaseStatus.unsupportedSchema => loc.dpdUnsupportedSchema(
          s.schemaVersion,
        ),
      },
    );
    final path = state.valueOrNull?.path;
    final isReady = state.valueOrNull?.status == DpdDatabaseStatus.ready;
    final update = ref.watch(dpdUpdateProvider);
    final latest = update.latest;
    final newer =
        latest != null &&
        (!isReady || latest.isNewerThan(state.valueOrNull?.releaseVersion));
    final lastCheck = update.lastCheck;
    final secondary = AppTypography.labelSmall.copyWith(
      color: colors.onSurfaceVariant,
    );
    return SettingsSection(
      title: loc.dpdDatabase,
      colors: colors,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subtitle,
                style: AppTypography.labelMedium.copyWith(
                  color: isReady ? colors.onSurface : colors.error,
                ),
              ),
              if (path != null) ...[
                const SizedBox(height: 4),
                SelectableText(
                  path,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              // The check date and its answer share a line, and so do the
              // buttons (user, 2026-10-14); each wraps when narrow.
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    lastCheck == null
                        ? loc.dpdNeverChecked
                        : loc.dpdLastCheck(_day(lastCheck)),
                    style: secondary,
                  ),
                  if (update.error != null)
                    SelectableText(
                      update.error!,
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.error,
                      ),
                    )
                  else if (latest != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          newer ? Icons.new_releases_outlined : Icons.check,
                          size: 16,
                          color: newer ? colors.primary : colors.onSurface,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            newer
                                ? loc.dpdNewerRelease(
                                    latest.tag,
                                    formatDpdSize(latest.size),
                                  )
                                : loc.dpdUpToDate,
                            style: AppTypography.labelMedium.copyWith(
                              color: newer ? colors.primary : colors.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Messages above, buttons in one row below: Check now first,
              // then the download button, then Import from file.
              Align(
                alignment: Alignment.centerLeft,
                child: DpdDownloadControl(
                  release: latest,
                  label: isReady && !newer ? loc.dpdReinstall : null,
                  primary: !isReady || newer,
                  leading: OutlinedButton.icon(
                    onPressed: update.checking
                        ? null
                        : () => ref.read(dpdUpdateProvider.notifier).checkNow(),
                    icon: update.checking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(loc.dpdCheckNow),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One text size for every dictionary, as a share of the normal size.
class _DictionaryFontSizeSection extends ConsumerWidget {
  const _DictionaryFontSizeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final scale = ref.watch(dictionaryFontScaleProvider);
    final percent = '${(scale * 100).round()}%';
    final percentStyle = AppTypography.labelMedium.copyWith(
      color: colors.onSurface,
    );
    return SettingsSection(
      title: loc.dictionaryFontSize,
      colors: colors,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Row(
            children: [
              Expanded(
                child: Slider(
                  value: scale,
                  min: kDictionaryFontScaleMin,
                  max: kDictionaryFontScaleMax,
                  divisions: 14,
                  label: percent,
                  onChanged: ref
                      .read(dictionaryFontScaleProvider.notifier)
                      .setScale,
                ),
              ),
              // An invisible copy of the widest label holds the width, so the
              // slider stays still as the percent changes length, at any text
              // size. Never wrapped.
              Stack(
                alignment: Alignment.centerRight,
                children: [
                  Visibility(
                    visible: false,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: Text(
                      '${(kDictionaryFontScaleMax * 100).round()}%',
                      maxLines: 1,
                      softWrap: false,
                      style: percentStyle,
                    ),
                  ),
                  Text(
                    percent,
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.end,
                    style: percentStyle,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// DPD sources, DPD's external dictionaries, ePitaka's books and MDX files in
/// the one order the lookup page follows, each with an on/off switch.
class _DictionaryListSection extends ConsumerWidget {
  const _DictionaryListSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final listAsync = ref.watch(dictionaryListProvider);
    final store = ref.read(dictionaryListStoreProvider.notifier);
    return SettingsSection(
      title: loc.dictionaryListTitle,
      colors: colors,
      children: [
        listAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '${loc.errorLoadingDict} $e',
              style: AppTypography.labelSmall.copyWith(color: colors.error),
            ),
          ),
          data: (entries) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.md,
                  AppDimensions.md,
                  AppDimensions.md,
                  0,
                ),
                child: Text(
                  loc.dictionaryListHelp,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorderItem: (int oldIndex, int newIndex) {
                  // onReorderItem already gives the FINAL index; do not
                  // adjust it again.
                  final ids = entries.map((e) => e.item.id).toList();
                  ids.insert(newIndex, ids.removeAt(oldIndex));
                  store.setOrder(ids);
                },
                children: [
                  for (var i = 0; i < entries.length; i++)
                    _DictionaryTile(
                      key: ValueKey(entries[i].item.id),
                      label: entries[i].item.label,
                      index: i,
                      colors: colors,
                      isEnabled: entries[i].enabled,
                      onToggle: () =>
                          store.setEnabled(entries[i].item, !entries[i].enabled),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The DPD entry options that apply to every level.
class _DpdOptionsSection extends ConsumerWidget {
  const _DpdOptionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final settings = ref.watch(dpdSettingsProvider);
    final notifier = ref.read(dpdSettingsProvider.notifier);
    return SettingsSection(
      title: loc.dpdOptionsTitle,
      colors: colors,
      children: [
        _OptionTile(
          title: loc.dpdGrammarOpen,
          value: settings.grammarOpen,
          onChanged: notifier.setGrammarOpen,
          colors: colors,
        ),
        _OptionTile(
          title: loc.dpdExamplesOpen,
          value: settings.examplesOpen,
          onChanged: notifier.setExamplesOpen,
          colors: colors,
        ),
        _OptionTile(
          title: loc.dpdOneSectionAtATime,
          value: settings.oneButtonAtATime,
          onChanged: notifier.setOneButtonAtATime,
          colors: colors,
        ),
        _OptionTile(
          title: loc.dpdShowConstruction,
          value: settings.showConstructionInSummary,
          onChanged: notifier.setShowConstructionInSummary,
          colors: colors,
        ),
        _OptionTile(
          title: loc.dpdShowSummary,
          value: settings.showSummary,
          onChanged: notifier.setShowSummary,
          colors: colors,
        ),
        _OptionTile(
          title: loc.dpdShowPartial,
          value: settings.showPartialResults,
          onChanged: notifier.setShowPartialResults,
          colors: colors,
        ),
        _OptionTile(
          title: loc.dpdShowFuzzy,
          value: settings.showFuzzyResults,
          onChanged: notifier.setShowFuzzyResults,
          colors: colors,
        ),
        _OptionTile(
          title: loc.dpdShowSandhi,
          value: settings.showSandhi,
          onChanged: notifier.setShowSandhi,
          colors: colors,
        ),
        Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  loc.dpdAudioVoice,
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ),
              SegmentedButton<AudioGender>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: AudioGender.male,
                    label: Text(loc.dpdVoiceMale),
                  ),
                  ButtonSegment(
                    value: AudioGender.female,
                    label: Text(loc.dpdVoiceFemale),
                  ),
                ],
                selected: {settings.audioGender},
                onSelectionChanged: (s) => notifier.setAudioGender(s.first),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final ColorScheme colors;
  const _OptionTile({
    required this.title,
    required this.value,
    required this.onChanged,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTypography.labelMedium.copyWith(
                color: colors.onSurface,
              ),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _DictionaryTile extends StatelessWidget {
  final String label;
  final int index;
  final ColorScheme colors;
  final bool isEnabled;
  final VoidCallback onToggle;
  const _DictionaryTile({
    super.key,
    required this.label,
    required this.index,
    required this.colors,
    required this.isEnabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.drag_handle,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isEnabled ? colors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isEnabled ? colors.primary : colors.outlineVariant,
                  width: 1.5,
                ),
              ),
              child: isEnabled
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
                  label,
                  style: AppTypography.labelMedium.copyWith(
                    color: isEnabled
                        ? colors.onSurface
                        : colors.onSurfaceVariant,
                    fontWeight: isEnabled ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '#${index + 1}',
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _day(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-'
    '${t.month.toString().padLeft(2, '0')}-'
    '${t.day.toString().padLeft(2, '0')}';
