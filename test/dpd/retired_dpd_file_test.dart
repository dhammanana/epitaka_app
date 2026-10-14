/// The old `dpd-dictionary.db` is deleted once the new DPD file opens, and
/// no start-up copy step brings it back, even from a build that still
/// bundles it.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:epitaka/core/utils/database_initializer.dart';
import 'package:epitaka/features/dpd/providers/dpd_database_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dpd_fixture.dart';

/// A build's assets: `AssetManifest.bin` lists [files], which load as bytes.
class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.files);

  final Map<String, List<int>> files;

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage({
        for (final asset in files.keys) asset: <Object?>[],
      })!;
    }
    final bytes = files[key];
    if (bytes == null) throw FlutterError('Unable to load asset: $key');
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory data;
  late Directory documents;

  setUp(() async {
    data = await Directory.systemTemp.createTemp('retired_dpd_data');
    documents = await Directory.systemTemp.createTemp('retired_dpd_docs');
  });

  tearDown(() async {
    await data.delete(recursive: true);
    await documents.delete(recursive: true);
  });

  File inData(String name) => File('${data.path}/$name');

  test('the old file is deleted, and two launches never bring it back', () async {
    buildDpdFixture(data);
    // An upgrade: the old file and a journal are still in the data folder.
    inData('dpd-dictionary.db').writeAsStringSync('old dictionary');
    inData('dpd-dictionary.db-wal').writeAsStringSync('old wal');
    // An old desktop build's Documents folder, and the DPD app's own file.
    File('${documents.path}/dpd-dictionary.db').writeAsStringSync('legacy');
    File('${documents.path}/dpd-mobile.db').writeAsStringSync('dpd app');
    File('${documents.path}/notes.db').writeAsStringSync('notes');
    // A build that still bundles the old file.
    final bundle = _FakeBundle({
      'assets/db/dpd-dictionary.db': [1, 2, 3],
      'assets/db/epitaka.db': [4, 5, 6],
    });

    for (var launch = 1; launch <= 2; launch++) {
      await migrateLegacyDatabases(
        targetDir: data,
        legacyDirsForTest: [documents.path],
      );
      await ensureBundledDatabases(targetDir: data, bundle: bundle);
      if (launch > 1) {
        expect(
          inData('dpd-dictionary.db').existsSync(),
          isFalse,
          reason: 'launch $launch: a copy step put the old file back',
        );
      }

      final container = ProviderContainer(
        overrides: [
          dpdDatabaseFileProvider.overrideWith(
            (ref) async => inData('dpd-mobile.db'),
          ),
        ],
      );
      final state = await container.read(dpdDatabaseProvider.future);
      container.dispose();

      expect(state.status, DpdDatabaseStatus.ready);
      // Still the fixture, not the DPD app's file from Documents.
      expect(state.releaseVersion, 'v0.4.20261012');
      expect(inData('dpd-dictionary.db').existsSync(), isFalse);
      expect(inData('dpd-dictionary.db-wal').existsSync(), isFalse);
    }

    // The copy steps did run: the other files arrived.
    expect(inData('epitaka.db').readAsBytesSync(), [4, 5, 6]);
    expect(inData('notes.db').readAsStringSync(), 'notes');
  });

  test("the DPD app's own file in Documents is never copied in", () async {
    File('${documents.path}/dpd-mobile.db').writeAsStringSync('dpd app');
    File('${documents.path}/dpd-mobile.db-wal').writeAsStringSync('dpd wal');

    await migrateLegacyDatabases(
      targetDir: data,
      legacyDirsForTest: [documents.path],
    );

    expect(inData('dpd-mobile.db').existsSync(), isFalse);
    expect(inData('dpd-mobile.db-wal').existsSync(), isFalse);
  });

  test('without the new file the old one is kept', () async {
    inData('dpd-dictionary.db').writeAsStringSync('old dictionary');
    final container = ProviderContainer(
      overrides: [
        dpdDatabaseFileProvider.overrideWith(
          (ref) async => inData('dpd-mobile.db'),
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = await container.read(dpdDatabaseProvider.future);

    expect(state.status, DpdDatabaseStatus.notInstalled);
    expect(inData('dpd-dictionary.db').existsSync(), isTrue);
  });
}
