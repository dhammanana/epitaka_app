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
import '../../../core/utils/pali_script_converter.dart';
import '../../../core/utils/pali_text_utils.dart';
import '../../../shared/utils/html_text_parser.dart';
import '../../../core/utils/velthuis.dart';
import '../../../shared/widgets/paragraph_preview_sheet.dart';
import '../../../shared/widgets/preview_content.dart';
import '../../reader/providers/reader_tabs_provider.dart';
import '../providers/search_provider.dart';
import 'search_result_highlight.dart';

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
  bool _showFilters = false;

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
    context.push('/reader');
  }

  void _onHeadingResultTap(HeadingResult heading) {
    final currentState = ref.read(searchProvider);
    final query = currentState is SearchResults ? currentState.query : null;

    ref
        .read(readerTabsProvider.notifier)
        .openTab(
          ReaderTabInfo(
            bookId: heading.bookId,
            bookName: heading.bookName ?? heading.bookId,
            initialParaId: heading.paraId,
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
          final transDb = await ref.read(translationDbProvider(activeLang).future);
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
        paliSnippet: item.lines.isNotEmpty
            ? item.lines.where((l) => l.isMatch).map((l) => l.pali).join(' ')
            : '',
        actionLabel: 'Open in Reader',
        onAction: () {
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

          // Open the reader tab
          ref
              .read(readerTabsProvider.notifier)
              .openTab(
                ReaderTabInfo(
                  bookId: item.bookId,
                  bookName: summary.book.bookName ?? item.bookId,
                  initialParaId: item.paraId,
                  initialLineId: initialLineId,
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
        actions: [
          const _FontSizeButton(),
          const SizedBox(width: AppDimensions.xs),
        ],
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
      child: Column(
        children: [
          Row(
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

              // Word distance selector
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

              // Fuzzy hint
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

              // Filter toggle
              IconButton(
                icon: Icon(
                  _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
                  size: 20,
                ),
                color: _showFilters ? colors.primary : colors.onSurfaceVariant,
                tooltip: 'Toggle filters',
                onPressed: () => setState(() => _showFilters = !_showFilters),
              ),

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

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
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
                    'Layer',
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
                    children: kAllCategories.map((key) => _FilterChip(
                      label: key,
                      selected: enabledCats.contains(key),
                      colors: colors,
                      onTap: () => notifier.toggleCategory(key),
                    )).toList(),
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
                    'Nikāya',
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
                    children: kAllNikayas.map((key) => _FilterChip(
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
        :final headings,
      ):
        return _buildResultList(
          colors, bookSummaries, query, totalResults, headings,
        );
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
    List<HeadingResult> headings,
  ) {
    if (summaries.isEmpty && headings.isEmpty) {
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

    final totalItems = summaries.length + (headings.isNotEmpty ? 1 : 0);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.marginMobile,
        AppDimensions.sm,
        AppDimensions.marginMobile,
        AppDimensions.bottomToolbarHeight + AppDimensions.lg,
      ),
      itemCount: totalItems,
      itemBuilder: (context, index) {
        // Show heading results card first (if any)
        if (headings.isNotEmpty && index == 0) {
          return _HeadingResultsCard(
            headings: headings,
            colors: colors,
            onTap: (heading) => _onHeadingResultTap(heading),
          );
        }

        // Then show book summary cards
        final summaryIndex = headings.isNotEmpty ? index - 1 : index;
        if (summaryIndex >= summaries.length) return const SizedBox.shrink();

        final summary = summaries[summaryIndex];
        return _BookResultCard(
          summary: summary,
          colors: colors,
          onTapResult: (item) => _onResultTap(summary, item),
          onLongPressResult: (item) => _onResultLongPress(summary, item),
          onToggleExpanded: () {
            if (summary.isExpanded) {
              ref.read(searchProvider.notifier).collapseBook(summaryIndex);
            } else {
              ref.read(searchProvider.notifier).expandBook(summaryIndex);
            }
          },
          onLoadMore: () {
            ref.read(searchProvider.notifier).loadMoreForBook(summaryIndex);
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

// ── Font size button ────────────────────────────────────────────────────

/// Small font-size popup button in the search screen's app bar.
///
/// Adjusts the Pāli + translation font sizes through the settings notifier
/// (the same path used by the typography settings screen and the keyboard
/// shortcuts), so the change is reflected everywhere — including the search
/// results, which follow the app's typography settings.
class _FontSizeButton extends ConsumerWidget {
  const _FontSizeButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final paliSize = settings.typography.pali.fontSize.round();

    return PopupMenuButton<String>(
      tooltip: 'Font size',
      icon: Text(
        'A',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: colors.onSurfaceVariant,
        ),
      ),
      offset: const Offset(0, 48),
      onSelected: (value) {
        final notifier = ref.read(settingsProvider.notifier);
        if (value == 'inc') {
          notifier.increaseFontSize();
        } else {
          notifier.decreaseFontSize();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Text(
                  'Pāli ${paliSize}px',
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  'Ctrl/Cmd + / −',
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'inc',
          child: Row(
            children: [
              const Icon(Icons.add, size: 18),
              const SizedBox(width: 8),
              Text(
                'Increase font size',
                style: AppTypography.labelMedium.copyWith(
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'dec',
          child: Row(
            children: [
              const Icon(Icons.remove, size: 18),
              const SizedBox(width: 8),
              Text(
                'Decrease font size',
                style: AppTypography.labelMedium.copyWith(
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
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

// ── Book Result Card ─────────────────────────────────────────────────────

class _BookResultCard extends StatelessWidget {
  final BookResultSummary summary;
  final ColorScheme colors;
  final void Function(SearchResultItem item) onTapResult;
  final void Function(SearchResultItem item)? onLongPressResult;
  final VoidCallback onToggleExpanded;
  final VoidCallback onLoadMore;

  const _BookResultCard({
    required this.summary,
    required this.colors,
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
            ...summary.loadedPages.expand(
              (page) => page.map(
                (item) => _SearchResultItemTile(
                  item: item,
                  colors: colors,
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

// ── Heading Results Card ──────────────────────────────────────────────────

class _HeadingResultsCard extends StatelessWidget {
  final List<HeadingResult> headings;
  final ColorScheme colors;
  final void Function(HeadingResult heading) onTap;

  const _HeadingResultsCard({
    required this.headings,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      elevation: 0,
      color: colors.tertiaryContainer.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        side: BorderSide(
          color: colors.tertiary.withValues(alpha: 0.4),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.md, 10, AppDimensions.md, 6,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.toc,
                  size: 16,
                  color: colors.tertiary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Section headings',
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.tertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${headings.length} found',
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onTertiaryContainer,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 12, endIndent: 12),
          // ── Heading items ─────────────────────────────────────────
          ...headings.map((heading) => InkWell(
            onTap: () => onTap(heading),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.md,
                vertical: 10,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.subdirectory_arrow_right,
                    size: 14,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          heading.title,
                          style: AppTypography.labelMedium.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (heading.bookName != null &&
                            heading.bookName!.isNotEmpty)
                          Text(
                            heading.bookName!,
                            style: AppTypography.labelSmall.copyWith(
                              color: colors.onSurfaceVariant,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}

// ── Search Result Item Tile (line-by-line) ───────────────────────────────

class _SearchResultItemTile extends ConsumerWidget {
  final SearchResultItem item;
  final ColorScheme colors;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _SearchResultItemTile({
    required this.item,
    required this.colors,
    required this.onTap,
    this.onLongPress,
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
      final query = searchState.query;
      searchTerms = normalizePaliFuzzy(query)
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
    } else {
      searchTerms = const [];
    }

    // Get typography for Pali
    final paliTypo = settings.typography.pali;
    final paliTextStyle = paliTypo.toTextStyle(
      fallbackColor: colors.onSurface,
    );

    // Get typography for translation
    final transTypo = activeLang != null
        ? settings.typography.typographyFor(activeLang)
        : null;
    final transTextStyle = transTypo?.toTextStyle(
      fallbackColor: colors.onSurfaceVariant.withValues(alpha: 0.8),
    ) ?? TextStyle(
      fontSize: 12,
      color: colors.onSurfaceVariant.withValues(alpha: 0.8),
      fontStyle: FontStyle.italic,
      height: 1.3,
    );

    // Only show lines that actually match the search
    final matchingLines = item.lines.where((l) => l.isMatch).toList();
    if (matchingLines.isEmpty) return const SizedBox.shrink();

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.md,
          8,
          AppDimensions.md,
          8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Para heading badge (tap to open) ──────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.tertiaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '§${item.paraId}',
                      style: AppTypography.labelSmall.copyWith(
                        fontSize: 9,
                        color: colors.onTertiaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (matchingLines.length < item.lines.length)
                    Text(
                      '${matchingLines.length}/${item.lines.length} matches',
                      style: AppTypography.labelSmall.copyWith(
                        fontSize: 9,
                        color: colors.primary.withValues(alpha: 0.7),
                      ),
                    ),
                  const Spacer(),
                  Icon(Icons.chevron_right, size: 14, color: colors.onSurfaceVariant),
                ],
              ),
            ),

            // ── Matching lines with Pali + Translation ──────────────
            ...matchingLines.map((line) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: _LineTile(
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

/// A single line in the search result, showing Pali and translation.
class _LineTile extends StatelessWidget {
  final SearchResultLine line;
  final List<String> searchTerms;
  final TextStyle paliTextStyle;
  final TextStyle transTextStyle;
  final ColorScheme colors;
  final Script script;

  const _LineTile({
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
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pali text — with search term highlighting and script conversion
          if (line.pali.isNotEmpty)
            _buildHighlightedPaliText(
              text: line.pali,
              searchTerms: searchTerms,
              script: script,
              style: paliTextStyle.copyWith(
                fontSize: paliTextStyle.fontSize ?? 14,
                height: paliTextStyle.height ?? 1.4,
              ),
              highlightColor: highlightColor,
            ),

          // Translation text — with search term highlighting
          if (line.translation != null && line.translation!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: _buildHighlightedTranslationText(
                text: line.translation!,
                searchTerms: searchTerms,
                style: transTextStyle.copyWith(
                  fontSize: transTextStyle.fontSize ?? 12,
                  height: transTextStyle.height ?? 1.3,
                ),
                highlightColor: highlightColor,
              ),
            ),
        ],
      ),
    );
  }

  /// Build Pali text with search terms highlighted, respecting script settings.
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
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      );
    }

    final spans = buildSearchSnippetSpans(
      html: converted,
      baseStyle: effStyle,
      terms: searchTerms,
      isPali: true,
      highlightColor: highlightColor,
      beforeChars: 40,
      afterChars: 60,
    );

    return Text.rich(
      TextSpan(style: effStyle, children: spans),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Build translation text with search terms highlighted (no script conversion).
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
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    final spans = buildSearchSnippetSpans(
      html: text,
      baseStyle: style,
      terms: searchTerms,
      isPali: false,
      highlightColor: highlightColor,
      beforeChars: 35,
      afterChars: 55,
    );

    return Text.rich(
      TextSpan(style: style, children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
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
