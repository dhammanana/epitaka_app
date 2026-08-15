import 'dart:async';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_models.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/pali_search_utils.dart';
import '../../../core/utils/responsive_breakpoint.dart';
import '../../../core/utils/pali_script_converter.dart';
import '../../../core/utils/pali_text_utils.dart';
import '../../../shared/utils/app_navigation.dart';
import '../../../shared/utils/html_text_parser.dart';
import '../../../shared/widgets/pali_text.dart';
import '../../../shared/widgets/paragraph_preview_sheet.dart';
import '../../../shared/widgets/preview_content.dart';
import '../../reader/providers/reader_tabs_provider.dart';
import '../providers/search_provider.dart';
import 'search_result_highlight.dart';
import 'search_results_navigator.dart';

/// Phone-only horizontal padding budget for one search result line.
///
/// On phones the Pāli snippet must end up exactly 5px from each screen
/// edge (10px total), split across the nested layers as
/// 0 (list) + 2 (tile) + 3 (line). Desktop/tablet keep their own wider
/// margins and ignore these.
const double _phoneListHPad = 10;
const double _phoneTileHPad = 3;
const double _phoneLineHPad = 10;

/// The shared results list for a completed [SearchResults] state.
///
/// Used by both the full-page Search screen and the Gavesana AI search
/// screen, so AI-found passages render exactly like normal FTS results
/// (book cards, expand/collapse, tap-to-open, long-press preview).
///
/// Supports keyboard navigation (j/k + Enter) when [resultsFocusNode] is
/// provided by the parent (or via an internal node): the list is wrapped in
/// a [Focus] that consumes j/k/arrows/Enter/Escape.
class SearchResultsView extends ConsumerStatefulWidget {
  final SearchResults state;

  /// Optional external focus node for the results list; when the parent
  /// provides one it can move focus here after a search executes.
  final FocusNode? resultsFocusNode;

  /// Called when Esc is pressed in the results (parent usually refocuses
  /// its search field).
  final VoidCallback? onEscape;

  const SearchResultsView({
    super.key,
    required this.state,
    this.resultsFocusNode,
    this.onEscape,
  });

  @override
  ConsumerState<SearchResultsView> createState() =>
      _SearchResultsViewState();
}

class _SearchResultsViewState extends ConsumerState<SearchResultsView> {
  final SearchResultsNavigator _searchNav = SearchResultsNavigator();
  final GlobalKey _selectedRowKey = GlobalKey();
  final FocusNode _internalFocusNode = FocusNode();
  SearchResults? _lastNavState;
  SearchResultRow? _lastSelectedRow;

  @override
  void initState() {
    super.initState();
    _searchNav.addListener(_onNavChanged);
  }

  @override
  void dispose() {
    _searchNav.removeListener(_onNavChanged);
    _internalFocusNode.dispose();
    super.dispose();
  }

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

  void _syncNavigator() {
    if (!identical(widget.state, _lastNavState)) {
      _lastNavState = widget.state;
      _searchNav.rebuild(widget.state);
    }
  }

  void _activateSelectedRow() {
    final row = _searchNav.selectedRow;
    if (row == null) return;
    switch (row.kind) {
      case SearchRowKind.headingCard:
        final headings = row.headings;
        if (headings != null && headings.isNotEmpty) {
          _onHeadingResultTap(context, ref, headings.first);
        }
      case SearchRowKind.bookHeader:
        final notifier = ref.read(searchProvider.notifier);
        if (row.summary!.isExpanded) {
          notifier.collapseBook(row.summaryIndex);
        } else {
          notifier.expandBook(row.summaryIndex);
        }
      case SearchRowKind.resultItem:
        _onResultTap(context, ref, row.summary!, row.item!);
      case SearchRowKind.loadMore:
        ref.read(searchProvider.notifier).loadMoreForBook(row.summaryIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncNavigator();
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final state = widget.state;

    if (state.bookSummaries.isEmpty && state.headings.isEmpty) {
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
              loc.noResultsForQuery(state.query),
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final focusNode = widget.resultsFocusNode ?? _internalFocusNode;
    final rows = _searchNav.rows;

    // On phones the result cards go edge-to-edge (no outer screen margin)
    // so the long snippet lines get as much width as possible. Together
    // with the tile paddings below the Pāli text ends up 5px from each
    // screen edge (10px total, see _phoneListHPad). Desktop keeps the
    // wider margins.
    final isPhone = ResponsiveBreakpoint.isPhone(context);
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) => handleSearchNavKey(
        event,
        _searchNav,
        onActivate: _activateSelectedRow,
        onEscape: () => widget.onEscape?.call(),
      ),
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          isPhone ? _phoneListHPad : AppDimensions.marginMobile,
          AppDimensions.sm,
          isPhone ? _phoneListHPad : AppDimensions.marginMobile,
          AppDimensions.bottomToolbarHeight + AppDimensions.lg,
        ),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          final isSelected = index == _searchNav.selected;
          final Widget child = switch (row.kind) {
            SearchRowKind.headingCard => _HeadingResultsCard(
              headings: row.headings!,
              colors: colors,
              onTap: (heading) =>
                  _onHeadingResultTap(context, ref, heading),
            ),
            SearchRowKind.bookHeader => _BookResultHeader(
              summary: row.summary!,
              colors: colors,
              onToggleExpanded: () {
                final notifier = ref.read(searchProvider.notifier);
                if (row.summary!.isExpanded) {
                  notifier.collapseBook(row.summaryIndex);
                } else {
                  notifier.expandBook(row.summaryIndex);
                }
              },
            ),
            SearchRowKind.resultItem => _SearchResultItemTile(
              item: row.item!,
              colors: colors,
              onTap: () => _onResultTap(context, ref, row.summary!, row.item!),
              onLongPress: () => _onResultLongPress(
                context,
                ref,
                row.summary!,
                row.item!,
              ),
            ),
            SearchRowKind.loadMore => SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => ref
                    .read(searchProvider.notifier)
                    .loadMoreForBook(row.summaryIndex),
                icon: const Icon(Icons.expand_more, size: 18),
                label: Text(
                  '${loc.showMore} (${row.summary!.totalCount - row.summary!.loadedCount} ${loc.remaining})',
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.primary,
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
      ),
    );
  }

  // ── Tap handlers (shared with the full search screen) ────────────────

  void _onResultTap(
    BuildContext context,
    WidgetRef ref,
    BookResultSummary summary,
    SearchResultItem item,
  ) {
    final query = widget.state.query;

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

    ref.read(readerTabsProvider.notifier).openTab(
          ReaderTabInfo(
            bookId: item.bookId,
            bookName: summary.book.bookName ?? item.bookId,
            initialParaId: item.paraId,
            initialLineId: initialLineId,
            searchQuery: query,
          ),
        );
    openReaderRoute(context);
  }

  void _onHeadingResultTap(
    BuildContext context,
    WidgetRef ref,
    HeadingResult heading,
  ) {
    ref.read(readerTabsProvider.notifier).openTab(
          ReaderTabInfo(
            bookId: heading.bookId,
            bookName: heading.bookName ?? heading.bookId,
            initialParaId: heading.paraId,
            searchQuery: widget.state.query,
          ),
        );
    openReaderRoute(context);
  }

  void _onResultLongPress(
    BuildContext context,
    WidgetRef ref,
    BookResultSummary summary,
    SearchResultItem item,
  ) {
    _showResultPreviewDialog(context, ref, summary, item);
  }

  Future<void> _showResultPreviewDialog(
    BuildContext context,
    WidgetRef ref,
    BookResultSummary summary,
    SearchResultItem item,
  ) async {
    final loc = AppLocalizations.of(context);
    HapticFeedback.mediumImpact();

    final searchQuery = widget.state.query;

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
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(loc.noHeadingFound)));
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
          final transDb = await ref.read(
            translationDbProvider(activeLang).future,
          );
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

      // The line holding the match — the quickview scrolls here and
      // highlights exactly this line (not the whole paragraph).
      final firstMatchLine = item.lines.isNotEmpty
          ? item.lines.firstWhere(
              (l) => l.isMatch,
              orElse: () => item.lines.first,
            )
          : null;
      // Find the snippet line index: prefer the matched line itself so the
      // visible <mark>-highlighted snippet sits on the highlighted line.
      final firstSnippetIndex = firstMatchLine == null
          ? previewLines.indexWhere((l) => l.paraId == item.paraId)
          : previewLines.indexWhere(
              (l) =>
                  l.paraId == item.paraId && l.lineId == firstMatchLine.lineId,
            );

      if (!context.mounted) return;

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
        highlightLineId: firstMatchLine?.lineId,
        scrollToParaId: item.paraId,
        scrollToLineId: firstMatchLine?.lineId,
        firstSnippetIndex: firstSnippetIndex >= 0 ? firstSnippetIndex : null,
        paliSnippet: item.lines.isNotEmpty
            ? item.lines.where((l) => l.isMatch).map((l) => l.pali).join(' ')
            : '',
        actionLabel: loc.openInReader,
        // Open the reader at where the user stopped reading in the sheet,
        // not the original match line.
        onAction: (currentParaId, currentLineId) {
          // Open the reader tab
          ref.read(readerTabsProvider.notifier).openTab(
                ReaderTabInfo(
                  bookId: item.bookId,
                  bookName: summary.book.bookName ?? item.bookId,
                  initialParaId: currentParaId,
                  initialLineId: currentLineId,
                  searchQuery: searchQuery,
                ),
              );
          Navigator.of(context).pop();
          openReaderRoute(context);
        },
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.failedToLoadPreview} $e')),
        );
      }
    }
  }
}

// ── Book Result Header (collapsible row) ──────────────────────────────

class _BookResultHeader extends ConsumerWidget {
  final BookResultSummary summary;
  final ColorScheme colors;
  final VoidCallback onToggleExpanded;

  const _BookResultHeader({
    required this.summary,
    required this.colors,
    required this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final script = ref.watch(settingsProvider).paliScript;
    final displayName = _displayBookName(summary.book);
    final subtitleStyle = AppTypography.labelSmall.copyWith(
      color: colors.onSurfaceVariant,
      fontSize: 10,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
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
                        // Book names are Pāli — render them in the user's
                        // script with the script font, like the library.
                        PaliTextStatic(
                          displayName,
                          script,
                          style: AppTypography.labelMedium.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Convert each Pāli name separately so the '·'
                        // separator stays plain text (it has no glyph in the
                        // script fonts and must not be run through the
                        // converter).
                        if (summary.book.nikaya != null ||
                            summary.book.category != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (summary.book.nikaya != null)
                                PaliTextStatic(
                                  summary.book.nikaya!,
                                  script,
                                  style: subtitleStyle,
                                  maxLines: 1,
                                ),
                              if (summary.book.nikaya != null &&
                                  summary.book.category != null)
                                Text(' · ', style: subtitleStyle),
                              if (summary.book.category != null)
                                PaliTextStatic(
                                  summary.book.category!,
                                  script,
                                  style: subtitleStyle,
                                  maxLines: 1,
                                ),
                            ],
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
    );
  }

  String _displayBookName(BookInfo book) {
    return book.displayName;
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
        borderRadius: BorderRadius.circular(8),
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

// ── Heading Results Card ──────────────────────────────────────────────────

class _HeadingResultsCard extends ConsumerWidget {
  final List<HeadingResult> headings;
  final ColorScheme colors;
  final void Function(HeadingResult heading) onTap;

  const _HeadingResultsCard({
    required this.headings,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final script = ref.watch(settingsProvider).paliScript;
    final loc = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      elevation: 0,
      color: colors.tertiaryContainer.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        side: BorderSide(color: colors.tertiary.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.md,
              10,
              AppDimensions.md,
              6,
            ),
            child: Row(
              children: [
                Icon(Icons.toc, size: 16, color: colors.tertiary),
                const SizedBox(width: 8),
                Text(
                  loc.sectionHeadings,
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.tertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    loc.headingsFound(headings.length),
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
          ...headings.map(
            (heading) => InkWell(
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
                          // Heading titles and book names are Pāli — render
                          // them in the user's script, like the reader does.
                          PaliTextStatic(
                            heading.title,
                            script,
                            style: AppTypography.labelMedium.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (heading.bookName != null &&
                              heading.bookName!.isNotEmpty)
                            PaliTextStatic(
                              heading.bookName!,
                              script,
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
            ),
          ),
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
      searchTerms = normalizePaliFuzzy(
        query,
      ).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    } else {
      searchTerms = const [];
    }

    // Get typography for Pali
    final paliTypo = settings.typography.pali;
    final paliTextStyle = paliTypo.toTextStyle(fallbackColor: colors.onSurface);

    // Get typography for translation
    final transTypo = activeLang != null
        ? settings.typography.typographyFor(activeLang)
        : null;
    final transTextStyle =
        transTypo?.toTextStyle(
          fallbackColor: colors.onSurfaceVariant.withValues(alpha: 0.8),
        ) ??
        TextStyle(
          fontSize: 12,
          color: colors.onSurfaceVariant.withValues(alpha: 0.8),
          fontStyle: FontStyle.italic,
          height: 1.3,
        );

    // AI-found results (showAllLines) display every line even when none of
    // the original query terms match — the whole passage is relevant.
    final matchingLines = item.showAllLines
        ? item.lines
        : item.lines.where((l) => l.isMatch).toList();
    if (matchingLines.isEmpty) return const SizedBox.shrink();

    // Raw Roman query (before fuzzy normalization), used to re-convert the
    // Pāli snippet terms into the display script for highlighting.
    final rawQuery = searchState is SearchResults ? searchState.query : '';

    final isPhone = ResponsiveBreakpoint.isPhone(context);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        // 5px per side on phones: 0 (list) + 2 (tile) + 3 (line).
        padding: EdgeInsets.fromLTRB(
          isPhone ? _phoneTileHPad : AppDimensions.md,
          8,
          isPhone ? _phoneTileHPad : AppDimensions.md,
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
                  if (!item.showAllLines &&
                      matchingLines.length < item.lines.length)
                    Text(
                      '${matchingLines.length}/${item.lines.length} matches',
                      style: AppTypography.labelSmall.copyWith(
                        fontSize: 9,
                        color: colors.primary.withValues(alpha: 0.7),
                      ),
                    ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),

            // ── Matching lines with Pali + Translation ──────────────
            ...matchingLines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: _LineTile(
                  line: line,
                  searchTerms: searchTerms,
                  query: rawQuery,
                  paliTextStyle: paliTextStyle,
                  transTextStyle: transTextStyle,
                  colors: colors,
                  script: script,
                ),
              ),
            ),
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

  /// The raw (Roman) search query, used to convert the Pāli snippet terms
  /// into the display script for highlighting.
  final String query;

  final TextStyle paliTextStyle;
  final TextStyle transTextStyle;
  final ColorScheme colors;
  final Script script;

  const _LineTile({
    required this.line,
    required this.searchTerms,
    required this.query,
    required this.paliTextStyle,
    required this.transTextStyle,
    required this.colors,
    required this.script,
  });

  @override
  Widget build(BuildContext context) {
    final highlightColor = colors.primary.withValues(alpha: 0.25);

    // 5px per side on phones: 0 (list) + 2 (tile) + 3 (this line).
    final isPhone = ResponsiveBreakpoint.isPhone(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isPhone ? _phoneLineHPad : 8,
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
              query: query,
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
    required String query,
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

    // The snippet text is converted to the display script, so the terms
    // must be too — otherwise a Roman query never matches Tamil/Myanmar
    // text and the found word stays unhighlighted.
    final List<String> terms = script == Script.roman
        ? searchTerms
        : (normalizePaliFuzzy(
            convertSearchQueryForScript(query, script),
          ).split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList());

    final spans = buildSearchSnippetSpans(
      html: converted,
      baseStyle: effStyle,
      terms: terms.isEmpty ? searchTerms : terms,
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
