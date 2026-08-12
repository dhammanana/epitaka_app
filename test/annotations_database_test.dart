import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:epitaka/core/database/app_database.dart';

/// Minimal drift database that only runs raw SQL — used to hand-craft the
/// v4-era schema on a real file before reopening it with [AppDatabase].
class _RawSqlDb extends GeneratedDatabase {
  _RawSqlDb(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
}

void main() {
  group('annotations table', () {
    test('upsertAnnotation works (regression: missing primary key)', () async {
      final db = AppDatabase(NativeDatabase.memory());

      final row = AnnotationRow(
        id: 'b5b17eb7-3a3f-4d19-b3d3-b3e4d5bcd123',
        type: 'bookmark',
        bookId: 'book-1',
        bookName: 'The Book',
        paraId: 12,
        lineId: 3,
        name: 'My bookmark',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
        dirty: false,
      );

      // Must NOT throw "Invalid arguments: table has no primary key".
      await db.upsertAnnotation(row);

      final saved = await db.getAnnotation(row.id);
      expect(saved, isNotNull);
      expect(saved!.name, 'My bookmark');

      // Upserting the same id again must UPDATE, not duplicate.
      await db.upsertAnnotation(
        row.copyWith(name: const Value('Renamed'), dirty: true),
      );
      final all = await db.getAllAnnotations();
      expect(all, hasLength(1));
      expect(all.single.name, 'Renamed');
      expect(all.single.dirty, isTrue);

      await db.close();
    });

    test(
      'v5 (PK-less) → v6 migration rebuilds table with primary key',
      () async {
        final dir = await Directory.systemTemp.createTemp(
          'annotations_v6_migration_test',
        );
        final dbFile = File(p.join(dir.path, 'app_data.db'));
        addTearDown(() => dir.delete(recursive: true));

        // Simulate the stuck device state: schemaVersion 5 with an
        // annotations table that still has NO primary key (the v5
        // migration rebuilt it from generated code that lacked the key).
        // This is exactly the state that produced the user-visible
        // "ON CONFLICT clause does not match any PRIMARY KEY or UNIQUE
        // constraint" error when saving a bookmark.
        final v5 = _RawSqlDb(NativeDatabase(dbFile));
        await v5.customStatement('''
          CREATE TABLE annotations (
            id TEXT NOT NULL,
            type TEXT NOT NULL,
            book_id TEXT NOT NULL,
            book_name TEXT,
            para_id INTEGER,
            line_id INTEGER,
            segment TEXT,
            lang_code TEXT,
            start_offset INTEGER,
            end_offset INTEGER,
            exact_text TEXT,
            prefix_text TEXT,
            suffix_text TEXT,
            color TEXT,
            note TEXT,
            name TEXT,
            page_number TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER,
            dirty INTEGER NOT NULL DEFAULT 0,
            server_updated_at INTEGER
          )
        ''');
        await v5.customStatement('PRAGMA user_version = 5');
        await v5.customStatement('''
          INSERT INTO annotations (
            id, type, book_id, book_name, para_id, line_id,
            name, created_at, updated_at, dirty
          ) VALUES (
            'stuck-uuid-5678', 'bookmark', 'book-7', 'Stuck Book',
            1, 2, 'Stuck bookmark', 1767225600, 1767225600, 1
          )
        ''');
        await v5.close();

        // Reopen with current schema: onUpgrade 5→6 must detect the missing
        // primary key and rebuild the table while keeping the row.
        final db = AppDatabase(NativeDatabase(dbFile));
        await db.customSelect('PRAGMA user_version').get();

        final rows = await db.getAllAnnotations();
        expect(rows, hasLength(1), reason: 'migration must preserve data');
        expect(rows.single.id, 'stuck-uuid-5678');

        // The rebuilt table must now accept upserts without the SQLite
        // "ON CONFLICT clause does not match any PRIMARY KEY" error.
        await db.upsertAnnotation(rows.single.copyWith(name: const Value('Fixed')));
        final after = await db.getAnnotation('stuck-uuid-5678');
        expect(after!.name, 'Fixed');

        await db.close();
      },
    );

    test(
      'v4 → v5 migration adds primary key and preserves existing rows',
      () async {
        final dir = await Directory.systemTemp.createTemp(
          'annotations_migration_test',
        );
        final dbFile = File(p.join(dir.path, 'app_data.db'));
        addTearDown(() => dir.delete(recursive: true));

        // Simulate a v4-era database: annotations table WITHOUT a primary
        // key, plus one existing bookmark row.
        final v4 = _RawSqlDb(NativeDatabase(dbFile));
        await v4.customStatement('''
          CREATE TABLE annotations (
            id TEXT NOT NULL,
            type TEXT NOT NULL,
            book_id TEXT NOT NULL,
            book_name TEXT,
            para_id INTEGER,
            line_id INTEGER,
            segment TEXT,
            lang_code TEXT,
            start_offset INTEGER,
            end_offset INTEGER,
            exact_text TEXT,
            prefix_text TEXT,
            suffix_text TEXT,
            color TEXT,
            note TEXT,
            name TEXT,
            page_number TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER,
            dirty INTEGER NOT NULL DEFAULT 0,
            server_updated_at INTEGER
          )
        ''');
        await v4.customStatement('PRAGMA user_version = 4');
        await v4.customStatement('''
          INSERT INTO annotations (
            id, type, book_id, book_name, para_id, line_id,
            name, created_at, updated_at, dirty
          ) VALUES (
            'old-uuid-1234', 'bookmark', 'book-9', 'Old Book',
            42, 7, 'Old bookmark', 1767225600, 1767225600, 0
          )
        ''');
        await v4.close();

        // Reopen with current schema: onUpgrade 4→5 must rebuild the table
        // with a primary key while keeping the existing row.
        final db = AppDatabase(NativeDatabase(dbFile));
        await db.customSelect('PRAGMA user_version').get();

        final rows = await db.getAllAnnotations();
        expect(rows, hasLength(1), reason: 'migration must preserve data');
        expect(rows.single.id, 'old-uuid-1234');
        expect(rows.single.name, 'Old bookmark');
        expect(rows.single.bookId, 'book-9');

        // And the rebuilt table must now accept upserts.
        await db.upsertAnnotation(rows.single);
        final after = await db.getAnnotation('old-uuid-1234');
        expect(after, isNotNull);

        await db.close();
      },
    );
  });
}
