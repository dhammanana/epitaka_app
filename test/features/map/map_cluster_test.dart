/// Tests for the map's overlapping markers.
///
/// Several names can share one spot on the map (a city and its monastery, a
/// river mouth and the town). A single tap there must offer every name instead
/// of opening whichever marker won the hit test.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/map/models/map_data.dart';
import 'package:epitaka/features/map/widgets/map_geometry.dart';
import 'package:epitaka/features/map/widgets/map_painter.dart';
import 'package:epitaka/features/map/widgets/place_picker_sheet.dart';

Basemap _basemap() => const Basemap(
  west: 60,
  east: 98,
  south: 5,
  north: 37,
  land: [],
  coast: [],
  borders: [],
  rivers: [],
  mountains: [],
  regions: [],
  journeys: [],
  sources: '',
);

MapPlace _place(String slug, String name, {double lat = 25, double lon = 85}) =>
    MapPlace(
      slug: slug,
      name: name,
      type: 'place',
      lat: lat,
      lon: lon,
    );

void main() {
  test('co-located names share one cluster', () {
    final geometry = MapGeometry.build(_basemap());
    final clusters = buildMapClusters(
      places: [
        _place('a', 'Alpha'),
        _place('b', 'Beta'),
        _place('c', 'Gamma', lat: 30, lon: 90),
      ],
      geometry: geometry,
      scale: 1,
      offset: Offset.zero,
      viewport: const Size(1200, 1000),
    );

    expect(clusters, hasLength(2));
    final shared = clusters.firstWhere((c) => !c.isSingle);
    expect(shared.places.map((p) => p.slug), containsAll(['a', 'b']));
  });

  testWidgets('the picker lists every name of the spot', (tester) async {
    MapPlace? picked;
    final places = [_place('a', 'Alpha'), _place('b', 'Beta')];

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizationsDelegate.supportedLocales,
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  picked = await showPlacePickerSheet(
                    context,
                    places: places,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);

    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();

    expect(picked?.slug, 'b');
  });
}
