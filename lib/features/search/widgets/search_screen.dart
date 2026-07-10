import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/pali_text_utils.dart';
import '../../reader/providers/reader_tabs_provider.dart';
import '../providers/search_provider.dart';

/// The full-page advanced search screen.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;

  bool _fuzzy = false;
  int _distance = 0;
  bool _showFilters = false;
  bool _showSuggestions = false;
  List<SearchSuggestion> _suggestions = [];

  @override
  void initState() {
    super.initState();
    // Build search index on first open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(searchProvider.notifier).ensureIndexBuilt();
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();

    // Fetch suggestions only (no auto-search)
    _debounce = Timer(const Duration(milliseconds: 200), () async {
      if (value.trim().isNotEmpty) {
        final suggestions =
            await ref.read(searchProvider.notifier).getSuggestions(value);
        if (mounted) {
          setState(() {
            _suggestions = suggestions;
            _showSuggestions = suggestions.isNotEmpty;
          });
        }
      } else {
        setState(() {
          _suggestions = [];
          _showSuggestions = false;
        });
      }
    });
  }

  void _executeSearch() {
    final query = _searchController.text;
    setState(() => _showSuggestions = false);
    ref.read(searchProvider.notifier).search(
          query: query,
          fuzzy: _fuzzy,
          distance: _distance,
        );
  }

  void _onSuggestionSelected(SearchSuggestion suggestion) {
    _searchController.text = suggestion.pali;
    setState(() => _showSuggestions = false);
    _executeSearch();
  }

  void _onResultTap(String bookId, String? bookName, int? paraId) {
    final currentState = ref.read(searchProvider);
    final query = currentState is SearchResults ? currentState.query : null;

    debugPrint('[SEARCH_TAP] bookId: $bookId, bookName: $bookName, paraId: $paraId, query: $query');

    ref.read(readerTabsProvider.notifier).openTab(
          ReaderTabInfo(
            bookId: bookId,
            bookName: bookName ?? bookId,
            initialParaId: paraId,
            searchQuery: query,
          ),
        );
    context.push('/reader');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final searchState = ref.watch(searchProvider);

    return Scaffold(
      appBar: _buildAppBar(colors),
      body: Column(
        children: [
          _buildSearchBar(colors),
          _buildOptionsBar(colors, searchState),
          if (_showSuggestions && _suggestions.isNotEmpty)
            _buildSuggestions(colors),
          if (_showFilters && searchState is SearchResults)
            _buildFilterBar(colors, searchState),
          Expanded(child: _buildResults(searchState, colors)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ColorScheme colors) {
    return AppBar(
      toolbarHeight: AppDimensions.appBarHeight,
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        color: colors.onSurfaceVariant,
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        'Search',
        style: AppTypography.headlineSmall.copyWith(
          color: colors.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.filter_list,
            color: _showFilters ? colors.primary : colors.onSurfaceVariant,
          ),
          onPressed: () => setState(() => _showFilters = !_showFilters),
          tooltip: 'Filter books',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildSearchBar(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.marginMobile,
        AppDimensions.sm,
        AppDimensions.marginMobile,
        0,
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search Pāli texts…',
          prefixIcon: IconButton(
            icon: Icon(Icons.search, color: colors.onSurfaceVariant),
            onPressed: _executeSearch,
            tooltip: 'Search',
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.search),
                      color: colors.primary,
                      onPressed: _executeSearch,
                      tooltip: 'Search',
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                        ref.read(searchProvider.notifier).clear();
                      },
                      tooltip: 'Clear',
                    ),
                  ],
                )
              : null,
          filled: true,
          fillColor: colors.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.md,
            vertical: 12,
          ),
        ),
        style: AppTypography.bodyPali.copyWith(fontSize: 16, color: colors.onSurface),
        onChanged: _onSearchChanged,
        onSubmitted: (_) => _executeSearch(),
      ),
    );
  }

  Widget _buildOptionsBar(ColorScheme colors, SearchState searchState) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.marginMobile,
        AppDimensions.sm,
        AppDimensions.marginMobile,
        0,
      ),
      child: Row(
        children: [
          // Fuzzy toggle
          FilterChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Fuzzy',
                  style: AppTypography.labelSmall.copyWith(
                    color: _fuzzy ? colors.onPrimaryContainer : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            selected: _fuzzy,
            onSelected: (val) {
              setState(() => _fuzzy = val);
              if (_searchController.text.isNotEmpty) _executeSearch();
            },
            selectedColor: colors.primaryContainer,
            checkmarkColor: colors.primary,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 8),

          // Distance selector
          if (_searchController.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length >= 2) ...[
            SizedBox(
              width: 100,
              child: DropdownButtonFormField<int>(
                initialValue: _distance,
                isDense: true,
                decoration: InputDecoration(
                  labelText: 'Distance',
                  labelStyle: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  filled: true,
                  fillColor: colors.surfaceContainerHighest,
                ),
                items: [0, 1, 2, 3, 5, 10, 20, 50]
                    .map((d) => DropdownMenuItem(
                          value: d,
                          child: Text(
                            d == 0 ? 'Off' : d.toString(),
                            style: AppTypography.labelSmall,
                          ),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _distance = val);
                    if (_searchController.text.isNotEmpty) _executeSearch();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
          ],

          const Spacer(),

          // Result count
          if (searchState is SearchResults)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Text(
                '${searchState.totalResults} results',
                style: AppTypography.labelSmall.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
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
        itemCount: _suggestions.length,
        separatorBuilder: (_, _) =>
            Divider(height: 1, color: colors.outlineVariant.withValues(alpha: 0.3)),
        itemBuilder: (context, index) {
          final sug = _suggestions[index];
          return InkWell(
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
                        fontSize: 15,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    '(${sug.fuzzy})',
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
          );
        },
      ),
    );
  }

  Widget _buildFilterBar(ColorScheme colors, SearchResults state) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDimensions.marginMobile,
        AppDimensions.sm,
        AppDimensions.marginMobile,
        0,
      ),
      padding: const EdgeInsets.all(AppDimensions.sm),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter by book category / nikaya',
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: state.filters.asMap().entries.map((entry) {
              final i = entry.key;
              final filter = entry.value;
              return FilterChip(
                label: Text(
                  filter.label,
                  style: AppTypography.labelSmall.copyWith(
                    fontSize: 11,
                    color: filter.selected
                        ? colors.onSecondaryContainer
                        : colors.onSurfaceVariant,
                  ),
                ),
                selected: filter.selected,
                onSelected: (_) =>
                    ref.read(searchProvider.notifier).toggleFilter(i),
                selectedColor: colors.secondaryContainer,
                checkmarkColor: colors.secondary,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
        ],
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
      case SearchResults(:final groups, :final query, :final totalResults):
        return _buildResultList(colors, groups, query, totalResults);
      case SearchError(:final message):
        return _buildErrorState(colors, message);
    }
  }

  Widget _buildIdleState(ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 56, color: colors.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: AppDimensions.md),
          Text(
            'Search the Pāli Tipiṭaka',
            style: AppTypography.headlineSmall.copyWith(
              color: colors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          SizedBox(
            width: 280,
            child: Text(
              'Use fuzzy search for diacritic-insensitive matching.\n'
              'Enable distance to find words near each other.\n'
              'Filter results by book category or nikaya.',
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

  Widget _buildIndexingState(ColorScheme colors, String status, double progress) {
    final p = progress.clamp(0.0, 1.0);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated progress indicator ring
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
                  // Percentage text in the center
                  Text(
                    p > 0 ? '${(p * 100).toStringAsFixed(0)}%' : '',
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

            // Status text
            Text(
              'Building Search Index',
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

            // Linear progress bar underneath
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
              p > 0 ? '${(p * 100).toStringAsFixed(0)}% complete' : 'Starting…',
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

  Widget _buildResultList(
    ColorScheme colors,
    List<SearchResultGroup> groups,
    String query,
    int totalResults,
  ) {
    if (groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: colors.onSurfaceVariant.withValues(alpha: 0.3)),
            const SizedBox(height: AppDimensions.sm),
            Text(
              'No results for "$query"',
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimensions.xs),
            Text(
              'Try enabling fuzzy search or adjusting distance.',
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.marginMobile,
        AppDimensions.sm,
        AppDimensions.marginMobile,
        AppDimensions.bottomToolbarHeight + AppDimensions.lg,
      ),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return _BookResultGroup(
          group: group,
          colors: colors,
          searchQuery: query,
          onTapResult: (item) => _onResultTap(
            item.bookId,
            group.book.bookName ?? group.book.bookId,
            item.firstParaId,
          ),
          onToggleExpanded: () =>
              ref.read(searchProvider.notifier).toggleGroupExpanded(index),
        );
      },
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

// ── Book Result Group ─────────────────────────────────────────────────────

class _BookResultGroup extends ConsumerWidget {
  final SearchResultGroup group;
  final ColorScheme colors;
  final String searchQuery;
  final void Function(SearchResultItem item) onTapResult;
  final VoidCallback onToggleExpanded;

  const _BookResultGroup({
    required this.group,
    required this.colors,
    required this.searchQuery,
    required this.onTapResult,
    required this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final script = ref.watch(settingsProvider).paliScript;
    final displayName = convertPaliToScript(group.book.displayName, script);
    final paliFont = scriptFontFamily(script);

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: onToggleExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.md,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.import_contacts,
                      size: 16,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: AppTypography.labelMedium.copyWith(
                            fontFamily: paliFont,
                            color: colors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (group.book.nikaya != null || group.book.category != null)
                          Text(
                            [
                              if (group.book.nikaya != null) group.book.nikaya,
                              if (group.book.category != null) group.book.category,
                            ].join(' · '),
                            style: AppTypography.labelSmall.copyWith(
                              color: colors.onSurfaceVariant,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${group.totalResults}',
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: group.isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      size: 20,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Items
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: group.items.map((item) {
                return _SearchResultItemTile(
                  item: item,
                  colors: colors,
                  searchQuery: searchQuery,
                  onTap: () => onTapResult(item),
                );
              }).toList(),
            ),
            crossFadeState: group.isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

// ── Search Result Item Tile ──────────────────────────────────────────────

class _SearchResultItemTile extends ConsumerWidget {
  final SearchResultItem item;
  final ColorScheme colors;
  final String searchQuery;
  final VoidCallback onTap;

  const _SearchResultItemTile({
    required this.item,
    required this.colors,
    required this.searchQuery,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final script = ref.watch(settingsProvider).paliScript;
    final convertedPaliText = convertPaliToScript(item.paliText, script);
    final paliFont = scriptFontFamily(script);
    final translationText = item.translation;
    final convertedQuery = convertSearchQueryForScript(searchQuery, script);

    // Build a version of paliText with search terms wrapped in <b> tags
    final highlightedFullText = _buildHighlightedPaliText(
      convertedPaliText,
      convertedQuery,
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppDimensions.md, 6, AppDimensions.md, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // VRI page indicator
            if (item.vripage.isNotEmpty) ...[
              Container(
                width: 40,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'p.${item.vripage}',
                  style: AppTypography.labelSmall.copyWith(
                    fontSize: 9,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Full page Pāli text with highlighted search terms
                  _HighlightedSnippet(
                    text: highlightedFullText,
                    style: AppTypography.bodyPali.copyWith(
                      fontFamily: paliFont,
                      fontSize: 14,
                      color: colors.onSurface,
                      height: 1.4,
                    ),
                    highlightStyle: AppTypography.bodyPali.copyWith(
                      fontFamily: paliFont,
                      fontSize: 14,
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  // Translation text (if available)
                  if (translationText != null && translationText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      translationText,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant.withValues(alpha: 0.8),
                        fontStyle: FontStyle.italic,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 16, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  /// Build a snippet from [paliText] with search-query words wrapped in
  /// `<b>…</b>` tags, truncated to ~80 words for a compact preview.
  String _buildHighlightedPaliText(String paliText, String query) {
    if (paliText.isEmpty) return item.snippet;

    // Truncate to first ~80 words for a compact preview
    final words = paliText.split(RegExp(r'\s+'));
    final truncated = words.take(80).join(' ');

    if (query.trim().isEmpty) return truncated;

    // Collect unique search terms (lowercased)
    final searchTerms = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toSet();

    if (searchTerms.isEmpty) return truncated;

    // Wrap each occurrence of any search term in <b>…</b> (case-insensitive)
    final buffer = StringBuffer();
    int i = 0;
    final lower = truncated.toLowerCase();

    while (i < truncated.length) {
      // Find the earliest match among all search terms at position i
      String? bestMatch;
      int bestLen = 0;
      for (final term in searchTerms) {
        if (i + term.length <= lower.length &&
            lower.substring(i, i + term.length) == term) {
          if (term.length > bestLen) {
            bestMatch = term;
            bestLen = term.length;
          }
        }
      }
      if (bestMatch != null) {
        buffer.write('<b>');
        buffer.write(truncated.substring(i, i + bestLen));
        buffer.write('</b>');
        i += bestLen;
      } else {
        buffer.write(truncated[i]);
        i++;
      }
    }

    return buffer.toString();
  }
}

// ── Highlighted Snippet ──────────────────────────────────────────────────

class _HighlightedSnippet extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextStyle highlightStyle;

  const _HighlightedSnippet({
    required this.text,
    required this.style,
    required this.highlightStyle,
  });

  @override
  Widget build(BuildContext context) {
    // Parse <b>...</b> tags from FTS snippet
    if (!text.contains('<b>')) {
      return Text(text, style: style, maxLines: 3, overflow: TextOverflow.ellipsis);
    }

    final spans = <TextSpan>[];
    final regex = RegExp(r'<b>(.*?)</b>');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: style,
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: highlightStyle,
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: style,
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ── Utility ──────────────────────────────────────────────────────────────

/// Format a number (e.g. 1234 -> "1.2k", 12345 -> "12k").
String formatCount(int count) {
  if (count < 1000) return count.toString();
  if (count < 10000) return '${(count / 1000).toStringAsFixed(1)}k';
  return '${(count / 1000).toStringAsFixed(0)}k';
}