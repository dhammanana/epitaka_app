import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/app_models.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/pali_search_utils.dart';
import '../../../core/utils/platform_info.dart';
import '../../../shared/widgets/pali_text.dart';
import '../../reader/providers/reader_tabs_provider.dart';
import '../providers/contents_provider.dart';

/// Contents screen showing the table of contents for a book.
///
/// Features:
/// - Collapsible section hierarchy (every section starts expanded).
/// - A search field (toggled from the top bar) to filter headings by title.
/// - Auto-scroll + highlight of the section the reader is currently in.
class ContentsScreen extends ConsumerStatefulWidget {
  final String bookId;
  final String bookName;

  /// paraId the reader is currently at, used to highlight and auto-scroll
  /// to the current section when this screen opens.
  final int? currentParaId;

  const ContentsScreen({
    super.key,
    required this.bookId,
    this.bookName = '',
    this.currentParaId,
  });

  @override
  ConsumerState<ContentsScreen> createState() => _ContentsScreenState();
}

class _ContentsScreenState extends ConsumerState<ContentsScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  bool _didScrollToCurrent = false;
  bool _searchActive = false;
  String _searchQuery = '';

  /// paraIds of headings whose children are currently collapsed.
  /// Empty by default — every section starts expanded.
  final Set<int> _collapsedParaIds = {};

  // ── Memoization ──────────────────────────────────────────────────────
  // This screen rebuilds on every frame of the on-screen keyboard's
  // show/hide animation (Scaffold resizes the body to avoid the keyboard,
  // which changes MediaQuery.viewInsets continuously for ~300ms). Without
  // caching, _computeParents and the visibility filter — each an O(n)
  // walk over every heading — were being redone from scratch on every one
  // of those frames, competing with the keyboard animation for the main
  // thread and making the keyboard appear to open sluggishly. Both are
  // now cached and only recomputed when the underlying data actually
  // changes.
  List<HeadingInfo>? _cachedHeadings;
  List<int?>? _cachedParents;

  List<HeadingInfo>? _cachedVisibleHeadings;
  int? _cachedVisibleVersion;
  String? _cachedVisibleQuery;
  List<int>? _cachedVisibleIndices;

  /// Bumped only when the collapse/expand tree actually changes, so the
  /// visible-indices cache above knows to invalidate.
  int _collapseVersion = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Index of the last heading whose paraId is <= currentParaId — i.e. the
  /// section the reader is currently inside.
  int _currentHeadingIndex(List<HeadingInfo> headings) {
    if (widget.currentParaId == null) return -1;
    int result = -1;
    for (var i = 0; i < headings.length; i++) {
      final paraId = headings[i].paraId;
      if (paraId <= widget.currentParaId!) {
        result = i;
      } else {
        break;
      }
    }
    return result;
  }

  void _scrollToIndex(int index) {
    if (index < 0 || !_scrollController.hasClients) return;
    // Rough estimate: each row ~52px. Good enough for the initial jump;
    // ListView.builder rows aren't uniform-height-guaranteed.
    const estimatedItemHeight = 52.0;
    final viewportHeight = _scrollController.position.viewportDimension;
    // Offset so the target row lands in the middle of the visible area,
    // not pinned to the very top.
    final target = (index * estimatedItemHeight -
            (viewportHeight / 2) +
            (estimatedItemHeight / 2))
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.jumpTo(target);
  }

  /// For each heading, the index of its nearest ancestor with a strictly
  /// smaller level (or null for top-level headings). Headings are in
  /// document order, so a heading's parent is simply the closest earlier
  /// entry with a shallower level — no explicit parent pointer needed.
  List<int?> _computeParents(List<HeadingInfo> headings) {
    final parents = List<int?>.filled(headings.length, null);
    final stack = <int>[];
    for (var i = 0; i < headings.length; i++) {
      final level = headings[i].level ?? 1;
      while (stack.isNotEmpty && (headings[stack.last].level ?? 1) >= level) {
        stack.removeLast();
      }
      parents[i] = stack.isEmpty ? null : stack.last;
      stack.add(i);
    }
    return parents;
  }

  /// A heading "has children" if the very next entry in document order is
  /// at a deeper level than it is.
  bool _hasChildren(int index, List<HeadingInfo> headings) {
    if (index + 1 >= headings.length) return false;
    final level = headings[index].level ?? 1;
    final nextLevel = headings[index + 1].level ?? 1;
    return nextLevel > level;
  }

  bool _isVisible(int index, List<int?> parents, List<HeadingInfo> headings) {
    int? p = parents[index];
    while (p != null) {
      final parentParaId = headings[p].paraId;
      if (_collapsedParaIds.contains(parentParaId)) return false;
      p = parents[p];
    }
    return true;
  }

  /// Cached wrapper around [_computeParents] — the parent map only
  /// depends on the headings list itself, which Riverpod keeps as the
  /// same instance across rebuilds once loaded.
  List<int?> _parentsFor(List<HeadingInfo> headings) {
    if (!identical(_cachedHeadings, headings)) {
      _cachedHeadings = headings;
      _cachedParents = _computeParents(headings);
    }
    return _cachedParents!;
  }

  /// Cached wrapper around the search/collapse filtering below —
  /// recomputed only when the headings list, the search query, or the
  /// collapse state actually changed.
  List<int> _visibleIndicesFor(
    List<HeadingInfo> headings,
    List<int?> parents,
    String query,
  ) {
    if (identical(_cachedVisibleHeadings, headings) &&
        _cachedVisibleVersion == _collapseVersion &&
        _cachedVisibleQuery == query) {
      return _cachedVisibleIndices!;
    }

    final result = query.isNotEmpty
        ? [
            for (var i = 0; i < headings.length; i++)
              if (normalizePaliFuzzy(headings[i].title ?? '')
                  .toLowerCase()
                  .contains(query))
                i,
          ]
        : [
            for (var i = 0; i < headings.length; i++)
              if (_isVisible(i, parents, headings)) i,
          ];

    _cachedVisibleHeadings = headings;
    _cachedVisibleVersion = _collapseVersion;
    _cachedVisibleQuery = query;
    _cachedVisibleIndices = result;
    return result;
  }

  void _toggleCollapse(int paraId) {
    setState(() {
      if (_collapsedParaIds.contains(paraId)) {
        _collapsedParaIds.remove(paraId);
      } else {
        _collapsedParaIds.add(paraId);
      }
      _collapseVersion++;
    });
  }

  void _openSearch() {
    setState(() => _searchActive = true);
  }

  void _closeSearch() {
    setState(() {
      _searchActive = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _jumpTo(HeadingInfo heading) {
    // Whether or not a tab is already open for this book, openTab jumps
    // within the existing tab (updating its initialParaId) rather than
    // creating a duplicate — so there's no need to branch on whether one
    // already exists.
    ref.read(readerTabsProvider.notifier).openTab(ReaderTabInfo(
          bookId: widget.bookId,
          bookName: widget.bookName,
          initialParaId: heading.paraId,
        ));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final contentsAsync = ref.watch(contentsProvider(widget.bookId));
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    return Scaffold(
      body: contentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stack) =>
            Center(child: Text(loc.errorMessage('$e'))),
        data: (headings) {
          final currentIndex = _currentHeadingIndex(headings);

          if (!_searchActive && !_didScrollToCurrent && currentIndex >= 0) {
            _didScrollToCurrent = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToIndex(currentIndex);
            });
          }

          final parents = _parentsFor(headings);
          final query = normalizePaliFuzzy(_searchQuery.trim()).toLowerCase();

          // Phones have much less horizontal room, so both the outer list
          // padding and the per-level indent step are tightened up.
          final isPhone = Mobile.isPhone(context);
          final indentUnit = isPhone ? AppDimensions.sm : AppDimensions.md;
          final listLeftPadding = isPhone ? AppDimensions.sm : AppDimensions.md;
          final rowLeftPadding = isPhone ? AppDimensions.sm : AppDimensions.md;

          // While searching, show a flat list of matches regardless of
          // collapse state. Otherwise, respect the expand/collapse tree.
          // Titles and query are both run through normalizePaliFuzzy so a
          // plain "n" also matches ñ/ṇ/ṅ and other Pāli diacritic letters.
          final visibleIndices = _visibleIndicesFor(headings, parents, query);

          return Column(
            children: [
              // Top bar with title/search toggle and close
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.marginMobile,
                    AppDimensions.sm,
                    AppDimensions.marginMobile,
                    0,
                  ),
                  child: _searchActive
                      ? _buildSearchBar(colors)
                      : _buildTitleBar(colors),
                ),
              ),
              Divider(color: colors.outlineVariant, height: 1),
              Expanded(
                child: visibleIndices.isEmpty
                    ? Center(
                        child: Text(
                          query.isNotEmpty
                              ? loc.noMatchingSections
                              : loc.noContentsAvailable,
                          style: AppTypography.labelSmall.copyWith(
                            fontSize: 14,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(
                          listLeftPadding,
                          AppDimensions.md,
                          AppDimensions.md,
                          AppDimensions.md,
                        ),
                        itemCount: visibleIndices.length,
                        itemBuilder: (context, i) {
                          final index = visibleIndices[i];
                          final heading = headings[index];
                          final indent = query.isEmpty
                              ? (heading.level ?? 1).clamp(1, 5) - 1
                              : 0;
                          final isCurrent = index == currentIndex;
                          final hasChildren =
                              query.isEmpty && _hasChildren(index, headings);
                          final isCollapsed =
                              _collapsedParaIds.contains(heading.paraId);

                          return _ContentsRow(
                            heading: heading,
                            indent: indent,
                            indentUnit: indentUnit,
                            leftPadding: rowLeftPadding,
                            isCurrent: isCurrent,
                            hasChildren: hasChildren,
                            isCollapsed: isCollapsed,
                            colors: colors,
                            onToggleCollapse: () =>
                                _toggleCollapse(heading.paraId),
                            onTap: () => _jumpTo(heading),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTitleBar(ColorScheme colors) {
    final loc = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          loc.contents,
          style: AppTypography.headlineSmall.copyWith(color: colors.primary),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.search),
              color: colors.onSurfaceVariant,
              tooltip: loc.searchContents,
              onPressed: _openSearch,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              color: colors.onSurfaceVariant,
              onPressed: () => context.pop(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar(ColorScheme colors) {
    final loc = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            autofocus: true,
            style: AppTypography.headlineSmall.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: colors.onSurface,
            ),
            decoration: InputDecoration(
              hintText: loc.searchContents,
              hintStyle: AppTypography.labelSmall.copyWith(
                fontSize: 14,
                color: colors.onSurfaceVariant,
              ),
              border: InputBorder.none,
              isDense: true,
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          color: colors.onSurfaceVariant,
          tooltip: loc.closeSearch,
          onPressed: _closeSearch,
        ),
      ],
    );
  }
}

/// Single row in the table of contents: an optional expand/collapse
/// chevron, the section title, and a small paraId badge at the end.
class _ContentsRow extends ConsumerWidget {
  final HeadingInfo heading;
  final int indent;

  /// Left-padding added per nesting level (smaller on phones).
  final double indentUnit;

  /// Left padding on the row's own content, independent of nesting
  /// (smaller on phones).
  final double leftPadding;
  final bool isCurrent;
  final bool hasChildren;
  final bool isCollapsed;
  final ColorScheme colors;
  final VoidCallback onToggleCollapse;
  final VoidCallback onTap;

  const _ContentsRow({
    required this.heading,
    required this.indent,
    required this.indentUnit,
    required this.leftPadding,
    required this.isCurrent,
    required this.hasChildren,
    required this.isCollapsed,
    required this.colors,
    required this.onToggleCollapse,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final script = ref.watch(settingsProvider).paliScript;

    return Padding(
      padding: EdgeInsets.only(left: indent * indentUnit),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isCurrent
              ? colors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              leftPadding,
              12,
              AppDimensions.md,
              12,
            ),
            child: Row(
              children: [
                if (hasChildren)
                  GestureDetector(
                    onTap: onToggleCollapse,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        isCollapsed ? Icons.chevron_right : Icons.expand_more,
                        size: 20,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 24),
                Expanded(
                  child: PaliTextStatic(
                    heading.title ?? loc.untitled,
                    script,
                    style: AppTypography.headlineSmall.copyWith(
                      color: isCurrent ? colors.primary : colors.onSurface,
                      fontWeight:
                          isCurrent ? FontWeight.w700 : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '¶${heading.paraId}',
                  style: AppTypography.labelSmall.copyWith(
                    fontSize: 11,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}