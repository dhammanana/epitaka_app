import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../providers/tts_provider.dart';
import '../providers/supertonic_download_provider.dart';
import '../services/system_tts_settings.dart';
import '../widgets/settings_app_bar.dart';
import '../widgets/settings_section.dart';

/// Voice styles available in Supertonic TTS.
const _supertonicVoices = [
  ('M1', 'Male Voice 1'),
  ('M2', 'Male Voice 2'),
  ('M3', 'Male Voice 3'),
  ('M4', 'Male Voice 4'),
  ('M5', 'Male Voice 5'),
  ('F1', 'Female Voice 1'),
  ('F2', 'Female Voice 2'),
  ('F3', 'Female Voice 3'),
  ('F4', 'Female Voice 4'),
  ('F5', 'Female Voice 5'),
];

/// Text-to-Speech settings with engine selection, voice, speed, and pitch.
class TtsSettingsScreen extends StatelessWidget {
  const TtsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: SettingsAppBar(colors: colors),
      body: const TtsSettingsBody(),
    );
  }
}

/// Scrollable body of the TTS settings — shared between the mobile screen and
/// the desktop settings window.
class TtsSettingsBody extends ConsumerStatefulWidget {
  const TtsSettingsBody({super.key});

  @override
  ConsumerState<TtsSettingsBody> createState() => _TtsSettingsBodyState();
}

class _TtsSettingsBodyState extends ConsumerState<TtsSettingsBody> {
  @override
  void initState() {
    super.initState();
    // Check supertonic model status on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(supertonicDownloadProvider.notifier).areModelsReady().then((ready) {
        if (ready) {
          ref.read(settingsProvider.notifier).setTtsSupertonicDownloaded(true);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final downloadState = ref.watch(supertonicDownloadProvider);
    final ttsPlayback = ref.watch(ttsProvider);

    final isSupertonic = settings.ttsEngine == 'supertonic';

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.marginMobile,
        AppDimensions.md,
        AppDimensions.marginMobile,
        120,
      ),
      children: [
          Text(
            loc.textToSpeech,
            style: AppTypography.headlineLarge.copyWith(
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: AppDimensions.lg),

          // ── Engine Selection ─────────────────────────────────────────
          SettingsSection(
            title: loc.engine,
            colors: colors,
            children: [
              _EngineSelector(
                currentEngine: settings.ttsEngine,
                colors: colors,
                onChanged: (engine) {
                  ref.read(settingsProvider.notifier).setTtsEngine(engine);
                },
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),

          // ── Speak mode (what to read aloud) ──────────────────────────
          SettingsSection(
            title: loc.ttsSpeakMode,
            colors: colors,
            children: [
              _SpeakModeTile(
                mode: TtsSpeakMode.translation,
                label: loc.ttsSpeakTranslation,
                description: loc.ttsSpeakTranslationDesc,
                icon: Icons.translate,
                isSelected: settings.ttsSpeakMode == TtsSpeakMode.translation,
                colors: colors,
                onTap: () {
                  ref
                      .read(settingsProvider.notifier)
                      .setTtsSpeakMode(TtsSpeakMode.translation);
                },
              ),
              const Divider(
                height: 1,
                indent: AppDimensions.md,
                endIndent: AppDimensions.md,
              ),
              _SpeakModeTile(
                mode: TtsSpeakMode.pali,
                label: loc.ttsSpeakPali,
                description: loc.ttsSpeakPaliDesc,
                icon: Icons.menu_book,
                isSelected: settings.ttsSpeakMode == TtsSpeakMode.pali,
                colors: colors,
                onTap: () {
                  ref
                      .read(settingsProvider.notifier)
                      .setTtsSpeakMode(TtsSpeakMode.pali);
                },
              ),
              const Divider(
                height: 1,
                indent: AppDimensions.md,
                endIndent: AppDimensions.md,
              ),
              _SpeakModeTile(
                mode: TtsSpeakMode.both,
                label: loc.ttsSpeakBoth,
                description: loc.ttsSpeakBothDesc,
                icon: Icons.library_books,
                isSelected: settings.ttsSpeakMode == TtsSpeakMode.both,
                colors: colors,
                onTap: () {
                  ref
                      .read(settingsProvider.notifier)
                      .setTtsSpeakMode(TtsSpeakMode.both);
                },
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),

          // ── Install a Pāli voice ─────────────────────────────────────
          // Pāli is always read in Devanagari (Hindi) — the script that
          // reads Pāli best. If the device has no Hindi voice, this tile
          // opens the system TTS settings to install one.
          SettingsSection(
            title: loc.ttsInstallVoice,
            colors: colors,
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.md,
                ),
                leading: Icon(Icons.download, color: colors.primary),
                title: Text(
                  loc.ttsInstallVoice,
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.onSurface,
                  ),
                ),
                subtitle: Text(
                  loc.ttsInstallVoiceHint,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: colors.onSurfaceVariant,
                ),
                onTap: () => openSystemTtsSettings(context),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),

          // ── Supertonic: Download & Setup ─────────────────────────────
          if (isSupertonic) ...[
            SettingsSection(
              title: loc.modelDownload,
              colors: colors,
              children: [
                _SupertonicDownloadTile(
                  downloadState: downloadState,
                  settings: settings,
                  colors: colors,
                  onDownload: () {
                    ref
                        .read(supertonicDownloadProvider.notifier)
                        .downloadModels(ref);
                  },
                  onCancel: () {
                    ref
                        .read(supertonicDownloadProvider.notifier)
                        .cancelDownload();
                  },
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.md),

            if (settings.ttsSupertonicDownloaded) ...[
              // Language — now follows the reading language automatically.
              SettingsSection(
                title: loc.language,
                colors: colors,
                children: [
                  _InfoTile(
                    icon: Icons.language,
                    title: loc.ttsLanguageLabel2,
                    subtitle: loc.ttsLanguageAutoNote,
                    colors: colors,
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.md),

              // Voice style selection
              SettingsSection(
                title: loc.voiceStyle,
                colors: colors,
                children: [
                  _DropdownTile(
                    icon: Icons.record_voice_over,
                    title: loc.ttsVoiceLabel,
                    value: _supertonicVoices.firstWhere(
                      (v) => v.$1 == settings.ttsSupertonicVoice,
                      orElse: () => ('M1', 'Male Voice 1'),
                    ).$2,
                    options: _supertonicVoices.map((v) => v.$2).toList(),
                    selectedValue: _supertonicVoices.firstWhere(
                      (v) => v.$1 == settings.ttsSupertonicVoice,
                      orElse: () => ('M1', 'Male Voice 1'),
                    ).$2,
                    onSelected: (label) {
                      final entry = _supertonicVoices.firstWhere(
                        (v) => v.$2 == label,
                        orElse: () => ('M1', 'Male Voice 1'),
                      );
                      ref
                          .read(settingsProvider.notifier)
                          .setTtsSupertonicVoice(entry.$1);
                    },
                    colors: colors,
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.md),

              // Synthesis quality (denoising steps).
              SettingsSection(
                title: loc.quality,
                colors: colors,
                children: [
                  _DropdownTile(
                    icon: Icons.tune,
                    title: loc.quality,
                    value: _qualityLabel(settings.ttsSupertonicQuality),
                    options: const ['Low', 'Medium', 'High'],
                    selectedValue: _qualityLabel(settings.ttsSupertonicQuality),
                    onSelected: (label) {
                      final code = label.toLowerCase();
                      ref
                          .read(settingsProvider.notifier)
                          .setTtsSupertonicQuality(code);
                    },
                    colors: colors,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimensions.md,
                      0,
                      AppDimensions.md,
                      AppDimensions.md,
                    ),
                    child: Text(
                      loc.qualitySubtitle,
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.md),
            ],
          ],

          // ── System TTS voice ─────────────────────────────────────────
          if (!isSupertonic) ...[
            SettingsSection(
              title: loc.ttsVoiceLabel,
              colors: colors,
              children: [
                _DropdownTile(
                  icon: Icons.record_voice_over,
                  title: loc.ttsVoiceLabel,
                  value: _voiceLabel(settings.ttsVoice),
                  options: _voiceOptions.map((o) => o.$2).toList(),
                  selectedValue: _voiceLabel(settings.ttsVoice),
                  onSelected: (label) {
                    final entry = _voiceOptions.firstWhere(
                      (o) => o.$2 == label,
                      orElse: () => ('default', 'System Default'),
                    );
                    ref.read(settingsProvider.notifier).setTtsVoice(entry.$1);
                  },
                  colors: colors,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.md),
          ],

          // ── Speed ────────────────────────────────────────────────────
          SettingsSection(
            title: loc.ttsSpeed,
            colors: colors,
            children: [
              _SpeedSlider(
                value: settings.ttsSpeed,
                min: 0.5,
                max: 4.0,
                divisions: 14,
                label: '${settings.ttsSpeed.toStringAsFixed(1)}×',
                colors: colors,
                onChanged: (v) {
                  ref.read(settingsProvider.notifier).setTtsSpeed(v);
                },
              ),
              const Divider(
                height: 1,
                indent: AppDimensions.md,
                endIndent: AppDimensions.md,
              ),
              // Pāli is read separately (Devanagari/Hindi), so it gets its
              // own speed — often a slower rate reads Pāli more clearly.
              _SpeedSlider(
                value: settings.ttsPaliSpeed,
                min: 0.1,
                max: 4.0,
                // 39 divisions → clean 0.1 steps across the 0.1–4.0 range.
                divisions: 39,
                label: '${settings.ttsPaliSpeed.toStringAsFixed(1)}×',
                colors: colors,
                caption: loc.ttsPaliSpeed,
                onChanged: (v) {
                  ref.read(settingsProvider.notifier).setTtsPaliSpeed(v);
                },
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),

          // ── Pitch ────────────────────────────────────────────────────
          SettingsSection(
            title: loc.ttPitch,
            colors: colors,
            children: [
              _SpeedSlider(
                value: settings.ttsPitch,
                min: 0.5,
                max: 2.0,
                divisions: 6,
                label: '${settings.ttsPitch.toStringAsFixed(1)}×',
                colors: colors,
                onChanged: (v) {
                  ref.read(settingsProvider.notifier).setTtsPitch(v);
                },
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),

          // ── Preview ──────────────────────────────────────────────────
          SettingsSection(
            title: loc.preview,
            colors: colors,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppDimensions.md),
                child: Row(
                  children: [
                    Icon(
                      ttsPlayback == TtsPlaybackState.playing
                          ? Icons.volume_up
                          : Icons.volume_up,
                      color: colors.primary,
                    ),
                    const SizedBox(width: AppDimensions.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _testButtonLabel(ttsPlayback),
                            style: AppTypography.labelMedium.copyWith(
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _testButtonSubtitle(ttsPlayback),
                            style: AppTypography.labelSmall.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (ttsPlayback == TtsPlaybackState.playing ||
                        ttsPlayback == TtsPlaybackState.paused)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (ttsPlayback == TtsPlaybackState.playing)
                            IconButton(
                              icon: Icon(Icons.pause_circle_filled,
                                  color: colors.primary),
                              onPressed: () {
                                ref.read(ttsProvider.notifier).pause();
                              },
                            ),
                          if (ttsPlayback == TtsPlaybackState.paused)
                            IconButton(
                              icon: Icon(Icons.play_circle_fill,
                                  color: colors.primary),
                              onPressed: () {
                                ref.read(ttsProvider.notifier).resume();
                              },
                            ),
                          IconButton(
                            icon: Icon(Icons.stop_circle,
                                color: colors.onSurfaceVariant),
                            onPressed: () {
                              ref.read(ttsProvider.notifier).stop();
                            },
                          ),
                        ],
                      )
                    else
                      IconButton(
                        icon: Icon(Icons.play_circle_fill,
                            color: colors.primary),
                        onPressed: () => _testSpeech(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
    );
  }

  void _testSpeech() {
    final text = 'Evaṃ me sutaṃ. Thus have I heard.';
    ref.read(ttsProvider.notifier).speak(text);
  }

  String _testButtonLabel(TtsPlaybackState state) {
    final loc = AppLocalizations.of(context);
    switch (state) {
      case TtsPlaybackState.playing:
        return loc.playing;
      case TtsPlaybackState.paused:
        return loc.paused;
      case TtsPlaybackState.loading:
        return loc.loadingDots;
      case TtsPlaybackState.stopped:
        return loc.testSpeech;
    }
  }

  String _testButtonSubtitle(TtsPlaybackState state) {
    final loc = AppLocalizations.of(context);
    switch (state) {
      case TtsPlaybackState.playing:
        return loc.tapPauseOrStop;
      case TtsPlaybackState.paused:
        return loc.tapResume;
      case TtsPlaybackState.loading:
        return loc.loadingAudio;
      case TtsPlaybackState.stopped:
        return loc.testHearSample;
    }
  }
}

// ── Speak Mode Tile ─────────────────────────────────────────────────────

class _SpeakModeTile extends StatelessWidget {
  final TtsSpeakMode mode;
  final String label;
  final String description;
  final IconData icon;
  final bool isSelected;
  final ColorScheme colors;
  final VoidCallback onTap;

  const _SpeakModeTile({
    required this.mode,
    required this.label,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md,
          vertical: AppDimensions.md,
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: isSelected ? colors.primary : colors.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: AppDimensions.md),
            Icon(icon, color: colors.primary, size: 20),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.labelMedium.copyWith(
                      color: isSelected ? colors.primary : colors.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  Text(
                    description,
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
  }
}

// ── Engine Selector ──────────────────────────────────────────────────────

class _EngineSelector extends StatelessWidget {
  final String currentEngine;
  final ColorScheme colors;
  final ValueChanged<String> onChanged;

  const _EngineSelector({
    required this.currentEngine,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Column(
      children: [
        _EngineOption(
          engine: 'system',
          label: loc.systemTts,
          description: loc.systemTtsDesc,
          icon: Icons.phone_android,
          isSelected: currentEngine == 'system',
          colors: colors,
          onTap: () => onChanged('system'),
        ),
        const Divider(height: 1, indent: AppDimensions.md, endIndent: AppDimensions.md),
        _EngineOption(
          engine: 'supertonic',
          label: loc.supertonic,
          description: loc.supertonicDesc,
          icon: Icons.auto_awesome,
          isSelected: currentEngine == 'supertonic',
          colors: colors,
          onTap: () => onChanged('supertonic'),
        ),
      ],
    );
  }
}

class _EngineOption extends StatelessWidget {
  final String engine;
  final String label;
  final String description;
  final IconData icon;
  final bool isSelected;
  final ColorScheme colors;
  final VoidCallback onTap;

  const _EngineOption({
    required this.engine,
    required this.label,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md,
          vertical: AppDimensions.md,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? colors.primary : colors.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: AppDimensions.md),
            Icon(icon, color: colors.primary, size: 20),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.labelMedium.copyWith(
                      color: isSelected ? colors.primary : colors.onSurface,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  Text(
                    description,
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
  }
}

// ── Supertonic Download Tile ─────────────────────────────────────────────

class _SupertonicDownloadTile extends StatelessWidget {
  final SupertonicDownloadState downloadState;
  final AppSettings settings;
  final ColorScheme colors;
  final VoidCallback onDownload;
  final VoidCallback onCancel;

  const _SupertonicDownloadTile({
    required this.downloadState,
    required this.settings,
    required this.colors,
    required this.onDownload,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isDownloaded = settings.ttsSupertonicDownloaded;
    final status = downloadState.status;
    final loc = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isDownloaded ? Icons.check_circle : Icons.cloud_download,
                color: isDownloaded ? Colors.green : colors.primary,
                size: 20,
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDownloaded ? loc.modelsInstalled : loc.ttsModels,
                      style: AppTypography.labelMedium.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    Text(
                      isDownloaded
                          ? loc.allModelsReady
                          : loc.requiresDownload,
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (status == SupertonicDownloadStatus.downloading)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: downloadState.progress > 0
                            ? downloadState.progress
                            : null,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: onCancel,
                      borderRadius: BorderRadius.circular(9999),
                      child: Icon(Icons.stop, color: colors.error, size: 20),
                    ),
                  ],
                )
              else if (!isDownloaded)
                InkWell(
                  onTap: status == SupertonicDownloadStatus.error
                      ? onDownload
                      : onDownload,
                  borderRadius: BorderRadius.circular(9999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
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
                          status == SupertonicDownloadStatus.error
                              ? loc.retry
                              : loc.download,
                          style: AppTypography.labelSmall.copyWith(
                            color: colors.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Icon(Icons.check_circle, color: Colors.green, size: 22),
            ],
          ),
          if (status == SupertonicDownloadStatus.downloading) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: downloadState.progress > 0 ? downloadState.progress : null,
              minHeight: 3,
              borderRadius: BorderRadius.circular(2),
              backgroundColor: colors.surfaceContainerHighest,
            ),
            const SizedBox(height: 4),
            Text(
              '${downloadState.filesDone}/${downloadState.filesTotal} ${loc.filesLabel}',
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
          if (status == SupertonicDownloadStatus.error &&
              downloadState.errorMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              downloadState.errorMessage!,
              style: AppTypography.labelSmall.copyWith(
                color: colors.error,
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Speed / Pitch Slider ─────────────────────────────────────────────────

class _SpeedSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final ColorScheme colors;
  final ValueChanged<double> onChanged;

  /// Optional override for the slider's title. When null, the title is
  /// derived from the min/max range (speed vs pitch).
  final String? caption;

  const _SpeedSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.colors,
    required this.onChanged,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                  _labelForSlider(context),
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ),
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: label,
            activeColor: colors.primary,
            inactiveColor: colors.outlineVariant,
            onChanged: onChanged,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _minLabel(context),
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                Text(
                  _maxLabel(context),
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

  String _labelForSlider(BuildContext context) {
    if (caption != null) return caption!;
    final loc = AppLocalizations.of(context);
    if (min == 0.5 && max == 4.0) return loc.speakingRate;
    return loc.ttPitch;
  }

  String _minLabel(BuildContext context) {
    if (min == 0.5 && max == 4.0) return '0.5×';
    return AppLocalizations.of(context).low;
  }

  String _maxLabel(BuildContext context) {
    if (min == 0.5 && max == 4.0) return '4.0×';
    return AppLocalizations.of(context).high;
  }
}

// ── Dropdown Tile ────────────────────────────────────────────────────────

class _DropdownTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final List<String> options;
  final String selectedValue;
  final ValueChanged<String> onSelected;
  final ColorScheme colors;

  const _DropdownTile({
    required this.icon,
    required this.title,
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
            child: Text(
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
                PopupMenuItem(
                  value: opt,
                  child: Text(opt),
                ),
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

// ── Voice options ────────────────────────────────────────────────────────

const _voiceOptions = [
  ('default', 'System Default'),
  ('female-1', 'Female Voice 1'),
  ('female-2', 'Female Voice 2'),
  ('male-1', 'Male Voice 1'),
  ('male-2', 'Male Voice 2'),
];

String _voiceLabel(String voice) {
  return _voiceOptions.firstWhere(
    (o) => o.$1 == voice,
    orElse: () => ('default', 'System Default'),
  ).$2;
}

/// Display label for a Supertonic quality preset ('low' | 'medium' | 'high').
String _qualityLabel(String quality) {
  switch (quality) {
    case 'low':
      return 'Low';
    case 'high':
      return 'High';
    default:
      return 'Medium';
  }
}

// ── Info Tile ───────────────────────────────────────────────────────────

/// A read-only settings tile (icon + title + subtitle, no interaction).
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final ColorScheme colors;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
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
                const SizedBox(height: 2),
                Text(
                  subtitle,
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
