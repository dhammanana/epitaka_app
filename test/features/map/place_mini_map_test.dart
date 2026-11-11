import 'package:epitaka/features/map/models/map_data.dart';
import 'package:epitaka/features/map/providers/map_data_provider.dart';
import 'package:epitaka/features/map/widgets/map_geometry.dart';
import 'package:epitaka/features/map/widgets/place_mini_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the small map draws a place from the bundled assets', (
    tester,
  ) async {
    // Asset bundles only complete inside the test's real async zone; loading
    // them in fake async would hang before the widget is ever built.
    final payloads = (await tester.runAsync(
      () => Future.wait([
        rootBundle.loadString('assets/map/places.json'),
        rootBundle.loadString('assets/map/names.json'),
        rootBundle.loadString('assets/map/basemap.json'),
      ]),
    ))!;
    final data = MapData.fromAssets(
      placesJson: payloads[0],
      namesJson: payloads[1],
      basemapJson: payloads[2],
    );
    final geometry = MapGeometry.build(data.basemap);
    final place = data.places.first;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapDataProvider.overrideWith((ref) async => data),
          mapGeometryProvider.overrideWith((ref) async => geometry),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(width: 360, child: PlaceMiniMap(place: place)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(PlaceMiniMap), findsOneWidget);
    expect(find.text(place.name), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
