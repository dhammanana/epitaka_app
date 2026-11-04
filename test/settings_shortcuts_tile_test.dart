import 'package:epitaka/core/providers/settings_provider.dart';
import 'package:epitaka/core/utils/app_localizations.dart';
import 'package:epitaka/features/settings/screens/settings_screen.dart';
import 'package:epitaka/features/settings/screens/shortcut_settings_screen.dart';
import 'package:epitaka/router/app_router.dart' show AppRoutes;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The phone Settings screen: Help is now Feedback, and a Keyboard Shortcuts
/// tile opens the full shortcut page. The test host is desktop Linux, so the
/// "no tile on a phone" side cannot be shown here.
void main() {
  testWidgets('Feedback replaces Help and Keyboard Shortcuts opens its page', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final prefs = await SharedPreferences.getInstance();
    container.read(settingsProvider.notifier).init(prefs);

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SettingsScreen()),
        GoRoute(
          path: AppRoutes.shortcutSettings,
          builder: (_, _) => const ShortcutSettingsScreen(),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          supportedLocales: AppLocalizationsDelegate.supportedLocales,
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.scrollUntilVisible(
      find.text('Keyboard Shortcuts'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Help'), findsNothing);
    expect(find.text('Feedback'), findsOneWidget);
    expect(find.text('Send Feedback'), findsOneWidget);

    await tester.tap(find.text('Keyboard Shortcuts'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('shortcut-search')), findsOneWidget);
  });
}
