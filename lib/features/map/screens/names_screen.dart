import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/app_localizations.dart';
import '../../../router/app_router.dart';
import '../models/map_data.dart';
import '../providers/map_data_provider.dart';
import '../widgets/name_type_icon.dart';

/// How the name lists are ordered.
enum NameSort { occurrences, alphabetical }

/// Every name of the texts, in tabs by kind, with how often it occurs.
///
/// The lists are built from the bundled gazetteer, so they open without a
/// database scan; only tapping a name loads its page.
class NamesScreen extends ConsumerStatefulWidget {
  const NamesScreen({super.key});

  @override
  ConsumerState<NamesScreen> createState() => _NamesScreenState();
}

class _NamesScreenState extends ConsumerState<NamesScreen> {
  NameSort _sort = NameSort.occurrences;

  static const _tabs = <(String, String)>[
    ('place', 'Places'),
    ('person', 'People'),
    ('deity', 'Deity'),
    ('animal', 'Animals'),
    ('group', 'People and clans'),
  ];

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final dataAsync = ref.watch(mapDataProvider);

    return dataAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(loc.t('Names of the texts'))),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(loc.t('Loading the map…')),
            ],
          ),
        ),
      ),
      error: (_, _) => Scaffold(
        appBar: AppBar(title: Text(loc.t('Names of the texts'))),
        body: Center(child: Text(loc.t('The map could not be loaded.'))),
      ),
      data: (data) {
        return DefaultTabController(
          length: _tabs.length,
          child: Scaffold(
            appBar: AppBar(
              title: Text(loc.t('Names of the texts')),
              actions: [
                PopupMenuButton<NameSort>(
                  tooltip: loc.t('Sort by'),
                  icon: Icon(
                    _sort == NameSort.occurrences
                        ? Icons.sort
                        : Icons.sort_by_alpha,
                  ),
                  initialValue: _sort,
                  onSelected: (sort) => setState(() => _sort = sort),
                  itemBuilder: (context) => [
                    CheckedPopupMenuItem(
                      value: NameSort.occurrences,
                      checked: _sort == NameSort.occurrences,
                      child: Text(loc.t('Occurrences')),
                    ),
                    CheckedPopupMenuItem(
                      value: NameSort.alphabetical,
                      checked: _sort == NameSort.alphabetical,
                      child: Text(loc.t('Alphabetical')),
                    ),
                  ],
                ),
              ],
              bottom: TabBar(
                isScrollable: true,
                tabs: [for (final tab in _tabs) Tab(text: loc.t(tab.$2))],
              ),
            ),
            body: TabBarView(
              children: [
                for (final tab in _tabs)
                  _NameList(names: _forType(data, tab.$1)),
              ],
            ),
          ),
        );
      },
    );
  }

  List<MapName> _forType(MapData data, String type) {
    final names = data.all.where((name) => name.type == type).toList();
    switch (_sort) {
      case NameSort.occurrences:
        names.sort((a, b) {
          final byCount = b.freq.compareTo(a.freq);
          if (byCount != 0) return byCount;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      case NameSort.alphabetical:
        names.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    }
    return names;
  }
}

class _NameList extends StatelessWidget {
  const _NameList({required this.names});

  final List<MapName> names;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    if (names.isEmpty) {
      return Center(child: Text(loc.t('No names found')));
    }
    return ListView.separated(
      itemCount: names.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final name = names[index];
        final subtitle = name.family.isNotEmpty ? name.family : name.meaning;
        return ListTile(
          leading: Icon(mapNameIcon(name.type)),
          title: Text(name.name),
          subtitle: subtitle.isEmpty
              ? null
              : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: Tooltip(
            message: loc.t('Mentions'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${name.freq}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          onTap: () => context.push(AppRoutes.mapPlaceAt(name.slug)),
        );
      },
    );
  }
}
