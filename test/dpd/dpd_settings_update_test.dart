/// The DPD database row in Settings → Dictionaries: the installed release,
/// the last check, Check now with its answer, and the download.
library;

import 'dart:io';

import 'package:epitaka/features/dpd/services/dpd_installer.dart';
import 'package:epitaka/features/dpd/services/dpd_release_service.dart';
import 'package:epitaka/features/dpd/services/dpd_update_checker.dart';
import 'package:epitaka/features/settings/providers/translation_download_provider.dart';
import 'package:epitaka/features/settings/screens/dictionary_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dpd_fixture.dart';
import 'shell_harness.dart';

class _FakeService extends DpdReleaseService {
  _FakeService({this.release, this.error});

  final DpdRelease? release;
  final Object? error;

  @override
  Future<DpdRelease> fetchLatest() async {
    if (error != null) throw error!;
    return release!;
  }
}

DpdRelease _release(String tag) =>
    DpdRelease(tag: tag, url: 'https://example.invalid/x.zip', size: 209945935);

void main() {
  late Directory dir;
  late File dbFile;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('dpd_settings_update_test');
    // The fixture's release is v0.4.20261012.
    dbFile = buildDpdFixture(dir);
  });

  tearDownAll(() async {
    await dir.delete(recursive: true);
  });

  Future<ProviderContainer> open(
    WidgetTester tester, {
    DpdRelease? latest,
    Object? error,
    File? file,
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = await makeShellContainer(
      tester,
      file ?? dbFile,
      overrides: [
        dpdUpdateProvider.overrideWith(
          (ref) => DpdUpdateNotifier(
            service: _FakeService(release: latest, error: error),
            now: () => DateTime(2026, 10, 14, 9),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      wrapShell(container, const DictionarySettingsBody()),
    );
    await settleShell(tester);
    return container;
  }

  Future<void> checkNow(WidgetTester tester) async {
    await tester.tap(find.text('Check now'));
    await settleShell(tester);
  }

  testWidgets('before any check: the release, "not checked", Reinstall', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Installed release: v0.4.20261012'), findsOneWidget);
    expect(find.text('Not checked yet'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Reinstall'), findsOneWidget);
  });

  testWidgets('an older newest release: up to date, with the check date', (
    tester,
  ) async {
    await open(tester, latest: _release('v0.4.20260926'));
    await checkNow(tester);
    expect(find.text('Up to date'), findsOneWidget);
    expect(find.text('Last checked: 2026-10-14'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Reinstall'), findsOneWidget);
  });

  testWidgets('the check and its answer share a line, as do the buttons', (
    tester,
  ) async {
    await open(tester, latest: _release('v0.4.20260926'));
    await checkNow(tester);
    double midY(Finder f) => tester.getCenter(f).dy;
    expect(
      find.descendant(
        of: find
            .ancestor(of: find.text('Up to date'), matching: find.byType(Row))
            .first,
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    expect(
      midY(find.text('Up to date')),
      moreOrLessEquals(midY(find.text('Last checked: 2026-10-14')), epsilon: 3),
    );
    expect(
      midY(find.text('Reinstall')),
      moreOrLessEquals(midY(find.text('Check now')), epsilon: 1),
    );
  });

  testWidgets('a newer release: named with its size, and Download', (
    tester,
  ) async {
    await open(tester, latest: _release('v0.4.20261101'));
    await checkNow(tester);
    expect(
      find.text('Newer release: v0.4.20261101 (200 MB)'),
      findsOneWidget,
    );
    expect(find.text('Up to date'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Download'), findsOneWidget);
  });

  testWidgets('a failed check shows its error, never "up to date"', (
    tester,
  ) async {
    await open(
      tester,
      error: const DpdReleaseException('GitHub rate limit reached.'),
    );
    await checkNow(tester);
    expect(find.text('GitHub rate limit reached.'), findsOneWidget);
    expect(find.text('Up to date'), findsNothing);
    expect(find.text('Not checked yet'), findsOneWidget);
  });

  testWidgets('a running download shows its progress', (tester) async {
    final container = await open(tester);
    container
        .read(translationDownloadProvider.notifier)
        .report(
          kDpdDownloadKey,
          const TranslationDownloadState(
            status: DownloadStatus.downloading,
            progress: 0.42,
          ),
        );
    await settleShell(tester, frames: 2);
    expect(find.text('DPD is downloading 42%'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Reinstall'), findsNothing);
  });

  testWidgets('no file: not installed, and Download', (tester) async {
    await open(tester, file: File('${dir.path}/missing/dpd-mobile.db'));
    expect(find.text('The DPD database is not installed.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Download'), findsOneWidget);
  });
}
