import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
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
    // Clear previous search results when sheet opens
    ref.read(searchProvider.notifier).clear();
    // Auto-focus the search field when the sheet opens
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
      ref.read(searchProvider.notifier).search(query);
    });
  }

  void _onResultTap(SearchResult result) {
    // Get the current search query from the state for highlighting
    final query = switch (ref.read(searchProvider)) {
      SearchResults(:final query) => query,
      _ => null,
    };

    // Open a new tab (or switch to existing) for the book/para
    ref.read(readerTabsProvider.notifier).openTab(
          ReaderTabInfo(
            bookId: result.bookId,
            bookName: result.bookName ?? result.bookId,
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
                if (searchState is SearchResults && searchState.results.isNotEmpty)
                  Text(
                    '${searchState.results.length} results',
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
                ref.read(searchProvider.notifier).search(query);
              },
            ),
          ),
          const SizedBox(height: AppDimensions.sm),

          // Results area
          Expanded(
            child: _buildResults(searchState, colors),
          ),
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
                'Type a word or phrase to search\nacross all Pāli texts',
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
      case SearchResults(:final results, :final query):
        if (results.isEmpty) {
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
        return ListView.separated(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.marginMobile,
          ),
          itemCount: results.length,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            color: colors.outlineVariant.withValues(alpha: 0.5),
          ),
          itemBuilder: (context, index) {
            final result = results[index];
            return _SearchResultTile(
              result: result,
              onTap: () => _onResultTap(result),
              colors: colors,
            );
          },
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
}

class _SearchResultTile extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;
  final ColorScheme colors;

  const _SearchResultTile({
    required this.result,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
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
                Icon(
                  Icons.import_contacts,
                  size: 14,
                  color: colors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  result.bookName ?? result.bookId,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '§${result.paraId}',
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Snippet
            if (result.snippet != null)
              Text(
                result.snippet!,
                style: AppTypography.bodyPali.copyWith(
                  fontSize: 15,
                  color: colors.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
