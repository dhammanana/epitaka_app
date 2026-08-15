import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/settings_provider.dart';
import '../../settings/providers/tts_provider.dart';
import '../../settings/services/system_tts_settings.dart';
import 'reader_tts_widgets.dart';

/// Show the TTS controls popup dialog. The dialog handles its own voice
/// loading and caching internally.
///
/// [isTtsLineVisible] controls whether the "Follow TTS position" button is
/// shown: it only appears when the spoken line is NOT currently visible.
/// [onSpeakModeChanged] is invoked when the user switches between
/// Translation / Pāli / Both. The caller (reader) uses it to apply the
/// change immediately during playback (restart from the current paragraph)
/// instead of requiring a stop → play cycle.
Future<void> showTtsControlsDialog(
  BuildContext context, {
  required String bookId,
  required bool isTtsLineVisible,
  required VoidCallback onFollowTts,
  required ValueChanged<TtsSpeakMode> onSpeakModeChanged,
}) {
  return showDialog(
    context: context,
    builder: (_) => _TtsControlsDialog(
      bookId: bookId,
      isTtsLineVisible: isTtsLineVisible,
      onFollowTts: onFollowTts,
      onSpeakModeChanged: onSpeakModeChanged,
    ),
  );
}

class _TtsControlsDialog extends ConsumerStatefulWidget {
  final String bookId;
  final bool isTtsLineVisible;
  final VoidCallback onFollowTts;
  final ValueChanged<TtsSpeakMode> onSpeakModeChanged;

  const _TtsControlsDialog({
    required this.bookId,
    required this.isTtsLineVisible,
    required this.onFollowTts,
    required this.onSpeakModeChanged,
  });

  @override
  ConsumerState<_TtsControlsDialog> createState() => _TtsControlsDialogState();
}

class _TtsControlsDialogState extends ConsumerState<_TtsControlsDialog> {
  List<Map<String, String>>? _cachedVoices;
  bool _voicesLoading = false;

  @override
  void initState() {
    super.initState();
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    if (_cachedVoices != null || _voicesLoading) return;
    setState(() => _voicesLoading = true);
    try {
      final voices = await ref.read(ttsProvider.notifier).getVoices();
      if (mounted) setState(() => _cachedVoices = voices);
    } catch (_) {
      // Silently fail — voices list stays empty
    }
    if (mounted) setState(() => _voicesLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      // Bottom-anchored and content-sized: the floating offset is applied
      // via insetPadding (outside the dialog box), so the theme's bordered
      // shape hugs exactly the card content — no empty strip below the
      // card, and taps anywhere outside reach the barrier and dismiss.
      alignment: Alignment.bottomCenter,
      insetPadding: const EdgeInsets.fromLTRB(40, 24, 40, 80),
      child: Consumer(
        builder: (ctx, watchRef, _) {
          final settings = watchRef.watch(settingsProvider);
          // The TTS language = the language of the first enabled
          // translation. Only show voices that can actually speak it, so
          // the voice picker isn't flooded with irrelevant voices.
          final lang = settings.visibleTranslationLangs.isNotEmpty
              ? settings.visibleTranslationLangs.first
              : 'en';
          final voices = filterVoicesForLanguage(
            _cachedVoices ?? [],
            lang,
            selectedVoice: settings.ttsVoice,
          );
          // Set when the engine can't speak Sinhala and is reading Pāli
          // in a fallback script — tell the user instead of silently
          // skipping the Pāli lines.
          final paliNotice = watchRef
              .read(ttsProvider.notifier)
              .paliFallbackNotice;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (paliNotice != null) _TtsFallbackNotice(text: paliNotice),
              TtsControlsCard(
                colors: colors,
                settings: settings,
                isTtsLineVisible: widget.isTtsLineVisible,
                onFollowTap: () {
                  Navigator.of(ctx).pop();
                  widget.onFollowTts();
                },
                onSpeedChanged: (v) {
                  ref.read(settingsProvider.notifier).setTtsSpeed(v);
                },
                onPaliSpeedChanged: (v) {
                  ref.read(settingsProvider.notifier).setTtsPaliSpeed(v);
                },
                onPitchChanged: (v) {
                  ref.read(settingsProvider.notifier).setTtsPitch(v);
                },
                onVoiceChanged: (voice) {
                  ref.read(settingsProvider.notifier).setTtsVoice(voice);
                },
                onSpeakModeChanged: widget.onSpeakModeChanged,
                onInstallVoiceTap: () => openSystemTtsSettings(ctx),
                onSystemConfigTap: () {
                  Navigator.of(ctx).pop();
                  context.push('/settings/tts');
                },
                onClose: () => Navigator.of(ctx).pop(),
                voices: voices,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Small warning banner shown above the TTS controls when the engine had
/// to fall back from Sinhala for Pāli (no Sinhala voice on this device /
/// engine), so the user knows why Pāli isn't being read in Sinhala.
class _TtsFallbackNotice extends StatelessWidget {
  const _TtsFallbackNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, size: 16, color: colors.onErrorContainer),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: colors.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
