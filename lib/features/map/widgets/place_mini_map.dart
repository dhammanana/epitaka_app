import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/map_data.dart';
import '../providers/map_data_provider.dart';
import 'map_geometry.dart';
import 'map_painter.dart';

/// A small map around one place, drawn with the same basemap as the map
/// screen. It is the preview shown in the dictionary and on the place page;
/// tapping it opens the full map at this place.
class PlaceMiniMap extends ConsumerWidget {
  const PlaceMiniMap({
    required this.place,
    this.height = 150,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    super.key,
  });

  final MapPlace place;
  final double height;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;

  /// Half the window shown around the place, in degrees.
  static const double _halfLon = 0.45;
  static const double _halfLat = 0.32;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(mapDataProvider).valueOrNull;
    final geometry = ref.watch(mapGeometryProvider).valueOrNull;
    final palette = MapPalette.of(Theme.of(context).brightness);

    final child = geometry == null
        ? ColoredBox(
            color: palette.water,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        : LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              final world = geometry.project(place.lon, place.lat);
              final basemap = geometry.basemap;
              final spanLon = math.max(0.0001, basemap.east - basemap.west);
              final spanLat = math.max(0.0001, basemap.north - basemap.south);
              final worldPerLon = geometry.worldSize.width / spanLon;
              final worldPerLat = geometry.worldSize.height / spanLat;
              final scale = math.min(
                size.width / (2 * _halfLon * worldPerLon),
                size.height / (2 * _halfLat * worldPerLat),
              );
              final offset = size.center(Offset.zero) - world * scale;

              // The neighbours give the preview its context; the focus is
              // added last so it is drawn on top of them.
              final clusters = <MapCluster>[];
              for (final other in data?.places ?? const <MapPlace>[]) {
                if (other.slug == place.slug) continue;
                if ((other.lon - place.lon).abs() > _halfLon * 1.3 ||
                    (other.lat - place.lat).abs() > _halfLat * 1.3) {
                  continue;
                }
                clusters.add(
                  MapCluster(
                    places: [other],
                    center:
                        geometry.project(other.lon, other.lat) * scale + offset,
                  ),
                );
                if (clusters.length >= 120) break;
              }
              clusters.add(
                MapCluster(places: [place], center: world * scale + offset),
              );

              return CustomPaint(
                size: size,
                painter: MapPainter(
                  geometry: geometry,
                  scale: scale,
                  offset: offset,
                  palette: palette,
                  clusters: clusters,
                  showLabels: false,
                  showRegionLabels: false,
                  highlightSlug: place.slug,
                ),
              );
            },
          );

    // The parent may be unbounded in height (a Column, ListView or sliver),
    // so the card gives the preview its own box; the Stack then expands into
    // it instead of asking for constraints that do not exist.
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            // The name of the place belongs with its position: the card and
            // the dictionary show both together.
            Positioned(
              left: 8,
              bottom: 8,
              child: IgnorePointer(
                child: Builder(
                  builder: (context) {
                    final colors = Theme.of(context).colorScheme;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        place.name,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (onTap != null)
              Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap),
              ),
          ],
        ),
      ),
    );
  }
}
