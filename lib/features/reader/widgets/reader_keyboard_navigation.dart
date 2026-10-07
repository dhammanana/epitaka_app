import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../shared/providers/vimamsa_panel_provider.dart';
import '../../../shared/utils/app_shortcuts.dart';
import '../providers/reader_keyboard_bridge.dart';
import '../providers/reader_provider.dart';
import '../providers/reader_tabs_provider.dart';
import '../providers/tts_reading_provider.dart';
import 'book_link_section_sheet.dart';

/// Wraps the reader content (inside the desktop shell's center area) and
/// handles full keyboard navigation once a book is open:
///
///   j / ↓  — move the reading cursor (focus line) to the next line
///   k / ↑  — move it to the previous line
///   h / ←  — select the previous book-link chip on the focused line
///   l / →  — select the next book-link chip on the focused line
///   Space / Enter — open the selected book-link chip
///   Esc    — clear the focus line (exit keyboard reading)
///
/// The focus line is rendered by the reader itself (the reader reads
/// [readerKeyboardNavProvider] and highlights the matching line + chip), so
/// this widget only owns the key handling and the scrolling.
///
/// The widget deliberately lives OUTSIDE [ReaderScreen] (it wraps the reader
/// from the desktop shell) so the reader's already-complex screen code stays
/// untouched apart from registering its scroll controller in the bridge and
/// threading the focus params down.
class ReaderKeyboardNavigation extends ConsumerStatefulWidget {
  final Widget child;

  const ReaderKeyboardNavigation({super.key, required this.child});

  @override
  ConsumerState<ReaderKeyboardNavigation> createState() =>
      _ReaderKeyboardNavigationState();
}

class _ReaderKeyboardNavigationState
    extends ConsumerState<ReaderKeyboardNavigation> {
  final FocusNode _focusNode = FocusNode();

  /// Display mode before keyboard navigation forced line-by-line, restored
  /// when navigation disengages (mirrors how TTS temporarily forces
  /// line-by-line so its per-line highlight is visible).
  TranslationDisplayMode? _modeBeforeNav;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// The focus line highlight only renders in line-by-line mode (the other
  /// modes join the paragraph into one continuous block). When keyboard
  /// navigation engages in another mode, temporarily switch to line-by-line
  /// and remember to restore it on disengage.
  void _ensureLineByLine() {
    final settings = ref.read(settingsProvider);
    if (settings.translationDisplayMode == TranslationDisplayMode.lineByLine) {
      return;
    }
    if (_modeBeforeNav == null) {
      _modeBeforeNav = settings.translationDisplayMode;
      ref
          .read(settingsProvider.notifier)
          .setTranslationDisplayModeTemporary(
            TranslationDisplayMode.lineByLine,
          );
    }
  }

  /// Restore the display mode saved when navigation engaged (only if the
  /// user hasn't switched it manually in the meantime).
  void _restoreDisplayMode() {
    final before = _modeBeforeNav;
    if (before == null) return;
    _modeBeforeNav = null;
    final current = ref.read(settingsProvider).translationDisplayMode;
    if (current == TranslationDisplayMode.lineByLine || current == before) {
      ref
          .read(settingsProvider.notifier)
          .setTranslationDisplayModeTemporary(before);
    }
  }

  void _disengage() {
    _restoreDisplayMode();
    ref.read(readerKeyboardNavProvider.notifier).disengage();
  }

  bool get _textFieldHasFocus {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  ReaderDataState? get _activeReaderState {
    final bookId = ref.read(readerTabsProvider).activeTab?.bookId;
    if (bookId == null) return null;
    return ref.read(readerDataProvider(bookId));
  }

  String? get _activeBookId => ref.read(readerTabsProvider).activeTab?.bookId;

  /// Whether keyboard navigation is blocked because TTS is active for the
  /// active book (playing or paused). TTS owns the auto-scroll and the
  /// line-by-line display override for that book; letting j/k jump around
  /// would fight the spoken-line scrolling, so every key except Esc is
  /// handed through. TTS on another tab — or no TTS at all — leaves
  /// keyboard navigation fully working.
  bool get _ttsBlocksNavigation {
    final bookId = _activeBookId;
    if (bookId == null) return false;
    final tts = ref.read(ttsReadingProvider);
    return tts.isActive && tts.bookId == bookId;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    // Never steal keys while the user is typing somewhere (search fields,
    // the Vīmaṃsā chat input, …) — those live outside this subtree on
    // desktop, but Vīmaṃsā is inside the center column, so guard by focus.
    if (_textFieldHasFocus) return KeyEventResult.ignored;
    if (ref.read(vimamsaOpenProvider)) return KeyEventResult.ignored;
    if (_activeBookId == null) return KeyEventResult.ignored;
    final data = _activeReaderState;
    if (data == null || data.paragraphs.isEmpty) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _disengage();
      return KeyEventResult.handled;
    }
    // TTS owns this book's scrolling — don't fight the spoken line.
    if (_ttsBlocksNavigation) return KeyEventResult.ignored;
    // With the find bar open, ↑/↓ walk the matches instead of the lines.
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      final forward = key == LogicalKeyboardKey.arrowDown;
      if (ref.read(readerKeyboardBridgeProvider).stepInBookMatch?.call(forward) ==
          true) {
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.arrowDown ||
        AppShortcuts.matches('reader-next-line', event)) {
      _moveLine(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        AppShortcuts.matches('reader-prev-line', event)) {
      _moveLine(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        AppShortcuts.matches('reader-prev-link', event)) {
      _moveChip(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        AppShortcuts.matches('reader-next-link', event)) {
      _moveChip(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      _openSelectedChip();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ── Line movement (j/k, ↑/↓) ────────────────────────────────────────

  void _moveLine(int direction) {
    final bookId = _activeBookId!;
    final data = _activeReaderState!;
    final paragraphs = data.paragraphs;
    final bridge = ref.read(readerKeyboardBridgeProvider);
    final controller = bridge.scrollControllerFor(bookId);
    if (controller == null) return;
    final nav = ref.read(readerKeyboardNavProvider);

    int paraIndex;
    int lineIndex;
    Future<void>? paragraphJump;
    if (!nav.engaged || nav.bookId != bookId || nav.paraId == null) {
      // Not engaged yet: force line-by-line (so the focus line renders) and
      // start from the topmost visible paragraph. The engage press just
      // highlights where the user already is — no centering scroll.
      _ensureLineByLine();
      paraIndex = bridge.firstVisibleIndex(bookId) ?? 0;
      paraIndex = paraIndex.clamp(0, paragraphs.length - 1);
      final para = paragraphs[paraIndex];
      lineIndex = direction > 0
          ? 0
          : (para.lines.isNotEmpty ? para.lines.length - 1 : 0);
    } else {
      paraIndex = paragraphs.indexWhere((p) => p.paraId == nav.paraId);
      if (paraIndex < 0) {
        paraIndex = bridge.firstVisibleIndex(bookId) ?? 0;
        paraIndex = paraIndex.clamp(0, paragraphs.length - 1);
      }
      final para = paragraphs[paraIndex];
      lineIndex = para.lines.indexWhere((l) => l.lineId == nav.lineId);
      if (lineIndex < 0) lineIndex = 0;
      lineIndex += direction;
      if (lineIndex < 0) {
        // Move to the previous paragraph's last line.
        if (paraIndex == 0) return;
        paraIndex--;
        final prev = paragraphs[paraIndex];
        lineIndex = prev.lines.isNotEmpty ? prev.lines.length - 1 : 0;
        paragraphJump = _scrollToParagraph(
          controller,
          paraIndex,
          alignment: 1.0,
        );
      } else if (lineIndex >= para.lines.length) {
        // Move to the next paragraph's first line.
        if (paraIndex >= paragraphs.length - 1) return;
        paraIndex++;
        lineIndex = 0;
        paragraphJump = _scrollToParagraph(
          controller,
          paraIndex,
          alignment: 0.0,
        );
      }
    }

    final para = paragraphs[paraIndex];
    if (para.lines.isEmpty) return;
    final line = para.lines[lineIndex.clamp(0, para.lines.length - 1)];
    // Fresh per-line keys every step so the centering fine-scroll below can
    // reach the new focus line even when the paragraph didn't move.
    ref
        .read(readerKeyboardNavProvider.notifier)
        .focus(
          bookId,
          para.paraId,
          line.lineId,
          lineKeys: {for (final l in para.lines) l.lineId: GlobalKey()},
        );
    if (nav.engaged && nav.bookId == bookId && nav.paraId != null) {
      // Was already engaged — center the new focus line.
      if (paragraphJump != null) {
        // Center only after the paragraph scroll settles — an ensureVisible
        // issued mid-animation would be overridden by the animation itself.
        paragraphJump.whenComplete(() {
          _centerFocusedLine(bookId, controller, para.paraId, line.lineId);
        });
      } else {
        _centerFocusedLine(bookId, controller, para.paraId, line.lineId);
      }
    }
    // Engage press: no scrolling — the highlight lands where the user is.
  }

  Future<void>? _scrollToParagraph(
    ItemScrollController controller,
    int index, {
    required double alignment,
  }) {
    if (!controller.isAttached) return null;
    return controller.scrollTo(
      index: index,
      alignment: alignment,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  /// Fine-scroll the keyboard focus line to the vertical center of the
  /// viewport.
  ///
  /// The per-line [GlobalKey]s registered via [focus]'s `lineKeys` are
  /// attached by the paragraph renderer (see `ReadingParagraph.lineKeys`),
  /// the same plumbing the TTS fine-scroll uses — but they live in the
  /// keyboard-nav state, never in TTS state, so the two can't fight. The
  /// line widget may not be laid out yet, so this retries for a few frames
  /// before giving up (leaving the focus line wherever the paragraph-level
  /// scroll put it).
  void _centerFocusedLine(
    String bookId,
    ItemScrollController controller,
    int paraId,
    int lineId,
  ) {
    // Snapshot the key instance this attempt targets: if another j/k press
    // replaces the keys map (fresh GlobalKey instances), this stale attempt
    // must not scroll or clear the newer attempt's keys.
    final attemptKey = ref.read(readerKeyboardNavProvider).lineKeys[lineId];
    if (attemptKey == null) return;

    void attempt(int remaining) {
      final nav = ref.read(readerKeyboardNavProvider);
      final key = nav.lineKeys[lineId];
      // Focus moved on, disengaged, keys consumed, or this attempt
      // superseded by a newer one — done.
      if (!nav.engaged || nav.paraId != paraId) return;
      if (key == null || !identical(key, attemptKey)) return;

      final ctx = key.currentContext;
      if (ctx == null || !ctx.mounted) {
        if (remaining <= 0) {
          // Give up: the focus line stays where the paragraph scroll put it.
          if (identical(
            ref.read(readerKeyboardNavProvider).lineKeys[lineId],
            attemptKey,
          )) {
            ref.read(readerKeyboardNavProvider.notifier).clearLineKeys();
          }
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          attempt(remaining - 1);
        });
        return;
      }

      Scrollable.ensureVisible(
        ctx,
        alignment: _kFocusLineAlignment,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
      ).whenComplete(() {
        // Only clear if this attempt is still the current one.
        if (!identical(
          ref.read(readerKeyboardNavProvider).lineKeys[lineId],
          attemptKey,
        )) {
          return;
        }
        ref.read(readerKeyboardNavProvider.notifier).clearLineKeys();
      });
    }

    if (!controller.isAttached) return;
    attempt(_kMaxCenterRetries);
  }

  /// Viewport alignment for the focus line: slightly above center so the
  /// next line is visible while reading.
  static const double _kFocusLineAlignment = 0.45;

  /// Max frames to wait for the focus line widget to be laid out before
  /// giving up on centering (the paragraph-level scroll still holds).
  static const int _kMaxCenterRetries = 15;

  // ── Chip selection (h/l, ←/→) ──────────────────────────────────────

  void _moveChip(int direction) {
    final bookId = _activeBookId!;
    final data = _activeReaderState!;
    final paragraphs = data.paragraphs;
    final nav = ref.read(readerKeyboardNavProvider);
    final notifier = ref.read(readerKeyboardNavProvider.notifier);

    if (!nav.engaged || nav.bookId != bookId || nav.paraId == null) {
      // Not engaged — jump to the nearest line (in [direction]) that has
      // chips and select its first chip.
      if (_focusNearestChipLine(direction, bookId, data, paragraphs)) return;
      return;
    }

    final links = data.bookLinks[nav.paraId]?[nav.lineId];
    if (links == null || links.isEmpty) {
      // Focus line has no chips — scan for the nearest line with chips.
      _focusNearestChipLine(direction, bookId, data, paragraphs);
      return;
    }

    final current = nav.chipIndex < 0 ? -1 : nav.chipIndex;
    final next = (current + direction) % links.length;
    notifier.selectChip(next < 0 ? links.length - 1 : next);
  }

  /// Scan forward/backward from the current focus (or the first visible
  /// paragraph when not engaged) for the nearest line carrying book-link
  /// chips; focus it and select its first chip.
  bool _focusNearestChipLine(
    int direction,
    String bookId,
    ReaderDataState data,
    List<ParagraphData> paragraphs,
  ) {
    final bridge = ref.read(readerKeyboardBridgeProvider);
    final controller = bridge.scrollControllerFor(bookId);
    final nav = ref.read(readerKeyboardNavProvider);

    var paraIndex = nav.engaged && nav.paraId != null && nav.bookId == bookId
        ? paragraphs.indexWhere((p) => p.paraId == nav.paraId)
        : (bridge.firstVisibleIndex(bookId) ?? 0);
    if (paraIndex < 0) paraIndex = 0;
    if (paragraphs.isEmpty) return false;

    // First scan the current paragraph from the focus line, then move to
    // adjacent paragraphs. Limit the scan so a pathological book can't
    // make j/k hang.
    for (var attempts = 0; attempts < 40; attempts++) {
      final para = paragraphs[paraIndex];
      final paraLinks = data.bookLinks[para.paraId];
      final lineRange = List<int>.generate(para.lines.length, (i) => i);
      final ordered = direction > 0 ? lineRange : lineRange.reversed.toList();
      final start =
          nav.engaged && nav.paraId == para.paraId && nav.lineId != null
          ? nav.lineId!
          : (direction > 0 ? -1 : para.lines.length);
      for (final lineIndex in ordered) {
        final line = para.lines[lineIndex];
        if (direction > 0 && line.lineId <= start) continue;
        if (direction < 0 && line.lineId >= start) continue;
        final links = paraLinks?[line.lineId];
        if (links == null || links.isEmpty) continue;
        ref
            .read(readerKeyboardNavProvider.notifier)
            .focus(bookId, para.paraId, line.lineId);
        ref.read(readerKeyboardNavProvider.notifier).selectChip(0);
        if (controller != null && attempts > 0) {
          _scrollToParagraph(
            controller,
            paraIndex,
            alignment: direction > 0 ? 0.0 : 1.0,
          );
        }
        return true;
      }
      paraIndex += direction;
      if (paraIndex < 0 || paraIndex >= paragraphs.length) break;
    }
    return false;
  }

  // ── Opening a chip (Space/Enter) ───────────────────────────────────

  void _openSelectedChip() {
    final data = _activeReaderState!;
    final nav = ref.read(readerKeyboardNavProvider);
    if (!nav.engaged || nav.chipIndex < 0) return;
    final links = data.bookLinks[nav.paraId]?[nav.lineId];
    if (links == null || nav.chipIndex >= links.length) return;
    showBookLinkSectionSheet(context, link: links[nav.chipIndex]);
  }

  // ── Pointer handling ───────────────────────────────────────────────

  /// Clear the focus line when the user interacts with the mouse so the
  /// stale highlight doesn't linger after scrolling/clicking away.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      _disengage();
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    _disengage();
  }

  @override
  Widget build(BuildContext context) {
    // If the user switches books (or closes the last tab) while keyboard
    // navigation is engaged, disengage and restore the display mode — the
    // focus line belongs to the previous book.
    ref.listen(readerTabsProvider, (prev, next) {
      if (prev?.activeTab?.bookId != next.activeTab?.bookId) {
        _disengage();
      }
    });

    // If TTS starts for the active book while the focus line is visible,
    // disengage: TTS owns the auto-scroll and its own line-by-line
    // override from here on, and the cursor would only fight it (keyboard
    // keys are separately blocked for TTS books in [_handleKeyEvent]).
    // This listener runs before the TTS controller's own, so the display
    // mode restored here is what TTS then snapshots and re-forces.
    ref.listen(ttsReadingProvider, (prev, next) {
      if (!(prev?.isActive ?? false) && next.isActive) {
        final activeBookId = ref.read(readerTabsProvider).activeTab?.bookId;
        if (next.bookId == activeBookId) {
          _disengage();
        }
      }
    });

    return Listener(
      onPointerSignal: _onPointerSignal,
      onPointerDown: _onPointerDown,
      child: Focus(
        focusNode: _focusNode,
        canRequestFocus: true,
        onKeyEvent: _handleKeyEvent,
        child: widget.child,
      ),
    );
  }
}
