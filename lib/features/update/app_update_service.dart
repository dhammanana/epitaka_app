import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Metadata for a newer desktop release.
class AppUpdate {
  final String version;
  final Uri releasePage;
  final String? releaseNotes;

  const AppUpdate({
    required this.version,
    required this.releasePage,
    this.releaseNotes,
  });
}

/// Checks GitHub Releases for side-loaded desktop installations.
///
/// This service intentionally does not replace application files itself. The
/// release page provides the signed/packaged installer appropriate for the
/// user's platform, while Store-installed builds continue using Store updates.
class AppUpdateService {
  static const repository = 'dhammanana/epitaka_app';
  static const _apiUri =
      'https://api.github.com/repos/$repository/releases/latest';
  static const releasePage = 'https://github.com/$repository/releases/latest';

  final http.Client _client;
  AppUpdateService({http.Client? client}) : _client = client ?? http.Client();

  static const dismissedVersionKey = 'desktop_update_dismissed_version';

  Future<String?> getDismissedVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(dismissedVersionKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> dismissVersion(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(dismissedVersionKey, version);
    } catch (_) {}
  }

  Future<AppUpdate?> checkForUpdate({String? dismissedVersion}) async {
    if (!_isDesktop) return null;

    final info = await PackageInfo.fromPlatform();
    final current = Version.parse(info.version);
    if (current == null) return null;

    final response = await _client
        .get(
          Uri.parse(_apiUri),
          headers: const {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
          },
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) return null;
    final tag = json['tag_name'] as String?;
    final latest = Version.parse(tag ?? '');
    if (latest == null || latest <= current) return null;
    if (dismissedVersion != null && latest.toString() == dismissedVersion) {
      return null;
    }

    final htmlUrl = json['html_url'] as String?;
    final uri = Uri.tryParse(htmlUrl ?? releasePage);
    if (uri == null || uri.scheme != 'https' || uri.host != 'github.com') {
      return null;
    }

    return AppUpdate(
      version: latest.toString(),
      releasePage: uri,
      releaseNotes: (json['body'] as String?)?.trim(),
    );
  }

  Future<bool> openReleasePage(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}

/// Small semantic-version value object. GitHub tags may optionally start with
/// `v`; prerelease/build metadata is ignored for update comparison.
class Version implements Comparable<Version> {
  final int major;
  final int minor;
  final int patch;

  const Version(this.major, this.minor, this.patch);

  static Version? parse(String value) {
    final match = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)').firstMatch(value.trim());
    if (match == null) return null;
    return Version(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  @override
  int compareTo(Version other) {
    final majorResult = major.compareTo(other.major);
    if (majorResult != 0) return majorResult;
    final minorResult = minor.compareTo(other.minor);
    if (minorResult != 0) return minorResult;
    return patch.compareTo(other.patch);
  }

  @override
  String toString() => '$major.$minor.$patch';

  @override
  bool operator ==(Object other) => other is Version && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  bool operator <(Version other) => compareTo(other) < 0;
  bool operator <=(Version other) => compareTo(other) <= 0;
  bool operator >(Version other) => compareTo(other) > 0;
  bool operator >=(Version other) => compareTo(other) >= 0;
}
