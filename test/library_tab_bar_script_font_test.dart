/// Regression: the library category tab bar ("Mūla", "Aṭṭhakathā", …) must
/// render its labels with the script-specific font, like the book/nikaya
/// names in the library do.
///
/// Previously the label text was converted to the display script (e.g. Lao)
/// but the TabBar's label styles kept the default font, so scripts with a
/// dedicated bundled font (Lao → LaoPaliRegular, …) fell back to the
/// platform default and rendered incorrectly.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/core/providers/books_provider.dart';
import '../lib/core/utils/app_localizations.dart';
import '../lib/core/providers/settings_provider.dart';
import '../lib/core/utils/pali_script_converter.dart';
import '../lib/features/library/widgets/library_browser.dart';

void main() {
  Widget build() => ProviderScope(
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
          settingsProvider.overrideWith((ref) {
            final notifier = SettingsNotifier(null);
            notifier.state = const AppSettings(paliScript: Script.laos);
            return notifier;
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizationsDelegate.supportedLocales,
          home: const Scaffold(body: LibraryBrowser()),
        ),
      );

  testWidgets('category tab bar labels use the script font and converted text',
      (tester) async {
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));

    // The script font must be applied to both selected and unselected labels.
    expect(tabBar.labelStyle?.fontFamily, 'LaoPaliRegular');
    expect(tabBar.unselectedLabelStyle?.fontFamily, 'LaoPaliRegular');

    // The label text must be converted to Lao (not the roman "Mūla" etc.).
    final labels = tabBar.tabs
        .map((t) => (t as Tab).text ?? '')
        .toList();
    expect(
      labels.any((l) => l.contains('ມ')),
      isTrue,
      reason: 'expected at least one Lao label, got $labels',
    );
  });
}
