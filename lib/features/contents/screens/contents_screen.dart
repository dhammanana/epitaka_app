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
import '../../../core/utils/velthuis.dart';
import '../../../shared/widgets/filter_list_nav.dart';
import '../../../shared/widgets/pali_text.dart';
import '../../../shared/widgets/regex_toggle_button.dart';
import '../../../shared/widgets/velthuis_help_icon.dart';
import '../../../shared/widgets/search_box_decoration.dart';
import '../../reader/providers/reader_tabs_provider.dart';
import '../../search/services/regex_search.dart';
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
  late final _nav = FilterListNav(
    boxNode: _searchFocusNode,
    onActivate: (i) {
      if (i < _found.length) _jumpTo(_found[i]);
    },
  );

  /// The headings the filter box found, in list order, for the Down-arrow
  /// path.
  List<HeadingInfo> _found = const [];

  bool _didScrollToCurrent = false;
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

  /// The Rx filter over the heading titles: a regex job, so a runaway
  /// pattern ends as "too slow" instead of freezing (spec K).
  late final _rxFilter = RegexListFilter(() {
    if (mounted) setState(() {});
  });

  @override
  void initState() {
    super.initState();
    _nav.addListener(_onNavChanged);
  }

  void _onNavChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _rxFilter.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _nav.dispose();
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
    final target =
        (index * estimatedItemHeight -
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
              if (normalizePaliFuzzy(
                headings[i].title ?? '',
              ).toLowerCase().contains(query))
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

  void _jumpTo(HeadingInfo heading) {
    // Whether or not a tab is already open for this book, openTab jumps
    // within the existing tab (updating its initialParaId) rather than
    // creating a duplicate — so there's no need to branch on whether one
    // already exists.
    ref
        .read(readerTabsProvider.notifier)
        .openTab(
          ReaderTabInfo(
            bookId: widget.bookId,
            bookName: widget.bookName,
            initialParaId: heading.paraId,
          ),
        );
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
        error: (e, stack) => Center(child: Text(loc.errorMessage('$e'))),
        data: (headings) {
          final currentIndex = _currentHeadingIndex(headings);

          if (_searchQuery.isEmpty &&
              !_didScrollToCurrent &&
              currentIndex >= 0) {
            _didScrollToCurrent = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToIndex(currentIndex);
            });
          }

          final parents = _parentsFor(headings);
          // rx: the raw text stays the pattern; it matches titles with
          // exact diacritics (spec H), in a regex job (spec K). An invalid one
          // filters to nothing.
          final rxOn = ref.watch(contentsRegexProvider);
          final rxText = rxOn ? _searchQuery : '';
          final patternError = rxText.isNotEmpty ? regexError(rxText) : null;
          final rxHits = _rxFilter.hitsFor(
            patternError == null ? rxText : '',
            headings,
            () => [
              for (final h in headings) [(h.title ?? '').toLowerCase()],
            ],
          );
          final query = rxOn
              ? _searchQuery
              : normalizePaliFuzzy(_searchQuery.trim()).toLowerCase();

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
          final visibleIndices = rxText.isNotEmpty
              ? (patternError != null || rxHits == null
                    ? const <int>[]
                    : (rxHits.toList()..sort()))
              : _visibleIndicesFor(headings, parents, query);
          _found = _searchQuery.trim().isEmpty
              ? const []
              : [for (final i in visibleIndices) headings[i]];
          _nav.count = _found.length;
          if (_nav.selected >= _found.length) _nav.selected = 0;

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
                  // The box shows at once, under the title (spec I).
                  child: Column(
                    children: [_buildTitleBar(colors), _buildSearchBar(colors)],
                  ),
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
                    : Focus(
                        focusNode: _nav.listFocus,
                        child: ListView.builder(
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
                            final isCollapsed = _collapsedParaIds.contains(
                              heading.paraId,
                            );

                            return FilterNavRow(
                              selected: _nav.isSelected(i),
                              child: _ContentsRow(
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
                              ),
                            );
                          },
                        ),
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
            // The outline of the book — every section with its study
            // guide — opened as a separate reading view.
            IconButton(
              icon: const Icon(Icons.account_tree_outlined),
              color: colors.onSurfaceVariant,
              tooltip: loc.outline,
              onPressed: () {
                context.push(
                  '/outline/${widget.bookId}?bookName=${Uri.encodeComponent(widget.bookName)}',
                );
              },
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
    final rxOn = ref.watch(contentsRegexProvider);
    final error = rxOn && _searchQuery.isNotEmpty
        ? regexError(_searchQuery)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: kSearchBoxGap),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        // `.m`, `.t`, `.n` are regex: rx keeps them as typed.
        inputFormatters: rxOn ? const [] : const [VelthuisInputFormatter()],
        style: searchBoxTextStyle(context, size: SearchBoxSize.screen),
        decoration: searchBoxDecoration(
          context,
          hintText: loc.searchContents,
          size: SearchBoxSize.screen,
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchQuery.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: loc.clear,
                  onPressed: () => setState(() {
                    _searchQuery = '';
                    _searchController.clear();
                  }),
                ),
              if (!rxOn) const VelthuisHelpIcon(),
              RegexToggleButton(
                on: rxOn,
                onToggle: () =>
                    ref.read(contentsRegexProvider.notifier).state = !rxOn,
              ),
            ],
          ),
          errorText: error != null
              ? loc.invalidPattern(error)
              : rxOn && _rxFilter.isTooSlow(_searchQuery)
              ? loc.patternTooSlow
              : null,
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
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
    final script = ref.watch(settingsProvider.select((s) => s.paliScript));

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
            padding: EdgeInsets.fromLTRB(leftPadding, 12, AppDimensions.md, 12),
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
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
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
