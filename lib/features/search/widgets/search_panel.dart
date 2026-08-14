import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart' hide SearchResultRow;
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_breakpoint.dart';
import '../../../core/utils/pali_search_utils.dart';
import '../../../core/utils/pali_script_converter.dart';
import '../../../core/utils/pali_text_utils.dart';
import '../../../shared/utils/html_text_parser.dart';
import '../../../shared/widgets/pali_text.dart';
import '../../../core/utils/velthuis.dart';
import '../../reader/providers/reader_tabs_provider.dart';
import '../providers/search_provider.dart';
import 'search_result_highlight.dart';
import 'search_results_navigator.dart';

/// A search panel that can be shown in a sidebar.
///
/// On desktop, this appears in the left sidebar. Results open in the
/// reader area (not a separate page).
class SearchPanel extends ConsumerStatefulWidget {
  /// When true, the search text field is focused once the panel is built
  /// (used by the Cmd+Shift+F shortcut so the user can type immediately).
  final bool autoFocus;

  const SearchPanel({super.key, this.autoFocus = false});

  @override
  ConsumerState<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends ConsumerState<SearchPanel> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  bool _isConverting = false;
  int _wordDistance = 0;
  bool _showSuggestions = false;
  List<SearchSuggestion> _suggestions = [];
  bool _isMultiWord = false;
  bool _showFilters = false;

  /// Keyboard navigation over the results list (j/k + Enter).
  final SearchResultsNavigator _searchNav = SearchResultsNavigator();
  final FocusNode _resultsFocusNode = FocusNode();
  final ScrollController _resultsScrollController = ScrollController();
  final GlobalKey _selectedRowKey = GlobalKey();
  SearchResults? _lastNavState;
  SearchResultRow? _lastSelectedRow;

  @override
  void initState() {
    super.initState();
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(searchProvider.notifier).ensureIndexBuilt();
    });
    _searchNav.addListener(_onNavChanged);
  }

  @override
  void dispose() {
    _searchNav.removeListener(_onNavChanged);
    _resultsFocusNode.dispose();
    _resultsScrollController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Rebuild + scroll to the newly selected row.
  void _onNavChanged() {
    if (!mounted) return;
    setState(() {});
    final row = _searchNav.selectedRow;
    if (row == null || identical(row, _lastSelectedRow)) return;
    _lastSelectedRow = row;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _selectedRowKey.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.25,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Keep the navigator in sync with the provider state.
  void _syncNavigator(SearchState searchState) {
    if (searchState is SearchResults) {
      if (!identical(searchState, _lastNavState)) {
        _lastNavState = searchState;
        _searchNav.rebuild(searchState, includeHeadings: false);
      }
    } else {
      if (_lastNavState != null) {
        _lastNavState = null;
        _searchNav.rows = const [];
        _searchNav.selected = 0;
        _lastSelectedRow = null;
      }
    }
  }

  /// Activate the currently selected result row.
  void _activateSelectedRow() {
    final row = _searchNav.selectedRow;
    if (row == null) return;
    switch (row.kind) {
      case SearchRowKind.headingCard:
        break; // the panel never renders heading rows
      case SearchRowKind.bookHeader:
        final notifier = ref.read(searchProvider.notifier);
        if (row.summary!.isExpanded) {
          notifier.collapseBook(row.summaryIndex);
        } else {
          notifier.expandBook(row.summaryIndex);
        }
      case SearchRowKind.resultItem:
        final summaries = ref.read(searchProvider);
        if (summaries is SearchResults && row.summary != null) {
          _onResultTap(row.summary!, row.item!);
        }
      case SearchRowKind.loadMore:
        ref
            .read(searchProvider.notifier)
            .loadMoreForBook(row.summaryIndex);
    }
  }

  void _onSearchChanged(String value) {
    if (_isConverting) return;
    final converted = velthuis(value);
    if (converted != value && converted.trim().isNotEmpty) {
      _isConverting = true;
      _searchController.value = convertedTextEditingValue(
        _searchController.value,
      );
      _isConverting = false;
    }

    final effectiveValue = converted;
    final wordCount = effectiveValue.trim().isEmpty
        ? 0
        : effectiveValue.trim().split(RegExp(r'\\s+')).length;
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
    _debounce = Timer(const Duration(milliseconds: 200), () async {
      if (effectiveValue.trim().isNotEmpty) {
        final words = effectiveValue.trim().split(RegExp(r'\\s+'));
        final lastWord = words.isNotEmpty ? words.last : '';
        if (lastWord.isNotEmpty) {
          final suggestions = await ref
              .read(searchProvider.notifier)
              .getSuggestions(lastWord);
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
      } else {
        setState(() {
          _suggestions = [];
          _showSuggestions = false;
        });
      }
    });
  }

  void _executeSearch() {
    final rawQuery = _searchController.text;
    final query = velthuis(rawQuery);
    setState(() => _showSuggestions = false);
    _focusNode.unfocus();
    ref
        .read(searchProvider.notifier)
        .search(query: query, distance: _wordDistance);
    // On desktop, move keyboard focus to the results so j/k navigation
    // works right after searching.
    if (ResponsiveBreakpoint.isDesktop(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resultsFocusNode.requestFocus();
      });
    }
  }

  void _onSuggestionSelected(SearchSuggestion suggestion) {
    final currentText = _searchController.text;
    final lastSpace = currentText.lastIndexOf(' ');
    if (lastSpace >= 0) {
      _searchController.text =
          '${currentText.substring(0, lastSpace + 1)}${suggestion.pali}';
    } else {
      _searchController.text = suggestion.pali;
    }
    setState(() => _showSuggestions = false);
    _executeSearch();
  }

  void _onResultTap(BookResultSummary summary, SearchResultItem item) {
    final currentState = ref.read(searchProvider);
    final query = currentState is SearchResults ? currentState.query : null;

    // Find the first matching line's lineId for precise line-level jumping
    final int? initialLineId;
    if (item.lines.isNotEmpty) {
      final firstMatchLine = item.lines.firstWhere(
        (l) => l.isMatch,
        orElse: () => item.lines.first,
      );
      initialLineId = firstMatchLine.lineId;
    } else {
      initialLineId = null;
    }

    ref
        .read(readerTabsProvider.notifier)
        .openTab(
          ReaderTabInfo(
            bookId: item.bookId,
            bookName: summary.book.bookName ?? item.bookId,
            initialParaId: item.paraId,
            initialLineId: initialLineId,
            searchQuery: query,
          ),
        );
    // On desktop, the reader is already visible side-by-side — just switch tabs.
    // On mobile, navigate to reader screen.
    if (context.mounted && !ResponsiveBreakpoint.isDesktop(context)) {
      context.push('/reader');
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    _syncNavigator(searchState);

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
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: loc.searchPaliShort,
              isDense: true,
              prefixIcon: Icon(
                Icons.search,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.search, size: 18),
                          color: colors.primary,
                          onPressed: _executeSearch,
                        ),
                        IconButton(
                          icon: Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                            ref.read(searchProvider.notifier).clear();
                          },
                        ),
                      ],
                    )
                  : null,
              filled: true,
              fillColor: colors.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.sm,
                vertical: 8,
              ),
            ),
            style: AppTypography.labelMedium.copyWith(
              fontSize: 14,
              color: colors.onSurface,
            ),
            onChanged: _onSearchChanged,
            onSubmitted: (_) => _executeSearch(),
          ),
        ),

        // Options bar
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.sm,
            4,
            AppDimensions.sm,
            0,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  PopupMenuButton<int>(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    initialValue: _wordDistance,
                    onSelected: (val) {
                      setState(() => _wordDistance = val);
                      if (_searchController.text.isNotEmpty) _executeSearch();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 0,
                        child: Text(loc.anyShort, style: const TextStyle(fontSize: 13)),
                      ),
                      PopupMenuItem(
                        value: 3,
                        child: Text(loc.withinNShort(3), style: const TextStyle(fontSize: 13)),
                      ),
                      PopupMenuItem(
                        value: 1,
                        child: Text(loc.withinNShort(1), style: const TextStyle(fontSize: 13)),
                      ),
                      PopupMenuItem(
                        value: 2,
                        child: Text(loc.withinNShort(2), style: const TextStyle(fontSize: 13)),
                      ),
                      PopupMenuItem(
                        value: 5,
                        child: Text(loc.withinNShort(5), style: const TextStyle(fontSize: 13)),
                      ),
                      PopupMenuItem(
                        value: 10,
                        child: Text(loc.withinNShort(10), style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _wordDistance > 0
                            ? colors.secondaryContainer
                            : colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.swap_horiz,
                            size: 12,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            loc.dist,
                            style: AppTypography.labelSmall.copyWith(
                              fontSize: 10,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            size: 14,
                            color: colors.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Filter toggle
                  IconButton(
                    icon: Icon(
                      _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
                      size: 16,
                    ),
                    color: _showFilters ? colors.primary : colors.onSurfaceVariant,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    padding: EdgeInsets.zero,
                    tooltip: loc.toggleFilters,
                    onPressed: () => setState(() => _showFilters = !_showFilters),
                  ),
                  if (searchState is SearchResults)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${searchState.totalResults}',
                        style: AppTypography.labelSmall.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),

              // ── Filter panel ──────────────────────────────────────────
              if (_showFilters) _buildFilterPanel(colors),
            ],
          ),
        ),

        // Suggestions
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 150),
            margin: const EdgeInsets.symmetric(horizontal: AppDimensions.sm),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
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
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: colors.outlineVariant.withValues(alpha: 0.3),
              ),
              itemBuilder: (context, index) {
                final sug = _suggestions[index];
                return InkWell(
                  onTap: () => _onSuggestionSelected(sug),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.sm,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.text_fields,
                          size: 14,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            sug.pali,
                            style: AppTypography.bodyPali.copyWith(
                              fontSize: 13,
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            formatCount(sug.count),
                            style: AppTypography.labelSmall.copyWith(
                              fontSize: 9,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

        const Divider(height: 1),
        // Results — wrapped in a Focus so j/k navigate the list (desktop).
        Expanded(
          child: Focus(
            focusNode: _resultsFocusNode,
            onKeyEvent: (node, event) => handleSearchNavKey(
              event,
              _searchNav,
              onActivate: _activateSelectedRow,
              onEscape: () => _focusNode.requestFocus(),
            ),
            child: _buildResults(searchState, colors),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPanel(ColorScheme colors) {
    final notifier = ref.read(searchProvider.notifier);
    final enabledCats = notifier.enabledCategories;
    final enabledNik = notifier.enabledNikayas;
    final loc = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category (layer) row
            Row(
              children: [
                Text(
                  loc.layer,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 9,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Wrap(
                    spacing: 3,
                    runSpacing: 3,
                    children: kAllCategories.map((key) => _PanelFilterChip(
                      label: key,
                      selected: enabledCats.contains(key),
                      colors: colors,
                      onTap: () => notifier.toggleCategory(key),
                    )).toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Nikaya (pitaka) row
            Row(
              children: [
                Text(
                  loc.nikaya,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 9,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Wrap(
                    spacing: 3,
                    runSpacing: 3,
                    children: kAllNikayas.map((key) => _PanelFilterChip(
                      label: key,
                      selected: enabledNik.contains(key),
                      colors: colors,
                      onTap: () => notifier.toggleNikaya(key),
                    )).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(SearchState state, ColorScheme colors) {
    final loc = AppLocalizations.of(context);
    switch (state) {
      case SearchIdle():
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search,
                size: 36,
                color: colors.onSurfaceVariant.withValues(alpha: 0.3),
              ),
              const SizedBox(height: AppDimensions.sm),
              Text(
                loc.searchTipitaka,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      case SearchIndexing(:final status, :final progress):
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    value: progress > 0 ? progress : null,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  status,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      case SearchLoading():
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      case SearchResults(
        :final bookSummaries,
        :final query,
        :final totalResults,
      ):
        return _buildResultList(colors, bookSummaries, query, totalResults);
      case SearchError(:final message):
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              loc.errorMessage(message),
              style: AppTypography.labelSmall.copyWith(color: colors.error),
              textAlign: TextAlign.center,
            ),
          ),
        );
    }
  }

  Widget _buildResultList(
    ColorScheme colors,
    List<BookResultSummary> summaries,
    String query,
    int totalResults,
  ) {
    final loc = AppLocalizations.of(context);
    if (summaries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 36,
              color: colors.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 4),
            Text(
              loc.noResultsForQuery(query),
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Flattened rows (book headers + expanded items + load-more), driven by
    // the keyboard navigator; j/k move the selection, Enter activates.
    final rows = _searchNav.rows;
    return ListView.builder(
      controller: _resultsScrollController,
      padding: const EdgeInsets.all(AppDimensions.sm),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final isSelected = index == _searchNav.selected;
        final Widget child = switch (row.kind) {
          SearchRowKind.headingCard => const SizedBox.shrink(),
          SearchRowKind.bookHeader => _BookResultHeader(
            summary: row.summary!,
            colors: colors,
            query: query,
            onToggleExpanded: () {
              final notifier = ref.read(searchProvider.notifier);
              if (row.summary!.isExpanded) {
                notifier.collapseBook(row.summaryIndex);
              } else {
                notifier.expandBook(row.summaryIndex);
              }
            },
          ),
          SearchRowKind.resultItem => _ResultItemTile(
            item: row.item!,
            colors: colors,
            query: query,
            onTap: () => _onResultTap(row.summary!, row.item!),
          ),
          SearchRowKind.loadMore => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => ref
                    .read(searchProvider.notifier)
                    .loadMoreForBook(row.summaryIndex),
                icon: Icon(Icons.expand_more, size: 14),
                label: Text(
                  loc.showNMore(
                    row.summary!.totalCount - row.summary!.loadedCount,
                  ),
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.primary,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ),
        };
        return _SearchRowHighlight(
          key: isSelected ? _selectedRowKey : null,
          selected: isSelected,
          colors: colors,
          child: child,
        );
      },
    );
  }
}

// ── Small panel filter chip ──────────────────────────────────────────────

class _PanelFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ColorScheme colors;
  final VoidCallback onTap;

  const _PanelFilterChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: selected
              ? colors.primaryContainer
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
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
            fontSize: 9,
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

// ── Book Result Header (collapsible row) ──────────────────────────────

class _BookResultHeader extends ConsumerWidget {
  final BookResultSummary summary;
  final ColorScheme colors;
  final String query;
  final VoidCallback onToggleExpanded;

  const _BookResultHeader({
    required this.summary,
    required this.colors,
    required this.query,
    required this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final script = ref.watch(settingsProvider).paliScript;
    final displayName = summary.book.displayName;
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onToggleExpanded,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.sm,
            vertical: 8,
          ),
          child: Row(
            children: [
              Icon(Icons.import_contacts, size: 14, color: colors.primary),
              const SizedBox(width: 6),
              Expanded(
                // Book names are Pāli — render in the user's script
                // with the script font, like the library.
                child: PaliTextStatic(
                  displayName,
                  script,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: summary.isExpanded
                      ? colors.primaryContainer
                      : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${summary.totalCount}',
                  style: AppTypography.labelSmall.copyWith(
                    color: summary.isExpanded
                        ? colors.primary
                        : colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: summary.isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.expand_more,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps a keyboard-navigable result row with the selection highlight.
class _SearchRowHighlight extends StatelessWidget {
  final bool selected;
  final ColorScheme colors;
  final Widget child;

  const _SearchRowHighlight({
    super.key,
    required this.selected,
    required this.colors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      decoration: BoxDecoration(
        color: selected
            ? colors.primary.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selected
              ? colors.primary.withValues(alpha: 0.6)
              : Colors.transparent,
          width: 1.2,
        ),
      ),
      child: child,
    );
  }
}

/// Format a count number for display.
String formatCount(int count) {
  if (count < 1000) return count.toString();
  if (count < 10000) return '${(count / 1000).toStringAsFixed(1)}k';
  return '${(count / 1000).toStringAsFixed(0)}k';
}

// ── Result Item Tile (line-by-line, compact) ───────────────────────────

class _ResultItemTile extends ConsumerWidget {
  final SearchResultItem item;
  final ColorScheme colors;
  final String query;
  final VoidCallback onTap;

  const _ResultItemTile({
    required this.item,
    required this.colors,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final searchState = ref.watch(searchProvider);
    final activeLang = settings.enabledTranslations.isNotEmpty
        ? settings.enabledTranslations.first
        : (settings.showTranslation ? settings.primaryTranslationLang : null);
    final script = settings.paliScript;

    // Extract search terms from the current query
    final List<String> searchTerms;
    if (searchState is SearchResults) {
      final q = searchState.query;
      searchTerms = normalizePaliFuzzy(q)
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
    } else {
      searchTerms = const [];
    }

    final paliTypo = settings.typography.pali;
    final paliTextStyle = paliTypo.toTextStyle(
      fallbackColor: colors.onSurface,
    );

    final transTypo = activeLang != null
        ? settings.typography.typographyFor(activeLang)
        : null;
    final transTextStyle = transTypo?.toTextStyle(
      fallbackColor: colors.onSurfaceVariant.withValues(alpha: 0.8),
    ) ?? TextStyle(
      fontSize: 11,
      color: colors.onSurfaceVariant.withValues(alpha: 0.8),
      fontStyle: FontStyle.italic,
      height: 1.3,
    );

    // Only show matching lines
    final matchingLines = item.lines.where((l) => l.isMatch).toList();
    if (matchingLines.isEmpty) return const SizedBox.shrink();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.sm + 10,
          vertical: 4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Para heading
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: colors.tertiaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '§${item.paraId}',
                    style: AppTypography.labelSmall.copyWith(
                      fontSize: 8,
                      color: colors.onTertiaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (matchingLines.length < item.lines.length) ...[
                  const SizedBox(width: 4),
                  Text(
                    '${matchingLines.length}/${item.lines.length}',
                    style: AppTypography.labelSmall.copyWith(
                      fontSize: 8,
                      color: colors.primary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
            // Matching lines
            ...matchingLines.map((line) => Padding(
              padding: const EdgeInsets.only(top: 1),
              child: _PanelLineTile(
                line: line,
                searchTerms: searchTerms,
                paliTextStyle: paliTextStyle,
                transTextStyle: transTextStyle,
                colors: colors,
                script: script,
              ),
            )),
          ],
        ),
      ),
    );
  }
}

/// A single line tile used in the panel.
class _PanelLineTile extends StatelessWidget {
  final SearchResultLine line;
  final List<String> searchTerms;
  final TextStyle paliTextStyle;
  final TextStyle transTextStyle;
  final ColorScheme colors;
  final Script script;

  const _PanelLineTile({
    required this.line,
    required this.searchTerms,
    required this.paliTextStyle,
    required this.transTextStyle,
    required this.colors,
    required this.script,
  });

  @override
  Widget build(BuildContext context) {
    final highlightColor = colors.primary.withValues(alpha: 0.25);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (line.pali.isNotEmpty)
            _buildHighlightedPaliText(
              text: line.pali,
              searchTerms: searchTerms,
              script: script,
              style: paliTextStyle.copyWith(
                fontSize: (paliTextStyle.fontSize ?? 14) - 2,
                height: paliTextStyle.height ?? 1.3,
              ),
              highlightColor: highlightColor,
            ),
          if (line.translation != null && line.translation!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: _buildHighlightedTranslationText(
                text: line.translation!,
                searchTerms: searchTerms,
                style: transTextStyle.copyWith(
                  fontSize: (transTextStyle.fontSize ?? 12) - 1,
                  height: transTextStyle.height ?? 1.2,
                ),
                highlightColor: highlightColor,
              ),
            ),
        ],
      ),
    );
  }

  /// Build Pali text with search terms highlighted.
  /// Trims the snippet to a window around the first match so the found word
  /// is always visible even in very long lines.
  Widget _buildHighlightedPaliText({
    required String text,
    required List<String> searchTerms,
    required Script script,
    required TextStyle style,
    required Color highlightColor,
  }) {
    // Convert script first (preserving HTML tags like <b>, <i>)
    final converted = convertPaliToScriptPreservingHtml(text, script);
    final effStyle = style.copyWith(fontFamily: scriptFontFamily(script));

    if (searchTerms.isEmpty || text.isEmpty) {
      return HtmlTextParser.richText(
        converted,
        effStyle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    final spans = buildSearchSnippetSpans(
      html: converted,
      baseStyle: effStyle,
      terms: searchTerms,
      isPali: true,
      highlightColor: highlightColor,
      beforeChars: 30,
      afterChars: 45,
    );

    return Text.rich(
      TextSpan(style: effStyle, children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Build translation text with search terms highlighted.
  /// Trims the snippet to a window around the first match so the found word
  /// is always visible even in very long lines.
  Widget _buildHighlightedTranslationText({
    required String text,
    required List<String> searchTerms,
    required TextStyle style,
    required Color highlightColor,
  }) {
    if (searchTerms.isEmpty || text.isEmpty) {
      return HtmlTextParser.richText(
        text,
        style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final spans = buildSearchSnippetSpans(
      html: text,
      baseStyle: style,
      terms: searchTerms,
      isPali: false,
      highlightColor: highlightColor,
      beforeChars: 25,
      afterChars: 40,
    );

    return Text.rich(
      TextSpan(style: style, children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
