// Pre-builds the DPD folded-search norm table inside a release
// dpd-dictionary.db BEFORE it is zipped and uploaded.
//
// Run from epitaka_app/:
//   dart run tool/build_dpd_norm.dart [path-to-dpd-dictionary.db]
//
// Why: the app builds this table on first launch when it is missing
// (DpdDictionaryDatabase.ensureNormTable). For 1.28M lookup rows that takes
// 10-20 minutes on a slow dual-core machine, during which the dictionary
// stalls and the whole app janks. Shipping the table prebuilt (plus its
// index) reduces first-launch work to a near-instant count check.
//
// After running this, re-zip and upload:
//   (cd <data-dir> && zip -q -r dpd-dictionary.zip dpd-dictionary.db)
//   gh release upload latest dpd-dictionary.zip --clobber
// and record the SHA-256 in assets/translations_manifest.json
// (core.dpd_dictionary.checksum).

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:epitaka/core/database/dpd_dictionary_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart run tool/build_dpd_norm.dart <dpd-dictionary.db>');
    exit(2);
  }
  final dbPath = args.first;
  if (!File(dbPath).existsSync()) {
    print('Not found: $dbPath');
    exit(2);
  }

  final sw = Stopwatch()..start();
  var lastPct = -1;
  final ok = await DpdDictionaryDatabase.ensureNormTable(
    dbPath,
    onProgress: (p) {
      final pct = (p * 100).floor();
      if (pct != lastPct && (pct % 5 == 0 || pct == 100)) {
        lastPct = pct;
        print('  … ${(p * 100).toStringAsFixed(1)}%');
      }
    },
  );
  sw.stop();
  if (!ok) {
    print('FAILED: norm table incomplete after ${sw.elapsed}.');
    exit(1);
  }
  print('OK in ${sw.elapsed}. Verifying...');

  final db = sqlite3.open(dbPath);
  try {
    final lookup =
        db.select('SELECT COUNT(*) c FROM dpd_lookup').first['c'] as int;
    final tables = db.select(
      "SELECT name FROM sqlite_master WHERE type='table' "
      'AND name LIKE \'dpd_lookup_norm%\' ORDER BY name',
    );
    for (final t in tables) {
      final name = t['name'] as String;
      final n = db.select('SELECT COUNT(*) c FROM "$name"').first['c'] as int;
      print('  $name: $n rows (dpd_lookup: $lookup)');
    }
    // Junk-key audit: the release DB has shipped empty / leading-space /
    // sentence-length keys; they pollute prefix suggestions.
    final junkEmpty = db
        .select(
          "SELECT COUNT(*) c FROM dpd_lookup WHERE lookup_key = '' "
          "OR TRIM(lookup_key) = ''",
        )
        .first['c'] as int;
    final junkLeadSpace = db
        .select(
          "SELECT COUNT(*) c FROM dpd_lookup WHERE lookup_key LIKE ' %'",
        )
        .first['c'] as int;
    final junkLong = db
        .select(
          'SELECT COUNT(*) c FROM dpd_lookup WHERE LENGTH(lookup_key) > 64',
        )
        .first['c'] as int;
    print('  junk keys: empty/blank=$junkEmpty '
        'leading-space=$junkLeadSpace longer-than-64=$junkLong');
    if (junkEmpty + junkLeadSpace > 0) {
      print('  NOTE: clean these in the DPD build pipeline; the app only '
          'filters the empty key at query time.');
    }
    final indexes = db.select(
      "SELECT name FROM sqlite_master WHERE type='index' "
      "AND tbl_name LIKE 'dpd_lookup_norm%' ORDER BY name",
    );
    print('  norm indexes: ${indexes.map((r) => r['name']).join(', ')}');
  } finally {
    db.dispose();
  }
}
