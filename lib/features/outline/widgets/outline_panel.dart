import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_localizations.dart';
import '../../../core/utils/pali_script_converter.dart';
import '../../../core/utils/pali_search_utils.dart';
import '../../../core/utils/velthuis.dart';
import '../../../shared/widgets/filter_list_nav.dart';
import '../../../shared/widgets/pali_text.dart';
import '../../../shared/widgets/regex_toggle_button.dart';
import '../../../shared/widgets/velthuis_help_icon.dart';
import '../../../shared/widgets/search_box_decoration.dart';
import '../../reader/providers/reader_tabs_provider.dart';
import '../../search/services/regex_search.dart';
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
  late final _nav = FilterListNav(
    boxNode: _searchFocusNode,
    onActivate: (i) {
      final tab = ref.read(readerTabsProvider).activeTab;
      if (tab != null && i < _found.length) {
        _openItem(tab.bookId, tab.bookName, _found[i]);
      }
    },
  );

  /// The sections the filter box found, in list order, for the Down-arrow
  /// path.
  List<OutlineItem> _found = const [];

  String _searchQuery = '';
  final Set<int> _collapsedGroups = {};
  final Set<int> _collapsedSuttas = {};

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

  void _onNavChanged() {
    if (mounted) setState(() {});
  }

  /// The Rx filter over the section titles: a regex job, so a runaway
  /// pattern ends as "too slow" instead of freezing (spec K).
  late final _rxFilter = RegexListFilter(() {
    if (mounted) setState(() {});
  });

  @override
  void dispose() {
    _rxFilter.dispose();
    _searchController.dispose();
    _nav.dispose();
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
    // rx: the raw text stays the pattern; it matches titles with exact
    // diacritics (spec H). An invalid one filters to nothing.
    final rxOn = ref.watch(outlineRegexProvider);
    final patternError = rxOn && _searchQuery.trim().isNotEmpty
        ? regexError(_searchQuery)
        : null;

    return Column(
      children: [
        Padding(
          padding: searchBoxPadding(SearchBoxSize.panel),
          // The box is always there, like Library and Search: the sidebar
          // already names the panel (spec I).
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            // `.m`, `.t`, `.n` are regex: rx keeps them as typed.
            inputFormatters: rxOn ? const [] : const [VelthuisInputFormatter()],
            style: searchBoxTextStyle(context),
            decoration: searchBoxDecoration(
              context,
              hintText: loc.searchContents,
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
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
                        ref.read(outlineRegexProvider.notifier).state = !rxOn,
                  ),
                ],
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
              final query = _searchQuery.trim().isEmpty
                  ? ''
                  : rxOn
                  ? _searchQuery
                  : normalizePaliFuzzy(_searchQuery.trim()).toLowerCase();
              // rx runs in a regex job (spec K); until it answers, and for
              // an invalid pattern, nothing matches.
              final rxText = rxOn ? query : '';
              final flat = [
                for (final g in groups)
                  for (final s in g.suttas) ...s.items,
              ];
              final hits = _rxFilter.hitsFor(
                rxText.isNotEmpty && patternError == null ? rxText : '',
                groups,
                () => [
                  for (final item in flat) [item.title.toLowerCase()],
                ],
              );
              final rxItems = Set<OutlineItem>.identity()
                ..addAll([
                  if (patternError == null && hits != null)
                    for (final i in hits) flat[i],
                ]);
              bool matches(OutlineItem item) => rxText.isNotEmpty
                  ? rxItems.contains(item)
                  : normalizePaliFuzzy(
                      item.title,
                    ).toLowerCase().contains(query);
              // With a query every row is a found section, in this order.
              _found = query.isEmpty
                  ? const []
                  : [
                      for (final item in flat)
                        if (matches(item)) item,
                    ];
              _nav.count = _found.length;
              if (_nav.selected >= _found.length) _nav.selected = 0;
              return Focus(
                focusNode: _nav.listFocus,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.xs,
                    AppDimensions.sm,
                    AppDimensions.sm,
                    AppDimensions.sm,
                  ),
                  itemCount: _rowCount(groups, query, matches),
                  itemBuilder: (context, i) => FilterNavRow(
                    selected: _nav.isSelected(i),
                    child: _buildRow(
                      groups,
                      query,
                      matches,
                      i,
                      colors,
                      script,
                      activeTab.bookId,
                      activeTab.bookName,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  int _rowCount(
    List<OutlineGroup> groups,
    String query,
    bool Function(OutlineItem item) matches,
  ) {
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
            if (matches(item)) n++;
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
    bool Function(OutlineItem item) matches,
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
            if (!matches(item)) continue;
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
