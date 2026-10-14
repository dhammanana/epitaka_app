/// A fresh install asks for the new DPD file in the wizard; an upgrade with a
/// built index cannot get past the start-up gate without it.
library;

import 'dart:convert';
import 'dart:io';

import 'package:epitaka/core/models/translation_version.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/theme/app_theme.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/dpd/providers/dpd_database_provider.dart';
import 'package:epitaka/features/dpd/services/dpd_installer.dart';
import 'package:epitaka/features/dpd/services/dpd_release_service.dart';
import 'package:epitaka/features/dpd/widgets/dpd_status_message.dart';
import 'package:epitaka/features/indexing/index_controller.dart';
import 'package:epitaka/features/indexing/index_gate.dart';
import 'package:epitaka/features/indexing/index_state.dart';
import 'package:epitaka/features/indexing/indexing_provider.dart';
import 'package:epitaka/features/settings/providers/translation_download_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dpd_fixture.dart';

class _ReadyIndex extends IndexController {
  _ReadyIndex(Ref ref) : super(ref);

  @override
  Future<void> checkStatus() async {
    state = const IndexState.ready();
  }
}

const _release = DpdRelease(
  tag: 'v0.4.20260926',
  url: 'https://example.invalid/dpd-mobile-db.zip',
  size: 209945935,
);

void main() {
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('dpd_gate_test');
  });

  tearDownAll(() async {
    await dir.delete(recursive: true);
  });

  group('the wizard', () {
    final manifest = TranslationManifest.fromJson(
      jsonDecode(File('assets/translations_manifest.json').readAsStringSync())
          as Map<String, dynamic>,
    );

    test('asks for the DPD mobile file, never the old one', () async {
      final required = await requiredCoreAssets(manifest, (_) async => false);
      final slugs = required.map((a) => a.slug).toList();
      expect(slugs, contains(kDpdDownloadKey));
      expect(slugs, isNot(contains('dpd_dictionary')));
      expect(
        required.map((a) => a.filename),
        isNot(contains('dpd-dictionary.db')),
      );
      expect(slugs, contains('epitaka'));
    });

    test('does not ask for DPD once the file is there', () async {
      final required = await requiredCoreAssets(
        manifest,
        (filename) async => filename == kDpdFilename,
      );
      expect(required.map((a) => a.slug), isNot(contains(kDpdDownloadKey)));
    });
  });

  Widget wrap(ProviderContainer container, Widget child) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.forPreference(
          ThemePreference.light,
          platformBrightness: Brightness.light,
        ),
        locale: const Locale('en'),
        supportedLocales: AppLocalizationsDelegate.supportedLocales,
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: child,
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<ProviderContainer> gateContainer(WidgetTester tester, File db) async {
    final container = ProviderContainer(
      overrides: [
        indexControllerProvider.overrideWith((ref) => _ReadyIndex(ref)),
        dpdDatabaseFileProvider.overrideWith((ref) async => db),
        dpdLatestReleaseProvider.overrideWith((ref) async => _release),
      ],
    );
    addTearDown(container.dispose);
    // Real file work never finishes on the test's fake clock.
    await tester.runAsync(() async {
      container.listen(dpdFileInstalledProvider, (_, _) {});
      await container.read(dpdFileInstalledProvider.future);
    });
    return container;
  }

  testWidgets('an upgrade without the DPD file stops at the download screen', (
    tester,
  ) async {
    final container = await gateContainer(
      tester,
      File('${dir.path}/missing/dpd-mobile.db'),
    );

    await tester.pumpWidget(
      wrap(container, const IndexGate(child: Text('THE APP'))),
    );
    await settle(tester);

    expect(find.text('THE APP'), findsNothing);
    expect(find.text('New DPD dictionary'), findsOneWidget);
    expect(
      find.textContaining('It must be downloaded before the app can open'),
      findsOneWidget,
    );
    expect(find.text('Download size: 200 MB'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Download'), findsOneWidget);
  });

  testWidgets('the screen shows the progress of a running download', (
    tester,
  ) async {
    final container = await gateContainer(
      tester,
      File('${dir.path}/missing/dpd-mobile.db'),
    );
    container
        .read(translationDownloadProvider.notifier)
        .report(
          kDpdDownloadKey,
          const TranslationDownloadState(
            status: DownloadStatus.downloading,
            progress: 0.42,
          ),
        );

    await tester.pumpWidget(
      wrap(container, const IndexGate(child: Text('THE APP'))),
    );
    await settle(tester);

    expect(find.text('DPD is downloading 42%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Download'), findsNothing);
  });

  testWidgets('with the DPD file in place the app opens', (tester) async {
    final installed = Directory('${dir.path}/installed')..createSync();
    final container = await gateContainer(tester, buildDpdFixture(installed));

    await tester.pumpWidget(
      wrap(container, const IndexGate(child: Text('THE APP'))),
    );
    await settle(tester);

    expect(find.text('THE APP'), findsOneWidget);
    expect(find.text('New DPD dictionary'), findsNothing);
  });

  testWidgets('a refresh while the app is open keeps the app', (tester) async {
    final installed = Directory('${dir.path}/kept')..createSync();
    final container = await gateContainer(tester, buildDpdFixture(installed));
    await tester.pumpWidget(
      wrap(container, const IndexGate(child: Text('THE APP'))),
    );
    await settle(tester);

    // What a swap does when it finishes.
    container.invalidate(dpdFileInstalledProvider);
    await tester.pump();

    expect(find.text('THE APP'), findsOneWidget);
    expect(find.text('Checking search index…'), findsNothing);
  });

  testWidgets('the app opens once the downloaded file is in place', (
    tester,
  ) async {
    final later = Directory('${dir.path}/later')..createSync();
    final container = await gateContainer(
      tester,
      File('${later.path}/dpd-mobile.db'),
    );
    await tester.pumpWidget(
      wrap(container, const IndexGate(child: Text('THE APP'))),
    );
    await settle(tester);
    expect(find.text('New DPD dictionary'), findsOneWidget);

    await tester.runAsync(() async {
      buildDpdFixture(later);
      container.invalidate(dpdFileInstalledProvider);
      await container.read(dpdFileInstalledProvider.future);
    });
    await settle(tester);

    expect(find.text('THE APP'), findsOneWidget);
  });

  testWidgets('the dictionary message shows a running download', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(translationDownloadProvider.notifier)
        .report(
          kDpdDownloadKey,
          const TranslationDownloadState(
            status: DownloadStatus.downloading,
            progress: 0.42,
          ),
        );

    await tester.pumpWidget(
      wrap(
        container,
        const Scaffold(
          body: DpdStatusMessage(
            unavailable: DpdUnavailable(
              DpdDatabaseState(
                status: DpdDatabaseStatus.notInstalled,
                path: '/data/dpd-mobile.db',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('The DPD database is not installed.'), findsOneWidget);
    expect(find.text('DPD is downloading 42%'), findsOneWidget);
  });
}
