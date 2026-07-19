import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/app_db_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_breakpoint.dart';
import '../../../shared/widgets/pali_text.dart';
import '../../reader/providers/reader_tabs_provider.dart';
import 'library_browser.dart';

/// A compact library panel for the left sidebar on desktop.
///
/// Contains three tabs: Browse (Tipitaka book tree), Reading (open tabs),
/// and Bookmarks (saved positions + reading history).
class LibraryPanel extends ConsumerStatefulWidget {
  const LibraryPanel({super.key});

  @override
  ConsumerState<LibraryPanel> createState() => _LibraryPanelState();
}

class _LibraryPanelState extends ConsumerState<LibraryPanel> {
  int _selectedIndex = 0;

  static const _tabs = ['Browse', 'Reading', 'Bookmarks'];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        // ── Compact segmented control ────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.sm, AppDimensions.sm, AppDimensions.sm, 0,
          ),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Row(
              children: [
                for (final (i, label) in _tabs.indexed)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedIndex = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppDimensions.xs,
                          horizontal: AppDimensions.sm,
                        ),
                        decoration: BoxDecoration(
                          color: i == _selectedIndex
                              ? colors.surface
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(
                              AppDimensions.radiusSm),
                          boxShadow: i == _selectedIndex
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (i == _selectedIndex)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(
                                  label == 'Browse'
                                      ? Icons.menu_book
                                      : label == 'Reading'
                                          ? Icons.tab
                                          : Icons.bookmark,
                                  size: 12,
                                  color: colors.primary,
                                ),
                              ),
                            Text(
                              label,
                              textAlign: TextAlign.center,
                              style: AppTypography.labelSmall.copyWith(
                                color: i == _selectedIndex
                                    ? colors.primary
                                    : colors.onSurfaceVariant,
                                fontWeight: i == _selectedIndex
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.sm),
        // ── Tab content ───────────────────────────────────────────
        Expanded(
          child: _buildTabContent(colors),
        ),
      ],
    );
  }

  Widget _buildTabContent(ColorScheme colors) {
    switch (_selectedIndex) {
      case 1:
        return _ReadingTab(colors: colors);
      case 2:
        return _BookmarksTab(colors: colors);
      default:
        return LibraryBrowser(maxWidth: double.infinity);
    }
  }
}

// ── Reading Tab ─────────────────────────────────────────────────────────

class _ReadingTab extends ConsumerWidget {
  final ColorScheme colors;
  const _ReadingTab({required this.colors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabsState = ref.watch(readerTabsProvider);

    if (tabsState.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tab, size: 32, color: colors.outlineVariant),
            const SizedBox(height: AppDimensions.sm),
            Text(
              'No books open yet.',
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text(
                'Open Tabs',
                style: AppTypography.labelMedium.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${tabsState.tabs.length}',
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        ...tabsState.tabs.map((tab) => _OpenTabCard(
              tab: tab,
              colors: colors,
              onTap: () {
                ref.read(readerTabsProvider.notifier).switchTo(
                      tabsState.tabs.indexOf(tab),
                    );
                if (!ResponsiveBreakpoint.isDesktop(context)) {
                  context.push('/reader');
                }
              },
              onClose: () {
                final index = tabsState.tabs.indexOf(tab);
                if (index >= 0) {
                  ref.read(readerTabsProvider.notifier).closeTab(index);
                }
              },
            )),
      ],
    );
  }
}

class _OpenTabCard extends ConsumerWidget {
  final ReaderTabInfo tab;
  final ColorScheme colors;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _OpenTabCard({
    required this.tab,
    required this.colors,
    required this.onTap,
    required this.onClose,
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
                tab.bookName,
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
              onPressed: onClose,
              icon: Icon(Icons.close, size: 14, color: colors.outline),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Bookmarks Tab ───────────────────────────────────────────────────────

class _BookmarksTab extends ConsumerWidget {
  final ColorScheme colors;
  const _BookmarksTab({required this.colors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarksAsync = ref.watch(bookmarksProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Icon(Icons.bookmark, size: 14, color: colors.primary),
            const SizedBox(width: 6),
            Text('Bookmarks',
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
            child: Text('Error: $e',
                style: AppTypography.labelSmall.copyWith(color: colors.error)),
          ),
          data: (bookmarks) {
            if (bookmarks.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('No bookmarks yet.',
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
                    onDelete: () => _confirmDeleteBookmark(context, ref, bm.id, bm.name),
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
      BuildContext context, WidgetRef ref, int id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Bookmark?'),
        content: Text('Delete bookmark "$name"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(appDbProvider.future).then((db) async {
                await db.deleteBookmark(id);
                ref.invalidate(bookmarksProvider);
              });
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _BookmarkCard extends ConsumerWidget {
  final Bookmark bookmark;
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
                bookmark.name,
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
              icon: Icon(Icons.delete_outline, size: 14,
                  color: colors.error.withValues(alpha: 0.6)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
          ]),
        ),
      ),
    );
  }
}
