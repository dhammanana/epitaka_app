import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/dpd_dictionary_database.dart';
import '../../../core/providers/dictionary_books_provider.dart';
import '../../../core/providers/dpd_dictionary_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_breakpoint.dart';
import '../../../core/utils/velthuis.dart';
import '../../../shared/providers/side_panel_provider.dart';
import '../providers/dictionary_sheet_open_provider.dart';
import 'dictionary_search_shared.dart';
import 'pali_definition_card.dart';

Future<T?> showDictionarySheet<T>(BuildContext context, String word) {
  // Mark the sheet as open so the reader behind it can drop its (very deep)
  // semantics subtree from collection. Collecting the reader's huge
  // ScrollablePositionedList while the sheet's own semantics are being built
  // causes re-entrant flushSemantics and the framework's
  // '!semantics.parentDataDirty' / '!conflict' assertions (see
  // reading_paragraph.dart). A modal sheet is exactly the case where the
  // behind-content should not be in the accessibility tree.
  final container = ProviderScope.containerOf(context);
  container.read(dictionarySheetOpenProvider.notifier).state = true;
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
    builder: (_) => DictionarySheet(initialWord: word),
  ).whenComplete(() {
    container.read(dictionarySheetOpenProvider.notifier).state = false;
  });
}

// ── Sheet sizing ────────────────────────────────────────────────────────
// The sheet follows the finger (no snap) so the user can freely:
//   • drag up    → the sheet grows and its content scrolls (see more info)
//   • drag down  → when released below [_sheetCloseExtent] the sheet closes
//
// We dismiss via a single guarded route pop (see the notification listener)
// which avoids the previous bug where a repeated maybePop also closed the
// reader route underneath.
const double _sheetMinSize = 0.25;
const double _sheetInitialSize = 0.7;
const double _sheetMaxSize = 0.95;
// Dragging the sheet below this extent dismisses it.
const double _sheetCloseExtent = 0.3;

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
  final _sheetController = DraggableScrollableController();
  Timer? _debounce;
  bool _isConverting = false;

  // Guards the single dismiss of this sheet's route so that a continuous
  // drag gesture can't pop the reader route underneath as well.
  bool _dismissed = false;

  // The currently looked up word
  String _query = '';

  // Deconstructor state (simple ints instead of TabController to avoid
  // !semantics.parentDataDirty assertion errors inside CustomScrollView)
  // -1 means no candidate card is expanded (all collapsed by default).
  int _activeDeconCardIndex = -1;
  int _activeDeconTokenIndex = 0;

  /// Cached sub-lookup results for deconstructor tokens.
  /// key: token word, value: list of headword rows
  final Map<String, List<DpdHeadwordRow>> _subLookupCache = {};
  // Bumped whenever _subLookupCache gains an entry, so the DPD section
  // memoization below knows to rebuild.
  int _subLookupVersion = 0;

  // The DPD section (headwords + deconstructor) is the most expensive part
  // of the sheet to build: it parses full HTML entries and regex-processes
  // them into clickable links. DraggableScrollableSheet re-invokes its
  // `builder` on every drag frame (not just on setState), so without this
  // cache the whole DPD section — and all its HTML parsing — was being
  // rebuilt from scratch dozens of times per second while the user simply
  // dragged the sheet. We reuse the last built widget whenever the
  // underlying data and UI state haven't actually changed.
  Widget? _cachedDpdSectionWidget;
  DpdFullLookup? _cachedDpdSectionLookup;
  int _cachedDpdSectionCardIndex = -2;
  int _cachedDpdSectionTokenIndex = -2;
  int _cachedDpdSectionSubLookupVersion = -1;

  // Search history
  late final List<String> _searchHistory = [];
  static const _historyPrefsKey = 'dict_search_history';
  static const _historyMaxLen = 100;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    final initial = widget.initialWord.trim();
    if (initial.isNotEmpty) {
      _searchController.text = initial;
      _query = initial;
      _addToHistory(initial);
      _performSearch(initial);
    }
  }

  Future _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_historyPrefsKey) ?? [];
    if (mounted) {
      setState(() {
        _searchHistory
          ..clear()
          ..addAll(saved);
      });
    }
  }

  void _addToHistory(String word) {
    final w = word.trim();
    if (w.isEmpty) return;
    setState(() {
      _searchHistory.remove(w);
      _searchHistory.insert(0, w);
      if (_searchHistory.length > _historyMaxLen) {
        _searchHistory.removeLast();
      }
    });
    _saveHistory();
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyPrefsKey, _searchHistory);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _sheetController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_isConverting) return;
    _debounce?.cancel();

    final converted = velthuis(value);

    if (converted != value && converted.trim().isNotEmpty) {
      _isConverting = true;
      _searchController.value = convertedTextEditingValue(
        _searchController.value,
      );
      _isConverting = false;
    }

    final trimmed = converted.trim();
    if (trimmed.isEmpty) {
      setState(() => _query = '');
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 200), () {
      _initiateSearch(trimmed);
    });
  }

  void _performSearch(String value) {
    final converted = velthuis(value).trim();
    if (converted.isEmpty) return;
    _focusNode.unfocus();
    _addToHistory(converted);
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
    setState(() {
      _query = word;
      _activeDeconCardIndex = -1;
      _activeDeconTokenIndex = 0;
      _subLookupCache.clear();
    });
  }

  void _selectWord(String word) {
    final converted = velthuis(word).trim();
    if (converted.isEmpty) return;
    _searchController.text = converted;
    _addToHistory(converted);
    _initiateSearch(converted);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final trans = settings.typography.typographyFor(
      settings.primaryTranslationLang,
    );
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final transSize = (trans.fontSize * 0.8).clamp(12.0, 24.0);

    return NotificationListener<DraggableScrollableNotification>(
      // Dismiss when the user drags the sheet below the smallest snap level.
      // Guarded by [_dismissed] so the pop only happens once per gesture,
      // preventing the reader route underneath from also being closed.
      onNotification: (notification) {
        if (!_dismissed && notification.extent <= _sheetCloseExtent) {
          _dismissed = true;
          Navigator.of(context).pop();
        }
        return false;
      },
      child: DraggableScrollableSheet(
        controller: _sheetController,
        initialChildSize: _sheetInitialSize,
        minChildSize: _sheetMinSize,
        maxChildSize: _sheetMaxSize,
        // No snap: the sheet tracks the finger so a downward drag can always
        // reach [_sheetCloseExtent] and close the sheet from any height.
        snap: false,
        builder: (context, scrollController) {
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
                      final screenHeight = MediaQuery.of(context).size.height;
                      final delta = details.primaryDelta! / screenHeight;
                      final newSize = (_sheetController.size - delta).clamp(
                        _sheetMinSize,
                        _sheetMaxSize,
                      );
                      _sheetController.jumpTo(newSize);
                    },
                    onVerticalDragEnd: (details) {
                      if (_sheetController.size <= _sheetCloseExtent &&
                          !_dismissed) {
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

                        // Search bar row
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            4,
                            AppDimensions.sm,
                            AppDimensions.marginMobile - 8,
                            0,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _focusNode,
                                  autofocus: _shouldAutofocus,
                                  textInputAction: TextInputAction.search,
                                  decoration: InputDecoration(
                                    hintText: 'Search Pāḷi…',
                                    prefixIcon: Icon(
                                      Icons.search,
                                      color: colors.onSurfaceVariant,
                                    ),
                                    suffixIcon:
                                        _searchController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: () {
                                              _searchController.clear();
                                              _onSearchChanged('');
                                              _focusNode.requestFocus();
                                            },
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: colors.surfaceContainerHighest,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppDimensions.radiusXl,
                                      ),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: AppDimensions.md,
                                      vertical: 12,
                                    ),
                                  ),
                                  style: AppTypography.bodyTranslation.copyWith(
                                    color: colors.onSurface,
                                    fontSize: transSize,
                                    fontFamily: trans.fontFamily.fontFamily,
                                  ),
                                  onChanged: _onSearchChanged,
                                  onSubmitted: _performSearch,
                                ),
                              ),
                              // Pin to right side panel (desktop only). When pinned,
                              // the lookup moves to the docked panel and this sheet
                              // closes.
                              if (ResponsiveBreakpoint.isDesktop(context)) ...[
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
                        if (_searchHistory.isNotEmpty)
                          Container(
                            height: 40,
                            margin: const EdgeInsets.only(
                              top: 8,
                              left: 16,
                              right: 16,
                            ),
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _searchHistory.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                return ActionChip(
                                  label: Text(_searchHistory[index]),
                                  labelStyle: AppTypography.labelSmall.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                  backgroundColor:
                                      colors.surfaceContainerHighest,
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  onPressed: () {
                                    _searchController.text =
                                        _searchHistory[index];
                                    _performSearch(_searchHistory[index]);
                                  },
                                );
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
                  Expanded(child: _buildContent(colors, scrollController)),

                  // Clear the system navigation bar.
                  SizedBox(height: bottomPadding),
                ],
              ),
            );
          },
        ),
    );
  }

  Widget _buildContent(ColorScheme colors, ScrollController scrollController) {
    if (_query.isEmpty) {
      return _buildIdleState(colors);
    }
    return _buildResults(colors, scrollController);
  }

  Widget _buildIdleState(ColorScheme colors) {
    final settings = ref.watch(settingsProvider);
    final pali = settings.typography.pali;
    final trans = settings.typography.typographyFor(
      settings.primaryTranslationLang,
    );
    final paliSize = (pali.fontSize * 0.8).clamp(13.0, 26.0);
    final transSize = (trans.fontSize * 0.8).clamp(12.0, 24.0);
    return Center(
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
            'Dictionary',
            style: AppTypography.headlineSmall.copyWith(
              color: colors.onSurfaceVariant,
              fontSize: paliSize,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            'Search for a Pāḷi word to see\ndefinitions across multiple dictionaries',
            textAlign: TextAlign.center,
            style: AppTypography.bodyTranslation.copyWith(
              color: colors.onSurfaceVariant.withValues(alpha: 0.7),
              fontSize: transSize,
              fontFamily: trans.fontFamily.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  /// Build the results — directly look up the word and show detail.
  /// If the exact lookup fails, fall back to prefix search suggestions.
  Widget _buildResults(ColorScheme colors, ScrollController scrollController) {
    // Try exact lookup first
    return ref
        .watch(dpdDictionaryLookupProvider(_query))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Error: $e',
                style: AppTypography.bodyTranslation.copyWith(
                  color: colors.error,
                ),
              ),
            ),
          ),
          data: (lookup) {
            if (lookup.hasHeadwords || lookup.hasDeconstructor) {
              return _buildDictionaryResults(colors, lookup, scrollController);
            }
            // No exact match — show prefix search suggestions
            return _buildPrefixSuggestions(colors, scrollController);
          },
        );
  }

  /// Show prefix search results as "Did you mean?" suggestions.
  Widget _buildPrefixSuggestions(
    ColorScheme colors,
    ScrollController scrollController,
  ) {
    final settings = ref.watch(settingsProvider);
    final trans = settings.typography.typographyFor(
      settings.primaryTranslationLang,
    );

    final transSize = (trans.fontSize * 0.8).clamp(12.0, 24.0);
    return ref
        .watch(dpdDictionarySearchProvider(_query))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Error: $e',
                style: AppTypography.bodyTranslation.copyWith(
                  color: colors.error,
                ),
              ),
            ),
          ),
          data: (results) {
            if (results.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(48.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 48,
                        color: colors.outlineVariant,
                      ),
                      const SizedBox(height: AppDimensions.md),
                      Text(
                        'No matches found for "$_query"',
                        style: AppTypography.bodyTranslation.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            return CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimensions.marginMobile,
                      AppDimensions.sm,
                      AppDimensions.marginMobile,
                      0,
                    ),
                    child: Text(
                      'Did you mean…',
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: transSize,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.marginMobile,
                    AppDimensions.sm,
                    AppDimensions.marginMobile,
                    32,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final result = results[index];
                      // Note: meaningPreview is plain text (stripped inside
                      // SuggestionTile via _stripHtml), not flutter_html —
                      // no WidgetSpan risk here, so this one doesn't need
                      // ExcludeSemantics like the DPD cards below do.
                      return SuggestionTile(
                        word: result.lemma1,
                        meaningPreview: result.meaningHtml,
                        onTap: () => _selectWord(result.lemma1),
                        colors: colors,
                      );
                    }, childCount: results.length),
                  ),
                ),
              ],
            );
          },
        );
  }

  /// Show combined results from DPD and other dictionaries.
  ///
  /// DPD (book_id=11) and the Pāli definition dictionary (book_id=100) are
  /// rendered inline at their settings-defined order position rather than
  /// pinned to the top.
  Widget _buildDictionaryResults(
    ColorScheme colors,
    DpdFullLookup lookup,
    ScrollController scrollController,
  ) {
    // Get the cleaned lemma_1 for cross-dictionary search
    String searchWord = _query;
    if (lookup.headwords.isNotEmpty) {
      searchWord = lookup.headwords.first.cleanLemma1;
    }

    return Consumer(
      builder: (context, ref, _) {
        final booksAsync = ref.watch(dictionaryBooksNotifierProvider);
        return booksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const SizedBox.shrink(),
          data: (books) {
            final enabledBooks = books.where((b) => b.userChoice).toList();
            return CustomScrollView(
              controller: scrollController,
              slivers: [
                ..._buildDictionarySections(
                  colors,
                  lookup,
                  searchWord,
                  enabledBooks,
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            );
          },
        );
      },
    );
  }

  /// Build all dictionary sections in settings order.
  ///
  /// - book_id=11 (DPD) → rich DPD section (headwords + deconstructor)
  /// - book_id=100 (Pāli definition) → linked sentence cards
  /// - everything else → plain-text definition lookup
  ///
  /// Each section owns its own outer padding and returns a zero-size widget
  /// when it has no record, so empty dictionaries simply disappear (no
  /// "No entry found" text).
  List<Widget> _buildDictionarySections(
    ColorScheme colors,
    DpdFullLookup lookup,
    String searchWord,
    List<DictionaryBook> enabledBooks,
  ) {
    if (enabledBooks.isEmpty) return const <Widget>[];

    return enabledBooks.map((book) {
      final child = switch (book.id) {
        11 =>
          (lookup.hasHeadwords || lookup.hasDeconstructor)
              ? _buildDpdSectionMemoized(colors, lookup)
              : const SizedBox.shrink(),
        100 => PaliDefinitionSection(
          searchWord: searchWord,
          bookName: book.name,
          colors: colors,
        ),
        _ => DictDefinitionSection(
          bookId: book.id,
          bookName: book.name,
          searchWord: searchWord,
          colors: colors,
        ),
      };
      if (child is SizedBox && child.child == null) {
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }
      return SliverToBoxAdapter(child: child);
    }).toList();
  }

  // ── DPD Section ──────────────────────────────────────────────────────────

  /// Returns the DPD section widget, rebuilding it only when the underlying
  /// data or expand/collapse state actually changed. See the fields above
  /// for why this cache exists — it's what keeps sheet dragging smooth.
  Widget _buildDpdSectionMemoized(ColorScheme colors, DpdFullLookup lookup) {
    final cached = _cachedDpdSectionWidget;
    if (cached != null &&
        identical(_cachedDpdSectionLookup, lookup) &&
        _cachedDpdSectionCardIndex == _activeDeconCardIndex &&
        _cachedDpdSectionTokenIndex == _activeDeconTokenIndex &&
        _cachedDpdSectionSubLookupVersion == _subLookupVersion) {
      return cached;
    }
    final built = _buildDpdSection(colors, lookup);
    _cachedDpdSectionWidget = built;
    _cachedDpdSectionLookup = lookup;
    _cachedDpdSectionCardIndex = _activeDeconCardIndex;
    _cachedDpdSectionTokenIndex = _activeDeconTokenIndex;
    _cachedDpdSectionSubLookupVersion = _subLookupVersion;
    return built;
  }

  Widget _buildDpdSection(ColorScheme colors, DpdFullLookup lookup) {
    final settings = ref.watch(settingsProvider);
    final pali = settings.typography.pali;
    final paliFontFamily = pali.fontFamily.fontFamily;
    return Padding(
      padding: EdgeInsetsGeometry.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label
          Row(
            children: [
              Icon(Icons.auto_stories, size: 16, color: colors.primary),
              const SizedBox(width: 6),
              Text(
                'dpd dictionary',
                style: AppTypography.labelSmall.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: (pali.fontSize * 0.55).clamp(9.0, 14.0),
                  fontFamily: paliFontFamily,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Searched word
          Text(
            lookup.searchedKey,
            style: AppTypography.displayPali.copyWith(
              color: colors.onSurface,
              fontSize: (pali.fontSize * 1.1).clamp(16.0, 28.0),
              fontWeight: FontWeight.bold,
              fontFamily: pali.fontFamily.fontFamily,
            ),
          ),
          const SizedBox(height: 10),

          // Deconstructor cards (if available)
          if (lookup.hasDeconstructor) ...[
            _buildDeconstructorSection(colors, lookup),
            const SizedBox(height: 12),
          ],

          // Headwords HTML — DpdHeadwordCard's DpdHtmlRichText wraps itself
          // in ExcludeSemantics at the source (see dictionary_search_shared.dart)
          // to avoid the flutter_html WidgetSpan merge-up '!conflict' assertion,
          // so no extra wrapping is needed here.
          if (lookup.hasHeadwords)
            ...lookup.headwords.map((hw) {
              return DpdHeadwordCard(
                lemma: hw.lemma1,
                meaningHtml: hw.meaningHtml,
                colors: colors,
                onWordTap: _selectWord,
              );
            }),
          const SizedBox(height: 8),

          const Divider(height: 1),
          const SizedBox(height: AppDimensions.sm),
        ],
      ),
    );
  }

  Widget _buildDeconstructorSection(ColorScheme colors, DpdFullLookup lookup) {
    final settings = ref.watch(settingsProvider);
    final pali = settings.typography.pali;
    final paliFontFamily = pali.fontFamily.fontFamily;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.call_split, size: 14, color: colors.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              'Compound breakdown',
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: (pali.fontSize * 0.6).clamp(10.0, 14.0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Deconstructor candidate cards
        ...lookup.deconstructionCandidates.asMap().entries.map((entry) {
          final idx = entry.key;
          final candidate = entry.value;
          final isActive = idx == _activeDeconCardIndex;

          return GestureDetector(
            onTap: () {
              setState(() {
                // Toggle: tapping the active card collapses it.
                _activeDeconCardIndex = _activeDeconCardIndex == idx ? -1 : idx;
                _activeDeconTokenIndex = 0;
              });
              _lookupDeconTokens(candidate);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? colors.primaryContainer.withValues(alpha: 0.3)
                    : colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive
                      ? colors.primary
                      : colors.outlineVariant.withValues(alpha: 0.3),
                  width: isActive ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Candidate header: tokens joined with " + " as a single label
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        candidate.tokens.join(' + '),
                        style: AppTypography.bodyTranslation.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w500,
                          fontSize: (pali.fontSize * 0.7).clamp(11.0, 18.0),
                          fontFamily: paliFontFamily,
                        ),
                      ),
                    ),
                  ),

                  // Expanded detail for active card — simple chip row
                  // instead of TabBar to avoid !semantics.parentDataDirty
                  // assertion errors inside CustomScrollView.
                  if (isActive && candidate.tokens.length > 1) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 8,
                        top: 4,
                        bottom: 4,
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(candidate.tokens.length, (i) {
                            final isTokenActive = i == _activeDeconTokenIndex;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() => _activeDeconTokenIndex = i);
                                  _lookupDeconToken(candidate.tokens[i]);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isTokenActive
                                        ? colors.primary
                                        : colors.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    candidate.tokens[i],
                                    style: AppTypography.labelSmall.copyWith(
                                      color: isTokenActive
                                          ? colors.onPrimary
                                          : colors.onSurfaceVariant,
                                      fontWeight: isTokenActive
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      fontSize: (pali.fontSize * 0.75).clamp(
                                        11.0,
                                        18.0,
                                      ),
                                      fontFamily: paliFontFamily,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                    // Token content — constrained height so the sheet does
                    // not grow unbounded; content scrolls within the box.
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(10),
                        child: _buildTokenContent(
                          colors,
                          candidate.tokens[_activeDeconTokenIndex],
                        ),
                      ),
                    ),
                  ] else if (isActive) ...[
                    const Divider(height: 1),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(10),
                        child: _buildTokenContent(colors, candidate.tokens[0]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTokenContent(ColorScheme colors, String token) {
    final cached = _subLookupCache[token];
    if (cached != null) {
      if (cached.isEmpty) {
        return const SizedBox.shrink();
      }
      // DpdHeadwordCard/DpdHtmlRichText self-excludes from semantics at
      // the source, so no extra wrapping needed here either.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: cached.map((hw) {
          return DpdHeadwordCard(
            lemma: hw.lemma1,
            meaningHtml: hw.meaningHtml,
            colors: colors,
            onWordTap: _selectWord,
            compact: true,
          );
        }).toList(),
      );
    }

    // Trigger async lookup
    _lookupDeconToken(token);
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

  Future<void> _lookupDeconToken(String token) async {
    if (_subLookupCache.containsKey(token)) return;
    try {
      final headwords = await ref.read(dpdSubLookupProvider(token).future);
      if (mounted) {
        setState(() {
          _subLookupCache[token] = headwords;
          _subLookupVersion++;
        });
      }
    } catch (_) {}
  }

  Future<void> _lookupDeconTokens(DeconstructionCandidate candidate) async {
    for (final token in candidate.tokens) {
      await _lookupDeconToken(token);
    }
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
    final right = ref.watch(sidePanelProvider).right;
    final isPinned =
        right.openPanel == SidePanelType.dictionary && right.isPinned;

    return Tooltip(
      message: isPinned ? 'Unpin from side panel' : 'Pin to side panel',
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
