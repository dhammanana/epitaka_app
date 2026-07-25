import 'dart:async';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/app_models.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/pali_search_utils.dart';
import '../../../core/utils/velthuis.dart';
import '../../../shared/widgets/paragraph_preview_sheet.dart';
import '../../../shared/widgets/preview_content.dart';
import '../../reader/providers/reader_tabs_provider.dart';
import '../providers/search_provider.dart';

/// The full-page search screen.
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
  int _wordDistance = 0;
  bool _showSuggestions = false;
  List<SearchSuggestion> _suggestions = [];
  bool _isMultiWord = false;
  bool _isConverting = false;

  @override
  void initState() {
    super.initState();
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
    // Prevent re-entry when updating the controller text after Velthuis conversion
    if (_isConverting) return;

    // Apply Velthuis conversion and update the displayed text on-the-fly
    final converted = velthuis(value);
    if (converted != value && converted.trim().isNotEmpty) {
      _isConverting = true;
      _searchController.value = convertedTextEditingValue(
        _searchController.value,
      );
      _isConverting = false;
    }

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
    _debounce = Timer(const Duration(milliseconds: 200), () async {
      if (effectiveValue.trim().isNotEmpty) {
        // Use the LAST word as the suggestion prefix, so multi-word queries
        // continue to show suggestions for the word being typed right now.
        final words = effectiveValue.trim().split(RegExp(r'\s+'));
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
        .search(query: query, fuzzy: _fuzzy, distance: _wordDistance);
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
    context.push('/reader');
  }

  void _onResultLongPress(BookResultSummary summary, SearchResultItem item) {
    _showResultPreviewDialog(summary, item);
  }

  Future<void> _showResultPreviewDialog(
    BookResultSummary summary,
    SearchResultItem item,
  ) async {
    HapticFeedback.mediumImpact();

    final currentState = ref.read(searchProvider);
    final searchQuery = currentState is SearchResults
        ? currentState.query
        : null;

    try {
      final epitakaDb = await ref.read(epitakaDbProvider.future);
      final settings = ref.read(settingsProvider);
      final activeLang = settings.enabledTranslations.isNotEmpty
          ? settings.enabledTranslations.first
          : (settings.showTranslation ? settings.primaryTranslationLang : null);

      // 1. Find nearest heading at or before the matched paraId
      final headingRows = await epitakaDb
          .customSelect(
            'SELECT title, para_id FROM headings '
            'WHERE book_id = ? AND para_id <= ? '
            'ORDER BY para_id DESC LIMIT 1',
            variables: [
              Variable.withString(item.bookId),
              Variable.withInt(item.paraId),
            ],
          )
          .get();

      if (headingRows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No heading found for this result')),
          );
        }
        return;
      }

      final headingTitle = (headingRows.first.data['title'] as String?) ?? '';
      final headingParaId = headingRows.first.data['para_id'] as int;

      // 2. Find next heading boundary
      final nextHeadingRows = await epitakaDb
          .customSelect(
            'SELECT para_id FROM headings '
            'WHERE book_id = ? AND para_id > ? '
            'ORDER BY para_id ASC LIMIT 1',
            variables: [
              Variable.withString(item.bookId),
              Variable.withInt(headingParaId),
            ],
          )
          .get();

      final endParaId = nextHeadingRows.isNotEmpty
          ? (nextHeadingRows.first.data['para_id'] as int)
          : 999999;

      // 3. Load all sentences in the heading section
      final sentenceRows = await epitakaDb
          .customSelect(
            'SELECT para_id, line_id, pali FROM sentences '
            'WHERE book_id = ? AND para_id >= ? AND para_id < ? '
            'ORDER BY para_id, line_id',
            variables: [
              Variable.withString(item.bookId),
              Variable.withInt(headingParaId),
              Variable.withInt(endParaId),
            ],
          )
          .get();

      // 4. Load translations for those sentences
      final translationMap = <String, Map<String, String>>{};
      if (activeLang != null) {
        try {
          final lang = TranslationLanguage.fromCode(activeLang);
          final transDb = await ref.read(translationDbProvider(lang).future);
          if (transDb != null) {
            final transRows = await transDb
                .customSelect(
                  'SELECT para_id, line_id, translation FROM sentences '
                  'WHERE book_id = ? AND para_id >= ? AND para_id < ? '
                  'ORDER BY para_id, line_id',
                  variables: [
                    Variable.withString(item.bookId),
                    Variable.withInt(headingParaId),
                    Variable.withInt(endParaId),
                  ],
                )
                .get();
            for (final row in transRows) {
              final key = '${row.data['para_id']}:${row.data['line_id']}';
              final t = row.data['translation'] as String?;
              if (t != null && t.isNotEmpty) {
                if (!translationMap.containsKey(key)) {
                  translationMap[key] = {};
                }
                translationMap[key]![activeLang] = t;
              }
            }
          }
        } catch (_) {}
      }

      // 5. Build preview line list
      final previewLines = sentenceRows.map((r) {
        final key = '${r.data['para_id']}:${r.data['line_id']}';
        return PreviewLineData(
          paraId: r.data['para_id'] as int,
          lineId: r.data['line_id'] as int,
          pali: r.data['pali'] as String? ?? '',
          translations: translationMap[key] ?? {},
        );
      }).toList();

      // Find the first snippet line index
      final firstSnippetIndex = previewLines.indexWhere(
        (l) => l.paraId == item.paraId,
      );

      if (!mounted) return;

      await showParagraphPreviewSheet(
        context,
        title: headingTitle.isNotEmpty
            ? headingTitle
            : (summary.book.bookName ?? item.bookId),
        subtitle: headingTitle.isNotEmpty
            ? (summary.book.bookName ?? item.bookId)
            : null,
        lines: previewLines,
        highlightParaId: item.paraId,
        firstSnippetIndex: firstSnippetIndex >= 0 ? firstSnippetIndex : null,
        paliSnippet: item.paliSnippet ?? item.paliText,
        actionLabel: 'Open in Reader',
        onAction: () {
          // Open the reader tab
          ref
              .read(readerTabsProvider.notifier)
              .openTab(
                ReaderTabInfo(
                  bookId: item.bookId,
                  bookName: summary.book.bookName ?? item.bookId,
                  initialParaId: item.paraId,
                  searchQuery: searchQuery,
                ),
              );
          Navigator.of(context).pop();
          context.push('/reader');
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load preview: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final searchState = ref.watch(searchProvider);

    final isFromDrawer =
        GoRouterState.of(context).uri.queryParameters['fromDrawer'] == 'true';

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: AppDimensions.appBarHeight,
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(isFromDrawer ? Icons.menu : Icons.arrow_back),
          color: colors.onSurfaceVariant,
          onPressed: () {
            if (isFromDrawer) {
              // Go back to library
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(
          'Search',
          style: AppTypography.headlineSmall.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(colors),
          _buildOptionsBar(colors, searchState),
          if (_showSuggestions && _suggestions.isNotEmpty)
            _buildSuggestions(colors),
          Expanded(child: _buildResults(searchState, colors)),
        ],
      ),
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
        style: AppTypography.bodyPali.copyWith(
          fontSize: 16,
          color: colors.onSurface,
        ),
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
            label: Text(
              'Fuzzy',
              style: AppTypography.labelSmall.copyWith(
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
          const SizedBox(width: 8),

          // Word distance selector — auto-highlights when 2+ words detected
          PopupMenuButton<int>(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Word distance',
            initialValue: _wordDistance,
            onSelected: (val) {
              setState(() => _wordDistance = val);
              if (_searchController.text.isNotEmpty) _executeSearch();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 0, child: Text('Any distance')),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 3,
                child: Row(
                  children: [
                    Icon(Icons.check, size: 16, color: Colors.transparent),
                    SizedBox(width: 8),
                    Text('Within 3 words'),
                  ],
                ),
              ),
              const PopupMenuItem(value: 1, child: Text('Within 1 word')),
              const PopupMenuItem(value: 2, child: Text('Within 2 words')),
              const PopupMenuItem(value: 5, child: Text('Within 5 words')),
              const PopupMenuItem(value: 10, child: Text('Within 10 words')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _wordDistance > 0
                    ? colors.secondaryContainer
                    : (_isMultiWord
                          ? colors.tertiaryContainer
                          : colors.surfaceContainerHighest),
                borderRadius: BorderRadius.circular(16),
                border: _isMultiWord && _wordDistance == 0
                    ? Border.all(color: colors.tertiary.withValues(alpha: 0.5))
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
                    _wordDistance > 0 ? 'Dist: $_wordDistance' : 'Dist',
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

          // Hint text for fuzzy
          if (_fuzzy)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '(ā=a, ñ=n, ṭ=t …)',
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
            ),

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
                '${searchState.totalResults} result${searchState.totalResults == 1 ? '' : 's'}',
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
          );
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
      case SearchResults(
        :final bookSummaries,
        :final query,
        :final totalResults,
      ):
        return _buildResultList(colors, bookSummaries, query, totalResults);
      case SearchError(:final message):
        return _buildErrorState(colors, message);
    }
  }

  Widget _buildIdleState(ColorScheme colors) {
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
            'Search the Pāli Tipiṭaka',
            style: AppTypography.headlineSmall.copyWith(
              color: colors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          SizedBox(
            width: 280,
            child: Text(
              'Search across both Pāli text and translations.\n'
              'Enable fuzzy mode to match diacritic variations (ā=a, ñ=n, ṭ=t …).',
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
            const SizedBox(height: AppDimensions.xs),
            Text(
              'Try enabling fuzzy search or using different terms.',
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
      itemCount: summaries.length,
      itemBuilder: (context, index) {
        final summary = summaries[index];
        return _BookResultCard(
          summary: summary,
          colors: colors,
          searchQuery: query,
          onTapResult: (item) => _onResultTap(summary, item),
          onLongPressResult: (item) => _onResultLongPress(summary, item),
          onToggleExpanded: () {
            if (summary.isExpanded) {
              ref.read(searchProvider.notifier).collapseBook(index);
            } else {
              ref.read(searchProvider.notifier).expandBook(index);
            }
          },
          onLoadMore: () {
            ref.read(searchProvider.notifier).loadMoreForBook(index);
          },
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

// ── Book Result Card ─────────────────────────────────────────────────────

class _BookResultCard extends StatelessWidget {
  final BookResultSummary summary;
  final ColorScheme colors;
  final String searchQuery;
  final void Function(SearchResultItem item) onTapResult;
  final void Function(SearchResultItem item)? onLongPressResult;
  final VoidCallback onToggleExpanded;
  final VoidCallback onLoadMore;

  const _BookResultCard({
    required this.summary,
    required this.colors,
    required this.searchQuery,
    required this.onTapResult,
    this.onLongPressResult,
    required this.onToggleExpanded,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = _displayBookName(summary.book);

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
          // ── Header ─────────────────────────────────────────────────
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
                            color: colors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (summary.book.nikaya != null ||
                            summary.book.category != null)
                          Text(
                            [
                              if (summary.book.nikaya != null)
                                summary.book.nikaya,
                              if (summary.book.category != null)
                                summary.book.category,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: summary.isExpanded
                          ? colors.primaryContainer
                          : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
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
                            fontSize: 11,
                          ),
                        ),
                        if (summary.isExpanded &&
                            summary.loadedCount < summary.totalCount)
                          Padding(
                            padding: const EdgeInsets.only(left: 2),
                            child: Text(
                              '/${summary.loadedCount}',
                              style: AppTypography.labelSmall.copyWith(
                                color: colors.onSurfaceVariant.withValues(
                                  alpha: 0.5,
                                ),
                                fontSize: 9,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: summary.isExpanded ? 0.5 : 0,
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

          // ── Expanded results ───────────────────────────────────────
          if (summary.isExpanded) ...[
            // Flatten all loaded pages into items
            ...summary.loadedPages.expand(
              (page) => page.map(
                (item) => _SearchResultItemTile(
                  item: item,
                  colors: colors,
                  searchQuery: searchQuery,
                  onTap: () => onTapResult(item),
                  onLongPress: () => onLongPressResult?.call(item),
                ),
              ),
            ),

            // Load more button
            if (!summary.fullyLoaded)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.md,
                  vertical: 4,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: onLoadMore,
                    icon: const Icon(Icons.expand_more, size: 18),
                    label: Text(
                      'Show more (${summary.totalCount - summary.loadedCount} remaining)',
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.primary,
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

  String _displayBookName(BookInfo book) {
    return book.displayName;
  }
}

// ── Search Result Item Tile ──────────────────────────────────────────────

class _SearchResultItemTile extends StatelessWidget {
  final SearchResultItem item;
  final ColorScheme colors;
  final String searchQuery;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _SearchResultItemTile({
    required this.item,
    required this.colors,
    required this.searchQuery,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.md,
          6,
          AppDimensions.md,
          6,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Para badge
            Container(
              width: 40,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              // child: Text(
              //   '§${item.paraId}',
              //   style: AppTypography.labelSmall.copyWith(
              //     fontSize: 9,
              //     color: colors.onSurfaceVariant,
              //   ),
              // ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pāli text — prefer FTS5 snippet with <mark> tags
                  // (shows context around the match), fall back to full text.
                  // When using the snippet, skip client-side searchTerms since
                  // FTS5 already inserted <mark> tags.
                  _HtmlRichText(
                    text: item.paliSnippet ?? item.paliText,
                    searchTerms: item.paliSnippet != null
                        ? const []
                        : _extractSearchTerms(searchQuery),
                    style: AppTypography.bodyPali.copyWith(
                      fontSize: 14,
                      color: colors.onSurface,
                      height: 1.4,
                    ),
                    highlightColor: colors.primary.withValues(alpha: 0.2),
                    // Show all content — no line limit
                    maxLines: null,
                  ),
                  // Translation text — prefer FTS5 snippet, fall back to full text
                  if (item.translation != null &&
                      item.translation!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _HtmlRichText(
                      text: item.translationSnippet ?? item.translation!,
                      searchTerms: item.translationSnippet != null
                          ? const []
                          : _extractSearchTerms(searchQuery),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant.withValues(alpha: 0.8),
                        fontStyle: FontStyle.italic,
                        height: 1.3,
                      ),
                      highlightColor: colors.primary.withValues(alpha: 0.15),
                      // Show all content — no line limit
                      maxLines: null,
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
}

// ── HTML + Markdown Rich Text Renderer ──────────────────────────────────

/// Renders text containing HTML tags (`<b>`, `<i>`, `<u>`, `<mark>`)
/// and highlights [searchTerms] with a colored background.
/// Also renders `<br>` as newlines.
class _HtmlRichText extends StatelessWidget {
  final String text;
  final List<String> searchTerms;
  final TextStyle style;
  final Color highlightColor;
  final int? maxLines;

  const _HtmlRichText({
    required this.text,
    this.searchTerms = const [],
    required this.style,
    required this.highlightColor,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    // First: split HTML tags into segments
    final segments = _parseHtmlSegments(text);

    // Second: for each segment, apply search highlighting
    final spans = <TextSpan>[];
    for (final segment in segments) {
      if (segment.isHtml) {
        // Render as styled text
        spans.add(
          TextSpan(
            text: segment.text,
            style: segment.htmlStyle?.let((s) => _applyStyle(s)),
          ),
        );
      } else {
        // Apply search highlighting to plain text
        _applyHighlighting(segment.text, spans);
      }
    }

    return Text.rich(
      TextSpan(children: spans, style: style),
      maxLines: maxLines,
      // Only ellipsize when a maxLines limit is actually set
      overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
    );
  }

  TextStyle _applyStyle(_HtmlTag tag) {
    var result = style;
    switch (tag) {
      case _HtmlTag.b:
        result = result.copyWith(fontWeight: FontWeight.w700);
      case _HtmlTag.i:
        result = result.copyWith(fontStyle: FontStyle.italic);
      case _HtmlTag.u:
        result = result.copyWith(decoration: TextDecoration.underline);
      case _HtmlTag.mark:
        result = result.copyWith(
          backgroundColor: highlightColor,
          fontWeight: FontWeight.w700,
        );
    }
    return result;
  }

  void _applyHighlighting(String plainText, List<TextSpan> spans) {
    if (searchTerms.isEmpty || plainText.isEmpty) {
      spans.add(TextSpan(text: plainText));
      return;
    }

    // Find intervals directly in the original text's position space by
    // comparing each character through a normalised lens.  This avoids the
    // index-mismatch bug that would occur if we called
    // normalizePaliFuzzy() on the whole string (which strips punctuation
    // and shifts character positions).
    final lowerText = plainText.toLowerCase();
    final textLen = lowerText.length;
    final intervals = <_Interval>[];

    for (final term in searchTerms) {
      if (term.isEmpty) continue;
      final termLen = term.length;
      final maxStart = textLen - termLen;
      if (maxStart < 0) continue;

      int pos = 0;
      while (pos <= maxStart) {
        bool match = true;
        for (int i = 0; i < termLen; i++) {
          if (_normChar(lowerText.codeUnitAt(pos + i)) != term.codeUnitAt(i)) {
            match = false;
            break;
          }
        }
        if (match) {
          intervals.add(_Interval(pos, pos + termLen));
          pos += termLen;
        } else {
          pos++;
        }
      }
    }

    if (intervals.isEmpty) {
      spans.add(TextSpan(text: plainText));
      return;
    }

    // Sort and merge overlapping/adjacent intervals
    intervals.sort((a, b) => a.start.compareTo(b.start));
    final merged = <_Interval>[];
    var current = intervals.first;
    for (int i = 1; i < intervals.length; i++) {
      final next = intervals[i];
      if (next.start <= current.end) {
        if (next.end > current.end) {
          current = _Interval(current.start, next.end);
        }
      } else {
        merged.add(current);
        current = next;
      }
    }
    merged.add(current);

    // Build spans using original-text positions (always correct now)
    int lastIdx = 0;
    for (final interval in merged) {
      if (interval.start > lastIdx) {
        spans.add(TextSpan(text: plainText.substring(lastIdx, interval.start)));
      }
      spans.add(
        TextSpan(
          text: plainText.substring(interval.start, interval.end),
          style: TextStyle(
            backgroundColor: highlightColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      lastIdx = interval.end;
    }
    if (lastIdx < plainText.length) {
      spans.add(TextSpan(text: plainText.substring(lastIdx)));
    }
  }

  /// Normalise a single lowercased code point for comparison.
  /// Pāli diacritics → ASCII; everything else (including punctuation)
  /// passes through unchanged so that positions stay in sync with the
  /// original [plainText].
  static int _normChar(int c) {
    switch (c) {
      case 0x0101:
        return 0x61; // ā → a
      case 0x012B:
        return 0x69; // ī → i
      case 0x016B:
        return 0x75; // ū → u
      case 0x014D:
        return 0x6F; // ō → o
      case 0x1E45:
        return 0x6E; // ṅ → n
      case 0x00F1:
        return 0x6E; // ñ → n
      case 0x1E6D:
        return 0x74; // ṭ → t
      case 0x1E0D:
        return 0x64; // ḍ → d
      case 0x1E47:
        return 0x6E; // ṇ → n
      case 0x1E37:
        return 0x6C; // ḷ → l
      case 0x1E3B:
        return 0x6C; // ḻ → l
      case 0x1E43:
        return 0x6D; // ṃ → m
      case 0x1E41:
        return 0x6D; // ṁ → m
      case 0x1E25:
        return 0x68; // ḥ → h
      default:
        return c;
    }
  }

  /// Parse text with HTML tags into segments.
  List<_TextSegment> _parseHtmlSegments(String html) {
    final segments = <_TextSegment>[];
    final regex = RegExp(r'<(/?)(b|i|u|mark|br)\s*/?>', caseSensitive: false);
    final stack = <_HtmlTag>[];
    int lastEnd = 0;

    for (final match in regex.allMatches(html)) {
      // Add text before this tag
      if (match.start > lastEnd) {
        segments.add(
          _TextSegment(
            text: html.substring(lastEnd, match.start),
            isHtml: stack.isNotEmpty,
            htmlStyle: stack.isNotEmpty ? stack.last : null,
          ),
        );
      }

      final isClosing = match.group(1) == '/';
      final tagName = match.group(2)!.toLowerCase();

      if (tagName == 'br') {
        // Line break - insert newline
        segments.add(_TextSegment(text: '\n', isHtml: false));
      } else if (isClosing) {
        // Closing tag
        final tag = _HtmlTag.values.firstWhere(
          (t) => t.name == tagName,
          orElse: () => _HtmlTag.b,
        );
        stack.remove(tag);
      } else {
        // Opening tag
        final tag = _HtmlTag.values.firstWhere(
          (t) => t.name == tagName,
          orElse: () => _HtmlTag.b,
        );
        stack.add(tag);
      }

      lastEnd = match.end;
    }

    // Remaining text after last tag
    if (lastEnd < html.length) {
      segments.add(
        _TextSegment(
          text: html.substring(lastEnd),
          isHtml: stack.isNotEmpty,
          htmlStyle: stack.isNotEmpty ? stack.last : null,
        ),
      );
    }

    return segments;
  }
}

enum _HtmlTag { b, i, u, mark }

class _TextSegment {
  final String text;
  final bool isHtml;
  final _HtmlTag? htmlStyle;

  const _TextSegment({
    required this.text,
    required this.isHtml,
    this.htmlStyle,
  });
}

class _Interval {
  final int start;
  final int end;
  const _Interval(this.start, this.end);
}

// ── Utility ──────────────────────────────────────────────────────────────

/// Extract normalized search terms for highlighting.
List<String> _extractSearchTerms(String query) {
  return normalizePaliFuzzy(
    query,
  ).split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
}

/// Format a number (e.g. 1234 -> "1.2k").
String formatCount(int count) {
  if (count < 1000) return count.toString();
  if (count < 10000) return '${(count / 1000).toStringAsFixed(1)}k';
  return '${(count / 1000).toStringAsFixed(0)}k';
}

extension _Lets<T> on T {
  R let<R>(R Function(T) fn) => fn(this);
}
