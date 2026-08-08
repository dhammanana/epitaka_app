import 'dart:async';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../../shared/utils/html_text_parser.dart';
import '../../../shared/widgets/pali_text.dart';
import '../../../shared/widgets/paragraph_preview_sheet.dart';
import '../../../shared/widgets/preview_content.dart';
import '../../reader/providers/reader_tabs_provider.dart';
import '../providers/search_provider.dart';
import 'search_result_highlight.dart';

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
class SearchResultsView extends ConsumerWidget {
  final SearchResults state;

  const SearchResultsView({super.key, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

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

    final totalItems =
        state.bookSummaries.length + (state.headings.isNotEmpty ? 1 : 0);

    // On phones the result cards go edge-to-edge (no outer screen margin)
    // so the long snippet lines get as much width as possible. Together
    // with the tile paddings below the Pāli text ends up 5px from each
    // screen edge (10px total, see _phoneListHPad). Desktop keeps the
    // wider margins.
    final isPhone = ResponsiveBreakpoint.isPhone(context);
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        isPhone ? _phoneListHPad : AppDimensions.marginMobile,
        AppDimensions.sm,
        isPhone ? _phoneListHPad : AppDimensions.marginMobile,
        AppDimensions.bottomToolbarHeight + AppDimensions.lg,
      ),
      itemCount: totalItems,
      itemBuilder: (context, index) {
        // Show heading results card first (if any)
        if (state.headings.isNotEmpty && index == 0) {
          return _HeadingResultsCard(
            headings: state.headings,
            colors: colors,
            onTap: (heading) => _onHeadingResultTap(context, ref, heading),
          );
        }

        // Then show book summary cards
        final summaryIndex = state.headings.isNotEmpty ? index - 1 : index;
        if (summaryIndex >= state.bookSummaries.length) {
          return const SizedBox.shrink();
        }

        final summary = state.bookSummaries[summaryIndex];
        return _BookResultCard(
          summary: summary,
          colors: colors,
          onTapResult: (item) => _onResultTap(context, ref, summary, item),
          onLongPressResult: (item) =>
              _onResultLongPress(context, ref, summary, item),
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

  // ── Tap handlers (shared with the full search screen) ────────────────

  void _onResultTap(
    BuildContext context,
    WidgetRef ref,
    BookResultSummary summary,
    SearchResultItem item,
  ) {
    final query = state.query;

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
    if (!ResponsiveBreakpoint.isDesktop(context)) {
      context.push('/reader');
    }
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
            searchQuery: state.query,
          ),
        );
    if (!ResponsiveBreakpoint.isDesktop(context)) {
      context.push('/reader');
    }
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

    final searchQuery = state.query;

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
      final targetLineKey = GlobalKey();

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
        targetLineKey: targetLineKey,
        firstSnippetIndex: firstSnippetIndex >= 0 ? firstSnippetIndex : null,
        paliSnippet: item.lines.isNotEmpty
            ? item.lines.where((l) => l.isMatch).map((l) => l.pali).join(' ')
            : '',
        actionLabel: loc.openInReader,
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
          ref.read(readerTabsProvider.notifier).openTab(
                ReaderTabInfo(
                  bookId: item.bookId,
                  bookName: summary.book.bookName ?? item.bookId,
                  initialParaId: item.paraId,
                  initialLineId: initialLineId,
                  searchQuery: searchQuery,
                ),
              );
          Navigator.of(context).pop();
          if (!ResponsiveBreakpoint.isDesktop(context)) {
            context.push('/reader');
          }
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

// ── Book Result Card ─────────────────────────────────────────────────────

class _BookResultCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
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
                      '${loc.showMore} (${summary.totalCount - summary.loadedCount} ${loc.remaining})',
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
