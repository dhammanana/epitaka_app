import 'dart:async';

import 'package:epitaka/core/utils/responsive_breakpoint.dart'
    show ResponsiveBreakpoint;
import 'package:epitaka/shared/providers/side_panel_provider.dart';
import 'package:epitaka/shared/widgets/regex_toggle_button.dart';
import 'package:epitaka/shared/widgets/velthuis_help_icon.dart';
import 'package:epitaka/shared/widgets/search_box_decoration.dart';
import 'package:epitaka/shared/widgets/wide_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/native_lookup_service.dart';
import '../../../core/utils/pali_script_converter.dart';
import '../../../core/utils/velthuis.dart';
import '../../dpd/providers/lookup_history.dart';
import '../../dpd/utils/query_cleaning.dart';
import '../../search/services/regex_search.dart';
import '../providers/dictionary_header_provider.dart';
import 'dictionary_header_icons.dart';
import 'lookup_history_list.dart';
import 'lookup_history_buttons.dart';
import 'lookup_history_chips.dart';
import '../providers/dictionary_expanded_provider.dart';
import '../providers/dictionary_font_scale_provider.dart';
import '../providers/dictionary_sheet_open_provider.dart'
    show dictionarySheetOpenProvider;
import '../../dpd/providers/dictionary_list_provider.dart';
import '../../dpd/providers/dpd_lookup_provider.dart';
import '../../dpd/providers/dpd_settings_provider.dart';
import '../../mdx_dictionary/models/mdx_dictionary_info.dart';
import '../../mdx_dictionary/providers/mdx_dictionary_provider.dart';
import '../../mdx_dictionary/providers/mdx_lookup_providers.dart';
import 'dictionary_search_shared.dart';
import 'ordered_dictionary_items.dart';
import 'page_anchors.dart';

/// A dictionary sheet that can be shown in a sidebar or as a standalone
/// widget. When used in the right sidebar on desktop, it communicates
/// with [SidePanelProvider] for word lookup navigation.
Future<T?> showDictionarySheet<T>(BuildContext context, String word) {
  // Mark the sheet as open so the reader behind it can drop its (very deep)
  // semantics subtree from collection. Collecting the reader's huge
  // ScrollablePositionedList while the sheet's own semantics are being built
  // causes re-entrant flushSemantics and the framework's
  // '!semantics.parentDataDirty' / '!conflict' assertions (see
  // reading_paragraph.dart). A modal sheet is exactly the case where the
  // behind-content should not be in the accessibility tree.
  final container = ProviderScope.containerOf(context);
  container.read(dictionarySheetOpenProvider.notifier).state++;
  return showModalBottomSheet<T>(
    context: context,
    // Route the sheet through the root navigator so it lives in its own
    // overlay entry, away from the reader's focus/semantics subtree (which
    // previously wrapped the SelectionArea). This keeps the sheet's own
    // TextField focus grab from conflicting with the reader's selection state.
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // The DraggableScrollableSheet handles its own drag/resize, so we
    // disable the modal's own drag-to-dismiss to avoid the elastic
    // rubber-band effect (especially noticeable on Android).
    enableDrag: false,
    // Wide screens: span 80% of the app instead of the 640 px default cap.
    constraints: wideBottomSheetConstraints(context),
    builder: (_) => DictionarySheet(initialWord: word),
  ).whenComplete(() {
    container.read(dictionarySheetOpenProvider.notifier).state--;
  });
}

// ── Sheet sizing ────────────────────────────────────────────────────────
// The sheet follows the finger (no snap) so the user can freely:
//   • drag up    → the sheet grows and its content scrolls (see more info)
//   • drag down  → a quick flick (or dragging below [_sheetCloseExtent])
//     dismisses the sheet — see [_isFlingClose]
//
// We dismiss via a single guarded route pop (see the notification listener)
// which avoids the previous bug where a repeated maybePop also closed the
// reader route underneath.
const double _sheetMinSize = 0.25;
const double _sheetInitialSize = 0.7;
const double _sheetMaxSize = 0.95;
// Dragging the sheet below this extent dismisses it.
const double _sheetCloseExtent = 0.4;
// A downward swipe faster than this (in extents per second) dismisses the
// sheet even if it never reaches [_sheetCloseExtent] — a quick flick only
// travels a small fraction of the screen, so the extent-based check alone
// makes "swipe down to close" feel dead.
const double _kFlingCloseExtentPerSec = 2.0;
// How far back to look when estimating the flick velocity from extent
// samples. Mirrors the reader's tab-swipe window.
const int _kFlingSampleWindowMs = 120;
// Header drag: a downward drag ending faster than this (px/s) dismisses the
// sheet regardless of its current size.
const double _kHeaderFlingVelocityPxPerSec = 700;

// ── Main Sheet Widget ──────────────────────────────────────────────────────

class DictionarySheet extends ConsumerStatefulWidget {
  final String initialWord;

  const DictionarySheet({super.key, this.initialWord = ''});

  @override
  ConsumerState<DictionarySheet> createState() => _DictionarySheetState();
}

class _DictionarySheetState extends ConsumerState<DictionarySheet> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  /// The history list drawn over the results (the icon row's history icon).
  bool _historyOpen = false;

  /// The sheet's own scroll controller, kept for the jump-to-top icon.
  ScrollController? _sheetScroll;
  final _sheetController = DraggableScrollableController();
  Timer? _suggestDebounce;

  // ── Swipe-down-to-close tracking ──────────────────────────────────
  // DraggableScrollableSheet reports no drag velocity, so we sample the
  // sheet extent while a pointer is down and estimate the flick speed
  // ourselves (same approach as the reader's tab-swipe velocity).
  int _pointersDown = 0;
  final List<({double extent, int ms})> _swipeSamples = [];

  // Guards the single dismiss of this sheet's route so that a continuous
  // drag gesture can't pop the reader route underneath as well.
  bool _dismissed = false;

  // The submitted word whose meanings are shown. Typing alone only
  // updates [_draft] (suggestions); meanings load on submit/enter.
  String _query = '';
  // Live textbox value (debounced) driving prefix suggestions.
  String _draft = '';

  /// [_query] is a pattern submitted with rx on.
  bool _queryIsRegex = false;

  /// Why the submitted pattern does not compile.
  String? _patternError;

  // Keyboard navigation over the suggestion dropdown: -1 = caret in the
  // field, otherwise the highlighted suggestion index (Enter accepts it).
  int _suggestIndex = -1;
  final Map<int, GlobalKey> _suggestKeys = {};
  final _suggestScroll = ScrollController();
  // Arrow pressed while suggestions were still loading: 0 = none,
  // 1 = highlight first row, -1 = highlight last row once rows arrive.
  int _suggestPending = 0;

  /// The last selection made inside the results, tracked via the
  /// SelectionArea's `onSelectionChanged`. The toolbar reads it because
  /// [SelectableRegionState] exposes no public accessor for the selected
  /// text (the reader tracks it the same way).
  SelectedContent? _lastSelectedContent;

  /// Memoized *whole* results body (all dictionary sections + suggestions).
  ///
  /// DraggableScrollableSheet re-invokes its builder on every drag and
  /// keyboard-animation frame, and building the DPD entries and the flutter_html
  /// definition cards is the sheet's biggest per-frame cost. Caching the
  /// assembled results keyed by (query, lookup, searchWord, enabled-books)
  /// means those frames just return the cached widget tree instead of
  /// rebuilding it.
  Widget? _cachedResultsWidget;
  String? _cachedResultsQuery;
  DpdLookup? _cachedResultsLookup;
  String? _cachedResultsSearchWord;
  String? _cachedResultsListKey;
  AsyncValue<List<String>>? _cachedResultsSuggestions;
  String? _cachedResultsExpandedKey;
  DictionaryLevel? _cachedResultsLevel;
  double? _cachedResultsFontScale;
  bool? _cachedResultsShowSummary;
  ColorScheme? _cachedResultsColors;

  /// Where each summary line of the results jumps to.
  final PageAnchors _anchors = PageAnchors();

  /// Back and forward over the words looked up in this sheet.
  LookupHistory get _lookupHistory => ref.read(lookupHistoryProvider);

  /// A provider cannot change inside `initState` or `didChangeDependencies`,
  /// which is where a word handed to this widget arrives, so the add waits one
  /// microtask.
  void _recordLookup(String word) => Future.microtask(() {
    if (mounted) _lookupHistory.navigateTo(word);
  });

  @override
  void initState() {
    super.initState();
    // With no word handed in, carry on from the word the panel or an earlier
    // sheet left current.
    final handedIn = cleanDpdQuery(widget.initialWord);
    final initial = handedIn.isNotEmpty
        ? handedIn
        : (_lookupHistory.current ?? '');
    if (initial.isNotEmpty) {
      _searchController.text = initial;
      _query = initial;
      _draft = initial;
    }
    // Only a handed-in word is a new lookup. Re-adding the current word would
    // move it to the end of the history after the user had gone back.
    if (handedIn.isNotEmpty) _recordLookup(handedIn);
    _focusNode.onKeyEvent = _handleSearchKey;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _sheetController.dispose();
    _suggestScroll.dispose();
    _suggestDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // The suggestions drop down under the history list; typing means the user
    // is done with the list.
    if (_historyOpen) setState(() => _historyOpen = false);
    _suggestDebounce?.cancel();

    final regex = ref.read(dictionaryRegexProvider);
    final trimmed = regex
        ? value.trim()
        : foldDpdQuery(convertToRomanPali(value)).trim();
    if (trimmed.isEmpty) {
      setState(() {
        _lookupHistory.resetPosition();
        _draft = '';
        _query = '';
        _suggestIndex = -1;
        _suggestPending = 0;
        _suggestKeys.clear();
      });
      return;
    }
    // A pattern has no suggestions. The redraw shows the clear button, which
    // the suggestion timer would otherwise bring.
    if (regex) {
      setState(() {});
      return;
    }

    // Typing only refreshes prefix suggestions (debounced). The full
    // meaning lookup runs on submit/enter via _performSearch.
    _suggestDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _draft = trimmed;
        _suggestIndex = -1;
        _suggestPending = 0;
        _suggestKeys.clear();
      });
    });
  }

  void _performSearch(String value) {
    if (ref.read(dictionaryRegexProvider)) {
      _submitPattern(value);
      return;
    }
    final converted = cleanDpdQuery(value);
    if (converted.isEmpty) return;
    _suggestDebounce?.cancel();
    _focusNode.unfocus();
    _initiateSearch(converted);
  }

  /// Whether the search text field should auto-focus. When the sheet is
  /// opened by double-tapping a word (which already fills in the search
  /// term), we skip auto-focus to avoid popping up the on-screen keyboard
  /// on touch devices. When opened via the dictionary button or keyboard
  /// shortcut with no word, we auto-focus so the user can start typing.
  bool get _shouldAutofocus => widget.initialWord.isEmpty;

  void _initiateSearch(String word) {
    if (word.isEmpty) return;
    _recordLookup(word);
    _showWord(word);
  }

  /// A pattern runs exactly as typed and stays out of the lookup history:
  /// re-run from there in normal mode it would mean something else.
  void _submitPattern(String pattern) {
    if (pattern.trim().isEmpty) return;
    _focusNode.unfocus();
    _setQuery(pattern, regex: true);
  }

  /// rx on or off runs the last submitted lookup again in the new mode.
  void _toggleRegex() {
    final on = !ref.read(dictionaryRegexProvider);
    ref.read(dictionaryRegexProvider.notifier).state = on;
    _suggestDebounce?.cancel();
    setState(() => _draft = _query);
    if (_query.isNotEmpty) _performSearch(_query);
    // A pattern that cleans to no word (`-`) runs no plain lookup; its
    // regex results must not stay up with rx off.
    if (!on && _queryIsRegex) {
      _setQuery('', regex: false);
    }
  }

  /// Back and forward put a word on screen without adding it to any list.
  void _stepHistory(String? word) {
    if (word == null) return;
    _searchController.text = word;
    _showWord(word);
  }

  void _showWord(String word) {
    // A word from a tap, the history or the reader is a plain lookup. The
    // flag may not change while a widget builds, so it waits a microtask.
    if (ref.read(dictionaryRegexProvider)) {
      Future.microtask(() {
        if (mounted) ref.read(dictionaryRegexProvider.notifier).state = false;
      });
    }
    _setQuery(word, regex: false);
  }

  void _setQuery(String word, {required bool regex}) {
    _suggestDebounce?.cancel();
    setState(() {
      _query = word;
      _draft = word;
      _queryIsRegex = regex;
      _patternError = regex ? regexError(word) : null;
      _historyOpen = false;
      _suggestIndex = -1;
      _suggestPending = 0;
      _suggestKeys.clear();
      // A new search invalidates the memoized results body so it rebuilds
      // with the fresh query.
      _cachedResultsWidget = null;
      _cachedResultsQuery = null;
      _cachedResultsLookup = null;
      _cachedResultsSearchWord = null;
      _cachedResultsListKey = null;
      _cachedResultsSuggestions = null;
      _cachedResultsExpandedKey = null;
      _cachedResultsLevel = null;
      _cachedResultsFontScale = null;
      _cachedResultsShowSummary = null;
    });
  }

  void _selectWord(String word) {
    final converted = cleanDpdQuery(word);
    if (converted.isEmpty) return;
    _searchController.text = converted;
    _initiateSearch(converted);
  }

  /// Arrow Up/Down moves through the suggestion dropdown, Enter accepts the
  /// highlighted row. Returns handled only when a suggestion consumed the
  /// key, so the caret and normal submit keep working otherwise.
  KeyEventResult _handleSearchKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isDown = event.logicalKey == LogicalKeyboardKey.arrowDown;
    final isUp = event.logicalKey == LogicalKeyboardKey.arrowUp;
    final isEnter =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (!isDown && !isUp && !isEnter) return KeyEventResult.ignored;
    if (!mounted) return KeyEventResult.ignored;
    if (ref.read(dictionaryRegexProvider)) return KeyEventResult.ignored;
    // Flush the live textbox value: the draft is debounced, so without
    // this an arrow pressed right after typing would see stale state.
    // Both sides cleaned: a typed draft is already clean, but a word put on
    // screen by a tap or a chip is not, and must not count as new typing.
    final live = cleanDpdQuery(_searchController.text);
    if (live != cleanDpdQuery(_draft)) {
      _suggestDebounce?.cancel();
      setState(() {
        _draft = live;
        if (live.isEmpty) {
          _query = '';
        }
        _suggestIndex = -1;
        _suggestKeys.clear();
      });
    }
    // Same gate as the suggestion box in _buildContent.
    final mdxDicts = ref.read(mdxDictionariesProvider).valueOrNull ?? [];
    final hasMdx = mdxDicts.any(
      (d) => d.enabled && d.status == MdxStatus.ready,
    );
    if (_draft.isEmpty ||
        _draft == _query ||
        (_draft.length < kDictionarySuggestionMinLength && !hasMdx)) {
      return KeyEventResult.ignored;
    }
    final dpdAsync = ref.read(
      dpdSuggestionsProvider(
        _draft.length >= kDictionarySuggestionMinLength ? _draft : '',
      ),
    );
    final mdxAsync = ref.read(mdxSuggestionsProvider(_draft));
    final exactAsync = ref.read(mdxExactHitProvider(_draft));
    final items = _suggestionItems(
      dpdAsync.valueOrNull ?? [],
      mdxAsync.valueOrNull ?? [],
      exactAsync.valueOrNull ?? false,
    );
    if (items.isEmpty) {
      // Rows for the flushed draft are still loading: swallow the arrow
      // and highlight once they arrive, instead of dropping the keypress.
      final loading =
          dpdAsync.isLoading || mdxAsync.isLoading || exactAsync.isLoading;
      if (loading && (isDown || isUp)) {
        setState(() => _suggestPending = isDown ? 1 : -1);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (isEnter) {
      if (_suggestIndex < 0 || _suggestIndex >= items.length) {
        return KeyEventResult.ignored;
      }
      _selectWord(items[_suggestIndex].search);
      return KeyEventResult.handled;
    }
    setState(() {
      if (_suggestIndex >= items.length) {
        _suggestIndex = items.length - 1;
      }
      if (isDown) {
        _suggestIndex = _suggestIndex < items.length - 1
            ? _suggestIndex + 1
            : items.length - 1;
      } else {
        _suggestIndex = _suggestIndex == -1
            ? items.length - 1
            : _suggestIndex - 1;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _revealSuggestion();
    });
    return KeyEventResult.handled;
  }

  /// Scrolls the suggestion box to the selected row. The box is a lazy list:
  /// the row the arrow jumps to from the text field (the last one) has no
  /// widget until the list is at its end, so go there first.
  void _revealSuggestion() {
    final ctx = _suggestKeys[_suggestIndex]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx);
      return;
    }
    // No row selected: the arrow went back up to the text field.
    if (_suggestIndex < 0 || !_suggestScroll.hasClients) return;
    _suggestScroll.jumpTo(_suggestScroll.position.maxScrollExtent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final built = _suggestKeys[_suggestIndex]?.currentContext;
      if (mounted && built != null) Scrollable.ensureVisible(built);
    });
  }

  /// Toolbar shown when the user selects text inside a dictionary result.
  ///
  /// Leading action: re-search the selection in the dictionary, so a Pāli
  /// word spotted inside a definition (e.g. in bold) can be looked up with
  /// one more tap instead of copy-pasting it into the search field. Falls
  /// back to Copy / Select All when there is no selection to search.
  Widget _resultsContextMenu(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    final loc = AppLocalizations.of(context);
    TextSelectionToolbarAnchors anchors;
    try {
      anchors = selectableRegionState.contextMenuAnchors;
    } catch (_) {
      // Flutter bug: SelectableRegionState.startGlyphHeight can be null when
      // selecting very long content — fall back to a zero anchor so the
      // toolbar still shows instead of crashing.
      anchors = const TextSelectionToolbarAnchors(primaryAnchor: Offset.zero);
    }

    // Selection's plain text. Drop the U+FFFC placeholders flutter_html
    // inserts for inline elements (<details>, links…) and collapse newlines
    // so a re-search of the surrounding words is clean.
    final raw = _lastSelectedContent?.plainText;
    final searchable = raw == null || raw.trim().isEmpty
        ? null
        : raw.replaceAll('\uFFFC', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: anchors,
      buttonItems: [
        if (searchable != null)
          ContextMenuButtonItem(
            label: '${loc.search} “${_truncateLabel(searchable)}”',
            onPressed: () {
              selectableRegionState.clearSelection();
              _selectWord(searchable);
            },
          ),
        if (searchable != null && NativeLookupService.isSupported)
          ContextMenuButtonItem(
            label: '${loc.lookUp} “${_truncateLabel(searchable)}”',
            onPressed: () {
              selectableRegionState.clearSelection();
              NativeLookupService.lookUp(
                searchable,
                anchor: anchors.primaryAnchor,
              );
            },
          ),
        ContextMenuButtonItem(
          label: loc.copy,
          onPressed: () {
            final text = _lastSelectedContent?.plainText;
            if (text != null && text.isNotEmpty) {
              Clipboard.setData(ClipboardData(text: text));
            }
            selectableRegionState.clearSelection();
          },
        ),
        ContextMenuButtonItem(
          label: loc.selectAll,
          onPressed: () =>
              selectableRegionState.selectAll(SelectionChangedCause.toolbar),
        ),
      ],
    );
  }

  /// Shorten a long selection for the toolbar label (the full text is still
  /// searched).
  static String _truncateLabel(String s) =>
      s.length <= 28 ? s : '${s.substring(0, 28)}…';

  // ── Swipe-down-to-close helpers ──────────────────────────────────────

  void _onSheetPointerDown(PointerDownEvent _) {
    _pointersDown++;
    _swipeSamples.clear();
  }

  void _onSheetPointerUp(PointerUpEvent _) {
    if (_pointersDown > 0) _pointersDown--;
    // Decide on release, not mid-drag: a deliberate quick drag to shrink the
    // sheet for a peek can briefly exceed the flick threshold, so closing
    // mid-gesture would be surprising. On release, the last samples capture
    // a real flick. Guarded by [_dismissed] so the pop happens only once.
    final flicked =
        _swipeSamples.length >= 2 &&
        _swipeDownVelocity() > _kFlingCloseExtentPerSec;
    _swipeSamples.clear();
    if (!_dismissed && flicked) {
      _dismissed = true;
      Navigator.of(context).pop();
    }
  }

  void _onSheetPointerCancel(PointerCancelEvent _) {
    if (_pointersDown > 0) _pointersDown--;
    _swipeSamples.clear();
  }

  /// Records the current sheet extent with a timestamp, pruning samples
  /// older than the flick window. Called from the notification listener while
  /// the sheet moves.
  void _recordSwipeSample(double extent) {
    final ms = DateTime.now().millisecondsSinceEpoch;
    _swipeSamples.add((extent: extent, ms: ms));
    final cutoff = ms - _kFlingSampleWindowMs;
    while (_swipeSamples.length > 1 && _swipeSamples.first.ms < cutoff) {
      _swipeSamples.removeAt(0);
    }
  }

  /// Downward speed of the sheet (extents per second) over the recent
  /// sample window. Extent decreasing = sheet moving down = positive.
  double _swipeDownVelocity() {
    if (_swipeSamples.length < 2) return 0;
    final first = _swipeSamples.first;
    final last = _swipeSamples.last;
    final dtSec = (last.ms - first.ms) / 1000.0;
    if (dtSec <= 0) return 0;
    return (first.extent - last.extent) / dtSec;
  }

  @override
  Widget build(BuildContext context) {
    // The chips and the arrows read the shared history, which the panel can
    // also change. No PopScope here: a tap on the barrier above the sheet and
    // the back key both pop the route, and both must close the sheet.
    ref.watch(lookupHistoryProvider);
    final regexOn = ref.watch(dictionaryRegexProvider);
    ref.listen(dictionaryScrollTopRequestProvider, (_, _) {
      final controller = _sheetScroll;
      if (controller != null && controller.hasClients) controller.jumpTo(0);
    });
    ref.listen(dictionaryHistoryRequestProvider, (_, _) {
      setState(() => _historyOpen = true);
    });
    ref.listen(dictionaryBackRequestProvider, (_, _) {
      _stepHistory(_lookupHistory.goBack());
    });
    ref.listen(dictionaryForwardRequestProvider, (_, _) {
      _stepHistory(_lookupHistory.goForward());
    });
    ref.listen(dictionarySearchFocusRequestProvider, (_, _) {
      _focusNode.requestFocus();
    });
    final colors = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final pali = settings.typography.pali;
    // Use paddingOf() instead of MediaQuery.of(context) to avoid
    // rebuilding on every keyboard animation frame. MediaQuery.of(context)
    // subscribes to the entire MediaQuery including viewInsets, which
    // changes ~60 times during the ~300ms keyboard open animation,
    // causing the expensive dictionary results to rebuild per frame.
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    // The same chip size as the desktop panel, so the rows look alike.
    final chipSize = (pali.fontSize * 0.55).clamp(9.0, 14.0);

    // Strip the keyboard view insets so the Scaffold created by
    // showModalBottomSheet does not resize when the keyboard opens.
    // Without this, the DraggableScrollableSheet and its scrollbar/bottom
    // bar shift upward on every keyboard animation frame (~300ms).
    return MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      child: Listener(
        // Track fingers on the whole sheet so the flick velocity can be
        // estimated from extent samples on release (DraggableScrollableSheet
        // gives no velocity on drag end).
        onPointerDown: _onSheetPointerDown,
        onPointerUp: _onSheetPointerUp,
        onPointerCancel: _onSheetPointerCancel,
        child: NotificationListener<DraggableScrollableNotification>(
          // Dismiss when the user drags the sheet below the close extent, or
          // flicks it down fast from any height. Guarded by [_dismissed] so
          // the pop only happens once per gesture, preventing the reader
          // route underneath from also being closed.
          onNotification: (notification) {
            if (!_dismissed) {
              // Feed the fling estimator; the actual flick decision happens on
              // pointer-up so a quick deliberate drag can't close mid-gesture.
              _recordSwipeSample(notification.extent);
              if (notification.extent <= _sheetCloseExtent) {
                _dismissed = true;
                Navigator.of(context).pop();
              }
            }
            return false;
          },
          child: DraggableScrollableSheet(
            controller: _sheetController,
            // Don't expand to fill the whole screen: with `expand: true` (the
            // default) the sheet's internal scrollable covers the full screen
            // and swallows taps in the space above the sheet, so tapping
            // outside no longer dismisses the modal (the barrier never sees
            // the tap). With `expand: false` the scrollable only covers the
            // sheet itself and the top space returns to the modal barrier.
            expand: false,
            initialChildSize: _sheetInitialSize,
            minChildSize: _sheetMinSize,
            maxChildSize: _sheetMaxSize,
            // No snap: the sheet tracks the finger so a downward drag can always
            // reach [_sheetCloseExtent] and close the sheet from any height.
            snap: false,
            builder: (context, scrollController) {
              _sheetScroll = scrollController;
              return Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppDimensions.radiusSheet),
                  ),
                ),
                child: Column(
                  children: [
                    // The handle, search bar, and history row are wrapped in a
                    // GestureDetector so dragging on them also resizes/closes the
                    // sheet, same as dragging on the content area below.
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onVerticalDragUpdate: (details) {
                        // The dismiss pop below can dispose the sheet while the
                        // drag gesture is still delivering events (the route's
                        // exit animation keeps the pointer stream alive), which
                        // detaches the controller mid-gesture. Guard so those
                        // trailing events no-op instead of asserting.
                        if (!_sheetController.isAttached) return;
                        // Use sizeOf() to avoid rebuilding the whole sheet
                        // when viewInsets change (keyboard open/close).
                        final screenHeight = MediaQuery.sizeOf(context).height;
                        final delta = details.primaryDelta! / screenHeight;
                        final newSize = (_sheetController.size - delta).clamp(
                          _sheetMinSize,
                          _sheetMaxSize,
                        );
                        _sheetController.jumpTo(newSize);
                      },
                      onVerticalDragEnd: (details) {
                        if (_dismissed || !_sheetController.isAttached) return;
                        final flick = details.primaryVelocity ?? 0;
                        if (flick > _kHeaderFlingVelocityPxPerSec ||
                            _sheetController.size <= _sheetCloseExtent) {
                          _dismissed = true;
                          Navigator.of(context).pop();
                        }
                      },
                      child: Column(
                        children: [
                          // Drag handle — a visual affordance for the pull-to-close /
                          // drag-to-expand gesture. The whole sheet is already draggable
                          // (handled by DraggableScrollableSheet), so this is purely
                          // decorative.
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: Container(
                                width: 36,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: colors.outlineVariant,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),

                          // The icon row, unless the user hid it.
                          if (ref.watch(dictionaryHeaderIconsProvider))
                            const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: DictionaryHeaderIcons(),
                                ),
                              ),
                            ),

                          // Search bar row
                          Padding(
                            padding: searchBoxPadding(SearchBoxSize.screen),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    focusNode: _focusNode,
                                    // `.m`, `.t`, `.n` are regex: rx keeps
                                    // them as typed.
                                    inputFormatters: regexOn
                                        ? const []
                                        : const [VelthuisInputFormatter()],
                                    autofocus: _shouldAutofocus,
                                    textInputAction: TextInputAction.search,
                                    decoration: searchBoxDecoration(
                                      context,
                                      hintText: AppLocalizations.of(
                                        context,
                                      ).searchPali,
                                      size: SearchBoxSize.screen,
                                      suffixIcon: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (_searchController.text.isNotEmpty)
                                            IconButton(
                                              icon: const Icon(Icons.clear),
                                              onPressed: () {
                                                _searchController.clear();
                                                _onSearchChanged('');
                                                _focusNode.requestFocus();
                                              },
                                            ),
                                          RegexToggleButton(
                                            on: regexOn,
                                            onToggle: _toggleRegex,
                                          ),
                                          if (!regexOn)
                                            const VelthuisHelpIcon(),
                                        ],
                                      ),
                                      errorText:
                                          _patternError != null &&
                                              _queryIsRegex &&
                                              _searchController.text == _query
                                          ? AppLocalizations.of(
                                              context,
                                            ).invalidPattern(_patternError!)
                                          : null,
                                    ),
                                    style: searchBoxTextStyle(
                                      context,
                                      size: SearchBoxSize.screen,
                                    ),
                                    onChanged: _onSearchChanged,
                                    onSubmitted: _performSearch,
                                  ),
                                ),
                                LookupHistoryButtons(
                                                    onBack: () =>
                                      _stepHistory(_lookupHistory.goBack()),
                                  onForward: () =>
                                      _stepHistory(_lookupHistory.goForward()),
                                ),
                                // Pin to right side panel (desktop only). When pinned,
                                // the lookup moves to the docked panel and this sheet
                                // closes.
                                if (ResponsiveBreakpoint.isDesktop(
                                  context,
                                )) ...[
                                  const SizedBox(width: 4),
                                  _SheetPinButton(
                                    word: _query,
                                    onPinned: () => Navigator.of(context).pop(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Search history row
                          if (_lookupHistory.words.isNotEmpty)
                            Container(
                              height: 32,
                              margin: const EdgeInsets.only(
                                top: 8,
                                left: 16,
                                right: 16,
                              ),
                              child: LookupHistoryChips(
                                words: _lookupHistory.words,
                                currentIndex: _lookupHistory.currentIndex,
                                colors: colors,
                                labelStyle: AppTypography.labelSmall.copyWith(
                                  color: colors.onSurfaceVariant,
                                  fontSize: chipSize,
                                  fontFamily: pali.fontFamily.fontFamily,
                                ),
                                // A word that is already in the history is
                                // searched as it is stored, not read as Velthuis.
                                onTap: (word) {
                                  _focusNode.unfocus();
                                  _selectWord(word);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppDimensions.sm),
                    const Divider(height: 1),

                    // Content area (uses the sheet's scroll controller so the
                    // sheet resizes while the content scrolls).
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: _buildContent(colors, scrollController),
                          ),
                          if (_historyOpen)
                            Positioned.fill(
                              child: LookupHistoryList(
                                words: _lookupHistory.words,
                                colors: colors,
                                onTap: (word) {
                                  _focusNode.unfocus();
                                  _selectWord(word);
                                },
                                onClose: () =>
                                    setState(() => _historyOpen = false),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Clear the system navigation bar.
                    SizedBox(height: bottomPadding),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme colors, ScrollController scrollController) {
    final mdxDicts = ref.watch(mdxDictionariesProvider).valueOrNull ?? [];
    final hasMdxDicts = mdxDicts.any(
      (d) => d.enabled && d.status == MdxStatus.ready,
    );
    final showSuggestions =
        !ref.watch(dictionaryRegexProvider) &&
        _draft.isNotEmpty &&
        _draft != _query &&
        (_draft.length >= kDictionarySuggestionMinLength || hasMdxDicts);
    if (_query.isEmpty && !showSuggestions) {
      return _buildIdleState(colors, scrollController);
    }
    // The suggestion box drops down over the results, as tall as its words, up
    // to the whole area.
    return Stack(
      children: [
        Positioned.fill(
          child: _query.isNotEmpty
              ? _buildResults(colors, scrollController)
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      AppLocalizations.of(context).dictIdlePrompt,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyTranslation.copyWith(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
        ),
        if (showSuggestions)
          Align(
            alignment: Alignment.topCenter,
            child: _buildSuggestionBox(colors),
          ),
      ],
    );
  }

  /// Prefix suggestions for the live draft (typing). Merges DPD prefix
  /// matches with MDX suggestions (enabled dicts, user order), with an
  /// exact MDX headword match pinned at the top. Tapping a suggestion
  /// submits it as the full lookup.
  Widget _buildSuggestionBox(ColorScheme colors) {
    final dpdAsync = ref.watch(
      dpdSuggestionsProvider(
        _draft.length >= kDictionarySuggestionMinLength ? _draft : '',
      ),
    );
    final mdxAsync = ref.watch(mdxSuggestionsProvider(_draft));
    final exactAsync = ref.watch(mdxExactHitProvider(_draft));
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 0),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Builder(
        builder: (context) {
          final dpd = dpdAsync.valueOrNull ?? [];
          final mdx = mdxAsync.valueOrNull ?? [];
          final tiles = _mergedSuggestionTiles(colors, dpd, mdx, exactAsync);
          // Arrow pressed while rows were loading: highlight now.
          if (_suggestPending != 0 && tiles.isNotEmpty) {
            final pending = _suggestPending;
            final last = tiles.length - 1;
            _suggestPending = 0;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => _suggestIndex = pending > 0 ? 0 : last);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _revealSuggestion();
              });
            });
          }
          if (tiles.isEmpty) {
            if (dpdAsync.isLoading || mdxAsync.isLoading) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          }
          return ListView.builder(
            controller: _suggestScroll,
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: tiles.length,
            itemBuilder: (context, index) => tiles[index],
          );
        },
      ),
    );
  }

  /// Merge MDX suggestions (enabled-order dicts first) with DPD rows,
  /// pinning the exact headword at the top. Dedupes case-insensitively.
  /// Shared with [_handleSearchKey] so keyboard and pointer pick the same
  /// rows in the same order.
  List<({String word, String search, String? preview, bool isExact})>
  _suggestionItems(List<String> dpd, List<String> mdx, bool exact) {
    final seen = <String>{};
    final items =
        <({String word, String search, String? preview, bool isExact})>[];
    void add(String word, String search, String? preview, bool isExact) {
      if (seen.add(word.toLowerCase()) && items.length < kSuggestionMaxRows) {
        items.add((
          word: word,
          search: search,
          preview: preview,
          isExact: isExact,
        ));
      }
    }

    final query = _draft.trim();
    if (exact) {
      add(query, query, null, true);
    }
    for (final w in mdx) {
      add(w, w, null, false);
    }
    for (final w in dpd) {
      add(w, w, null, false);
    }
    return items;
  }

  List<Widget> _mergedSuggestionTiles(
    ColorScheme colors,
    List<String> dpd,
    List<String> mdx,
    AsyncValue<bool> exactAsync,
  ) {
    final query = _draft.trim();
    final items = _suggestionItems(dpd, mdx, exactAsync.valueOrNull == true);
    final selected = _suggestIndex < items.length ? _suggestIndex : -1;
    return items.asMap().entries.map((e) {
      final i = e.key;
      final it = e.value;
      return SuggestionTile(
        key: _suggestKeys.putIfAbsent(i, () => GlobalKey()),
        word: it.word,
        meaningPreview: it.preview,
        onTap: () => _selectWord(it.search),
        colors: colors,
        highlightQuery: query,
        isExact: it.isExact,
        selected: i == selected,
      );
    }).toList();
  }

  Widget _buildIdleState(
    ColorScheme colors,
    ScrollController scrollController,
  ) {
    final pali = ref.watch(dictionaryPaliProvider);
    final paliSize = (pali.fontSize * 0.8).clamp(kDictionaryMinTextSize, 26.0);
    final idlePromptSize = (pali.fontSize * 0.72).clamp(kDictionaryMinTextSize, 24.0);
    // Attach the sheet's scroll controller even when idle: the header's
    // drag-to-resize/close reads the sheet size via the controller, and
    // DraggableScrollableController.isAttached requires the controller to
    // have a client scrollable. Without one (plain Center), every header
    // drag while the dictionary was opened empty hit the framework's
    // 'not attached to a sheet' assertion in debug and did nothing.
    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.menu_book,
                  size: 56,
                  color: colors.primary.withValues(alpha: 0.3),
                ),
                const SizedBox(height: AppDimensions.md),
                Text(
                  AppLocalizations.of(context).dictionary,
                  style: AppTypography.headlineSmall.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: paliSize,
                  ),
                ),
                const SizedBox(height: AppDimensions.sm),
                Text(
                  AppLocalizations.of(context).dictIdlePrompt,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyTranslation.copyWith(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                    fontSize: idlePromptSize,
                    fontFamily: pali.fontFamily.fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Build the results — directly look up the word and show detail.
  /// If the exact lookup fails, fall back to prefix search suggestions.
  Widget _buildResults(ColorScheme colors, ScrollController scrollController) {
    if (_patternError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            AppLocalizations.of(context).invalidPattern(_patternError!),
            style: AppTypography.bodyTranslation.copyWith(color: colors.error),
          ),
        ),
      );
    }
    // Try exact lookup first
    return ref
        .watch(
          _queryIsRegex
              ? dpdRegexLookupProvider(_query)
              : dpdLookupProvider(_query),
        )
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                e is RegexTooSlow
                    ? AppLocalizations.of(context).patternTooSlow
                    : AppLocalizations.of(context).errorMessage(e.toString()),
                style: AppTypography.bodyTranslation.copyWith(
                  color: colors.error,
                ),
              ),
            ),
          ),
          data: (lookup) {
            if (lookup.regexTotal != null) {
              return _buildDictionaryResults(colors, lookup, scrollController);
            }
            final hasDpdMatch = lookup.hasMatch;
            // DPD is not the only dictionary: the enabled Bold Definition
            // and other books can match words DPD has no entry for. When DPD
            // misses, still render those sections and append DPD's
            // "Did you mean?" suggestions underneath.
            return _buildDictionaryResults(
              colors,
              lookup,
              scrollController,
              includePrefixSuggestions:
                  !hasDpdMatch &&
                  lookup.unavailable == null &&
                  _query.length >= kDictionarySuggestionMinLength,
            );
          },
        );
  }

  /// Slivers for DPD "Did you mean?" prefix suggestions.
  ///
  /// Rendered below the enabled dictionary sections when DPD has no exact
  /// match for the searched word.
  List<Widget> _prefixSuggestionsSlivers(ColorScheme colors, WidgetRef ref) {
    final pali = ref.watch(dictionaryPaliProvider);

    final didYouMeanSize = (pali.fontSize * 0.64).clamp(kDictionaryMinTextSize, 18.0);
    return ref
        .watch(dpdClosestMatchesProvider(_query))
        .when(
          loading: () => [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
          ],
          error: (e, _) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  AppLocalizations.of(context).errorMessage(e.toString()),
                  style: AppTypography.bodyTranslation.copyWith(
                    color: colors.error,
                  ),
                ),
              ),
            ),
          ],
          data: (results) {
            if (results.isEmpty) return _noMatchesSlivers(colors);

            return [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppDimensions.sm),
                  child: Text(
                    AppLocalizations.of(context).didYouMean,
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: didYouMeanSize,
                      fontFamily: pali.fontFamily.fontFamily,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(0, AppDimensions.sm, 0, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final result = results[index];
                    // Note: meaningPreview is plain text (stripped inside
                    // SuggestionTile via _stripHtml), not flutter_html —
                    // no WidgetSpan risk here, so this one doesn't need
                    // ExcludeSemantics like the DPD cards below do.
                    return SuggestionTile(
                      word: result,
                      onTap: () => _selectWord(result),
                      colors: colors,
                      highlightQuery: _query.trim(),
                    );
                  }, childCount: results.length),
                ),
              ),
            ];
          },
        );
  }

  List<Widget> _noMatchesSlivers(ColorScheme colors) => [
    const SliverToBoxAdapter(child: SizedBox(height: 24)),
    SliverToBoxAdapter(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(48.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 48, color: colors.outlineVariant),
              const SizedBox(height: AppDimensions.md),
              Text(
                AppLocalizations.of(context).noMatchesFoundForQuery(_query),
                style: AppTypography.bodyTranslation.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  ];

  /// Show combined results from DPD and the other dictionaries, in the order
  /// of the user's dictionary list.
  Widget _buildDictionaryResults(
    ColorScheme colors,
    DpdLookup lookup,
    ScrollController scrollController, {
    bool includePrefixSuggestions = false,
  }) {
    // The cleaned lemma_1 for cross-dictionary search
    final searchWord = lookup.searchWord;
    final regexTotal = lookup.regexTotal;

    return Consumer(
      builder: (context, ref, _) {
        final listAsync = ref.watch(dictionaryListProvider);
        // Expand/collapse state is part of the memo key: toggling a card
        // must rebuild, while sheet drag frames reuse the cached tree.
        final expandedMap = ref.watch(dictionaryExpandedProvider);
        final level = ref.watch(dpdSettingsProvider.select((s) => s.level));
        final fontScale = ref.watch(dictionaryFontScaleProvider);
        final showSummary = ref.watch(
          dpdSettingsProvider.select((s) => s.showSummary),
        );
        // When DPD misses, the "Did you mean?" suggestions are a nested
        // provider; watch it here (instead of inside a cached subtree) so a
        // resolve invalidates the memoized results and rebuilds them.
        final suggestionsAsync = includePrefixSuggestions
            ? ref.watch(dpdClosestMatchesProvider(_query))
            : null;
        return listAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const SizedBox.shrink(),
          data: (allEntries) {
            // A regex answers from the DPD headword list only, drawn as the
            // usual headwords (and the summary, which lists them).
            final entries = regexTotal == null
                ? allEntries
                : [
                    for (final e in allEntries)
                      if (e.item.id == 'dpd_headwords' ||
                          e.item.id == kDpdSummaryId)
                        e,
                  ];
            // Memoize: skip rebuilding when nothing changed. The sheet's
            // builder re-runs on every drag/keyboard frame, and rebuilding
            // flutter_html definitions each time is the dictionary's biggest
            // per-frame cost.
            final listKey = entries
                .map(
                  (e) => '${e.item.id}:${e.item.label}:${e.enabled}:${e.item.ready}',
                )
                .join('|');
            final expandedKey = [
              for (final e in entries)
                if (e.enabled && e.item.kind != DictionaryItemKind.dpdSource)
                  '${e.item.id}:${expandedMap[e.item.id] ?? true}',
            ].join('|');
            // Suggestions value identity is part of the key: when it
            // transitions loading → data, the builder re-runs (watch above)
            // and this comparison fails, forcing a rebuild with fresh data.
            if (_cachedResultsWidget != null &&
                _cachedResultsQuery == _query &&
                identical(_cachedResultsLookup, lookup) &&
                _cachedResultsSearchWord == searchWord &&
                _cachedResultsListKey == listKey &&
                identical(_cachedResultsSuggestions, suggestionsAsync) &&
                _cachedResultsExpandedKey == expandedKey &&
                _cachedResultsLevel == level &&
                _cachedResultsFontScale == fontScale &&
                _cachedResultsShowSummary == showSummary &&
                _cachedResultsColors == colors) {
              return _cachedResultsWidget!;
            }

            // Select-and-search: the whole results block sits inside a
            // SelectionArea so any word inside a definition can be
            // long-pressed/double-tapped (or drag-selected on desktop) and
            // re-looked-up via the toolbar's "Search" action — the cheap
            // alternative to wrapping every Pāli word in a tappable link
            // (that regex linkification was the single most expensive step
            // in rendering a DPD entry and was removed for performance).
            // Being inside the memoized widget means dragging the sheet
            // never rebuilds this subtree, so selection costs nothing on
            // drag frames.
            final built = SelectionArea(
              onSelectionChanged: (content) => _lastSelectedContent = content,
              contextMenuBuilder: (context, selectableRegionState) =>
                  _resultsContextMenu(context, selectableRegionState),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, AppDimensions.sm, 10, 0),
                child: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    if (regexTotal == 0) ..._noMatchesSlivers(colors),
                    if (regexTotal != null &&
                        regexTotal > lookup.headwords.length)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            AppLocalizations.of(context).regexMatchesShown(
                              regexTotal,
                              lookup.headwords.length,
                            ),
                            style: AppTypography.labelSmall.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    for (final w in buildOrderedDictionaryItems(
                      entries: entries,
                      lookup: lookup,
                      level: level,
                      searchWord: searchWord,
                      colors: colors,
                      onWordTap: _selectWord,
                      anchors: _anchors,
                      onJump: (id) => _anchors.jumpTo(id, scrollController),
                      showSummary: showSummary,
                    ))
                      SliverToBoxAdapter(child: w),
                    if (includePrefixSuggestions)
                      ..._prefixSuggestionsSlivers(colors, ref),
                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                ),
              ),
            );
            _cachedResultsWidget = built;
            _cachedResultsQuery = _query;
            _cachedResultsLookup = lookup;
            _cachedResultsSearchWord = searchWord;
            _cachedResultsListKey = listKey;
            _cachedResultsSuggestions = suggestionsAsync;
            _cachedResultsExpandedKey = expandedKey;
            _cachedResultsLevel = level;
            _cachedResultsFontScale = fontScale;
            _cachedResultsShowSummary = showSummary;
            _cachedResultsColors = colors;
            return built;
          },
        );
      },
    );
  }
}

/// A pin/unpin button shown inside the dictionary bottom sheet (desktop only).
///
/// When pinned, the dictionary is docked into the right side panel and the
/// sheet closes. Closing the right panel (via its close button) resets the
/// pin automatically, so the next lookup returns to the popup sheet.
class _SheetPinButton extends ConsumerWidget {
  final String word;
  final VoidCallback onPinned;

  const _SheetPinButton({required this.word, required this.onPinned});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final left = ref.watch(sidePanelProvider).left;
    final isPinned =
        left.openPanel == SidePanelType.dictionary && left.isPinned;

    return Tooltip(
      message: isPinned
          ? AppLocalizations.of(context).unpinFromSidePanel
          : AppLocalizations.of(context).pinToSidePanel,
      child: InkWell(
        onTap: () {
          final notifier = ref.read(sidePanelProvider.notifier);
          if (isPinned) {
            notifier.togglePin(SidePanelType.dictionary);
          } else {
            final w = word.trim();
            notifier.open(
              SidePanelType.dictionary,
              data: w.isNotEmpty ? w : null,
              pin: true,
            );
            onPinned();
          }
        },
        borderRadius: BorderRadius.circular(9999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isPinned
                ? colors.primary.withValues(alpha: 0.15)
                : colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Icon(
            isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            size: 18,
            color: isPinned ? colors.primary : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
