import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:epitaka/features/dpd/providers/dpd_database_provider.dart';
import 'package:epitaka/features/dpd/services/dpd_installer.dart';
import 'package:epitaka/features/dpd/services/dpd_release_service.dart';
import 'package:epitaka/features/settings/providers/translation_download_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'dpd_fixture.dart';

/// The installer only reads and invalidates through its ref. With
/// [closesAfterFirstRead] it behaves like the ref of a screen closed right
/// after Download was tapped: every later use throws, as Riverpod's does.
class _ContainerRef implements WidgetRef {
  _ContainerRef(this.container, {this.closesAfterFirstRead = false});

  final ProviderContainer container;
  final bool closesAfterFirstRead;
  bool _closed = false;

  void _check() {
    if (_closed) {
      throw StateError('Cannot use "ref" after the widget was disposed.');
    }
  }

  @override
  T read<T>(ProviderListenable<T> provider) {
    _check();
    final value = container.read(provider);
    if (closesAfterFirstRead) _closed = true;
    return value;
  }

  @override
  void invalidate(ProviderOrFamily provider) {
    _check();
    container.invalidate(provider);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _url = 'https://example.invalid/dpd-mobile-db.zip';
const _oldRelease = 'v0.4.20260101';
const _newRelease = 'v0.4.20261101';

Uint8List zipOf(File db) {
  final bytes = db.readAsBytesSync();
  final archive = Archive()..addFile(ArchiveFile.bytes('dpd-mobile.db', bytes));
  return ZipEncoder().encodeBytes(archive);
}

void main() {
  late Directory dir;
  late Directory src;
  late ProviderContainer container;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('dpd_install_test');
    src = await Directory.systemTemp.createTemp('dpd_install_src');
    buildDpdFixture(dir, releaseVersion: _oldRelease);
    container = ProviderContainer(
      overrides: [
        dpdDatabaseFileProvider.overrideWith(
          (ref) async => File('${dir.path}/dpd-mobile.db'),
        ),
      ],
    );
    // Kept open, as in the app: the swap has to close both handles.
    container.listen(dpdDatabaseProvider, (_, _) {});
    container.listen(dpdQuickLookupProvider, (_, _) {});
    await container.read(dpdQuickLookupProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await dir.delete(recursive: true);
    await src.delete(recursive: true);
  });

  Future<bool> install(
    Uint8List zip, {
    String? sha256,
    bool screenCloses = false,
  }) {
    return installDpdRelease(
      _ContainerRef(container, closesAfterFirstRead: screenCloses),
      release: DpdRelease(
        tag: _newRelease,
        url: _url,
        size: zip.length,
        sha256: sha256 ?? sha256Of(zip),
      ),
      dbDir: dir,
      client: MockClient((_) async => http.Response.bytes(zip, 200)),
    );
  }

  Future<void> expectOldStillAnswers() async {
    final state = await container.read(dpdDatabaseProvider.future);
    expect(state.status, DpdDatabaseStatus.ready);
    expect(state.releaseVersion, _oldRelease);
    expect(await state.dao!.searchExact('dhamma'), isNotEmpty);
    final quick = await container.read(dpdQuickLookupProvider.future);
    expect(quick!.hasContent('dhamma'), isTrue);
  }

  List<String> filesInDir() =>
      dir.listSync().map((e) => e.uri.pathSegments.last).toList()..sort();

  String? errorMessage() => container
      .read(translationDownloadProvider)[kDpdDownloadKey]
      ?.errorMessage;

  test('a good release replaces the open database without a restart', () async {
    final zip = zipOf(buildDpdFixture(src, releaseVersion: _newRelease, wal: true));

    expect(await install(zip), isTrue);

    final state = await container.read(dpdDatabaseProvider.future);
    expect(state.releaseVersion, _newRelease);
    expect(await state.dao!.searchExact('dhamma'), isNotEmpty);
    final quick = await container.read(dpdQuickLookupProvider.future);
    expect(quick!.hasContent('dhamma'), isTrue);
    // Header bytes 18 and 19 are 1 for a rollback journal, 2 for WAL.
    final header = File('${dir.path}/dpd-mobile.db').openSync().readSync(20);
    expect([header[18], header[19]], [1, 1]);
    expect(filesInDir(), ['dpd-mobile.db']);
  });

  // A damaged file shows as "not installed", with the download button. The
  // download has to be able to replace it.
  test('a release replaces a damaged file', () async {
    container.dispose();
    File('${dir.path}/dpd-mobile.db')
      ..deleteSync()
      ..writeAsBytesSync([]);
    container = ProviderContainer(
      overrides: [
        dpdDatabaseFileProvider.overrideWith(
          (ref) async => File('${dir.path}/dpd-mobile.db'),
        ),
      ],
    );
    container.listen(dpdDatabaseProvider, (_, _) {});
    final before = await container.read(dpdDatabaseProvider.future);
    expect(before.status, DpdDatabaseStatus.notInstalled);

    final zip = zipOf(buildDpdFixture(src, releaseVersion: _newRelease));
    expect(await install(zip), isTrue);

    final state = await container.read(dpdDatabaseProvider.future);
    expect(state.status, DpdDatabaseStatus.ready);
    expect(state.releaseVersion, _newRelease);
    expect(filesInDir(), ['dpd-mobile.db']);
  });

  test('the install finishes after the screen that started it closed', () async {
    final zip = zipOf(buildDpdFixture(src, releaseVersion: _newRelease));

    expect(await install(zip, screenCloses: true), isTrue);

    final state = await container.read(dpdDatabaseProvider.future);
    expect(state.releaseVersion, _newRelease);
    expect(filesInDir(), ['dpd-mobile.db']);
  });

  test("right after a swap, the reader's direct read does not crash", () async {
    final zip = zipOf(buildDpdFixture(src, releaseVersion: _newRelease));
    expect(await install(zip), isTrue);

    // The reader reads the value without waiting, as reader_screen does.
    final quick = container.read(dpdQuickLookupProvider).valueOrNull;
    expect(() => quick?.hasContent('dhamma'), returnsNormally);
  });

  test('a failed swap leaves no extracted file behind', () async {
    final zip = zipOf(buildDpdFixture(src, releaseVersion: _newRelease));
    final ok = await container
        .read(translationDownloadProvider.notifier)
        .downloadCoreAsset(
          url: _url,
          filename: kDpdFilename,
          displayName: kDpdDisplayName,
          ref: _ContainerRef(container),
          versionKey: kDpdDownloadKey,
          verify: verifyDpdDownload,
          swap: (replace, invalidate) async =>
              throw const FileSystemException('rename refused'),
          dbDir: dir,
          client: MockClient((_) async => http.Response.bytes(zip, 200)),
        );

    expect(ok, isFalse);
    expect(errorMessage(), contains('rename refused'));
    await expectOldStillAnswers();
    expect(filesInDir(), ['dpd-mobile.db']);
  });

  test('a corrupt zip leaves the old database answering', () async {
    final zip = Uint8List.fromList(List.generate(4096, (i) => i * 7 % 256));

    expect(await install(zip), isFalse);

    expect(errorMessage(), isNotNull);
    await expectOldStillAnswers();
    expect(filesInDir(), ['dpd-mobile.db']);
  });

  test('a wrong digest is refused before extraction', () async {
    final zip = zipOf(buildDpdFixture(src, releaseVersion: _newRelease));

    expect(await install(zip, sha256: '0' * 64), isFalse);

    expect(errorMessage(), contains('checksum'));
    await expectOldStillAnswers();
    expect(filesInDir(), ['dpd-mobile.db']);
  });

  test('schema 8 asks for an ePitaka update and keeps the old one', () async {
    final zip = zipOf(
      buildDpdFixture(src, releaseVersion: _newRelease, schemaVersion: '8'),
    );

    expect(await install(zip), isFalse);

    expect(errorMessage(), contains('Update ePitaka to use this DPD release'));
    await expectOldStillAnswers();
    expect(filesInDir(), ['dpd-mobile.db']);
  });

  test('a failed release lookup is an error, not "up to date"', () async {
    final ok = await installDpdRelease(
      _ContainerRef(container),
      service: DpdReleaseService(
        client: MockClient((_) async => http.Response('', 403)),
      ),
      dbDir: dir,
    );

    expect(ok, isFalse);
    expect(errorMessage(), contains('rate limit'));
    await expectOldStillAnswers();
  });

  test('Stop pressed during a failing release lookup stays cancelled', () async {
    final notifier = container.read(translationDownloadProvider.notifier);
    final ok = await installDpdRelease(
      _ContainerRef(container),
      service: DpdReleaseService(
        client: MockClient((_) async {
          notifier.cancelDownload(kDpdDownloadKey);
          return http.Response('', 403);
        }),
      ),
      dbDir: dir,
    );

    expect(ok, isFalse);
    expect(
      container.read(translationDownloadProvider)[kDpdDownloadKey]?.status,
      DownloadStatus.cancelled,
    );
    expect(errorMessage(), isNull);
  });

  test('a full disk says so in plain words', () {
    expect(
      downloadErrorMessage(
        const FileSystemException('write', 'x', OSError('No space', 28)),
      ),
      'Not enough storage',
    );
  });
}

String sha256Of(List<int> bytes) => sha256.convert(bytes).toString();
