import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_db_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/responsive_breakpoint.dart';
import '../../../shared/widgets/pali_text.dart';
import '../../annotations/models/annotation.dart';
import '../../annotations/providers/annotations_provider.dart';
import '../../reader/providers/reader_tabs_provider.dart';

/// A self-contained bookmarks list panel for the desktop sidebar.
///
/// Shows the user's saved reading positions with delete support; tapping a
/// bookmark opens it in the reader (switching/opening the tab, and only
/// navigating to the reader route on non-desktop platforms).
class BookmarksPanel extends ConsumerWidget {
  const BookmarksPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarksAsync = ref.watch(bookmarksProvider);
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Row(children: [
            Icon(Icons.bookmark, size: 14, color: colors.primary),
            const SizedBox(width: 6),
            Text(loc.bookmarks,
                style: AppTypography.labelMedium.copyWith(
                    color: colors.primary, fontWeight: FontWeight.w600)),
          ]),
        ),
        bookmarksAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text(loc.errorMessage('$e'),
                style: AppTypography.labelSmall.copyWith(color: colors.error)),
          ),
          data: (bookmarks) {
            if (bookmarks.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(loc.noBookmarksShort,
                      style: AppTypography.labelSmall.copyWith(
                          color: colors.onSurfaceVariant)),
                ),
              );
            }
            return Column(
              children: bookmarks.map((bm) => _BookmarkCard(
                    bookmark: bm,
                    colors: colors,
                    onTap: () => _openBook(context, ref, bm.bookId,
                        bm.bookName, bm.paraId, bm.lineId),
                    onDelete: () => _confirmDeleteBookmark(
                        context, ref, bm.id, bm.name ?? ''),
                  )).toList(),
            );
          },
        ),
      ],
    );
  }

  void _openBook(BuildContext context, WidgetRef ref, String bookId,
      String? bookName, int? paraId, [int? lineId]) {
    ref.read(readerTabsProvider.notifier).openTab(
          ReaderTabInfo(
            bookId: bookId,
            bookName: bookName ?? bookId,
            initialParaId: paraId,
            initialLineId: lineId,
          ),
        );
    if (!ResponsiveBreakpoint.isDesktop(context)) {
      context.push('/reader');
    }
  }

  void _confirmDeleteBookmark(
      BuildContext context, WidgetRef ref, String id, String name) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.removeBookmark),
        content: Text(loc.deleteBookmarkConfirm(name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(loc.cancel)),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(annotationRepositoryProvider.future).then((repo) async {
                await repo.delete(id);
                ref.invalidate(bookmarksProvider);
              });
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(loc.delete),
          ),
        ],
      ),
    );
  }
}

class _BookmarkCard extends ConsumerWidget {
  final Annotation bookmark;
  final ColorScheme colors;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _BookmarkCard({
    required this.bookmark,
    required this.colors,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final script = ref.watch(settingsProvider).paliScript;
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        side: BorderSide(color: colors.outlineVariant, width: 0.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(children: [
            Expanded(
              child: PaliTextStatic(
                bookmark.name ?? '',
                script,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline,
                  size: 14, color: colors.error.withValues(alpha: 0.6)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
          ]),
        ),
      ),
    );
  }
}
