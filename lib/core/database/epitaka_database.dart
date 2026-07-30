import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

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

    final database = NativeDatabase(
      file,
      setup: (db) {
        db.execute('PRAGMA journal_mode=WAL');
        db.execute('PRAGMA foreign_keys=ON');
      },
      logStatements: false,
    );

    return EpitakaDatabase(database);
  }
}
