// The sheet keeps its results between drag frames. A change of the colour
// scheme has to rebuild them: a card that kept the old scheme would show the
// light colours on the dark page until something else changed.
library;

import 'dart:io';

import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/theme/app_theme.dart';
import 'package:epitaka/features/dictionary/widgets/external_dictionary_section.dart';
import 'package:epitaka/features/dictionary/widgets/dictionary_sheet.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dpd_fixture.dart';
import 'shell_harness.dart';

void main() {
  late Directory dir;
  late File dbFile;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('sheet_memo_test');
    dbFile = buildDpdFixture(dir);
  });

  tearDownAll(() async {
    await dir.delete(recursive: true);
  });

  Widget app(ProviderContainer c, ThemePreference preference, Brightness b) =>
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: AppTheme.forPreference(preference, platformBrightness: b),
          locale: const Locale('en'),
          supportedLocales: AppLocalizationsDelegate.supportedLocales,
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(body: DictionarySheet(initialWord: 'dhamma')),
        ),
      );

  testWidgets('a new colour scheme rebuilds the memoized results', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final c = await makeShellContainer(tester, dbFile, words: ['dhamma']);

    await tester.pumpWidget(app(c, ThemePreference.light, Brightness.light));
    await settleShell(tester);
    final card = find.byType(ExternalDictionarySection, skipOffstage: false);
    expect(card, findsWidgets);
    final light = tester.widget<ExternalDictionarySection>(card.first).colors;

    await tester.pumpWidget(app(c, ThemePreference.dark, Brightness.dark));
    await settleShell(tester);
    final dark = tester.widget<ExternalDictionarySection>(card.first).colors;

    expect(dark, isNot(light));
    expect(dark.brightness, Brightness.dark);
  });
}
