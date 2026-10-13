/// The desktop settings window reopens on the page the user last chose.
library;

import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/settings/widgets/desktop_settings_dialog.dart';
import 'package:flutter/material.dart';
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

  testWidgets('a saved page that is not in the list opens the first page', (
    tester,
  ) async {
    await show(tester, window(initialId: 'tts'));
    expect(find.text('body One'), findsOneWidget);
  });
}
