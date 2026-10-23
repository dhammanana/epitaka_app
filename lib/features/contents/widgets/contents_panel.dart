import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/app_models.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/pali_search_utils.dart';
import '../../../core/utils/responsive_breakpoint.dart';
import '../../../core/utils/velthuis.dart';
import '../../../shared/providers/side_panel_provider.dart';
import '../../../shared/widgets/filter_list_nav.dart';
import '../../../shared/widgets/pali_text.dart';
import '../../../shared/widgets/search_box_actions.dart';
import '../../../shared/widgets/search_box_decoration.dart';
import '../../reader/providers/reader_tabs_provider.dart';
import '../../search/services/regex_search.dart';
import '../providers/contents_provider.dart';

/// A panel showing the table of contents for a book.
///
/// Used inside the left sidebar on desktop, or via [showModalBottomSheet]
/// on mobile.
class ContentsPanel extends ConsumerStatefulWidget {
  final String? bookId;
  final String? bookName;
  final int? currentParaId;

  /// When true, tapping a heading pops the screen (for full-page mode).
  final bool autoPopOnTap;

  /// Put the cursor in the search box once the panel shows.
  final bool autoFocus;

  const ContentsPanel({
    super.key,
    this.bookId,
    this.bookName,
    this.currentParaId,
    this.autoPopOnTap = false,
    this.autoFocus = false,
  });

  @override
  ConsumerState<ContentsPanel> createState() => _ContentsPanelState();
}

class _ContentsPanelState extends ConsumerState<ContentsPanel> {
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

  final Set<int> _collapsedParaIds = {};

  // Memoization
  List<HeadingInfo>? _cachedHeadings;
  List<int?>? _cachedParents;
  List<HeadingInfo>? _cachedVisibleHeadings;
  int? _cachedVisibleVersion;
  String? _cachedVisibleQuery;
  List<int>? _cachedVisibleIndices;
  int _collapseVersion = 0;

  /// Resolve the effective bookId from widget or active tab.
  String get _effectiveBookId {
    if (widget.bookId != null) return widget.bookId!;
    final activeTab = ref.read(readerTabsProvider).activeTab;
    return activeTab?.bookId ?? '';
  }

  String get _effectiveBookName {
    if (widget.bookName != null) return widget.bookName!;
    final activeTab = ref.read(readerTabsProvider).activeTab;
    return activeTab?.bookName ?? _effectiveBookId;
  }

  int? get _effectiveCurrentParaId {
    if (widget.currentParaId != null) return widget.currentParaId;
    final activeTab = ref.read(readerTabsProvider).activeTab;
    return activeTab?.currentParaId;
  }

  @override
  void initState() {
    super.initState();
    _nav.addListener(_onNavChanged);
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    }
  }

  /// The Rx filter over the heading titles: a regex job, so a runaway
  /// pattern ends as "too slow" instead of freezing (spec K).
  late final _rxFilter = RegexListFilter(() {
    if (mounted) setState(() {});
  });

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

  int _currentHeadingIndex(List<HeadingInfo> headings) {
    final currentParaId = _effectiveCurrentParaId;
    if (currentParaId == null) return -1;
    int result = -1;
    for (var i = 0; i < headings.length; i++) {
      if (headings[i].paraId <= currentParaId) {
        result = i;
      } else {
        break;
      }
    }
    return result;
  }

  void _scrollToIndex(int index) {
    if (index < 0 || !_scrollController.hasClients) return;
    const estimatedItemHeight = 52.0;
    final viewportHeight = _scrollController.position.viewportDimension;
    final target =
        (index * estimatedItemHeight -
                (viewportHeight / 2) +
                (estimatedItemHeight / 2))
            .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.jumpTo(target);
  }

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

  bool _hasChildren(int index, List<HeadingInfo> headings) {
    if (index + 1 >= headings.length) return false;
    return (headings[index + 1].level ?? 1) > (headings[index].level ?? 1);
  }

  bool _isVisible(int index, List<int?> parents, List<HeadingInfo> headings) {
    int? p = parents[index];
    while (p != null) {
      if (_collapsedParaIds.contains(headings[p].paraId)) return false;
      p = parents[p];
    }
    return true;
  }

  List<int?> _parentsFor(List<HeadingInfo> headings) {
    if (!identical(_cachedHeadings, headings)) {
      _cachedHeadings = headings;
      _cachedParents = _computeParents(headings);
    }
    return _cachedParents!;
  }

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
    ref
        .read(readerTabsProvider.notifier)
        .openTab(
          ReaderTabInfo(
            bookId: _effectiveBookId,
            bookName: _effectiveBookName,
            initialParaId: heading.paraId,
          ),
        );
    if (widget.autoPopOnTap && context.mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final contentsAsync = ref.watch(contentsProvider(_effectiveBookId));
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    return contentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, stack) => Center(child: Text(loc.errorMessage('$e'))),
      data: (headings) {
        final currentIndex = _currentHeadingIndex(headings);
        // Inside panel it's always compact

        if (_searchQuery.isEmpty && !_didScrollToCurrent && currentIndex >= 0) {
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
        final indentUnit = AppDimensions.sm;
        final rowLeftPadding = AppDimensions.sm;
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
            // Search bar (compact)
            Padding(
              padding: searchBoxPadding(SearchBoxSize.panel),
              // The box is always there, like Library and Search: the
              // sidebar already names the panel (spec I).
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      // `.m`, `.t`, `.n` are regex: rx keeps them as typed.
                      inputFormatters: rxOn
                          ? const []
                          : const [VelthuisInputFormatter()],
                      style: searchBoxTextStyle(context),
                      decoration: searchBoxDecoration(
                        context,
                        hintText: loc.searchContents,
                        suffixIcon: SearchBoxSuffixActions(
                          showClear: _searchQuery.isNotEmpty,
                          onClear: () => setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                          }),
                          regexOn: rxOn,
                          onToggleRegex: () =>
                              ref.read(contentsRegexProvider.notifier).state =
                                  !rxOn,
                        ),
                        errorText: patternError != null
                            ? loc.invalidPattern(patternError)
                            : rxOn && _rxFilter.isTooSlow(_searchQuery)
                            ? loc.patternTooSlow
                            : null,
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  // The outline is the full outline of the book —
                  // every section with its study guide — opened as a
                  // separate reading view.
                  IconButton(
                    icon: const Icon(Icons.account_tree_outlined, size: 18),
                    color: colors.onSurfaceVariant,
                    tooltip: loc.outline,
                    onPressed: () {
                      if (_effectiveBookId.isEmpty) return;
                      if (ResponsiveBreakpoint.isDesktop(context)) {
                        ref
                            .read(sidePanelProvider.notifier)
                            .toggle(SidePanelType.outline);
                        return;
                      }
                      context.push(
                        '/outline/$_effectiveBookId?bookName=${Uri.encodeComponent(_effectiveBookName)}',
                      );
                    },
                  ),
                ],
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
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    )
                  : Focus(
                      focusNode: _nav.listFocus,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(
                          AppDimensions.xs,
                          AppDimensions.sm,
                          AppDimensions.sm,
                          AppDimensions.sm,
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
    );
  }
}

/// Single row in the table of contents.
class _ContentsRow extends ConsumerWidget {
  final HeadingInfo heading;
  final int indent;
  final double indentUnit;
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
    final settings = ref.watch(settingsProvider);
    final script = settings.paliScript;
    // Match the reader's Pāli text size so the TOC aligns with the book.
    final paliFontSize = settings.typography.pali.fontSize;
    return Padding(
      padding: EdgeInsets.only(left: indent * indentUnit),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isCurrent
              ? colors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          child: Padding(
            padding: EdgeInsets.fromLTRB(leftPadding, 10, AppDimensions.sm, 10),
            child: Row(
              children: [
                if (hasChildren)
                  GestureDetector(
                    onTap: onToggleCollapse,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: Icon(
                        isCollapsed ? Icons.chevron_right : Icons.expand_more,
                        size: 16,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 20),
                Expanded(
                  child: PaliTextStatic(
                    heading.title ?? loc.untitled,
                    script,
                    style: AppTypography.labelSmall.copyWith(
                      color: isCurrent ? colors.primary : colors.onSurface,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                      fontSize: paliFontSize * 0.8,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
