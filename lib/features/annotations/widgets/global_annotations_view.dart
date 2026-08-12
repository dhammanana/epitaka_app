// lib/features/annotations/widgets/global_annotations_view.dart
//
// A self-contained overview of ALL the user's annotations (highlights,
// notes, bookmarks) across every book. Used both by the full-screen
// AnnotationsScreen (mobile route) and the desktop sidebar's annotations
// panel, so the two share one implementation.
//
// Design highlights:
//   • Search field (case- and diacritic-insensitive).
//   • Filter chips with live per-type counts (All / Highlights / Notes /
//     Bookmarks).
//   • A book filter (toggle + chip panel) like the search screen.
//   • Annotations grouped by book; a group with more than 5 annotations
//     starts collapsed (tap the header to expand).
//   • Each card shows the quote with its highlight tint, note preview, and
//     location; tap to open in the reader, swipe to delete, long-press /
//     right-click / ⋮ for more actions (change color, edit note, delete).
//   • A "more colors" picker at the end of every color row reaches the full
//     extended palette.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/diacritics.dart';
import '../../../core/utils/pali_script_converter.dart';
import '../../../core/utils/responsive_breakpoint.dart';
import '../../../shared/widgets/pali_text.dart';
import '../../library/widgets/history_tabs.dart' show formatTimeAgo;
import '../../reader/providers/reader_tabs_provider.dart';
import '../models/annotation.dart';
import '../providers/annotations_provider.dart';
import 'highlight_palette.dart' show HighlightColorPickerSwatch;
import 'note_editor_sheet.dart';

/// Threshold above which a book group starts collapsed.
const int _kCollapseAfter = 5;

/// The reusable annotations overview (no app bar — the caller supplies
/// chrome). Suitable for a full screen or a desktop sidebar panel.
class GlobalAnnotationsView extends ConsumerStatefulWidget {
  const GlobalAnnotationsView({super.key});

  @override
  ConsumerState<GlobalAnnotationsView> createState() =>
      _GlobalAnnotationsViewState();
}

class _GlobalAnnotationsViewState extends ConsumerState<GlobalAnnotationsView> {
  /// Active type filter: null = all.
  AnnotationType? _filter;

  /// Book filter: empty = all books.
  final Set<String> _selectedBooks = {};
  bool _showBookFilters = false;

  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  /// Ids of cards already swiped away (see _AnnotationsListState).
  final Set<String> _dismissed = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final allAsync = ref.watch(allAnnotationsProvider);
    final all = allAsync.valueOrNull ?? const <Annotation>[];

    int countOf(AnnotationType t) => all.where((a) => a.type == t).length;

    return Column(
      children: [
        // ── Search field ───────────────────────────────────────────
        _SearchField(
          controller: _searchController,
          query: _query,
          onChanged: (v) => setState(() => _query = v),
          onClear: _clearSearch,
        ),
        // ── Filter chips (with live counts) + book-filter toggle ────
        _SummaryHeader(
          counts: {
            AnnotationType.highlight: countOf(AnnotationType.highlight),
            AnnotationType.note: countOf(AnnotationType.note),
            AnnotationType.bookmark: countOf(AnnotationType.bookmark),
          },
          total: all.length,
          filter: _filter,
          showBookFilters: _showBookFilters,
          selectedBookCount: _selectedBooks.length,
          onChanged: (t) => setState(() => _filter = t),
          onToggleBookFilters: () =>
              setState(() => _showBookFilters = !_showBookFilters),
        ),
        // ── Book filter panel ──────────────────────────────────────
        if (_showBookFilters)
          _BookFilterPanel(
            books: _bookOptions(all),
            selectedBooks: _selectedBooks,
            onToggle: (bookId) {
              setState(() {
                if (!_selectedBooks.remove(bookId)) _selectedBooks.add(bookId);
              });
            },
            onClear: () => setState(() => _selectedBooks.clear()),
          ),
        Expanded(
          child: _AnnotationsList(
            filter: _filter,
            query: _query,
            selectedBooks: _selectedBooks,
            dismissed: _dismissed,
            onClearSearch: _clearSearch,
            onClearBooks: () => setState(() => _selectedBooks.clear()),
          ),
        ),
      ],
    );
  }

  /// Books visible under the current search + type filter, in display
  /// order (bookId → best display name). Multi-select filter options.
  List<MapEntry<String, String>> _bookOptions(List<Annotation> all) {
    final options = <String, String>{};
    for (final a in all) {
      if (_query.isNotEmpty && !_annotationMatches(a, _query)) continue;
      if (_filter != null && a.type != _filter) continue;
      options.putIfAbsent(a.bookId, () => a.bookName ?? a.bookId);
    }
    return options.entries.toList();
  }
}

/// Case- and diacritic-insensitive match of [query] against an
/// annotation's quote text, note body, bookmark name, and book name/id.
bool _annotationMatches(Annotation a, String query) {
  final q = stripDiacritics(query.trim().toLowerCase());
  if (q.isEmpty) return true;
  bool hit(String? s) =>
      s != null && s.isNotEmpty && stripDiacritics(s.toLowerCase()).contains(q);
  return hit(a.exactText) ||
      hit(a.note) ||
      hit(a.name) ||
      hit(a.bookName) ||
      hit(a.bookId);
}

// ── Search field ────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.xs,
        AppDimensions.md,
        AppDimensions.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: AppTypography.bodyTranslation.copyWith(
          fontSize: 14,
          color: colors.onSurface,
        ),
        decoration: InputDecoration(
          hintText: loc.searchAnnotations,
          hintStyle: AppTypography.bodyTranslation.copyWith(
            fontSize: 13.5,
            color: colors.onSurfaceVariant.withValues(alpha: 0.7),
          ),
          prefixIcon: Icon(Icons.search, size: 18, color: colors.onSurfaceVariant),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  onPressed: onClear,
                  tooltip: loc.clearSearch,
                  icon: Icon(Icons.clear, size: 16, color: colors.onSurfaceVariant),
                ),
          isDense: true,
          filled: true,
          fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// ── Summary header + filter chips ───────────────────────────────────────

class _SummaryHeader extends StatelessWidget {
  final Map<AnnotationType, int> counts;
  final int total;
  final AnnotationType? filter;
  final bool showBookFilters;
  final int selectedBookCount;
  final ValueChanged<AnnotationType?> onChanged;
  final VoidCallback onToggleBookFilters;

  const _SummaryHeader({
    required this.counts,
    required this.total,
    required this.filter,
    required this.showBookFilters,
    required this.selectedBookCount,
    required this.onChanged,
    required this.onToggleBookFilters,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.sm,
        AppDimensions.md,
        AppDimensions.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: loc.allLabel,
              icon: Icons.apps,
              count: total,
              selected: filter == null,
              colors: colors,
              onTap: () => onChanged(null),
            ),
            const SizedBox(width: 6),
            _FilterChip(
              label: loc.highlights,
              icon: Icons.edit_note,
              count: counts[AnnotationType.highlight]!,
              selected: filter == AnnotationType.highlight,
              colors: colors,
              onTap: () => onChanged(AnnotationType.highlight),
            ),
            const SizedBox(width: 6),
            _FilterChip(
              label: loc.notesLabel,
              icon: Icons.sticky_note_2_outlined,
              count: counts[AnnotationType.note]!,
              selected: filter == AnnotationType.note,
              colors: colors,
              onTap: () => onChanged(AnnotationType.note),
            ),
            const SizedBox(width: 6),
            _FilterChip(
              label: loc.bookmarks,
              icon: Icons.bookmark_outline,
              count: counts[AnnotationType.bookmark]!,
              selected: filter == AnnotationType.bookmark,
              colors: colors,
              onTap: () => onChanged(AnnotationType.bookmark),
            ),
            const SizedBox(width: 8),
            // Book filter toggle
            Tooltip(
              message: loc.filterByBook,
              child: GestureDetector(
                onTap: onToggleBookFilters,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: showBookFilters || selectedBookCount > 0
                        ? colors.secondaryContainer
                        : colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                    border: Border.all(
                      color: showBookFilters || selectedBookCount > 0
                          ? colors.secondary.withValues(alpha: 0.5)
                          : colors.outlineVariant.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        showBookFilters || selectedBookCount > 0
                            ? Icons.filter_alt
                            : Icons.filter_alt_outlined,
                        size: 14,
                        color: showBookFilters || selectedBookCount > 0
                            ? colors.onSecondaryContainer
                            : colors.onSurfaceVariant,
                      ),
                      if (selectedBookCount > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '$selectedBookCount',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colors.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final int count;
  final bool selected;
  final ColorScheme colors;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.count,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? colors.primaryContainer
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          border: Border.all(
            color: selected
                ? colors.primary.withValues(alpha: 0.5)
                : colors.outlineVariant.withValues(alpha: 0.4),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected
                  ? colors.onPrimaryContainer
                  : colors.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected
                    ? colors.onPrimaryContainer
                    : colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? colors.primary.withValues(alpha: 0.15)
                    : colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: selected ? colors.onPrimaryContainer : colors.outline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Book filter panel ───────────────────────────────────────────────────

class _BookFilterPanel extends StatelessWidget {
  final List<MapEntry<String, String>> books;
  final Set<String> selectedBooks;
  final ValueChanged<String> onToggle;
  final VoidCallback onClear;

  const _BookFilterPanel({
    required this.books,
    required this.selectedBooks,
    required this.onToggle,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.sm,
        AppDimensions.md,
        0,
      ),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_outlined, size: 14, color: colors.secondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  loc.filterByBook,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 10.5,
                  ),
                ),
              ),
              if (selectedBooks.isNotEmpty)
                TextButton(
                  onPressed: onClear,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 28),
                  ),
                  child: Text(
                    loc.allBooks,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
          if (books.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                loc.noAnnotationsInBooks,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            )
          else
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final entry in books)
                  _BookChip(
                    label: entry.value,
                    selected: selectedBooks.contains(entry.key),
                    colors: colors,
                    onTap: () => onToggle(entry.key),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _BookChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ColorScheme colors;
  final VoidCallback onTap;

  const _BookChip({
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? colors.secondaryContainer
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? colors.secondary.withValues(alpha: 0.5)
                : colors.outlineVariant.withValues(alpha: 0.4),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check, size: 12, color: colors.onSecondaryContainer),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected
                    ? colors.onSecondaryContainer
                    : colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── The grouped list ───────────────────────────────────────────────────

class _AnnotationsList extends ConsumerStatefulWidget {
  final AnnotationType? filter;
  final String query;
  final Set<String> selectedBooks;
  final Set<String> dismissed;

  /// Clears the search field (offered from the search empty state).
  final VoidCallback? onClearSearch;

  /// Clears the book filter (offered from the book-filter empty state).
  final VoidCallback? onClearBooks;

  const _AnnotationsList({
    required this.filter,
    required this.query,
    required this.selectedBooks,
    required this.dismissed,
    this.onClearSearch,
    this.onClearBooks,
  });

  @override
  ConsumerState<_AnnotationsList> createState() => _AnnotationsListState();
}

class _AnnotationsListState extends ConsumerState<_AnnotationsList> {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final allAsync = ref.watch(allAnnotationsProvider);

    return allAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (e, _) => Center(
        child: Text(
          '${loc.errorLoadingAnnotations} $e',
          style: AppTypography.bodyTranslation.copyWith(color: colors.error),
          textAlign: TextAlign.center,
        ),
      ),
      data: (all) {
        // Search → type filter → book filter → swiped-away filter.
        final searched = widget.query.trim().isEmpty
            ? all
            : all.where((a) => _annotationMatches(a, widget.query)).toList();
        final byType = searched
            .where((a) => widget.filter == null || a.type == widget.filter)
            .toList();
        final byBook = widget.selectedBooks.isEmpty
            ? byType
            : byType
                  .where((a) => widget.selectedBooks.contains(a.bookId))
                  .toList();
        final filtered = byBook
            .where((a) => !widget.dismissed.contains(a.id))
            .toList();

        if (filtered.isEmpty) {
          return _EmptyState(
            filter: widget.filter,
            query: widget.query,
            isBookFiltered: widget.selectedBooks.isNotEmpty,
            colors: colors,
            loc: loc,
            onClearSearch: widget.onClearSearch,
            onClearBooks: widget.onClearBooks,
          );
        }

        // Group by book, preserving order (books are ordered by their most
        // recent annotation).
        final byBookMap = <String, List<Annotation>>{};
        for (final a in filtered) {
          (byBookMap[a.bookId] ??= []).add(a);
        }

        final script = ref.watch(settingsProvider).paliScript;

        return ListView(
          padding: const EdgeInsets.only(bottom: AppDimensions.xl),
          children: [
            for (final entry in byBookMap.entries)
              _BookSection(
                key: ValueKey('book-section-${entry.key}'),
                bookName: entry.value.first.bookName ?? entry.key,
                annotations: entry.value,
                script: script,
                onOpen: (a) => _openInReader(context, ref, a),
                onDelete: (a) => _requestDelete(context, ref, a),
                onSwipeDelete: (a) => _swipeDelete(context, ref, a),
                onLongPress: (a) => _showCardActions(context, ref, a),
              ),
          ],
        );
      },
    );
  }

  void _openInReader(BuildContext context, WidgetRef ref, Annotation a) {
    final paraId = a.paraId;
    if (paraId == null) return;
    ref.read(readerTabsProvider.notifier).openTab(
          ReaderTabInfo(
            bookId: a.bookId,
            bookName: a.bookName ?? a.bookId,
            initialParaId: paraId,
            initialLineId: a.lineId,
          ),
        );
    if (!ResponsiveBreakpoint.isDesktop(context)) {
      context.push('/reader');
    }
  }

  /// Confirmation dialog used by both the trash button and swipe-to-delete.
  Future<bool> _confirmDeleteDialog(BuildContext context, Annotation a) async {
    final loc = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.deleteAnnotation),
        content: Text(
          a.isBookmark
              ? loc.deleteAnnotationBookmarkMsg
              : loc.deleteAnnotationMsg,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: Text(loc.delete),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Soft-delete + snackbar. Runs after the Dismissible has confirmed (so
  /// the stream removes the card naturally) or after the dialog.
  Future<void> _deleteAndNotify(
    BuildContext context,
    WidgetRef ref,
    Annotation a,
  ) async {
    final loc = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = await ref.read(annotationRepositoryProvider.future);
      await repo.delete(a.id);
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(loc.removedLabel + a.displayLabel()),
            duration: const Duration(milliseconds: 1500),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      // A failed delete would leave the dismissed card dangling in the tree;
      // restore it and force a rebuild so it snaps back into place.
      setState(() => widget.dismissed.remove(a.id));
      ref.invalidate(allAnnotationsProvider);
    }
  }

  /// Trash-button entry point: confirm, then delete.
  Future<void> _requestDelete(
    BuildContext context,
    WidgetRef ref,
    Annotation a,
  ) async {
    if (await _confirmDeleteDialog(context, a) && context.mounted) {
      await _deleteAndNotify(context, ref, a);
    }
  }

  /// Swipe-to-delete: hide the card synchronously (so the dismissed
  /// Dismissible leaves the tree), then soft-delete. The stream reconciles
  /// once the DB write lands; a failure restores the card.
  Future<void> _swipeDelete(
    BuildContext context,
    WidgetRef ref,
    Annotation a,
  ) async {
    setState(() => widget.dismissed.add(a.id));
    await _deleteAndNotify(context, ref, a);
  }

  /// Long-press / ⋮ menu / right-click: show the action sheet.
  void _showCardActions(BuildContext context, WidgetRef ref, Annotation a) {
    final loc = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => _CardActionsSheet(
        annotation: a,
        loc: loc,
        onOpenReader: () {
          Navigator.of(sheetContext).pop();
          _openInReader(context, ref, a);
        },
        onChangeColor: (c) {
          Navigator.of(sheetContext).pop();
          _updateColor(context, ref, a, c);
        },
        onEditNote: () {
          Navigator.of(sheetContext).pop();
          _editNote(context, ref, a);
        },
        onDelete: () {
          Navigator.of(sheetContext).pop();
          _requestDelete(context, ref, a);
        },
      ),
    );
  }

  Future<void> _updateColor(
    BuildContext context,
    WidgetRef ref,
    Annotation a,
    HighlightColor color,
  ) async {
    if (color == a.color) return;
    final loc = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = await ref.read(annotationRepositoryProvider.future);
      await repo.update(a.copyWith(color: color));
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(loc.colorUpdated),
            duration: const Duration(milliseconds: 1200),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(loc.failedToSave('')),
            duration: const Duration(milliseconds: 1600),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _editNote(
    BuildContext context,
    WidgetRef ref,
    Annotation a,
  ) async {
    final loc = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await showNoteEditorSheet(
      context,
      initialNote: a.note ?? '',
      initialColor: a.color ?? HighlightColor.yellow,
    );
    if (result == null) return;
    try {
      final repo = await ref.read(annotationRepositoryProvider.future);
      // A highlight that gains a body becomes a note (matches the reader's
      // edit flow); clearing the body keeps it a plain highlight.
      final type = (result.note.isEmpty && a.isHighlight)
          ? AnnotationType.highlight
          : AnnotationType.note;
      await repo.update(
        a.copyWith(
          note: result.note.isEmpty ? null : result.note,
          color: result.color,
          type: type,
        ),
      );
    } catch (_) {
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(loc.failedToSave('')),
            duration: const Duration(milliseconds: 1600),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ── Collapsible book section ────────────────────────────────────────────

/// A book group: a tappable header + the annotation cards underneath.
/// Groups with more than [_kCollapseAfter] annotations start collapsed.
class _BookSection extends StatefulWidget {
  final String bookName;
  final List<Annotation> annotations;
  final Script script;
  final ValueChanged<Annotation> onOpen;

  /// Trash-button path: confirm first (handled here), then delete.
  final ValueChanged<Annotation> onDelete;

  /// Swipe path: delete directly (the confirm dialog already ran during
  /// the swipe via [confirmDismiss]).
  final ValueChanged<Annotation> onSwipeDelete;
  final ValueChanged<Annotation> onLongPress;

  const _BookSection({
    super.key,
    required this.bookName,
    required this.annotations,
    required this.script,
    required this.onOpen,
    required this.onDelete,
    required this.onSwipeDelete,
    required this.onLongPress,
  });

  @override
  State<_BookSection> createState() => _BookSectionState();
}

class _BookSectionState extends State<_BookSection> {
  late bool _expanded = widget.annotations.length <= _kCollapseAfter;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final count = widget.annotations.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BookHeader(
          bookName: widget.bookName,
          count: count,
          expanded: _expanded,
          colors: colors,
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        // Collapsed groups render NO cards (nothing left in the tree), so
        // collapsed content can't be found, focused or read by screen
        // readers. The chevron animation in the header gives the visual cue.
        if (_expanded)
          Column(
            children: [
              for (final a in widget.annotations)
                Dismissible(
                  key: ValueKey('annot-${a.id}'),
                  direction: DismissDirection.endToStart,
                  background: _DeleteBackground(colors: colors, loc: loc),
                  // Swipe confirms here; the trash button delegates to the
                  // list-level [_AnnotationsListState._requestDelete], which
                  // shows the same confirmation dialog.
                  confirmDismiss: (_) => _confirmDelete(context, a),
                  onDismissed: (_) => widget.onSwipeDelete(a),
                  child: _AnnotationCard(
                    annotation: a,
                    script: widget.script,
                    onTap: () => widget.onOpen(a),
                    onDelete: () => widget.onDelete(a),
                    onLongPress: () => widget.onLongPress(a),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Future<bool> _confirmDelete(BuildContext context, Annotation a) async {
    final loc = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.deleteAnnotation),
        content: Text(
          a.isBookmark
              ? loc.deleteAnnotationBookmarkMsg
              : loc.deleteAnnotationMsg,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: Text(loc.delete),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}

// ── Book section header ─────────────────────────────────────────────────

class _BookHeader extends StatelessWidget {
  final String bookName;
  final int count;
  final bool expanded;
  final ColorScheme colors;
  final VoidCallback onTap;

  const _BookHeader({
    required this.bookName,
    required this.count,
    required this.expanded,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Tooltip(
      message: expanded ? loc.collapseLabel : loc.expand,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.md,
            AppDimensions.md,
            AppDimensions.md,
            AppDimensions.xs,
          ),
          child: Row(
            children: [
              Icon(Icons.menu_book_outlined, size: 15, color: colors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  bookName,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                ),
                child: Text(
                  '$count',
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.expand_more,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 2),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Action sheet (long-press / ⋮ menu / right-click) ──────────────────

class _CardActionsSheet extends StatelessWidget {
  final Annotation annotation;
  final AppLocalizations loc;
  final VoidCallback onOpenReader;
  final ValueChanged<HighlightColor> onChangeColor;
  final VoidCallback onEditNote;
  final VoidCallback onDelete;

  const _CardActionsSheet({
    required this.annotation,
    required this.loc,
    required this.onOpenReader,
    required this.onChangeColor,
    required this.onEditNote,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final a = annotation;
    final isBookmark = a.isBookmark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppDimensions.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header — type icon + label
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Icon(
                    isBookmark ? Icons.bookmark : Icons.edit_note,
                    size: 18,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      a.displayLabel(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelMedium.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!isBookmark) ...[
              // Color row — tap a swatch to change the highlight color; the
              // rainbow swatch at the end opens the full palette picker.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      loc.changeColor,
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    for (final c in HighlightColor.quick)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _ColorSwatch(
                          color: c,
                          selected: c == a.color,
                          onTap: () => onChangeColor(c),
                        ),
                      ),
                    HighlightColorPickerSwatch(
                      initialColor: a.color,
                      size: 28,
                      onColorPicked: onChangeColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              ListTile(
                dense: true,
                leading: const Icon(Icons.edit_note),
                title: Text(loc.editNoteLabel),
                onTap: onEditNote,
              ),
            ],
            ListTile(
              dense: true,
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(loc.openInReader),
              onTap: onOpenReader,
            ),
            const Divider(height: 1),
            ListTile(
              dense: true,
              leading: Icon(Icons.delete_outline, color: colors.error),
              title: Text(
                loc.delete,
                style: TextStyle(
                  color: colors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// A tappable color dot inside the action sheet.
class _ColorSwatch extends StatelessWidget {
  final HighlightColor color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.swatch,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? colors.onSurface : colors.outlineVariant,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, size: 15, color: Colors.black87)
            : null,
      ),
    );
  }
}

// ── Annotation card ────────────────────────────────────────────────────

class _AnnotationCard extends StatelessWidget {
  final Annotation annotation;
  final Script script;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  /// Opens the action sheet (long-press on touch, right-click on desktop).
  final VoidCallback onLongPress;

  const _AnnotationCard({
    required this.annotation,
    required this.script,
    required this.onTap,
    required this.onDelete,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final a = annotation;
    final isBookmark = a.isBookmark;
    final accent = isBookmark
        ? colors.primary
        : (a.color?.color(context) ?? colors.tertiary);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.md, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: GestureDetector(
        // Long-press (touch) and secondary tap (desktop right-click) both
        // open the action sheet.
        onLongPress: onLongPress,
        onSecondaryTap: onLongPress,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Color / type bar
                Container(
                  width: 4,
                  height: 46,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMainLine(context, colors),
                      const SizedBox(height: 4),
                      _buildMetaLine(context, colors),
                    ],
                  ),
                ),
                _DeleteButton(onDelete: onDelete),
                _MenuButton(onTap: onLongPress),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainLine(BuildContext context, ColorScheme colors) {
    final a = annotation;
    final isBookmark = a.isBookmark;

    if (isBookmark) {
      return Row(
        children: [
          Icon(Icons.bookmark, size: 14, color: colors.primary),
          const SizedBox(width: 5),
          Expanded(
            child: PaliTextStatic(
              a.name ?? a.bookId,
              script,
              style: AppTypography.bodyTranslation.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    // Highlight / note: quote text with the highlight tint as backdrop.
    // NOTE: the quote is stored ALREADY script-converted (the anchor
    // builder converts to the display script before persisting), so render
    // it with plain Text — running it through PaliTextStatic would convert
    // it a second time (and could garble non-Roman text).
    final quote = a.exactText?.trim() ?? '';
    final tint = a.color?.color(context);
    final noteText = a.hasNote ? a.note!.trim() : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (quote.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tint ?? colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              quote,
              style: AppTypography.bodyTranslation.copyWith(
                fontSize: 13.5,
                fontStyle: FontStyle.italic,
                color: colors.onSurface,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (noteText.isNotEmpty) ...[
          if (quote.isNotEmpty) const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.sticky_note_2_outlined, size: 13, color: colors.tertiary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  noteText.split('\n').first,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMetaLine(BuildContext context, ColorScheme colors) {
    final loc = AppLocalizations.of(context);
    final a = annotation;
    final location = a.paraId != null ? '· ${a.paraId}' : '';

    return Row(
      children: [
        Icon(
          a.segment == 'translation' ? Icons.translate : Icons.menu_book,
          size: 11,
          color: colors.outline,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '${a.bookName ?? a.bookId} $location',
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant.withValues(alpha: 0.8),
              fontSize: 10.5,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          formatTimeAgo(a.updatedAt, loc),
          style: AppTypography.labelSmall.copyWith(
            color: colors.outline,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}

class _DeleteButton extends StatelessWidget {
  final VoidCallback onDelete;

  const _DeleteButton({required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onDelete,
      icon: Icon(
        Icons.delete_outline,
        size: 18,
        color: colors.error.withValues(alpha: 0.6),
      ),
      tooltip: AppLocalizations.of(context).delete,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}

/// ⋮ menu button — opens the same action sheet as long-press / right-click.
class _MenuButton extends StatelessWidget {
  final VoidCallback onTap;

  const _MenuButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onTap,
      icon: Icon(Icons.more_vert, size: 18, color: colors.onSurfaceVariant),
      tooltip: AppLocalizations.of(context).moreActions,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}

/// Red background revealed while swiping a card left.
class _DeleteBackground extends StatelessWidget {
  final ColorScheme colors;
  final AppLocalizations loc;

  const _DeleteBackground({required this.colors, required this.loc});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.md, vertical: 4),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline, size: 18, color: colors.onErrorContainer),
          const SizedBox(width: 6),
          Text(
            loc.delete,
            style: TextStyle(
              color: colors.onErrorContainer,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty states ───────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final AnnotationType? filter;
  final String? query;
  final bool isBookFiltered;
  final ColorScheme colors;
  final AppLocalizations loc;
  final VoidCallback? onClearSearch;
  final VoidCallback? onClearBooks;

  const _EmptyState({
    required this.filter,
    required this.colors,
    required this.loc,
    required this.isBookFiltered,
    this.query,
    this.onClearSearch,
    this.onClearBooks,
  });

  @override
  Widget build(BuildContext context) {
    final q = query?.trim() ?? '';
    final isSearch = q.isNotEmpty;

    final (icon, title, hint) = isSearch
        ? (Icons.search_off, loc.noResultsForQuery(q), loc.tryDifferentSearchTerm)
        : isBookFiltered
            ? (Icons.filter_alt_off, loc.noAnnotationsInBooks, '')
            : switch (filter) {
                AnnotationType.highlight => (
                  Icons.edit_note,
                  loc.noHighlightsYet,
                  loc.highlightDesc,
                ),
                AnnotationType.note => (
                  Icons.sticky_note_2_outlined,
                  loc.noNotesYet,
                  loc.noteDesc,
                ),
                AnnotationType.bookmark => (
                  Icons.bookmark_border,
                  loc.noBookmarksShort,
                  loc.addBookmark,
                ),
                _ => (
                  Icons.edit_note,
                  loc.noAnnotations,
                  loc.highlightsNotesBookmarks,
                ),
              };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: colors.primary),
            ),
            const SizedBox(height: AppDimensions.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.headlineSmall.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 17,
              ),
            ),
            if (hint.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.lg),
            if (isSearch)
              FilledButton.tonalIcon(
                onPressed: onClearSearch ?? () {},
                icon: const Icon(Icons.search_off, size: 16),
                label: Text(loc.clearSearch),
              )
            else if (isBookFiltered)
              FilledButton.tonalIcon(
                onPressed: onClearBooks ?? () {},
                icon: const Icon(Icons.filter_alt_off, size: 16),
                label: Text(loc.allBooks),
              )
            else if (!ResponsiveBreakpoint.isDesktop(context))
              FilledButton.tonalIcon(
                onPressed: () => context.push('/'),
                icon: const Icon(Icons.menu_book, size: 16),
                label: Text(loc.openLibrary),
              ),
          ],
        ),
      ),
    );
  }
}
