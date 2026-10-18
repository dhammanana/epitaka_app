import 'dart:io';

import 'package:epitaka/features/dpd/providers/dpd_database_provider.dart';
import 'package:epitaka/features/dpd/services/dpd_installer.dart';
import 'package:epitaka/features/dpd/services/dpd_release_service.dart';
import 'package:epitaka/features/dpd/widgets/dpd_download_control.dart';
import 'package:epitaka/features/settings/providers/translation_download_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shell_harness.dart';

const _mb = 1024 * 1024;
const _release = DpdRelease(
  tag: 'v0.4.20260926',
  url: 'https://example.invalid/dpd-mobile-db.zip',
  size: 200 * _mb,
);

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('dpd_resume_control_test');
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  File partial(
    int bytes, [
    String name = 'dpd-mobile.db.0123456789ab.zip.part',
  ]) => File('${dir.path}/$name')..writeAsBytesSync(List.filled(bytes, 1));

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        dpdDatabaseFileProvider.overrideWith(
          (ref) async => File('${dir.path}/dpd-mobile.db'),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('dpdPartialBytesProvider', () {
    test('reads the partial zip next to the database', () async {
      partial(1234);
      final container = makeContainer();

      expect(await container.read(dpdPartialBytesProvider(null).future), 1234);
    });

    test('with the name known, counts only that release', () async {
      partial(500, 'dpd-mobile.db.aaaaaaaaaaaa.zip.part');
      partial(900, 'dpd-mobile.db.bbbbbbbbbbbb.zip.part');
      final container = makeContainer();

      expect(
        await container.read(
          dpdPartialBytesProvider('dpd-mobile.db.bbbbbbbbbbbb.zip.part').future,
        ),
        900,
      );
      expect(
        await container.read(
          dpdPartialBytesProvider('dpd-mobile.db.cccccccccccc.zip.part').future,
        ),
        0,
      );
      expect(await container.read(dpdPartialBytesProvider(null).future), 900);
    });

    test('is 0 without a partial, and ignores other files', () async {
      File('${dir.path}/dpd-mobile.db').writeAsBytesSync([1, 2, 3]);
      final container = makeContainer();

      expect(await container.read(dpdPartialBytesProvider(null).future), 0);
    });

    test('is 0 while a download runs', () async {
      partial(1234);
      final container = makeContainer();
      container.listen(translationDownloadProvider, (_, _) {});
      container
          .read(translationDownloadProvider.notifier)
          .report(
            kDpdDownloadKey,
            const TranslationDownloadState(status: DownloadStatus.downloading),
          );

      expect(await container.read(dpdPartialBytesProvider(null).future), 0);
    });
  });

  group('DpdDownloadControl', () {
    Future<ProviderContainer> show(
      WidgetTester tester, {
      int? partialBytes,
      bool installed = false,
      DpdRelease? release,
      TranslationDownloadState? state,
    }) async {
      final container = ProviderContainer(
        overrides: [
          dpdPartialBytesProvider.overrideWith(
            (ref, name) async => partialBytes ?? 0,
          ),
          dpdFileInstalledProvider.overrideWith((ref) async => installed),
        ],
      );
      addTearDown(container.dispose);
      if (state != null) {
        container
            .read(translationDownloadProvider.notifier)
            .report(kDpdDownloadKey, state);
      }
      await tester.pumpWidget(
        wrapShell(container, DpdDownloadControl(release: release)),
      );
      await tester.pump();
      await tester.pump();
      return container;
    }

    testWidgets('with a partial it says Resume and how much is there', (
      tester,
    ) async {
      await show(tester, partialBytes: 84 * _mb, release: _release);

      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Download'), findsNothing);
      expect(find.text('84 of 200 MB already downloaded'), findsOneWidget);
    });

    testWidgets('without a known release it leaves out the total', (
      tester,
    ) async {
      await show(tester, partialBytes: 84 * _mb);

      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('84 MB already downloaded'), findsOneWidget);
    });

    testWidgets('without a partial it says Download', (tester) async {
      await show(tester, release: _release);

      expect(find.text('Download'), findsOneWidget);
      expect(find.text('Resume'), findsNothing);
      expect(find.textContaining('already downloaded'), findsNothing);
    });

    testWidgets('after a failure with a partial it says Resume, not Retry', (
      tester,
    ) async {
      await show(
        tester,
        partialBytes: 84 * _mb,
        state: const TranslationDownloadState(
          status: DownloadStatus.error,
          errorMessage: 'No data for 60 seconds. Press Resume to continue.',
        ),
      );

      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(
        find.text('No data for 60 seconds. Press Resume to continue.'),
        findsOneWidget,
      );
    });

    testWidgets('after a failure with a database installed there is no Retry', (
      tester,
    ) async {
      await show(
        tester,
        installed: true,
        state: const TranslationDownloadState(
          status: DownloadStatus.error,
          errorMessage: 'No database file found in the archive',
        ),
      );

      expect(find.text('Retry'), findsNothing);
      expect(find.text('Download'), findsOneWidget);
      expect(
        find.text('No database file found in the archive'),
        findsOneWidget,
      );
    });

    testWidgets('after a failure with nothing installed it still says Retry', (
      tester,
    ) async {
      await show(
        tester,
        state: const TranslationDownloadState(
          status: DownloadStatus.error,
          errorMessage: 'Download failed (HTTP 404)',
        ),
      );

      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Resume'), findsNothing);
    });
  });
}
