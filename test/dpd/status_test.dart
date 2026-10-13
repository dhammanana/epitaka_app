/// With no usable DPD database, the sheet, the panel and the settings page
/// say so and name the file, instead of showing an empty result.
library;

import 'dart:io';

import 'package:epitaka/core/providers/dictionary_books_provider.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/theme/app_theme.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_panel.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_sheet.dart';
import 'package:epitaka/features/dpd/providers/dpd_database_provider.dart';
import 'package:epitaka/features/dpd/providers/dpd_lookup_provider.dart';
import 'package:epitaka/features/settings/screens/dictionary_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dpd_fixture.dart';

class _FakeBooksNotifier extends DictionaryBooksNotifier {
  _FakeBooksNotifier(super.ref);

  @override
  Future<void> load() async {
    state = AsyncData(const [
      DictionaryBook(id: 11, name: 'DPD', userOrder: 1, userChoice: true),
    ]);
  }
}

/// Keeps the books list loading, so the settings page shows only its DPD row.
class _LoadingBooksNotifier extends DictionaryBooksNotifier {
  _LoadingBooksNotifier(super.ref);

  @override
  Future<void> load() async {}
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('dpd_status_test');
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  Future<ProviderContainer> makeContainer(
    WidgetTester tester,
    File dbFile, {
    bool loadingBooks = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        dpdDatabaseFileProvider.overrideWith((ref) async => dbFile),
        dictionaryBooksNotifierProvider.overrideWith(
          (ref) => loadingBooks
              ? _LoadingBooksNotifier(ref)
              : _FakeBooksNotifier(ref),
        ),
      ],
    );
    addTearDown(container.dispose);
    final prefs = await SharedPreferences.getInstance();
    container.read(settingsProvider.notifier).init(prefs);
    // Real file work never finishes on the test's fake clock.
    await tester.runAsync(() async {
      container.listen(dpdDatabaseProvider, (_, _) {});
      container.listen(dpdLookupProvider('dhamma'), (_, _) {});
      await container.read(dpdLookupProvider('dhamma').future);
    });
    return container;
  }

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
        home: Scaffold(body: child),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('sheet: no file → not-installed message with the path', (
    tester,
  ) async {
    bigView(tester);
    final missing = File('${dir.path}/dpd-mobile.db');
    final container = await makeContainer(tester, missing);

    await tester.pumpWidget(
      wrap(container, const DictionarySheet(initialWord: 'dhamma')),
    );
    await settle(tester);

    expect(find.text('The DPD database is not installed.'), findsOneWidget);
    expect(
      find.text('Expected file: ${missing.path}', findRichText: true),
      findsOneWidget,
    );
    expect(missing.existsSync(), isFalse, reason: 'looking must not create it');
  });

  testWidgets('panel: schema 8 → unsupported message with the path', (
    tester,
  ) async {
    bigView(tester);
    final file = buildDpdFixture(dir, schemaVersion: '8');
    final container = await makeContainer(tester, file);

    await tester.pumpWidget(
      wrap(container, const DictionaryPanel(initialWord: 'dhamma')),
    );
    await settle(tester);

    expect(find.textContaining('schema 8'), findsOneWidget);
    expect(find.textContaining('Update ePitaka'), findsOneWidget);
    expect(
      find.text('Expected file: ${file.path}', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('settings: the installed release shows', (tester) async {
    bigView(tester);
    final file = buildDpdFixture(dir);
    final container = await makeContainer(tester, file, loadingBooks: true);

    await tester.pumpWidget(wrap(container, const DictionarySettingsBody()));
    await settle(tester);

    expect(find.textContaining('Installed release: v0.4.'), findsOneWidget);
  });

  testWidgets('settings: no file → not-installed and the path', (tester) async {
    bigView(tester);
    final missing = File('${dir.path}/dpd-mobile.db');
    final container = await makeContainer(tester, missing, loadingBooks: true);

    await tester.pumpWidget(wrap(container, const DictionarySettingsBody()));
    await settle(tester);

    expect(find.text('The DPD database is not installed.'), findsOneWidget);
    expect(find.text(missing.path, findRichText: true), findsOneWidget);
  });
}
