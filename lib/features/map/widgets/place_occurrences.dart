import 'dart:math' as math;

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_models.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../shared/services/paragraph_preview_loader.dart';
import '../../../shared/utils/app_navigation.dart';
import '../../../shared/widgets/paragraph_preview_sheet.dart';
import '../../reader/providers/reader_tabs_provider.dart';
import '../../search/providers/search_provider.dart';
import '../../search/widgets/search_results_view.dart';
import '../../search/widgets/search_row_list.dart';
import '../models/map_data.dart';
import '../services/place_text_stats.dart';

/// The paragraphs that name one name, grouped by book exactly like a search
/// result: each book is a collapsible card, and opening it shows the matching
/// paragraphs with the same tiles, highlighting and `<b>`/`<i>` support the
/// search screen uses.
///
/// The counts come from [PlaceTextStats]; the paragraph text is loaded only
/// for a book the user opens, one page at a time, so a name mentioned
/// thousands of times stays responsive.
class PlaceOccurrences extends ConsumerStatefulWidget {
  const PlaceOccurrences({required this.name, required this.stats, super.key});

  final MapName name;
  final PlaceTextStats stats;

  @override
  ConsumerState<PlaceOccurrences> createState() => _PlaceOccurrencesState();
}

class _PlaceOccurrencesState extends ConsumerState<PlaceOccurrences> {
  static const int _pageSize = 20;
  static const int _queryChunk = 400;

  late final List<PlaceBookCount> _books;
  final Map<String, List<SearchResultItem>> _items = {};
  final Map<String, int> _consumed = {};
  final Set<String> _expanded = {};
  final Set<String> _loading = {};

  String get _query => widget.name.forms.isNotEmpty
      ? widget.name.forms.join(' ')
      : widget.name.name;

  @override
  void initState() {
    super.initState();
    _books = [...widget.stats.books];
  }

  int _consumedFor(String bookId) => _consumed[bookId] ?? 0;

  void _toggleBook(PlaceBookCount book) {
    final bookId = book.bookId;
    final expanding = !_expanded.contains(bookId);
    setState(() {
      if (expanding) {
        _expanded.add(bookId);
      } else {
        _expanded.remove(bookId);
      }
    });
    if (expanding && _items[bookId] == null) _loadMore(book);
  }

  Future<void> _loadMore(PlaceBookCount book) async {
    final bookId = book.bookId;
    if (_loading.contains(bookId)) return;
    final start = _consumedFor(bookId);
    if (start >= book.paraIds.length) return;
    final end = math.min(start + _pageSize, book.paraIds.length);
    setState(() => _loading.add(bookId));

    final ids = book.paraIds.sublist(start, end);
    final pali = <int, List<(int, String)>>{};
    final translations = <String, String>{};
    try {
      final db = await ref.read(epitakaDbProvider.future);
      for (final chunk in _chunks(ids)) {
        final placeholders = List.filled(chunk.length, '?').join(',');
        final rows = await db
            .customSelect(
              'SELECT para_id, line_id, pali FROM sentences '
              'WHERE book_id = ? AND para_id IN ($placeholders) '
              'ORDER BY para_id, line_id',
              variables: [
                Variable.withString(bookId),
                for (final id in chunk) Variable.withInt(id),
              ],
            )
            .get();
        for (final row in rows) {
          final text = row.readNullable<String>('pali') ?? '';
          if (text.isEmpty) continue;
          (pali[row.read<int>('para_id')] ??= []).add((
            row.read<int>('line_id'),
            text,
          ));
        }
      }

      final langs = ref.read(settingsProvider).visibleTranslationLangs;
      for (final lang in langs) {
        try {
          final transDb = await ref.read(translationDbProvider(lang).future);
          if (transDb == null) continue;
          for (final chunk in _chunks(ids)) {
            final placeholders = List.filled(chunk.length, '?').join(',');
            final rows = await transDb
                .customSelect(
                  'SELECT para_id, line_id, translation FROM sentences '
                  'WHERE book_id = ? AND para_id IN ($placeholders) '
                  'ORDER BY para_id, line_id',
                  variables: [
                    Variable.withString(bookId),
                    for (final id in chunk) Variable.withInt(id),
                  ],
                )
                .get();
            for (final row in rows) {
              final text = row.readNullable<String>('translation') ?? '';
              if (text.isEmpty) continue;
              translations.putIfAbsent(
                '${row.read<int>('para_id')}:${row.read<int>('line_id')}',
                () => text,
              );
            }
          }
        } catch (_) {
          // A missing or broken translation database must not hide the Pāli.
        }
      }
    } catch (_) {
      // Mark the page done below so the spinner does not stay forever; the
      // caller can retry by collapsing and reopening the book.
    }

    if (!mounted) return;
    final loaded = <SearchResultItem>[
      for (final paraId in ids)
        if (pali[paraId] != null)
          SearchResultItem(
            bookId: bookId,
            paraId: paraId,
            showAllLines: true,
            lines: [
              for (final (lineId, text) in pali[paraId]!)
                SearchResultLine(
                  lineId: lineId,
                  pali: text,
                  translation: translations['$paraId:$lineId'],
                ),
            ],
          ),
    ];
    setState(() {
      _items[bookId] = [...?_items[bookId], ...loaded];
      _consumed[bookId] = end;
      _loading.remove(bookId);
    });
  }

  static Iterable<List<int>> _chunks(List<int> ids) sync* {
    for (var i = 0; i < ids.length; i += _queryChunk) {
      yield ids.sublist(i, math.min(i + _queryChunk, ids.length));
    }
  }

  void _openReader(PlaceBookCount book, SearchResultItem item) {
    ref
        .read(readerTabsProvider.notifier)
        .openTab(
          ReaderTabInfo(
            bookId: item.bookId,
            bookName: book.name,
            initialParaId: item.paraId,
            searchQuery: _query,
            searchQueryFuzzy: false,
          ),
        );
    openReaderRoute(context);
  }

  Future<void> _openPreview(PlaceBookCount book, SearchResultItem item) async {
    final loc = AppLocalizations.of(context);
    final preview = await loadParagraphPreview(
      ref,
      bookId: item.bookId,
      paraId: item.paraId,
      maxLinesBefore: 3,
      maxLinesAfter: 6,
    );
    if (!mounted) return;

    await showParagraphPreviewSheet(
      context,
      title: book.name,
      subtitle: widget.name.name,
      lines: preview.lines,
      highlightParaId: item.paraId,
      actionLabel: loc.openInReader,
      onAction: (paraId, lineId) {
        ref
            .read(readerTabsProvider.notifier)
            .openTab(
              ReaderTabInfo(
                bookId: item.bookId,
                bookName: book.name,
                initialParaId: paraId,
                initialLineId: lineId,
                searchQuery: _query,
                searchQueryFuzzy: false,
              ),
            );
        Navigator.of(context).pop();
        openReaderRoute(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (_books.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          loc.t('This name was not found in the Pāli text.'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final book in _books) _buildBook(context, book, colors, loc),
      ],
    );
  }

  Widget _buildBook(
    BuildContext context,
    PlaceBookCount book,
    ColorScheme colors,
    AppLocalizations loc,
  ) {
    final bookId = book.bookId;
    final items = _items[bookId] ?? const <SearchResultItem>[];
    final expanded = _expanded.contains(bookId);
    final loading = _loading.contains(bookId);
    final summary = BookResultSummary(
      book: BookInfo(
        id: 0,
        bookId: bookId,
        bookName: book.name,
        category: book.category.isEmpty ? null : book.category,
        nikaya: book.nikaya.isEmpty ? null : book.nikaya,
      ),
      totalCount: book.paragraphs,
      isExpanded: expanded,
      loadedPages: [items],
    );
    final consumed = _consumedFor(bookId);
    final remaining = book.paragraphs - consumed;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: BookCardSlice(
        isFirst: true,
        isLast: true,
        radius: AppDimensions.radiusMd,
        colors: colors,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SearchBookHeader(
              summary: summary,
              colors: colors,
              onToggleExpanded: () => _toggleBook(book),
            ),
            if (expanded) ...[
              const Divider(height: 1, indent: 12, endIndent: 12),
              if (loading && items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        loc.t('Scanning the texts…'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                )
              else ...[
                for (final item in items)
                  GroupRowHighlight(
                    selected: false,
                    colors: colors,
                    child: SearchResultItemView(
                      item: item,
                      colors: colors,
                      query: _query,
                      fuzzy: false,
                      onTap: () => _openReader(book, item),
                      onLongPress: () => _openPreview(book, item),
                    ),
                  ),
                if (remaining > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Center(
                      child: TextButton.icon(
                        onPressed: loading ? null : () => _loadMore(book),
                        icon: loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.expand_more, size: 18),
                        label: Text(
                          '${loc.t('Show more')} ($remaining ${loc.t('remaining')})',
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
