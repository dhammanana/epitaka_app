import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/app_db_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/reader/providers/reader_tabs_provider.dart';
import '../../gavesana/screens/gavesana_drawer.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/pali_text.dart';
import '../widgets/library_browser.dart';
import '../providers/heading_title_provider.dart';

/// Library screen with Browse / Reading / Bookmarks tabs.
///
/// - Browse: the Tipitaka book tree (existing [LibraryBrowser]).
/// - Reading: shows currently open reader tabs at the top.
/// - Bookmarks: shows saved bookmarks at the top, reading history below.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Check if a tab index was passed via query parameter (from drawer)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleTabQueryParam();
    });
  }

  void _handleTabQueryParam() {
    final uri = Uri.tryParse(GoRouterState.of(context).uri.toString());
    if (uri != null && uri.queryParameters.containsKey('tab')) {
      final tabParam = uri.queryParameters['tab'];
      final tabIndex = int.tryParse(tabParam ?? '');
      if (tabIndex != null && tabIndex >= 0 && tabIndex < 3) {
        setState(() => _selectedIndex = tabIndex);
        // Clean the query parameter so it doesn't re-trigger
        context.go('/');
      }
    }
  }

  static const _tabs = ['Browse', 'Reading', 'Bookmarks'];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // Use GlobalKey to control the drawer from the app bar button
    return AppShell(
      drawer: const MainDrawer(),
      appBar: _LibraryAppBar(colors: colors),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.marginMobile,
              AppDimensions.md,
              AppDimensions.marginMobile,
              0,
            ),
            child: _SegmentedControl(
              tabs: _tabs,
              selectedIndex: _selectedIndex,
              colors: colors,
              onTabChanged: (i) => setState(() => _selectedIndex = i),
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _selectedIndex == 0 ? 0 : AppDimensions.marginMobile,
              ),
              child: _buildTabContent(colors),
            ),
          ),
          const SizedBox(height: AppDimensions.md),
        ],
      ),
    );
  }

  Widget _buildTabContent(ColorScheme colors) {
    switch (_selectedIndex) {
      case 1:
        return _ReadingTab(colors: colors);
      case 2:
        return _BookmarksTab(colors: colors);
      default:
        return const LibraryBrowser();
    }
  }
}

// ── App Bar ──────────────────────────────────────────────────────────────

class _LibraryAppBar extends StatelessWidget implements PreferredSizeWidget {
  final ColorScheme colors;

  const _LibraryAppBar({required this.colors});

  @override
  Size get preferredSize => const Size.fromHeight(AppDimensions.appBarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: AppDimensions.appBarHeight,
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: colors.outlineVariant),
      ),        leading: Builder(builder: (context) {
          return IconButton(
            icon: const Icon(Icons.menu),
            color: colors.onSurfaceVariant,
            onPressed: () => Scaffold.of(context).openDrawer(),
          );
        }),
      title: Text(
        'ePitaka',
        style: AppTypography.headlineLarge.copyWith(
          color: colors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          color: colors.onSurfaceVariant,
          onPressed: () => context.push('/search'),
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          color: colors.onSurfaceVariant,
          onPressed: () => context.push('/settings'),
        ),
      ],
    );
  }
}

// ── Segmented Control ────────────────────────────────────────────────────

class _SegmentedControl extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ColorScheme colors;
  final ValueChanged<int> onTabChanged;

  const _SegmentedControl({
    required this.tabs,
    required this.selectedIndex,
    required this.colors,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Row(
        children: [
          for (final (i, label) in tabs.indexed)
            Expanded(
              child: GestureDetector(
                onTap: () => onTabChanged(i),
                child: _Segment(
                  label: label,
                  selected: i == selectedIndex,
                  colors: colors,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final ColorScheme colors;

  const _Segment({
    required this.label,
    required this.selected,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(
        vertical: AppDimensions.sm,
        horizontal: AppDimensions.md,
      ),
      decoration: BoxDecoration(
        color: selected ? colors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        boxShadow: selected
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
          if (selected)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(
                label == 'Browse'
                    ? Icons.menu_book
                    : label == 'Reading'
                        ? Icons.tab
                        : Icons.bookmark,
                size: 14,
                color: colors.primary,
              ),
            ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.labelMedium.copyWith(
              color: selected ? colors.primary : colors.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reading Tab (open tabs at top) ──────────────────────────────────────

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
            Icon(Icons.tab, size: 48, color: colors.outlineVariant),
            const SizedBox(height: 12),
            Text(
              'No books open yet.\nBrowse and open a book to start reading.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyTranslation.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Icon(Icons.arrow_upward, size: 20, color: colors.outlineVariant),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Icon(Icons.tab, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'Open Tabs',
                style: AppTypography.headlineSmall.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              Text(
                '${tabsState.tabs.length} book${tabsState.tabs.length == 1 ? '' : 's'}',
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        // Tab cards
        ...tabsState.tabs.map((tab) => _OpenTabCard(
              tab: tab,
              colors: colors,
              onTap: () {
                ref.read(readerTabsProvider.notifier).switchTo(
                      tabsState.tabs.indexOf(tab),
                    );
                context.push('/reader');
              },
              onClose: () {
                final index = tabsState.tabs.indexOf(tab);
                if (index >= 0) {
                  ref.read(readerTabsProvider.notifier).closeTab(index);
                }
              },
            )),
        // History section at the bottom
        const SizedBox(height: 24),
        _HistorySection(colors: colors),
      ],
    );
  }
}/// Card for an open tab in the Reading tab.
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

    // Look up nearest heading title
    final headingAsync = tab.currentParaId != null
        ? ref.watch(headingTitleProvider(HeadingQuery(
            bookId: tab.bookId,
            paraId: tab.currentParaId!,
          )))
        : null;
    final headingTitle = headingAsync?.when(
      data: (t) => t,
      loading: () => null,
      error: (_, __) => null,
    );
    final mainTitle = headingTitle ??
        (tab.currentParaId != null ? 'Para ${tab.currentParaId}' : null);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        side: BorderSide(color: colors.outlineVariant, width: 0.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.menu_book,
                  size: 18,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (mainTitle != null) PaliTextStatic(
                      mainTitle,
                      script,
                      style: AppTypography.bodyTranslation.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: PaliTextStatic(
                        tab.bookName,
                        script,
                        style: AppTypography.labelSmall.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: Icon(Icons.close, size: 18, color: colors.outline),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bookmarks Tab (bookmarks + history) ─────────────────────────────────

class _BookmarksTab extends ConsumerWidget {
  final ColorScheme colors;

  const _BookmarksTab({required this.colors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarksAsync = ref.watch(bookmarksProvider);
    final historyAsync = ref.watch(historyProvider);

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        // Bookmarks section
        Row(
          children: [
            Icon(Icons.bookmark, size: 18, color: colors.primary),
            const SizedBox(width: 8),
            Text(
              'Bookmarks',
              style: AppTypography.headlineSmall.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        bookmarksAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error loading bookmarks: $e'),
          ),
          data: (bookmarks) {
            if (bookmarks.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.bookmark_border, size: 36, color: colors.outlineVariant),
                      const SizedBox(height: 8),
                      Text(
                        'No bookmarks yet.\nSave your reading position from the reader.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyTranslation.copyWith(
                          color: colors.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(
              children: bookmarks.map((bm) => _BookmarkCard(
                bookmark: bm,
                colors: colors,
                onTap: () => _openBook(context, ref, bm.bookId, bm.bookName, bm.paraId, bm.lineId),
                onDelete: () => _confirmDeleteBookmark(context, ref, bm.id, bm.name),
              )).toList(),
            );
          },
        ),
        const SizedBox(height: 24),
        // History section at the bottom
        Row(
          children: [
            Icon(Icons.history, size: 18, color: colors.tertiary),
            const SizedBox(width: 8),
            Text(
              'Reading History',
              style: AppTypography.headlineSmall.copyWith(
                color: colors.tertiary,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        historyAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error loading history: $e'),
          ),
          data: (history) {
            if (history.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.history, size: 36, color: colors.outlineVariant),
                      const SizedBox(height: 8),
                      Text(
                        'No reading history yet.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyTranslation.copyWith(
                          color: colors.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(
              children: history.map((entry) => _HistoryCard(
                entry: entry,
                colors: colors,
                onTap: () => _openBook(context, ref, entry.bookId, entry.bookName, entry.paraId, entry.lineId),
                onDelete: () => _confirmDeleteHistory(context, ref, entry.id, entry.bookName ?? entry.bookId),
              )).toList(),
            );
          },
        ),
      ],
    );
  }

  void _openBook(BuildContext context, WidgetRef ref, String bookId, String? bookName, int? paraId, [int? lineId]) {
    ref.read(readerTabsProvider.notifier).openTab(
      ReaderTabInfo(
        bookId: bookId,
        bookName: bookName ?? bookId,
        initialParaId: paraId,
        initialLineId: lineId,
      ),
    );
    context.push('/reader');
  }

  void _confirmDeleteBookmark(BuildContext context, WidgetRef ref, int id, String name) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Bookmark?'),
        content: Text('Delete bookmark "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _deleteBookmark(ref, id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Removed: $name'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBookmark(WidgetRef ref, int id) async {
    try {
      final db = await ref.read(appDbProvider.future);
      await db.deleteBookmark(id);
      ref.invalidate(bookmarksProvider);
    } catch (e) {
      // Silently fail
    }
  }

  void _confirmDeleteHistory(BuildContext context, WidgetRef ref, int id, String label) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove History Entry?'),
        content: Text('Delete history entry for "$label"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _deleteHistoryEntry(ref, id);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteHistoryEntry(WidgetRef ref, int id) async {
    try {
      final db = await ref.read(appDbProvider.future);
      await db.deleteHistoryEntry(id);
      ref.invalidate(historyProvider);
    } catch (_) {}
  }
}


// ── Bookmark Card ────────────────────────────────────────────────────────

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
    final displayName = bookmark.name;

    // Look up nearest heading title
    final headingAsync = bookmark.paraId != null
        ? ref.watch(headingTitleProvider(HeadingQuery(
            bookId: bookmark.bookId,
            paraId: bookmark.paraId!,
          )))
        : null;
    final headingTitle = headingAsync?.when(
      data: (t) => t,
      loading: () => null,
      error: (_, __) => null,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        side: BorderSide(color: colors.outlineVariant, width: 0.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.bookmark,
                  size: 18,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main title: heading title from DB
                    if (headingTitle != null)
                      PaliTextStatic(
                        headingTitle,
                        script,
                        style: AppTypography.bodyTranslation.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    // Secondary: bookmark name + para location
                    Padding(
                      padding: EdgeInsets.only(top: headingTitle != null ? 2 : 0),
                      child: PaliTextStatic(
                        headingTitle != null
                            ? '$displayName — Para ${bookmark.paraId}'
                            : displayName,
                        script,
                        style: AppTypography.labelSmall.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (bookmark.pageNumber != null && bookmark.pageNumber!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'p. ${bookmark.pageNumber}',
                          style: AppTypography.labelSmall.copyWith(
                            color: colors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: PaliTextStatic(
                        bookmark.bookName ?? bookmark.bookId,
                        script,
                        style: AppTypography.labelSmall.copyWith(
                          color: colors.primary.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, size: 18, color: colors.error.withValues(alpha: 0.6)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── History Section (used in Reading tab) ────────────────────────────────

class _HistorySection extends ConsumerWidget {
  final ColorScheme colors;

  const _HistorySection({required this.colors});

  void _confirmDeleteHistory(BuildContext context, WidgetRef ref, int id, String label) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove History Entry?'),
        content: Text('Delete history entry for "$label"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(appDbProvider.future).then((db) async {
                await db.deleteHistoryEntry(id);
                ref.invalidate(historyProvider);
              });
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history, size: 18, color: colors.tertiary),
            const SizedBox(width: 8),
            Text(
              'History',
              style: AppTypography.headlineSmall.copyWith(
                color: colors.tertiary,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        historyAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error loading history: $e'),
          ),
          data: (history) {
            if (history.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.history, size: 36, color: colors.outlineVariant),
                      const SizedBox(height: 8),
                      Text(
                        'No reading history yet.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyTranslation.copyWith(
                          color: colors.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(
              children: history.map((entry) => _HistoryCard(
                entry: entry,
                colors: colors,
                onTap: () {
                  ref.read(readerTabsProvider.notifier).openTab(
                    ReaderTabInfo(
                      bookId: entry.bookId,
                      bookName: entry.bookName ?? entry.bookId,
                      initialParaId: entry.paraId,
                      initialLineId: entry.lineId,
                    ),
                  );
                  context.push('/reader');
                },
                onDelete: () => _confirmDeleteHistory(context, ref, entry.id, entry.bookName ?? entry.bookId),
              )).toList(),
            );
          },
        ),
      ],
    );
  }
}

// ── History Card ─────────────────────────────────────────────────────────

class _HistoryCard extends ConsumerWidget {
  final ReadingHistoryData entry;
  final ColorScheme colors;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryCard({
    required this.entry,
    required this.colors,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeAgo = _formatTimeAgo(entry.updatedAt);
    final script = ref.watch(settingsProvider).paliScript;

    // Look up nearest heading title
    final headingAsync = entry.paraId != null
        ? ref.watch(headingTitleProvider(HeadingQuery(
            bookId: entry.bookId,
            paraId: entry.paraId!,
          )))
        : null;
    final headingTitle = headingAsync?.when(
      data: (t) => t,
      loading: () => null,
      error: (_, __) => null,
    );
    final mainTitle = headingTitle ??
        (entry.paraId != null ? 'Para ${entry.paraId}' : null);

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        side: BorderSide(color: colors.outlineVariant, width: 0.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colors.tertiaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.history,
                  size: 16,
                  color: colors.tertiary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main title: heading title from DB
                    if (mainTitle != null) PaliTextStatic(
                      mainTitle,
                      script,
                      style: AppTypography.bodyTranslation.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Secondary: book name + para location
                    PaliTextStatic(
                      entry.bookName ?? entry.bookId,
                      script,
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Timestamp + read count
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Text(
                            timeAgo,
                            style: AppTypography.labelSmall.copyWith(
                              color: colors.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                          if (entry.readCount > 1) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.touch_app, size: 10, color: colors.outline),
                            const SizedBox(width: 2),
                            Text(
                              '${entry.readCount}',
                              style: AppTypography.labelSmall.copyWith(
                                color: colors.outline,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, size: 16, color: colors.error.withValues(alpha: 0.6)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}
