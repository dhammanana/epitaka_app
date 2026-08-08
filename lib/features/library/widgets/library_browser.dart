import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/books_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/pali_text_utils.dart';
import '../../../core/utils/responsive_breakpoint.dart';
import '../../../shared/widgets/pali_text.dart';
import '../../../features/reader/providers/reader_tabs_provider.dart';
import '../providers/library_filter_provider.dart';

/// Self-contained Tipitaka book browser: category tabs (Mūla, Aṭṭhakathā,
/// Ṭīkā, Añña) plus the collapsible nikaya tree underneath.
///
/// This owns its own data fetching (via [booksTreeProvider]) and its own
/// [DefaultTabController], so it can be dropped in anywhere — the full
/// [LibraryScreen], a dialog, a side panel, etc. — without the caller
/// needing to wire anything up.
///
/// On wide screens the content is capped at [maxWidth] and centered, so it
/// doesn't stretch into an awkwardly long single-column list. When shown in
/// a dialog, wrap this in a [SizedBox] (or give the dialog a fixed size) so
/// it has a bounded height to lay out the tab view in.
class LibraryBrowser extends ConsumerWidget {
  final double maxWidth;

  const LibraryBrowser({super.key, this.maxWidth = 640});

  static const List<LibraryFilter> _tabFilters = [
    LibraryFilter.mula,
    LibraryFilter.atthakatha,
    LibraryFilter.tika,
    LibraryFilter.anna,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treeAsync = ref.watch(booksTreeProvider);
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: treeAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off, size: 48, color: colors.error),
                  const SizedBox(height: 16),
                  Text(
                    'Could not load the Tipitaka library.\n$e',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          data: (categories) => _buildTabs(context, categories, colors),
        ),
      ),
    );
  }

  Widget _buildTabs(
      BuildContext context, List<BookCategory> categories, ColorScheme colors) {
    BookCategory? categoryFor(LibraryFilter filter) {
      for (final c in categories) {
        if (c.name == filter.label) return c;
      }
      return null;
    }

    return DefaultTabController(
      length: _tabFilters.length,
      child: Column(
        children: [
          _CategoryTabBar(colors: colors, filters: _tabFilters),
          const SizedBox(height: AppDimensions.sm),
          Expanded(
            child: TabBarView(
              children: [
                for (final filter in _tabFilters)
                  _CategoryTabContent(
                    category: categoryFor(filter),
                    colors: colors,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ── Category Tab Bar ──────────────────────────────────────────────────────

class _CategoryTabBar extends ConsumerWidget {
  final ColorScheme colors;
  final List<LibraryFilter> filters;

  const _CategoryTabBar({required this.colors, required this.filters});

  IconData _categoryIcon(LibraryFilter filter) {
    switch (filter) {
      case LibraryFilter.mula:
        return Icons.menu_book;
      case LibraryFilter.atthakatha:
        return Icons.description;
      case LibraryFilter.tika:
        return Icons.notes;
      case LibraryFilter.anna:
        return Icons.library_books;
      default:
        return Icons.auto_stories;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final script = ref.watch(settingsProvider).paliScript;
    // The tab labels are converted to the display script (see the `text:`
    // below), so they must be rendered with the script-specific font too —
    // otherwise scripts with a dedicated bundled font (Lao, Myanmar, …)
    // fall back to the platform default and render incorrectly, unlike the
    // book/nikaya names in the library which go through [PaliTextStatic].
    final scriptFont = scriptFontFamily(script);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.marginMobile),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: TabBar(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        splashBorderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        indicator: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        labelColor: colors.primary,
        unselectedLabelColor: colors.onSurfaceVariant,
        labelStyle: AppTypography.labelMedium.copyWith(
          fontWeight: FontWeight.w600,
          fontFamily: scriptFont,
        ),
        unselectedLabelStyle: AppTypography.labelMedium.copyWith(
          fontWeight: FontWeight.w500,
          fontFamily: scriptFont,
        ),
        tabs: [
          for (final filter in filters)
            Tab(
              height: 40,
              icon: Icon(_categoryIcon(filter), size: 16),
              text: convertPaliToScript(filter.label, script),
              iconMargin: const EdgeInsets.only(bottom: 2),
            ),
        ],
      ),
    );
  }
}

/// ── Category Tab Content ──────────────────────────────────────────────────

class _CategoryTabContent extends StatelessWidget {
  final BookCategory? category;
  final ColorScheme colors;

  const _CategoryTabContent({required this.category, required this.colors});

  @override
  Widget build(BuildContext context) {
    final cat = category;

    if (cat == null || cat.nikayas.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_alt_off, size: 48, color: colors.outlineVariant),
            const SizedBox(height: 12),
            Text(
              'No books in this Piṭaka yet.',
              style: AppTypography.bodyTranslation.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.marginMobile,
        0,
        AppDimensions.marginMobile,
        120, // bottom padding
      ),
      children: [
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            children: [
              for (final (index, nikaya) in cat.nikayas.indexed)
                _NikayaSection(
                  nikaya: nikaya,
                  colors: colors,
                  isLast: index == cat.nikayas.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// ── Nikaya Section ────────────────────────────────────────────────────────

class _NikayaSection extends ConsumerStatefulWidget {
  final BookNikaya nikaya;
  final ColorScheme colors;
  final bool isLast;

  const _NikayaSection({
    required this.nikaya,
    required this.colors,
    this.isLast = false,
  });

  @override
  ConsumerState<_NikayaSection> createState() => _NikayaSectionState();
}

class _NikayaSectionState extends ConsumerState<_NikayaSection> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _initExpanded();
  }

  void _initExpanded() {
    final level = ref.read(settingsProvider).libraryExpandLevel;
    _expanded = level != LibraryExpandLevel.collapsed;
  }

  @override
  Widget build(BuildContext context) {
    // Re-init expand state when setting changes
    ref.listen(settingsProvider, (prev, next) {
      if (prev?.libraryExpandLevel != next.libraryExpandLevel) {
        setState(() => _expanded = next.libraryExpandLevel != LibraryExpandLevel.collapsed);
      }
    });

    final nikaya = widget.nikaya;
    final colors = widget.colors;
    final script = ref.watch(settingsProvider).paliScript;

    // A sub-nikaya is "redundant" when it adds no information beyond the
    // nikaya itself — either it has no name of its own (an empty
    // placeholder) or its name just repeats the nikaya's name. Either way
    // its books render one level up, directly under the nikaya, instead
    // of behind their own header. The nikaya header itself always shows,
    // even when every one of its sub-nikayas is redundant.
    bool isRedundant(BookSubNikaya sub) {
      final name = sub.name.trim();
      return name.isEmpty || name == nikaya.name;
    }

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            color: _expanded
                ? colors.primaryContainer.withValues(alpha: 0.18)
                : Colors.transparent,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.md,
              vertical: 14,
            ),
            child: Row(
              children: [
                Icon(
                  _nikayaIcon(nikaya.name),
                  size: 20,
                  color: _expanded ? colors.primary : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PaliTextStatic(
                    nikaya.name,
                    script,
                    style: AppTypography.bodyTranslation.copyWith(
                      color: _expanded ? colors.primary : colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: _expanded ? colors.primary : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          ...nikaya.subNikayas.expand((sub) {
            if (isRedundant(sub)) {
              return sub.books.map(
                (book) => _BookRow(book: book, colors: colors, depth: 2),
              );
            }
            return [_SubNikayaSection(subNikaya: sub, colors: colors)];
          }),
        if (!widget.isLast) Divider(height: 1, color: colors.outlineVariant),
      ],
    );
  }

  IconData _nikayaIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('vinaya')) return Icons.account_balance;
    if (n.contains('sutta')) return Icons.description;
    if (n.contains('abhidhamma')) return Icons.psychology;
    if (n.contains('pariv')) return Icons.menu_book;
    return Icons.auto_stories;
  }
}

/// ── Sub-Nikaya Section ────────────────────────────────────────────────────

class _SubNikayaSection extends ConsumerStatefulWidget {
  final BookSubNikaya subNikaya;
  final ColorScheme colors;

  const _SubNikayaSection({required this.subNikaya, required this.colors});

  @override
  ConsumerState<_SubNikayaSection> createState() => _SubNikayaSectionState();
}

class _SubNikayaSectionState extends ConsumerState<_SubNikayaSection> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _initExpanded();
  }

  void _initExpanded() {
    final level = ref.read(settingsProvider).libraryExpandLevel;
    _expanded = level == LibraryExpandLevel.expand;
  }

  @override
  Widget build(BuildContext context) {
    // Re-init expand state when setting changes
    ref.listen(settingsProvider, (prev, next) {
      if (prev?.libraryExpandLevel != next.libraryExpandLevel) {
        setState(() => _expanded = next.libraryExpandLevel == LibraryExpandLevel.expand);
      }
    });

    final sub = widget.subNikaya;
    final colors = widget.colors;
    final script = ref.watch(settingsProvider).paliScript;

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _expanded
                  ? colors.primaryContainer.withValues(alpha: 0.14)
                  : Colors.transparent,
              border: Border(
                left: BorderSide(
                  color: _expanded ? colors.primary : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            padding: const EdgeInsets.only(
              left: 15, // 64 minus the 3px accent border above
              right: AppDimensions.md,
              top: 10,
              bottom: 10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: PaliTextStatic(
                    sub.name,
                    script,
                    style: AppTypography.bodyTranslation.copyWith(
                      color: _expanded ? colors.primary : colors.onSurfaceVariant,
                      fontWeight: _expanded ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward,
                  size: 14,
                  color: _expanded ? colors.primary : colors.outlineVariant,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          ...sub.books.map(
            (book) => _BookRow(book: book, colors: colors, depth: 3),
          ),
      ],
    );
  }
}

/// ── Book Row ──────────────────────────────────────────────────────────────

class _BookRow extends ConsumerStatefulWidget {
  final BookItem book;
  final ColorScheme colors;
  final int depth;

  const _BookRow({
    required this.book,
    required this.colors,
    required this.depth,
  });

  @override
  ConsumerState<_BookRow> createState() => _BookRowState();
}

class _BookRowState extends ConsumerState<_BookRow> {
  bool _relatedExpanded = false;

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    final colors = widget.colors;
    final hasRelated = book.relatedBooks.isNotEmpty;
    final script = ref.watch(settingsProvider).paliScript;

    return Column(
      children: [
        InkWell(
          onTap: () {
            ref.read(readerTabsProvider.notifier).openTab(
              ReaderTabInfo(
                bookId: book.book.bookId,
                bookName: book.book.displayName,
              ),
            );
            // Desktop: the reader is already visible — never push a second
            // reader onto the history stack (pops past it → black screen).
            if (!ResponsiveBreakpoint.isDesktop(context)) {
              context.push('/reader');
            }
          },
          child: Padding(
            padding: EdgeInsets.only(
              left: 18.0 + (widget.depth - 1) * 24,
              right: AppDimensions.md,
              top: 10,
              bottom: 10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: PaliTextStatic(
                    book.book.displayName,
                    script,
                    style: AppTypography.bodyTranslation.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                ),
                if (hasRelated)
                  GestureDetector(
                    onTap: () =>
                        setState(() => _relatedExpanded = !_relatedExpanded),
                    child: AnimatedRotation(
                      turns: _relatedExpanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _relatedExpanded
                              ? colors.primaryContainer.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.arrow_drop_down,
                          size: 20,
                          color: _relatedExpanded
                              ? colors.primary
                              : colors.outlineVariant,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: colors.outlineVariant,
                ),
              ],
            ),
          ),
        ),
        if (_relatedExpanded && hasRelated)
          ...book.relatedBooks.map(
            (ref) => _RelatedBookRow(ref: ref, colors: colors, depth: widget.depth),
          ),
      ],
    );
  }
}

/// ── Related Book Row ──────────────────────────────────────────────────────

class _RelatedBookRow extends ConsumerWidget {
  final RelatedBookRef ref;
  final ColorScheme colors;
  final int depth;

  const _RelatedBookRow({
    required this.ref,
    required this.colors,
    required this.depth,
  });

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final script = widgetRef.watch(settingsProvider).paliScript;

    return InkWell(
      onTap: () {
        widgetRef.read(readerTabsProvider.notifier).openTab(
          ReaderTabInfo(
            bookId: ref.bookId,
            bookName: ref.bookName,
          ),
        );
        if (!ResponsiveBreakpoint.isDesktop(context)) {
          context.push('/reader');
        }
      },
      child: Padding(
        padding: EdgeInsets.only(
          left: 18.0 + depth * 24,
          right: AppDimensions.md,
          top: 8,
          bottom: 8,
        ),
        child: Row(
          children: [
            // Type badge
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: _typeColor(colors).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                ref.type,
                style: AppTypography.labelSmall.copyWith(
                  color: _typeColor(colors),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PaliTextStatic(
                ref.bookName,
                script,
                style: AppTypography.bodyTranslation.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward,
              size: 14,
              color: colors.outlineVariant,
            ),
          ],
        ),
      ),
    );
  }

  Color _typeColor(ColorScheme colors) {
    switch (ref.type) {
      case 'mūla':
        return colors.primary;
      case 'aṭṭha':
        return colors.tertiary;
      case 'tīka':
        return colors.secondary;
      default:
        return colors.onSurfaceVariant;
    }
  }
}
