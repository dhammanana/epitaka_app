import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/tts_provider.dart';
import '../providers/supertonic_download_provider.dart';
import '../widgets/settings_app_bar.dart';
import '../widgets/settings_section.dart';

/// Languages supported by Supertonic TTS.
const _supertonicLanguages = [
  ('en', 'English'),
  ('th', 'Thai'),
  ('si', 'Sinhala'),
  ('my', 'Burmese'),
  ('bn', 'Bengali'),
  ('de', 'German'),
  ('es', 'Spanish'),
  ('fr', 'French'),
  ('hi', 'Hindi'),
  ('id', 'Indonesian'),
  ('ja', 'Japanese'),
  ('jv', 'Javanese'),
  ('km', 'Khmer'),
  ('ko', 'Korean'),
  ('lo', 'Lao'),
  ('ml', 'Malayalam'),
  ('mn', 'Mongolian'),
  ('ms', 'Malay'),
  ('ne', 'Nepali'),
  ('nl', 'Dutch'),
  ('pt', 'Portuguese'),
  ('ru', 'Russian'),
  ('ta', 'Tamil'),
  ('te', 'Telugu'),
  ('tr', 'Turkish'),
  ('ur', 'Urdu'),
  ('vi', 'Vietnamese'),
  ('zh', 'Chinese'),
];

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
class TtsSettingsScreen extends ConsumerStatefulWidget {
  const TtsSettingsScreen({super.key});

  @override
  ConsumerState<TtsSettingsScreen> createState() => _TtsSettingsScreenState();
}

class _TtsSettingsScreenState extends ConsumerState<TtsSettingsScreen> {
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
    final downloadState = ref.watch(supertonicDownloadProvider);
    final ttsPlayback = ref.watch(ttsProvider);

    final isSupertonic = settings.ttsEngine == 'supertonic';

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
            'Text-to-Speech',
            style: AppTypography.headlineLarge.copyWith(
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: AppDimensions.lg),

          // ── Engine Selection ─────────────────────────────────────────
          SettingsSection(
            title: 'Engine',
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

          // ── Supertonic: Download & Setup ─────────────────────────────
          if (isSupertonic) ...[
            SettingsSection(
              title: 'Model Download',
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
              // Language selection
              SettingsSection(
                title: 'Language',
                colors: colors,
                children: [
                  _DropdownTile(
                    icon: Icons.language,
                    title: 'TTS Language',
                    value: _supertonicLanguages.firstWhere(
                      (l) => l.$1 == settings.ttsSupertonicLanguage,
                      orElse: () => ('en', 'English'),
                    ).$2,
                    options: _supertonicLanguages.map((l) => l.$2).toList(),
                    selectedValue: _supertonicLanguages.firstWhere(
                      (l) => l.$1 == settings.ttsSupertonicLanguage,
                      orElse: () => ('en', 'English'),
                    ).$2,
                    onSelected: (label) {
                      final entry = _supertonicLanguages.firstWhere(
                        (l) => l.$2 == label,
                        orElse: () => ('en', 'English'),
                      );
                      ref
                          .read(settingsProvider.notifier)
                          .setTtsSupertonicLanguage(entry.$1);
                    },
                    colors: colors,
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.md),

              // Voice style selection
              SettingsSection(
                title: 'Voice Style',
                colors: colors,
                children: [
                  _DropdownTile(
                    icon: Icons.record_voice_over,
                    title: 'Voice',
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
            ],
          ],

          // ── System TTS voice ─────────────────────────────────────────
          if (!isSupertonic) ...[
            SettingsSection(
              title: 'Voice',
              colors: colors,
              children: [
                _DropdownTile(
                  icon: Icons.record_voice_over,
                  title: 'Voice',
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
            title: 'Speed',
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
            ],
          ),
          const SizedBox(height: AppDimensions.md),

          // ── Pitch ────────────────────────────────────────────────────
          SettingsSection(
            title: 'Pitch',
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
            title: 'Preview',
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
      ),
    );
  }

  void _testSpeech() {
    final text = 'Evaṃ me sutaṃ. Thus have I heard.';
    ref.read(ttsProvider.notifier).speak(text);
  }

  String _testButtonLabel(TtsPlaybackState state) {
    switch (state) {
      case TtsPlaybackState.playing:
        return 'Playing…';
      case TtsPlaybackState.paused:
        return 'Paused';
      case TtsPlaybackState.loading:
        return 'Loading…';
      case TtsPlaybackState.stopped:
        return 'Test Speech';
    }
  }

  String _testButtonSubtitle(TtsPlaybackState state) {
    switch (state) {
      case TtsPlaybackState.playing:
        return 'Tap pause or stop to control playback';
      case TtsPlaybackState.paused:
        return 'Tap resume to continue';
      case TtsPlaybackState.loading:
        return 'Preparing audio…';
      case TtsPlaybackState.stopped:
        return 'Hear a sample of the current voice & settings';
    }
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
    return Column(
      children: [
        _EngineOption(
          engine: 'system',
          label: 'System TTS',
          description: 'Platform-native text-to-speech (fast, no download)',
          icon: Icons.phone_android,
          isSelected: currentEngine == 'system',
          colors: colors,
          onTap: () => onChanged('system'),
        ),
        const Divider(height: 1, indent: AppDimensions.md, endIndent: AppDimensions.md),
        _EngineOption(
          engine: 'supertonic',
          label: 'SuperTonic',
          description: 'Neural TTS with 31 languages (~400 MB model download)',
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
                      isDownloaded ? 'Models Installed' : 'TTS Models',
                      style: AppTypography.labelMedium.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    Text(
                      isDownloaded
                          ? 'All models are ready for use'
                          : 'Requires ~400 MB download for neural TTS',
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
                              ? 'Retry'
                              : 'Download',
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
              '${downloadState.filesDone}/${downloadState.filesTotal} files',
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

  const _SpeedSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.colors,
    required this.onChanged,
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
                  _labelForSlider(),
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
                  _minLabel(),
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                Text(
                  _maxLabel(),
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

  String _labelForSlider() {
    if (min == 0.5 && max == 4.0) return 'Speaking Rate';
    return 'Pitch';
  }

  String _minLabel() {
    if (min == 0.5 && max == 4.0) return '0.5×';
    return 'Low';
  }

  String _maxLabel() {
    if (min == 0.5 && max == 4.0) return '4.0×';
    return 'High';
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
