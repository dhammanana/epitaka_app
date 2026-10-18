import 'dart:async';
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

const _url = 'https://example.invalid/dpd-mobile-db.zip';
const _oldRelease = 'v0.4.20260101';
const _newRelease = 'v0.4.20261101';
const _stallMessage = 'No data for 60 seconds. Press Resume to continue.';

Uint8List _zipOf(File db) {
  final archive = Archive()
    ..addFile(ArchiveFile.bytes('dpd-mobile.db', db.readAsBytesSync()));
  return ZipEncoder().encodeBytes(archive);
}

String _sha256Of(List<int> bytes) => sha256.convert(bytes).toString();

void main() {
  late Directory dir;
  late Directory src;
  late ProviderContainer container;
  late Uint8List zip;
  late String digest;
  late int cut;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('dpd_resume_test');
    src = await Directory.systemTemp.createTemp('dpd_resume_src');
    buildDpdFixture(dir, releaseVersion: _oldRelease);
    zip = _zipOf(buildDpdFixture(src, releaseVersion: _newRelease));
    digest = _sha256Of(zip);
    cut = (zip.length * 0.4).floor();
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

  File partialFile([String? name]) => File(
    '${dir.path}/${name ?? 'dpd-mobile.db.${digest.substring(0, 12)}.zip.part'}',
  );

  List<String> filesInDir() =>
      dir.listSync().map((e) => e.uri.pathSegments.last).toList()..sort();

  TranslationDownloadState downloadState() =>
      container.read(translationDownloadProvider)[kDpdDownloadKey] ??
      const TranslationDownloadState();

  DpdRelease release() =>
      DpdRelease(tag: _newRelease, url: _url, size: zip.length, sha256: digest);

  Future<bool> install(http.Client client) => installDpdRelease(
    _ContainerRef(container),
    release: release(),
    dbDir: dir,
    client: client,
  );

  /// Serves [zip]; answers a `Range: bytes=N-` request with `206` the way
  /// GitHub does. [requests] collects each request's Range header.
  http.Client server(List<String?> requests) {
    return MockClient.streaming((request, _) async {
      final range = request.headers['Range'] ?? request.headers['range'];
      requests.add(range);
      if (range != null) {
        final start = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)![1]!);
        final rest = zip.sublist(start);
        return http.StreamedResponse(
          Stream.value(rest),
          206,
          contentLength: rest.length,
          headers: {
            'content-range': 'bytes $start-${zip.length - 1}/${zip.length}',
          },
        );
      }
      return http.StreamedResponse(
        Stream.value(zip),
        200,
        contentLength: zip.length,
      );
    });
  }

  /// A server that ignores Range and sends everything, or refuses it.
  http.Client serverIgnoring(int rangeStatus, List<String?> requests) {
    return MockClient.streaming((request, _) async {
      final range = request.headers['Range'] ?? request.headers['range'];
      requests.add(range);
      if (range != null && rangeStatus == 416) {
        return http.StreamedResponse(const Stream.empty(), 416);
      }
      return http.StreamedResponse(
        Stream.value(zip),
        200,
        contentLength: zip.length,
      );
    });
  }

  /// Sends the first [cut] bytes, then calls [then] with the open stream.
  http.Client dropsAfterCut(
    void Function(StreamController<List<int>> body) then,
  ) {
    return MockClient.streaming((request, _) async {
      final body = StreamController<List<int>>();
      body.add(zip.sublist(0, cut));
      scheduleMicrotask(() => then(body));
      return http.StreamedResponse(body.stream, 200, contentLength: zip.length);
    });
  }

  Future<void> expectOldStillAnswers() async {
    final state = await container.read(dpdDatabaseProvider.future);
    expect(state.releaseVersion, _oldRelease);
  }

  Future<void> expectNewInstalled() async {
    final state = await container.read(dpdDatabaseProvider.future);
    expect(state.releaseVersion, _newRelease);
  }

  test('a download that fails at 40% keeps the part it has', () async {
    final ok = await install(
      dropsAfterCut((body) {
        body.addError(const SocketException('signal lost'));
        body.close();
      }),
    );

    expect(ok, isFalse);
    expect(partialFile().existsSync(), isTrue);
    expect(partialFile().lengthSync(), cut);
    expect(downloadState().status, DownloadStatus.error);
    await expectOldStillAnswers();
  });

  test('the next install sends Range and appends the 206 body', () async {
    partialFile().writeAsBytesSync(zip.sublist(0, cut));
    final requests = <String?>[];

    final ok = await install(server(requests));

    expect(ok, isTrue);
    expect(requests, ['bytes=$cut-']);
    await expectNewInstalled();
    expect(filesInDir(), ['dpd-mobile.db']);
  });

  test('a 200 answer to a Range request restarts from byte 0', () async {
    partialFile().writeAsBytesSync(List.filled(cut, 7));
    final requests = <String?>[];

    final ok = await install(serverIgnoring(200, requests));

    expect(ok, isTrue);
    expect(requests, ['bytes=$cut-']);
    await expectNewInstalled();
    expect(filesInDir(), ['dpd-mobile.db']);
  });

  test('a 416 answer restarts from byte 0', () async {
    partialFile().writeAsBytesSync(List.filled(cut, 7));
    final requests = <String?>[];

    final ok = await install(serverIgnoring(416, requests));

    expect(ok, isTrue);
    expect(requests, ['bytes=$cut-', null]);
    await expectNewInstalled();
    expect(filesInDir(), ['dpd-mobile.db']);
  });

  test('a partial of another release is deleted, not continued', () async {
    final other = partialFile('dpd-mobile.db.aaaaaaaaaaaa.zip.part')
      ..writeAsBytesSync(List.filled(cut, 7));
    final plain = partialFile('dpd-mobile.db.zip.part')
      ..writeAsBytesSync(List.filled(cut, 9));
    final requests = <String?>[];

    final ok = await install(server(requests));

    expect(ok, isTrue);
    expect(requests, [null]);
    expect(other.existsSync(), isFalse);
    expect(plain.existsSync(), isFalse);
    await expectNewInstalled();
    expect(filesInDir(), ['dpd-mobile.db']);
  });

  test('a full-size partial with a wrong checksum is deleted', () async {
    partialFile().writeAsBytesSync(List.filled(zip.length, 7));
    final requests = <String?>[];

    final ok = await install(server(requests));

    expect(ok, isFalse);
    expect(requests, isEmpty);
    expect(downloadState().errorMessage, contains('damaged'));
    expect(filesInDir(), ['dpd-mobile.db']);
    await expectOldStillAnswers();
  });

  test('Stop keeps the partial', () async {
    final sub = container.listen(translationDownloadProvider, (_, _) {});
    addTearDown(sub.close);
    final first = zip.sublist(0, cut);
    late StreamController<List<int>> body;
    final client = MockClient.streaming((request, _) async {
      body = StreamController<List<int>>()..add(first);
      return http.StreamedResponse(body.stream, 200, contentLength: zip.length);
    });

    final running = install(client);
    await Future.doWhile(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return downloadState().progress <= 0;
    }).timeout(const Duration(seconds: 5));
    container
        .read(translationDownloadProvider.notifier)
        .cancelDownload(kDpdDownloadKey);
    body.add([1, 2, 3]);
    await body.close();

    expect(await running, isFalse);
    expect(downloadState().status, DownloadStatus.cancelled);
    expect(partialFile().existsSync(), isTrue);
    expect(partialFile().lengthSync(), cut);
  });

  test(
    'a full-size partial with the right checksum installs offline',
    () async {
      partialFile().writeAsBytesSync(zip);
      final requests = <String?>[];

      final ok = await install(server(requests));

      expect(ok, isTrue);
      expect(requests, isEmpty);
      await expectNewInstalled();
      expect(filesInDir(), ['dpd-mobile.db']);
    },
  );

  test('a 206 answer is refused when no range was asked for', () async {
    final ok = await container
        .read(translationDownloadProvider.notifier)
        .downloadCoreAsset(
          url: _url,
          filename: kDpdFilename,
          displayName: kDpdDisplayName,
          ref: _ContainerRef(container),
          versionKey: kDpdDownloadKey,
          verify: verifyDpdDownload,
          dbDir: dir,
          client: MockClient.streaming(
            (request, _) async => http.StreamedResponse(
              Stream.value(zip),
              206,
              contentLength: zip.length,
            ),
          ),
        );

    expect(ok, isFalse);
    expect(downloadState().errorMessage, contains('HTTP 206'));
    await expectOldStillAnswers();
  });

  // After Stop, the first run stays blocked on a silent server until its
  // stall timeout. It must not stop or overwrite the run the reader started
  // with Resume in the meantime.
  test('a stopped run waking late leaves the newer run alone', () async {
    final notifier = container.read(translationDownloadProvider.notifier);
    final silent = StreamController<List<int>>();
    final first = notifier.downloadCoreAsset(
      url: _url,
      filename: kDpdFilename,
      displayName: kDpdDisplayName,
      ref: _ContainerRef(container),
      versionKey: kDpdDownloadKey,
      expectedBytes: zip.length,
      expectedZipSha256: digest,
      verify: verifyDpdDownload,
      resume: true,
      stallTimeout: const Duration(milliseconds: 400),
      dbDir: dir,
      client: MockClient.streaming((request, _) async {
        silent.add(zip.sublist(0, cut));
        return http.StreamedResponse(
          silent.stream,
          200,
          contentLength: zip.length,
        );
      }),
    );
    await Future.doWhile(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return downloadState().progress <= 0;
    }).timeout(const Duration(seconds: 5));
    notifier.cancelDownload(kDpdDownloadKey);

    final secondBody = StreamController<List<int>>();
    final second = notifier.downloadCoreAsset(
      url: _url,
      filename: kDpdFilename,
      displayName: kDpdDisplayName,
      ref: _ContainerRef(container),
      versionKey: kDpdDownloadKey,
      expectedBytes: zip.length,
      expectedZipSha256: digest,
      verify: verifyDpdDownload,
      resume: true,
      dbDir: dir,
      client: MockClient.streaming(
        (request, _) async => http.StreamedResponse(
          secondBody.stream,
          200,
          contentLength: zip.length,
        ),
      ),
    );

    expect(await first, isFalse);
    expect(downloadState().status, DownloadStatus.downloading);

    notifier.cancelDownload(kDpdDownloadKey);
    secondBody.add([1, 2, 3]);
    await secondBody.close();

    expect(await second, isFalse);
    expect(downloadState().status, DownloadStatus.cancelled);
  });

  test('a server error keeps the partial and does not restart', () async {
    partialFile().writeAsBytesSync(zip.sublist(0, cut));
    final requests = <String?>[];
    final client = MockClient.streaming((request, _) async {
      requests.add(request.headers['Range']);
      return http.StreamedResponse(const Stream.empty(), 503);
    });

    final ok = await install(client);

    expect(ok, isFalse);
    expect(requests, ['bytes=$cut-']);
    expect(downloadState().errorMessage, contains('HTTP 503'));
    expect(partialFile().lengthSync(), cut);
  });

  test('Stop while the server is still answering opens no file', () async {
    final answer = Completer<http.StreamedResponse>();
    final client = MockClient.streaming((request, _) => answer.future);

    final running = install(client);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    container
        .read(translationDownloadProvider.notifier)
        .cancelDownload(kDpdDownloadKey);
    answer.complete(
      http.StreamedResponse(Stream.value(zip), 200, contentLength: zip.length),
    );

    expect(await running, isFalse);
    expect(downloadState().status, DownloadStatus.cancelled);
    expect(partialFile().existsSync(), isFalse);
  });

  test('a stream silent for too long stops and keeps the partial', () async {
    final body = StreamController<List<int>>();
    final client = MockClient.streaming((request, _) async {
      body.add(zip.sublist(0, cut));
      return http.StreamedResponse(body.stream, 200, contentLength: zip.length);
    });

    final ok = await container
        .read(translationDownloadProvider.notifier)
        .downloadCoreAsset(
          url: _url,
          filename: kDpdFilename,
          displayName: kDpdDisplayName,
          ref: _ContainerRef(container),
          versionKey: kDpdDownloadKey,
          expectedBytes: zip.length,
          expectedZipSha256: digest,
          verify: verifyDpdDownload,
          resume: true,
          stallTimeout: const Duration(milliseconds: 200),
          dbDir: dir,
          client: client,
        );

    expect(ok, isFalse);
    expect(downloadState().errorMessage, _stallMessage);
    expect(partialFile().lengthSync(), cut);
    await body.close();
  });

  test('a resumed download starts its progress at partial/total', () async {
    partialFile().writeAsBytesSync(zip.sublist(0, cut));
    final seen = <double>[];
    final sub = container.listen(translationDownloadProvider, (_, next) {
      final s = next[kDpdDownloadKey];
      if (s != null && s.status == DownloadStatus.downloading) {
        seen.add(s.progress);
      }
    });
    addTearDown(sub.close);

    expect(await install(server([])), isTrue);

    final firstReal = seen.firstWhere((v) => v > 0);
    expect(firstReal, closeTo(0.4, 0.02));
  });

  test('without resume a failed download still deletes its file', () async {
    final ok = await container
        .read(translationDownloadProvider.notifier)
        .downloadCoreAsset(
          url: _url,
          filename: kDpdFilename,
          displayName: kDpdDisplayName,
          ref: _ContainerRef(container),
          versionKey: kDpdDownloadKey,
          verify: verifyDpdDownload,
          dbDir: dir,
          client: dropsAfterCut((body) {
            body.addError(const SocketException('signal lost'));
            body.close();
          }),
        );

    expect(ok, isFalse);
    expect(filesInDir(), ['dpd-mobile.db']);
  });
}
