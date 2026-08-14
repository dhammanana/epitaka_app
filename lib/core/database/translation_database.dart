import 'dart:io';

import 'package:drift/drift.dart';

import 'drift_database_executor.dart';

part 'translation_database.g.dart';

// ---------------------------------------------------------------------------
// Table: sentences (matches epitaka_th.db schema)
// ---------------------------------------------------------------------------
class TranslationSentences extends Table {
  @override
  String? get tableName => 'sentences';
  TextColumn get bookId => text()();
  IntColumn get paraId => integer()();
  IntColumn get lineId => integer()();
  TextColumn get paliSentence => text().nullable()();
  TextColumn get translation => text().nullable()();
  TextColumn get translationConfidence => text().nullable()();
  TextColumn get confidenceNote => text().nullable()();

  @override
  Set<Column> get primaryKey => {bookId, paraId, lineId};
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------
@DriftDatabase(tables: [TranslationSentences])
class TranslationDatabase extends _$TranslationDatabase {
  TranslationDatabase(super.e);

  @override
  int get schemaVersion => 1;

  /// Open an existing translation database at [dbPath].
  static Future<TranslationDatabase> open(String dbPath) async {
    final file = File(dbPath);
    if (!await file.exists()) {
      throw Exception('Translation database not found at $dbPath');
    }

    final database = openDriftExecutor(
      file,
      setup: (db) {
        db.execute('PRAGMA journal_mode=WAL');
        db.execute('PRAGMA foreign_keys=ON');
      },
    );

    return TranslationDatabase(database);
  }
}
