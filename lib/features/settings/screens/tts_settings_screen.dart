import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../providers/tts_provider.dart';
import '../providers/supertonic_download_provider.dart';
import '../services/system_tts_availability.dart';
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
  List<Map<String, String>>? _cachedVoices;
  bool _voicesLoading = false;

  @override
  void initState() {
    super.initState();
    // Check supertonic model status on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(supertonicDownloadProvider.notifier).areModelsReady().then((
        ready,
      ) {
        if (ready) {
          ref.read(settingsProvider.notifier).setTtsSupertonicDownloaded(true);
        }
      });
      _loadVoices();
    });
  }

  Future<void> _loadVoices() async {
    if (_cachedVoices != null || _voicesLoading) return;
    setState(() => _voicesLoading = true);
    try {
      final voices = await ref.read(ttsProvider.notifier).getVoices();
      if (mounted) setState(() => _cachedVoices = voices);
    } catch (_) {
      // Silently fail — voice pickers will show defaults
    }
    if (mounted) setState(() => _voicesLoading = false);
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
          style: AppTypography.headlineLarge.copyWith(color: colors.onSurface),
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

        // ── TTS Script/Language for Pāli ────────────────────────────
        // Choose which script/language to use for Pāli TTS.
        // Hindi (Sanskrit) enables Devanagari conversion + replacement text.
        // Other scripts use their natural script without replacement.
        SettingsSection(
          title: loc.ttsScriptLabel,
          colors: colors,
          children: [
            _TtsScriptSettingsTile(
              selectedScript: settings.ttsScript,
              colors: colors,
              onScriptChanged: (script) {
                ref.read(settingsProvider.notifier).setTtsScript(script);
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
            _VoiceStatusTile(
              colors: colors,
              langCode: settings.visibleTranslationLangs.isNotEmpty
                  ? settings.visibleTranslationLangs.first
                  : 'en',
              label: loc.ttsTranslationVoice,
            ),
            _VoiceStatusTile(
              colors: colors,
              langCode: settings.ttsScript,
              label: loc.ttsPaliVoice,
            ),
            _EngineTile(colors: colors),
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
                  value: _supertonicVoices
                      .firstWhere(
                        (v) => v.$1 == settings.ttsSupertonicVoice,
                        orElse: () => ('M1', 'Male Voice 1'),
                      )
                      .$2,
                  options: _supertonicVoices.map((v) => v.$2).toList(),
                  selectedValue: _supertonicVoices
                      .firstWhere(
                        (v) => v.$1 == settings.ttsSupertonicVoice,
                        orElse: () => ('M1', 'Male Voice 1'),
                      )
                      .$2,
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

        // ── Pāli speed + voice ────────────────────────────────────────
        if (!isSupertonic) ...[
          SettingsSection(
            title: loc.ttsPaliSpeed,
            colors: colors,
            children: [
              _SpeedSlider(
                value: settings.ttsPaliSpeed,
                min: 0.1,
                max: 3.0,
                // 29 divisions → clean 0.1 steps across the 0.1–3.0 range.
                divisions: 29,
                label: '${settings.ttsPaliSpeed.toStringAsFixed(1)}×',
                colors: colors,
                onChanged: (v) {
                  ref.read(settingsProvider.notifier).setTtsPaliSpeed(v);
                },
              ),
              const Divider(
                height: 1,
                indent: AppDimensions.md,
                endIndent: AppDimensions.md,
              ),
              // Pāli voice for the chosen Pāli TTS script — separate
              // from the translation voice so users can pick the best
              // voice for Pāli pronunciation.
              _RealVoiceTile(
                icon: Icons.record_voice_over,
                title: loc.ttsPaliVoice,
                selectedVoice: settings.ttsPaliVoice,
                langCode: settings.ttsScript,
                allVoices: _cachedVoices ?? const [],
                loading: _voicesLoading,
                colors: colors,
                showNoVoiceHint: true,
                onVoiceChanged: (name) {
                  ref.read(settingsProvider.notifier).setTtsPaliVoice(name);
                },
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
        ],

        // ── Translation speed + voice ────────────────────────────────
        SettingsSection(
          title: loc.ttsTranslationSpeed,
          colors: colors,
          children: [
            _SpeedSlider(
              value: settings.ttsSpeed,
              min: 0.5,
              max: 8.0,
              divisions: 71,
              label: '${settings.ttsSpeed.toStringAsFixed(1)}×',
              colors: colors,
              onChanged: (v) {
                ref.read(settingsProvider.notifier).setTtsSpeed(v);
              },
            ),
            if (!isSupertonic) ...[
              const Divider(
                height: 1,
                indent: AppDimensions.md,
                endIndent: AppDimensions.md,
              ),
              _RealVoiceTile(
                icon: Icons.record_voice_over,
                title: loc.ttsTranslationVoice,
                selectedVoice: settings.ttsVoice,
                langCode: settings.visibleTranslationLangs.isNotEmpty
                    ? settings.visibleTranslationLangs.first
                    : 'en',
                allVoices: _cachedVoices ?? const [],
                loading: _voicesLoading,
                colors: colors,
                onVoiceChanged: (name) {
                  ref.read(settingsProvider.notifier).setTtsVoice(name);
                },
              ),
            ],
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
                            icon: Icon(
                              Icons.pause_circle_filled,
                              color: colors.primary,
                            ),
                            onPressed: () {
                              ref.read(ttsProvider.notifier).pause();
                            },
                          ),
                        if (ttsPlayback == TtsPlaybackState.paused)
                          IconButton(
                            icon: Icon(
                              Icons.play_circle_fill,
                              color: colors.primary,
                            ),
                            onPressed: () {
                              ref.read(ttsProvider.notifier).resume();
                            },
                          ),
                        IconButton(
                          icon: Icon(
                            Icons.stop_circle,
                            color: colors.onSurfaceVariant,
                          ),
                          onPressed: () {
                            ref.read(ttsProvider.notifier).stop();
                          },
                        ),
                      ],
                    )
                  else
                    IconButton(
                      icon: Icon(Icons.play_circle_fill, color: colors.primary),
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
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
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
        const Divider(
          height: 1,
          indent: AppDimensions.md,
          endIndent: AppDimensions.md,
        ),
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
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
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
                      isDownloaded ? loc.allModelsReady : loc.requiresDownload,
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
                      horizontal: 14,
                      vertical: 6,
                    ),
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
    if (min == 0.5 && max == 8.0) return '0.5×';
    return AppLocalizations.of(context).low;
  }

  String _maxLabel(BuildContext context) {
    if (min == 0.5 && max == 8.0) return '8.0×';
    if (min == 0.1 && max == 8.0) return '8.0×';
    if (min == 0.1 && max == 3.0) return '3.0×';
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

// ── Voice options ────────────────────────────────────────────────────────

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

// ── Real Voice Picker ────────────────────────────────────────────────────

/// A voice picker tile that shows real system TTS voices filtered by
/// language. Uses the same voice list as the reader's TTS controls dialog.
class _RealVoiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String selectedVoice;
  final String langCode;
  final List<Map<String, String>> allVoices;
  final bool loading;
  final ColorScheme colors;
  final ValueChanged<String> onVoiceChanged;

  /// When true and no voices match [langCode], shows a warning hint
  /// instead of a near-empty popup.
  final bool showNoVoiceHint;

  const _RealVoiceTile({
    required this.icon,
    required this.title,
    required this.selectedVoice,
    required this.langCode,
    required this.allVoices,
    required this.loading,
    required this.colors,
    required this.onVoiceChanged,
    this.showNoVoiceHint = false,
  });

  /// Short display name of a Pāli TTS script code for the
  /// "voice not installed" hint (matches the script dropdown labels).
  static String _scriptShortLabel(String code) => switch (code) {
    'kn' => 'Kannada',
    'te' => 'Telugu',
    'si' => 'Sinhala',
    'hi' => 'Hindi',
    _ => code,
  };

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    // Filter voices to the target language.
    final lc = langCode.toLowerCase();
    final filtered = allVoices.where((v) {
      final vLoc = (v['locale'] ?? '').toLowerCase();
      return vLoc == lc || vLoc.startsWith('$lc-') || vLoc.startsWith('${lc}_');
    }).toList();
    // Always include the selected voice even if it doesn't match the
    // language filter (e.g. after switching languages).
    if (selectedVoice.isNotEmpty &&
        selectedVoice != 'default' &&
        !filtered.any((v) => v['name'] == selectedVoice)) {
      final sel = allVoices.where((v) => v['name'] == selectedVoice).toList();
      if (sel.isNotEmpty) filtered.insert(0, sel.first);
    }

    final displayName = _voiceDisplayName(selectedVoice, filtered, loc);

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
          if (loading)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.onSurfaceVariant,
              ),
            )
          else if (filtered.isEmpty &&
              showNoVoiceHint &&
              selectedVoice == 'default')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colors.errorContainer,
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber, size: 12, color: colors.error),
                  const SizedBox(width: 4),
                  Text(
                    loc.ttsVoiceNotInstalledFor(_scriptShortLabel(langCode)),
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.error,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            )
          else
            PopupMenuButton<String>(
              initialValue: selectedVoice,
              onSelected: onVoiceChanged,
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'default',
                  child: Text(loc.systemDefault),
                ),
                for (final v in filtered)
                  PopupMenuItem<String>(
                    value: v['name'] ?? 'default',
                    child: Text(
                      v['name'] ?? loc.unknown,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color: colors.onSurfaceVariant,
                    size: 18,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _voiceDisplayName(
    String selected,
    List<Map<String, String>> filtered,
    AppLocalizations loc,
  ) {
    if (selected.isEmpty || selected == 'default') {
      return loc.systemDefault;
    }
    final match = filtered.firstWhere(
      (v) => v['name'] == selected,
      orElse: () => const {},
    );
    return match['name'] ?? loc.systemDefault;
  }
}

class _VoiceStatusTile extends ConsumerStatefulWidget {
  const _VoiceStatusTile({
    required this.colors,
    required this.langCode,
    required this.label,
  });

  final ColorScheme colors;
  final String langCode;
  final String label;

  @override
  ConsumerState<_VoiceStatusTile> createState() => _VoiceStatusTileState();
}

class _VoiceStatusTileState extends ConsumerState<_VoiceStatusTile> {
  TtsLanguageCheck? _check;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant _VoiceStatusTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.langCode != widget.langCode) _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final check = await ref
          .read(ttsProvider.notifier)
          .refreshLanguageCheck(widget.langCode);
      if (mounted) setState(() => _check = check);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final status = _check?.status;
    final ready = status == TtsVoiceStatus.ready;
    final needsDownload = status == TtsVoiceStatus.needsDownload;
    final notSupported = status == TtsVoiceStatus.notSupported;
    final subtitle = _loading
        ? loc.loadingDots
        : ready
        ? '${widget.label}: OK'
        : needsDownload
        ? '${widget.label}: ${loc.ttsVoiceNotInstalledFor(widget.langCode)}'
        : notSupported
        ? '${widget.label}: not supported by this engine'
        : '${widget.label}: ${_check?.status.name ?? loc.loadingDots}';
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.md,
      ),
      child: Row(
        children: [
          Icon(
            ready ? Icons.check_circle : Icons.warning_amber,
            color: ready ? Colors.green : widget.colors.error,
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Text(
              subtitle,
              style: AppTypography.labelSmall.copyWith(
                color: ready
                    ? widget.colors.onSurfaceVariant
                    : widget.colors.error,
              ),
            ),
          ),
          if (needsDownload || notSupported)
            TextButton(
              onPressed: () => openSystemTtsSettings(context),
              child: Text(loc.ttsInstallVoice),
            )
          else if (!_loading)
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: _refresh,
            ),
        ],
      ),
    );
  }
}

class _EngineTile extends ConsumerStatefulWidget {
  const _EngineTile({required this.colors});

  final ColorScheme colors;

  @override
  ConsumerState<_EngineTile> createState() => _EngineTileState();
}

class _EngineTileState extends ConsumerState<_EngineTile> {
  List<String> _engines = const [];
  String? _defaultEngine;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final notifier = ref.read(ttsProvider.notifier);
      final engines = await notifier.getEngines();
      final def = await notifier.getDefaultEngine();
      if (mounted) {
        setState(() {
          _engines = engines;
          _defaultEngine = def;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_engines.isEmpty) return const SizedBox.shrink();
    final short = _engines.map((e) {
      final parts = e.split('.');
      return parts.isNotEmpty ? parts.last : e;
    }).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.md,
      ),
      child: Row(
        children: [
          Icon(Icons.settings_voice, color: widget.colors.primary),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TTS Engine',
                  style: AppTypography.labelMedium.copyWith(
                    color: widget.colors.onSurface,
                  ),
                ),
                Text(
                  _defaultEngine ?? _engines.first,
                  style: AppTypography.labelSmall.copyWith(
                    color: widget.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (_engines.length > 1)
            PopupMenuButton<String>(
              initialValue: _defaultEngine,
              onSelected: (name) async {
                await ref.read(ttsProvider.notifier).setEngine(name);
                _refresh();
              },
              itemBuilder: (context) => [
                for (var i = 0; i < _engines.length; i++)
                  PopupMenuItem<String>(
                    value: _engines[i],
                    child: Text(short[i], overflow: TextOverflow.ellipsis),
                  ),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Switch',
                    style: AppTypography.labelSmall.copyWith(
                      color: widget.colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color: widget.colors.onSurfaceVariant,
                    size: 18,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
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

// ── TTS Script Settings Tile ─────────────────────────────────────────────

/// Settings tile for selecting the TTS script/language for Pāli.
class _TtsScriptSettingsTile extends StatelessWidget {
  final String selectedScript;
  final ColorScheme colors;
  final ValueChanged<String> onScriptChanged;

  const _TtsScriptSettingsTile({
    required this.selectedScript,
    required this.colors,
    required this.onScriptChanged,
  });

  static const _scriptOptions = [
    ('kn', 'Kannada'),
    ('te', 'Telugu'),
    ('si', 'Sinhala'),
    ('hi', 'Hindi (Sanskrit)'),
  ];

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final selectedLabel = _scriptOptions
        .firstWhere(
          (opt) => opt.$1 == selectedScript,
          orElse: () => _scriptOptions.last,
        )
        .$2;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.language, color: colors.primary),
      title: Text(
        loc.ttsScriptLabel,
        style: AppTypography.labelMedium.copyWith(color: colors.onSurface),
      ),
      subtitle: Text(
        selectedLabel,
        style: AppTypography.labelSmall.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
      trailing: PopupMenuButton<String>(
        initialValue: selectedScript,
        onSelected: onScriptChanged,
        itemBuilder: (context) => [
          for (final opt in _scriptOptions)
            PopupMenuItem<String>(
              value: opt.$1,
              child: Row(
                children: [
                  if (opt.$1 == selectedScript)
                    Icon(Icons.check, size: 18, color: colors.primary),
                  if (opt.$1 == selectedScript) const SizedBox(width: 8),
                  Expanded(
                    child: Text(opt.$2, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
        ],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedLabel,
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: colors.onSurfaceVariant, size: 18),
          ],
        ),
      ),
    );
  }
}
