import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/app_localizations.dart';
import '../../../router/app_router.dart';
import '../models/map_data.dart';
import '../providers/map_data_provider.dart';
import '../services/place_text_stats.dart';
import '../widgets/place_mini_map.dart';
import '../widgets/place_occurrences.dart';

/// The page of one name of the texts: a place with its position, or a person,
/// deity, animal or group with its occurrences in the texts.
class PlaceDetailScreen extends ConsumerWidget {
  const PlaceDetailScreen({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final dataAsync = ref.watch(mapDataProvider);

    return dataAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
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
        appBar: AppBar(),
        body: Center(child: Text(loc.t('The map could not be loaded.'))),
      ),
      data: (data) {
        final name = data.nameBySlug(slug);
        if (name == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(loc.t('This name is not on the map.'))),
          );
        }
        final place = name is MapPlace ? name : null;
        return Scaffold(
          appBar: AppBar(
            title: Text(name.name),
            actions: [
              if (place != null)
                IconButton(
                  tooltip: loc.t('Open the map'),
                  icon: const Icon(Icons.map_outlined),
                  onPressed: () => context.push(AppRoutes.mapAt(place.slug)),
                ),
            ],
          ),
          body: _PlaceBody(name: name, place: place),
        );
      },
    );
  }
}

class _PlaceBody extends ConsumerWidget {
  const _PlaceBody({required this.name, required this.place});

  final MapName name;
  final MapPlace? place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final statsAsync = ref.watch(placeTextStatsProvider(name.slug));
    final located = place;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (located != null) ...[
          PlaceMiniMap(
            place: located,
            height: 180,
            onTap: () => context.push(AppRoutes.mapAt(located.slug)),
          ),
          const SizedBox(height: 12),
        ],
        _HeaderCard(name: name, place: place),
        const SizedBox(height: 24),
        Text(
          loc.t('Texts that name it'),
          style: theme.textTheme.titleSmall?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (name.forms.isEmpty)
          _Hint(text: loc.t('This name has no word forms to search for.'))
        else
          statsAsync.when(
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(loc.t('Scanning the texts…')),
                ],
              ),
            ),
            error: (_, _) =>
                _Hint(text: loc.t('The texts could not be searched.')),
            data: (stats) {
              if (stats.isEmpty) {
                return _Hint(
                  text: loc.t('This name was not found in the Pāli text.'),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${loc.t('Mentions')}: ${stats.paragraphs} · '
                    '${stats.bookCount} ${loc.t('book')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  PlaceOccurrences(name: name, stats: stats),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.name, required this.place});

  final MapName name;
  final MapPlace? place;

  String _typeLabel(AppLocalizations loc) => switch (name.type) {
    'person' => loc.t('Person'),
    'deity' => loc.t('Deity'),
    'animal' => loc.t('Animal'),
    'group' => loc.t('People and clans'),
    _ => loc.t('Place'),
  };

  String _accuracyLabel(AppLocalizations loc, int prec) => switch (prec) {
    >= 4 => loc.t('Exact location'),
    3 => loc.t('Approximate location'),
    2 => loc.t('Approximate position'),
    _ => loc.t('In or near another place'),
  };

  static String _coordinate(double value, String positive, String negative) {
    final hemisphere = value >= 0 ? positive : negative;
    return '${value.abs().toStringAsFixed(3)}° $hemisphere';
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final place = this.place;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(switch (name.type) {
                  'person' || 'deity' => Icons.person_outline,
                  'animal' => Icons.pets_outlined,
                  'group' => Icons.groups_outlined,
                  _ => Icons.place_outlined,
                }, color: colors.primary),
                const SizedBox(width: 8),
                Text(
                  _typeLabel(loc),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.primary,
                  ),
                ),
              ],
            ),
            if (name.family.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Field(label: loc.t('Family'), value: name.family),
            ],
            if (name.meaning.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(name.meaning, style: theme.textTheme.bodyMedium),
            ],
            if (name.dppn.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Field(label: 'DPPN', value: name.dppn),
            ],
            if (place != null) ...[
              const SizedBox(height: 12),
              _Field(
                label: loc.t('Coordinates'),
                value:
                    '${_coordinate(place.lat, 'N', 'S')}, '
                    '${_coordinate(place.lon, 'E', 'W')}',
              ),
              const SizedBox(height: 12),
              _Field(
                label: loc.t('Accuracy'),
                value: _accuracyLabel(loc, place.prec),
              ),
              if (place.area) ...[
                const SizedBox(height: 12),
                _Field(
                  label: loc.t('Overview'),
                  value: loc.t('In or near another place'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}
