/// Regression: the library category tabs were a fixed 40 high, so a reading
/// font with tall lines (or a larger text size) overflowed them by a few
/// pixels — the debug overflow stripes under "Mūla", "Aṭṭhakathā", …
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epitaka/core/providers/books_provider.dart';
import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/library/widgets/library_browser.dart';

void main() {
  Widget build(double textScale) => ProviderScope(
    overrides: [
      // No DB needed — feed the tree directly.
      booksTreeProvider.overrideWith(
        (ref) async => const [
          BookCategory(name: 'Mūla', nikayas: []),
          BookCategory(name: 'Aṭṭhakathā', nikayas: []),
          BookCategory(name: 'Ṭīkā', nikayas: []),
          BookCategory(name: 'Añña', nikayas: []),
        ],
      ),
      settingsProvider.overrideWith((ref) => SettingsNotifier(null)),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizationsDelegate.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const Scaffold(body: LibraryBrowser()),
    ),
  );

  testWidgets('tall labels fit inside the category tabs', (tester) async {
    await tester.pumpWidget(build(1.6));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final tab = tester.widget<Tab>(find.byType(Tab).first);
    expect(tab.height, greaterThan(40));
  });

  testWidgets('normal labels keep the 40-high tabs', (tester) async {
    await tester.pumpWidget(build(1.0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.widget<Tab>(find.byType(Tab).first).height, 40);
  });
}
