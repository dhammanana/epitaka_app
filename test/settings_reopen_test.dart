/// The desktop settings window reopens on the page the user last chose.
library;

import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/settings/screens/help_screen.dart';
import 'package:epitaka/features/settings/widgets/desktop_settings_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<SettingsCategory> pages() => [
  for (final n in ['One', 'Two', 'Three'])
    SettingsCategory(
      id: n.toLowerCase(),
      icon: Icons.tune,
      title: n,
      body: Text('body $n'),
    ),
];

Widget window({String? initialId}) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizationsDelegate.supportedLocales,
  localizationsDelegates: const [AppLocalizationsDelegate()],
  home: Scaffold(
    body: DesktopSettingsDialog(
      categories: pages(),
      sidebarWidth: 230,
      initialId: initialId,
    ),
  ),
);

/// The first frame is empty until the localisations load.
Future<void> show(WidgetTester tester, Widget w) async {
  await tester.pumpWidget(w);
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('with nothing saved it opens on the first page', (tester) async {
    await show(tester, window());
    expect(find.text('body One'), findsOneWidget);
  });

  testWidgets('choosing a page saves it, and the next window opens there', (
    tester,
  ) async {
    await show(tester, window());
    await tester.tap(find.text('Three'));
    await tester.pump();
    expect(find.text('body Three'), findsOneWidget);

    final saved = await tester.runAsync(loadLastSettingsCategory);
    expect(saved, 'three');

    // Close the window, so the next one is built from scratch.
    await tester.pumpWidget(const SizedBox());
    await show(tester, window(initialId: saved));
    expect(find.text('body Three'), findsOneWidget);
  });

  // The tests above build the window by hand; this one opens it the way the
  // app does, so it fails if the saved page is not handed to the window.
  testWidgets('the settings window the app opens shows the saved page', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'settings_last_category': 'help'});
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizationsDelegate.supportedLocales,
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: Builder(
            builder: (c) => TextButton(
              onPressed: () => showDesktopSettingsDialog(c),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('open'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(HelpScreenBody), findsOneWidget);
  });

  testWidgets('a saved page that is not in the list opens the first page', (
    tester,
  ) async {
    await show(tester, window(initialId: 'tts'));
    expect(find.text('body One'), findsOneWidget);
  });
}
