import 'dart:async';

import 'package:epitaka/shared/providers/side_panel_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dpd/providers/dictionary_list_provider.dart';
import '../providers/dictionary_panel_memory.dart';
import '../../dpd/providers/dpd_lookup_provider.dart';
import '../../dpd/providers/dpd_settings_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/native_lookup_service.dart';
import '../../../core/utils/velthuis.dart';
import '../../dpd/providers/lookup_history.dart';
import '../../dpd/utils/query_cleaning.dart';
import 'lookup_history_buttons.dart';
import 'lookup_history_chips.dart';
import '../../mdx_dictionary/models/mdx_dictionary_info.dart';
import '../../mdx_dictionary/providers/mdx_dictionary_provider.dart';
import '../../mdx_dictionary/providers/mdx_lookup_providers.dart';
import 'dictionary_search_shared.dart';
import 'ordered_dictionary_items.dart';
import 'page_anchors.dart';

/// A dictionary panel that can be shown in a sidebar or as a standalone
/// widget. When used in the right sidebar on desktop, it communicates
/// with [SidePanelProvider] for word lookup navigation.
class DictionaryPanel extends ConsumerStatefulWidget {
  final String initialWord;

  /// When true, the search text field is focused once the panel is built.
  /// Used by the Ctrl/Cmd + D shortcut so the user can type immediately.
  /// This is intentionally NOT triggered on word double-click (which opens
  /// the dictionary with a word already filled in) to avoid popping up the
  /// on-screen keyboard on touch devices.
  final bool autoFocus;

  const DictionaryPanel({
    super.key,
    this.initialWord = '',
    this.autoFocus = false,
  });

  @override
  ConsumerState<DictionaryPanel> createState() => _DictionaryPanelState();
}

class _DictionaryPanelState extends ConsumerState<DictionaryPanel> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  /// Where each summary line of the results jumps to.
  final PageAnchors _anchors = PageAnchors();
  Timer? _suggestDebounce;
  bool _isConverting = false;

  // Submitted word (meanings shown) vs live draft (suggestions only).
  String _query = '';
  String _draft = '';

  // Keyboard navigation over the suggestion dropdown: -1 = caret in the
  // field, otherwise the highlighted suggestion index (Enter accepts it).
  int _suggestIndex = -1;
  final Map<int, GlobalKey> _suggestKeys = {};
  // Arrow pressed while suggestions were still loading: 0 = none,
  // 1 = highlight first row, -1 = highlight last row once rows arrive.
  int _suggestPending = 0;

  /// Back and forward over the words looked up in this panel.
  LookupHistory get _lookupHistory => ref.read(lookupHistoryProvider);

  /// A provider cannot change inside `initState` or `didChangeDependencies`,
  /// which is where a word handed to this widget arrives, so the add waits one
  /// microtask.
  void _recordLookup(String word) => Future.microtask(() {
    if (mounted) _lookupHistory.navigateTo(word);
  });

  /// The last selection made inside the results, tracked via the
  /// SelectionArea's `onSelectionChanged` (SelectableRegionState exposes no
  /// public accessor for the selected text).
  SelectedContent? _lastSelectedContent;

  @override
  void initState() {
    super.initState();
    final handedIn = cleanShownWord(widget.initialWord);
    // With no word handed in, carry on from the word the sheet or an earlier
    // panel left current.
    final initial = handedIn.isNotEmpty ? handedIn : (_lookupHistory.current ?? '');
    if (initial.isNotEmpty) {
      _searchController.text = initial;
      _query = initial;
      _draft = initial;
      _recordLookup(initial);
    }
    if (handedIn.isEmpty && widget.autoFocus) {
      // Focus the search field after the first frame so the keyboard can show.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
    _focusNode.onKeyEvent = _handleSearchKey;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Apply the word the panel was opened with (if any) on first mount. This
    // is a read (not a watch): subsequent word updates arrive through the
    // [ref.listen] in build, and watching here would rebuild the whole panel
    // on every sidePanelProvider change (e.g. panel-width drags) for nothing.
    final panels = ref.read(sidePanelProvider);
    final panelData = panels.left.openPanel == SidePanelType.dictionary
        ? panels.left.panelData
        : panels.right.openPanel == SidePanelType.dictionary
        ? panels.right.panelData
        : null;
    if (panelData != null) {
      _syncPanelWord(panelData);
    }
  }

  /// Apply a dictionary word coming from [SidePanelProvider] to the search
  /// field, ignoring repeats of the current query.
  void _syncPanelWord(String word) {
    final trimmed = cleanShownWord(word);
    if (trimmed.isEmpty || trimmed == _query) return;
    _searchController.text = trimmed;
    _initiateSearch(trimmed);
  }

  @override
  void didUpdateWidget(DictionaryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newWord = cleanShownWord(widget.initialWord);
    if (newWord.isNotEmpty && newWord != cleanShownWord(oldWidget.initialWord)) {
      _searchController.text = newWord;
      _initiateSearch(newWord);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _suggestDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_isConverting) return;
    _suggestDebounce?.cancel();

    final converted = velthuis(value);
    // Only update the display for Roman-script input; non-Roman
    // scripts (Sinhala, Thai, Myanmar, …) pass through unchanged.
    if (isRomanScript(value) &&
        converted != value &&
        converted.trim().isNotEmpty) {
      _isConverting = true;
      _searchController.value = convertedTextEditingValue(
        _searchController.value,
      );
      _isConverting = false;
    }

    final trimmed = foldDpdQuery(converted).trim();
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
    final converted = cleanDpdQuery(value);
    if (converted.isEmpty) return;
    _suggestDebounce?.cancel();
    _focusNode.unfocus();
    _initiateSearch(converted);
  }

  void _initiateSearch(String word) {
    if (word.isEmpty) return;
    _recordLookup(word);
    _showWord(word);
  }

  /// Back and forward put a word on screen without adding it to any list.
  void _stepHistory(String? word) {
    if (word == null) return;
    _searchController.text = word;
    _showWord(word);
  }

  void _showWord(String word) {
    _suggestDebounce?.cancel();
    DictionaryPanelMemory.saveWord(word);
    setState(() {
      _query = word;
      _draft = word;
      _suggestIndex = -1;
      _suggestPending = 0;
      _suggestKeys.clear();
    });
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
    // Flush the live textbox value: the draft is debounced, so without
    // this an arrow pressed right after typing would see stale state.
    final live = _searchController.text.trim();
    if (live != _draft) {
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
    // Same gate as the suggestion box below.
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
      if (_suggestIndex >= items.length) _suggestIndex = items.length - 1;
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
      if (!mounted) return;
      final ctx = _suggestKeys[_suggestIndex]?.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx);
    });
    return KeyEventResult.handled;
  }

  void _selectWord(String word) {
    final converted = cleanShownWord(word);
    if (converted.isEmpty) return;
    _searchController.text = converted;
    _initiateSearch(converted);
  }

  /// Toolbar shown when the user selects text inside a result: re-search
  /// the selection in the dictionary, plus Copy / Select All. Mirrors the
  /// dictionary sheet's toolbar.
  Widget _resultsContextMenu(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    final loc = AppLocalizations.of(context);
    TextSelectionToolbarAnchors anchors;
    try {
      anchors = selectableRegionState.contextMenuAnchors;
    } catch (_) {
      anchors = const TextSelectionToolbarAnchors(primaryAnchor: Offset.zero);
    }

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

  static String _truncateLabel(String s) =>
      s.length <= 28 ? s : '${s.substring(0, 28)}…';

  @override
  Widget build(BuildContext context) {
    // The recent chips and the arrows read the history the sheet also writes.
    ref.watch(lookupHistoryProvider);
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final pali = ref.watch(settingsProvider.select((s) => s.typography.pali));
    final searchSize = (pali.fontSize * 0.72).clamp(12.0, 22.0);
    final chipSize = (pali.fontSize * 0.55).clamp(9.0, 14.0);
    final mdxDicts = ref.watch(mdxDictionariesProvider).valueOrNull ?? [];
    final hasMdxDicts = mdxDicts.any(
      (d) => d.enabled && d.status == MdxStatus.ready,
    );

    // Word lookups routed from the reader (e.g. double-clicking a word on
    // desktop) arrive as panelData changes on [sidePanelProvider].
    // didChangeDependencies is only re-invoked on InheritedWidget changes,
    // NOT on provider changes — so without this listener the panel only
    // picked up a new word when something else (a window resize) happened to
    // rebuild it. React to the provider change explicitly instead.
    ref.listen(sidePanelProvider, (prev, next) {
      final word = next.left.openPanel == SidePanelType.dictionary
          ? next.left.panelData
          : next.right.openPanel == SidePanelType.dictionary
          ? next.right.panelData
          : null;
      if (word != null) _syncPanelWord(word);
    });

    return Column(
      children: [
        // Compact search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.sm,
            AppDimensions.sm,
            AppDimensions.sm,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: loc.searchPali,
                    isDense: true,
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: colors.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusLg,
                      ),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.sm,
                      vertical: 8,
                    ),
                  ),
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.onSurface,
                    fontSize: searchSize,
                    fontFamily: pali.fontFamily.fontFamily,
                  ),
                  onChanged: _onSearchChanged,
                  onSubmitted: _performSearch,
                ),
              ),
              LookupHistoryButtons(
                onBack: () => _stepHistory(_lookupHistory.goBack()),
                onForward: () => _stepHistory(_lookupHistory.goForward()),
              ),
            ],
          ),
        ),

        // Search history chips
        if (_lookupHistory.words.isNotEmpty)
          Container(
            height: 32,
            margin: const EdgeInsets.only(top: 4, left: 8, right: 8),
            child: LookupHistoryChips(
              words: _lookupHistory.words,
              currentIndex: _lookupHistory.currentIndex,
              colors: colors,
              labelStyle: AppTypography.labelSmall.copyWith(
                color: colors.onSurfaceVariant,
                fontSize: chipSize,
                fontFamily: pali.fontFamily.fontFamily,
              ),
              // A word that is already in the history is searched as it is
              // stored, not read as Velthuis.
              onTap: (word) {
                _focusNode.unfocus();
                _selectWord(word);
              },
            ),
          ),

        const SizedBox(height: 4),
        const Divider(height: 1),

        if (_draft.isNotEmpty &&
            _draft != _query &&
            (_draft.length >= kDictionarySuggestionMinLength || hasMdxDicts))
          _buildSuggestionBox(colors),

        // Results (only for the submitted word)
        Expanded(
          child: _query.isEmpty
              ? _buildIdleState(colors)
              : _buildResults(colors),
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
      constraints: const BoxConstraints(maxHeight: 220),
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
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
                if (!mounted) return;
                final ctx = _suggestKeys[_suggestIndex]?.currentContext;
                if (ctx != null) {
                  Scrollable.ensureVisible(ctx);
                }
              });
            });
          }
          if (tiles.isEmpty) {
            if (dpdAsync.isLoading || mdxAsync.isLoading) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          }
          return ListView.builder(
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
      if (seen.add(word.toLowerCase()) && items.length < 10) {
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

  Widget _buildIdleState(ColorScheme colors) {
    final loc = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book,
            size: 40,
            color: colors.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            loc.dictionary,
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(ColorScheme colors) {
    final loc = AppLocalizations.of(context);
    return ref
        .watch(dpdLookupProvider(_query))
        .when(
          loading: () =>
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                loc.errorMessage(e.toString()),
                style: AppTypography.labelSmall.copyWith(color: colors.error),
              ),
            ),
          ),
          data: (lookup) {
            final hasDpdMatch = lookup.hasMatch;
            // DPD is not the only dictionary: the enabled Bold Definition
            // and other books can match words DPD has no entry for. When DPD
            // misses, still render those sections and append DPD's
            // "Did you mean?" suggestions underneath.
            return _buildDictionaryResults(
              colors,
              lookup,
              includePrefixSuggestions:
                  !hasDpdMatch &&
                  lookup.unavailable == null &&
                  _query.length >= kDictionarySuggestionMinLength,
            );
          },
        );
  }

  /// Children for DPD "Did you mean?" prefix suggestions.
  ///
  /// Rendered below the enabled dictionary sections when DPD has no exact
  /// match for the searched word.
  List<Widget> _prefixSuggestionChildren(ColorScheme colors) {
    final loc = AppLocalizations.of(context);
    return ref
        .watch(dpdClosestMatchesProvider(_query))
        .when(
          loading: () => [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ],
          error: (e, _) => [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                loc.errorMessage(e.toString()),
                style: AppTypography.labelSmall.copyWith(color: colors.error),
              ),
            ),
          ],
          data: (results) {
            if (results.isEmpty) {
              return [
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 36,
                        color: colors.outlineVariant,
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      Text(
                        loc.noMatchesForQuery(_query),
                        style: AppTypography.labelSmall.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ];
            }
            return [
              Text(
                loc.didYouMean,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              ...results.map(
                (r) => SuggestionTile(
                  word: r,
                  onTap: () => _selectWord(r),
                  colors: colors,
                  highlightQuery: _query.trim(),
                ),
              ),
            ];
          },
        );
  }

  Widget _buildDictionaryResults(
    ColorScheme colors,
    DpdLookup lookup, {
    bool includePrefixSuggestions = false,
  }) {
    final searchWord = lookup.searchWord;

    return Consumer(
      builder: (context, ref, _) {
        final listAsync = ref.watch(dictionaryListProvider);
        final level = ref.watch(dpdSettingsProvider.select((s) => s.level));
        final showSummary = ref.watch(
          dpdSettingsProvider.select((s) => s.showSummary),
        );
        return listAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (_, _) => const SizedBox.shrink(),
          data: (entries) {
            final children = <Widget>[
              ...buildOrderedDictionaryItems(
                entries: entries,
                lookup: lookup,
                level: level,
                searchWord: searchWord,
                colors: colors,
                onWordTap: _selectWord,
                anchors: _anchors,
                onJump: (id) => _anchors.jumpTo(id, _scrollController),
                showSummary: showSummary,
              ),
              if (includePrefixSuggestions)
                ..._prefixSuggestionChildren(colors),
              const SizedBox(height: 24),
            ];
            // Select-and-search: same treatment as the dictionary sheet — a
            // SelectionArea over the results lets any word inside a
            // definition be selected and re-looked-up via the toolbar's
            // "Search" action, without the per-word linkification that was
            // dropped for performance.
            return SelectionArea(
              onSelectionChanged: (content) => _lastSelectedContent = content,
              contextMenuBuilder: (context, selectableRegionState) =>
                  _resultsContextMenu(context, selectableRegionState),
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(AppDimensions.sm),
                children: children,
              ),
            );
          },
        );
      },
    );
  }
}
