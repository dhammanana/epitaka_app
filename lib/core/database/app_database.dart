import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

// ---------------------------------------------------------------------------
// Table: bookmarks
// ---------------------------------------------------------------------------
class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get bookId => text()();
  IntColumn get paraId => integer().nullable()();
  IntColumn get lineId => integer().nullable()();
  TextColumn get bookName => text().nullable()();
  TextColumn get pageNumber => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

}

// ---------------------------------------------------------------------------
// Table: reading_history
// ---------------------------------------------------------------------------
class ReadingHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId => text()();
  TextColumn get bookName => text().nullable()();
  IntColumn get paraId => integer().nullable()();
  IntColumn get lineId => integer().nullable()();
  DateTimeColumn get openedAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get readCount => integer().withDefault(const Constant(1))();

}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------
@DriftDatabase(tables: [Bookmarks, ReadingHistory])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA journal_mode=WAL');
        await customStatement('PRAGMA foreign_keys=ON');
      },
    );
  }

  /// Open the app database at the default path.
  static Future<AppDatabase> open() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'app_data.db');
    final file = File(dbPath);

    final database = NativeDatabase(
      file,
      setup: (db) {
        db.execute('PRAGMA journal_mode=WAL');
        db.execute('PRAGMA foreign_keys=ON');
      },
      logStatements: false,
    );

    return AppDatabase(database);
  }

  /// Add or update a bookmark.
  Future<Bookmark> addBookmark({
    required String name,
    required String bookId,
    int? paraId,
    int? lineId,
    String? bookName,
    String? pageNumber,
  }) async {
    final now = DateTime.now();
    final id = await into(bookmarks).insert(BookmarksCompanion(
      name: Value(name),
      bookId: Value(bookId),
      paraId: Value(paraId),
      lineId: Value(lineId),
      bookName: Value(bookName),
      pageNumber: Value(pageNumber),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));

    return (await (select(bookmarks)..where((b) => b.id.equals(id))).get()).first;
  }

  /// Delete a bookmark by ID.
  Future<void> deleteBookmark(int id) async {
    await (delete(bookmarks)..where((b) => b.id.equals(id))).go();
  }

  /// Get all bookmarks, ordered by most recent first.
  Future<List<Bookmark>> getAllBookmarks() async {
    return (select(bookmarks)..orderBy([(b) => OrderingTerm(expression: b.createdAt, mode: OrderingMode.desc)])).get();
  }

  /// Get bookmarks for a specific book.
  Future<List<Bookmark>> getBookmarksForBook(String bookId) async {
    return (select(bookmarks)
          ..where((b) => b.bookId.equals(bookId))
          ..orderBy([(b) => OrderingTerm(expression: b.createdAt, mode: OrderingMode.desc)]))
        .get();
  }

  /// Add or update reading history entry.
  Future<void> recordReading({
    required String bookId,
    String? bookName,
    int? paraId,
    int? lineId,
  }) async {
    final now = DateTime.now();

    // Check if an entry for this book already exists (not just updated today)
    final existing = await (select(readingHistory)
          ..where((h) => h.bookId.equals(bookId))
          ..orderBy([(h) => OrderingTerm(expression: h.updatedAt, mode: OrderingMode.desc)])
          ..limit(1))
        .get();

    if (existing.isNotEmpty) {
      final entry = existing.first;
      // Update the existing entry with new location and timestamp
      await (update(readingHistory)..where((h) => h.id.equals(entry.id))).write(ReadingHistoryCompanion(
        bookName: Value(bookName ?? entry.bookName),
        paraId: Value(paraId ?? entry.paraId),
        lineId: Value(lineId ?? entry.lineId),
        updatedAt: Value(now),
        readCount: Value(entry.readCount + 1),
      ));
    } else {
      await into(readingHistory).insert(ReadingHistoryCompanion(
        bookId: Value(bookId),
        bookName: Value(bookName),
        paraId: Value(paraId),
        lineId: Value(lineId),
        openedAt: Value(now),
        updatedAt: Value(now),
        readCount: const Value(1),
      ));
    }
  }

  /// Get all reading history, ordered by most recently updated first.
  Future<List<ReadingHistoryData>> getAllHistory() async {
    return (select(readingHistory)
          ..orderBy([(h) => OrderingTerm(expression: h.updatedAt, mode: OrderingMode.desc)]))
        .get();
  }
}
