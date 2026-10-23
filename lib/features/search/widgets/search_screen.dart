import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/pali_script_converter.dart';
import '../../../core/utils/velthuis.dart';
import '../../../shared/widgets/font_size_adjuster.dart';
import '../../../shared/widgets/regex_toggle_button.dart';
import '../../../shared/widgets/velthuis_help_icon.dart';
import '../../../shared/widgets/search_box_decoration.dart';
import '../providers/search_provider.dart';
import 'search_history_chips.dart';
import '../../gavesana/screens/gavesana_drawer.dart';
import 'search_results_view.dart';

/// The full-page search screen.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery});

  /// Text to search for as soon as the screen opens, as if typed and
  /// submitted — set by incoming search links (share sheet, selection menu).
  final String? initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  late final _focusNode = FocusNode(onKeyEvent: _onFieldKey);

  /// Focus node for the results list (j/k navigation on desktop).
  final FocusNode _resultsFocusNode = FocusNode();
  Timer? _debounce;

  /// Bumped whenever a search is executed or the field changes; a
  /// suggestion fetch only applies its result if the sequence still
  /// matches, so a fetch that finishes after the user pressed Enter can
  /// never pop the suggestion panel over the results.
  int _suggestSeq = 0;
  int _wordDistance = 0;
  bool _showSuggestions = false;
  List<SearchSuggestion> _suggestions = [];

  /// The suggestion the arrow keys have reached; -1 means none.
  int _suggestionIndex = -1;
  final GlobalKey _suggestionKey = GlobalKey();
  bool _isMultiWord = false;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(searchProvider.notifier).ensureIndexBuilt();
      final initial = widget.initialQuery?.trim() ?? '';
      if (initial.isNotEmpty) {
        _onHistorySelected(initial);
      } else {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _resultsFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _suggestionIndex = -1;
    if (ref.read(searchRegexProvider)) {
      // A pattern has no suggestions and sets its own word distance.
      _debounce?.cancel();
      _suggestSeq++;
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    // Any script → Roman IAST. The box converts Velthuis as it is typed.
    final converted = convertToRomanPali(value);

    final effectiveValue = converted;

    // Detect multi-word and auto-set distance=3 when second word is typed
    final wordCount = effectiveValue.trim().isEmpty
        ? 0
        : effectiveValue.trim().split(RegExp(r'\s+')).length;
    if (wordCount >= 2 && !_isMultiWord) {
      setState(() {
        _isMultiWord = true;
        if (_wordDistance == 0) _wordDistance = 3;
      });
    } else if (wordCount < 2 && _isMultiWord) {
      setState(() {
        _isMultiWord = false;
      });
    }

    _debounce?.cancel();
    final seq = ++_suggestSeq;
    _debounce = Timer(const Duration(milliseconds: 120), () async {
      if (effectiveValue.trim().isNotEmpty) {
        // Use the LAST word as the suggestion prefix, so multi-word queries
        // continue to show suggestions for the word being typed right now.
        // NOT using trim() before split ensures that a trailing space makes
        // lastWord empty, clearing suggestions and starting fresh for the
        // next word the user types.
        final words = effectiveValue.split(RegExp(r'\s+'));
        final lastWord = words.isNotEmpty ? words.last : '';
        if (lastWord.isNotEmpty) {
          final suggestions = await ref
              .read(searchProvider.notifier)
              .getSuggestions(lastWord);
          // Drop stale results: the user may have typed more or pressed
          // Enter while the fetch was in flight.
          if (!mounted || seq != _suggestSeq) return;
          setState(() {
            _suggestions = suggestions;
            _suggestionIndex = -1;
            _showSuggestions = suggestions.isNotEmpty;
          });
        } else {
          if (!mounted || seq != _suggestSeq) return;
          setState(() {
            _suggestions = [];
            _showSuggestions = false;
          });
        }
      } else {
        if (!mounted || seq != _suggestSeq) return;
        setState(() {
          _suggestions = [];
          _showSuggestions = false;
        });
      }
    });
  }

  /// Down arrow in the box moves to the results, where j/k, Enter and Esc
  /// work; the box keeps the cursor after a search, so this is the way in.
  KeyEventResult _onFieldKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (_showSuggestions && _suggestions.isNotEmpty) {
      if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
        return KeyEventResult.ignored;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        _moveSuggestion(
          (_suggestionIndex + 1).clamp(0, _suggestions.length - 1),
        );
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp && _suggestionIndex >= 0) {
        _moveSuggestion(_suggestionIndex - 1);
        return KeyEventResult.handled;
      }
      if ((key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.numpadEnter) &&
          _suggestionIndex >= 0 &&
          _suggestionIndex < _suggestions.length) {
        _onSuggestionSelected(_suggestions[_suggestionIndex]);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    final state = ref.read(searchProvider);
    if (event is! KeyDownEvent ||
        key != LogicalKeyboardKey.arrowDown ||
        state is! SearchResults ||
        (state.bookSummaries.isEmpty && state.headings.isEmpty) ||
        _resultsFocusNode.context == null) {
      return KeyEventResult.ignored;
    }
    _resultsFocusNode.requestFocus();
    return KeyEventResult.handled;
  }

  void _moveSuggestion(int index) {
    setState(() => _suggestionIndex = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _suggestionKey.currentContext;
      if (mounted && ctx != null) Scrollable.ensureVisible(ctx);
    });
  }

  void _executeSearch() {
    // Cancel any pending suggestion fetch and invalidate in-flight ones,
    // so the panel can't pop up over the results after searching.
    _debounce?.cancel();
    _suggestSeq++;
    final rawQuery = _searchController.text;
    final regex = ref.read(searchRegexProvider);
    // A pattern runs exactly as typed: script conversion would rewrite it.
    final query = regex ? rawQuery : convertToRomanPali(rawQuery);
    setState(() => _showSuggestions = false);
    ref
        .read(searchProvider.notifier)
        .search(query: query, distance: _wordDistance, regex: regex);
  }

  void _onSuggestionSelected(SearchSuggestion suggestion) {
    final currentText = _searchController.text;
    final lastSpace = currentText.lastIndexOf(' ');
    if (lastSpace >= 0) {
      // Multi-word: replace only the last word with the selected suggestion
      _searchController.text =
          '${currentText.substring(0, lastSpace + 1)}${suggestion.pali}';
    } else {
      _searchController.text = suggestion.pali;
    }
    setState(() {
      _showSuggestions = false;
      _suggestionIndex = -1;
    });
    _executeSearch();
  }

  void _toggleRegex() {
    final on = !ref.read(searchRegexProvider);
    ref.read(searchRegexProvider.notifier).state = on;
    _onSearchChanged(_searchController.text);
    if (_searchController.text.isNotEmpty) _executeSearch();
  }

  /// Fill the search bar with a previous query from history and run it.
  /// History and searches from outside the app hold plain words, so they
  /// run with rx off.
  void _onHistorySelected(String query) {
    ref.read(searchRegexProvider.notifier).state = false;
    _searchController.text = query;
    final wordCount = query.trim().isEmpty
        ? 0
        : query.trim().split(RegExp(r'\s+')).length;
    setState(() {
      _isMultiWord = wordCount >= 2;
      if (_isMultiWord && _wordDistance == 0) _wordDistance = 3;
    });
    _executeSearch();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final searchState = ref.watch(searchProvider);
    ref.listen<IncomingSearch?>(incomingSearchProvider, (_, next) {
      if (next != null) _onHistorySelected(next.query);
    });

    final isFromDrawer =
        GoRouterState.of(context).uri.queryParameters['fromDrawer'] == 'true';

    return Scaffold(
      drawer: isFromDrawer ? const MainDrawer() : null,
      appBar: AppBar(
        toolbarHeight: AppDimensions.appBarHeight,
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: isFromDrawer
            ? Builder(
                builder: (drawerContext) => IconButton(
                  icon: const Icon(Icons.menu),
                  color: colors.onSurfaceVariant,
                  onPressed: () => Scaffold.of(drawerContext).openDrawer(),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                color: colors.onSurfaceVariant,
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
              ),
        title: Text(
          loc.search,
          style: AppTypography.headlineSmall.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          const _FontSizeButton(),
          const SizedBox(width: AppDimensions.xs),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(colors, searchState),
          if (searchState is SearchIdle && !_showSuggestions)
            SearchHistoryChips(onSelected: _onHistorySelected),
          _buildOptionsBar(colors, searchState),
          if (_showSuggestions && _suggestions.isNotEmpty)
            _buildSuggestions(colors),
          Expanded(child: _buildResults(searchState, colors)),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ColorScheme colors, SearchState searchState) {
    final loc = AppLocalizations.of(context);
    final regexOn = ref.watch(searchRegexProvider);
    // "Invalid pattern" or "Pattern too slow", while the box still holds
    // the pattern it belongs to.
    final patternMessage =
        searchState is SearchError &&
            searchState.query == _searchController.text
        ? searchState.patternMessage(loc)
        : null;
    return Padding(
      padding: searchBoxPadding(SearchBoxSize.screen),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        // `.m`, `.t`, `.n` are regex: rx keeps them as typed.
        inputFormatters: regexOn ? const [] : const [VelthuisInputFormatter()],
        textInputAction: TextInputAction.search,
        decoration: searchBoxDecoration(
          context,
          hintText: loc.searchPaliTexts,
          size: SearchBoxSize.screen,
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchController.text.isNotEmpty) ...[
                IconButton(
                  icon: const Icon(Icons.search),
                  color: colors.primary,
                  onPressed: _executeSearch,
                  tooltip: loc.search,
                ),
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                    ref.read(searchProvider.notifier).clear();
                  },
                  tooltip: loc.clear,
                ),
              ],
              if (!regexOn) const VelthuisHelpIcon(),
              if (!kIsWeb)
                RegexToggleButton(on: regexOn, onToggle: _toggleRegex),
            ],
          ),
          errorText: patternMessage,
          prefixIcon: IconButton(
            icon: Icon(Icons.search, color: colors.onSurfaceVariant),
            onPressed: _executeSearch,
            tooltip: loc.search,
          ),
        ),
        style: searchBoxTextStyle(context, size: SearchBoxSize.screen),
        onChanged: _onSearchChanged,
        onSubmitted: (_) => _executeSearch(),
        // An empty handler stops the field dropping the cursor on Enter.
        onEditingComplete: () {},
      ),
    );
  }

  Widget _buildOptionsBar(ColorScheme colors, SearchState searchState) {
    final loc = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.marginMobile,
        AppDimensions.sm,
        AppDimensions.marginMobile,
        0,
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Word distance selector. A pattern sets its own distance.
              if (!ref.watch(searchRegexProvider)) ...[
                PopupMenuButton<int>(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: loc.wordDistance,
                  initialValue: _wordDistance,
                  onSelected: (val) {
                    setState(() => _wordDistance = val);
                    if (_searchController.text.isNotEmpty) _executeSearch();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 0, child: Text(loc.anyDistance)),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 3,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.transparent,
                          ),
                          const SizedBox(width: 8),
                          Text(loc.withinNWords(3)),
                        ],
                      ),
                    ),
                    PopupMenuItem(value: 1, child: Text(loc.withinNWords(1))),
                    PopupMenuItem(value: 2, child: Text(loc.withinNWords(2))),
                    PopupMenuItem(value: 5, child: Text(loc.withinNWords(5))),
                    PopupMenuItem(value: 10, child: Text(loc.withinNWords(10))),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _wordDistance > 0
                          ? colors.secondaryContainer
                          : (_isMultiWord
                                ? colors.tertiaryContainer
                                : colors.surfaceContainerHighest),
                      borderRadius: BorderRadius.circular(16),
                      border: _isMultiWord && _wordDistance == 0
                          ? Border.all(
                              color: colors.tertiary.withValues(alpha: 0.5),
                            )
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.swap_horiz,
                          size: 14,
                          color: _wordDistance > 0
                              ? colors.onSecondaryContainer
                              : (_isMultiWord
                                    ? colors.onTertiaryContainer
                                    : colors.onSurfaceVariant),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _wordDistance > 0
                              ? '${loc.dist}: $_wordDistance'
                              : loc.dist,
                          style: AppTypography.labelSmall.copyWith(
                            color: _wordDistance > 0
                                ? colors.onSecondaryContainer
                                : (_isMultiWord
                                      ? colors.onTertiaryContainer
                                      : colors.onSurfaceVariant),
                            fontWeight: _wordDistance > 0 || _isMultiWord
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 16,
                          color: _wordDistance > 0
                              ? colors.onSecondaryContainer
                              : (_isMultiWord
                                    ? colors.onTertiaryContainer
                                    : colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              const Spacer(),

              // Filter toggle
              IconButton(
                icon: Icon(
                  _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
                  size: 20,
                ),
                color: _showFilters ? colors.primary : colors.onSurfaceVariant,
                tooltip: loc.toggleFilters,
                onPressed: () => setState(() => _showFilters = !_showFilters),
              ),

              // Result count
              if (searchState is SearchResults)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: Text(
                    loc.resultsCount(searchState.totalResults),
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),

          // ── Filter panel ───────────────────────────────────────────────
          if (_showFilters) _buildFilterPanel(colors),
        ],
      ),
    );
  }

  Widget _buildFilterPanel(ColorScheme colors) {
    final notifier = ref.read(searchProvider.notifier);
    final enabledCats = notifier.enabledCategories;
    final enabledNik = notifier.enabledNikayas;
    final loc = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category (layer) row
            Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    loc.layer,
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: kAllCategories
                        .map(
                          (key) => _FilterChip(
                            label: key,
                            selected: enabledCats.contains(key),
                            colors: colors,
                            onTap: () => notifier.toggleCategory(key),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Nikaya (pitaka) row
            Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    loc.nikaya,
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: kAllNikayas
                        .map(
                          (key) => _FilterChip(
                            label: key,
                            selected: enabledNik.contains(key),
                            colors: colors,
                            onTap: () => notifier.toggleNikaya(key),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions(ColorScheme colors) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      margin: const EdgeInsets.fromLTRB(
        AppDimensions.marginMobile,
        0,
        AppDimensions.marginMobile,
        0,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppDimensions.radiusMd),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        scrollCacheExtent: const ScrollCacheExtent.pixels(2000),
        itemCount: _suggestions.length,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          color: colors.outlineVariant.withValues(alpha: 0.3),
        ),
        itemBuilder: (context, index) {
          final sug = _suggestions[index];
          return Container(
            key: index == _suggestionIndex ? _suggestionKey : null,
            color: index == _suggestionIndex
                ? colors.primary.withValues(alpha: 0.12)
                : null,
            child: InkWell(
            onTap: () => _onSuggestionSelected(sug),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.md,
                vertical: 10,
              ),
              child: Row(
                children: [
                  Icon(Icons.text_fields, size: 16, color: colors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      sug.pali,
                      style: AppTypography.bodyPali.copyWith(
                      fontFamily: ref
                          .watch(
                            settingsProvider.select((s) => s.typography.pali.fontFamily),
                          )
                          .fontFamily,
                        fontSize: 15,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      formatCount(sug.count),
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ));
        },
      ),
    );
  }

  Widget _buildResults(SearchState state, ColorScheme colors) {
    switch (state) {
      case SearchIdle():
        return _buildIdleState(colors);
      case SearchIndexing(:final status, :final progress):
        return _buildIndexingState(colors, status, progress);
      case SearchLoading():
        return const Center(child: CircularProgressIndicator());
      case SearchResults():
        return SearchResultsView(
          state: state,
          resultsFocusNode: _resultsFocusNode,
          onEscape: () => _focusNode.requestFocus(),
        );
      case SearchError(:final message):
        return _buildErrorState(
          colors,
          state.patternMessage(AppLocalizations.of(context)) ?? message,
        );
    }
  }

  Widget _buildIdleState(ColorScheme colors) {
    final loc = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search,
            size: 56,
            color: colors.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppDimensions.md),
          Text(
            loc.searchTipitaka,
            style: AppTypography.headlineSmall.copyWith(
              color: colors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          SizedBox(
            width: 280,
            child: Text(
              loc.searchIdleHint,
              textAlign: TextAlign.center,
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndexingState(
    ColorScheme colors,
    String status,
    double progress,
  ) {
    final loc = AppLocalizations.of(context);
    final p = progress.clamp(0.0, 1.0);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: p > 0 ? p : null,
                      strokeWidth: 8,
                      backgroundColor: colors.surfaceContainerHighest,
                      color: colors.primary,
                    ),
                  ),
                  if (p > 0)
                    Text(
                      '${(p * 100).toStringAsFixed(0)}%',
                      style: AppTypography.headlineSmall.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            Text(
              loc.buildingSearchIndex,
              style: AppTypography.headlineSmall.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 300,
              child: Text(
                status,
                textAlign: TextAlign.center,
                style: AppTypography.bodyTranslation.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: p > 0 ? p : null,
                minHeight: 6,
                backgroundColor: colors.surfaceContainerHighest,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: AppDimensions.xs),
            Text(
              p > 0
                  ? '${(p * 100).toStringAsFixed(0)}% ${loc.percentComplete}'
                  : loc.starting,
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ColorScheme colors, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colors.error),
            const SizedBox(height: AppDimensions.sm),
            Text(
              message,
              style: AppTypography.labelSmall.copyWith(color: colors.error),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Font size button ────────────────────────────────────────────────────

/// Small font-size popup button in the search screen's app bar.
///
/// Adjusts the Pāli + translation font sizes through the settings notifier
/// (the same path used by the typography settings screen and the keyboard
/// shortcuts), so the change is reflected everywhere — including the search
/// results, which follow the app's typography settings.
class _FontSizeButton extends StatelessWidget {
  const _FontSizeButton();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: AppLocalizations.of(context).fontSizeLabel,
      icon: Text(
        'A',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: colors.onSurfaceVariant,
        ),
      ),
      onPressed: () {
        // A persistent popup (like the reader's display popup) so the sizes
        // stay visible while tapping +/− — a menu would dismiss each tap.
        showDialog<void>(
          context: context,
          barrierColor: Colors.transparent,
          barrierDismissible: true,
          builder: (dialogContext) => Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: EdgeInsets.only(
                // Dialogs overlay the full screen including the status-bar
                // area, so offset by it plus the toolbar height.
                top:
                    MediaQuery.paddingOf(dialogContext).top +
                    AppDimensions.appBarHeight +
                    8,
                right: 12,
              ),
              child: const _FontSizePopup(),
            ),
          ),
        );
      },
    );
  }
}

/// Compact popup card with the shared [FontSizeAdjuster] (Pāli + translation
/// sizes with +/− buttons), mirroring the reader's display popup.
class _FontSizePopup extends StatelessWidget {
  const _FontSizePopup();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 230,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.fontSize,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            const FontSizeAdjuster(),
          ],
        ),
      ),
    );
  }
}

// ── Small filter chip widget ─────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ColorScheme colors;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? colors.primaryContainer
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? colors.primary.withValues(alpha: 0.5)
                : colors.outlineVariant.withValues(alpha: 0.4),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? colors.onPrimaryContainer
                : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ── Utility ──────────────────────────────────────────────────────────────

/// Format a number (e.g. 1234 -> "1.2k").
String formatCount(int count) {
  if (count < 1000) return count.toString();
  if (count < 10000) return '${(count / 1000).toStringAsFixed(1)}k';
  return '${(count / 1000).toStringAsFixed(0)}k';
}
