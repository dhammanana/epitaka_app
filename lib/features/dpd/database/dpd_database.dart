import 'dart:io';

import 'package:drift/drift.dart';

import '../../../core/database/drift_database_executor.dart';
import 'tables.dart';
export 'dao.dart';

part 'dpd_database.g.dart';

@DriftDatabase(
  tables: [
    DpdHeadwords,
    Lookup,
    DpdRoots,
    DbInfo,
    InflectionTemplates,
    FamilyRoot,
    FamilyWord,
    FamilyCompound,
    FamilyIdiom,
    FamilySet,
    SuttaInfo,
    DictMeta,
    DictEntries,
  ],
)
class DpdDatabase extends _$DpdDatabase {
  /// Bump when the Drift schema changes and a matching DB export is required.
  /// The exported DB must set `db_schema_version` in the `db_info` table to
  /// the same value. A file with another value is refused (see
  /// `kSupportedDpdSchemas`).
  static const schemaNumber = 7;

  /// Opens the downloaded DPD file without ever writing to it. The export
  /// leaves `user_version` at 0, which Drift would read as a new database and
  /// answer with `onCreate` plus a version write, so migrations are off.
  /// `query_only` refuses every other write. The file itself is kept in
  /// `journal_mode=DELETE`, so a reader creates no `-wal` or `-shm` files.
  DpdDatabase(File file)
    : super(
        openDriftExecutor(
          file,
          enableMigrations: false,
          setup: (db) => db.execute('PRAGMA query_only=ON'),
        ),
      );

  DpdDatabase.forTesting(super.e);

  @override
  int get schemaVersion => schemaNumber;
}
