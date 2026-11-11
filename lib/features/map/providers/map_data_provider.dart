import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/map_data.dart';
import '../widgets/map_geometry.dart';

/// Loads the bundled map assets once and parses them into [MapData].
///
/// The assets are committed (see `tool/build_map_data.dart`), so the map is
/// fully offline: no network request and no database access.
final mapDataProvider = FutureProvider<MapData>((ref) async {
  final payloads = await Future.wait([
    rootBundle.loadString('assets/map/places.json'),
    rootBundle.loadString('assets/map/names.json'),
    rootBundle.loadString('assets/map/basemap.json'),
  ]);
  return MapData.fromAssets(
    placesJson: payloads[0],
    namesJson: payloads[1],
    basemapJson: payloads[2],
  );
});

/// The basemap projected once and shared by the map and the small map cards,
/// so opening a dictionary entry does not rebuild every coastline path.
final mapGeometryProvider = FutureProvider<MapGeometry>((ref) async {
  final data = await ref.watch(mapDataProvider.future);
  return MapGeometry.build(data.basemap);
});
