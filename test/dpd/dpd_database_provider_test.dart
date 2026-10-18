import 'dart:io';

import 'package:drift/native.dart';
import 'package:epitaka/features/dpd/database/dpd_database.dart';
import 'package:epitaka/features/dpd/providers/dpd_database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'dpd_fixture.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('dpd_provider_test');
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  Future<DpdDatabaseState> readState(File file) async {
    final container = ProviderContainer(
      overrides: [dpdDatabaseFileProvider.overrideWith((ref) async => file)],
    );
    addTearDown(container.dispose);
    return container.read(dpdDatabaseProvider.future);
  }

  test('schema 7 is ready, with the release from db_info', () async {
    final state = await readState(buildDpdFixture(dir));
    expect(state.status, DpdDatabaseStatus.ready);
    expect(state.releaseVersion, startsWith('v0.4.'));
    expect(state.dao, isNotNull);
    expect(await state.dao!.searchExact('dhamma'), isNotEmpty);
  });

  test('schema 8 is unsupported and gives no DAO', () async {
    final state = await readState(buildDpdFixture(dir, schemaVersion: '8'));
    expect(state.status, DpdDatabaseStatus.unsupportedSchema);
    expect(state.schemaVersion, '8');
    expect(state.dao, isNull);
  });

  test('a missing file is not installed, and is not created', () async {
    final file = File('${dir.path}/dpd-mobile.db');
    final state = await readState(file);
    expect(state.status, DpdDatabaseStatus.notInstalled);
    expect(state.path, file.path);
    expect(file.existsSync(), isFalse);
  });

  // A file that exists but cannot be read (cut short, zero bytes, not a
  // database) used to surface a raw SQLite error on the lookup page. The
  // not-installed screen offers the download, which replaces the file.
  test('an empty file is not installed, and is left alone', () async {
    final file = File('${dir.path}/dpd-mobile.db')..writeAsBytesSync([]);
    final state = await readState(file);
    expect(state.status, DpdDatabaseStatus.notInstalled);
    expect(state.path, file.path);
    expect(state.dao, isNull);
    expect(file.lengthSync(), 0);
  });

  test('a file that is not a database is not installed', () async {
    final file = File('${dir.path}/dpd-mobile.db')
      ..writeAsBytesSync(List.filled(4096, 0x41));
    final state = await readState(file);
    expect(state.status, DpdDatabaseStatus.notInstalled);
    expect(state.dao, isNull);
  });

  test('a database without the DPD tables is not installed', () async {
    final file = File('${dir.path}/dpd-mobile.db');
    final db = sqlite3.open(file.path);
    db.execute('CREATE TABLE other (a)');
    db.dispose();
    final state = await readState(file);
    expect(state.status, DpdDatabaseStatus.notInstalled);
  });

  // On a phone drift runs the database in a worker isolate, and the error
  // reaches the app as a `DriftRemoteException` that holds only text. The
  // test opens the same way, so it sees the real shape of that error.
  group('what counts as an unreadable file', () {
    Future<Object> openError(File file, {required bool background}) async {
      // Migrations off, as in the app: drift would create the tables.
      final db = DpdDatabase.forTesting(
        background
            ? NativeDatabase.createInBackground(file, enableMigrations: false)
            : NativeDatabase(file, enableMigrations: false),
      );
      try {
        await DpdDao(db).getDbValue('db_schema_version');
      } catch (e) {
        return e;
      } finally {
        await db.close();
      }
      fail('the file was readable');
    }

    File damaged(String kind) {
      final file = File('${dir.path}/$kind.db');
      switch (kind) {
        case 'empty':
          file.writeAsBytesSync([]);
        case 'garbage':
          file.writeAsBytesSync(List.filled(4096, 0x41));
        default:
          final db = sqlite3.open(file.path);
          db.execute('CREATE TABLE other (a)');
          db.dispose();
      }
      return file;
    }

    for (final background in [false, true]) {
      for (final kind in ['empty', 'garbage', 'no-tables']) {
        test('$kind, ${background ? 'worker isolate' : 'in the app'}', () async {
          final error = await openError(damaged(kind), background: background);
          expect(isUnreadableDpdFile(error), isTrue, reason: '$error');
        });
      }
    }

    test('a busy or locked file is not a damaged one', () {
      expect(isUnreadableDpdFile(SqliteException(5, 'database is locked')), isFalse);
      expect(isUnreadableDpdFile(SqliteException(10, 'disk I/O error')), isFalse);
      expect(isUnreadableDpdFile(StateError('anything else')), isFalse);
    });
  });
}
