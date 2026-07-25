import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../settings/providers/tts_provider.dart';
import 'reader_tts_widgets.dart';

/// Show the TTS controls popup dialog. The dialog handles its own voice
/// loading and caching internally.
Future<void> showTtsControlsDialog(
  BuildContext context, {
  required String bookId,
  required VoidCallback onFollowTts,
}) {
  return showDialog(
    context: context,
    builder: (_) => _TtsControlsDialog(
      bookId: bookId,
      onFollowTts: onFollowTts,
    ),
  );
}

class _TtsControlsDialog extends ConsumerStatefulWidget {
  final String bookId;
  final VoidCallback onFollowTts;

  const _TtsControlsDialog({
    required this.bookId,
    required this.onFollowTts,
  });

  @override
  ConsumerState<_TtsControlsDialog> createState() =>
      _TtsControlsDialogState();
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
      child: Consumer(
        builder: (ctx, watchRef, _) {
          final settings = watchRef.watch(settingsProvider);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Spacer(),
              TtsControlsCard(
                colors: colors,
                settings: settings,
                isTtsLineVisible:
                    false, // Not needed here — always shows follow button
                onFollowTap: () {
                  Navigator.of(ctx).pop();
                  widget.onFollowTts();
                },
                onSpeedChanged: (v) {
                  ref
                      .read(settingsProvider.notifier)
                      .setTtsSpeed(v);
                },
                onPitchChanged: (v) {
                  ref
                      .read(settingsProvider.notifier)
                      .setTtsPitch(v);
                },
                onVoiceChanged: (voice) {
                  ref
                      .read(settingsProvider.notifier)
                      .setTtsVoice(voice);
                },
                onSystemConfigTap: () {
                  Navigator.of(ctx).pop();
                  context.push('/settings/tts');
                },
                onClose: () => Navigator.of(ctx).pop(),
                voices: _cachedVoices ?? [],
              ),
            ],
          );
        },
      ),
    );
  }
}
