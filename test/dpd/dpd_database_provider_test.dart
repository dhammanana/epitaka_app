import 'dart:io';

import 'package:epitaka/features/dpd/providers/dpd_database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
