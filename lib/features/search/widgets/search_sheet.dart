import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/pali_text.dart';
import '../../reader/providers/reader_tabs_provider.dart';
import '../providers/search_provider.dart';

/// A modal bottom sheet for searching Pāli text across all books.
///
/// Shows a search field at the top and displays results below as the user
/// types. Tapping a result opens (or switches to) that paragraph in the
/// reader.
class SearchSheet extends ConsumerStatefulWidget {
  const SearchSheet({super.key});

  @override
  ConsumerState<SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends ConsumerState<SearchSheet> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    ref.read(searchProvider.notifier).clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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

  void _onSearch(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(searchProvider.notifier).search(query: query);
    });
  }

  void _onResultTap(SearchResultItem result) {
    final query = switch (ref.read(searchProvider)) {
      SearchResults(:final query) => query,
      _ => null,
    };

    ref.read(readerTabsProvider.notifier).openTab(
          ReaderTabInfo(
            bookId: result.bookId,
            bookName: result.bookId,
            initialParaId: result.paraId,
            searchQuery: query,
          ),
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final colors = Theme.of(context).colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusSheet),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: colors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.marginMobile,
              AppDimensions.md,
              AppDimensions.marginMobile,
              0,
            ),
            child: Row(
              children: [
                Text(
                  'Search',
                  style: AppTypography.headlineSmall.copyWith(
                    color: colors.onSurface,
                  ),
                ),
                const Spacer(),
                if (searchState is SearchResults && searchState.totalResults > 0)
                  Text(
                    '${searchState.totalResults} results',
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.sm),

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.marginMobile,
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              autofocus: false,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search Pāli texts…',
                prefixIcon: Icon(Icons.search, color: colors.onSurfaceVariant),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearch('');
                        },
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
              style: AppTypography.labelMedium.copyWith(
                color: colors.onSurface,
              ),
              onChanged: _onSearch,
              onSubmitted: (query) {
                _debounce?.cancel();
                ref.read(searchProvider.notifier).search(query: query);
              },
            ),
          ),
          const SizedBox(height: AppDimensions.sm),

          // Results area
          Expanded(child: _buildResults(searchState, colors)),
        ],
      ),
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
                size: 48,
                color: colors.onSurfaceVariant.withValues(alpha: 0.3),
              ),
              const SizedBox(height: AppDimensions.sm),
              Text(
                'Type a word or phrase to search\\nacross all Pāli texts',
                textAlign: TextAlign.center,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      case SearchLoading():
        return const Center(child: CircularProgressIndicator());
      case SearchResults(:final bookSummaries, :final query, :final totalResults):
        return _buildResultsList(
            colors, bookSummaries, query, totalResults);
      case SearchIndexing(:final progress, :final status):
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                  value: progress > 0 ? progress : null),
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
        );
      case SearchError(:final message):
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Text(
              'Search failed: $message',
              style: AppTypography.labelSmall.copyWith(
                color: colors.error,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
    }
  }

  Widget _buildResultsList(
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
              size: 48,
              color: colors.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppDimensions.sm),
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

    // Check if any books are expanded with loaded items
    final hasLoadedItems = summaries.any(
        (s) => s.isExpanded && s.loadedPages.isNotEmpty);

    if (!hasLoadedItems) {
      // Only show summary counts (collapsed)
      return ListView.separated(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.marginMobile,
        ),
        itemCount: summaries.length,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          color: colors.outlineVariant.withValues(alpha: 0.5),
        ),
        itemBuilder: (context, index) {
          final summary = summaries[index];
          return _BookSummaryTile(
            summary: summary,
            colors: colors,
            onTap: () {
              ref
                  .read(searchProvider.notifier)
                  .expandBook(index);
            },
          );
        },
      );
    }

    // Show expanded results
    final allItems = summaries
        .where((s) => s.isExpanded)
        .expand((s) => s.loadedPages.expand((p) => p))
        .toList();

    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.marginMobile,
      ),
      itemCount: allItems.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        color: colors.outlineVariant.withValues(alpha: 0.5),
      ),
      itemBuilder: (context, index) {
        final result = allItems[index];
        return _SearchResultTile(
          result: result,
          onTap: () => _onResultTap(result),
          colors: colors,
        );
      },
    );
  }
}

// ── Book Summary Tile (for collapsed state) ─────────────────────────────

class _BookSummaryTile extends StatelessWidget {
  final BookResultSummary summary;
  final ColorScheme colors;
  final VoidCallback onTap;

  const _BookSummaryTile({
    required this.summary,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = summary.book.bookName ?? summary.book.bookId;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: AppDimensions.sm),
        child: Row(
          children: [
            Icon(Icons.import_contacts, size: 14, color: colors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                name,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${summary.totalCount}',
                style: AppTypography.labelSmall.copyWith(
                  color: colors.primary,

                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 16, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ── Search Result Tile ──────────────────────────────────────────────────

class _SearchResultTile extends ConsumerWidget {
  final SearchResultItem result;
  final VoidCallback onTap;
  final ColorScheme colors;

  const _SearchResultTile({
    required this.result,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paliText = result.paliText;
    final translation = result.translation;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: AppDimensions.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book info line
            Row(
              children: [
                Icon(Icons.import_contacts, size: 14, color: colors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    result.bookId,
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 14, color: colors.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 4),              // Pāli snippet
            if (paliText.isNotEmpty)
              PaliText(
                paliText,
                style: AppTypography.bodyPali.copyWith(
                  color: colors.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            // Translation snippet
            if (translation != null && translation.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  translation,
                  style: AppTypography.bodyTranslation.copyWith(
                    color: colors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
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

/// Convenience function to show the search sheet as a modal bottom sheet.
void showSearchSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const SearchSheet(),
  );
}
