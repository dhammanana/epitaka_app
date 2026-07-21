part of 'reader_screen.dart';

/// TTS (Text-To-Speech) control state and methods for the reader screen.
///
/// Manages TTS auto-scroll, jump-in-progress flags, voice caching,
/// and all TTS control actions (play/pause/stop/rewind/forward).
mixin ReaderTtsMixin on ConsumerState<ReaderScreen> {
  // ── TTS state ───────────────────────────────────────────────────────
  bool _ttsAutoScroll = true;
  bool _ttsJumpInProgress = false;
  Timer? _ttsJumpTimer;
  List<Map<String, String>>? _cachedSystemVoices;
  bool _voicesLoading = false;

  // ═════════════════════════════════════════════════════════════════════
  // TTS LINE VISIBILITY
  // ═════════════════════════════════════════════════════════════════════

  bool _isTtsLineVisible(String bookId, int? ttsParaId) {
    if (ttsParaId == null) return false;
    final listener = _itemPositionsListeners[bookId];
    final positions = listener?.itemPositions.value;
    if (positions == null || positions.isEmpty) return false;

    final visibleIndices =
        positions.where((p) => p.itemTrailingEdge > 0).map((p) => p.index).toSet();
    if (visibleIndices.isEmpty) return false;

    final readerState = ref.read(readerDataProvider(bookId));
    for (final idx in visibleIndices) {
      if (idx >= 0 && idx < readerState.paragraphs.length) {
        if (readerState.paragraphs[idx].paraId == ttsParaId) return true;
      }
    }
    return false;
  }

  // ═════════════════════════════════════════════════════════════════════
  // TTS CONTROLS POPUP
  // ═════════════════════════════════════════════════════════════════════

  Future<void> _showTtsControlsPopup(
    BuildContext context,
    String bookId,
  ) async {
    final colors = Theme.of(context).colorScheme;
    final ttsReadingState = ref.read(ttsReadingProvider);
    final isTtsLineVisible =
        _isTtsLineVisible(bookId, ttsReadingState.currentParaId);

    if (_cachedSystemVoices == null && !_voicesLoading) {
      _voicesLoading = true;
      try {
        final voices = await ref.read(ttsProvider.notifier).getVoices();
        _cachedSystemVoices = voices;
      } catch (_) {}
      _voicesLoading = false;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Consumer(
            builder: (context, watchRef, child) {
              final s = watchRef.watch(settingsProvider);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Spacer(),
                  TtsControlsCard(
                    isTtsLineVisible: isTtsLineVisible,
                    isJumpPending: _ttsJumpInProgress,
                    currentSpeed: s.ttsSpeed,
                    currentPitch: s.ttsPitch,
                    currentVoice: s.ttsVoice,
                    onPlayPause: () => _ttsPlayPause(bookId),
                    onStop: () => _ttsStop(bookId),
                    onRewind: () => _ttsRewind(bookId),
                    onForward: () => _ttsForward(bookId),
                    onFollowTap: () => _followTts(bookId),
                    onSpeedChanged: (v) =>
                        ref.read(settingsProvider.notifier).setTtsSpeed(v),
                    onPitchChanged: (v) =>
                        ref.read(settingsProvider.notifier).setTtsPitch(v),
                    onVoiceChanged: (v) =>
                        ref.read(settingsProvider.notifier).setTtsVoice(v),
                    onSystemConfigTap: () {
                      Navigator.of(dialogContext).pop();
                      context.push('/settings/tts');
                    },
                    onClose: () => Navigator.of(dialogContext).pop(),
                    voices: _cachedSystemVoices ?? [],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // TTS ACTIONS
  // ═════════════════════════════════════════════════════════════════════

  void _followTts(String bookId) {
    _ttsAutoScroll = true;
    _setTtsJumpInProgress();
    final ttsState = ref.read(ttsReadingProvider);
    if (ttsState.currentParaId != null) {
      _jumpToParagraph(
        bookId,
        ttsState.currentParaId!,
        lineId: ttsState.currentLineId,
      );
    }
  }

  void _setTtsJumpInProgress() {
    developer.log('[TTS] _setTtsJumpInProgress', name: 'epitaka.tts');
    _ttsJumpInProgress = true;
    _ttsJumpTimer?.cancel();
    _ttsJumpTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) _ttsJumpInProgress = false;
    });
  }

  void _ttsPlayPause(String bookId) {
    final ttsState = ref.read(ttsReadingProvider);
    if (ttsState.isActive) {
      ref.read(ttsReadingProvider.notifier).pause();
    } else {
      ref
          .read(ttsReadingProvider.notifier)
          .start(bookId, ref.read(readerDataProvider(bookId)));
    }
  }

  void _ttsStop(String bookId) {
    ref.read(ttsReadingProvider.notifier).stop();
  }

  void _ttsRewind(String bookId) {
    final ttsState = ref.read(ttsReadingProvider);
    if (ttsState.currentParaId != null) {
      _setTtsJumpInProgress();
      ref
          .read(ttsReadingProvider.notifier)
          .jumpToParagraph(ttsState.currentParaId! - 1);
    }
  }

  void _ttsForward(String bookId) {
    final ttsState = ref.read(ttsReadingProvider);
    if (ttsState.currentParaId != null) {
      _setTtsJumpInProgress();
      ref
          .read(ttsReadingProvider.notifier)
          .jumpToParagraph(ttsState.currentParaId! + 1);
    }
  }
}
