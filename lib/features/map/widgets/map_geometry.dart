import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/map_data.dart';

/// The basemap projected once into "world" coordinates, so panning and
/// zooming only change the canvas transform instead of rebuilding paths.
class MapGeometry {
  MapGeometry._({
    required this.basemap,
    required this.worldSize,
    required this.land,
    required this.coast,
    required this.borders,
    required this.mountains,
    required this.rivers,
    required this.regions,
    required this.journeys,
  });

  /// Width of the world canvas in logical units.
  static const double worldWidth = 1000;

  final Basemap basemap;
  final Size worldSize;

  final Path land;
  final Path coast;
  final Path borders;
  final Path mountains;

  /// River paths, widest rank first.
  final List<MapRiverPath> rivers;

  /// Filled regions.
  final List<MapRegionPath> regions;

  /// Routes with their stops.
  final List<MapJourneyPath> journeys;

  /// Project a position into world coordinates.
  Offset project(double lon, double lat) {
    final spanLon = math.max(0.0001, basemap.east - basemap.west);
    final spanLat = math.max(0.0001, basemap.north - basemap.south);
    final x = (lon - basemap.west) / spanLon * worldSize.width;
    final y = (basemap.north - lat) / spanLat * worldSize.height;
    return Offset(x, y);
  }

  factory MapGeometry.build(Basemap basemap) {
    final spanLon = math.max(0.0001, basemap.east - basemap.west);
    final spanLat = math.max(0.0001, basemap.north - basemap.south);
    final midLat = (basemap.north + basemap.south) / 2;
    // Longitude degrees shrink with latitude: keep the shapes true.
    final cosLat = math.max(0.2, math.cos(midLat * math.pi / 180));
    final worldSize = Size(
      worldWidth,
      worldWidth * (spanLat / (spanLon * cosLat)),
    );

    MapGeometry project() => MapGeometry._(
      basemap: basemap,
      worldSize: worldSize,
      land: Path(),
      coast: Path(),
      borders: Path(),
      mountains: Path(),
      rivers: const [],
      regions: const [],
      journeys: const [],
    );

    // A throwaway instance provides [project] while the real paths are built.
    final helper = project();
    final projectPoint = helper.project;

    Path polygons(List<List<MapPoint>> rings) {
      final path = Path();
      for (final ring in rings) {
        if (ring.length < 2) continue;
        final first = projectPoint(ring.first.lon, ring.first.lat);
        path.moveTo(first.dx, first.dy);
        for (var i = 1; i < ring.length; i++) {
          final p = projectPoint(ring[i].lon, ring[i].lat);
          path.lineTo(p.dx, p.dy);
        }
        path.close();
      }
      return path;
    }

    Path polylines(List<List<MapPoint>> lines) {
      final path = Path();
      for (final line in lines) {
        if (line.length < 2) continue;
        final first = projectPoint(line.first.lon, line.first.lat);
        path.moveTo(first.dx, first.dy);
        for (var i = 1; i < line.length; i++) {
          final p = projectPoint(line[i].lon, line[i].lat);
          path.lineTo(p.dx, p.dy);
        }
      }
      return path;
    }

    final rivers = <MapRiverPath>[
      for (final river in basemap.rivers)
        MapRiverPath(rank: river.rank, path: polylines(river.lines)),
    ];

    final regions = <MapRegionPath>[
      for (final region in basemap.regions)
        MapRegionPath(
          name: region.name,
          color: Color(region.color),
          path: polygons([region.ring]),
          anchor: _ringCenter(region.ring, projectPoint),
        ),
    ];

    final journeys = <MapJourneyPath>[
      for (final journey in basemap.journeys)
        MapJourneyPath(
          path: polylines([
            [for (final s in journey.stops) MapPoint(s.lon, s.lat)],
          ]),
          stops: [
            for (final s in journey.stops)
              MapJourneyStop(
                name: s.name,
                slug: s.slug,
                lon: s.lon,
                lat: s.lat,
              ),
          ],
        ),
    ];

    return MapGeometry._(
      basemap: basemap,
      worldSize: worldSize,
      land: polygons(basemap.land),
      coast: polylines(basemap.coast),
      borders: polylines(basemap.borders),
      mountains: polygons(basemap.mountains),
      rivers: rivers,
      regions: regions,
      journeys: journeys,
    );
  }
}

class MapRiverPath {
  const MapRiverPath({required this.rank, required this.path});

  final int rank;
  final Path path;
}

class MapRegionPath {
  const MapRegionPath({
    required this.name,
    required this.color,
    required this.path,
    required this.anchor,
  });

  final String name;
  final Color color;
  final Path path;

  /// Where the region's name is drawn, in world coordinates.
  final Offset anchor;
}

/// The mean of a ring's projected points, used as the label position.
Offset _ringCenter(
  List<MapPoint> ring,
  Offset Function(double lon, double lat) project,
) {
  if (ring.isEmpty) return Offset.zero;
  var x = 0.0;
  var y = 0.0;
  for (final point in ring) {
    final projected = project(point.lon, point.lat);
    x += projected.dx;
    y += projected.dy;
  }
  return Offset(x / ring.length, y / ring.length);
}

class MapJourneyPath {
  const MapJourneyPath({required this.path, required this.stops});

  final Path path;
  final List<MapJourneyStop> stops;
}

/// The colours of the map, light and dark.
class MapPalette {
  const MapPalette({
    required this.water,
    required this.land,
    required this.mountain,
    required this.coast,
    required this.border,
    required this.river,
    required this.marker,
    required this.markerText,
    required this.label,
    required this.labelHalo,
    required this.route,
  });

  final Color water;
  final Color land;
  final Color mountain;
  final Color coast;
  final Color border;
  final Color river;
  final Color marker;
  final Color markerText;
  final Color label;
  final Color labelHalo;
  final Color route;

  static const light = MapPalette(
    water: Color(0xFFDCE7F0),
    land: Color(0xFFF4F0E4),
    mountain: Color(0xFFE3D9C4),
    coast: Color(0xFF8FA3B5),
    border: Color(0x997B8794),
    river: Color(0xFF8AB6D6),
    marker: Color(0xFFB03030),
    markerText: Color(0xFFFFFFFF),
    label: Color(0xFF2B2B2B),
    labelHalo: Color(0xF2FFFFFF),
    route: Color(0xFF7A4FB0),
  );

  static const dark = MapPalette(
    water: Color(0xFF1B2733),
    land: Color(0xFF2A2F28),
    mountain: Color(0xFF3A362B),
    coast: Color(0xFF55636F),
    border: Color(0x88576270),
    river: Color(0xFF3E6B8A),
    marker: Color(0xFFE06A5F),
    markerText: Color(0xFF1A1A1A),
    label: Color(0xFFEDEDED),
    labelHalo: Color(0xF21A1A1A),
    route: Color(0xFFB491E0),
  );

  static MapPalette of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}
