import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/dpd_dictionary_database.dart';
import '../../../core/providers/dictionary_books_provider.dart';
import '../../../core/providers/dpd_dictionary_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/velthuis.dart';
import '../../../core/providers/database_provider.dart';
import 'package:drift/drift.dart' hide Column;

void showDictionarySheet(BuildContext context, String word) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DictionarySheet(initialWord: word),
  );
}

// ── Enums ──────────────────────────────────────────────────────────────────

enum _SheetView { search, results }

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
  final _scrollController = ScrollController();
  Timer? _debounce;
  bool _isConverting = false;

  _SheetView _view = _SheetView.search;

  /// Whether to show the word detail instead of search results.
  bool _showDetail = false;

  // The currently looked up word
  String _query = '';
  // Deconstructor card navigation
  int _activeDeconCardIndex = 0;
  int _activeDeconTabIndex = 0;

  /// Cached sub-lookup results for deconstructor tokens.
  /// key: token word, value: list of headword rows
  final Map<String, List<DpdHeadwordRow>> _subLookupCache = {};

  /// Cached epitaka dictionary results (from epitaka.db dictionary table).
  /// key: dictionary book_id, value: list of definition texts
  final Map<int, List<String>> _epitakaDictCache = {};

  // Search history
  final List<String> _searchHistory = [];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialWord.trim();
    if (initial.isNotEmpty) {
      _searchController.text = initial;
      _query = initial;
      _addToHistory(initial);
      _performSearch(initial);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _addToHistory(String word) {
    final w = word.trim();
    if (w.isEmpty) return;
    setState(() {
      _searchHistory.remove(w);
      _searchHistory.insert(0, w);
      if (_searchHistory.length > 15) {
        _searchHistory.removeLast();
      }
    });
  }

  void _onSearchChanged(String value) {
    if (_isConverting) return;
    _debounce?.cancel();

    final converted = velthuis(value);

    if (converted != value && converted.trim().isNotEmpty) {
      _isConverting = true;
      _searchController.value = TextEditingValue(
        text: converted,
        selection: TextSelection.collapsed(offset: converted.length),
      );
      _isConverting = false;
    }

    final trimmed = converted.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _query = '';
        _view = _SheetView.search;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _query = trimmed;
        _view = _SheetView.results;
        _showDetail = false;
      });
    });
  }

  void _performSearch(String value) {
    final converted = velthuis(value).trim();
    _addToHistory(converted);
    setState(() {
      _query = converted;
      _view = _SheetView.results;
      _showDetail = false;
    });
    _focusNode.unfocus();
  }

  void _selectWord(String word) {
    final converted = velthuis(word);
    _searchController.text = converted;
    _addToHistory(converted);
    _query = converted;
    _view = _SheetView.results;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.88,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusSheet),
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: Column(
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
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search Pāḷi…',
                        prefixIcon: Icon(Icons.search, color: colors.onSurfaceVariant),
                        suffixIcon: _searchController.text.isNotEmpty
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
                          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.md,
                          vertical: 12,
                        ),
                      ),
                      style: AppTypography.bodyTranslation.copyWith(
                        color: colors.onSurface,
                        fontSize: 16,
                      ),
                      onChanged: _onSearchChanged,
                      onSubmitted: _performSearch,
                    ),
                  ),
                ],
              ),
            ),

            // Search history row
            if (_searchHistory.isNotEmpty)
              Container(
                height: 40,
                margin: const EdgeInsets.only(top: 8, left: 16, right: 16),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _searchHistory.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return ActionChip(
                      label: Text(_searchHistory[index]),
                      labelStyle: AppTypography.labelSmall.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      backgroundColor: colors.surfaceContainerHighest,
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onPressed: () {
                        _searchController.text = _searchHistory[index];
                        _performSearch(_searchHistory[index]);
                      },
                    );
                  },
                ),
              ),

            const SizedBox(height: AppDimensions.sm),
            const Divider(height: 1),

            // Content area
            Expanded(
              child: _buildContent(colors),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme colors) {
    switch (_view) {
      case _SheetView.search:
        return _buildIdleState(colors);
      case _SheetView.results:
        return _buildResults(colors);
    }
  }

  Widget _buildIdleState(ColorScheme colors) {
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
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            'Search for a Pāḷi word to see\ndefinitions across multiple dictionaries',
            textAlign: TextAlign.center,
            style: AppTypography.bodyTranslation.copyWith(
              color: colors.onSurfaceVariant.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(ColorScheme colors) {
    return ref.watch(dpdDictionarySearchProvider(_query)).when(
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
        // When a result card was tapped, show detail directly
        if (_showDetail) {
          return _buildWordDetail(colors);
        }
        if (results.isEmpty && _query.length >= 2) {
          // Try showing the word directly (not just search prefix)
          return _buildWordDetail(colors);
        }
        if (results.isEmpty) {
          return _buildEmptyState(colors);
        }

        // Show search results
        return CustomScrollView(
          controller: _scrollController,
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
                  'Search results for "$_query"',
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
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
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final result = results[index];
                    return _SearchResultCard(
                      lemma1: result.lemma1,
                      meaningHtmlPreview: result.meaningHtml,
                      onTap: () {
                        _selectWordFromResult(result);
                      },
                      colors: colors,
                    );
                  },
                  childCount: results.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _selectWordFromResult(DpdHeadwordRow hw) {
    _searchController.text = hw.cleanLemma1;
    _query = hw.cleanLemma1;
    _addToHistory(hw.cleanLemma1);
    _subLookupCache.clear();
    _epitakaDictCache.clear();
    _activeDeconCardIndex = 0;
    _activeDeconTabIndex = 0;
    _showDetail = true;
    _view = _SheetView.results;
    // Trigger state rebuild so _buildResults shows detail
    setState(() {});
  }

  Widget _buildEmptyState(ColorScheme colors) {
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
              'No direct matches found for "$_query"',
              style: AppTypography.bodyTranslation.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            // Show detail view directly
            const SizedBox(height: 16),
            TextButton.icon(
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Show full details'),
              onPressed: () {
                setState(() => _showDetail = true);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Build the full word detail view (DPD + other dictionaries).
  Widget _buildWordDetail(ColorScheme colors) {
    return ref.watch(dpdDictionaryLookupProvider(_query)).when(
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
        if (!lookup.hasHeadwords && !lookup.hasDeconstructor) {
          return _buildEmptyState(colors);
        }
        return _buildDictionaryResults(colors, lookup);
      },
    );
  }

  /// Show combined results from DPD and other dictionaries.
  Widget _buildDictionaryResults(ColorScheme colors, DpdFullLookup lookup) {
    // Get the cleaned lemma_1 for cross-dictionary search
    String searchWord = _query;
    if (lookup.headwords.isNotEmpty) {
      searchWord = lookup.headwords.first.cleanLemma1;
    }

    return FutureBuilder<List<DictionaryBook>>(
      future: ref.read(dictionaryBooksProvider.future),
      builder: (context, booksSnapshot) {
        final enabledBooks = booksSnapshot.data
                ?.where((b) => b.userChoice)
                .toList() ??
            [];

        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            // ── DPD Dictionary Section ──────────────────────────────
            if (lookup.hasHeadwords || lookup.hasDeconstructor)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.marginMobile,
                    AppDimensions.sm,
                    AppDimensions.marginMobile,
                    0,
                  ),
                  child: _buildDpdSection(colors, lookup),
                ),
              ),

            // ── Other Dictionaries ──────────────────────────────────
            ..._buildOtherDictionarySections(colors, searchWord, enabledBooks),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        );
      },
    );
  }

  // ── DPD Section ──────────────────────────────────────────────────────────

  Widget _buildDpdSection(ColorScheme colors, DpdFullLookup lookup) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label
        Row(
          children: [
            Icon(Icons.auto_stories, size: 18, color: colors.primary),
            const SizedBox(width: 6),
            Text(
              'dpd dictionary',
              style: AppTypography.labelSmall.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Searched word
        Text(
          lookup.searchedKey,
          style: AppTypography.displayPali.copyWith(
            color: colors.onSurface,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // Deconstructor cards (if available)
        if (lookup.hasDeconstructor) ...[
          _buildDeconstructorSection(colors, lookup),
          const SizedBox(height: 16),
        ],

        // Headwords HTML
        if (lookup.hasHeadwords)
          ...lookup.headwords.map((hw) {
            return _HeadwordHtmlCard(
              headword: hw,
              colors: colors,
              onWordTap: _selectWord,
            );
          }),
        const SizedBox(height: AppDimensions.md),

        const Divider(height: 1),
        const SizedBox(height: AppDimensions.md),
      ],
    );
  }

  Widget _buildDeconstructorSection(ColorScheme colors, DpdFullLookup lookup) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.call_split, size: 16, color: colors.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              'Compound breakdown',
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Deconstructor candidate cards
        ...lookup.deconstructionCandidates.asMap().entries.map((entry) {
          final idx = entry.key;
          final candidate = entry.value;
          final isActive = idx == _activeDeconCardIndex;

          return GestureDetector(
            onTap: () {
              setState(() {
                _activeDeconCardIndex = idx;
                _activeDeconTabIndex = 0;
              });
              _lookupDeconTokens(candidate);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? colors.primaryContainer.withValues(alpha: 0.3)
                    : colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive ? colors.primary : colors.outlineVariant.withValues(alpha: 0.3),
                  width: isActive ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Candidate header with word chips
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: candidate.tokens.map((token) {
                        return ActionChip(
                          label: Text(token),
                          labelStyle: AppTypography.bodyTranslation.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                          backgroundColor: colors.primary.withValues(alpha: 0.08),
                          side: BorderSide(
                            color: colors.primary.withValues(alpha: 0.2),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          onPressed: () => _selectWord(token),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Expanded detail tabs for active card
                  if (isActive) ...[
                    _buildDeconTabs(colors, candidate, lookup),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDeconTabs(
    ColorScheme colors,
    DeconstructionCandidate candidate,
    DpdFullLookup lookup,
  ) {
    if (candidate.tokens.length <= 1) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab bar for tokens
        const Divider(height: 1),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            children: candidate.tokens.asMap().entries.map((entry) {
              final idx = entry.key;
              final token = entry.value;
              final isActive = idx == _activeDeconTabIndex;

              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _activeDeconTabIndex = idx);
                    _lookupDeconToken(token);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive
                          ? colors.primary.withValues(alpha: 0.15)
                          : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      token,
                      style: AppTypography.labelSmall.copyWith(
                        color: isActive ? colors.primary : colors.onSurfaceVariant,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Tab content: sub-lookup results for the active token
        if (candidate.tokens.isNotEmpty &&
            _activeDeconTabIndex < candidate.tokens.length)
          _buildTokenContent(colors, candidate.tokens[_activeDeconTabIndex]),
      ],
    );
  }

  Widget _buildTokenContent(ColorScheme colors, String token) {
    final cached = _subLookupCache[token];
    if (cached != null) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: cached.map((hw) {
            return _HeadwordHtmlCard(
              headword: hw,
              colors: colors,
              onWordTap: _selectWord,
              compact: true,
            );
          }).toList(),
        ),
      );
    }

    // Trigger async lookup
    _lookupDeconToken(token);
    return const Padding(
      padding: EdgeInsets.all(12),
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
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
        });
      }
    } catch (_) {}
  }

  Future<void> _lookupDeconTokens(DeconstructionCandidate candidate) async {
    for (final token in candidate.tokens) {
      await _lookupDeconToken(token);
    }
  }

  // ── Other Dictionaries Section ───────────────────────────────────────────

  List<Widget> _buildOtherDictionarySections(
    ColorScheme colors,
    String searchWord,
    List<DictionaryBook> enabledBooks,
  ) {
    // Filter out DPD (book_id=11) since it's shown separately from dpd-dictionary.db
    final otherBooks = enabledBooks.where((b) => b.id != 11).toList();
    if (otherBooks.isEmpty) return [];

    // Start fetching results for all other dictionaries
    return otherBooks.map((book) {
      return SliverToBoxAdapter(
        child: _OtherDictionarySection(
          book: book,
          searchWord: searchWord,
          colors: colors,
          onWordTap: _selectWord,
        ),
      );
    }).toList();
  }
}

// ── Search Result Card ──────────────────────────────────────────────────────

class _SearchResultCard extends StatelessWidget {
  final String lemma1;
  final String? meaningHtmlPreview;
  final VoidCallback onTap;
  final ColorScheme colors;

  const _SearchResultCard({
    required this.lemma1,
    this.meaningHtmlPreview,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    // Extract a plain-text preview from HTML
    final plainPreview = meaningHtmlPreview != null
        ? _stripHtml(meaningHtmlPreview!)
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: colors.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lemma1,
                      style: AppTypography.headlineSmall.copyWith(
                        color: colors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (plainPreview.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        plainPreview,
                        style: AppTypography.bodyTranslation.copyWith(
                          color: colors.onSurfaceVariant,
                          fontSize: 13,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colors.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

// ── Headword HTML Card ──────────────────────────────────────────────────────

class _HeadwordHtmlCard extends StatelessWidget {
  final DpdHeadwordRow headword;
  final ColorScheme colors;
  final ValueChanged<String> onWordTap;
  final bool compact;

  const _HeadwordHtmlCard({
    required this.headword,
    required this.colors,
    required this.onWordTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final html = headword.meaningHtml;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(compact ? 8 : 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lemma with secondary number
          Text(
            headword.lemma1,
            style: TextStyle(
              fontSize: compact ? 14 : 16,
              fontWeight: FontWeight.w600,
              color: colors.primary,
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 6),
          // HTML content rendered as plain text with HTML-like formatting
          if (html != null && html.isNotEmpty)
            _HtmlRichText(
              html: html,
              baseStyle: TextStyle(
                fontSize: compact ? 13 : 14,
                height: 1.5,
                color: colors.onSurface,
                fontFamily: 'Georgia',
              ),
              linkColor: colors.primary,
              onWordTap: onWordTap,
            )
          else
            Text(
              'No definition available',
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: colors.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

// ── HTML Rich Text Widget ──────────────────────────────────────────────────

/// Renders simple HTML content (details/summary, b, i, divs) as rich text
/// with tappable word links.
class _HtmlRichText extends StatelessWidget {
  final String html;
  final TextStyle baseStyle;
  final Color linkColor;
  final ValueChanged<String> onWordTap;

  const _HtmlRichText({
    required this.html,
    required this.baseStyle,
    required this.linkColor,
    required this.onWordTap,
  });

  @override
  Widget build(BuildContext context) {
    // Parse the HTML into segments
    final segments = _parseHtml(html);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: segments.map((segment) {
        if (segment is _HtmlText) {
          return _buildTextSegment(segment);
        } else if (segment is _HtmlLinkList) {
          return _buildLinkList(segment);
        }
        return const SizedBox.shrink();
      }).toList(),
    );
  }

  Widget _buildTextSegment(_HtmlText seg) {
    final spans = <TextSpan>[];

    // Split by words to find Pāli words (which should be tappable)
    final words = seg.text.split(RegExp(r'(\s+)'));
    for (final word in words) {
      if (word.trim().isEmpty) {
        spans.add(TextSpan(text: word));
      } else if (seg.boldWords.any((bw) => word.contains(bw))) {
        spans.add(TextSpan(
          text: word,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ));
      } else {
        spans.add(TextSpan(text: word));
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: RichText(
        text: TextSpan(
          style: _mergeStyles(seg.style, baseStyle),
          children: spans,
        ),
      ),
    );
  }

  Widget _buildLinkList(_HtmlLinkList seg) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: seg.words.map((word) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: GestureDetector(
              onTap: () => onWordTap(word),
              child: Text(
                word,
                style: baseStyle.copyWith(
                  color: linkColor,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  TextStyle _mergeStyles(TextStyle? override, TextStyle base) {
    if (override == null) return base;
    return base.merge(override);
  }

  List<dynamic> _parseHtml(String html) {
    final segments = <dynamic>[];
    // Remove the outer <details> wrapper if present
    String content = html;

    // Extract text from <summary> tags
    final summaryMatch = RegExp(r'<summary>(.*?)</summary>', dotAll: true).firstMatch(content);
    if (summaryMatch != null) {
      final summaryText = _stripAllTags(summaryMatch.group(1)!);
      segments.add(_HtmlText(summaryText, const TextStyle(fontWeight: FontWeight.bold), []));
      content = content.substring(summaryMatch.end);
    }

    // Extract detail div content
    final detailMatch = RegExp(r'<div class="dpd-meaning-detail">(.*?)</div>', dotAll: true).firstMatch(content);
    if (detailMatch != null) {
      final detail = detailMatch.group(1)!;
      // Parse grammar lines
      final grammarMatch = RegExp(r'<b>Grammar:</b>\s*(.*?)(?:</div>|<br)').firstMatch(detail);
      if (grammarMatch != null) {
        segments.add(_HtmlText(
          'Grammar: ${_stripAllTags(grammarMatch.group(1)!)}',
          TextStyle(color: baseStyle.color?.withValues(alpha: 0.7), fontSize: baseStyle.fontSize! - 1),
          [],
        ));
      }

      // Parse Sanskrit
      final sanskritMatch = RegExp(r'<b>Sanskrit:</b>\s*(.*?)(?:</div>|<br)').firstMatch(detail);
      if (sanskritMatch != null) {
        segments.add(_HtmlText(
          'Skt: ${_stripAllTags(sanskritMatch.group(1)!)}',
          TextStyle(color: baseStyle.color?.withValues(alpha: 0.7), fontSize: baseStyle.fontSize! - 1),
          [],
        ));
      }

      // Parse example
      final exampleMatch = RegExp(r'<b>Example:</b>\s*(.*?)(?:</div>|$)').firstMatch(detail);
      if (exampleMatch != null) {
        final exampleText = _stripAllTags(exampleMatch.group(1)!);
        segments.add(const SizedBox(height: 4));
        segments.add(_HtmlText(
          exampleText,
          TextStyle(fontStyle: FontStyle.italic, fontSize: baseStyle.fontSize! - 1),
          [],
        ));
      }

      // Extract remaining plain text
      final remaining = detail
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (remaining.isNotEmpty && segments.length <= 3) {
        segments.add(_HtmlText(
          remaining,
          baseStyle,
          [],
        ));
      }
    }

    return segments;
  }

  String _stripAllTags(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }
}

class _HtmlText {
  final String text;
  final TextStyle? style;
  final List<String> boldWords;

  const _HtmlText(this.text, this.style, this.boldWords);
}

class _HtmlLinkList {
  final List<String> words;

  const _HtmlLinkList(this.words);
}

// ── Cached dictionary definitions provider ───────────────────────────────────

/// Cache key for dictionary definitions.
class _DictLookupKey {
  final int bookId;
  final String word;
  const _DictLookupKey(this.bookId, this.word);

  @override
  bool operator ==(Object other) =>
      other is _DictLookupKey && bookId == other.bookId && word == other.word;

  @override
  int get hashCode => Object.hash(bookId, word);
}

/// Provider that caches dictionary definitions from epitaka.dictionary.
final _dictionaryDefinitionProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, _DictLookupKey>((ref, key) async {
  try {
    final db = await ref.read(epitakaDbProvider.future);
    final rows = await db.customSelect(
      'SELECT definition FROM dictionary WHERE word = ? AND book_id = ? LIMIT 5',
      variables: [
        Variable.withString(key.word.toLowerCase()),
        Variable.withInt(key.bookId),
      ],
    ).get();
    return rows.map((r) => r.data).toList();
  } catch (_) {
    return [];
  }
});

// ── Other Dictionary Section ───────────────────────────────────────────────

/// A section showing results from a single dictionary book in epitaka.dictionary.
class _OtherDictionarySection extends ConsumerWidget {
  final DictionaryBook book;
  final String searchWord;
  final ColorScheme colors;
  final ValueChanged<String> onWordTap;

  const _OtherDictionarySection({
    required this.book,
    required this.searchWord,
    required this.colors,
    required this.onWordTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = _DictLookupKey(book.id, searchWord);
    final defsAsync = ref.watch(_dictionaryDefinitionProvider(key));

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.marginMobile,
        0,
        AppDimensions.marginMobile,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Book name header
          Row(
            children: [
              Icon(Icons.book, size: 18, color: colors.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                book.name,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          defsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, _) => Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'No entry found',
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            data: (definitions) {
              if (definitions.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'No entry found',
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...definitions.map((def) {
                    final definition = def['definition'] as String? ?? '';
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colors.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: _DictionaryHtmlContent(
                        html: definition,
                        baseStyle: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: colors.onSurface,
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),

          const SizedBox(height: AppDimensions.md),
          const Divider(height: 1),
          const SizedBox(height: AppDimensions.md),
        ],
      ),
    );
  }
}

// ── Dictionary HTML Content ─────────────────────────────────────────────────

/// Renders HTML content from epitaka.dictionary definitions.
class _DictionaryHtmlContent extends StatelessWidget {
  final String html;
  final TextStyle baseStyle;

  const _DictionaryHtmlContent({
    required this.html,
    required this.baseStyle,
  });

  @override
  Widget build(BuildContext context) {
    // Strip HTML tags and render as plain text with basic formatting
    final text = _stripHtml(html);
    return Text(
      text,
      style: baseStyle,
    );
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
