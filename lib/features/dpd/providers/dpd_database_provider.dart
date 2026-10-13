import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/utils/database_initializer.dart';
import '../database/dpd_database.dart';
import '../database/dpd_quick_lookup.dart';

/// `db_info.db_schema_version` values this build can read.
const kSupportedDpdSchemas = {'7'};

enum DpdDatabaseStatus { notInstalled, unsupportedSchema, ready }

class DpdDatabaseState {
  final DpdDatabaseStatus status;

  /// Where the app expects the file, shown to the user when it is missing.
  final String path;

  /// The `db_schema_version` found in the file, when there is a file.
  final String? schemaVersion;

  /// `db_info.dpd_release_version`, e.g. `v0.4.20261012`.
  final String? releaseVersion;

  /// Set only when [status] is [DpdDatabaseStatus.ready].
  final DpdDao? dao;

  const DpdDatabaseState({
    required this.status,
    required this.path,
    this.schemaVersion,
    this.releaseVersion,
    this.dao,
  });
}

final dpdDatabaseFileProvider = FutureProvider<File>((ref) async {
  final dir = await getDatabaseDirectory();
  return File(p.join(dir.path, 'dpd-mobile.db'));
});

final dpdDatabaseProvider = FutureProvider<DpdDatabaseState>((ref) async {
  final file = await ref.watch(dpdDatabaseFileProvider.future);
  // Opening a missing path would create an empty database file there.
  if (!await file.exists()) {
    return DpdDatabaseState(
      status: DpdDatabaseStatus.notInstalled,
      path: file.path,
    );
  }

  final db = DpdDatabase(file);
  final dao = DpdDao(db);
  final String? schema;
  final String? release;
  try {
    schema = await dao.getDbValue('db_schema_version');
    release = await dao.getDbValue('dpd_release_version');
  } catch (_) {
    await db.close();
    rethrow;
  }

  if (!kSupportedDpdSchemas.contains(schema)) {
    await db.close();
    return DpdDatabaseState(
      status: DpdDatabaseStatus.unsupportedSchema,
      path: file.path,
      schemaVersion: schema,
      releaseVersion: release,
    );
  }

  ref.onDispose(db.close);
  return DpdDatabaseState(
    status: DpdDatabaseStatus.ready,
    path: file.path,
    schemaVersion: schema,
    releaseVersion: release,
    dao: dao,
  );
});

/// Thrown by [dpdDaoProvider] when there is no readable DPD database. The
/// state says why, so the screen can show the right message.
class DpdUnavailable implements Exception {
  const DpdUnavailable(this.state);

  final DpdDatabaseState state;

  @override
  String toString() => switch (state.status) {
    DpdDatabaseStatus.notInstalled =>
      'DPD database not installed. Expected at ${state.path}',
    DpdDatabaseStatus.unsupportedSchema =>
      'DPD database schema ${state.schemaVersion} is not supported by this '
          'version of ePitaka (file: ${state.path})',
    DpdDatabaseStatus.ready => 'DPD database is ready',
  };
}

final dpdDaoProvider = FutureProvider<DpdDao>((ref) async {
  final state = await ref.watch(dpdDatabaseProvider.future);
  final dao = state.dao;
  if (dao == null) throw DpdUnavailable(state);
  return dao;
});

/// The synchronous read-only handle for the reader's quote-join check. Null
/// when there is no readable DPD database.
final dpdQuickLookupProvider = FutureProvider<DpdQuickLookup?>((ref) async {
  final state = await ref.watch(dpdDatabaseProvider.future);
  if (state.status != DpdDatabaseStatus.ready) return null;
  final quick = DpdQuickLookup.open(state.path);
  ref.onDispose(quick.dispose);
  return quick;
});
