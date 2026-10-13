/// Shared setup for the dictionary sheet and panel tests: the real DPD
/// fixture database, no ePitaka books, and the app theme.
library;

import 'dart:io';

import 'package:epitaka/core/providers/dictionary_books_provider.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/theme/app_theme.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/dpd/providers/dictionary_list_provider.dart';
import 'package:epitaka/features/dpd/providers/dpd_database_provider.dart';
import 'package:epitaka/features/dpd/providers/dpd_lookup_provider.dart';
import 'package:epitaka/features/dpd/providers/dpd_settings_provider.dart';
import 'package:epitaka/features/dpd/providers/internet_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loads the dictionary list inside `runAsync`, where real file work can
/// finish, and keeps it alive for the widget to read.
Future<void> preloadDictionaryList(ProviderContainer container) async {
  container.listen(dictionaryListProvider, (_, _) {});
  await container.read(dictionaryAvailableProvider.future);
  await pumpEventQueue();
}

/// A container over the fixture database [dbFile].
///
/// Real file work never finishes on the test's fake clock, so every lookup in
/// [words] and every suggestion list in [prefixes] is loaded first, inside
/// `runAsync`, and kept alive for the widget to read.
Future<ProviderContainer> makeShellContainer(
  WidgetTester tester,
  File dbFile, {
  List<String> words = const [],
  List<String> prefixes = const [],
  WordLookupGesture? gesture,
  bool online = false,
  List<Override> overrides = const [],
  bool summary = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(
    overrides: [
      dpdDatabaseFileProvider.overrideWith((ref) async => dbFile),
      // No test may reach the network, so the audio check never looks up a host.
      hasInternetProvider.overrideWith((ref) async => online),
      // DPD is a list source now, not a book, so no ePitaka books are listed.
      dictionaryBooksProvider.overrideWith((ref) async => const []),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  final prefs = await SharedPreferences.getInstance();
  container.read(settingsProvider.notifier).init(prefs);
  if (gesture != null) {
    container.read(settingsProvider.notifier).setWordLookupGesture(gesture);
  }
  // Most tests are about the cards, so the summary above them is off unless
  // the test asks for it.
  container.read(dpdSettingsProvider.notifier).setShowSummary(summary);
  await tester.runAsync(() async {
    await preloadDictionaryList(container);
    for (final w in words) {
      container.listen(dpdLookupProvider(w), (_, _) {});
      await container.read(dpdLookupProvider(w).future);
    }
    for (final p in prefixes) {
      container.listen(dpdSuggestionsProvider(p), (_, _) {});
      await container.read(dpdSuggestionsProvider(p).future);
    }
  });
  return container;
}

Widget wrapShell(ProviderContainer container, Widget child) {
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

/// Pumps the fake clock in 60 ms frames, past the 300 ms suggestion debounce.
Future<void> settleShell(WidgetTester tester, {int frames = 16}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

String fieldText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField).first).controller!.text;
