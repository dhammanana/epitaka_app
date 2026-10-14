import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// Builds `dpd-mobile.db` in [dir] from `test/fixtures/dpd_mini.sql`, real
/// rows copied by `scripts/build_dpd_fixture.py`.
///
/// [schemaVersion] overrides `db_info.db_schema_version`, to fake a release
/// this app cannot read. [releaseVersion] overrides
/// `db_info.dpd_release_version`. [wal] leaves the file in WAL mode, as the
/// release export ships.
File buildDpdFixture(
  Directory dir, {
  String? schemaVersion,
  String? releaseVersion,
  bool wal = false,
}) {
  final file = File('${dir.path}/dpd-mobile.db');
  final db = sqlite3.open(file.path);
  try {
    db.execute(File('test/fixtures/dpd_mini.sql').readAsStringSync());
    if (schemaVersion != null) {
      db.execute(
        "UPDATE db_info SET value = ? WHERE key = 'db_schema_version'",
        [schemaVersion],
      );
    }
    if (releaseVersion != null) {
      db.execute(
        "UPDATE db_info SET value = ? WHERE key = 'dpd_release_version'",
        [releaseVersion],
      );
    }
    if (wal) db.execute('PRAGMA journal_mode=WAL');
  } finally {
    db.dispose();
  }
  return file;
}
