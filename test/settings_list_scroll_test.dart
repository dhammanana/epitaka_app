/// The phone settings list reopens where the user left it (Q4): the scroll
/// position is kept for the run and saved for the next start. It opens on the
/// list, never straight on a page.
library;

import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/settings/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(resetSettingsListOffsetForTest);

  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final prefs = await SharedPreferences.getInstance();
    container.read(settingsProvider.notifier).init(prefs);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizationsDelegate.supportedLocales,
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double listOffset(WidgetTester tester) => tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .pixels;

  testWidgets('with nothing saved the list opens at the top', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpSettings(tester);
    expect(listOffset(tester), 0);
  });

  testWidgets('a scroll is saved, and the list reopens there in the same run', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await pumpSettings(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    final left = listOffset(tester);
    expect(left, greaterThan(200));

    final prefs = await tester.runAsync(SharedPreferences.getInstance);
    expect(prefs!.getDouble('settings_list_offset'), left);
    // The stored value is wiped, so only the run's own memory can give the
    // place back and the saved copy cannot stand in for it.
    await tester.runAsync(() => prefs.setDouble('settings_list_offset', 0));

    // A new widget of the same type in the same place would keep the old
    // state, so the list is closed first.
    await tester.pumpWidget(const SizedBox());
    await pumpSettings(tester);
    expect(listOffset(tester), left);
  });

  testWidgets('a new run opens at the saved place', (tester) async {
    SharedPreferences.setMockInitialValues({'settings_list_offset': 250.0});
    await pumpSettings(tester);
    expect(listOffset(tester), 250);
  });
}
