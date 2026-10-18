import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:epitaka/features/dpd/providers/dpd_database_provider.dart';
import 'package:epitaka/features/dpd/services/dpd_installer.dart';
import 'package:epitaka/features/settings/providers/translation_download_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dpd_fixture.dart';

/// The installer only reads and invalidates through its ref.
class _ContainerRef implements WidgetRef {
  _ContainerRef(this.container);

  final ProviderContainer container;

  @override
  T read<T>(ProviderListenable<T> provider) => container.read(provider);

  @override
  void invalidate(ProviderOrFamily provider) => container.invalidate(provider);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _oldRelease = 'v0.4.20260101';
const _newRelease = 'v0.4.20261101';

Uint8List _zipOf(List<int> bytes, {String name = 'dpd-mobile.db'}) {
  final archive = Archive()..addFile(ArchiveFile.bytes(name, bytes));
  return ZipEncoder().encodeBytes(archive);
}

void main() {
  late Directory dir;
  late Directory src;
  late ProviderContainer container;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('dpd_import_test');
    src = await Directory.systemTemp.createTemp('dpd_import_src');
    buildDpdFixture(dir, releaseVersion: _oldRelease);
    container = ProviderContainer(
      overrides: [
        dpdDatabaseFileProvider.overrideWith(
          (ref) async => File('${dir.path}/dpd-mobile.db'),
        ),
      ],
    );
    container.listen(dpdDatabaseProvider, (_, _) {});
    container.listen(dpdQuickLookupProvider, (_, _) {});
    await container.read(dpdQuickLookupProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await dir.delete(recursive: true);
    await src.delete(recursive: true);
  });

  /// A zip of the fixture database, written where the reader would keep it.
  File picked(Uint8List zip) =>
      File('${src.path}/dpd-mobile-db.zip')..writeAsBytesSync(zip);

  Uint8List goodZip({String? schemaVersion}) {
    final built = Directory.systemTemp.createTempSync('dpd_import_build');
    addTearDown(() => built.deleteSync(recursive: true));
    final db = buildDpdFixture(
      built,
      releaseVersion: _newRelease,
      schemaVersion: schemaVersion,
    );
    return _zipOf(db.readAsBytesSync());
  }

  Future<bool> import(File file) =>
      importDpdZip(_ContainerRef(container), file.path, dbDir: dir);

  List<String> filesInDir() =>
      dir.listSync().map((e) => e.uri.pathSegments.last).toList()..sort();

  TranslationDownloadState downloadState() =>
      container.read(translationDownloadProvider)[kDpdDownloadKey] ??
      const TranslationDownloadState();

  Future<void> expectOldStillAnswers() async {
    final state = await container.read(dpdDatabaseProvider.future);
    expect(state.status, DpdDatabaseStatus.ready);
    expect(state.releaseVersion, _oldRelease);
    expect(await state.dao!.searchExact('dhamma'), isNotEmpty);
  }

  test('a good zip installs and the open database answers', () async {
    final file = picked(goodZip());

    expect(await import(file), isTrue);

    final state = await container.read(dpdDatabaseProvider.future);
    expect(state.releaseVersion, _newRelease);
    expect(await state.dao!.searchExact('dhamma'), isNotEmpty);
    expect(filesInDir(), ['dpd-mobile.db']);
    expect(downloadState().status, DownloadStatus.completed);
  });

  test(
    'an install clears the partial of an earlier stopped download',
    () async {
      final stale = File('${dir.path}/dpd-mobile.db.0123456789ab.zip.part')
        ..writeAsBytesSync(List.filled(1000, 1));

      expect(await import(picked(goodZip())), isTrue);

      expect(stale.existsSync(), isFalse);
      expect(filesInDir(), ['dpd-mobile.db']);
    },
  );

  test('a refused file keeps the partial of a stopped download', () async {
    final stale = File('${dir.path}/dpd-mobile.db.0123456789ab.zip.part')
      ..writeAsBytesSync(List.filled(1000, 1));

    expect(await import(picked(goodZip(schemaVersion: '8'))), isFalse);

    expect(stale.existsSync(), isTrue);
  });

  test('the picked zip is still there after an install', () async {
    final file = picked(goodZip());

    expect(await import(file), isTrue);

    expect(file.existsSync(), isTrue);
  });

  group('a bad file leaves the old database answering', () {
    Future<void> expectRefused(File file) async {
      expect(await import(file), isFalse);

      expect(downloadState().status, DownloadStatus.error);
      expect(downloadState().errorMessage, isNotEmpty);
      await expectOldStillAnswers();
      expect(filesInDir(), ['dpd-mobile.db']);
      expect(file.existsSync(), isTrue);
    }

    test('not a zip', () async {
      await expectRefused(
        picked(Uint8List.fromList(List.generate(4096, (i) => i * 7 % 256))),
      );
    });

    test('a zip without a database inside', () async {
      await expectRefused(picked(_zipOf([1, 2, 3], name: 'readme.txt')));
    });

    test('a database of a schema this app cannot read', () async {
      await expectRefused(picked(goodZip(schemaVersion: '8')));
      expect(downloadState().errorMessage, contains('Update ePitaka'));
    });
  });

  // Probe 1.3: the unzip step does not check the entry's checksum, so one
  // flipped byte unpacks without an error. Only the database checks stand
  // between that file and the dictionary.
  test('a zip with one flipped byte never breaks the open database', () async {
    final zip = goodZip();
    zip[zip.length ~/ 2] ^= 0xFF;
    final file = picked(zip);

    final ok = await import(file);

    if (ok) {
      final state = await container.read(dpdDatabaseProvider.future);
      expect(state.releaseVersion, _newRelease);
    } else {
      await expectOldStillAnswers();
    }
    expect(filesInDir(), ['dpd-mobile.db']);
    expect(file.existsSync(), isTrue);
  });

  test('progress shows unpacking, then completed', () async {
    final seen = <DownloadStatus>[];
    final sub = container.listen(translationDownloadProvider, (_, next) {
      final status = next[kDpdDownloadKey]?.status;
      if (status != null && (seen.isEmpty || seen.last != status)) {
        seen.add(status);
      }
    });
    addTearDown(sub.close);

    expect(await import(picked(goodZip())), isTrue);

    expect(seen, [DownloadStatus.extracting, DownloadStatus.completed]);
  });

  test('an import is refused while a download is running', () async {
    container
        .read(translationDownloadProvider.notifier)
        .report(
          kDpdDownloadKey,
          const TranslationDownloadState(
            status: DownloadStatus.downloading,
            progress: 0.5,
          ),
        );
    final file = picked(goodZip());

    expect(await import(file), isFalse);

    expect(downloadState().status, DownloadStatus.downloading);
    expect(downloadState().progress, 0.5);
    await expectOldStillAnswers();
  });

  test('a missing file is an error, not a crash', () async {
    final ok = await import(File('${src.path}/not-there.zip'));

    expect(ok, isFalse);
    expect(downloadState().status, DownloadStatus.error);
    expect(downloadState().errorMessage, contains('could not be found'));
    await expectOldStillAnswers();
  });
}
