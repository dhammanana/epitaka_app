import 'dart:convert';
import 'dart:io';

import 'package:epitaka/features/dpd/services/dpd_release_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The real reply of 2026-10-14, trimmed to the fields the service reads.
List<dynamic> realReleases() =>
    jsonDecode(File('test/fixtures/dpd_releases.json').readAsStringSync())
        as List<dynamic>;

DpdReleaseService serviceAnswering(int status, Object body) {
  return DpdReleaseService(
    client: MockClient(
      (request) async => http.Response(
        body is String ? body : jsonEncode(body),
        status,
      ),
    ),
  );
}

void main() {
  test('the newest release with the mobile zip wins', () async {
    final release = await serviceAnswering(200, realReleases()).fetchLatest();
    expect(release.tag, 'v0.4.20260926');
    expect(release.size, 209945935);
    expect(
      release.url,
      'https://github.com/digitalpalidictionary/dpd-db/releases/download/'
      'v0.4.20260926/dpd-mobile-db.zip',
    );
    expect(
      release.sha256,
      '6f274778e519237d5719dddd378f72bdb86ab4ae64f432b94c34bb6e02ff24a9',
    );
  });

  test('a pre-release wins when it is the newest with the zip', () async {
    final releases = realReleases().skip(2).toList();
    expect((releases.first as Map)['prerelease'], isTrue);
    final release = await serviceAnswering(200, releases).fetchLatest();
    expect(release.tag, 'v0.4.20260612');
  });

  test('a release without the zip is skipped', () async {
    final releases = realReleases();
    final first = releases.first as Map<String, dynamic>;
    (first['assets'] as List).removeWhere(
      (a) => (a as Map)['name'] == kDpdAssetName,
    );
    final release = await serviceAnswering(200, releases).fetchLatest();
    expect(release.tag, 'v0.4.20260728');
  });

  test('no release with the zip is an error, not "no update"', () async {
    final releases = realReleases().skip(6).toList();
    expect(
      serviceAnswering(200, releases).fetchLatest(),
      throwsA(isA<DpdReleaseException>()),
    );
  });

  test('a 403 rate limit is an error that says so', () async {
    await expectLater(
      serviceAnswering(403, {'message': 'API rate limit exceeded'})
          .fetchLatest(),
      throwsA(
        isA<DpdReleaseException>().having(
          (e) => e.message,
          'message',
          contains('rate limit'),
        ),
      ),
    );
  });

  test('a server error is an error with its code', () async {
    await expectLater(
      serviceAnswering(500, 'oops').fetchLatest(),
      throwsA(
        isA<DpdReleaseException>().having(
          (e) => e.message,
          'message',
          contains('500'),
        ),
      ),
    );
  });

  test('no connection is an error that says so', () async {
    final service = DpdReleaseService(
      client: MockClient(
        (_) async => throw http.ClientException('Failed host lookup'),
      ),
    );
    await expectLater(
      service.fetchLatest(),
      throwsA(
        isA<DpdReleaseException>().having(
          (e) => e.message,
          'message',
          contains('Could not reach GitHub'),
        ),
      ),
    );
  });

  test('a release of the wrong shape is an error, not a crash', () async {
    final releases = realReleases();
    final first = releases.first as Map<String, dynamic>;
    for (final a in first['assets'] as List) {
      if ((a as Map)['name'] == kDpdAssetName) a['size'] = '209945935';
    }
    await expectLater(
      serviceAnswering(200, releases).fetchLatest(),
      throwsA(isA<DpdReleaseException>()),
    );
  });

  test('a reply that is not JSON is an error', () async {
    await expectLater(
      serviceAnswering(200, '<html>').fetchLatest(),
      throwsA(isA<DpdReleaseException>()),
    );
  });

  group('isNewerThan compares the numbers', () {
    const release = DpdRelease(tag: 'v0.4.20260926', url: '', size: 0);

    test('an older install is offered the release', () {
      expect(release.isNewerThan('v0.4.20260728'), isTrue);
      expect(release.isNewerThan('v0.3.20261231'), isTrue);
    });

    test('the same or a newer install is not', () {
      expect(release.isNewerThan('v0.4.20260926'), isFalse);
      expect(release.isNewerThan('v0.4.20261012'), isFalse);
    });

    test('an unreadable or missing tag is never offered', () {
      expect(release.isNewerThan(null), isFalse);
      expect(release.isNewerThan('local'), isFalse);
    });
  });
}
