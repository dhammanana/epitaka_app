import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../update/app_update_service.dart' show Version;

/// DPD releases live in the DPD repository, not in ePitaka's manifest: old
/// ePitaka versions read that manifest and cannot open this database.
const kDpdReleasesUrl =
    'https://api.github.com/repos/digitalpalidictionary/dpd-db/releases?per_page=10';
const kDpdAssetName = 'dpd-mobile-db.zip';

class DpdRelease {
  const DpdRelease({
    required this.tag,
    required this.url,
    required this.size,
    this.sha256,
  });

  /// e.g. `v0.4.20260926`, the same text as `db_info.dpd_release_version`.
  final String tag;
  final String url;

  /// Size of the zip in bytes.
  final int size;

  /// Lower-case hex SHA-256 of the zip, from the asset's `digest`.
  final String? sha256;

  /// Compared by number, not by "a different tag": a local export newer than
  /// every release must never be offered an older one.
  bool isNewerThan(String? installedTag) {
    final latest = Version.parse(tag);
    final installed = Version.parse(installedTag ?? '');
    if (latest == null || installed == null) return false;
    return latest > installed;
  }
}

class DpdReleaseException implements Exception {
  const DpdReleaseException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DpdReleaseService {
  DpdReleaseService({this.client});

  /// For tests; null makes a client per call and closes it.
  final http.Client? client;

  /// The newest release that carries [kDpdAssetName], pre-releases included
  /// (the DPD app's own rule). Throws [DpdReleaseException] when GitHub
  /// cannot be read or no release has the file.
  Future<DpdRelease> fetchLatest() async {
    final httpClient = client ?? http.Client();
    try {
      final http.Response response;
      try {
        response = await httpClient
            .get(
              Uri.parse(kDpdReleasesUrl),
              headers: const {
                'Accept': 'application/vnd.github+json',
                'X-GitHub-Api-Version': '2022-11-28',
              },
            )
            .timeout(const Duration(seconds: 15));
      } on TimeoutException {
        throw const DpdReleaseException(
          'GitHub did not answer. Check the connection and try again.',
        );
      } on Exception catch (e) {
        // Offline shows up here (ClientException, SocketException).
        throw DpdReleaseException(
          'Could not reach GitHub. Check the connection and try again. ($e)',
        );
      }
      if (response.statusCode == 403 || response.statusCode == 429) {
        throw const DpdReleaseException(
          'GitHub rate limit reached. Try again in an hour.',
        );
      }
      if (response.statusCode != 200) {
        throw DpdReleaseException(
          'Could not read the DPD releases (HTTP ${response.statusCode}).',
        );
      }
      return parseLatest(response.body);
    } finally {
      if (client == null) httpClient.close();
    }
  }

  static DpdRelease parseLatest(String body) {
    final Object? json;
    try {
      json = jsonDecode(body);
    } on FormatException {
      throw const DpdReleaseException('Unexpected reply from GitHub.');
    }
    if (json is! List) {
      throw const DpdReleaseException('Unexpected reply from GitHub.');
    }
    for (final release in json) {
      if (release is! Map<String, dynamic>) continue;
      final assets = release['assets'];
      if (assets is! List) continue;
      for (final asset in assets) {
        if (asset is! Map<String, dynamic>) continue;
        if (asset['name'] != kDpdAssetName) continue;
        final tag = release['tag_name'];
        final url = asset['browser_download_url'];
        final size = asset['size'];
        final digest = asset['digest'];
        if (tag is! String || url is! String || size is! int) {
          throw const DpdReleaseException('Unexpected reply from GitHub.');
        }
        return DpdRelease(
          tag: tag,
          url: url,
          size: size,
          sha256: digest is String && digest.startsWith('sha256:')
              ? digest.substring('sha256:'.length).toLowerCase()
              : null,
        );
      }
    }
    throw const DpdReleaseException(
      'No DPD release has the $kDpdAssetName file.',
    );
  }
}
