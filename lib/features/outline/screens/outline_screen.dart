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
import '../../../router/app_router.dart';
import '../../../shared/widgets/pali_text.dart';
import '../models/outline_models.dart';
import '../providers/outline_provider.dart';
import '../widgets/outline_section_sheet.dart';

class OutlineScreen extends ConsumerStatefulWidget {
  final String bookId;
  final String bookName;

  const OutlineScreen({
    super.key,
    required this.bookId,
    this.bookName = '',
  });

  @override
  ConsumerState<OutlineScreen> createState() => _OutlineScreenState();
}

class _OutlineScreenState extends ConsumerState<OutlineScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  bool _searchActive = false;
  String _searchQuery = '';

  /// Indices of collapsed vagga groups.
  final Set<int> _collapsedGroups = {};

  /// Indices of collapsed sutta rows (only meaningful when their vagga is
  /// open) — used to keep long suttas tidy.
  final Set<int> _collapsedSuttas = {};

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchActive = !_searchActive;
      if (!_searchActive) {
        _searchQuery = '';
        _searchController.clear();
      }
    });
    if (_searchActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocusNode.requestFocus();
      });
    }
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
    final query = _searchQuery.trim().isEmpty
        ? ''
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
            if (normalizePaliFuzzy(item.title)
                .toLowerCase()
                .contains(query)) {
              rows.add(_ItemRow(item: item));
            }
          }
          continue;
        }

        final visibleItems = suttaCollapsed
            ? <OutlineItem>[]
            : sutta.items;
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
              ref.watch(settingsProvider).paliScript,
              style: AppTypography.headlineSmall.copyWith(color: colors.primary),
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
        actions: [
          IconButton(
            icon: Icon(_searchActive ? Icons.close : Icons.search),
            tooltip: loc.searchContents,
            onPressed: _toggleSearch,
          ),
        ],
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
          final total = groups.fold<int>(
            0,
            (sum, g) => sum + g.itemCount,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Intro header ─────────────────────────────────────
              _OutlineHeader(
                bookName: widget.bookName,
                sectionCount: total,
                searchActive: _searchActive,
                searchController: _searchController,
                searchFocusNode: _searchFocusNode,
                onSearchChanged: (v) => setState(() => _searchQuery = v),
                onCloseSearch: _toggleSearch,
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
                        itemBuilder: (context, i) =>
                            _buildRow(rows[i], colors),
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
  final bool searchActive;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onCloseSearch;

  const _OutlineHeader({
    required this.bookName,
    required this.sectionCount,
    required this.searchActive,
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearchChanged,
    required this.onCloseSearch,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final script = ref.watch(settingsProvider).paliScript;
    final isPhone = Mobile.isPhone(context);

    final pad = isPhone ? AppDimensions.md : AppDimensions.lg;

    return Padding(
      padding: EdgeInsets.fromLTRB(pad, AppDimensions.md, pad, AppDimensions.sm),
      child: searchActive
          ? TextField(
              controller: searchController,
              focusNode: searchFocusNode,
              autofocus: true,
              style: AppTypography.bodyTranslation.copyWith(
                color: colors.onSurface,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: loc.searchContents,
                hintStyle: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onCloseSearch,
                ),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  borderSide: BorderSide(color: colors.outlineVariant),
                ),
              ),
              onChanged: onSearchChanged,
            )
          : Column(
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
    final script = ref.watch(settingsProvider).paliScript;

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
              child: PaliTextStatic(
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
