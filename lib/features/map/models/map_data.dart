import 'dart:convert';

/// A name of the texts, as shown on the map or on its own page.
///
/// Located names are [MapPlace]s; every other name (people, deities, animals,
/// groups, and the places the gazetteer does not locate) is a plain [MapName].
class MapName {
  const MapName({
    required this.slug,
    required this.name,
    required this.type,
    this.family = '',
    this.meaning = '',
    this.dppn = '',
    this.dpd = 0,
    this.freq = 0,
    this.forms = const [],
  });

  /// The unique identifier of the name.
  final String slug;

  /// The display name (the lemma, without the homonym number).
  final String name;

  /// `place`, `group`, `person`, `deity` or `animal`.
  final String type;

  /// The gazetteer family, e.g. "names of rivers".
  final String family;

  /// The dictionary gloss, when the source has one.
  final String meaning;

  /// The DPPN reference, when the source has one.
  final String dppn;

  /// The DPD headword id this name belongs to (0 when unknown).
  final int dpd;

  /// How often the name occurs in the texts.
  final int freq;

  /// The inflected word forms used to search the texts.
  final List<String> forms;

  bool get isPlace => type == 'place';
  bool get isGroup => type == 'group';
  bool get isPerson => type == 'person';
  bool get isDeity => type == 'deity';
  bool get isAnimal => type == 'animal';

  /// True for the names that have no point on the map.
  bool get isUnlocated => this is! MapPlace;

  factory MapName.fromJson(Map<String, dynamic> json) => MapName(
    slug: json['slug'] as String,
    name: json['name'] as String,
    type: json['type'] as String? ?? 'place',
    family: json['family'] as String? ?? '',
    meaning: json['meaning'] as String? ?? '',
    dppn: json['dppn'] as String? ?? '',
    dpd: (json['dpd'] as num?)?.toInt() ?? 0,
    freq: (json['freq'] as num?)?.toInt() ?? 0,
    forms: _forms(json),
  );

  static List<String> _forms(Map<String, dynamic> json) {
    final raw = json['forms'];
    if (raw is! List) return const [];
    return [
      for (final f in raw)
        if (f is String && f.isNotEmpty) f,
    ];
  }
}

/// A name the map can draw: a place, people or clan with a position.
class MapPlace extends MapName {
  const MapPlace({
    required super.slug,
    required super.name,
    required super.type,
    required this.lat,
    required this.lon,
    this.prec = 4,
    this.area = false,
    super.family = '',
    super.meaning,
    super.dppn,
    super.dpd,
    super.freq,
    super.forms,
  });

  final double lat;
  final double lon;

  /// Position accuracy: 4 exact, 3 approximate location, 2 approximate
  /// position, 1 in or near another place.
  final int prec;

  /// True when the name describes an area (country, kingdom, region …).
  final bool area;

  factory MapPlace.fromJson(Map<String, dynamic> json) => MapPlace(
    slug: json['slug'] as String,
    name: json['name'] as String,
    type: json['type'] as String? ?? 'place',
    family: json['family'] as String? ?? '',
    meaning: json['meaning'] as String? ?? '',
    dppn: json['dppn'] as String? ?? '',
    dpd: (json['dpd'] as num?)?.toInt() ?? 0,
    freq: (json['freq'] as num?)?.toInt() ?? 0,
    forms: MapName._forms(json),
    lat: (json['lat'] as num).toDouble(),
    lon: (json['lon'] as num).toDouble(),
    prec: (json['prec'] as num?)?.toInt() ?? 4,
    area: json['area'] == true,
  );
}

/// One `[lon, lat]` position.
class MapPoint {
  const MapPoint(this.lon, this.lat);

  final double lon;
  final double lat;

  static MapPoint? fromJson(Object? json) {
    if (json is! List || json.length < 2) return null;
    final lon = json[0];
    final lat = json[1];
    if (lon is! num || lat is! num) return null;
    return MapPoint(lon.toDouble(), lat.toDouble());
  }
}

/// A river: its rank (width) and one or more polylines.
class MapRiver {
  const MapRiver({required this.rank, required this.lines});

  final int rank;
  final List<List<MapPoint>> lines;
}

/// A filled region (a janapada or kingdom).
class MapRegion {
  const MapRegion({
    required this.name,
    required this.kind,
    required this.color,
    required this.ring,
  });

  final String name;
  final String kind;
  final int color;
  final List<MapPoint> ring;
}

/// A labelled route through the texts (e.g. the Buddha's last journey).
class MapJourney {
  const MapJourney({required this.id, required this.key, required this.stops});

  final String id;
  final String key;
  final List<MapJourneyStop> stops;
}

class MapJourneyStop {
  const MapJourneyStop({
    required this.name,
    required this.slug,
    required this.lon,
    required this.lat,
  });

  final String name;
  final String slug;
  final double lon;
  final double lat;
}

/// The base geography drawn under the markers.
class Basemap {
  const Basemap({
    required this.west,
    required this.east,
    required this.south,
    required this.north,
    required this.land,
    required this.coast,
    required this.borders,
    required this.rivers,
    required this.mountains,
    required this.regions,
    required this.journeys,
    required this.sources,
  });

  final double west;
  final double east;
  final double south;
  final double north;

  /// Land polygons.
  final List<List<MapPoint>> land;

  /// Coastline polylines.
  final List<List<MapPoint>> coast;

  /// Border polylines.
  final List<List<MapPoint>> borders;

  /// Rivers, widest first.
  final List<MapRiver> rivers;

  /// Mountain-range polygons.
  final List<List<MapPoint>> mountains;

  /// Filled regions.
  final List<MapRegion> regions;

  /// Routes through the texts.
  final List<MapJourney> journeys;

  /// The credit line shown under the map.
  final String sources;

  factory Basemap.fromJson(Map<String, dynamic> json) {
    final bbox = json['bbox'] as Map<String, dynamic>? ?? const {};
    List<List<MapPoint>> rings(Object? raw) {
      if (raw is! List) return const [];
      return [
        for (final ring in raw)
          if (ring is List) [for (final p in ring) ?MapPoint.fromJson(p)],
      ];
    }

    final rivers = <MapRiver>[];
    for (final raw in json['rivers'] as List<dynamic>? ?? const []) {
      if (raw is! Map<String, dynamic>) continue;
      rivers.add(
        MapRiver(
          rank: (raw['rank'] as num?)?.toInt() ?? 1,
          lines: rings(raw['lines']),
        ),
      );
    }

    final mountains = <List<MapPoint>>[];
    for (final raw in json['mountains'] as List<dynamic>? ?? const []) {
      if (raw is! Map<String, dynamic>) continue;
      mountains.addAll(rings(raw['rings']));
    }

    final regions = <MapRegion>[];
    for (final raw in json['regions'] as List<dynamic>? ?? const []) {
      if (raw is! Map<String, dynamic>) continue;
      final ring = raw['ring'];
      if (ring is! List) continue;
      final points = [for (final p in ring) ?MapPoint.fromJson(p)];
      if (points.length < 3) continue;
      regions.add(
        MapRegion(
          name: raw['name'] as String? ?? '',
          kind: raw['kind'] as String? ?? '',
          color: _parseColor(raw['color'] as String?),
          ring: points,
        ),
      );
    }

    final journeys = <MapJourney>[];
    for (final raw in json['journeys'] as List<dynamic>? ?? const []) {
      if (raw is! Map<String, dynamic>) continue;
      final stops = <MapJourneyStop>[];
      for (final s in raw['stops'] as List<dynamic>? ?? const []) {
        if (s is! Map<String, dynamic>) continue;
        final at = s['at'];
        if (at is! List || at.length < 2) continue;
        stops.add(
          MapJourneyStop(
            name: s['name'] as String? ?? '',
            slug: s['slug'] as String? ?? '',
            lon: (at[0] as num).toDouble(),
            lat: (at[1] as num).toDouble(),
          ),
        );
      }
      journeys.add(
        MapJourney(
          id: raw['id'] as String? ?? '',
          key: raw['key'] as String? ?? '',
          stops: stops,
        ),
      );
    }

    return Basemap(
      west: (bbox['w'] as num?)?.toDouble() ?? 60,
      east: (bbox['e'] as num?)?.toDouble() ?? 98,
      south: (bbox['s'] as num?)?.toDouble() ?? 5,
      north: (bbox['n'] as num?)?.toDouble() ?? 37,
      land: rings(json['land']),
      coast: rings(json['coast']),
      borders: rings(json['borders']),
      rivers: rivers,
      mountains: mountains,
      regions: regions,
      journeys: journeys,
      sources: json['sources'] as String? ?? '',
    );
  }

  static int _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return 0x00000000;
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(cleaned, radix: 16) ?? 0;
    return cleaned.length <= 6 ? 0xFF000000 | value : value;
  }
}

/// Everything the map feature needs, parsed once from the bundled assets.
class MapData {
  MapData({required this.places, required this.names, required this.basemap})
    : _bySlug = {
        for (final p in places) p.slug: p,
        for (final n in names) n.slug: n,
      };

  /// The located names, drawn as markers.
  final List<MapPlace> places;

  /// The names without a point: people, deities, animals, groups and the
  /// places the gazetteer leaves unlocated.
  final List<MapName> names;

  final Basemap basemap;

  final Map<String, MapName> _bySlug;

  MapName? nameBySlug(String slug) => _bySlug[slug];

  MapPlace? placeBySlug(String slug) {
    final found = _bySlug[slug];
    return found is MapPlace ? found : null;
  }

  /// The name belonging to the DPD headword [dpd], if any.
  ///
  /// Located names are checked first, so a place wins over the people of the
  /// same name when the dictionary entry belongs to both.
  MapName? nameByDpd(int dpd) {
    if (dpd <= 0) return null;
    for (final place in places) {
      if (place.dpd == dpd) return place;
    }
    for (final name in names) {
      if (name.dpd == dpd) return name;
    }
    return null;
  }

  /// The located name belonging to the DPD headword [dpd], if any.
  MapPlace? placeByDpd(int dpd) {
    final name = nameByDpd(dpd);
    return name is MapPlace ? name : null;
  }

  /// Every name, located first, for search and listings.
  List<MapName> get all => [...places, ...names];

  static MapData fromAssets({
    required String placesJson,
    required String namesJson,
    required String basemapJson,
  }) {
    final placesPayload = jsonDecode(placesJson) as Map<String, dynamic>;
    final namesPayload = jsonDecode(namesJson) as Map<String, dynamic>;
    final basemapPayload = jsonDecode(basemapJson) as Map<String, dynamic>;

    final places = <MapPlace>[
      for (final raw in placesPayload['places'] as List<dynamic>? ?? const [])
        if (raw is Map<String, dynamic>) MapPlace.fromJson(raw),
    ];
    final names = <MapName>[
      for (final raw in namesPayload['names'] as List<dynamic>? ?? const [])
        if (raw is Map<String, dynamic>)
          if (raw['lat'] == null || raw['lon'] == null) MapName.fromJson(raw),
    ];

    return MapData(
      places: places,
      names: names,
      basemap: Basemap.fromJson(basemapPayload),
    );
  }
}
