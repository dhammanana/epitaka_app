import 'package:flutter/material.dart';

import '../../../core/utils/app_localizations.dart';
import '../models/map_data.dart';

/// Shows the places that share one spot on the map and returns the one the
/// user picked (or null when the sheet is dismissed).
///
/// Several names can sit at the same coordinates — a city, a monastery and a
/// river mouth, for example — so a single tap must offer the choice instead of
/// silently opening whichever marker happened to win the hit test.
Future<MapPlace?> showPlacePickerSheet(
  BuildContext context, {
  required List<MapPlace> places,
  String? title,
}) {
  final loc = AppLocalizations.of(context);
  return showModalBottomSheet<MapPlace>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final colors = Theme.of(context).colorScheme;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  title ?? loc.t('Places'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: places.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final place = places[index];
                    final subtitle = place.family.isNotEmpty
                        ? place.family
                        : place.meaning;
                    return ListTile(
                      leading: Icon(
                        place.type == 'group'
                            ? Icons.groups_outlined
                            : Icons.place_outlined,
                        color: colors.primary,
                      ),
                      title: Text(place.name),
                      subtitle: subtitle.isEmpty
                          ? null
                          : Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).pop(place),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
