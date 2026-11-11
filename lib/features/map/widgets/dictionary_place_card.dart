import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_localizations.dart';
import '../../dpd/providers/dpd_lookup_provider.dart';
import '../models/map_data.dart';
import '../providers/map_data_provider.dart';
import 'name_type_icon.dart';
import 'place_mini_map.dart';

/// A card shown above the dictionary definitions when the looked-up word is
/// also a name of the texts: a place (with a small map), a person, a deity, an
/// animal or a group.
///
/// It is self-hiding: when the word has no map entry the widget renders
/// nothing, so callers can always insert it as the `leading` item.
class DictionaryPlaceCard extends ConsumerWidget {
  const DictionaryPlaceCard({
    required this.lookup,
    required this.onOpen,
    super.key,
  });

  final DpdLookup lookup;

  /// Opens the name: the map for a located place, the name's page otherwise.
  final ValueChanged<MapName> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(mapDataProvider).valueOrNull;
    if (data == null) return const SizedBox.shrink();

    final name = _match(data);
    if (name == null) return const SizedBox.shrink();

    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final place = name is MapPlace ? name : null;

    final subtitle = [
      _typeLabel(loc, name.type),
      if (name.family.isNotEmpty) name.family,
      if (place == null && name.meaning.isNotEmpty) name.meaning,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (place != null)
              PlaceMiniMap(
                place: place,
                height: 140,
                borderRadius: BorderRadius.zero,
                onTap: () => onOpen(place),
              ),
            InkWell(
              onTap: place == null ? () => onOpen(name) : null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Row(
                  children: [
                    Icon(mapNameIcon(name.type), color: colors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name.name, style: theme.textTheme.titleSmall),
                          if (subtitle.isNotEmpty)
                            Text(
                              subtitle,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (place != null)
                      TextButton.icon(
                        onPressed: () => onOpen(place),
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: Text(loc.t('Open the map')),
                      )
                    else
                      Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(AppLocalizations loc, String type) => switch (type) {
    'person' => loc.t('Person'),
    'deity' => loc.t('Deity'),
    'animal' => loc.t('Animal'),
    'group' => loc.t('People and clans'),
    _ => loc.t('Place'),
  };

  MapName? _match(MapData data) {
    final ids = <int>{};
    final lemmas = <String>{};
    for (final entry in lookup.headwords) {
      final headword = entry.headword;
      if (headword.id > 0) ids.add(headword.id);
      final lemma = headword.lemma1.toLowerCase().trim();
      if (lemma.isNotEmpty) lemmas.add(lemma);
    }

    for (final name in data.all) {
      if (ids.contains(name.dpd)) return name;
    }
    for (final name in data.all) {
      if (lemmas.contains(name.name.toLowerCase().trim())) return name;
    }
    return null;
  }
}
