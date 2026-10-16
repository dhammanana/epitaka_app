import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

// The links are built inside plain widgets and tap handlers, which cannot
// read providers, so the two versions are kept here once they are known.
String? _appVersion;
String? _dpdRelease;

/// Reads the app version as the About box shows it, `1.1.8 (39)`. Called once
/// at start-up; a failure leaves the version out of the label.
Future<void> loadFeedbackAppVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    _appVersion = '${info.version} (${info.buildNumber})';
  } catch (e) {
    developer.log('App version for feedback not read: $e', name: 'epitaka.dpd');
  }
}

/// The open DPD file's `dpd_release_version`, e.g. `v0.4.20261012`.
void setFeedbackDpdRelease(String? release) => _dpdRelease = release;

@visibleForTesting
void resetFeedbackVersionsForTest() {
  _appVersion = null;
  _dpdRelease = null;
}

/// Copied from the DPD app's `date_utils.dart`.
String feedbackPlatform() {
  if (Platform.isAndroid) return 'Android';
  if (Platform.isIOS) return 'iOS';
  if (Platform.isLinux) return 'Linux';
  if (Platform.isMacOS) return 'macOS';
  if (Platform.isWindows) return 'Windows';
  return 'Unknown';
}

/// What the forms' app field gets: `ePitaka 1.1.8 (39) Linux DPD v0.4.20261012`,
/// with any part not yet known left out.
String _appLabel() => [
  'ePitaka',
  ?_appVersion,
  feedbackPlatform(),
  if (_dpdRelease != null && _dpdRelease!.isNotEmpty) 'DPD $_dpdRelease',
].join(' ');

/// Opens DPD's own correction form in the browser. ePitaka has no in-app
/// feedback forms, so this is the only feedback path.
String buildMistakeUrl({String? word, int? headwordId, String? feedbackType}) {
  final url = StringBuffer(
    'https://docs.google.com/forms/d/e/1FAIpQLSf9boBe7k5tCwq7LdWgBHHGIPVc4ROO5yjVDo1X5LDAxkmGWQ/viewform?usp=pp_url',
  );

  if (word != null) {
    final encodedWord = Uri.encodeComponent(word);
    final wordIdentifier = headwordId != null
        ? '$headwordId%20$encodedWord'
        : encodedWord;
    url.write('&entry.438735500=$wordIdentifier');
  }
  if (feedbackType != null && feedbackType.isNotEmpty) {
    url.write('&entry.326955045=${Uri.encodeComponent(feedbackType)}');
  }

  url.write('&entry.1433863141=${Uri.encodeComponent(_appLabel())}');
  return url.toString();
}

/// DPD's form for a word the dictionary is missing.
String buildAddWordUrl() {
  return 'https://docs.google.com/forms/d/e/1FAIpQLSfResxEUiRCyFITWPkzoQ2HhHEvUS5fyg68Rl28hFH6vhHlaA/viewform?usp=pp_url'
      '&entry.1433863141=${Uri.encodeComponent(_appLabel())}';
}
