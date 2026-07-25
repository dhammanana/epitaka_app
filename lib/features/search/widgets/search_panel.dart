import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_breakpoint.dart';
import '../../../core/utils/velthuis.dart';
import '../../../shared/widgets/pali_text.dart';
import '../../reader/providers/reader_tabs_provider.dart';
import '../providers/search_provider.dart';

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
  bool _fuzzy = false;
  int _wordDistance = 0;
  bool _showSuggestions = false;
  List<SearchSuggestion> _suggestions = [];
  bool _isMultiWord = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoFocus) {
      // Focus the search field after the first frame so the keyboard shows.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(searchProvider.notifier).ensureIndexBuilt();
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
    _debounce = Timer(const Duration(milliseconds: 200), () async {
      if (effectiveValue.trim().isNotEmpty) {
        final words = effectiveValue.trim().split(RegExp(r'\s+'));
        final lastWord = words.isNotEmpty ? words.last : '';
        if (lastWord.isNotEmpty) {
          final suggestions = await ref
              .read(searchProvider.notifier)
              .getSuggestions(lastWord);
          if (mounted)
            setState(() {
              _suggestions = suggestions;
              _showSuggestions = suggestions.isNotEmpty;
            });
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
        .search(query: query, fuzzy: _fuzzy, distance: _wordDistance);
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

    ref
        .read(readerTabsProvider.notifier)
        .openTab(
          ReaderTabInfo(
            bookId: item.bookId,
            bookName: summary.book.bookName ?? item.bookId,
            initialParaId: item.paraId,
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
              hintText: 'Search Pāli…',
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
          child: Row(
            children: [
              FilterChip(
                label: Text(
                  'Fuzzy',
                  style: AppTypography.labelSmall.copyWith(
                    fontSize: 10,
                    color: _fuzzy
                        ? colors.onPrimaryContainer
                        : colors.onSurfaceVariant,
                  ),
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
              const SizedBox(width: 4),
              PopupMenuButton<int>(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                initialValue: _wordDistance,
                onSelected: (val) {
                  setState(() => _wordDistance = val);
                  if (_searchController.text.isNotEmpty) _executeSearch();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 0,
                    child: Text('Any', style: TextStyle(fontSize: 13)),
                  ),
                  const PopupMenuItem(
                    value: 3,
                    child: Text('Within 3', style: TextStyle(fontSize: 13)),
                  ),
                  const PopupMenuItem(
                    value: 1,
                    child: Text('Within 1', style: TextStyle(fontSize: 13)),
                  ),
                  const PopupMenuItem(
                    value: 2,
                    child: Text('Within 2', style: TextStyle(fontSize: 13)),
                  ),
                  const PopupMenuItem(
                    value: 5,
                    child: Text('Within 5', style: TextStyle(fontSize: 13)),
                  ),
                  const PopupMenuItem(
                    value: 10,
                    child: Text('Within 10', style: TextStyle(fontSize: 13)),
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
                        'Dist',
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
        // Results
        Expanded(child: _buildResults(searchState, colors)),
      ],
    );
  }

  Widget _buildResults(SearchState state, ColorScheme colors) {
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
                'Search the Pāli Tipiṭaka',
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
              'Error: $message',
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
              'No results for "$query"',
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.sm),
      itemCount: summaries.length,
      itemBuilder: (context, index) {
        final summary = summaries[index];
        return _BookResultCard(
          summary: summary,
          colors: colors,
          query: query,
          onTapResult: (item) => _onResultTap(summary, item),
          onToggleExpanded: () {
            if (summary.isExpanded) {
              ref.read(searchProvider.notifier).collapseBook(index);
            } else {
              ref.read(searchProvider.notifier).expandBook(index);
            }
          },
          onLoadMore: () =>
              ref.read(searchProvider.notifier).loadMoreForBook(index),
        );
      },
    );
  }
}

// ── Book Result Card ───────────────────────────────────────────────────

class _BookResultCard extends StatelessWidget {
  final BookResultSummary summary;
  final ColorScheme colors;
  final String query;
  final void Function(SearchResultItem item) onTapResult;
  final VoidCallback onToggleExpanded;
  final VoidCallback onLoadMore;

  const _BookResultCard({
    required this.summary,
    required this.colors,
    required this.query,
    required this.onTapResult,
    required this.onToggleExpanded,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
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
                    child: Text(
                      displayName,
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${summary.totalCount}',
                          style: AppTypography.labelSmall.copyWith(
                            color: summary.isExpanded
                                ? colors.primary
                                : colors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ],
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
          if (summary.isExpanded) ...[
            ...summary.loadedPages.expand(
              (page) => page.map(
                (item) => _ResultItemTile(
                  item: item,
                  colors: colors,
                  query: query,
                  onTap: () => onTapResult(item),
                ),
              ),
            ),
            if (!summary.fullyLoaded)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.sm,
                  vertical: 2,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: onLoadMore,
                    icon: Icon(Icons.expand_more, size: 14),
                    label: Text(
                      'Show ${summary.totalCount - summary.loadedCount} more',
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.primary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Format a count number for display.
String formatCount(int count) {
  if (count < 1000) return count.toString();
  if (count < 10000) return '${(count / 1000).toStringAsFixed(1)}k';
  return '${(count / 1000).toStringAsFixed(0)}k';
}

// ── Result Item Tile ───────────────────────────────────────────────────

class _ResultItemTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.sm + 14,
          vertical: 6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.paliText.isNotEmpty)
              PaliText(
                item.paliText,
                style: AppTypography.bodyPali.copyWith(
                  fontSize: 12,
                  color: colors.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (item.translation != null && item.translation!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  item.translation!,
                  style: AppTypography.bodyTranslation.copyWith(
                    color: colors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
