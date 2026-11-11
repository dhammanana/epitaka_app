// Builds the offline map assets from tipitaka.app's committed names data.
//
//   dart run tool/build_map_data.dart [--src ../tipitaka.app] [--out assets/map]
//
// Writes:
//   assets/map/places.json  — the geolocated names (places and peoples/clans)
//   assets/map/names.json   — the names with no point (people, deities, animals
//                             and places the gazetteer does not locate)
//   assets/map/basemap.json — coast, borders, rivers, mountains, regions
//
// Both files are committed, so the app needs no network and no extra package.
// Re-run after the source data changes.
import 'dart:convert';
import 'dart:io';

const _assetVersion = 1;

/// Families that describe an area rather than a point (mirrors the source
/// feature: countries, kingdoms, regions … are drawn as regions, not pins).
final _areaFamily = RegExp(
  'countries|continents|country|kingdom|district|region|province|janapada',
  caseSensitive: false,
);

Future<void> main(List<String> args) async {
  final src = _arg(args, '--src') ?? '../tipitaka_app';
  final outDir = Directory(_arg(args, '--out') ?? 'assets/map');

  final namesDir = Directory('$src/data/names');
  final entitiesFile = File('${namesDir.path}/entities.tsv');
  final geoFile = File('${namesDir.path}/geo.tsv');
  final formsFile = File('${namesDir.path}/forms.tsv');
  final basemapFile = File('$src/web/src/assets/map/basemap.json');

  for (final file in [entitiesFile, geoFile, formsFile, basemapFile]) {
    if (!file.existsSync()) {
      stderr.writeln('Missing ${file.path}');
      exitCode = 1;
      return;
    }
  }

  final entities = _readTsv(entitiesFile);
  final geo = _readTsv(geoFile);
  final forms = _formsBySlug(_readTsv(formsFile));

  final places = <Map<String, Object?>>[];
  final located = <String>{};
  for (final row in geo.values) {
    final slug = row['slug'];
    final entity = entities[slug];
    if (entity == null || slug == null || slug.isEmpty) continue;
    located.add(slug);

    final name = _displayName(entity['lemma'] ?? slug);
    final lat = double.tryParse(row['lat'] ?? '');
    final lon = double.tryParse(row['lon'] ?? '');
    if (lat == null || lon == null) continue;

    final dpd = int.tryParse(entity['dpd'] ?? '') ?? 0;
    final freq = int.tryParse(entity['freq'] ?? '') ?? 0;
    final family = entity['family'] ?? '';
    final dppn = entity['dppn'] ?? '';
    final meaning = entity['meaning'] ?? '';

    places.add({
      'slug': slug,
      'name': name,
      'type': entity['type'] ?? 'place',
      'family': family,
      if (dppn.isNotEmpty) 'dppn': dppn,
      'lat': lat,
      'lon': lon,
      'prec': int.tryParse(row['prec'] ?? '') ?? 4,
      'area': _areaFamily.hasMatch(family),
      if (dpd > 0) 'dpd': dpd,
      if (meaning.isNotEmpty) 'meaning': meaning,
      'freq': freq,
      if (forms[slug] != null) 'forms': forms[slug]!,
    });
  }
  places.sort((a, b) => (a['slug'] as String).compareTo(b['slug'] as String));

  // Every name the map cannot draw still has a page: the people, deities and
  // animals of the texts, and the places the gazetteer leaves unlocated.
  final names = <Map<String, Object?>>[];
  for (final entity in entities.values) {
    final slug = entity['slug'];
    if (slug == null || slug.isEmpty || located.contains(slug)) continue;
    final type = entity['type'] ?? '';
    if (!_pageTypes.contains(type)) continue;
    names.add(_nameJson(entity, forms[slug]));
  }
  names.sort((a, b) => (a['slug'] as String).compareTo(b['slug'] as String));

  final basemap =
      jsonDecode(basemapFile.readAsStringSync()) as Map<String, Object?>;
  // The geo.tsv positions come from SuttaCentral's map and the DPPN's
  // location tags; the source's credit line names the first only.
  basemap['sources'] =
      '${basemap['sources']} · DPPN (CC BY-SA): place positions';
  final payload = <String, Object?>{
    'version': _assetVersion,
    'bbox': basemap['bbox'],
    'places': places,
  };

  outDir.createSync(recursive: true);
  File('${outDir.path}/places.json').writeAsStringSync(jsonEncode(payload));
  File(
    '${outDir.path}/names.json',
  ).writeAsStringSync(jsonEncode({'version': _assetVersion, 'names': names}));
  File('${outDir.path}/basemap.json').writeAsStringSync(jsonEncode(basemap));

  final placeCount = places.where((p) => p['type'] == 'place').length;
  final areaCount = places.where((p) => p['area'] == true).length;
  final withForms = places.where((p) => p.containsKey('forms')).length;
  final bytes = File('${outDir.path}/places.json').lengthSync();
  final nameBytes = File('${outDir.path}/names.json').lengthSync();
  stdout.writeln(
    'Wrote ${places.length} located names ($placeCount places, '
    '${places.length - placeCount} groups, $areaCount areas, '
    '$withForms with inflections) → ${outDir.path} '
    '(${(bytes / 1024).round()} KB places.json)',
  );
  stdout.writeln(
    'Wrote ${names.length} unlocated names '
    '(${(nameBytes / 1024).round()} KB names.json)',
  );
}

/// Types that get a page even without a point on the map.
const _pageTypes = {'place', 'group', 'person', 'deity', 'animal'};

Map<String, Object?> _nameJson(
  Map<String, String> entity,
  List<String>? entityForms,
) {
  final dpd = int.tryParse(entity['dpd'] ?? '') ?? 0;
  final freq = int.tryParse(entity['freq'] ?? '') ?? 0;
  final dppn = entity['dppn'] ?? '';
  final meaning = entity['meaning'] ?? '';
  return {
    'slug': entity['slug'],
    'name': _displayName(entity['lemma'] ?? entity['slug']!),
    'type': entity['type'] ?? 'place',
    'family': entity['family'] ?? '',
    if (dppn.isNotEmpty) 'dppn': dppn,
    if (meaning.isNotEmpty) 'meaning': meaning,
    if (dpd > 0) 'dpd': dpd,
    'freq': freq,
    'forms': ?entityForms,
  };
}

String? _arg(List<String> args, String name) {
  final i = args.indexOf(name);
  if (i < 0 || i + 1 >= args.length) return null;
  return args[i + 1];
}

/// Rows keyed by the first column (the slug for entities, geo and forms are
/// handled separately).
Map<String, Map<String, String>> _readTsv(File file) {
  final lines = file.readAsLinesSync();
  if (lines.isEmpty) return {};
  final header = lines.first.split('\t');
  final rows = <String, Map<String, String>>{};
  for (var i = 1; i < lines.length; i++) {
    final line = lines[i];
    if (line.isEmpty) continue;
    final cells = line.split('\t');
    final row = <String, String>{};
    for (var c = 0; c < header.length && c < cells.length; c++) {
      row[header[c]] = cells[c];
    }
    final key = row[header.first];
    if (key != null && key.isNotEmpty) rows[key] = row;
  }
  return rows;
}

/// The inflected word forms of every name, from `forms.tsv`.
///
/// A form's `entities` cell is a comma-separated list, because one written
/// form can belong to more than one homonym; a form is kept for every name
/// it can mean. The regex pattern needs the forms escaped, which happens when
/// the scan is built, not here.
Map<String, List<String>> _formsBySlug(Map<String, Map<String, String>> rows) {
  final bySlug = <String, List<String>>{};
  for (final row in rows.values) {
    final form = row['form'];
    if (form == null || form.isEmpty) continue;
    final slugs = (row['entities'] ?? '').split(',');
    for (final slug in slugs) {
      if (slug.isEmpty) continue;
      (bySlug[slug] ??= <String>[]).add(form);
    }
  }
  for (final forms in bySlug.values) {
    forms.sort((a, b) => b.length.compareTo(a.length));
  }
  return bySlug;
}

/// `sāvatthī` stays as it is; the homonym number DPD appends (`ānanda 2`) is
/// not part of a name on the map.
String _displayName(String lemma) =>
    lemma.replaceFirst(RegExp(r'\s+\d+$'), '').trim();
