import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/pali_script_converter.dart';
import '../../../core/utils/pali_search_utils.dart';
import '../../../shared/widgets/pali_text.dart';
import '../../reader/providers/reader_tabs_provider.dart';
import '../models/outline_models.dart';
import '../providers/outline_provider.dart';
import 'outline_section_sheet.dart';

class OutlinePanel extends ConsumerStatefulWidget {
  final bool autoFocus;

  const OutlinePanel({super.key, this.autoFocus = false});

  @override
  ConsumerState<OutlinePanel> createState() => _OutlinePanelState();
}

class _OutlinePanelState extends ConsumerState<OutlinePanel> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  bool _searchActive = false;
  String _searchQuery = '';
  final Set<int> _collapsedGroups = {};
  final Set<int> _collapsedSuttas = {};

  @override
  void initState() {
    super.initState();
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _searchActive = true);
        _searchFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  int _suttaKey(int gi, int si) => gi * 1000 + si;

  void _openItem(String bookId, String bookName, OutlineItem item) {
    showOutlineSectionSheet(
      context,
      ref,
      bookId: bookId,
      bookName: bookName,
      item: item,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    final script = ref.watch(settingsProvider.select((s) => s.paliScript));
    final activeTab = ref.watch(readerTabsProvider.select((s) => s.activeTab));

    if (activeTab == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.lg),
          child: Text(
            loc.noBooksOpenShort,
            style: AppTypography.labelSmall.copyWith(
              color: colors.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final outlineAsync = ref.watch(outlineProvider(activeTab.bookId));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.sm,
            0,
            AppDimensions.sm,
            0,
          ),
          child: _searchActive
              ? TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  autofocus: true,
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: loc.searchContents,
                    isDense: true,
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        setState(() {
                          _searchActive = false;
                          _searchQuery = '';
                          _searchController.clear();
                        });
                      },
                    ),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                )
              : Row(
                  children: [
                    Expanded(
                      child: Text(
                        loc.outline,
                        style: AppTypography.labelMedium.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search, size: 18),
                      color: colors.onSurfaceVariant,
                      onPressed: () => setState(() => _searchActive = true),
                    ),
                  ],
                ),
        ),
        Divider(color: colors.outlineVariant, height: 1),
        Expanded(
          child: outlineAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(loc.errorMessage('$e'))),
            data: (groups) {
              if (groups.isEmpty) {
                return Center(
                  child: Text(
                    loc.noSectionsFound,
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                );
              }
              final query = normalizePaliFuzzy(
                _searchQuery.trim(),
              ).toLowerCase();
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.xs,
                  AppDimensions.sm,
                  AppDimensions.sm,
                  AppDimensions.sm,
                ),
                itemCount: _rowCount(groups, query),
                itemBuilder: (context, i) => _buildRow(
                  groups,
                  query,
                  i,
                  colors,
                  script,
                  activeTab.bookId,
                  activeTab.bookName,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  int _rowCount(List<OutlineGroup> groups, String query) {
    var n = 0;
    for (var gi = 0; gi < groups.length; gi++) {
      final group = groups[gi];
      if (query.isEmpty) {
        n++;
        if (_collapsedGroups.contains(gi)) continue;
      }
      for (var si = 0; si < group.suttas.length; si++) {
        final sutta = group.suttas[si];
        if (query.isNotEmpty) {
          for (final item in sutta.items) {
            if (normalizePaliFuzzy(item.title).toLowerCase().contains(query)) {
              n++;
            }
          }
          continue;
        }
        if (_collapsedSuttas.contains(_suttaKey(gi, si))) continue;
        if (sutta.title.isNotEmpty) n++;
        n += sutta.items.length;
      }
    }
    return n;
  }

  Widget _buildRow(
    List<OutlineGroup> groups,
    String query,
    int index,
    ColorScheme colors,
    Script script,
    String bookId,
    String bookName,
  ) {
    var n = 0;
    for (var gi = 0; gi < groups.length; gi++) {
      final group = groups[gi];
      if (query.isEmpty) {
        if (n++ == index) {
          final collapsed = _collapsedGroups.contains(gi);
          return _PanelGroupHeader(
            title: group.title.isEmpty ? bookName : group.title,
            count: group.itemCount,
            collapsed: collapsed,
            colors: colors,
            onTap: () {
              setState(() {
                if (!collapsed) {
                  _collapsedGroups.add(gi);
                } else {
                  _collapsedGroups.remove(gi);
                }
              });
            },
          );
        }
        if (_collapsedGroups.contains(gi)) continue;
      }
      for (var si = 0; si < group.suttas.length; si++) {
        final sutta = group.suttas[si];
        if (query.isNotEmpty) {
          for (final item in sutta.items) {
            if (!normalizePaliFuzzy(item.title).toLowerCase().contains(query)) {
              continue;
            }
            if (n++ == index) {
              return _PanelItemTile(
                item: item,
                colors: colors,
                script: script,
                onTap: () => _openItem(bookId, bookName, item),
              );
            }
          }
          continue;
        }
        if (_collapsedSuttas.contains(_suttaKey(gi, si))) continue;
        if (sutta.title.isNotEmpty) {
          if (n++ == index) {
            return _PanelSuttaLabel(title: sutta.title, colors: colors);
          }
        }
        for (final item in sutta.items) {
          if (n++ == index) {
            return _PanelItemTile(
              item: item,
              colors: colors,
              script: script,
              onTap: () => _openItem(bookId, bookName, item),
            );
          }
        }
      }
    }
    return const SizedBox.shrink();
  }
}

class _PanelGroupHeader extends StatelessWidget {
  final String title;
  final int count;
  final bool collapsed;
  final ColorScheme colors;
  final VoidCallback onTap;

  const _PanelGroupHeader({
    required this.title,
    required this.count,
    required this.collapsed,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Material(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Icon(
                  collapsed ? Icons.chevron_right : Icons.expand_more,
                  size: 16,
                  color: colors.primary,
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.labelSmall.copyWith(
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
                    fontSize: 11,
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

class _PanelSuttaLabel extends StatelessWidget {
  final String title;
  final ColorScheme colors;

  const _PanelSuttaLabel({required this.title, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2, left: 4),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.labelSmall.copyWith(
          color: colors.primary.withValues(alpha: 0.8),
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _PanelItemTile extends StatelessWidget {
  final OutlineItem item;
  final ColorScheme colors;
  final Script script;
  final VoidCallback onTap;

  const _PanelItemTile({
    required this.item,
    required this.colors,
    required this.script,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = item.title.isEmpty ? '—' : item.title;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 1),
              constraints: const BoxConstraints(minWidth: 28),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Text(
                '${item.paraId}',
                textAlign: TextAlign.center,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: item.translated
                  ? Text(
                      title,
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.onSurface,
                        height: 1.4,
                      ),
                    )
                  : PaliTextStatic(
                      title,
                      script,
                      style: AppTypography.labelSmall.copyWith(
                        color: colors.onSurface,
                        height: 1.4,
                      ),
                    ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.play_circle_outline,
              size: 16,
              color: colors.outlineVariant,
            ),
          ],
        ),
      ),
    );
  }
}
