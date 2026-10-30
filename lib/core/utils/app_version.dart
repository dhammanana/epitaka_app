import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_version.g.dart';

/// The application version, as Settings → About shows it.
///
/// The single source of truth is `pubspec.yaml`'s `version:` field:
///
///  * [kPubspecAppVersion] / [kPubspecAppBuildNumber] are generated from it by
///    `tool/gen_app_version.dart` and compiled into the app, so every platform
///    and every build mode (release, profile, `flutter run`) reports the same
///    number without reading bundle metadata.
///  * A release build may re-stamp the number when the git tag outranks
///    pubspec, by passing `--dart-define=APP_VERSION=…` (and
///    `APP_BUILD_NUMBER=…`) — see the build workflow.
///  * [PackageInfo] is only a fallback for a build whose generated file is
///    missing or empty.
class AppVersion {
  final String version;
  final String buildNumber;

  const AppVersion({required this.version, this.buildNumber = ''});

  /// `1.2.3 (45)`, or just the version when no build number is known.
  String get display =>
      buildNumber.isEmpty ? version : '$version ($buildNumber)';
}

/// Build-time overrides for tagged releases (they win over pubspec).
const String _appVersionDefine = String.fromEnvironment('APP_VERSION');
const String _appBuildNumberDefine = String.fromEnvironment('APP_BUILD_NUMBER');

Future<AppVersion>? _cached;

/// Resolve the app version once per run: build-time defines first, then the
/// generated pubspec version, then the platform bundle.
Future<AppVersion> loadAppVersion() => _cached ??= _loadAppVersion();

Future<AppVersion> _loadAppVersion() async {
  if (_appVersionDefine.isNotEmpty) {
    return AppVersion(
      version: _appVersionDefine,
      buildNumber: _appBuildNumberDefine,
    );
  }
  if (kPubspecAppVersion.isNotEmpty) {
    return const AppVersion(
      version: kPubspecAppVersion,
      buildNumber: kPubspecAppBuildNumber,
    );
  }
  try {
    final info = await PackageInfo.fromPlatform();
    return AppVersion(version: info.version, buildNumber: info.buildNumber);
  } catch (e) {
    debugPrint('[VERSION] PackageInfo unavailable: $e');
    return const AppVersion(version: '—');
  }
}

@visibleForTesting
void resetAppVersionForTest() => _cached = null;
