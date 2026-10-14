import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/theme/app_theme.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/dpd/services/dpd_installer.dart';
import 'package:epitaka/features/dpd/services/dpd_release_service.dart';
import 'package:epitaka/features/dpd/services/dpd_update_checker.dart';
import 'package:epitaka/features/dpd/widgets/dpd_update_dialog.dart';
import 'package:epitaka/features/settings/providers/translation_download_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeService extends DpdReleaseService {
  _FakeService({this.release, this.error});

  final DpdRelease? release;
  final Object? error;
  int calls = 0;

  @override
  Future<DpdRelease> fetchLatest() async {
    calls++;
    if (error != null) throw error!;
    return release!;
  }
}

const _latest = DpdRelease(
  tag: 'v0.4.20260926',
  url: 'https://example.invalid/dpd-mobile-db.zip',
  size: 209945935,
);

void main() {
  final monday = DateTime(2026, 10, 14, 9);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(DpdRelease?, int)> launch(
    DateTime at,
    String installed, {
    Object? error,
  }) async {
    final service = _FakeService(release: _latest, error: error);
    final checker = DpdUpdateNotifier(service: service, now: () => at);
    addTearDown(checker.dispose);
    final offer = await checker.checkIfDue(installed);
    return (offer, service.calls);
  }

  test('an older install is offered the newer release', () async {
    final (offer, calls) = await launch(monday, 'v0.4.20260728');
    expect(calls, 1);
    expect(offer?.tag, 'v0.4.20260926');
  });

  test('a second launch within a day does not ask GitHub', () async {
    await launch(monday, 'v0.4.20260728');
    final (offer, calls) = await launch(
      monday.add(const Duration(hours: 23)),
      'v0.4.20260728',
    );
    expect(calls, 0);
    expect(offer, isNull);
  });

  test('a launch a day later asks again and offers it again', () async {
    await launch(monday, 'v0.4.20260728');
    final (offer, calls) = await launch(
      monday.add(const Duration(hours: 24)),
      'v0.4.20260728',
    );
    expect(calls, 1);
    expect(offer?.tag, 'v0.4.20260926');
  });

  test('the same or a newer install is offered nothing', () async {
    expect((await launch(monday, 'v0.4.20260926')).$1, isNull);
    SharedPreferences.setMockInitialValues({});
    expect((await launch(monday, 'v0.4.20261012')).$1, isNull);
  });

  test('a failed check records no time, so the next launch asks', () async {
    await expectLater(
      launch(monday, 'v0.4.20260728', error: const DpdReleaseException('x')),
      throwsA(isA<DpdReleaseException>()),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(kDpdLastCheckKey), isNull);

    final (offer, calls) = await launch(
      monday.add(const Duration(minutes: 5)),
      'v0.4.20260728',
    );
    expect(calls, 1);
    expect(offer, isNotNull);
  });

  test('Check now shows the error, and keeps the last good time', () async {
    await launch(monday, 'v0.4.20260728');
    final checker = DpdUpdateNotifier(
      service: _FakeService(
        error: const DpdReleaseException('GitHub rate limit reached.'),
      ),
      now: () => monday.add(const Duration(hours: 1)),
    );
    addTearDown(checker.dispose);

    await checker.checkNow();

    expect(checker.state.error, 'GitHub rate limit reached.');
    expect(checker.state.lastCheck, monday);
    expect(checker.state.checking, isFalse);
  });

  test('a check time in the future (clock set back) counts as due', () async {
    await launch(monday, 'v0.4.20260728');
    final (offer, calls) = await launch(
      monday.subtract(const Duration(days: 3)),
      'v0.4.20260728',
    );
    expect(calls, 1);
    expect(offer, isNotNull);
  });

  test('Check now ends "checking" on an unexpected error too', () async {
    final checker = DpdUpdateNotifier(
      service: _FakeService(error: StateError('boom')),
      now: () => monday,
    );
    addTearDown(checker.dispose);

    await checker.checkNow();

    expect(checker.state.checking, isFalse);
    expect(checker.state.error, contains('boom'));
  });

  testWidgets('the notice stays until a button closes it', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
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
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => DpdUpdateDialog.show(context, _latest),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('v0.4.20260926 (200 MB)'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Download'), findsOneWidget);
    // Later and Download sit together in the button row.
    expect(
      tester.getCenter(find.text('Download')).dy,
      moreOrLessEquals(tester.getCenter(find.text('Later')).dy, epsilon: 1),
    );

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('New DPD release'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('New DPD release'), findsOneWidget);

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text('New DPD release'), findsNothing);
  });

  testWidgets('during the download the notice shows progress and Close', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizationsDelegate.supportedLocales,
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => DpdUpdateDialog.show(context, _latest),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    ProviderScope.containerOf(tester.element(find.text('New DPD release')))
        .read(translationDownloadProvider.notifier)
        .report(
          kDpdDownloadKey,
          const TranslationDownloadState(
            status: DownloadStatus.downloading,
            progress: 0.42,
          ),
        );
    await tester.pump();

    expect(find.text('DPD is downloading 42%'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Download'), findsNothing);
  });
}
