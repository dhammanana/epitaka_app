import 'dart:io';

import 'package:epitaka/features/dpd/providers/dpd_database_provider.dart';
import 'package:epitaka/features/dpd/services/dpd_installer.dart';
import 'package:epitaka/features/dpd/widgets/dpd_download_control.dart';
import 'package:epitaka/features/settings/providers/translation_download_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shell_harness.dart';

// The desktop dialog (file_selector); the test host is a desktop, so the control
// uses it here. The phone branch, which uses file_picker, is not run by tests.
const _pickerChannel = MethodChannel('plugins.flutter.io/file_selector');

void main() {
  group('deletePickerCopy', () {
    late Directory cache;
    late Directory elsewhere;

    setUp(() async {
      cache = await Directory.systemTemp.createTemp('picker_cache');
      elsewhere = await Directory.systemTemp.createTemp('picker_own');
    });

    tearDown(() async {
      await cache.delete(recursive: true);
      await elsewhere.delete(recursive: true);
    });

    File fileAt(String path) => File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync([1]);

    test('removes the picker copy under the cache folder', () async {
      final copy = fileAt('${cache.path}/file_picker/1700/dpd-mobile-db.zip');

      await deletePickerCopy(copy.path, cache);

      expect(copy.existsSync(), isFalse);
    });

    test("never removes the reader's own file", () async {
      final own = fileAt('${elsewhere.path}/dpd-mobile-db.zip');
      final inCache = fileAt('${cache.path}/other/dpd-mobile-db.zip');

      await deletePickerCopy(own.path, cache);
      await deletePickerCopy(inCache.path, cache);

      expect(own.existsSync(), isTrue);
      expect(inCache.existsSync(), isTrue);
    });

    test(
      'a path that climbs out of the picker folder is not removed',
      () async {
        final own = fileAt('${cache.path}/own.zip');

        await deletePickerCopy('${cache.path}/file_picker/../own.zip', cache);

        expect(own.existsSync(), isTrue);
      },
    );
  });

  group('the Import from file… button', () {
    Future<ProviderContainer> show(
      WidgetTester tester, {
      TranslationDownloadState? state,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          dpdPartialBytesProvider.overrideWith((ref, name) async => 0),
          dpdFileInstalledProvider.overrideWith((ref) async => false),
        ],
      );
      addTearDown(container.dispose);
      if (state != null) {
        container
            .read(translationDownloadProvider.notifier)
            .report(kDpdDownloadKey, state);
      }
      await tester.pumpWidget(wrapShell(container, const DpdDownloadControl()));
      await tester.pump();
      await tester.pump();
      return container;
    }

    void fakePicker(WidgetTester tester, Object? answer) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _pickerChannel,
        (call) async => answer,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          _pickerChannel,
          null,
        ),
      );
    }

    Future<void> tapImport(WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.tap(find.text('Import from file…'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
    }

    testWidgets('shows when idle', (tester) async {
      await show(tester);

      expect(find.text('Import from file…'), findsOneWidget);
    });

    testWidgets('shows after a failure', (tester) async {
      await show(
        tester,
        state: const TranslationDownloadState(
          status: DownloadStatus.error,
          errorMessage: 'Download failed (HTTP 404)',
        ),
      );

      expect(find.text('Import from file…'), findsOneWidget);
    });

    testWidgets('is hidden while downloading', (tester) async {
      await show(
        tester,
        state: const TranslationDownloadState(
          status: DownloadStatus.downloading,
          progress: 0.3,
        ),
      );

      expect(find.text('Import from file…'), findsNothing);
    });

    testWidgets('is hidden while unpacking', (tester) async {
      await show(
        tester,
        state: const TranslationDownloadState(
          status: DownloadStatus.extracting,
        ),
      );

      expect(find.text('Import from file…'), findsNothing);
    });

    testWidgets('imports the file the picker returns', (tester) async {
      fakePicker(tester, ['/nowhere/picked-dpd.zip']);
      final container = await show(tester);

      await tapImport(tester);

      final state = container.read(
        translationDownloadProvider,
      )[kDpdDownloadKey];
      expect(state?.status, DownloadStatus.error);
      expect(state?.errorMessage, contains('picked-dpd.zip'));
    });

    testWidgets('the dialog opens in the folder of the last pick', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final folder = Directory.systemTemp.createTempSync('dpd_last_folder');
      addTearDown(() => folder.deleteSync(recursive: true));
      final asked = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _pickerChannel,
        (call) async {
          asked.add((call.arguments as Map)['initialDirectory']);
          return ['${folder.path}/picked-dpd.zip'];
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          _pickerChannel,
          null,
        ),
      );
      await show(tester);

      await tapImport(tester);
      await tapImport(tester);

      expect(asked, [null, folder.path]);
    });

    testWidgets('a cancelled picker changes nothing', (tester) async {
      fakePicker(tester, null);
      final container = await show(tester);

      await tapImport(tester);

      expect(
        container.read(translationDownloadProvider)[kDpdDownloadKey],
        isNull,
      );
    });

    testWidgets('a picker that fails shows its error', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _pickerChannel,
        (call) async => throw PlatformException(code: 'broken'),
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          _pickerChannel,
          null,
        ),
      );
      final container = await show(tester);

      await tapImport(tester);

      final state = container.read(
        translationDownloadProvider,
      )[kDpdDownloadKey];
      expect(state?.status, DownloadStatus.error);
      expect(state?.errorMessage, contains('Could not open the file picker'));
    });
  });
}
