/// The book's outline — a full-screen "separated book" reading view.
///
/// Shows every section of a book grouped vagga → sutta, with the same
/// structure as the web outline page. Design goals:
///   * readable at a glance — numbered items, Pāli titles in the user's
///     script, groups collapsible so long books stay navigable;
///   * fast to scan — search filters items while browsing;
///   * one tap to read — tapping a section opens the quickview sheet
///     (excerpt, then "Open in Reader"), and study guides are one tab away.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/pali_search_utils.dart';
import '../../../core/utils/platform_info.dart';
import '../../../core/utils/velthuis.dart';
import '../../../router/app_router.dart';
import '../../../shared/widgets/pali_text.dart';
import '../../../shared/widgets/regex_toggle_button.dart';
import '../../../shared/widgets/velthuis_help_icon.dart';
import '../../../shared/widgets/search_box_decoration.dart';
import '../../search/services/regex_search.dart';
import '../models/outline_models.dart';
import '../providers/outline_provider.dart';
import '../widgets/outline_section_sheet.dart';

class OutlineScreen extends ConsumerStatefulWidget {
  final String bookId;
  final String bookName;

  const OutlineScreen({super.key, required this.bookId, this.bookName = ''});

  @override
  ConsumerState<OutlineScreen> createState() => _OutlineScreenState();
}

class _OutlineScreenState extends ConsumerState<OutlineScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  String _searchQuery = '';

  /// Indices of collapsed vagga groups.
  final Set<int> _collapsedGroups = {};

  /// Indices of collapsed sutta rows (only meaningful when their vagga is
  /// open) — used to keep long suttas tidy.
  final Set<int> _collapsedSuttas = {};

  /// The Rx filter over the section titles: a regex job, so a runaway
  /// pattern ends as "too slow" instead of freezing (spec K).
  late final _rxFilter = RegexListFilter(() {
    if (mounted) setState(() {});
  });

  @override
  void dispose() {
    _rxFilter.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _openItem(OutlineItem item) {
    showOutlineSectionSheet(
      context,
      ref,
      bookId: widget.bookId,
      bookName: widget.bookName,
      item: item,
    );
  }

  /// Flat list of rows to render, honouring collapse state and search.
  List<_Row> _buildRows(List<OutlineGroup> groups) {
    // rx: the raw text stays the pattern; it matches titles with exact
    // diacritics (spec H), in a regex job (spec K). An invalid one filters
    // to nothing.
    final rxOn = ref.watch(outlineRegexProvider);
    final rxText = rxOn && _searchQuery.trim().isNotEmpty ? _searchQuery : '';
    final valid = rxText.isNotEmpty && regexError(rxText) == null;
    final flat = [
      for (final g in groups)
        for (final s in g.suttas) ...s.items,
    ];
    final hits = _rxFilter.hitsFor(
      valid ? rxText : '',
      groups,
      () => [
        for (final item in flat) [item.title.toLowerCase()],
      ],
    );
    if (rxText.isNotEmpty && (!valid || hits == null)) return const [];
    final rxItems = rxText.isEmpty
        ? null
        : (Set<OutlineItem>.identity()
            ..addAll([for (final i in hits!) flat[i]]));
    final query = _searchQuery.trim().isEmpty
        ? ''
        : rxOn
        ? _searchQuery
        : normalizePaliFuzzy(_searchQuery.trim()).toLowerCase();

    final rows = <_Row>[];
    for (var gi = 0; gi < groups.length; gi++) {
      final group = groups[gi];
      final groupCollapsed = _collapsedGroups.contains(gi);

      if (query.isEmpty) {
        rows.add(_GroupRow(group: group, index: gi));
        if (groupCollapsed) continue;
      }

      for (var si = 0; si < group.suttas.length; si++) {
        final sutta = group.suttas[si];
        final suttaCollapsed = _collapsedSuttas.contains(_suttaKey(gi, si));

        // Search: flat match list, no group/sutta headers.
        if (query.isNotEmpty) {
          for (final item in sutta.items) {
            final matches = rxItems != null
                ? rxItems.contains(item)
                : normalizePaliFuzzy(item.title).toLowerCase().contains(query);
            if (matches) rows.add(_ItemRow(item: item));
          }
          continue;
        }

        final visibleItems = suttaCollapsed ? <OutlineItem>[] : sutta.items;
        if (sutta.title.isNotEmpty && visibleItems.isNotEmpty) {
          rows.add(_SuttaRow(title: sutta.title));
        } else if (sutta.title.isEmpty && visibleItems.isNotEmpty) {
          // Unnamed sutta (e.g. a level-2 item listing directly under the
          // group) — render items flat.
        }
        rows.addAll(visibleItems.map((i) => _ItemRow(item: i)));
      }
    }
    return rows;
  }

  int _suttaKey(int gi, int si) => gi * 1000 + si;

  @override
  Widget build(BuildContext context) {
    final outlineAsync = ref.watch(outlineProvider(widget.bookId));
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.library);
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            PaliTextStatic(
              widget.bookName.isEmpty ? widget.bookId : widget.bookName,
              ref.watch(settingsProvider.select((s) => s.paliScript)),
              style: AppTypography.headlineSmall.copyWith(
                color: colors.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              loc.outline,
              style: AppTypography.labelSmall.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: outlineAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stack) => Center(child: Text(loc.errorMessage('$e'))),
        data: (groups) {
          if (groups.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  loc.noSectionsFound,
                  textAlign: TextAlign.center,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            );
          }

          final rows = _buildRows(groups);
          final total = groups.fold<int>(0, (sum, g) => sum + g.itemCount);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Intro header ─────────────────────────────────────
              _OutlineHeader(
                bookName: widget.bookName,
                sectionCount: total,
                searchController: _searchController,
                searchFocusNode: _searchFocusNode,
                onSearchChanged: (v) => setState(() => _searchQuery = v),
                onClearSearch: _clearSearch,
                patternTooSlow: _rxFilter.isTooSlow(_searchQuery),
              ),
              Divider(color: colors.outlineVariant, height: 1),
              // ── Rows ─────────────────────────────────────────────
              Expanded(
                child: rows.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.trim().isEmpty
                              ? loc.noSectionsFound
                              : loc.noMatchingSections,
                          style: AppTypography.labelSmall.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(
                          left: AppDimensions.md,
                          right: AppDimensions.md,
                          bottom: AppDimensions.xxl,
                        ),
                        itemCount: rows.length,
                        itemBuilder: (context, i) => _buildRow(rows[i], colors),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRow(_Row row, ColorScheme colors) {
    return switch (row) {
      _GroupRow(:final group, :final index) => _GroupHeader(
        title: group.title.isEmpty ? widget.bookName : group.title,
        count: group.itemCount,
        collapsed: _collapsedGroups.contains(index),
        colors: colors,
        onTap: () {
          setState(() {
            if (!_collapsedGroups.remove(index)) {
              _collapsedGroups.add(index);
            }
          });
        },
      ),
      _SuttaRow(:final title) => _SuttaLabel(title: title, colors: colors),
      _ItemRow(:final item) => _ItemTile(
        item: item,
        colors: colors,
        onTap: () => _openItem(item),
      ),
    };
  }
}

/// A row in the flattened outline list.
sealed class _Row {}

class _GroupRow extends _Row {
  final OutlineGroup group;
  final int index;
  _GroupRow({required this.group, required this.index});
}

class _SuttaRow extends _Row {
  final String title;
  _SuttaRow({required this.title});
}

class _ItemRow extends _Row {
  final OutlineItem item;
  _ItemRow({required this.item});
}

/// Intro block: the outline title + section count + search field.
class _OutlineHeader extends ConsumerWidget {
  final String bookName;
  final int sectionCount;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;

  /// The Rx pattern ran past its time limit.
  final bool patternTooSlow;

  const _OutlineHeader({
    required this.bookName,
    required this.sectionCount,
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearchChanged,
    required this.onClearSearch,
    this.patternTooSlow = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final script = ref.watch(settingsProvider.select((s) => s.paliScript));
    final isPhone = Mobile.isPhone(context);
    final rxOn = ref.watch(outlineRegexProvider);
    final error = rxOn && searchController.text.trim().isNotEmpty
        ? regexError(searchController.text)
        : null;

    final pad = isPhone ? AppDimensions.md : AppDimensions.lg;

    final searching = searchController.text.isNotEmpty;
    // The box shows at once (spec I); the intro below it shows while the
    // box is empty, as it did while search was closed.
    final box = Padding(
      padding: searchBoxPadding(SearchBoxSize.screen),
      child: TextField(
        controller: searchController,
        focusNode: searchFocusNode,
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
              if (searching)
                IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: loc.clear,
                  onPressed: onClearSearch,
                ),
              RegexToggleButton(
                on: rxOn,
                onToggle: () =>
                    ref.read(outlineRegexProvider.notifier).state = !rxOn,
              ),
            ],
          ),
          errorText: error != null
              ? loc.invalidPattern(error)
              : rxOn && patternTooSlow
              ? loc.patternTooSlow
              : null,
        ),
        onChanged: onSearchChanged,
      ),
    );
    // One tree whether or not the box has text: switching between "box"
    // and "box plus intro" would rebuild the field and drop its focus.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        box,
        if (!searching)
          Padding(
            padding: EdgeInsets.fromLTRB(pad, 0, pad, AppDimensions.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.outline,
                  style: AppTypography.headlineSmall.copyWith(
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
              if (!rxOn) const VelthuisHelpIcon(),
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: PaliTextStatic(
                        bookName,
                        script,
                        style: AppTypography.bodyPali.copyWith(
                          color: colors.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusFull,
                        ),
                      ),
                      child: Text(
                        loc.sectionsCount(sectionCount),
                        style: AppTypography.labelSmall.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  loc.outlineHint,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Collapsible vagga (level-2) header.
class _GroupHeader extends StatelessWidget {
  final String title;
  final int count;
  final bool collapsed;
  final ColorScheme colors;
  final VoidCallback onTap;

  const _GroupHeader({
    required this.title,
    required this.count,
    required this.collapsed,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.sm),
      child: Material(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.sm,
              vertical: 10,
            ),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: collapsed ? -0.25 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.expand_more,
                    size: 20,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.labelMedium.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '$count',
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
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

/// Small-caps sutta (level-4) label.
class _SuttaLabel extends StatelessWidget {
  final String title;
  final ColorScheme colors;

  const _SuttaLabel({required this.title, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.md, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.labelSmall.copyWith(
          color: colors.primary.withValues(alpha: 0.8),
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// One numbered section row — tap to preview.
class _ItemTile extends ConsumerWidget {
  final OutlineItem item;
  final ColorScheme colors;
  final VoidCallback onTap;

  const _ItemTile({
    required this.item,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final script = ref.watch(settingsProvider.select((s) => s.paliScript));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Number badge (para id for numbered items).
            Container(
              margin: const EdgeInsets.only(top: 1),
              constraints: const BoxConstraints(minWidth: 30),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Text(
                '${item.paraId}',
                textAlign: TextAlign.center,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: item.translated
                  ? Text(
                      item.title.isEmpty ? '—' : item.title,
                      style: AppTypography.bodyTranslation.copyWith(
                        color: colors.onSurface,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    )
                  : PaliTextStatic(
                      item.title.isEmpty ? '—' : item.title,
                      script,
                      style: AppTypography.bodyTranslation.copyWith(
                        color: colors.onSurface,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.play_circle_outline,
              size: 18,
              color: colors.outlineVariant,
            ),
          ],
        ),
      ),
    );
  }
}
