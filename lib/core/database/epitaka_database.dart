import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'drift_database_executor.dart';

part 'epitaka_database.g.dart';

// ---------------------------------------------------------------------------
// Table: books
// ---------------------------------------------------------------------------
class Books extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get refId => integer().nullable()();
  TextColumn get vriId => text().nullable()();
  TextColumn get bookId => text()();
  TextColumn get category => text().nullable()();
  TextColumn get nikaya => text().nullable()();
  TextColumn get subNikaya => text().nullable()();
  TextColumn get bookName => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get mulaRef => text().nullable()();
  TextColumn get atthaRef => text().nullable()();
  TextColumn get tikaRef => text().nullable()();
  IntColumn get paraId => integer().nullable()();
  IntColumn get chapterLen => integer().nullable()();
}

// ---------------------------------------------------------------------------
// Table: headings (table of contents per book)
// ---------------------------------------------------------------------------
class Headings extends Table {
  TextColumn get bookId => text()();
  IntColumn get paraId => integer()();
  IntColumn get level => integer().nullable()();
  TextColumn get title => text().nullable()();
  IntColumn get chapterLen => integer().nullable()();
  IntColumn get parent => integer().nullable()();
  TextColumn get scId => text().nullable()();

  @override
  Set<Column> get primaryKey => {bookId, paraId};
}

// ---------------------------------------------------------------------------
// Table: sentences (Pāli text line by line)
// ---------------------------------------------------------------------------
class Sentences extends Table {
  TextColumn get bookId => text()();
  IntColumn get paraId => integer()();
  IntColumn get lineId => integer()();
  TextColumn get vripara => text().nullable()();
  TextColumn get thaipage => text().nullable()();
  TextColumn get vripage => text().nullable()();
  TextColumn get ptspage => text().nullable()();
  TextColumn get mypage => text().nullable()();
  TextColumn get pali => text().nullable()();

  @override
  Set<Column> get primaryKey => {bookId, paraId, lineId};
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------
@DriftDatabase(tables: [Books, Headings, Sentences])
class EpitakaDatabase extends _$EpitakaDatabase {
  EpitakaDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        // Tables already exist in the pre-bundled database
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA journal_mode=WAL');
        await customStatement('PRAGMA foreign_keys=ON');
      },
    );
  }

  /// Get the nearest heading title at or before [paraId] for a [bookId].
  ///
  /// When [includeLevel10] is true, headings with level=10 are included in
  /// the search (useful for commentary annotations).  The default is `false`
  /// for backward-compatibility with the reader's table-of-contents display.
  Future<String?> getHeadingTitleAtPara(
    String bookId,
    int paraId, {
    bool includeLevel10 = false,
  }) async {
    final levelClause = includeLevel10 ? '' : 'and level<10';
    final rows = await customSelect(
      'SELECT title FROM headings WHERE book_id = ? AND para_id <= ? $levelClause ORDER BY para_id DESC LIMIT 1',
      variables: [Variable.withString(bookId), Variable.withInt(paraId)],
    ).get();
    if (rows.isEmpty) return null;
    return rows.first.data['title'] as String?;
  }

  /// Get the nearest heading (title and para_id) at or before [paraId] for a [bookId].
  ///
  /// When [includeLevel10] is true, headings with level=10 are included in
  /// the search (useful for commentary annotations). The default is `false`.
  /// Returns the heading title and its para_id, or null if no heading found.
  Future<({String? title, int? paraId})?> getHeadingAtPara(
    String bookId,
    int paraId, {
    bool includeLevel10 = false,
  }) async {
    final levelClause = includeLevel10 ? '' : 'and level<10';
    final rows = await customSelect(
      'SELECT title, para_id FROM headings WHERE book_id = ? AND para_id <= ? $levelClause ORDER BY para_id DESC LIMIT 1',
      variables: [Variable.withString(bookId), Variable.withInt(paraId)],
    ).get();
    if (rows.isEmpty) return null;
    final row = rows.first.data;
    return (title: row['title'] as String?, paraId: row['para_id'] as int?);
  }

  /// Open an existing SQLite database at [dbPath].
  static Future<EpitakaDatabase> open(String dbPath) async {
    final file = File(dbPath);
    if (!await file.exists()) {
      throw Exception('Database not found at $dbPath');
    }

    final database = openDriftExecutor(
      file,
      setup: (db) {
        db.execute('PRAGMA journal_mode=WAL');
        db.execute('PRAGMA foreign_keys=ON');
      },
    );

    // Ensure supporting indexes on epitaka.db in the background. epitaka.db
    // is a downloaded core asset (replaced on update), so indexes must be
    // (re)created at runtime rather than baked into the shipped file.
    unawaited(_ensureDictionaryIndex(dbPath));

    return EpitakaDatabase(database);
  }

  /// Creates `idx_dictionary_word_book ON dictionary(word, book_id)` when it
  /// is missing, on a background isolate so the UI thread never stalls.
  ///
  /// The dictionary sections query `dictionary` per enabled book on every
  /// lookup (`WHERE word = ? AND book_id = ?`). The table (~570k rows) ships
  /// WITHOUT an index, so without this SQLite full-scans it per book —
  /// roughly 150–270 ms each on desktop, and several dictionaries are
  /// enabled by default, which is the dominant cost when the dictionary
  /// opens. With the index the same query is ~0.1 ms. Building the index is
  /// a one-time ~0.8 s cost, done off the UI thread; afterwards the check is
  /// a trivial sqlite_master probe per open.
  static Future<void> _ensureDictionaryIndex(String dbPath) async {
    if (kIsWeb) return;
    try {
      await Isolate.run(() {
        final db = sqlite.sqlite3.open(dbPath);
        try {
          db.execute('PRAGMA journal_mode=WAL');
          db.execute('PRAGMA busy_timeout=10000');
          db.execute(
            'CREATE INDEX IF NOT EXISTS idx_dictionary_word_book '
            'ON dictionary(word, book_id)',
          );
        } finally {
          db.dispose();
        }
      });
    } catch (_) {}
  }
}
