import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'reader_provider.dart';
import 'reader_tabs_provider.dart';

/// Controller for precise paragraph jumping in the reader.
class ReaderJumpController {
  final Ref _ref;

  ReaderJumpController(this._ref);

  /// Tracks the last paraId jumped to per book, to avoid re-jumping.
  final Map<String, int> lastJumpedParaId = {};

  /// Guards against overlapping jump attempts.
  final Map<String, int> _pendingJumpParaId = {};

  static const int _maxRetries = 30;
  static const int _kMaxTtsScrollRetries = 15;

  /// Jumps to the paragraph identified by [paraId] within [bookId].
  Future<bool> jumpToParagraph({
    required String bookId,
    required int paraId,
    required ItemScrollController controller,
    required Map<int, GlobalKey> ttsTargetLineKeys,
    required void Function(int lineId, GlobalKey key) onTtsLineKeyCreated,
    required void Function() onSuppressAppBarScroll,
    required void Function() onClearSuppressAppBarScroll,
    bool animate = true,
    double alignment = 0.0,
    int? lineId,
    int retryCount = 0,
  }) async {
    onSuppressAppBarScroll();
    _pendingJumpParaId[bookId] = paraId;

    var state = _ref.read(readerDataProvider(bookId));
    var index = state.paragraphs.indexWhere((p) => p.paraId == paraId);

    if (index < 0) {
      if (!state.isLoaded) {
        developer.log(
          '[JUMP] book=$bookId paraId=$paraId data still loading, waiting…',
          name: 'epitaka.reader',
        );
        await _ref.read(readerDataProvider(bookId).notifier).waitUntilLoaded();
        if (_pendingJumpParaId[bookId] != paraId) return false;

        state = _ref.read(readerDataProvider(bookId));
        index = state.paragraphs.indexWhere((p) => p.paraId == paraId);
      }
      if (index < 0) {
        developer.log(
          '[JUMP] book=$bookId paraId=$paraId not found',
          name: 'epitaka.reader',
        );
        return false;
      }
    }

    if (!controller.isAttached) {
      if (retryCount >= _maxRetries) {
        developer.log(
          '[JUMP] book=$bookId paraId=$paraId controller still not attached '
          'after $_maxRetries retries',
          name: 'epitaka.reader.ui',
        );
        return false;
      }
      await Future.delayed(const Duration(milliseconds: 16));
      return jumpToParagraph(
        bookId: bookId,
        paraId: paraId,
        controller: controller,
        ttsTargetLineKeys: ttsTargetLineKeys,
        onTtsLineKeyCreated: onTtsLineKeyCreated,
        onSuppressAppBarScroll: onSuppressAppBarScroll,
        onClearSuppressAppBarScroll: onClearSuppressAppBarScroll,
        animate: animate,
        alignment: alignment,
        lineId: lineId,
        retryCount: retryCount + 1,
      );
    }

    developer.log(
      '[JUMP] book=$bookId paraId=$paraId index=$index lineId=$lineId animate=$animate',
      name: 'epitaka.reader.ui',
    );

    lastJumpedParaId[bookId] = paraId;

    if (lineId != null) {
      onTtsLineKeyCreated(lineId, GlobalKey());
    }

    // ── Calculate alignment from line position ─────────────────────
    // When a lineId is provided, estimate the paragraph scroll
    // alignment so the target line appears at ~30% from the viewport
    // top. This way, even if the async fine-scroll fails (e.g. TTS
    // advances to the next line before Scrollable.ensureVisible's
    // retry loop completes), the paragraph-level scroll already
    // placed the correct line at a reasonable position instead of
    // snapping to alignment 0.0 (beginning of paragraph).
    final effectiveAlignment = () {
      if (lineId != null) {
        if (index >= 0 && index < state.paragraphs.length) {
          final para = state.paragraphs[index];
          final lineIndex = para.lines.indexWhere((l) => l.lineId == lineId);
          if (lineIndex >= 0 && para.lines.length > 1) {
            return ((lineIndex / (para.lines.length - 1)) * 0.3).clamp(0.0, 0.3);
          }
        }
      }
      return alignment;
    }();

    if (animate) {
      await controller.scrollTo(
        index: index,
        alignment: effectiveAlignment,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      controller.jumpTo(index: index, alignment: effectiveAlignment);
    }

    if (lineId != null) {
      scrollToLine(
        lineId: lineId,
        ttsTargetLineKeys: ttsTargetLineKeys,
        onClearSuppressAppBarScroll: onClearSuppressAppBarScroll,
      );
    }

    final tabsNotifier = _ref.read(readerTabsProvider.notifier);
    final tabsState = _ref.read(readerTabsProvider);
    final tabIndex = tabsState.tabs.indexWhere((t) => t.bookId == bookId);
    if (tabIndex >= 0) {
      tabsNotifier.clearInitialParaId(tabIndex);
    }
    _pendingJumpParaId.remove(bookId);

    developer.log(
      '[JUMP] book=$bookId paraId=$paraId COMPLETE',
      name: 'epitaka.reader.ui',
    );

    return true;
  }

  /// Fine-scroll to a specific line using Scrollable.ensureVisible.
  void scrollToLine({
    required int lineId,
    required Map<int, GlobalKey> ttsTargetLineKeys,
    required void Function() onClearSuppressAppBarScroll,
    int retries = 0,
  }) {
    final key = ttsTargetLineKeys[lineId];
    if (key == null) {
      onClearSuppressAppBarScroll();
      return;
    }

    void doScroll() {
      final lineContext = key.currentContext;
      if (lineContext != null && lineContext.mounted) {
        developer.log(
          '[TTS_LINE] Scrollable.ensureVisible line=$lineId',
          name: 'epitaka.tts',
        );
        Scrollable.ensureVisible(
          lineContext,
          alignment: 0.3,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        ).then((_) {
          ttsTargetLineKeys.remove(lineId);
          onClearSuppressAppBarScroll();
        });
      } else {
        if (retries >= _kMaxTtsScrollRetries) {
          ttsTargetLineKeys.remove(lineId);
          onClearSuppressAppBarScroll();
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          scrollToLine(
            lineId: lineId,
            ttsTargetLineKeys: ttsTargetLineKeys,
            onClearSuppressAppBarScroll: onClearSuppressAppBarScroll,
            retries: retries + 1,
          );
        });
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => doScroll());
  }

  /// Clear the pending jump guard for [bookId].
  void clearPendingJump(String bookId) {
    _pendingJumpParaId.remove(bookId);
  }
}

/// Provider for the jump controller service.
final readerJumpControllerProvider = Provider<ReaderJumpController>((ref) {
  return ReaderJumpController(ref);
});
