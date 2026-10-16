/// The DPD feedback forms carry the ePitaka version, the platform and the DPD
/// release in their app field (Q27), so a report says which build and which
/// dictionary file it came from.
library;

import 'dart:io';

import 'package:epitaka/features/dpd/providers/dpd_database_provider.dart';
import 'package:epitaka/features/dpd/utils/feedback_urls.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'dpd_fixture.dart';

String _appField(String url) =>
    Uri.parse(url).queryParameters['entry.1433863141']!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(resetFeedbackVersionsForTest);

  test('before anything is known: the app name and the platform', () {
    expect(_appField(buildAddWordUrl()), 'ePitaka ${feedbackPlatform()}');
  });

  test('both forms carry the app version and the DPD release', () async {
    PackageInfo.setMockInitialValues(
      appName: 'ePitaka',
      packageName: 'com.dn.epitaka',
      version: '1.1.8',
      buildNumber: '39',
      buildSignature: '',
    );
    await loadFeedbackAppVersion();
    setFeedbackDpdRelease('v0.4.20261012');
    final label = 'ePitaka 1.1.8 (39) ${feedbackPlatform()} DPD v0.4.20261012';
    expect(_appField(buildAddWordUrl()), label);
    expect(_appField(buildMistakeUrl(word: 'dhamma', headwordId: 1)), label);
  });

  test('opening the DPD file records its release', () async {
    final dir = await Directory.systemTemp.createTemp('feedback_release');
    addTearDown(() => dir.delete(recursive: true));
    final file = buildDpdFixture(dir, releaseVersion: 'v0.4.20990101');
    final c = ProviderContainer(
      overrides: [dpdDatabaseFileProvider.overrideWith((ref) async => file)],
    );
    addTearDown(c.dispose);
    final state = await c.read(dpdDatabaseProvider.future);
    expect(state.status, DpdDatabaseStatus.ready);
    expect(_appField(buildAddWordUrl()), endsWith('DPD v0.4.20990101'));
  });
}
