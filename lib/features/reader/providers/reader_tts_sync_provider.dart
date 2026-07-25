import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// TTS sync state for a single book tab.
class TtsSyncState {
  final bool ttsAutoScroll;
  final bool ttsJumpInProgress;
  final int? ttsTargetParaId;

  const TtsSyncState({
    this.ttsAutoScroll = true,
    this.ttsJumpInProgress = false,
    this.ttsTargetParaId,
  });

  TtsSyncState copyWith({
    bool? ttsAutoScroll,
    bool? ttsJumpInProgress,
    int? ttsTargetParaId,
    bool clearTtsTargetParaId = false,
  }) {
    return TtsSyncState(
      ttsAutoScroll: ttsAutoScroll ?? this.ttsAutoScroll,
      ttsJumpInProgress: ttsJumpInProgress ?? this.ttsJumpInProgress,
      ttsTargetParaId:
          clearTtsTargetParaId
              ? null
              : (ttsTargetParaId ?? this.ttsTargetParaId),
    );
  }
}

/// Notifier that manages TTS auto-scroll sync for a single book tab.
class TtsSyncNotifier extends StateNotifier<TtsSyncState> {
  Timer? _ttsJumpTimer;

  TtsSyncNotifier() : super(const TtsSyncState());

  /// Whether the current tab is the active TTS book. Set by widget layer.
  bool isActiveTtsTab = false;

  /// Called when the TTS paragraph is scrolled out of visible range
  /// by manual scrolling. Disables auto-scroll.
  void disableAutoScroll() {
    if (state.ttsAutoScroll) {
      developer.log(
        '[TTS_SYNC] disableAutoScroll: user scrolled away from TTS position',
        name: 'epitaka.tts',
      );
      state = state.copyWith(ttsAutoScroll: false);
    }
  }

  /// Re-enable TTS auto-scroll (e.g. user tapped "Follow TTS").
  void enableAutoScroll() {
    state = state.copyWith(ttsAutoScroll: true);
  }

  /// Set the TTS jump-in-progress flag with a timer to auto-clear.
  void setJumpInProgress() {
    developer.log('[TTS_SYNC] setJumpInProgress', name: 'epitaka.tts');
    state = state.copyWith(ttsJumpInProgress: true);
    _ttsJumpTimer?.cancel();
    _ttsJumpTimer = Timer(const Duration(milliseconds: 800), () {
      state = state.copyWith(ttsJumpInProgress: false);
    });
  }

  /// Set the target paraId for TTS line highlighting.
  void setTargetParaId(int paraId) {
    state = state.copyWith(ttsTargetParaId: paraId);
  }

  /// Clear the target paraId (after fine-scroll completes).
  void clearTargetParaId() {
    state = state.copyWith(clearTtsTargetParaId: true);
  }

  /// Cancel the jump timer immediately.
  void cancelJumpTimer() {
    _ttsJumpTimer?.cancel();
    _ttsJumpTimer = null;
    state = state.copyWith(ttsJumpInProgress: false);
  }

  @override
  void dispose() {
    _ttsJumpTimer?.cancel();
    _ttsJumpTimer = null;
    super.dispose();
  }
}

/// Provider for TTS sync state, scoped per bookId (family).
/// Uses autoDispose so state is cleaned up when the tab is closed.
final ttsSyncProvider = StateNotifierProvider.autoDispose.family<
    TtsSyncNotifier,
    TtsSyncState,
    String>(
  (ref, bookId) => TtsSyncNotifier(),
);
