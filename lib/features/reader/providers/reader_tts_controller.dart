// lib/features/reader/providers/reader_tts_controller.dart
//
// TTS → reader coordination, extracted from _ReaderScreenState so the screen
// only wires UI and delegates. This controller owns:
//
//   * building the TTS line list and starting/stopping reading,
//   * the TTS floating controls dialog + system-voices cache,
//   * "follow TTS" (re-enable auto-scroll + jump to the spoken line),
//   * reacting to [ttsReadingProvider] changes (force line-by-line display
//     mode while playing, save reading history, auto-scroll to the spoken
//     line via fine-scroll/jump),
//   * disabling auto-scroll when the user manually scrolls the spoken
//     paragraph out of the visible range.
//
// It holds no Flutter widget state of its own. Scrolling is delegated back
// to the screen through injected callbacks so the exact jump/fine-scroll
// machinery (ItemScrollController lifecycle, jump tokens, app-bar
// suppression) stays in one place.

import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../core/database/app_database.dart' show TtsReplacement;
import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/pali_script_converter.dart';
import '../../settings/providers/tts_replacements_provider.dart';
import '../providers/reader_provider.dart';
import '../providers/reader_tabs_provider.dart';
import '../providers/reader_tts_sync_provider.dart';
import '../providers/tts_reading_provider.dart';
import '../utils/reader_position_utils.dart' as position_utils;
import '../widgets/reader_tts_controls_dialog.dart';
import '../widgets/reader_tts_widgets.dart' show stripHtmlForTts;

/// Coordinates TTS playback with the reader UI.
class ReaderTtsController {
  ReaderTtsController({
    required this.ref,
    required this.isMounted,
    required this.isAppResumed,
    required this.positionsFor,
    required this.jumpToParagraph,
    required this.fineScrollToLine,
    required this.nextJumpToken,
    required this.saveHistory,
    required this.requestRebuild,
  });

  /// Riverpod reference for provider reads/writes.
  final WidgetRef ref;

  /// Whether the owning screen is still mounted (guards async callbacks).
  final bool Function() isMounted;

  /// Whether the app lifecycle state is `resumed` (TTS UI only follows
  /// while the app is foregrounded).
  final bool Function() isAppResumed;

  /// Returns the item positions of the reader list for [bookId], or null
  /// when the tab has no mounted list yet.
  final Iterable<ItemPosition>? Function(String bookId) positionsFor;

  /// Scroll the reader to [paraId] (see the screen's `_jumpToParagraph`).
  final Future<void> Function(
    String bookId,
    int paraId, {
    bool animate,
    double alignment,
    int? lineId,
  }) jumpToParagraph;

  /// Fine-scroll to a specific line inside the current paragraph (see the
  /// screen's `_fineScrollToLine`).
  final void Function(String bookId, int lineId, {required int jumpToken})
  fineScrollToLine;

  /// Allocate a fresh jump token for [bookId] so stale fine-scrolls from a
  /// superseded jump can't clear newer jump flags.
  final int Function(String bookId) nextJumpToken;

  /// Persist the reading position (debounced by the caller).
  final void Function(
    String bookId,
    String? bookName, {
    int? explicitParaId,
    int? explicitLineId,
  }) saveHistory;

  /// Request a rebuild of the owning screen (guarded by [isMounted]).
  final VoidCallback requestRebuild;

  /// Reader display mode before TTS started, restored when reading stops.
  ///
  /// TTS temporarily forces [TranslationDisplayMode.lineByLine] because it
  /// is the only display mode that renders per-line widgets — and therefore
  /// the only one where the per-line GlobalKeys used by the fine-scroll can
  /// be attached. null = TTS is not forcing a mode.
  TranslationDisplayMode? _ttsModeBefore;

  /// Build the TTS line list for [activeTab] starting at the first visible
  /// paragraph and start reading.
  ///
  /// What gets spoken follows [TtsSpeakMode]: the (first enabled)
  /// translation, the Pāli (converted to Sinhala script for accurate
  /// pronunciation), or both. Applies the user's TTS replacement rules to
  /// each translation line.
  /// No-op when no translation language is enabled.
  Future<void> startListening(
    ReaderTabInfo activeTab,
    ReaderDataState readerState,
  ) async {
    final positions = positionsFor(activeTab.bookId);
    int startParaIndex = 0;

    // Use canonical viewport-aware paragraph resolution so the beginning
    // paragraph of the current screen is accurately detected across platforms
    // (accounting for app bar collapse, header insets, and safe areas).
    final currentParaId =
        position_utils.getCurrentParaId(positions, readerState, threshold: 0.0) ??
        activeTab.currentParaId ??
        activeTab.initialParaId;

    if (currentParaId != null) {
      final idx = readerState.paragraphs.indexWhere(
        (p) => p.paraId == currentParaId,
      );
      if (idx >= 0) {
        startParaIndex = idx;
      }
    } else if (positions != null && positions.isNotEmpty) {
      final visible =
          positions
              .where((p) => p.itemTrailingEdge > 0)
              .toList()
            ..sort(
              (a, b) => a.itemLeadingEdge.compareTo(b.itemLeadingEdge),
            );
      if (visible.isNotEmpty) {
        startParaIndex = visible.first.index.clamp(
          0,
          readerState.paragraphs.isEmpty
              ? 0
              : readerState.paragraphs.length - 1,
        );
      }
    }

    developer.log(
      '[TTS_START] startListening: startParaIndex=$startParaIndex '
      'resolvedParaId=$currentParaId '
      'fromPositions=${positions?.isNotEmpty ?? false} '
      'tabParaId=${activeTab.currentParaId}',
      name: 'epitaka.tts',
    );

    final settings = ref.read(settingsProvider);
    final mode = settings.ttsSpeakMode;
    final enabledLangs = settings.visibleTranslationLangs;
    final lang = enabledLangs.isNotEmpty ? enabledLangs.first : null;
    // Listening needs something to speak: a translation language, or
    // Pāli-only mode (which needs no translation).
    if (lang == null && mode == TtsSpeakMode.translation) return;

    // Load TTS replacements
    final replaceAsyncState = ref.read(ttsReplacementsNotifierProvider);
    if (replaceAsyncState is AsyncLoading || replaceAsyncState is AsyncError) {
      await ref.read(ttsReplacementsNotifierProvider.notifier).load();
    }
    final activeReplacements = ref.read(activeTtsReplacementsProvider);

    final lines = buildTtsLines(
      readerState.paragraphs.sublist(startParaIndex),
      lang: lang,
      mode: mode,
      activeReplacements: activeReplacements,
    );

    if (lines.isNotEmpty) {
      // Cache the book name so the Android notification shows a
      // human-readable title instead of the raw bookId.
      TtsReadingNotifier.cacheBookName(
        activeTab.bookId,
        readerState.bookName ?? activeTab.bookId,
      );
      ref
          .read(ttsReadingProvider.notifier)
          .startReading(activeTab.bookId, lines);
    }
  }

  /// Build the TTS line items for [paragraphs] according to [mode].
  ///
  /// Pure and static so it can be unit-tested without providers.
  ///
  /// * [TtsSpeakMode.translation] — one item per line with the translation.
  /// * [TtsSpeakMode.pali] — one item per line with the Pāli converted to
  ///   Sinhala script (language 'si').
  /// * [TtsSpeakMode.both] — Pāli item first (Sinhala), then the
  ///   translation item, mirroring the reader's Pāli-above-translation
  ///   layout.
  ///
  /// [lang] is the translation language to speak (null when Pāli-only
  /// listening with no enabled translation); [activeReplacements] are the
  /// user's TTS replacement rules applied to translation text.
  static List<TtsLineItem> buildTtsLines(
    List<ParagraphData> paragraphs, {
    required String? lang,
    required TtsSpeakMode mode,
    required List<TtsReplacement> activeReplacements,
  }) {
    final lines = <TtsLineItem>[];
    final speakPali = mode != TtsSpeakMode.translation;
    final speakTranslation = mode != TtsSpeakMode.pali;

    for (final para in paragraphs) {
      for (final line in para.lines) {
        if (speakPali) {
          final pali = paliForTts(line.paliText ?? '');
          if (pali.sinhala.isNotEmpty) {
            lines.add(
              TtsLineItem(
                paraId: para.paraId,
                lineId: line.lineId,
                text: pali.sinhala,
                language: 'si',
                // Keep the Roman source so the engine can re-encode for a
                // fallback script when Sinhala isn't available (instead of
                // skipping the line).
                paliRoman: pali.roman,
              ),
            );
          }
        }
        if (speakTranslation) {
          final rawText = lang == null ? '' : (line.translations[lang] ?? '');
          final stripped = stripHtmlForTts(rawText);
          var text = stripped;
          for (final rule in activeReplacements) {
            try {
              if (rule.isRegex) {
                text = text.replaceAll(
                  RegExp(rule.pattern),
                  rule.replacement,
                );
              } else {
                text = text.replaceAll(rule.pattern, rule.replacement);
              }
            } catch (_) {}
          }
          if (text.trim().isNotEmpty) {
            lines.add(
              TtsLineItem(
                paraId: para.paraId,
                lineId: line.lineId,
                text: text,
                language: lang,
              ),
            );
          }
        }
      }
    }
    return lines;
  }

  /// Convert Pāli text (in whatever script the DB stores) to Sinhala for
  /// TTS. Roman Pāli with diacritics reads poorly on system TTS; Sinhala
  /// maps 1:1 to Pāli phonemes and reads naturally (the tradition's own
  /// script).
  static String paliToSinhalaForTts(String paliText) =>
      paliForTts(paliText).sinhala;

  /// Strip + normalize Pāli text to a clean Roman source, then convert to
  /// Sinhala. Returns both so the engine can fall back to another script
  /// (Devanagari / ASCII Roman) from the Roman source when the active TTS
  /// engine has no Sinhala voice — otherwise those lines are silently
  /// skipped.
  static ({String sinhala, String roman}) paliForTts(String paliText) {
    final stripped = stripHtmlForTts(paliText);
    if (stripped.trim().isEmpty) return (sinhala: '', roman: '');
    // Normalize any non-Roman script to Roman first (no-op for already
    // Roman text), then Roman → Sinhala.
    final roman = convertToRomanPali(stripped);
    return (
      sinhala: TextProcessor.convertFrom(roman, Script.roman),
      roman: roman,
    );
  }

  /// Stop TTS reading.
  void stopListening() {
    ref.read(ttsReadingProvider.notifier).stopReading();
  }

  /// Re-enable TTS auto-scroll and jump to the current TTS line.
  ///
  /// Must set the jump-in-progress flag so the scroll triggered by
  /// [jumpToParagraph] doesn't immediately re-disable auto-scroll in the
  /// position callback.
  void follow(String bookId) {
    ref.read(ttsSyncProvider(bookId).notifier).enableAutoScroll();
    ref.read(ttsSyncProvider(bookId).notifier).setJumpInProgress();
    final ttsState = ref.read(ttsReadingProvider);
    if (ttsState.currentParaId != null) {
      jumpToParagraph(
        bookId,
        ttsState.currentParaId!,
        lineId: ttsState.currentLineId,
      );
    }
  }

  /// Whether the paragraph currently being spoken is visible in [bookId]'s
  /// reader viewport.
  bool isTtsLineVisible(String bookId, int? ttsParaId) {
    return position_utils.isTtsLineVisible(
      positionsFor(bookId),
      ref.read(readerDataProvider(bookId)),
      ttsParaId,
    );
  }

  /// Show the TTS floating controls dialog.
  Future<void> showControls(BuildContext context, String bookId) {
    final ttsReadingState = ref.read(ttsReadingProvider);
    return showTtsControlsDialog(
      context,
      bookId: bookId,
      isTtsLineVisible: isTtsLineVisible(bookId, ttsReadingState.currentParaId),
      onFollowTts: () => follow(bookId),
      onSpeakModeChanged: (mode) => applySpeakMode(mode, bookId),
    );
  }

  /// Apply a new speak mode (Translation / Pāli / Both).
  ///
  /// If reading is active, the change takes effect immediately: the line
  /// list is rebuilt with the new mode from the paragraph currently being
  /// spoken and playback restarts there (so the user hears the change right
  /// away instead of having to stop and play again).
  Future<void> applySpeakMode(TtsSpeakMode mode, String bookId) async {
    ref.read(settingsProvider.notifier).setTtsSpeakMode(mode);

    final ttsState = ref.read(ttsReadingProvider);
    if (!ttsState.isActive || ttsState.bookId != bookId) return;
    final activeTab = ref.read(readerTabsProvider).activeTab;
    if (activeTab == null) return;

    // Rebuild lines from the paragraph currently being spoken so the new
    // mode applies at (and after) the current position.
    final readerState = ref.read(readerDataProvider(bookId));
    final currentParaId = ttsState.currentParaId;
    if (currentParaId == null) return;
    final startIdx = readerState.paragraphs.indexWhere(
      (p) => p.paraId == currentParaId,
    );
    if (startIdx < 0) return;

    final settings = ref.read(settingsProvider);
    final enabledLangs = settings.visibleTranslationLangs;
    final lang = enabledLangs.isNotEmpty ? enabledLangs.first : null;
    if (lang == null && mode == TtsSpeakMode.translation) return;

    final replaceAsyncState = ref.read(ttsReplacementsNotifierProvider);
    if (replaceAsyncState is AsyncLoading ||
        replaceAsyncState is AsyncError) {
      await ref.read(ttsReplacementsNotifierProvider.notifier).load();
    }
    final activeReplacements = ref.read(activeTtsReplacementsProvider);

    final lines = buildTtsLines(
      readerState.paragraphs.sublist(startIdx),
      lang: lang,
      mode: mode,
      activeReplacements: activeReplacements,
    );
    if (lines.isNotEmpty) {
      ref
          .read(ttsReadingProvider.notifier)
          .startReading(bookId, lines);
    }
  }

  /// React to [ttsReadingProvider] changes.
  ///
  /// * Auto-switches the reader to line-by-line while TTS plays — the only
  ///   display mode that renders per-line widgets (and thus per-line
  ///   GlobalKeys for the fine-scroll), so the spoken line can be followed
  ///   precisely. Restores the previous mode when reading stops.
  /// * Saves reading history as the spoken line advances.
  /// * Auto-scrolls to the spoken line: same-paragraph line changes
  ///   fine-scroll directly (a full paragraph re-scroll would re-anchor the
  ///   paragraph and cause visible jumping); paragraph changes jump.
  void handleTtsStateChanged(TtsReadingState? prev, TtsReadingState next) {
    final wasActive = prev?.isActive ?? false;
    final isActive = next.isActive;
    if (isActive && !wasActive && _ttsModeBefore == null) {
      _ttsModeBefore = ref.read(settingsProvider).translationDisplayMode;
      if (_ttsModeBefore != TranslationDisplayMode.lineByLine) {
        // Temporary (non-persisting) override so the user's saved mode
        // is untouched even if this is never undone.
        ref
            .read(settingsProvider.notifier)
            .setTranslationDisplayModeTemporary(
              TranslationDisplayMode.lineByLine,
            );
      }
    } else if (!isActive && wasActive && _ttsModeBefore != null) {
      final currentMode = ref.read(settingsProvider).translationDisplayMode;
      // Respect a manual display-mode change made during playback;
      // otherwise restore what the reader used before TTS started.
      if (currentMode == TranslationDisplayMode.lineByLine ||
          currentMode == _ttsModeBefore) {
        ref.read(settingsProvider.notifier).setTranslationDisplayModeTemporary(
          _ttsModeBefore!,
        );
      }
      _ttsModeBefore = null;
    }

    final prevParaId = prev?.currentParaId;
    final nextParaId = next.currentParaId;
    final prevLineId = prev?.currentLineId;
    final nextLineId = next.currentLineId;
    if (!isMounted() || nextParaId == null) return;
    if (!isAppResumed()) return;
    final currentBookId = ref.read(readerTabsProvider).activeTab?.bookId;
    if (currentBookId == null || next.bookId != currentBookId) return;

    // Issue 4: Also handle intra-paragraph line changes
    final paraChanged = prevParaId != nextParaId;
    final lineChanged = prevLineId != nextLineId;
    if (!paraChanged && !lineChanged) return;

    // Save reading history
    final bookName = ref.read(readerDataProvider(currentBookId)).bookName;
    final ttsSync = ref.read(ttsSyncProvider(currentBookId));
    developer.log(
      '[TTS_UI] listener: prevParaId=$prevParaId nextParaId=$nextParaId '
      'prevLineId=$prevLineId nextLineId=$nextLineId '
      'ttsAutoScroll=${ttsSync.ttsAutoScroll}',
      name: 'epitaka.tts',
    );
    saveHistory(
      currentBookId,
      bookName,
      explicitParaId: nextParaId,
      explicitLineId: nextLineId,
    );

    if (!ttsSync.ttsAutoScroll) {
      developer.log(
        '[TTS_UI] auto-scroll off, skipping jump',
        name: 'epitaka.tts',
      );
      requestRebuild();
      return;
    }

    // Same-paragraph line change: the paragraph is already on screen, so a
    // full paragraph-level re-scroll would re-anchor it at a new alignment
    // (causing visible jumping / the "line not following" effect). Instead
    // fine-scroll directly to the new line via its GlobalKey.
    if (!paraChanged && nextLineId != null) {
      final ttsSyncNotifier = ref.read(ttsSyncProvider(currentBookId).notifier);
      ttsSyncNotifier.setJumpInProgress();
      ttsSyncNotifier.clearTargetLineKeys();
      ttsSyncNotifier.setTargetParaId(nextParaId);
      ttsSyncNotifier.setTargetLineKey(nextLineId, GlobalKey());
      requestRebuild();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!isMounted()) return;
        final jumpToken = nextJumpToken(currentBookId);
        developer.log(
          '[TTS_UI] fine-scroll same-para to line=$nextLineId '
          'token=$jumpToken',
          name: 'epitaka.tts',
        );
        fineScrollToLine(currentBookId, nextLineId, jumpToken: jumpToken);
      });
      return;
    }

    ref.read(ttsSyncProvider(currentBookId).notifier).setJumpInProgress();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isMounted()) return;
      developer.log(
        '[TTS_UI] post-frame jump to $nextParaId line=$nextLineId',
        name: 'epitaka.tts',
      );
      jumpToParagraph(
        currentBookId,
        nextParaId,
        animate: false,
        lineId: nextLineId,
      );
    });
  }

  /// Detect manual scroll: called from the position-tracking callback when
  /// the visible paragraph changes. If TTS is playing and this scroll was
  /// NOT a TTS-initiated jump, disable auto-scroll.
  ///
  /// [visible] must be the sorted list of visible item positions (the same
  /// list the caller uses to derive the topmost paragraph).
  ///
  /// The spoken paragraph is considered in range if it maps to ANY visible
  /// position — not just the top-most one, which can differ after a
  /// fine-scroll without the user having scrolled at all.
  void handleManualScroll(
    String bookId,
    List<ItemPosition> visible,
    List<ParagraphData> paragraphs,
  ) {
    final ttsSync = ref.read(ttsSyncProvider(bookId));
    if (ttsSync.ttsJumpInProgress) {
      developer.log(
        '[UI_POS] book=$bookId ttsJumpInProgress=true → skip auto-scroll check',
        name: 'epitaka.reader.ui',
      );
      return;
    }
    final ttsState = ref.read(ttsReadingProvider);
    if (!ttsState.isActive || ttsState.bookId != bookId) return;
    final ttsParaId = ttsState.currentParaId;
    if (ttsParaId == null) return;

    // O(visible) index lookup — no full-paragraph indexWhere scan on every
    // scroll event.
    final isTtsInVisibleRange = visible.any(
      (p) =>
          p.index >= 0 &&
          p.index < paragraphs.length &&
          paragraphs[p.index].paraId == ttsParaId,
    );
    if (!isTtsInVisibleRange) {
      developer.log(
        '[UI_POS] book=$bookId DISABLE auto-scroll: ttsPara=$ttsParaId '
        'visible=${visible.map((p) => p.index).toList()}',
        name: 'epitaka.reader.ui',
      );
      ref.read(ttsSyncProvider(bookId).notifier).disableAutoScroll();
    }
  }
}
